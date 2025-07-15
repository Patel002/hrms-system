import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;  
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar.dart';
import 'package:curved_labeled_navigation_bar/curved_navigation_bar_item.dart';
import 'widgets/attendance_summary_screen.dart';
import 'attendance/attendance_in_screen.dart';
import 'attendance/attendance_out_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  final baseUrl = dotenv.env['API_BASE_URL'];

  String? userRole;
  String? username,profileImage;
  String? empId; 
  String? _expandedTile;
  DateTime? selectedDate;
  int? totalWorkingDays = 0;
  int? presentDays = 0;
  int? leaveDays = 0;
  int? absentDays = 0;
  bool isDataLoaded = false;
  bool isDateProcessing = false;
  bool isSupervisor = false;
  bool _isNavigating = false;
  bool isLoading = false;
  int _currentIndex = 2;

  Map<DateTime, List<Map<String, dynamic>>> leaveDurations = {};

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  late final Widget attendanceInPage;
  late final Widget attendanceOutPage;

  final ValueNotifier<String> profileImageNotifier = ValueNotifier<String>('');
  Map<DateTime, List<String>> punchDurations = {};
  
  
   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  @override
void initState() {
  super.initState();
  loadUserPermissions();
  attendanceInPage = const AttendanceScreenIN();
  attendanceOutPage = const AttendanceScreenOut();
}

   String formatDuration(String rawDuration) {
  try {
    final parts = rawDuration.split(' ');
    final hours = int.parse(parts[0].replaceAll('h', ''));
    final rawMinutes = double.parse(parts[1].replaceAll('m', ''));
    final minutes = rawMinutes.round();

    if (hours == 0 && minutes == 0) return '0 m';
    if (hours == 0) return '$minutes m';
    if (minutes == 0) return '$hours h';
    return '$hours : $minutes h';
  } catch (e) {
    return rawDuration; 
  }
}


Future<void> loadUserPermissions() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token != null) {
    final decoded = Jwt.parseJwt(token);
    setState(() {
      userRole = decoded['em_role']; 
      username = decoded['em_username'];
      empId = decoded['em_id'];
      print('Employee Id, $empId');
      isSupervisor = decoded['isSupervisor'] == true;
    });
    
    await Future.wait([
    fetchLeaveDurations(),
    fetchPunchDurations(),
    fetchProfileImage(),
    fetchAttendanceSummary(selectedMonth, selectedYear),
  ]);

    setState(() {
      isDataLoaded = true;    
    });
  }
}

Future<void> fetchProfileImage() async {
  try{
    final response = await http.get(Uri.parse('$baseUrl/api/employee/info/$empId'),
        headers: {
          'Content-Type': 'application/json',
        });

        debugPrint('Response Status: ${response.body}');

        if(response.statusCode == 201) {
        final finalData = json.decode(response.body);
        final data = finalData['data']; 

        profileImageNotifier.value = data['em_image'] ?? '';        

        debugPrint('Profile Image: $profileImage');
      }

  }catch(e) {
    showAboutDialog(context: context, children: [Text('$e')]);
    setState(() {
    isLoading = false;
    });

  }
}

