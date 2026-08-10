import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';
import '../screens/reports_list_screen.dart';
import '../screens/report_details_screen.dart';
import 'route_map_bottom_sheet.dart';
import 'action_report_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/notification_service.dart';
class ManagementReportsSection extends StatelessWidget {
  const ManagementReportsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportProvider>(
      builder: (context, provider, child) {
        final pendingReports = provider.reports
            .where((r) => r.status == ReportStatus.pending)
            .toList();

        // Sort by newest first (descending timestamp)
        pendingReports.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        final displayReports = pendingReports.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ReportsListScreen(isManagement: true)),
                      );
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),
            if (displayReports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/reports.svg',
                          width: 32,
                          height: 32,
                          colorFilter: ColorFilter.mode(Colors.green.shade600, BlendMode.srcIn),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All caught up!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'There are no new reports right now.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: displayReports.length,
                itemBuilder: (context, index) {
                  return _ManagementReportCard(report: displayReports[index]);
                },
              ),
          ],
        );
      },
    );
  }
}

class _ManagementReportCard extends StatelessWidget {
  final Report report;

  const _ManagementReportCard({required this.report});

  void _showMap(BuildContext context, String location) {
    // Parse location 'lat, lng'
    final parts = location.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) {
        // Show map bottom sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => RouteMapBottomSheet(targetLat: lat, targetLng: lng),
        );
        return;
      }
    }
    NotificationService.showError(context, 'Invalid location data.');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDetailsScreen(report: report),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12.0),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report.issueType == IssueType.brokenLight 
                      ? 'Broken Light' 
                      : report.issueType == IssueType.noStreetLight 
                          ? 'No Street Light' 
                          : 'Other Issue',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${report.timestamp.month}/${report.timestamp.day}/${report.timestamp.year}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(report.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: ReporterInfoWidget(userId: report.userId)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showMap(context, report.location),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.map, color: Colors.blue, size: 26),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (report.id == null) return;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) => ActionReportBottomSheet(report: report, isApprove: true),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.check_circle, color: Colors.green, size: 26),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (report.id == null) return;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) => ActionReportBottomSheet(report: report, isApprove: false),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.cancel, color: Colors.red, size: 26),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

class ReporterInfoWidget extends StatefulWidget {
  final String userId;
  const ReporterInfoWidget({super.key, required this.userId});

  @override
  State<ReporterInfoWidget> createState() => _ReporterInfoWidgetState();
}

class _ReporterInfoWidgetState extends State<ReporterInfoWidget> {
  String _name = 'Loading...';
  String _initials = '';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchName();
  }

  Future<void> _fetchName() async {
    try {
      // First try fetching with avatar_url
      var response = await Supabase.instance.client
          .from('users')
          .select('first_name, last_name, avatar_url')
          .eq('id', widget.userId)
          .maybeSingle();

      _updateStateWithResponse(response);
    } catch (e) {
      // Fallback if avatar_url column does not exist in DB
      try {
        var responseFallback = await Supabase.instance.client
            .from('users')
            .select('first_name, last_name')
            .eq('id', widget.userId)
            .maybeSingle();
        _updateStateWithResponse(responseFallback);
      } catch (e2) {
        if (mounted) {
          setState(() {
            _name = 'Unknown User';
            _initials = '?';
          });
        }
      }
    }
  }

  void _updateStateWithResponse(Map<String, dynamic>? response) {
    if (response != null && mounted) {
      final first = response['first_name'] ?? '';
      final last = response['last_name'] ?? '';
      setState(() {
        _name = '$first $last'.trim();
        if (_name.isEmpty) _name = 'Unknown User';
        _initials = _name.isNotEmpty ? _name.substring(0, 1).toUpperCase() : '?';
        _avatarUrl = response['avatar_url'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Colors.indigo.shade100,
          backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty 
              ? NetworkImage(_avatarUrl!) 
              : null,
          child: _avatarUrl == null || _avatarUrl!.isEmpty
              ? Text(
                  _initials, 
                  style: TextStyle(fontSize: 11, color: Colors.indigo.shade900, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _name, 
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
