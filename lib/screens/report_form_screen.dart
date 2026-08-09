import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';
import '../widgets/custom_svg_loader.dart';

class ReportFormScreen extends StatefulWidget {
  final String poleId;

  const ReportFormScreen({super.key, required this.poleId});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  IssueType _selectedIssueType = IssueType.brokenLight;
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
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

      final report = Report(
        userId: user.id,
        poleId: widget.poleId,
        issueType: _selectedIssueType,
        description: _descriptionController.text,
        location: _locationController.text,
      );

      try {
        await Provider.of<ReportProvider>(context, listen: false).addReport(report);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Success'),
              content: const Text('Your report has been submitted to the maintenance team.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // close dialog
                    Navigator.of(context).pop(); // close form screen, go back to home
                  },
                  child: const Text('OK'),
                )
              ],
            ),
          );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pole ID Scanned', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Text(widget.poleId, style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<IssueType>(
                value: _selectedIssueType,
                decoration: const InputDecoration(
                  labelText: 'Issue Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: IssueType.brokenLight,
                    child: Text('Broken Light'),
                  ),
                  DropdownMenuItem(
                    value: IssueType.noStreetLight,
                    child: Text('No Street Light'),
                  ),
                  DropdownMenuItem(
                    value: IssueType.other,
                    child: Text('Other'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedIssueType = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location / Landmark',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Additional Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.blue.shade300,
                ),
                child: _isSubmitting 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CustomSvgLoader(size: 24)
                      )
                    : const Text('Submit Report', style: TextStyle(fontSize: 18)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