Future<void> fetchLeaveDurations() async {
  try {
    final response = await http.get(Uri.parse('$baseUrl/api/emp-leave/all-calendar-leaves?em_id=$empId&status=Approve'));

     if (response.statusCode == 200) {
      final result = json.decode(response.body);
      debugPrint('Leave Durations Response: $result');
      final Map<String, dynamic> data = result['calendarLeaves'];

      print('Leave Durations: $data');

      Map<DateTime, List<Map<String, dynamic>>> tempLeaves = {};

      data.forEach((dateString, leaveList) {
        DateTime date = DateTime.parse(dateString);
        tempLeaves[date] = List<Map<String, dynamic>>.from(leaveList);
      });

      setState(() {
        leaveDurations = tempLeaves;
      });
    }
  }
  catch (e) {
    print('Error fetching leave durations: $e');
  }
}

  Future<void> fetchPunchDurations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/attendance/day-duration/$empId'));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final List data = result['data'];

        print('Punch Durations: $data');

        Map<DateTime, List<String>> tempDurations = {};
       
        for (var item in data) {
          DateTime date = DateTime.parse(item['punch_in']);
          String duration = item['duration'];

          print('Date: $date, Duration: $duration');

          DateTime key = DateTime(date.year, date.month, date.day);

          print('Key: $key');

          if (tempDurations.containsKey(key)) {
            tempDurations[key]!.add(duration);
          } else {
            tempDurations[key] = [duration];
          }
        }

        setState(() {
          punchDurations = tempDurations;
        });
      }
    } catch (e) {
      print('Error fetching punch durations: $e');
    }
  }

  Future<void> fetchAttendanceSummary(int month, int year) async {

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/attendance/summary/$empId?month=${month.toString().padLeft(2, '0')}&year=$year'));


      print("month & year, $month & $year, $empId");
      print("response,$response");
      print('Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        final Map<String, dynamic> summary = result['data'];
        print('Summary: $summary'); 
       
      setState(() {
      totalWorkingDays = summary['totalWorkingDays'];
      presentDays = summary['present'];
      leaveDays = summary['approvedLeave'];
      absentDays = summary['absent'];
    });
          }
    } catch (e) {
      print('Error fetching punch durations: $e');
    }
  }

  Future<void> _refreshPage() async {

    setState(() {
      isLoading = true;
    });
    
    await Future.wait([
      fetchLeaveDurations(),
      fetchPunchDurations(),
      fetchAttendanceSummary(selectedMonth, selectedYear)
    ]);
    
    // setState(() {
    //   isLoading = false;
    // });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }


int calculateTotalMinutes(List<String> durations) {
  int totalMinutes = 0;

  for (var duration in durations) {
    final hourMatch = RegExp(r'(\d+)h').firstMatch(duration);
    final minMatch = RegExp(r'([\d.]+)m').firstMatch(duration);

    if (hourMatch != null) {
      totalMinutes += int.parse(hourMatch.group(1)!) * 60;
    }

    if (minMatch != null) {
      totalMinutes += double.parse(minMatch.group(1)!).round();
    }
  }

  return totalMinutes;
}

  void _showHalfDayOptions(BuildContext context, DateTime day, DateTime dayKey) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    backgroundColor: Colors.white,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(5))),
            
            const SizedBox(height: 16),

            Text('Select Option for', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            
            Text('${day.day}/${day.month}/${day.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 20),
 
            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.blueAccent),
              title: const Text('View Attendance', style: TextStyle(fontSize: 16)),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.pushNamed(context, '/attendance-history', arguments: {'selectedDate': day});
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: Colors.green),
              title: const Text('View Leave', style: TextStyle(fontSize: 16)),
              onTap: () async {
               Navigator.pop(context);
               await  Navigator.pushNamed(context, '/leave-status', arguments: {
                  'selectedDate': dayKey,
                  'leavesTypeId': leaveDurations[dayKey]![0]['leaveTypeId'],
                  'tabIndex': 1,
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.redAccent),
              title: const Text('Close', style: TextStyle(fontSize: 16)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      );
    },
  );
}


