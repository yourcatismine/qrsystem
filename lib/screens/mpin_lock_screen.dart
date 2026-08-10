import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'intro_screen.dart';
import '../widgets/custom_svg_loader.dart';

class MpinLockScreen extends StatefulWidget {
  final String? email;
  final String? name;

  const MpinLockScreen({
    super.key,
    this.email,
    this.name,
  });

  @override
  State<MpinLockScreen> createState() => _MpinLockScreenState();
}

class _MpinLockScreenState extends State<MpinLockScreen> {
  final TextEditingController _mpinController = TextEditingController();
  final FocusNode _mpinFocusNode = FocusNode();
  
  bool _isLoading = false;
  String? _errorMessage;

  String get mpin => _mpinController.text;

  @override
  void initState() {
    super.initState();
    // Start listening to the controller to auto-verify at 6 digits
    _mpinController.addListener(_onMpinChanged);
  }

  @override
  void dispose() {
    _mpinController.removeListener(_onMpinChanged);
    _mpinController.dispose();
    _mpinFocusNode.dispose();
    super.dispose();
  }

  void _onMpinChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
    
    if (mpin.length == 6 && !_isLoading) {
      _verifyMpin();
    } else {
      setState(() {});
    }
  }

  Future<void> _verifyMpin() async {
    setState(() => _isLoading = true);
    
    // Simulate a tiny delay for smooth UI feedback
    await Future.delayed(const Duration(milliseconds: 300));
    
    final user = Supabase.instance.client.auth.currentUser;
    final isLoginMode = widget.email != null;

    if (isLoginMode) {
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: widget.email,
          password: mpin,
        );
        
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          _mpinController.clear();
          setState(() {
            _isLoading = false;
            _errorMessage = "Incorrect MPIN. Please try again.";
          });
          _mpinFocusNode.requestFocus();
        }
      }
    } else {
      final metadata = user?.userMetadata ?? {};
      final correctMpin = metadata['mpin'] as String?;

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (correctMpin == mpin) {
          // Success! Go to Home Screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          // Failed
          _mpinController.clear();
          setState(() {
            _errorMessage = "Incorrect MPIN. Please try again.";
          });
          _mpinFocusNode.requestFocus();
        }
      }
    }
  }

  Future<void> _switchAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.auth.signOut();
    }
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const IntroScreen()),
        (route) => false,
      );
    }
  }

  String _getMaskedContact() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    String phone = metadata['phone'] as String? ?? '';
    String email = widget.email ?? user?.email ?? '';

    if (phone.isNotEmpty && phone.length >= 10) {
      // e.g., 09171234567 -> 09 17 *** 4567
      String first4 = phone.substring(0, 4); // 0917
      String last4 = phone.substring(phone.length - 4); // 4567
      return '${first4.substring(0, 2)} ${first4.substring(2, 4)} *** $last4';
    } else if (email.isNotEmpty && email.contains('@')) {
      final parts = email.split('@');
      if (parts[0].length > 3) {
        return '${parts[0].substring(0, 3)}***@${parts[1]}';
      }
      return email;
    }
    return 'Unknown Account';
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final firstName = widget.name ?? user?.userMetadata?['first_name'] as String? ?? 'User';

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // Prevents banner from moving up when keyboard shows
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  
                  // Logo
                  Image.asset(
                    'assets/logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 48),
                  
                  // Welcome Text
                  Text(
                    'Welcome back, $firstName',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your 6-digit passcode',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Enter MPIN Label & Clear Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Enter your MPIN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _mpinController.clear();
                          setState(() => _errorMessage = null);
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // MPIN Input Boxes
                  GestureDetector(
                    behavior: HitTestBehavior.opaque, // Makes the empty spaces between boxes clickable!
                    onTap: () {
                      _mpinFocusNode.unfocus();
                      Future.delayed(const Duration(milliseconds: 50), () {
                        _mpinFocusNode.requestFocus();
                      });
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Hidden TextField
                        Opacity(
                          opacity: 0.0,
                          child: TextField(
                            controller: _mpinController,
                            focusNode: _mpinFocusNode,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            autofocus: true,
                            enabled: !_isLoading,
                          ),
                        ),
                        // Visual PIN boxes
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            String digit = '';
                            if (mpin.length > index) {
                              digit = mpin[index];
                            }
                            bool isFocused = index == mpin.length || (mpin.length == 6 && index == 5);
                            bool hasError = _errorMessage != null;
                            
                            return Container(
                              width: 48,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: hasError 
                                      ? Colors.red.shade400 
                                      : (isFocused && _mpinFocusNode.hasFocus)
                                          ? Colors.blue.shade400
                                          : Colors.grey.shade300,
                                  width: (isFocused && _mpinFocusNode.hasFocus) ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: digit.isNotEmpty
                                  ? Text(
                                      index == mpin.length - 1 && !_isLoading ? digit : '•',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    )
                                  : null,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  
                  // Error Message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  if (_isLoading) ...[
                    const SizedBox(height: 24),
                    const CustomSvgLoader(),
                  ],

                  const SizedBox(height: 32),

                  // Forgot MPIN
                  TextButton(
                    onPressed: () {
                      // TBD: Forgot MPIN logic
                    },
                    child: Text(
                      'Forgot MPIN?',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),


                  const SizedBox(height: 32),
                  
                  // Masked Contact & Switch Account
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getMaskedContact(),
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Not you? ',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      GestureDetector(
                        onTap: _switchAccount,
                        child: Text(
                          'Switch Account.',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  
                  // Space for bottom
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          ),
          
          // Background graphic anchored to absolute bottom without overlapping
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.0), // Fully transparent at the very top
                  Colors.white, // Fully opaque slightly below the top
                ],
                stops: const [0.0, 0.25], // Fades out in the top 25% of the image
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: Image.asset(
              'assets/mnip.png',
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}
