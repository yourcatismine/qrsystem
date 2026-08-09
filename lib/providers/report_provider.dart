import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';

class ReportProvider with ChangeNotifier {
  List<Report> _reports = [];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  List<Report> get reports => _reports;

  ReportProvider() {
    _initStream();
  }

  void _initStream() {
    // Listen to all reports. Real-time updates automatically!
    _subscription = Supabase.instance.client
        .from('reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .listen((data) {
      print('Stream received ${data.length} reports from Supabase.');
      try {
        _reports = data.map((json) {
          try {
            return Report.fromJson(json);
          } catch (e) {
            print('Error parsing individual report JSON: $e');
            print('JSON was: $json');
            rethrow; // Skip this update if parsing fails
          }
        }).toList();
        print('Successfully parsed ${_reports.length} reports.');
        notifyListeners();
      } catch (e) {
        print('Fatal error parsing reports stream: $e');
      }
    }, onError: (error) {
      print('Error listening to reports: $error');
    });
  }

  Future<void> addReport(Report report) async {
    // OPTIMISTIC UPDATE: Instantly show it on the UI before the server even responds!
    _reports.insert(0, report);
    notifyListeners();

    try {
      await Supabase.instance.client
          .from('reports')
          .insert(report.toJson())
          .select()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // Revert the UI if the database insert actually failed
      _reports.remove(report);
      notifyListeners();
      print('Error adding report: $e');
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
      print('Updated report $reportId to $newStatus');
    } catch (e) {
      print('Error updating report status: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