@override
Widget build(BuildContext context) {
  return Scaffold(
    key: _scaffoldKey,
    extendBody: true,
    backgroundColor: const Color(0xFFF5F7FA),
    appBar: AppBar(
       backgroundColor: Colors.transparent,
    title: const Text(
      "Dashboard",
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    automaticallyImplyLeading: false,
    forceMaterialTransparency: true,
    actions: [
      IconButton(
        icon: const Icon(Icons.logout, color: Colors.black87),
        onPressed: _logout,
        tooltip: 'Logout',
      ),
    ],
          ),

    drawer: buildDrawer(),
    body: Stack(
    children: [
    RefreshIndicator(
      onRefresh: _refreshPage,
      backgroundColor: Colors.white,
      color: Colors.black87,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: !isDataLoaded ?
          MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top
          :null,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: !isDataLoaded
              ? Shimmer.fromColors(
                  baseColor: Colors.grey[300]!,
                  highlightColor: Colors.grey[100]!,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Shimmerr AttendanceSummaryWidget
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Shimmer for calendar or other content
                        GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 42,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        },
              ),
                      ],
                    ),
                  ),
                )
          :  Padding(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      kToolbarHeight - MediaQuery.of(context).padding.top,
                ),
            child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AttendanceSummaryWidget(
                  workingHours: totalWorkingDays.toString(), 
                  presentDays: presentDays ?? 0,        
                  leaveDays: leaveDays ?? 0,            
                  absentDays: absentDays ?? 0,    
                ),
                const SizedBox(height: 20),
                buildCalendar(),
            ],
          ),
        ),
      ),
    ),
  ),
 ),
),
    
  if (isDateProcessing)
  Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.3),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
        ),
      ),
    ),
  ),
    ],
  ),


  bottomNavigationBar: SafeArea(
  maintainBottomViewPadding: true,
  child: CurvedNavigationBar(
  backgroundColor: Colors.transparent,
  color: Colors.white,
  buttonBackgroundColor: Colors.tealAccent.withOpacity(0.3),
  height: 65,
  index: _currentIndex,
  animationCurve: Curves.easeInOutQuad,
  animationDuration: const Duration(milliseconds: 490),
  onTap: (index) async{
    if(_isNavigating) return;

  if (index == 0) {
    _scaffoldKey.currentState?.openDrawer();
    return;
  }
  
  _isNavigating = true;

try{
  switch (index) {
    case 1:
    await Future.delayed(const Duration(milliseconds: 490));  
      await Navigator.push(context, MaterialPageRoute(builder: (_) => attendanceInPage));
  break;

    case 2:
    if (ModalRoute.of(context)?.settings.name != '/home') {
    Navigator.pushNamed(context, '/home');
      }
      break;

    case 3:
    Future.delayed(const Duration(milliseconds: 490), () async {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => attendanceOutPage));

    });
      break;

    case 4:
    Future.delayed(const Duration(milliseconds: 490), () async{
    await Navigator.pushNamed(context, '/user-info');
    });
      break;

    default:
      setState(() => _currentIndex = index);
  }
} finally{
      _isNavigating = false;
}
},

  items: [
    
   CurvedNavigationBarItem(
    child: Icon(Icons.menu_rounded, color:Colors.black87  ),
    label: "Menu",
    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color:  Colors.black87),
  ),

  CurvedNavigationBarItem(
    child: Icon(Icons.punch_clock_outlined, color: Colors.black87),
    label: "In",
    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color:  Colors.black87),
  ),

CurvedNavigationBarItem(
    child: Icon(Icons.home_outlined, color: Colors.black87),
    label: "Home",
    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
  ),
  

  CurvedNavigationBarItem(
    child: Icon(Icons.lock_clock_outlined, color:Colors.black87),
    label: "Out",
    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
  ),

  CurvedNavigationBarItem(
    child: ValueListenableBuilder<String>(
      valueListenable: profileImageNotifier,
      builder: (context, value, _) {
        return CircleAvatar(
          radius: 14,
          backgroundImage: value.isNotEmpty
              ? NetworkImage('$baseUrl/api/employee/attachment/$value')
              : const AssetImage('assets/icon/face-id.png') as ImageProvider,
        );
      },
    ),
    label: "Profile",
    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color:  Colors.black87),
  ),

],
),
  ),
  );
}


