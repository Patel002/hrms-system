import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screen/splash_screen.dart';
import 'screen/login_screen.dart';
import 'screen/home_screen.dart';
import 'screen/leave/leave_application.dart';
import 'screen/leave/leave_request.dart';
import 'screen/leave/leave_history_screen.dart';
import 'screen/holiday_screen.dart';
import 'screen/leave/leave_balance.dart';
import 'screen/attendance/attendance_in_screen.dart';
import 'screen/attendance/attendance_history_screen.dart';
import 'screen/attendance/attendance_out_screen.dart';
import 'screen/getpass/odpass_screen.dart';
import 'screen/getpass/odpass_history_screen.dart';
import 'screen/timeMachine/attendance_report_screen.dart';
import 'screen/user/user_info_screen.dart';
import 'screen/pay/payslip_screen.dart';
import 'screen/getpass/odPass_request_screen.dart';
import 'screen/visit entry/visit_apply_screen.dart';
import 'screen/visit entry/visit_history_screen.dart';
import 'screen/expense/expense_apply_screen.dart';
import 'screen/expense/expense_history_screen.dart';
import 'screen/expense/expense_request_screen.dart';
import 'screen/utils/keyboard_dismiss.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

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
  await Future.delayed(Duration(seconds: 2));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return KeyboardVisibilityProvider( 
      child: GlobalKeyboardDismiss(   
    child: ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,

      builder: (context, child) {
        
      return MaterialApp(
        theme: ThemeData(
            brightness: Brightness.light,
            textTheme: GoogleFonts.openSansTextTheme(),
            primarySwatch: Colors.indigo,
            scaffoldBackgroundColor: Colors.white,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            textTheme: GoogleFonts.openSansTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme,
            ),
            primarySwatch: Colors.indigo,
            scaffoldBackgroundColor: Colors.black,
          ),
        themeMode: ThemeMode.system,
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
          '/od-request': (context) => const ODPassRequest(),
          '/attendance-record': (context) => const AttendanceReportPage(),
          '/profile': (context) => const UserInfo(),
          '/payslips': (context) => const PayslipScreen(),
          '/visit-entry-apply': (context) => const VisitEntryScreen(),
          '/visit-entry-history': (context) => const VisitHistory(),
          '/apply-expense': (context) => const ExpenseApplyScreen(), 
          '/expense-history': (context) => const ExpenseHistoryScreen(),
          '/expense-request': (context) => const ExpenseRequestScreen(),
        },
      );
      },
    ),
      ),
    );
  }
}
