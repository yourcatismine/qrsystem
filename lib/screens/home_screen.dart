import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'scanner_screen.dart';
import 'reports_list_screen.dart';
import 'manage_qr_screen.dart';
import 'teams_screen.dart';
import '../widgets/report_form_bottom_sheet.dart';
import 'intro_screen.dart';

import 'profile_screen.dart';
import '../widgets/custom_svg_loader.dart';
import '../widgets/management_reports_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _userRole;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', user.id)
            .single(); // Using single() so it throws an error if RLS blocks it
            
        if (mounted) {
          setState(() {
            _userRole = data['role'] as String?;
            _isLoadingRole = false;
          });
        }
      } catch (e) {
        debugPrint('Error fetching user role: $e');
        if (mounted) {
          setState(() {
            _isLoadingRole = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingRole = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Custom Floating Action Button in the center
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 10), // pushes the button down slightly into the notch
        width: 56, // Normal FAB size
        height: 56,
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScannerScreen()),
            );
            
            if (result != null && result is String) {
              // Give the scanner screen's exit animation time to finish
              await Future.delayed(const Duration(milliseconds: 300));
              if (context.mounted) {
                debugPrint("Showing bottom sheet for poleId: $result");
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
                    child: ReportFormBottomSheet(poleId: result),
                  ),
                );
              }
            }
          },
          backgroundColor: Colors.blue.shade700,
          elevation: 4,
          shape: const CircleBorder(),
          child: SvgPicture.asset(
            'assets/icons/nav_scan_qr.svg',
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            width: 28,
            height: 28,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Custom Bottom App Bar
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 10,
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
          ),
          child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _buildBottomNavItem("assets/icons/nav_home.svg", "Home", 0)),
            Expanded(child: _buildBottomNavItem("assets/icons/nav_news.svg", "News", 1)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 30.0), // Pushes text down below the FAB notch
                child: Text(
                  'Scan QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _userRole == 'management'
                ? _buildBottomNavItem("assets/icons/nav_teams.svg", "Teams", 2)
                : _buildBottomNavItem("assets/icons/nav_mobile_id.svg", "Mobile ID", 2)
            ),
            Expanded(
              child: _userRole == 'management'
                ? _buildBottomNavItem("assets/icons/manage_qr.svg", "Manage QR", 3)
                : _buildBottomNavItem("assets/icons/nav_account.svg", "Account", 3),
            ),
          ],
        ),
        ),
      ),
      body: _isLoadingRole 
        ? const CustomSvgLoader()
        : Stack(
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
                    stops: const [0.0, 0.7, 1.0], // Pushed gradient down so short content doesn't cause a white void
                  ),
                ),
              ),
            ),
          ),
          // Main Foreground Content
          SafeArea(
            child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              _buildProfileSection(),
              const SizedBox(height: 12),
              _buildMainBanner(),
              const SizedBox(height: 20),
              _buildActionGrid(context),
              const SizedBox(height: 20),
              
              if (_userRole == 'management') ...[
                const ManagementReportsSection(),
                const SizedBox(height: 40),
              ],

              // Only show these sections to non-management users (e.g. regular users)
              if (_userRole != 'management') ...[
                _buildPromoBanner(),
                const SizedBox(height: 24),
                _buildFeaturedServices(),
                const SizedBox(height: 40), // extra padding for bottom scroll
              ],
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavItem(String svgPath, String label, int index,
      {int? badgeCount}) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? Colors.blue.shade700 : Colors.grey.shade600;

    return InkWell(
      onTap: () {
        if (label == 'Manage QR') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageQrScreen()));
          return;
        } else if (label == 'Teams') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamsScreen()));
          return;
        } else if (label == 'Account') {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
          return;
        }
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset(
                svgPath,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                width: 24,
                height: 24,
              ),
              if (badgeCount != null)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          )
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 0.0, right: 20.0, top: 12.0, bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Custom Logo Image
          Transform.translate(
            offset: const Offset(-12.0, 0), // Pushes the image physically left to combat transparent margins
            child: Image.asset(
              'assets/logo.png',
              height: 50,
              alignment: Alignment.centerLeft,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text('Save your image as assets/logo.png', style: TextStyle(fontSize: 12, color: Colors.grey));
              },
            ),
          ),
          // Notification Bell
          Stack(
            children: [
              Icon(Icons.notifications, color: Colors.blue.shade700, size: 28),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Builder(builder: (context) {
      final hour = DateTime.now().hour;
      Color timeColor;
      String greeting;

      if (hour < 12) {
        timeColor = Colors.lightBlue.shade200; // Morning (Soft blue)
        greeting = 'Good Morning';
      } else if (hour < 15) {
        timeColor = Colors.amber.shade200; // Noon (Bright sun)
        greeting = 'Good Noon';
      } else if (hour < 18) {
        timeColor = Colors.orange.shade300; // Afternoon (Sunset)
        greeting = 'Good Afternoon';
      } else {
        timeColor = Colors.deepPurple.shade300; // Night (Purple)
        greeting = 'Good Evening';
      }

      // Fetch the currently logged-in user's first name from Supabase
      String firstName = 'Guest';
      String phone = '';
      String? avatarUrl;
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.userMetadata != null) {
        firstName = user.userMetadata!['first_name'] ?? 'Guest';
        phone = user.userMetadata!['phone'] ?? '';
        avatarUrl = user.userMetadata!['avatar_url'];
      }

      return Container(
        margin: const EdgeInsets.only(left: 20.0, right: 20.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              timeColor.withOpacity(0.9),
              timeColor.withOpacity(0.0), // Fades out completely when it hits the left side
            ],
          ),
        ),
        child: Stack(
          children: [
            // Fading Philippine Flag
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.6], // Fades out completely before reaching the text
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SvgPicture.asset(
                    'assets/ph_flag.svg',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            // Profile Content
            Padding(
              padding: const EdgeInsets.only(left: 0.0, right: 16.0, top: 12.0, bottom: 12.0),
              child: Row(
          children: [
            InkWell(
              onTap: () async {
                final user = Supabase.instance.client.auth.currentUser;
                if (user != null) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                  // Refresh the home screen when returning to load the new avatar
                  if (mounted) setState(() {});
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const IntroScreen()),
                  );
                }
              },
              borderRadius: BorderRadius.circular(28),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 36) : null,
              ),
            ),
            const SizedBox(width: 8), // Reduced from 16 to pull text closer to the avatar
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $firstName',
                    style: TextStyle(
                        color: Colors.blue.shade900, // Darker blue for contrast
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 8,
                          )
                        ],
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(
                        color: Colors.blue.shade900.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 8,
                          )
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
    });
  }

  Widget _buildActionGrid(BuildContext context) {
    var actions = [
      {
        'svg': 'assets/icons/scan_qr.svg',
        'label': 'Scan QR',
        'isNew': false,
        'route': const ScannerScreen()
      },
      {
        'svg': 'assets/icons/reports.svg',
        'label': 'My Reports',
        'isNew': false,
        'route': const ReportsListScreen()
      },
      {
        'svg': 'assets/icons/map.svg',
        'label': 'Map',
        'isNew': false,
      },
      {
        'svg': 'assets/icons/alerts.svg',
        'label': 'Alerts',
        'isNew': false,
      },
      {
        'svg': 'assets/icons/guidelines.svg',
        'label': 'Guidelines',
        'isNew': false,
      },
    ];

    if (_userRole == 'management') {
      actions.removeWhere((action) => action['label'] == 'Scan QR' || action['label'] == 'My Reports');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: actions.length < 5 ? actions.length : 5,
          childAspectRatio: actions.length < 5 ? 1.2 : 0.8, // Adjust aspect ratio so they don't get too tall when stretched
          mainAxisSpacing: 16,
        ),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _buildGridItem(
            context,
            svgPath: action['svg'] as String,
            label: action['label'] as String,
            isNew: action['isNew'] as bool,
            route: action['route'] as Widget?,
          );
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context,
      {required String svgPath,
      required String label,
      required bool isNew,
      Widget? route}) {
    return GestureDetector(
      onTap: () async {
        if (route != null) {
          final result = await Navigator.push(
              context, MaterialPageRoute(builder: (context) => route));
              
          if (route is ScannerScreen && result != null && result is String) {
            // Give the scanner screen's exit animation time to finish
            await Future.delayed(const Duration(milliseconds: 300));
            if (context.mounted) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => Padding(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 40),
                  child: ReportFormBottomSheet(poleId: result),
                ),
              );
            }
          }
        }
      },
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F6FA), // Light bluish-grey background
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    svgPath,
                    width: 28,
                    height: 28,
                  ),
                ),
              ),
              if (isNew)
                Positioned(
                  top: -5,
                  right: -10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('New',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return SizedBox(
      height: 130, // Fixed height for the banner
      child: PageView(
        controller: PageController(viewportFraction: 0.92), // Allows slightly peeking the next item
        children: [
          _buildCarouselItem(
            imagePath: 'assets/featured/two.jpg',
            title: 'THINK SAFETY FIRST',
            summary: 'Ipinagbabawal ang pagsusunog ng basura malapit sa power lines upang maiwasan ang sunog at power interruptions (RA 11361).',
            titleColor: Colors.red.shade700,
          ),
          _buildCarouselItem(
            imagePath: 'assets/featured/one.png',
            title: '17TH NEAM & 57TH NEA',
            summary: 'Nakikiisa ang SOCOTECO II sa pagdiriwang ng NEAM at NEA Anniversary na may temang "Forging the Brightest As One".',
            titleColor: Colors.blue.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem({
    required String imagePath,
    required String title,
    required String summary,
    required Color titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8), // Reduced margin for carousel peeking
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
              ),
            ),
            // Gradient Overlay so text is readable
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Top Left Title
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: titleColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Summary Text
            Positioned(
              left: 12,
              top: 40,
              right: 60, // Keep text away from the right side illustration
              child: Text(
                summary,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Author Icon at Bottom Left
            Positioned(
              left: 12,
              bottom: 12,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.blue.shade600,
                    child: const Icon(Icons.person, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'System Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedServices() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About app',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFeaturedCard(
                  title: 'National Government\nServices',
                  subtitle: 'National Documents',
                  imagePath: 'assets/app/one.png',
                ),
                const SizedBox(width: 16),
                _buildFeaturedCard(
                  title: 'Local Government\nServices',
                  subtitle: 'Local Documents',
                  imagePath: 'assets/app/two.png',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFeaturedCard(
      {required String title,
      required String subtitle,
      IconData? icon,
      String? imagePath}) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: imagePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(imagePath, fit: BoxFit.cover),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                  Positioned(
                    right: -16,
                    bottom: -16,
                    child: Icon(icon, size: 80, color: Colors.blue.withOpacity(0.1)),
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildMainBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/banner.png',
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return const SkeletonLoader(height: 140);
          },
          errorBuilder: (context, error, stackTrace) {
            return const SkeletonLoader(height: 140);
          },
        ),
      ),
    );
  }
}

class SkeletonLoader extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletonLoader({
    super.key, 
    required this.height, 
    this.width = double.infinity, 
    this.borderRadius = 12,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}
