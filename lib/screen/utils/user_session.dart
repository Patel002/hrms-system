import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String,dynamic>?> getUserDataPacket() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? dataPacket = prefs.getString('data_packet');
    if (dataPacket == null || dataPacket.isEmpty) return null;
    try {
      return jsonDecode(dataPacket);
    } catch (_) {
      return null;
    }
  }

  static Future<T?> getField<T>(String key) async {
    final data = await getUserDataPacket();
    return data?[key] as T?;
  }

  static Future<String?> getUserId() async => getField<String>('user_id');

  static Future<String?> getRole() async => getField<String>('em_role');

  static Future<String?> getCompId() async => getField<String>('comp_id');

  static Future<String?> getUserName() async => getField<String>('name');

  static Future<String?> getUserImageUrl() async => getField<String>('image_url');



  static Future<void> logout(BuildContext context) async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  static Future<void> checkInvalidAuthToken(BuildContext context, dynamic responseBody, int statusCode) async{
    try {

      if(statusCode == 401 && responseBody is Map<String, dynamic> && responseBody['message'] == "Invalid Auth Token"){
        await logout(context);
      }
      
    } catch (e) {
      debugPrint('Token check error: $e');
    }
  }
}