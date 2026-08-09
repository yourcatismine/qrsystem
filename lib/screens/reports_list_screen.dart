import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';

class ReportsListScreen extends StatelessWidget {
  final bool isManagement;
  const ReportsListScreen({super.key, this.isManagement = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isManagement ? 'All Reports' : 'My Reports'),
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.reports.isEmpty) {
            return const Center(
              child: Text('You have not submitted any reports yet.'),
            );
          }
          
          return ListView.builder(
            itemCount: provider.reports.length,
            itemBuilder: (context, index) {
              final report = provider.reports[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    report.issueType == IssueType.brokenLight 
                      ? 'Broken Light' 
                      : (report.issueType == IssueType.noStreetLight ? 'No Street Light' : 'Other'),
                  ),
                  subtitle: Text('Pole: ${report.poleId}\nLoc: ${report.location}'),
                  trailing: _buildStatusChip(report.status),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color color;
    String text;

    switch (status) {
      case ReportStatus.pending:
        color = Colors.orange;
        text = 'Pending';
        break;
      case ReportStatus.inspected:
        color = Colors.blue;
        text = 'Inspected';
        break;
      case ReportStatus.resolved:
        color = Colors.green;
        text = 'Resolved';
        break;
      case ReportStatus.approved:
        color = Colors.green;
        text = 'Approved';
        break;
      case ReportStatus.declined:
        color = Colors.red;
        text = 'Declined';
        break;
    }

    return Chip(
      label: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
    );
  }
}
