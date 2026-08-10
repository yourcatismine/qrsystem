import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_account.dart';
import '../utils/account_manager.dart';
import '../screens/login_screen.dart';
import '../screens/mpin_lock_screen.dart';

class AccountSwitcherBottomSheet extends StatefulWidget {
  const AccountSwitcherBottomSheet({super.key});

  @override
  State<AccountSwitcherBottomSheet> createState() => _AccountSwitcherBottomSheetState();
}

class _AccountSwitcherBottomSheetState extends State<AccountSwitcherBottomSheet> {
  List<SavedAccount> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final accounts = await AccountManager.getSavedAccounts();
    if (mounted) {
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    }
  }

  void _onAccountSelected(SavedAccount account) async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser?.email == account.email) {
      // Already logged into this account
      Navigator.pop(context); // Close bottom sheet
      return;
    }

    // Log out current user if any
    if (currentUser != null) {
      await Supabase.instance.client.auth.signOut();
    }

    // Navigate to MpinLockScreen in "Login Mode"
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MpinLockScreen(
            email: account.email,
            name: account.firstName,
          ),
        ),
        (route) => false,
      );
    }
  }

  void _onAddAccount() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      await Supabase.instance.client.auth.signOut();
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onLogout() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      await Supabase.instance.client.auth.signOut();
    }
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onRemoveAccount(SavedAccount account) async {
    await AccountManager.removeAccount(account.id);
    _loadAccounts(); // Reload list
  }

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = Supabase.instance.client.auth.currentUser?.email;

    return Container(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Switch Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ))
          else if (_accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text("No saved accounts found."),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _accounts.length,
                itemBuilder: (context, index) {
                  final account = _accounts[index];
                  final isCurrent = account.email == currentUserEmail;
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: account.avatarUrl != null ? NetworkImage(account.avatarUrl!) : null,
                      child: account.avatarUrl == null 
                          ? Text(
                              account.firstName.isNotEmpty ? account.firstName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            )
                          : null,
                    ),
                    title: Text(
                      '${account.firstName} ${account.lastName}',
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(account.email),
                    trailing: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: isCurrent
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                                onPressed: () => _onRemoveAccount(account),
                              ),
                      ),
                    ),
                    onTap: isCurrent ? null : () => _onAccountSelected(account),
                  );
                },
              ),
            ),
            
          const Divider(height: 16),
          
          // Add Account Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: _onAddAccount,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade100,
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/add_account.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(Colors.grey.shade800, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Log into another account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Full Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: InkWell(
              onTap: _onLogout,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade50,
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/logout.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(Colors.redAccent, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
