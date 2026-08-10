import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_account.dart';

class AccountManager {
  static const String _key = 'saved_accounts';

  // Get all saved accounts
  static Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? accountsJson = prefs.getString(_key);
    
    if (accountsJson == null || accountsJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decodedList = jsonDecode(accountsJson);
      return decodedList.map((item) => SavedAccount.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  // Save an account (adds new or updates existing based on ID)
  static Future<void> saveAccount(SavedAccount newAccount) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();
    
    // Remove if already exists to update it and move to front
    accounts.removeWhere((acc) => acc.id == newAccount.id || acc.email == newAccount.email);
    
    // Add to top of list
    accounts.insert(0, newAccount);
    
    // Convert to JSON and save
    final List<Map<String, dynamic>> jsonList = accounts.map((acc) => acc.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  // Remove an account
  static Future<void> removeAccount(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();
    
    accounts.removeWhere((acc) => acc.id == id);
    
    final List<Map<String, dynamic>> jsonList = accounts.map((acc) => acc.toJson()).toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }
}
