import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';
import '../providers/report_provider.dart';
import '../utils/notification_service.dart';

class ActionReportBottomSheet extends StatefulWidget {
  final Report report;
  final bool isApprove;

  const ActionReportBottomSheet({
    super.key,
    required this.report,
    required this.isApprove,
  });

  @override
  State<ActionReportBottomSheet> createState() => _ActionReportBottomSheetState();
}

class _ActionReportBottomSheetState extends State<ActionReportBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();

  String? _selectedTeamId;   // stores the team UUID
  String? _selectedTeamName; // stores the team name for display
  bool _isSubmitting = false;
  bool _isLoadingTeams = true;
  List<Map<String, dynamic>> _teams = [];

  @override
  void initState() {
    super.initState();
    if (widget.isApprove) _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      final data = await Supabase.instance.client
          .from('teams')
          .select('id, name')
          .order('name', ascending: true);
      if (mounted) {
        setState(() {
          _teams = List<Map<String, dynamic>>.from(data as List);
          _isLoadingTeams = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load teams: $e');
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitAction() async {
    if (!_formKey.currentState!.validate()) return;
    
    // For approval, ensure a team is selected
    if (widget.isApprove && _selectedTeamId == null) {
      NotificationService.showError(context, 'Please assign a team.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final newStatus = widget.isApprove ? ReportStatus.ongoing : ReportStatus.declined;
      
      await Provider.of<ReportProvider>(context, listen: false).updateReportStatus(
        widget.report.id!,
        newStatus,
        assignedUnit: widget.isApprove ? _selectedTeamName : null,
        managementRemarks: _remarksController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true); // Close bottom sheet and return true
        NotificationService.showSuccess(context, widget.isApprove ? 'Report Approved & Unit Assigned!' : 'Report Declined.');
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(context, 'Error: $e');
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bottom padding handles the keyboard popping up
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    final color = widget.isApprove ? Colors.green : Colors.red;
    final icon = widget.isApprove ? Icons.check_circle_outline : Icons.cancel_outlined;
    final title = widget.isApprove ? 'Approve & Assign' : 'Decline Report';
    final submitText = widget.isApprove ? 'Confirm Approval' : 'Confirm Decline';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset > 0 ? bottomInset + 24 : 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: color),
              ),
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Dropdown (Only for Approve)
            if (widget.isApprove) ...[
              const Text(
                'Assign Team',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              if (_isLoadingTeams)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green.shade700)),
                      const SizedBox(width: 10),
                      Text('Loading teams...', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    ]),
                  ),
                )
              else if (_teams.isEmpty)
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Center(
                    child: Text('No teams found — create one in Assigns first',
                        style: TextStyle(color: Colors.orange.shade700, fontSize: 13)),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedTeamId,
                  hint: const Text('Select a team to assign...'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: _teams.map((team) {
                    return DropdownMenuItem<String>(
                      value: team['id'] as String,
                      child: Text(team['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTeamId = val;
                      _selectedTeamName = _teams.firstWhere((t) => t['id'] == val)['name'] as String;
                    });
                  },
                  validator: (val) => (val == null || val.isEmpty) ? 'Please assign a team' : null,
                ),
              const SizedBox(height: 20),
            ],

            // Remarks
            Text(
              widget.isApprove ? 'Instructions / Remarks (Optional)' : 'Reason for Decline (Required)',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _remarksController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: widget.isApprove 
                    ? 'Enter any specific notes for the unit...' 
                    : 'Explain why this report is being rejected...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              validator: (val) {
                if (!widget.isApprove && (val == null || val.isEmpty)) {
                  return 'Please provide a reason for declining';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting ? null : _submitAction,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(
                        submitText,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
