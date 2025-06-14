import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserSession {
  static const String _userKey = 'current_user';

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString(_userKey);
    if (userString != null) {
      return jsonDecode(userString);
    }
    return null;
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  static Future<bool> isLoggedIn() async {
    final user = await getUser();
    return user != null;
  }

  static Future<String?> getUserRole() async {
    final user = await getUser();
    return user?['role'];
  }

  static Future<int?> getUserId() async {
    final user = await getUser();
    return user?['id'];
  }

  static Future<String?> getUserName() async {
    final user = await getUser();
    return user?['full_name'];
  }

  static Future<String?> getUsername() async {
    final user = await getUser();
    return user?['username'];
  }

  static Future<String?> getUserEmail() async {
    final user = await getUser();
    return user?['email'];
  }

  static Future<String?> getUserPhone() async {
    final user = await getUser();
    return user?['phone'];
  }
}