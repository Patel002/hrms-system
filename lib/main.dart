import 'package:flutter/material.dart';
import 'screen/splash_screen.dart';
import 'screen/login_screen.dart';
import 'screen/home_screen.dart';
import 'screen/leave/leave_application.dart';
import 'screen/leave/leave_request.dart';
import 'screen/leave/leave_status_screen.dart';
import 'screen/holiday_screen.dart';
import 'screen/leave/leave_balance.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
      ),
      routes: {
        '/': (context) => const ModernAnimatedSplash(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomePage(),
        '/holiday': (context) => const HolidayScreen(),
        '/leave': (context) => const LeaveApplicationPage(),
        '/leave-status': (context) => LeaveStatusPage(),
        '/leave-request': (context) => LeaveRequestPage(),
        '/leave-balance': (context) => LeaveBalancePage(),
      },

    );
  }
}
