import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/notification_service.dart';

// ─── Team Color Presets ────────────────────────────────────────────────────────
const _teamColors = [
  Color(0xFF1565C0), // Blue
  Color(0xFF6A1B9A), // Purple
  Color(0xFF00695C), // Teal
  Color(0xFFE65100), // Orange
  Color(0xFFC62828), // Red
  Color(0xFF37474F), // Dark Gray
  Color(0xFF558B2F), // Green
  Color(0xFF4527A0), // Deep Purple
];

// ─── New Team Bottom Sheet ─────────────────────────────────────────────────────
class _NewTeamSheet extends StatefulWidget {
  const _NewTeamSheet();

  @override
  State<_NewTeamSheet> createState() => _NewTeamSheetState();
}

class _NewTeamSheetState extends State<_NewTeamSheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  File? _pickedImage;
  Color _selectedColor = _teamColors[0];
  LatLng? _selectedLocation;
  bool _isCreating = false;
  final _formKey = GlobalKey<FormState>();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isCreating = true);

    try {
      String? avatarUrl;

      // Upload avatar — wrapped separately so a missing bucket won't kill team creation
      if (_pickedImage != null) {
        try {
          final bytes = await _pickedImage!.readAsBytes();
          final fileName = 'team_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage
              .from('avatars')
              .uploadBinary(fileName, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
          avatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
        } catch (uploadErr) {
          debugPrint('Avatar upload failed (continuing without it): $uploadErr');
        }
      }

      final name = _nameController.text.trim();
      final desc = _descController.text.trim();

      final insertData = <String, dynamic>{
        'name': name,
        if (desc.isNotEmpty) 'description': desc,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (_selectedLocation != null) 'latitude': _selectedLocation!.latitude,
        if (_selectedLocation != null) 'longitude': _selectedLocation!.longitude,
        'created_by': Supabase.instance.client.auth.currentUser?.id,
      };

      // Try to include color — silently skip if the column doesn't exist yet
      try {
        insertData['color'] = '#${_selectedColor.value.toRadixString(16).substring(2).toUpperCase()}';
      } catch (_) {}

      final newTeam = await Supabase.instance.client
          .from('teams')
          .insert(insertData)
          .select()
          .single();

      if (mounted) {
        Navigator.pop(context, newTeam);
      }
    } catch (e) {
      debugPrint('Create team error: $e');
      if (mounted) {
        setState(() => _isCreating = false);
        NotificationService.showError(context, 'Failed to create team: ${e.toString()}');
      }
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _selectedColor.withOpacity(0.12), shape: BoxShape.circle),
                    child: SvgPicture.asset(
                      'assets/icons/team.svg',
                      colorFilter: ColorFilter.mode(_selectedColor, BlendMode.srcIn),
                      width: 22, height: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('New Team', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 28),

              // ── Team Avatar Picker ──
              Center(
                child: GestureDetector(
                  onTap: _isCreating ? null : _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _selectedColor.withOpacity(0.1),
                          border: Border.all(color: _selectedColor.withOpacity(0.4), width: 2.5),
                          image: _pickedImage != null
                              ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _pickedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.group_rounded, size: 36, color: _selectedColor.withOpacity(0.7)),
                                ],
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _selectedColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Tap to set team photo', style: TextStyle(fontSize: 12, color: Colors.black38)),
              ),
              const SizedBox(height: 24),

              // ── Team Name ──
              TextFormField(
                controller: _nameController,
                enabled: !_isCreating,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Team Name *',
                  hintText: 'e.g. Alpha Response Team',
                  prefixIcon: const Icon(Icons.group_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _selectedColor, width: 2),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Team name is required' : null,
              ),
              const SizedBox(height: 14),

              // ── Description ──
              TextFormField(
                controller: _descController,
                enabled: !_isCreating,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'What does this team handle?',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(Icons.description_outlined),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: _selectedColor, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Team Color ──
              const Text('Team Color', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _teamColors.map((color) {
                  final selected = _selectedColor == color;
                  return GestureDetector(
                    onTap: _isCreating ? null : () => setState(() => _selectedColor = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black26 : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)]
                            : [],
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              
              const Text('Team Location', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final loc = await showModalBottomSheet<LatLng>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => LocationPickerSheet(initialLocation: _selectedLocation),
                  );
                  if (loc != null && mounted) {
                    setState(() => _selectedLocation = loc);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: _selectedLocation != null ? Colors.green.shade700 : Colors.grey.shade500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedLocation != null
                              ? 'Location: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                              : 'Tap to pick location on map',
                          style: TextStyle(
                            color: _selectedLocation != null ? Colors.black87 : Colors.black54,
                            fontWeight: _selectedLocation != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.black38),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Submit Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add, size: 20),
                            const SizedBox(width: 8),
                            const Text('Create Team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  List<Map<String, dynamic>> _teams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    try {
      setState(() => _isLoading = true);
      final data = await Supabase.instance.client
          .from('teams')
          .select('*, team_members(count)')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _teams = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading teams: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        NotificationService.showError(context, 'Failed to load teams: ${e.toString()}');
      }
    }
  }

  void _showCreateTeamDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewTeamSheet(),
    ).then((newTeam) {
      if (newTeam != null && newTeam is Map<String, dynamic>) {
        setState(() => _teams.insert(0, newTeam));
        NotificationService.showSuccess(context, 'Team "${newTeam['name']}" created!');
      }
    });
  }


  void _openTeamDetail(Map<String, dynamic> team) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TeamDetailScreen(team: team)),
    ).then((_) => _loadTeams()); // Refresh on return
  }

  void _confirmDeleteTeam(Map<String, dynamic> team) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Team', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "${team['name']}"? All members will be removed.'),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isDeleting ? null : () async {
                setD(() => isDeleting = true);
                try {
                  await Supabase.instance.client
                      .from('teams')
                      .delete()
                      .eq('id', team['id']);
                  setState(() => _teams.removeWhere((t) => t['id'] == team['id']));
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    NotificationService.showSuccess(context, 'Team deleted.');
                  }
                } catch (e) {
                  setD(() => isDeleting = false);
                  if (ctx.mounted) {
                    NotificationService.showError(context, 'Failed to delete team.');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isDeleting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/nav_teams.svg',
              colorFilter: ColorFilter.mode(Colors.blue.shade700, BlendMode.srcIn),
              width: 24, height: 24,
            ),
            const SizedBox(width: 10),
            const Text(
              'Assigns',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _showCreateTeamDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Team'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                    ),
                    child: CircularProgressIndicator(color: Colors.blue.shade700, strokeWidth: 3),
                  ),
                  const SizedBox(height: 20),
                  const Text('Loading Teams...', style: TextStyle(color: Colors.black54, fontSize: 15)),
                ],
              ),
            )
          : _teams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/icons/team.svg',
                        colorFilter: ColorFilter.mode(Colors.grey.shade300, BlendMode.srcIn),
                        width: 80, height: 80,
                      ),
                      const SizedBox(height: 20),
                      const Text('No Teams Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black45)),
                      const SizedBox(height: 8),
                      const Text('Tap "+ New Team" to create your first assign group', style: TextStyle(color: Colors.black38, fontSize: 14), textAlign: TextAlign.center),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTeams,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _teams.length,
                    itemBuilder: (ctx, i) {
                      final team = _teams[i];
                      final memberCount = (team['team_members'] as List?)?.isNotEmpty == true
                          ? (team['team_members'] as List).first['count'] ?? 0
                          : 0;

                      return _TeamCard(
                        team: team,
                        memberCount: memberCount,
                        onTap: () => _openTeamDetail(team),
                        onDelete: () => _confirmDeleteTeam(team),
                      );
                    },
                  ),
                ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final Map<String, dynamic> team;
  final dynamic memberCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TeamCard({
    required this.team,
    required this.memberCount,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = team['name'] ?? 'Unnamed Team';
    final desc = team['description'] as String?;
    final avatarUrl = team['avatar_url'] as String?;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'T';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(initials, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700))
                      : null,
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      if (desc != null && desc.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black45, fontSize: 13)),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.people_alt_outlined, size: 14, color: Colors.blue.shade400),
                          const SizedBox(width: 4),
                          Text('$memberCount member${memberCount == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade600, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                    if (v == 'open') onTap();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'open', child: Row(children: [Icon(Icons.open_in_new, size: 18), SizedBox(width: 8), Text('Open')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Team Detail Screen ───────────────────────────────────────────────────────

class TeamDetailScreen extends StatefulWidget {
  final Map<String, dynamic> team;
  const TeamDetailScreen({super.key, required this.team});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  late Map<String, dynamic> _team;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _team = Map.from(widget.team);
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      setState(() => _isLoading = true);
      final data = await Supabase.instance.client
          .from('team_members')
          .select('*, users:user_id(id, full_name, email, avatar_url, role)')
          .eq('team_id', _team['id'])
          .order('joined_at', ascending: true);
      if (mounted) {
        setState(() {
          _members = List<Map<String, dynamic>>.from(data as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading members: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditTeamDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTeamSheet(team: _team),
    ).then((updated) {
      if (updated != null && updated is Map<String, dynamic>) {
        setState(() {
          _team['name'] = updated['name'];
          _team['description'] = updated['description'];
          if (updated['avatar_url'] != null) _team['avatar_url'] = updated['avatar_url'];
        });
        NotificationService.showSuccess(context, 'Team updated!');
      }
    });
  }

  void _showAddMemberDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMemberSheet(teamId: _team['id'] as String),
    ).then((_) => _loadMembers());
  }

  void _removeMember(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove "${member['users']?['full_name'] ?? 'this member'}" from the team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Supabase.instance.client
                    .from('team_members')
                    .delete()
                    .eq('id', member['id']);
                await _loadMembers();
                if (mounted) NotificationService.showSuccess(context, 'Member removed.');
              } catch (e) {
                if (mounted) NotificationService.showError(context, 'Failed to remove member.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _team['name'] ?? 'Team';
    final desc = _team['description'] as String?;
    final avatarUrl = _team['avatar_url'] as String?;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'T';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        actions: [
          IconButton(
            tooltip: 'Edit Team',
            icon: const Icon(Icons.edit_outlined, color: Colors.black54),
            onPressed: _showEditTeamDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        backgroundColor: Colors.blue.shade700,
        icon: SvgPicture.asset(
          'assets/icons/team_add_member.svg',
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          width: 20, height: 20,
        ),
        label: const Text('Add Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Team header card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Text(initials, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade700))
                          : null,
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      if (desc != null && desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(desc, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_alt_outlined, size: 14, color: Colors.blue.shade700),
                                const SizedBox(width: 4),
                                Text('${_members.length} member${_members.length == 1 ? '' : 's'}',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          if (_team['latitude'] != null && _team['longitude'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: Colors.green.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(_team['latitude'] as double).toStringAsFixed(2)}, ${(_team['longitude'] as double).toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Members header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SvgPicture.asset('assets/icons/nav_teams.svg',
                    colorFilter: ColorFilter.mode(Colors.blue.shade700, BlendMode.srcIn),
                    width: 18, height: 18),
                const SizedBox(width: 8),
                const Text('Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Members list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blue.shade700))
                : _members.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset('assets/icons/team_add_member.svg',
                                colorFilter: ColorFilter.mode(Colors.grey.shade300, BlendMode.srcIn),
                                width: 60, height: 60),
                            const SizedBox(height: 16),
                            const Text('No members yet', style: TextStyle(color: Colors.black38, fontSize: 15)),
                            const SizedBox(height: 4),
                            const Text('Tap "Add Member" to get started', style: TextStyle(color: Colors.black26, fontSize: 13)),
                            const SizedBox(height: 80),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: _members.length,
                        itemBuilder: (ctx, i) {
                          final member = _members[i];
                          final user = member['users'] as Map<String, dynamic>? ?? {};
                          final fullName = user['full_name'] as String? ?? 'Unknown';
                          final email = user['email'] as String? ?? '';
                          final memberRole = member['role'] as String? ?? 'member';
                          final userAvatarUrl = user['avatar_url'] as String?;
                          final memberInitials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              leading: CircleAvatar(
                                radius: 24,
                                backgroundColor: memberRole == 'leader' ? Colors.amber.shade100 : Colors.grey.shade100,
                                backgroundImage: userAvatarUrl != null ? NetworkImage(userAvatarUrl) : null,
                                child: userAvatarUrl == null
                                    ? Text(memberInitials,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: memberRole == 'leader' ? Colors.amber.shade700 : Colors.grey.shade600,
                                        ))
                                    : null,
                              ),
                              title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              subtitle: Text(email, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: memberRole == 'leader' ? Colors.amber.shade50 : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: memberRole == 'leader' ? Colors.amber.shade300 : Colors.blue.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      memberRole == 'leader' ? '👑 Leader' : 'Member',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: memberRole == 'leader' ? Colors.amber.shade700 : Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                    onPressed: () => _removeMember(member),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit Team Bottom Sheet ───────────────────────────────────────────────────

class _EditTeamSheet extends StatefulWidget {
  final Map<String, dynamic> team;
  const _EditTeamSheet({required this.team});
  @override
  State<_EditTeamSheet> createState() => _EditTeamSheetState();
}

class _EditTeamSheetState extends State<_EditTeamSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  File? _pickedImage;
  LatLng? _selectedLocation;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team['name'] ?? '');
    _descController = TextEditingController(text: widget.team['description'] ?? '');
    if (widget.team['latitude'] != null && widget.team['longitude'] != null) {
      _selectedLocation = LatLng(widget.team['latitude'] as double, widget.team['longitude'] as double);
    }
  }

  @override
  void dispose() { _nameController.dispose(); _descController.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      String? avatarUrl = widget.team['avatar_url'] as String?;
      if (_pickedImage != null) {
        try {
          final bytes = await _pickedImage!.readAsBytes();
          final fileName = 'team_${DateTime.now().millisecondsSinceEpoch}.jpg';
          await Supabase.instance.client.storage.from('avatars')
              .uploadBinary(fileName, bytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
          avatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);
        } catch (e) { debugPrint('Avatar upload skipped: $e'); }
      }
      final name = _nameController.text.trim();
      final desc = _descController.text.trim();
      await Supabase.instance.client.from('teams')
          .update({
            'name': name, 
            'description': desc.isEmpty ? null : desc, 
            if (avatarUrl != null) 'avatar_url': avatarUrl,
            'latitude': _selectedLocation?.latitude,
            'longitude': _selectedLocation?.longitude,
          })
          .eq('id', widget.team['id']);
      if (mounted) Navigator.pop(context, {'name': name, 'description': desc, 'avatar_url': avatarUrl, 'latitude': _selectedLocation?.latitude, 'longitude': _selectedLocation?.longitude});
    } catch (e) {
      if (mounted) { setState(() => _isSaving = false); NotificationService.showError(context, 'Failed to update team.'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAvatar = widget.team['avatar_url'] as String?;
    final name = (widget.team['name'] ?? '') as String;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'T';
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: SvgPicture.asset('assets/icons/team_edit.svg', colorFilter: ColorFilter.mode(Colors.blue.shade700, BlendMode.srcIn), width: 20, height: 20)),
              const SizedBox(width: 12),
              const Text('Edit Team', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            ]),
            const SizedBox(height: 24),
            Center(child: GestureDetector(
              onTap: _isSaving ? null : _pickImage,
              child: Stack(children: [
                Container(width: 96, height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.shade50, border: Border.all(color: Colors.blue.shade200, width: 2.5),
                    image: _pickedImage != null ? DecorationImage(image: FileImage(_pickedImage!), fit: BoxFit.cover)
                        : currentAvatar != null ? DecorationImage(image: NetworkImage(currentAvatar), fit: BoxFit.cover) : null),
                  child: (_pickedImage == null && currentAvatar == null) ? Center(child: Text(initials, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue.shade700))) : null),
                Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 14))),
              ]),
            )),
            const SizedBox(height: 8),
            const Center(child: Text('Tap to change photo', style: TextStyle(fontSize: 12, color: Colors.black38))),
            const SizedBox(height: 20),
            TextFormField(controller: _nameController, enabled: !_isSaving, textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Team Name *', prefixIcon: const Icon(Icons.group_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade700, width: 2))),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 14),
            TextFormField(controller: _descController, enabled: !_isSaving, maxLines: 3,
              decoration: InputDecoration(labelText: 'Description',
                prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 44), child: Icon(Icons.description_outlined)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.blue.shade700, width: 2)))),
              
              const SizedBox(height: 20),
              const Text('Team Location', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _isSaving ? null : () async {
                  final loc = await showModalBottomSheet<LatLng>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => LocationPickerSheet(initialLocation: _selectedLocation),
                  );
                  if (loc != null && mounted) {
                    setState(() => _selectedLocation = loc);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: _selectedLocation != null ? Colors.green.shade700 : Colors.grey.shade500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedLocation != null
                              ? 'Location: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                              : 'Tap to pick location on map',
                          style: TextStyle(
                            color: _selectedLocation != null ? Colors.black87 : Colors.black54,
                            fontWeight: _selectedLocation != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.black38),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: _isSaving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SvgPicture.asset('assets/icons/team_edit.svg', colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), width: 18, height: 18),
                        const SizedBox(width: 8), const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]),
              )),
          ]),
        ),
      ),
    );
  }
}

