import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';

class ReportProvider with ChangeNotifier {
  List<Report> _reports = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _currentFilter = 'All'; // 'All', 'Pending', 'Inspected', 'Resolved', 'Approved', 'Declined'
  
  RealtimeChannel? _subscription;
  
  static const int _pageSize = 5;

  List<Report> get reports => _reports;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String get currentFilter => _currentFilter;

  ReportProvider() {
    _initRealtimeSubscription();
    fetchReports(refresh: true);
  }

  void setFilter(String filter) {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    notifyListeners();
    fetchReports(refresh: true);
  }

  Future<void> fetchReports({bool refresh = false}) async {
    if (refresh) {
      _isLoading = true;
      _hasMore = true;
      _reports = [];
      notifyListeners();
    } else {
      if (_isLoadingMore || !_hasMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      var query = Supabase.instance.client
          .from('reports')
          .select();
          
      if (_currentFilter != 'All') {
        query = query.eq('status', _currentFilter.toLowerCase());
      }

      final data = await query
          .order('created_at', ascending: false)
          .range(_reports.length, _reports.length + _pageSize - 1);
      
      if (data.length < _pageSize) {
        _hasMore = false;
      }

      final newReports = data.map((json) => Report.fromJson(json)).toList();
      _reports.addAll(newReports);
      
    } catch (e) {
      debugPrint('Error fetching reports: $e');
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void _initRealtimeSubscription() {
    _subscription = Supabase.instance.client.channel('public:reports')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'reports',
        callback: (payload) {
          final newRecord = payload.newRecord;
          final oldRecord = payload.oldRecord;
          
          if (payload.eventType == PostgresChangeEvent.insert) {
            final report = Report.fromJson(newRecord);
            if (_currentFilter == 'All' || report.status.name.toLowerCase() == _currentFilter.toLowerCase()) {
               _reports.insert(0, report);
               notifyListeners();
            }
          } else if (payload.eventType == PostgresChangeEvent.update) {
            final updatedReport = Report.fromJson(newRecord);
            final index = _reports.indexWhere((r) => r.id == updatedReport.id);
            
            if (index != -1) {
              // If it no longer matches the filter, remove it
              if (_currentFilter != 'All' && updatedReport.status.name.toLowerCase() != _currentFilter.toLowerCase()) {
                _reports.removeAt(index);
              } else {
                _reports[index] = updatedReport;
              }
              notifyListeners();
            } else {
              // If it wasn't in the list but now matches the filter
              if (_currentFilter == 'All' || updatedReport.status.name.toLowerCase() == _currentFilter.toLowerCase()) {
                 _reports.insert(0, updatedReport);
                 notifyListeners();
              }
            }
          } else if (payload.eventType == PostgresChangeEvent.delete) {
            final deletedId = oldRecord['id'];
            _reports.removeWhere((r) => r.id == deletedId);
            notifyListeners();
          }
        }
      )
      .subscribe();
  }

  Future<void> addReport(Report report) async {
    try {
      await Supabase.instance.client
          .from('reports')
          .insert(report.toJson())
          .select()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Error adding report: $e');
      rethrow;
    }
  }

  Future<void> updateReportStatus(
    String reportId, 
    ReportStatus newStatus, {
    String? assignedUnit,
    String? managementRemarks,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus.name,
      };
      
      if (assignedUnit != null) {
        updateData['assigned_unit'] = assignedUnit;
      }
      if (managementRemarks != null) {
        updateData['management_remarks'] = managementRemarks;
      }

      await Supabase.instance.client
          .from('reports')
          .update(updateData)
          .eq('id', reportId);
      debugPrint('Updated report $reportId to $newStatus');
    } catch (e) {
      debugPrint('Error updating report status: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
