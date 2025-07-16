import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screen/splash_screen.dart';
import 'screen/login_screen.dart';
import 'screen/home_screen.dart';
import 'screen/leave/leave_application.dart';
import 'screen/leave/leave_request.dart';
import 'screen/leave/leave_status_screen.dart';
import 'screen/holiday_screen.dart';
import 'screen/leave/leave_balance.dart';
import 'screen/attendance/attendance_in_screen.dart';
import 'screen/attendance/attendance_history_screen.dart';
import 'screen/attendance/attendance_out_screen.dart';
import 'screen/getPass/odPass_screen.dart';
import 'screen/getPass/odPass_history_screen.dart';
import 'screen/timeMachine/attendance_report_screen.dart';
import 'screen/userInfo/user_info_screen.dart';
import 'screen/pay/payslip_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,

      builder: (context, child) {
        
      return MaterialApp(
        debugShowCheckedModeBanner: true,
        title: 'HuCap',
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomePage(),
          '/holiday': (context) => const HolidayScreen(),
          '/leave': (context) => const LeaveApplicationPage(),
          '/leave-status': (context) => LeaveStatusPage(),
          '/leave-request': (context) => LeaveRequestPage(),
          '/leave-balance': (context) => LeaveBalancePage(),
          '/attendance-in': (context) => const AttendanceScreenIN(),
          '/attendance-out': (context) => const AttendanceScreenOut(),
          '/attendance-history': (context) => const AttandanceHistory(),
          '/od-pass': (context) => const ODPassScreen(),
          '/od-history': (context) => const OdHistory(),
          '/attendance-record': (context) => const AttendanceReportPage(),
          '/user-info': (context) => const UserInfo(),
          '/payslips': (context) => const PayslipScreen(),
        },
      );
      },
    );
  }
}
