import 'package:flutter/material.dart';
import '../models/report.dart';

class ReportProvider with ChangeNotifier {
  final List<Report> _reports = [];

  List<Report> get reports => _reports;

  void addReport(Report report) {
    _reports.add(report);
    notifyListeners();
  }

  void updateReportStatus(String id, ReportStatus newStatus) {
    final index = _reports.indexWhere((report) => report.id == id);
    if (index != -1) {
      _reports[index].status = newStatus;
      notifyListeners();
    }
  }
}
