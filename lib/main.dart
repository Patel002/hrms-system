import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:safe_device/safe_device.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'screen/settings/setting_screen.dart';
import 'screen/utils/keyboard_dismiss.dart';
import 'dart:async';

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
  runApp(const RootApp());
}

class RootApp extends StatefulWidget {
  const RootApp({super.key});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> {
  bool _isDeveloperMode = false;
  bool _checked = false;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _checkSafety();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkSafety();
    });
  }

  Future<void> _checkSafety() async {
    bool devMode = false;
    try {
      devMode = await SafeDevice.isDevelopmentModeEnable;
    } on PlatformException {
      devMode = false;
    }

    if (mounted) {
      setState(() {
        _isDeveloperMode = devMode;
        _checked = true;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_isDeveloperMode) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 90, color: Colors.red),
                  SizedBox(height: 20),
                  Text(
                    "Access Denied",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 14),
                  Text(
                    "Developer Mode is enabled on this device.\n"
                    "Please disable Developer Options to continue.",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return const MyApp();
  }
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}


class _MyAppState extends State<MyApp> {

  ThemeMode _themeMode = ThemeMode.system;

  Future<void> _saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString("themeMode", mode.toString());
}

Future<ThemeMode> _loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getString("themeMode");

  switch (value) {
    case "ThemeMode.light":
      return ThemeMode.light;
    case "ThemeMode.dark":
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}


  @override
  void initState() {
    super.initState();
    _loadThemeMode().then((mode) {
      setState(() {
        _themeMode = mode;
      });
    });
  }

  void _changeTheme(ThemeMode? mode) {
  if (mode != null) {
    setState(() {
      _themeMode = mode;
    });
    _saveThemeMode(mode);
  }
}

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
        // themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: true,
        title: 'HuCap',
        initialRoute: '/',
        themeMode: _themeMode, 
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
          '/settings': (context) => SettingScreen(
                      themeMode: _themeMode,
                      onThemeChanged: _changeTheme,
                    ),
             },
           );
          },
        ),
      ),
    );
  }
}
