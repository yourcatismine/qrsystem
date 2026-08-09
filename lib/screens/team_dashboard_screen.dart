import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';

class TeamDashboardScreen extends StatelessWidget {
  const TeamDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance Dashboard'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.reports.isEmpty) {
            return const Center(
              child: Text('No reports to show.'),
            );
          }
          
          return ListView.builder(
            itemCount: provider.reports.length,
            itemBuilder: (context, index) {
              final report = provider.reports[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text('Pole ID: ${report.poleId}'),
                        subtitle: Text('Location: ${report.location}\nDesc: ${report.description}'),
                        isThreeLine: true,
                        trailing: _buildStatusDropdown(context, report),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context, Report report) {
    return DropdownButton<ReportStatus>(
      value: report.status,
      items: const [
        DropdownMenuItem(
          value: ReportStatus.pending,
          child: Text('Pending'),
        ),
        DropdownMenuItem(
          value: ReportStatus.inspected,
          child: Text('Inspected'),
        ),
        DropdownMenuItem(
          value: ReportStatus.resolved,
          child: Text('Resolved'),
        ),
      ],
      onChanged: (newStatus) {
        if (newStatus != null && report.id != null) {
          Provider.of<ReportProvider>(context, listen: false)
              .updateReportStatus(report.id!, newStatus);
        }
      },
    );
  }
}