Widget buildCalendar() {
  final today = DateTime.now();
  final List<Appointment> appointments = [];

  punchDurations.forEach((date, durations) {
    final totalMinutes = calculateTotalMinutes(durations);
    appointments.add(
      Appointment(
        startTime: date,
        endTime: date.add(Duration(minutes: totalMinutes)),
        subject: 'Punch: ${formatDuration('${(totalMinutes ~/ 60)}h ${(totalMinutes % 60)}m')}',
        color: Colors.green.shade300,
      ),
    );
  });


leaveDurations.forEach((date, leaves) {
    for (var leave in leaves) {
      appointments.add(
        Appointment(
          startTime: date,
          endTime: date,
          subject: leave['isHalfDay'] == true ? 'Half Day Leave' : 'Leave',
          color: leave['isHalfDay'] == true ? Colors.orangeAccent : Colors.redAccent,
        ),
      );
    }
  });

   final calendarDataSource = _InlineAppointmentDataSource(appointments);

  return SafeArea(
    child: Column(
    children: [
     SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.45,
      child: SfCalendar(
        view: CalendarView.month,
        initialDisplayDate: today,
        initialSelectedDate: today,
        showNavigationArrow: true,
          onViewChanged: (ViewChangedDetails details) {
          final DateTime currentMonthDate = details.visibleDates[details.visibleDates.length ~/ 2];

          final int newMonth = currentMonthDate.month;
          final int newYear = currentMonthDate.year;

          if (newMonth != selectedMonth || newYear != selectedYear) {
            setState(() {
              selectedMonth = newMonth;
              selectedYear = newYear;
            });
            fetchAttendanceSummary(newMonth, newYear);
          }
        },

        dataSource: calendarDataSource as CalendarDataSource,
            headerStyle: CalendarHeaderStyle(
            textAlign: TextAlign.center,
            backgroundColor:  Color(0xFFF5F7FA),
            textStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          viewHeaderStyle: ViewHeaderStyle(
            backgroundColor: const Color.fromRGBO(224, 242, 241, 1),
            dayTextStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        monthViewSettings: MonthViewSettings(
        showAgenda: false,
        appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
        numberOfWeeksInView: 6,
        dayFormat: 'EEE',
        monthCellStyle: MonthCellStyle(
          textStyle: const TextStyle(fontSize: 11, color: Colors.black87),
          trailingDatesTextStyle: TextStyle(color: Colors.grey.shade400, fontSize: 10),
          leadingDatesTextStyle: TextStyle(color: Colors.grey.shade400, fontSize: 10),
        ),
      ),

        onTap: (CalendarTapDetails details) async {
          if (details.targetElement == CalendarElement.calendarCell && details.date != null) {
            final DateTime tappedDate = details.date!;
            final DateTime dayKey = DateTime(tappedDate.year, tappedDate.month, tappedDate.day);

            final isPresent = punchDurations.containsKey(dayKey);
            final isLeave = leaveDurations.containsKey(dayKey);
            final totalMinutes = isPresent ? calculateTotalMinutes(punchDurations[dayKey]!) : 0;

            final isHalfDayAttendance = isPresent && totalMinutes < 270;
            final isHalfDayLeave = isLeave && leaveDurations[dayKey]!.any((leave) => leave['isHalfDay'] == true);
            
            final isSplitDay = isPresent && isLeave;

            final isFullLeave = isLeave && !isSplitDay && (!isPresent || (isHalfDayLeave && !isHalfDayAttendance));

            
            final isFullAttendance = isPresent && !isSplitDay && (!isLeave || (isHalfDayAttendance && !isHalfDayLeave));


            // final isFuture = tappedDate.isAfter(today);

            final isAbsent = !isPresent && !isLeave;

            if (isAbsent) {
            final isFuture = tappedDate.isAfter(today);
            final message = isFuture
            ? 'No future attendance or leave data found.'
            : 'No attendance or leave data available.';
            _showCustomSnackBar(
              context,
              message,
              Colors.orange,
              Icons.warning_amber_outlined,
            );
            return;
          }

            setState(() {
              isDateProcessing = true;
            });

            try {
              if (isSplitDay) {
                _showHalfDayOptions(context, tappedDate, dayKey);
              } else if (isFullLeave && leaveDurations[dayKey]!.isNotEmpty) {
                await Navigator.pushNamed(
                  context,
                  '/leave-status',
                  arguments: {
                    'selectedDate': tappedDate,
                    'leavesTypeId': leaveDurations[dayKey]![0]['leaveTypeId'],
                    'tabIndex': 1,
                  },
                );
              } else if (isFullAttendance) {
                await Navigator.pushNamed(
                  context,
                  '/attendance-history',
                  arguments: {'selectedDate': tappedDate},
                );
              }
            } catch (e) {
              _showCustomSnackBar(context, 'Something went wrong.', Colors.red, Icons.error_outline);
            } finally {
              if (mounted) {
                setState(() {
                  isDateProcessing = false;
               });
                }
              }
            }
          },
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            buildLegendItem(Colors.green.shade300, 'Present'),
            buildLegendItem(Colors.orangeAccent, 'Half Day'),
            buildLegendItem(Colors.redAccent, 'Leave'),
          ],
        ),
      ),
    ],
  ),
);
}

