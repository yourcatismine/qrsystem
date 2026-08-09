import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String fullName = 'Guest User';
  String email = 'No email provided';
  String phone = 'No phone number';
  String? avatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        email = user.email ?? 'No email provided';
        final meta = user.userMetadata;
        if (meta != null) {
          final first = meta['first_name'] ?? '';
          final middle = meta['middle_name'] ?? '';
          final last = meta['last_name'] ?? '';
          final suffix = meta['suffix'] ?? '';
          
          // Construct full name
          List<String> nameParts = [];
          if (first.isNotEmpty) nameParts.add(first);
          if (middle.isNotEmpty) nameParts.add(middle);
          if (last.isNotEmpty) nameParts.add(last);
          if (suffix.isNotEmpty && suffix != 'None' && suffix != 'N/A') nameParts.add(suffix);
          
          fullName = nameParts.isEmpty ? 'Guest User' : nameParts.join(' ');
          phone = meta['phone'] ?? 'No phone number';
          avatarUrl = meta['avatar_url'];
        }
      });
    }
  }

  Future<void> _uploadProfilePicture() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile == null) return;
    
    setState(() {
      _isUploading = true;
    });

    try {
      final file = File(pickedFile.path);
      final fileExt = pickedFile.path.split('.').last;
      final fileName = '${user.id}-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      // Upload to Supabase Storage
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(fileName, file);
          
      // Get public URL
      final publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);
          
      // Update User Metadata
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'avatar_url': publicUrl},
        ),
      );
      
      setState(() {
        avatarUrl = publicUrl;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true, // Allows background to flow under AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Image with fading gradient overlay
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/background.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                foregroundDecoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.0), // Transparent at the top
                      Colors.white.withOpacity(0.5), // Semi-transparent white
                      Colors.white,                  // Solid white at the bottom
                    ],
                    stops: const [0.0, 0.4, 0.7],
                  ),
                ),
              ),
            ),
          ),
          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                const SizedBox(height: 32),
                // Profile Picture with Edit Badge
                GestureDetector(
                  onTap: _isUploading ? null : _uploadProfilePicture,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue.shade100, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                            child: _isUploading 
                                ? const CircularProgressIndicator()
                                : (avatarUrl == null 
                                    ? const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.white,
                                      )
                                    : null),
                          ),
                        ),
                        if (!_isUploading)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Full Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      shadows: [
                        Shadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Email
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Phone Number
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black87.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      icon: Icons.image_outlined,
                      label: 'Change profile picture',
                      onTap: _isUploading ? () {} : _uploadProfilePicture,
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: Icons.phone_android_outlined,
                      label: 'Change Number',
                      onTap: () {
                        // Action
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Hotlines Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'KORONADAL HOTLINES',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap any number to call immediately',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildHotlineCard(
                        icon: Icons.local_hospital, // Universal 911
                        title: 'NATIONAL EMERGENCY HOTLINE',
                        numbers: [
                          {'label': 'Emergency', 'number': '911'},
                        ],
                      ),
                      _buildHotlineCard(
                        icon: Icons.security, // CDRRMO
                        title: 'KORONADAL CDRRMO',
                        subtitle: '(City Disaster Risk Reduction and Management Office)',
                        numbers: [
                          {'label': 'Verified Landline', 'number': '(083) 228-3488'},
                          {'label': 'Verified Mobile', 'number': '0920-593-2201'},
                        ],
                      ),
                      _buildHotlineCard(
                        icon: Icons.local_police, // PNP
                        title: 'KORONADAL PNP',
                        subtitle: '(Koronadal City Police Station)',
                        numbers: [
                          {'label': 'Verified Landline', 'number': '(083) 228-2410'},
                          {'label': 'Verified Mobile', 'number': '0928-842-8344'},
                        ],
                      ),
                      _buildHotlineCard(
                        icon: Icons.electrical_services, // SOCOTECO
                        title: 'SOCOTECO II',
                        subtitle: '(South Cotabato II Electric Cooperative)',
                        numbers: [
                          {'label': 'Verified Landline', 'number': '(083) 228-2460'},
                          {'label': 'Verified Mobile', 'number': '0917-821-2201'},
                        ],
                      ),
                      _buildHotlineCard(
                        icon: Icons.fire_extinguisher, // BFP
                        title: 'BFP KORONADAL',
                        subtitle: '(Bureau of Fire Protection)',
                        numbers: [
                          {'label': 'Verified Landline', 'number': '(083) 228-2454'},
                          {'label': 'Verified Mobile', 'number': '0921-228-2454'},
                        ],
                      ),
                      _buildHotlineCard(
                        icon: Icons.medical_services, // CHO / Red Cross
                        title: 'MEDICAL EMERGENCIES',
                        subtitle: 'City Health Office / Red Cross / Provincial Hospital',
                        numbers: [
                          {'label': 'Red Cross', 'number': '(083) 228-2236'},
                          {'label': 'CHO', 'number': '(083) 228-2321'},
                          {'label': 'Provincial Hospital', 'number': '(083) 228-2616'},
                        ],
                      ),
                    ],
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

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              icon,
              size: 14,
              color: Colors.blue.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotlineCard({
    required IconData icon,
    required String title,
    String? subtitle,
    required List<Map<String, String>> numbers,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...numbers.map((num) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () async {
                      final cleanNum = num['number']!.replaceAll(RegExp(r'[^0-9]'), '');
                      final Uri url = Uri.parse('tel:$cleanNum');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 14),
                              children: [
                                TextSpan(
                                  text: '${num['label']}: ',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: num['number'],
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