// ─── Add Member Bottom Sheet ──────────────────────────────────────────────────

class _AddMemberSheet extends StatefulWidget {
  final String teamId;
  const _AddMemberSheet({required this.teamId});
  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _emailController = TextEditingController();
  String _selectedRole = 'member';
  bool _isAdding = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() { _emailController.dispose(); super.dispose(); }

  Future<void> _add() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isAdding = true);
    try {
      final userData = await Supabase.instance.client.from('users').select('id').eq('email', _emailController.text.trim()).single();
      await Supabase.instance.client.from('team_members').insert({'team_id': widget.teamId, 'user_id': userData['id'], 'role': _selectedRole});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _isAdding = false); NotificationService.showError(context, 'User not found or already in this team.'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: SvgPicture.asset('assets/icons/team_add_member.svg', colorFilter: ColorFilter.mode(Colors.green.shade700, BlendMode.srcIn), width: 20, height: 20)),
              const SizedBox(width: 12),
              const Text('Add Member', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            ]),
            const SizedBox(height: 8),
            Text('Add a user by their registered email.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 24),
            TextFormField(controller: _emailController, enabled: !_isAdding, keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'Member Email *', hintText: 'e.g. juan@mnip.gov.ph', prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.green.shade700, width: 2))),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null),
            const SizedBox(height: 18),
            const Text('Assign Role', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 10),
            Row(children: [
              _RoleTile(label: 'Member', icon: 'assets/icons/nav_teams.svg', description: 'Can view reports',
                selected: _selectedRole == 'member', color: Colors.blue.shade700,
                onTap: _isAdding ? null : () => setState(() => _selectedRole = 'member')),
              const SizedBox(width: 10),
              _RoleTile(label: 'Leader', icon: 'assets/icons/team.svg', description: 'Can manage team',
                selected: _selectedRole == 'leader', color: Colors.amber.shade700,
                onTap: _isAdding ? null : () => setState(() => _selectedRole = 'leader')),
            ]),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _isAdding ? null : _add,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: _isAdding ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SvgPicture.asset('assets/icons/team_add_member.svg', colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), width: 18, height: 18),
                        const SizedBox(width: 8), const Text('Add to Team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))]),
              )),
          ]),
        ),
      ),
    );
  }
}

