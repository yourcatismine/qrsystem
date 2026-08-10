import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';
import 'report_details_screen.dart';

class ReportsListScreen extends StatefulWidget {
  final bool isManagement;
  const ReportsListScreen({super.key, this.isManagement = false});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<ReportProvider>(context, listen: false);
      if (!provider.isLoading && !provider.isLoadingMore && provider.hasMore) {
        provider.fetchReports();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isManagement ? 'All Reports' : 'My Reports',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Consumer<ReportProvider>(
            builder: (context, provider, child) {
              return PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list, color: Color(0xFF1E293B)),
                onSelected: (value) {
                  provider.setFilter(value);
                },
                itemBuilder: (BuildContext context) {
                  final filters = ['All', 'Pending', 'Inspected', 'Resolved', 'Approved', 'Declined'];
                  return filters.map((String filter) {
                    return PopupMenuItem<String>(
                      value: filter,
                      child: Row(
                        children: [
                          Icon(
                            _getFilterIcon(filter),
                            color: _getFilterColor(filter),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            filter,
                            style: TextStyle(
                              fontWeight: provider.currentFilter == filter 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            ),
                          ),
                          if (provider.currentFilter == filter) ...[
                            const Spacer(),
                            const Icon(Icons.check, color: Colors.blue, size: 20),
                          ],
                        ],
                      ),
                    );
                  }).toList();
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<ReportProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/icons/reports.svg',
                    width: 120,
                    height: 120,
                    colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.isManagement 
                      ? 'No reports available for this filter.'
                      : 'You have not submitted any reports yet.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: provider.reports.length + (provider.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == provider.reports.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final report = provider.reports[index];
              return _buildPremiumCard(context, report);
            },
          );
        },
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'Pending': return Icons.schedule;
      case 'Inspected': return Icons.search;
      case 'Resolved': return Icons.check_circle;
      case 'Approved': return Icons.thumb_up;
      case 'Declined': return Icons.thumb_down;
      default: return Icons.apps;
    }
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Pending': return Colors.orange;
      case 'Inspected': return Colors.blue;
      case 'Resolved': return Colors.green;
      case 'Approved': return Colors.green;
      case 'Declined': return Colors.red;
      default: return Colors.grey.shade700;
    }
  }

  Widget _buildPremiumCard(BuildContext context, Report report) {
    String title = report.issueType == IssueType.brokenLight 
        ? 'Broken Light' 
        : (report.issueType == IssueType.noStreetLight ? 'No Street Light' : 'Other Issue');

    String iconPath;
    if (report.issueType == IssueType.brokenLight) {
      iconPath = 'assets/icons/broken_light.svg';
    } else if (report.issueType == IssueType.noStreetLight) {
      iconPath = 'assets/icons/no_street_light.svg';
    } else {
      iconPath = 'assets/icons/other_issue.svg';
    }

    LatLng? locationPoint;
    if (report.location.isNotEmpty) {
      final parts = report.location.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          locationPoint = LatLng(lat, lng);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportDetailsScreen(report: report),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SvgPicture.asset(
                        iconPath,
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(Color(0xFF3B82F6), BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Title and Pole info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.electric_bolt, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                'Pole: ${report.poleId}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Status Badge
                    _buildStatusBadge(report.status),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                
                // Location Info
                Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/form_location.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(Color(0xFF94A3B8), BlendMode.srcIn),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location: ${report.location}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
                  ],
                ),
                
                if (locationPoint != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: locationPoint,
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.qrsystem',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: locationPoint,
                                width: 36,
                                height: 36,
                                alignment: Alignment.topCenter,
                                child: SvgPicture.asset(
                                  'assets/icons/form_location.svg',
                                  colorFilter: const ColorFilter.mode(Colors.redAccent, BlendMode.srcIn),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(ReportStatus status) {
    Color color;
    Color bgColor;
    String text;

    switch (status) {
      case ReportStatus.pending:
        color = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFEF3C7);
        text = 'Pending';
        break;
      case ReportStatus.inspected:
        color = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFDBEAFE);
        text = 'Inspected';
        break;
      case ReportStatus.resolved:
        color = const Color(0xFF10B981);
        bgColor = const Color(0xFFD1FAE5);
        text = 'Resolved';
        break;
      case ReportStatus.approved:
        color = const Color(0xFF10B981);
        bgColor = const Color(0xFFD1FAE5);
        text = 'Approved';
        break;
      case ReportStatus.declined:
        color = const Color(0xFFEF4444);
        bgColor = const Color(0xFFFEE2E2);
        text = 'Declined';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
