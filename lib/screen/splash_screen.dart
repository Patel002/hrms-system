import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token != null && token.isNotEmpty) {
    bool isExpired = Jwt.isExpired(token);
    if (!isExpired) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }
  }

  Navigator.pushReplacementNamed(context, '/login');
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