// ─── Role Tile ────────────────────────────────────────────────────────────────
class _RoleTile extends StatelessWidget {
  final String label, icon, description;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;
  const _RoleTile({required this.label, required this.icon, required this.description, required this.selected, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 2 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SvgPicture.asset(icon, colorFilter: ColorFilter.mode(selected ? color : Colors.grey.shade400, BlendMode.srcIn), width: 22, height: 22),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: selected ? color : Colors.black54)),
            const SizedBox(height: 2),
            Text(description, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
      ),
    );
  }
}

// ─── Location Picker Bottom Sheet ─────────────────────────────────────────────
class LocationPickerSheet extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerSheet({
    Key? key,
    this.initialLocation,
  }) : super(key: key);

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late LatLng? _currentLocation;
  // Default to Koronadal City, South Cotabato, Mindanao
  final LatLng _defaultCenter = const LatLng(6.4988, 124.8488);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
  }

  void _onTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _currentLocation = point;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // Take up 70% of screen height
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.map_outlined, color: Colors.blue),
                SizedBox(width: 12),
                Text('Pick Location', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? _defaultCenter,
                    initialZoom: 12.0,
                    onTap: _onTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.qrsystem',
                    ),
                    if (_currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            alignment: Alignment.topCenter,
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Text(
                        _currentLocation == null
                            ? 'Tap anywhere on the map to place a pin.'
                            : 'Pin placed at:\n${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _currentLocation == null ? FontWeight.normal : FontWeight.bold,
                          color: _currentLocation == null ? Colors.black87 : Colors.blue.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _currentLocation = null);
                        Navigator.pop(context, null);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Clear', style: TextStyle(fontSize: 16, color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _currentLocation == null ? null : () {
                        Navigator.pop(context, _currentLocation);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Location', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