Widget buildLegendItem(Color color, String label) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 12),
      ),
    ],
  );
}


void _showCustomSnackBar(BuildContext context, String message, Color color, IconData icon) {

  final ScaffoldMessengerState scaffoldMessenger = ScaffoldMessenger.of(context);

  scaffoldMessenger.clearSnackBars();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
      Widget buildDrawer() {
      return Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
              child: Row(
                children: [
                ValueListenableBuilder<String>(
                valueListenable: profileImageNotifier,
                builder: (context, value, _) {
                   return CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(
                      '$baseUrl/api/employee/attachment/$value', 
                    ),
                  );
                },
              ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                           Text(
                            '$username',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              // decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              

          Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
           child: ExpansionTile(
              key: Key('Leave_${_expandedTile == 'Leave'}'),
              title: const Text('Leave',
              style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.calendar_month_outlined), 
              initiallyExpanded: _expandedTile == 'Leave',
              onExpansionChanged: (expanded) {
                setState(() => _expandedTile = expanded ? 'Leave' : null);
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 8), 
              children: [
                 ListTile(
                  title: const Text('Holiday'),
                  onTap: () => Navigator.pushNamed(context, '/holiday'),
                ),
                ListTile(
                  title: const Text('Leave Application'),
                  onTap: () => Navigator.pushNamed(context, '/leave'),
                ),
                ListTile(
                  title: const Text('Leave Status'),
                  onTap: () => Navigator.pushNamed(context, '/leave-status'),
                ),
                ListTile(
                  title: const Text('Leave Balance'),
                  onTap: () => Navigator.pushNamed(context, '/leave-balance'),
                ),
                if (userRole == 'SUPER ADMIN' || isSupervisor)
                ListTile(
                  title: const Text('Leave Request'),
                  onTap: () => Navigator.pushNamed(context, '/leave-request'),
                ),
              ],
            ),
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
            child: ExpansionTile(
              key: Key('Attendance_${_expandedTile == 'Attendance'}'),
              title: const Text('Attendance',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.rocket_launch_outlined),
              initiallyExpanded: _expandedTile == 'Attendance',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'Attendance' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
              children: [
                ListTile(
                  title: const Text('Attendance In'),
                  onTap: () => Navigator.pushNamed(context, '/attendance-in'),
                ),
                ListTile(
                  title: const Text('Attendance Out'),
                  onTap: () => Navigator.pushNamed(context, '/attendance-out'),
                ),
                ListTile(
                  title: const Text('Attendance History'),
                  onTap: () => Navigator.pushNamed(context, '/attendance-history',
                  ),
                ),    
              ],
            ),
          ),

            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
            child: ExpansionTile(
              key: Key('GatePass_${_expandedTile == 'Gate Pass'}'),
              title: const Text('Gate Pass',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.door_back_door),
              initiallyExpanded: _expandedTile == 'Gate Pass',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'Gate Pass' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
              children: [
                ListTile(
                  title: const Text('Apply OD'),
                  onTap: () => Navigator.pushNamed(context, '/od-pass'),
                ),
                ListTile(
                  title: const Text('OD History'),
                  onTap: () => Navigator.pushNamed(context, '/od-history'),
                ),
              ]
             )
            ),

            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
            child: ExpansionTile(
              key: Key('Time Machine${_expandedTile == 'Time Machine'}'),
              title: const Text('Time Machine',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.access_time),
              initiallyExpanded: _expandedTile == 'Time Machine',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'Time Machine' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
              children: [
                ListTile(
                  title: const Text('Attendance Record'),
                  onTap: () => Navigator.pushNamed(context, '/attendance-record'),
               ),
              ],
             ),
            ),

            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
            child: ExpansionTile(
              key: Key('Payroll${_expandedTile == 'Payroll'}'),
              title: const Text('Payroll',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.currency_rupee),
              initiallyExpanded: _expandedTile == 'Payroll',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'Payroll' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
              children: [
                ListTile(
                  title: const Text('Payslips'),
                  onTap: () => Navigator.pushNamed(context, '/payslips'),
               ),
              ],
             ),
            ),
           ],
          ),
         ),
        ),
       );
      }
     }
  
  class _InlineAppointmentDataSource extends CalendarDataSource {  
  _InlineAppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}
