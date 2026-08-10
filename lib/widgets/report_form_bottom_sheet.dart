import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';
import '../widgets/custom_svg_loader.dart';
import '../utils/notification_service.dart';

class ReportFormBottomSheet extends StatefulWidget {
  final String poleId;

  const ReportFormBottomSheet({super.key, required this.poleId});

  @override
  State<ReportFormBottomSheet> createState() => _ReportFormBottomSheetState();
}

class _ReportFormBottomSheetState extends State<ReportFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  IssueType _selectedIssueType = IssueType.brokenLight;
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _otherIssueController = TextEditingController();

  LatLng? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    _otherIssueController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    setState(() => _isLoadingLocation = true);
    
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _locationController.text = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      _isLoadingLocation = false;
    });
  }

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isSubmitting = true; });
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() { _isSubmitting = false; });
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Dismiss',
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: FadeTransition(
                opacity: animation,
                child: AlertDialog(
                  title: const Text('Authentication Required'),
                  content: const Text('You must be logged in to submit a report. Please log in or sign up to continue.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        return;
      }

      String finalDescription = _descriptionController.text;
      if (_selectedIssueType == IssueType.other && _otherIssueController.text.isNotEmpty) {
        finalDescription = 'Other Issue: ${_otherIssueController.text}\n\n$finalDescription'.trim();
      }

      final report = Report(
        userId: user.id,
        poleId: widget.poleId,
        issueType: _selectedIssueType,
        description: finalDescription,
        location: _locationController.text,
      );

      try {
        await Provider.of<ReportProvider>(context, listen: false).addReport(report);
        if (mounted) {
          Navigator.pop(context); // Close the bottom sheet
          NotificationService.showSuccess(context, 'Report submitted successfully!');
        }
      } catch (e) {
        if (mounted) {
          setState(() { _isSubmitting = false; });
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error Submitting Report'),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Submit Report',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Pole ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pole ID Scanned', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(widget.poleId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Issue Type
              Text('Select Issue Type', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: IssueType.values.map((type) {
                    final isSelected = _selectedIssueType == type;
                    final label = type == IssueType.brokenLight ? 'Broken Light' :
                                  type == IssueType.noStreetLight ? 'No Street Light' : 'Other';
                    final icon = type == IssueType.brokenLight ? Icons.lightbulb_outline :
                                 type == IssueType.noStreetLight ? Icons.power_off : Icons.more_horiz;
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.blue.shade900)),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: Colors.blue.shade700,
                        backgroundColor: Colors.blue.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), 
                          side: BorderSide(color: isSelected ? Colors.blue.shade700 : Colors.blue.shade200)
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedIssueType = type);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_selectedIssueType == IssueType.other) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('other_issue_field'),
                  controller: _otherIssueController,
                  decoration: InputDecoration(
                    labelText: 'Specify Other Issue',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.edit_note, color: Colors.blue),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Please specify the issue' : null,
                ),
              ],
              const SizedBox(height: 20),

              // Location Field
              TextFormField(
                key: const ValueKey('location_field'),
                controller: _locationController,
                readOnly: true, // Auto-filled from GPS
                decoration: InputDecoration(
                  labelText: 'Location / Coordinates',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SvgPicture.asset('assets/icons/form_location.svg', width: 24, height: 24),
                  ),
                  suffixIcon: _isLoadingLocation 
                      ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.my_location, color: Colors.blue),
                          onPressed: _determinePosition,
                        ),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please wait for location' : null,
              ),
              const SizedBox(height: 16),

              // Map View
              if (_currentPosition != null)
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: _currentPosition!,
                        initialZoom: 16.0,
                        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.diego.qrsystem',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _currentPosition!,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_currentPosition != null) const SizedBox(height: 16),

              // Description
              TextFormField(
                key: const ValueKey('description_field'),
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Additional Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 12.0, bottom: 48.0),
                    child: SvgPicture.asset('assets/icons/form_desc.svg', width: 24, height: 24),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  disabledBackgroundColor: Colors.green.shade300,
                ),
                child: _isSubmitting 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CustomSvgLoader(size: 24)
                      )
                    : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
