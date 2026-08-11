import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';

class LiveTrackerMap extends StatefulWidget {
  final String reportId;
  final String teamName;
  final String reportLocationString;
  final ReportStatus initialStatus;

  const LiveTrackerMap({
    Key? key,
    required this.reportId,
    required this.teamName,
    required this.reportLocationString,
    required this.initialStatus,
  }) : super(key: key);

  @override
  State<LiveTrackerMap> createState() => _LiveTrackerMapState();
}

class _LiveTrackerMapState extends State<LiveTrackerMap> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  
  LatLng? _teamLocation;
  late LatLng _targetLocation;
  
  List<LatLng> _routePoints = [];
  LatLng? _currentAnimatedPos;
  
  bool _isLoading = true;
  String _statusMessage = "Locating team...";
  
  // ETA data
  double _totalDistanceKm = 0;
  double _totalDurationMins = 0;
  double _elapsedFraction = 0;

  bool _isExpanded = false;
  bool _hasNotifiedArrival = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    
    // Parse the report location
    _targetLocation = const LatLng(6.5050, 124.8500); // Default Koronadal City
    if (widget.reportLocationString.isNotEmpty) {
      final parts = widget.reportLocationString.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          _targetLocation = LatLng(lat, lng);
        }
      }
    }

    _animationController = AnimationController(
      vsync: this,
      // Compress the actual duration to 20 seconds for demonstration purposes
      duration: const Duration(seconds: 20), 
    );

    if (widget.initialStatus == ReportStatus.arrived) {
      _animationController.value = 1.0;
      _hasNotifiedArrival = true; // don't notify again
    }

    _animationController.addListener(() {
      if (_routePoints.isEmpty) return;
      
      setState(() {
        _elapsedFraction = _animationController.value;
        _currentAnimatedPos = _calculateInterpolatedPosition(_elapsedFraction);
      });

      if (_elapsedFraction >= 1.0 && !_hasNotifiedArrival) {
        _hasNotifiedArrival = true;
        // Update report status in DB silently
        try {
          Provider.of<ReportProvider>(context, listen: false)
              .updateReportStatus(widget.reportId, ReportStatus.arrived);
        } catch (e) {
          debugPrint("Failed to update arrival status: $e");
        }
      }
    });

    _initTracker();
  }

  Future<void> _initTracker() async {
    try {
      // 1. Fetch team location
      final data = await Supabase.instance.client
          .from('teams')
          .select('latitude, longitude')
          .eq('name', widget.teamName)
          .maybeSingle();

      if (data != null && data['latitude'] != null && data['longitude'] != null) {
        _teamLocation = LatLng(data['latitude'] as double, data['longitude'] as double);
      } else {
        // Fallback team location
        _teamLocation = const LatLng(6.4988, 124.8488);
      }

      setState(() {
        _statusMessage = "Calculating route...";
      });

      // 2. Fetch Route from OSRM
      await _fetchRoute();

    } catch (e) {
      debugPrint("LiveTracker init error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Error loading map";
        });
      }
    }
  }

  Future<void> _fetchRoute() async {
    if (_teamLocation == null) return;

    final startLon = _teamLocation!.longitude;
    final startLat = _teamLocation!.latitude;
    final endLon = _targetLocation.longitude;
    final endLat = _targetLocation.latitude;

    final url = 'http://router.project-osrm.org/route/v1/driving/$startLon,$startLat;$endLon,$endLat?overview=full&geometries=geojson';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['routes'] != null && json['routes'].isNotEmpty) {
          final route = json['routes'][0];
          
          _totalDistanceKm = (route['distance'] as num) / 1000.0;
          _totalDurationMins = (route['duration'] as num) / 60.0;
          
          final coords = route['geometry']['coordinates'] as List;
          _routePoints = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
          
          if (mounted) {
            setState(() {
              _isLoading = false;
              _currentAnimatedPos = widget.initialStatus == ReportStatus.arrived ? _routePoints.last : _routePoints.first;
              if (widget.initialStatus == ReportStatus.arrived) {
                _elapsedFraction = 1.0;
              }
            });
            
            // Adjust bounds
            _fitBounds();
            
            // Start animation only if not already arrived
            if (widget.initialStatus != ReportStatus.arrived) {
              _animationController.forward();
            }
          }
        }
      } else {
        // Fallback straight line
        _fallbackRoute();
      }
    } catch (e) {
      debugPrint("OSRM fetch error: $e");
      _fallbackRoute();
    }
  }

  void _fallbackRoute() {
    _routePoints = [_teamLocation!, _targetLocation];
    _totalDistanceKm = 5.0; // dummy
    _totalDurationMins = 10.0; // dummy
    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentAnimatedPos = widget.initialStatus == ReportStatus.arrived ? _routePoints.last : _routePoints.first;
        if (widget.initialStatus == ReportStatus.arrived) {
          _elapsedFraction = 1.0;
        }
      });
      _fitBounds();
      if (widget.initialStatus != ReportStatus.arrived) {
        _animationController.forward();
      }
    }
  }

  void _fitBounds() {
    if (_routePoints.isEmpty) return;
    
    final bounds = LatLngBounds.fromPoints(_routePoints);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _mapController.fitCamera(CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ));
      }
    });
  }

  LatLng _calculateInterpolatedPosition(double fraction) {
    if (_routePoints.isEmpty) return _teamLocation ?? _targetLocation;
    if (_routePoints.length == 1) return _routePoints.first;
    if (fraction >= 1.0) return _routePoints.last;
    if (fraction <= 0.0) return _routePoints.first;

    double totalPathDistance = 0;
    List<double> cumulativeDistances = [0];
    
    final distance = const Distance();
    for (int i = 0; i < _routePoints.length - 1; i++) {
      double d = distance.as(LengthUnit.Meter, _routePoints[i], _routePoints[i+1]);
      totalPathDistance += d;
      cumulativeDistances.add(totalPathDistance);
    }
    
    double targetDistance = totalPathDistance * fraction;
    
    for (int i = 0; i < cumulativeDistances.length - 1; i++) {
      if (targetDistance >= cumulativeDistances[i] && targetDistance <= cumulativeDistances[i+1]) {
        double segmentFraction = (targetDistance - cumulativeDistances[i]) / (cumulativeDistances[i+1] - cumulativeDistances[i]);
        return _interpolatePoint(_routePoints[i], _routePoints[i+1], segmentFraction);
      }
    }
    
    return _routePoints.last;
  }

  LatLng _interpolatePoint(LatLng p1, LatLng p2, double fraction) {
    double lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
    double lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;
    return LatLng(lat, lng);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(_statusMessage, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    final minsRemaining = (_totalDurationMins * (1.0 - _elapsedFraction)).ceil();
    final isArrived = _elapsedFraction >= 1.0;

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isExpanded ? MediaQuery.of(context).size.height * 0.7 : 250,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _targetLocation,
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.qrsystem',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints,
                    color: Colors.blue.shade600,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Target Report Marker
                  Marker(
                    point: _targetLocation,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    alignment: Alignment.topCenter,
                  ),
                  // Animated Team Marker
                  if (_currentAnimatedPos != null)
                    Marker(
                      point: _currentAnimatedPos!,
                      width: 50,
                      height: 50,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Icon(Icons.local_shipping, color: Colors.blue.shade800, size: 24),
                      ),
                      alignment: Alignment.center,
                    ),
                ],
              ),
            ],
          ),
        ),
        
        // ETA Banner Overlay
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isArrived ? Colors.green.shade600 : Colors.blue.shade700,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isArrived ? Icons.check_circle : Icons.directions_car,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isArrived ? 'Team has arrived!' : 'Team is on the way',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (!isArrived)
                        Text(
                          'ETA: $minsRemaining min • ${(_totalDistanceKm * (1.0 - _elapsedFraction)).toStringAsFixed(1)} km left',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Recenter on Team Button
        if (_currentAnimatedPos != null)
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_team',
                  backgroundColor: Colors.white,
                  onPressed: () {
                    _mapController.move(_currentAnimatedPos!, 16.0);
                  },
                  child: SvgPicture.asset('assets/icons/team.svg', colorFilter: ColorFilter.mode(Colors.blue.shade700, BlendMode.srcIn), width: 20, height: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fullscreen_map',
                  backgroundColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                    if (!_isExpanded) {
                      _fitBounds();
                    }
                  },
                  child: Icon(_isExpanded ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.black87),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
