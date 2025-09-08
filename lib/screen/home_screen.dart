import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:http/http.dart' as http;  
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/rendering.dart';
import 'dart:convert';
import '../screen/user/page_swip.dart';
import 'utils/user_session.dart';
import 'widgets/attendance_summary_screen.dart';
import 'attendance/attendance_in_screen.dart';
import 'attendance/attendance_out_screen.dart';
import 'helper/top_snackbar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage>  {
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  String appVersion = '';
  String? userRole;
  String? username,profileImage;
  String? empId; 
  String? image;
  String? _expandedTile;
  DateTime? selectedDate;
  int? totalWorkingDays = 0;
  double presentDays = 0;
  double leaveDays = 0;
  double absentDays = 0;
  bool isDataLoaded = false;
  bool isDateProcessing = false;
  bool isSupervisor = false;
  bool isGatePassAccess = false;
  bool isVisitAccess = false;
  bool _isNavigating = false;
  bool isLoading = false;
  int _currentIndex = 1;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  DateTime? joiningDate;

  DateTime firstOfMonth({required int year, required int month}) => DateTime(year, month, 1);

  DateTime lastOfMonth({required int year, required int month})  => DateTime(year, month + 1, 0);

  late final Widget attendanceInPage;
  late final Widget attendanceOutPage;

  final ValueNotifier<String> profileImageNotifier = ValueNotifier<String>('');
  Map<DateTime, Map<String, dynamic>> punchDurations = {};
  Map<DateTime, List<Map<String, dynamic>>> leaveDurations = {};

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final grey300 = Colors.grey.shade300;

  final ScrollController _scrollController = ScrollController();
  bool _isBottomBarVisible = true;


  @override
void initState() {
  super.initState();
  loadUserPermissions();
  attendanceInPage = const AttendanceScreenIN();
  attendanceOutPage = const AttendanceScreenOut();
  _loadVersion();

  _scrollController.addListener(() {
    final direction = _scrollController.position.userScrollDirection;
    if (direction == ScrollDirection.reverse && _isBottomBarVisible) {
      setState(() => _isBottomBarVisible = false);
    } else if (direction == ScrollDirection.forward && !_isBottomBarVisible) {
      setState(() => _isBottomBarVisible = true);
    }
  });
}


Future<void> _loadVersion() async {
  final info = await PackageInfo.fromPlatform();
  setState(() {
    appVersion = '${info.version}+${info.buildNumber}';
  });
}

//   String formatDuration(String rawDuration) {
//   try {
//     final parts = rawDuration.split(' ');
//     final hours = int.parse(parts[0].replaceAll('h', ''));
//     final minutes = int.parse(parts[1].replaceAll('m', ''));

//     if (hours == 0 && minutes == 0) return '0 m';
//     if (hours == 0) return '$minutes m';
//     if (minutes == 0) return '$hours h';
//     return '$hours : $minutes h';
//   } catch (e) {
//     return rawDuration; 
//   }
// }

  String getTime(String? dateTime) {
    if (dateTime == null || dateTime.isEmpty) return '-';
      final parts = dateTime.split(" ");
    if (parts.length >= 3) {
      return "${parts[1]} ${parts[2]}"; 
    }
    return dateTime;
    }


Future<void> loadUserPermissions() async {
  final token = await UserSession.getToken();

   if (token == null) {
    Navigator.pushReplacementNamed(context, '/login');
    return;
   }

  final role = await UserSession.getRole();
  final name = await UserSession.getUserName();
  final emId = await UserSession.getUserId();
  final imageUrl = await UserSession.getUserImageUrl();
  final supervisor = await UserSession.isSupervisor() == 'YES';
  final gatePass = await UserSession.hasGatePassAccess();
  final visit = await UserSession.hasLeaveAccess();

    setState(() {
      userRole = role; 
      username = name;
      empId = emId;
      image = imageUrl;
      isSupervisor = supervisor;
      isGatePassAccess = gatePass;
      isVisitAccess = visit;
      // print('image url, $image');
      // print('Employee Id, $empId');
      // print('Is Supervisor: $isSupervisor');
      // print('Gate Pass Access: $isGatePassAccess');
      // print('Visit Access: $isVisitAccess');
    });
    
    
  //  await fetchLeaveDurations();

    await fetchPunchDurations(
    fromDate: firstOfMonth(year: selectedYear, month: selectedMonth),
    toDate: getToDate(selectedYear, selectedMonth));

  //  await fetchAttendanceSummary(fromDate: firstOfMonth(year: selectedYear, month: selectedMonth),toDate:lastOfMonth(year: selectedYear, month: selectedMonth));
  
    setState(() {
      isDataLoaded = true;    
    });
}

String formatWrkhrsToHM(String wrkhrs) {
  wrkhrs = wrkhrs.trim();
  if (wrkhrs.isEmpty) return '0h 0m';

  final parts = wrkhrs.split('.');
  final hours = int.tryParse(parts[0]) ?? 0;
  int minutes = 0;

  if (parts.length > 1) {
    var minStr = parts[1];
    if (minStr.length > 2) minStr = minStr.substring(0, 2);
    if (minStr.length == 1) minStr = '${minStr}0'; 
    minutes = int.tryParse(minStr) ?? 0;
    if (minutes > 59) minutes = 59;
  }
  return '${hours}h ${minutes}m';
}

 DateTime getToDate(int year, int month) {
  DateTime today = DateTime.now();
  if (year == today.year && month == today.month) {
    return today;
  } else {
    return lastOfMonth(year: year, month: month);
  }
}


Future<void> fetchProfileImage() async {
  try{
    final response = await http.get(Uri.parse('$baseUrl/api/employee/info/$empId'),
        headers: {
          'Content-Type': 'application/json',
        });

        debugPrint('Response Status: ${response.body}');

        if(response.statusCode == 200) {
        final finalData = json.decode(response.body);
        final data = finalData['data']; 

        profileImageNotifier.value = data['em_image'] ?? '';        

        // debugPrint('Profile Image: $profileImage');
      }

  }catch(e) {
    showAboutDialog(context: context, children: [Text('$e')]);
    setState(() {
    isLoading = false;
    });

  }
}

// Future<void> fetchLeaveDurations() async {

//   final token = await UserSession.getToken();

//     if(token == null) {
//       Navigator.pushReplacementNamed(context, '/login');
//       return;
//     }
    
//     final empId = await UserSession.getUserId();
//   try {
//     final response = await http.get(Uri.parse('$baseUrl/MyApis/leavetherecords?fetch_type=SELF&leave_status=Approve'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $apiToken',
//           'auth_token': token,
//           'user_id': empId!
//         });

//         debugPrint('Response Status: ${response.statusCode}');

//         await UserSession.checkInvalidAuthToken(context, response.body, response.statusCode);

//     if (response.statusCode == 200) {
//     final result = json.decode(response.body);
    
//     final List data = result['data_packet'];

//     Map<DateTime, List<Map<String, dynamic>>> tempLeaves = {};

//     for (var leave in data) {
//     DateTime startDate = DateTime.parse(leave['start_date']);
//     DateTime endDate = DateTime.parse(leave['end_date']);

//     for (DateTime date = startDate;
//         !date.isAfter(endDate);
//         date = date.add(const Duration(days: 1))) {
//       DateTime key = DateTime(date.year, date.month, date.day);

//       final simplifiedLeave = {
//         'leaveName': leave['leave_type_name'],
//         'leaveTypeId': leave['typeid'],
//         'id': leave['id'],
//         'leave_type': leave['leave_type'],
//       };

//       print('simplifiedLeave: $simplifiedLeave');

//       if (tempLeaves.containsKey(key)) {
//         tempLeaves[key]!.add(simplifiedLeave);
//       } else {
//         tempLeaves[key] = [simplifiedLeave];
//       }
//     }
//   }
//       setState(() {
//         leaveDurations = tempLeaves;
//       });
//     }

//     setState(() {
//       isDataLoaded = true;
//     });

//   } catch (e) {
//     print('Error fetching leave durations: $e');
//   }
// }


Future<void> fetchPunchDurations({required DateTime fromDate, required DateTime toDate}) async {

      final token = await UserSession.getToken();

      if(token == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      
      final empId = await UserSession.getUserId();

      final fromDateStr = DateFormat('yyyy-MM-dd').format(fromDate);

      final toDateStr = DateFormat('yyyy-MM-dd').format(toDate);

      // print('fromDateStr: $fromDateStr, toDateStr: $toDateStr');

      try {

        final url = Uri.parse('$baseUrl/MyApis/attendancetherecords?emp_id=$empId&from_date=$fromDateStr&to_date=$toDateStr');

        // print('URL: $url');

        final response = await http.get(url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiToken',
              'auth_token': token,
              'user_id': empId!
        });

        // debugPrint('Response Status: ${response.statusCode}');

        await UserSession.checkInvalidAuthToken(context, response.body, response.statusCode);

        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final List data = result['data_packet'];
          final userData = result['user_details'];
          final Map<String, dynamic> summary = result['attendance_summary'];

          setState(() {
          joiningDate = userData['em_joining_date'] != null
            ? DateFormat('yyyy-MM-dd').parse(userData['em_joining_date'])
            : null;

          // print('Joining Date: ${joiningDate.runtimeType}');

          totalWorkingDays = int.tryParse(summary['total_days'].toString()) ?? 0;

          presentDays = double.tryParse(summary['total_present_days'].toString()) ?? 0;

          leaveDays = double.tryParse(summary['leaves'].toString()) ?? 0;

          absentDays = double.tryParse(summary['total_absent_days'].toString()) ?? 0;
          });

          Map<DateTime, Map<String, dynamic>> tempDurations = {};
        
          for (var item in data) {
            DateTime date = DateTime.parse(item['date']);
            String duration = formatWrkhrsToHM(item['wrkhrs'].toString());

            String punchin = item['punchin_formatted']?.toString() ?? '';

            int weekoffs = int.tryParse(item['weekoffs'] ?? '0') ?? 0;

            // print('Weekoffs  item: ${item['weekoffs']} (${item['weekoffs'].runtimeType})');

            String punchout = item['punchout_formatted']?.toString() ?? '';

            String presabs = item['presabs']?.toString() ?? '';

            var dayDetails = item['dayDetails'] ?? {};

           if (duration == '0h 0m' &&
            weekoffs == 0 &&
            presabs != 'WO' &&
            presabs != 'A' &&
            presabs != 'FP' &&
            (dayDetails == null || (dayDetails is Map && dayDetails.isEmpty))) {
            continue;
        }

            DateTime key = DateTime(date.year, date.month, date.day);

            // print('Key: $key');

            if (!tempDurations.containsKey(key)) {
            tempDurations[key] = {
              'durations': <String>[],
              'punchin': punchin,
              'punchout': punchout,
              'weekoffs': weekoffs,
              'presabs': presabs,
              'dayDetails': dayDetails,
            };
          }

          tempDurations[key]!['durations'].add(duration);
          tempDurations[key]!['presabs'] = presabs;
          tempDurations[key]!['dayDetails'] = dayDetails;
          tempDurations[key]!['punchin_formatted'] = punchin;
          tempDurations[key]!['punchout_formatted'] = punchout;
          tempDurations[key]!['weekoffs'] = weekoffs;
        }
          if (mounted) {
          setState(() {
            punchDurations = tempDurations;
          });
        }
          // print('Punch Durations: $tempDurations');
        }

        if (mounted) {
        setState(() {
          isDataLoaded = true;
        });
      }

      } catch (e) {
        print('Error fetching punch durations: $e');
      }
    }

    // Future<void> fetchAttendanceSummary({required DateTime fromDate, required DateTime toDate}) async {

    //   final empId = await UserSession.getUserId();
    //   final token = await UserSession.getToken();

    //   // print('empId: $empId, token: $token');

    //   if(token == null) {
    //     Navigator.pushReplacementNamed(context, '/login');
    //     return;
    //   }

    //   final fromDateStr = DateFormat('yyyy-MM-dd').format(fromDate);
    //   final toDateStr = DateFormat('yyyy-MM-dd').format(toDate);

    //   // print('fromDateStr: $fromDateStr, toDateStr: $toDateStr');

    //   try {

    //     final url = Uri.parse('$baseUrl/MyApis/attendancethesummary?emp_id=$empId&from_date=$fromDateStr&to_date=$toDateStr');

    //     print('url:-$url');

    //     final response = await http.get(url,
    //       headers: {
    //           'Content-Type': 'application/json',
    //           'Authorization': 'Bearer $apiToken',
    //           'auth_token': token,
    //           'user_id': empId!
    //     });

    //     // print("month & year,$empId");
    //     // print("response,$response");
    //     // print('Response Status: ${response.statusCode} from summary');

    //     await UserSession.checkInvalidAuthToken(context, response.body, response.statusCode);

    //     if (response.statusCode == 200) {
    //       final result = json.decode(response.body);

    //       final Map<String, dynamic> summary = result['data_packet'];
    //       // print('Summary: $summary'); 
        
    //     setState(() {
    //       totalWorkingDays = int.tryParse(summary['total_days'].toString()) ?? 0;
    //       presentDays = double.tryParse(summary['total_present_days'].toString()) ?? 0;
    //       leaveDays = double.tryParse(summary['leaves'].toString()) ?? 0;
    //       absentDays = double.tryParse(summary['total_absent_days'].toString()) ?? 0;
    //   });
    // }

    // setState(() {
    //     isDataLoaded = true;
    //   });

    //   } catch (e) {
    //     // print('Error summary: $e');
    //   }
    // }

    Future<void> _refreshPage() async {

      setState(() {
        isLoading = true;
      });
      
      await Future.wait([
      // fetchLeaveDurations(),
      
      fetchPunchDurations(
      fromDate: firstOfMonth(year: selectedYear, month: selectedMonth),
      toDate: getToDate(selectedYear, selectedMonth)),

      // fetchAttendanceSummary(fromDate: firstOfMonth(year: selectedYear, month: selectedMonth),toDate:   lastOfMonth(year: selectedYear, month: selectedMonth))

      ]);
      
      setState(() {
        isLoading = false;
      });
    }
    

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }


int calculateTotalMinutes(List<String> durations) {
  int total = 0;
  for (var dur in durations) {
    final parts = dur.split(' ');
    final hours = int.tryParse(parts[0].replaceAll('h', '')) ?? 0;
    final minutes = int.tryParse(parts[1].replaceAll('m', '')) ?? 0;
    total += (hours * 60 + minutes);
  }
  return total;
}

void _showBottomSheet(BuildContext context, DateTime day, DateTime dayKey) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.grey.shade900,
    builder: (context) {
      final attendance = punchDurations[dayKey];
      final dayDetails = attendance?['dayDetails'] ?? {};

      Color _getEventColor(String categoryKey, String type, String duration) {
        switch (categoryKey) {
          case 'HL':
            return Colors.purple.shade200;
          case 'Leaves':
            return duration == 'Half-Day'
                ? Colors.yellow.shade500
                : Colors.orangeAccent.shade100;
          case 'OD':
            return Colors.blueAccent.shade100;
          case 'WO':
            return Colors.grey;
          default:
            return Colors.teal.shade100;
        }
      }

      Color _getEventTextColor(String categoryKey, String duration) {
      switch (categoryKey) {
        case 'HL':
          return Colors.purple.shade500;
        case 'Leaves':
          return duration == 'Half-Day'
                    ? Colors.yellow.shade800
                    : Colors.orangeAccent.shade400;
        case 'OD':
          return Colors.blue.shade700;
        case 'WO':
          return Colors.grey.shade800;
        default:
          return Colors.teal.shade700;
      }
    }

  IconData _getEventIcon(String categoryKey) {
  switch (categoryKey) {
    case 'HL':  
      return Icons.beach_access;
    case 'Leaves':
      return Icons.event_busy;
    case 'OD':   
      return Icons.work;
    case 'WO':  
      return Icons.weekend;
    default:
      return Icons.event_note;
  }
}


String _getEventLabel(String categoryKey) {
  switch (categoryKey) {
    case 'HL':
      return 'Holiday';
    case 'Leaves':
      return 'Leave';
    case 'OD':
      return 'On Duty';
    case 'WO':
      return 'Week Off';
    default:
      return categoryKey;
  }
}


      return Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 16),

              Text('Details for',
                  style: TextStyle(fontSize: 18, color: Theme.of( context) == Brightness.light ? Colors.black87 : Colors.grey[700])),
              Text(
                '${day.day}/${day.month}/${day.year}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              if (attendance != null &&
              (attendance['presabs']?.toString().contains('P') ?? false)) ...[
                Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Attendance:",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).brightness == Brightness.light ? Colors.green.shade100 : Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children :[
                    Padding(padding:  const EdgeInsets.only(left: 12.0, top: 8.0),
                    child: Text(
                      "Present",
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey[800] : Colors.black87,
                       fontSize: 15,
                       fontWeight: FontWeight.bold),
                     ),
                    ),
                   ListTile(
                    leading: const Icon(Icons.access_time, color: Colors.green),
                    subtitle: Text(
                      "Durations: ${attendance['durations']?.join(', ') ?? '-'}\n"
                      // "Pres/Abs: ${attendance['presabs'] ?? '-'}\n"
                      "Check-In: ${getTime(attendance['punchin'])}\n"
                      "Check-Out: ${getTime(attendance['punchout'])}",
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey[700] : Colors.black87),
                    ),
                  ),
                ]
              ),
            ),
          ],
              const SizedBox(height: 8),

              if (dayDetails.isNotEmpty) ...[
               Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Day Details:",
                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

          for (var entry in dayDetails.entries) ...[
            Card(
              color: _getEventColor(
              (entry.key),
              (entry.value as List).isNotEmpty
                  ? (entry.value[0]['type'] ?? entry.key)
                  : entry.key,
              (entry.value as List).isNotEmpty
                  ? (entry.value[0]['duration'] ?? '')
                  : '',
            ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getEventLabel(entry.key),
                       style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey[800] : Colors.black87,
                       fontSize: 15,
                       fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),

                    for (var detail in (entry.value as List)) ...[
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _getEventIcon(entry.key),
                          color: _getEventTextColor(
                          entry.key, 
                          detail['duration'] ?? ''),
                        ),
                        title: Text(
                          detail['type'] ?? '-',
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey[800] : Colors.black87),
                        ),
                        subtitle: Text(
                          "Duration: ${detail['duration'] ?? '-'}",
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.grey[800] : Colors.black87),
                        ),
                      ),
                      // const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
             const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.redAccent),
                title:
                    const Text('Close', style: TextStyle(fontSize: 16)),
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
    resizeToAvoidBottomInset: false,
    key: _scaffoldKey,
    drawer: buildDrawer(),
    extendBody: true,
    backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
    appBar: AppBar(
    backgroundColor: Colors.transparent,
    title: Text(
      "Dashboard",
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
      leading: Padding(
      padding: const EdgeInsets.only(left: 5), 
   child: IconButton(
    icon: CircleAvatar(
      radius: 18,
    backgroundImage: NetworkImage(image ?? ''),
     ),
    onPressed: () {
      _scaffoldKey.currentState?.openDrawer();
    },
  ),
    ),
    automaticallyImplyLeading: false,
    forceMaterialTransparency: true,
    actions: [
      IconButton(
        icon: Icon(Icons.logout, color: Theme.of(context).iconTheme.color),
        onPressed: _logout,
        tooltip: 'Logout',
      ),
    ],
  ),

    body: Column(
    children: [
      Expanded(
      child: RefreshIndicator(
      onRefresh: _refreshPage,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      color: Theme.of(context).iconTheme.color,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: !isDataLoaded ?
          MediaQuery.of(context).size.height - kToolbarHeight - MediaQuery.of(context).padding.top
          :null,
          width: double.infinity,
          decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? const LinearGradient(
                      colors: [Color(0xFF121212), Color(0xFF121212)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : const LinearGradient(
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
                            color: Theme.of(context).cardColor,
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
                              color: Theme.of(context).cardColor,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAttendanceSummary(),
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

  bottomNavigationBar: AnimatedContainer(
  duration: const Duration(milliseconds: 200),
  height: _isBottomBarVisible ? kBottomNavigationBarHeight + 14 : 0,
  child: Wrap(
    children: [
      SafeArea(
        child: Padding(
          padding: EdgeInsets.zero,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 7.0),
            child: GNav(
              selectedIndex: _currentIndex,
              onTabChange: (index) async {
                if (_isNavigating) return;

                setState(() => _currentIndex = index);
                _isNavigating = true;

                try {
                  switch (index) {
                    case 0:
                      await Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 500),
                          pageBuilder: (_, __, ___) => attendanceInPage,
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              )),
                              child: child,
                            );
                          },
                        ),
                      );
                      break;

                    case 1:
                      if (ModalRoute.of(context)?.settings.name != '/home') {
                        await Navigator.pushNamed(context, '/home');
                      }
                      break;

                    case 2:
                      await Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 500),
                          pageBuilder: (_, __, ___) => attendanceOutPage,
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1.0, 0.0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              )),
                              child: child,
                            );
                          },
                        ),
                      );
                      break;
                  }
                  await Future.delayed(const Duration(milliseconds: 100));
                  setState(() => _currentIndex = 1);
                } finally {
                  _isNavigating = false;
                }
              },
              backgroundColor: Colors.transparent,
              haptic: true,
              tabBackgroundColor: Theme.of(context)
              .colorScheme
              .primary
              .withOpacity(0.1), 
              activeColor: Theme.of(context).colorScheme.primary,
              color: Theme.of(context).iconTheme.color,
              gap: 10,
              duration: const Duration(milliseconds: 900),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              tabs: const [
                GButton(icon: Icons.punch_clock_outlined, text: 'In'),
                GButton(icon: Icons.home_outlined, text: 'Home'),
                GButton(icon: Icons.lock_clock_outlined, text: 'Out'),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),

  
// bottomNavigationBar: SafeArea(
//   maintainBottomViewPadding: true,
//   child: CurvedNavigationBar(
//   backgroundColor: Colors.transparent,
//   color: Colors.white,
//   buttonBackgroundColor: Colors.white,
//   height: 65,
//   index: _currentIndex,
//   animationCurve: Curves.easeInOutQuad,
//   animationDuration: const Duration(milliseconds: 490),
//   onTap: (index) async {
//   if (_isNavigating) return;

//   if (index == 0) {
//     _scaffoldKey.currentState?.openDrawer();
//     return;
//   }

//   setState(() => _currentIndex = index); 

//   _isNavigating = true;

//   try {
//     switch (index) {
//       case 1:
//         await Future.delayed(const Duration(milliseconds: 490));
//         await Navigator.push(context, MaterialPageRoute(builder: (_) => attendanceInPage));
//         break;

//       case 2:
//         if (ModalRoute.of(context)?.settings.name != '/home') {
//           await Navigator.pushNamed(context, '/home');
//         }
//         break;

//       case 3:
//         await Future.delayed(const Duration(milliseconds: 490));
//         await Navigator.push(context, MaterialPageRoute(builder: (_) => attendanceOutPage));
//         break;

//       case 4:
//         await Future.delayed(const Duration(milliseconds: 490));
//         await Navigator.pushNamed(context, '/user-info');
//         break;
//     }
//     setState(() => _currentIndex = 2);
//   } finally {
//     _isNavigating = false;
//   }
// },

//   items: [
//    CurvedNavigationBarItem(
//     child: Icon(Icons.menu_rounded, color:Colors.black87  ),
//     label: "Menu",
//     labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color:  Colors.black87),
//   ),

//   CurvedNavigationBarItem(
//     child: Icon(Icons.punch_clock_outlined, color: _currentIndex == 1 ? Colors.green : Colors.black87),
//     label: "In",
//     labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
//   ),

//   CurvedNavigationBarItem(
//     child: Icon(Icons.home_outlined, color: Colors.black87),
//     label: "Home",
//     labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
//   ),
  

//   CurvedNavigationBarItem(
//     child: Icon(Icons.lock_clock_outlined, color:_currentIndex == 3 ? Colors.redAccent : Colors.black87),
//     label: "Out",
//     labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color:Colors.black87),
//   ),

//   CurvedNavigationBarItem(
//     child: ValueListenableBuilder<String>(
//       valueListenable: profileImageNotifier,
//       builder: (context, value, _) {
//         return CircleAvatar(
//           radius: 14,
//           backgroundImage: value.isNotEmpty
//               ? NetworkImage('$baseUrl/api/employee/attachment/$value')
//               : const AssetImage('assets/icon/face-id.png') as ImageProvider,
//         );
//       },
//     ),
//     label: "Profile",
//     labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color:  Colors.black87),
//   ),
//  ],
// ),  

// ),
  );
}

String formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}


Widget _buildAttendanceSummary() {
  try {
    double presentDaysValue = presentDays - leaveDays;
    return AttendanceSummaryWidget(
      workingHours: totalWorkingDays.toString(),
      presentDays: formatNumber(presentDaysValue),
      leaveDays: formatNumber(leaveDays),
      absentDays: formatNumber(absentDays),

    );
  } catch (e) {
    print("Error rendering AttendanceSummaryWidget: $e");
    return const Text("Error in summary widget");
  }
}

Widget buildCalendar() {
  final today = DateTime.now();

  print('today: $today');
  final List<Appointment> appointments = [];

  try {
  punchDurations.forEach((date, value) {
  final List<String> durations = value['durations'] ?? [];
  final totalMinutes = calculateTotalMinutes(durations);

  print('totalMinutes: $totalMinutes');

  final isWeekOff = value['weekoffs'] == 1 || value['presabs'] == 'WO';
  final isAbsent = value['presabs'] == 'A';

  print('isWeekOff: $isWeekOff, isAbsent: $isAbsent');

    if (isWeekOff) {
      appointments.add(
        Appointment(
          startTime: date,
          endTime: date.add(const Duration(hours: 1)),
          subject: 'Week Off',
          color: Colors.grey, 
        ),
      );
      return;
    }

      if (isAbsent) {
      appointments.add(
      Appointment(
        startTime: date,
        endTime: date.add(const Duration(hours: 1)),
        subject: 'Absent',
        color: Colors.redAccent,
      ),
    );
    return;
  }

    if(totalMinutes > 0){
    appointments.add(
      Appointment(
        startTime: date,
        endTime: date.add(Duration(minutes: totalMinutes)),
        subject: 'Punch: ${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
        color: Colors.green.shade300,
      ),
    );
  }

    final dayDetails = value['dayDetails'];
     if (dayDetails != null && dayDetails.isNotEmpty) {
    if (dayDetails is Map<String, dynamic>) {
      dayDetails.forEach((categoryKey, entries) {  
        if (entries is List) {
          for (var entry in entries) {
            String type = entry['type'] ?? categoryKey;
            String duration = entry['duration'] ?? '';

            Color eventColor;
            String subject;

            switch (categoryKey) {
            case 'HL':
              eventColor = Colors.purpleAccent;
              subject = 'Holiday';
              break;

             case 'Leaves':
              eventColor = duration == 'Half-Day'
                  ? Colors.yellow.shade500
                  : Colors.orangeAccent;
              subject = duration == 'Half-Day'
                  ? 'Half Leave (${type})'
                  : 'Leave (${type})';
              break;

            case 'OD': 
              eventColor = Colors.blueAccent;
              subject =
                  duration == 'Half-Day' ? 'Half OD' : 'On Duty';
              break;

            case 'WO':
              eventColor = Colors.grey;
              subject = 'Week Off';
              break;

            default: 
              eventColor = Colors.teal;
              subject = '$type';
          }

          appointments.add(
            Appointment(
              startTime: date,
              endTime: date,
              subject: subject,
              color: eventColor,
            ),
          );
        }
      }
    });
  }
}

  });
} catch (e, stack) {
  print("Error in punch loop: $e");
  print(stack);
}


// // try {
// //   leaveDurations.forEach((date, leaves) {
// //     for (var leave in leaves) {
// //       bool isHalfDay = leave['leave_type'] == 'Half-Day';
// //       appointments.add(
// //         Appointment(
// //           startTime: date,
// //           endTime: date,
// //           subject: isHalfDay ? 'Half Day Leave' : 'Leave',
// //           color: isHalfDay ? Colors.orangeAccent : Colors.redAccent,
// //         ),
// //       );
// //     }
// //   });
// } catch (e, stack) {
//   print("Error in leave loop: $e");
//   print(stack);
// }


  final calendarDataSource = _InlineAppointmentDataSource(appointments);

bool isPresabsHalfDay(String presabs) {
  return RegExp(r'\b0\.5\b').hasMatch(presabs);
}

print('isPresabsHalfDay: ${isPresabsHalfDay('0.5')}');

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

        minDate: joiningDate ?? DateTime.now(),
        maxDate: DateTime.now(),     

          onViewChanged: (ViewChangedDetails details) {
          final DateTime currentMonthDate = details.visibleDates[details.visibleDates.length ~/ 2];

          final int newMonth = currentMonthDate.month;
          final int newYear = currentMonthDate.year;

          if (newMonth != selectedMonth || newYear != selectedYear) {
            setState(() {
              selectedMonth = newMonth;
              selectedYear = newYear;
            });
            //  fetchAttendanceSummary(fromDate: firstOfMonth(year: selectedYear, month: selectedMonth),toDate: lastOfMonth(year: selectedYear, month: selectedMonth));

            fetchPunchDurations(
            fromDate: firstOfMonth(year: newYear, month: newMonth),
            toDate: getToDate(newYear, newMonth),
          );
        }
      },

      dataSource: calendarDataSource,
      headerStyle: CalendarHeaderStyle(
        textAlign: TextAlign.center,
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? const Color.fromARGB(255, 240, 243, 247)
            : Colors.grey[850], 
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.black87
              : Colors.white70,
        ),
      ),
      viewHeaderStyle: ViewHeaderStyle(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? const Color.fromRGBO(224, 242, 241, 1)
            : Colors.grey[900],
        dayTextStyle: TextStyle(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.black87
              : Colors.white70,
        ),
      ),
      monthViewSettings: MonthViewSettings(
        showAgenda: false,
        appointmentDisplayMode: MonthAppointmentDisplayMode.indicator,
        numberOfWeeksInView: 6,
        dayFormat: 'EEE',
        monthCellStyle: MonthCellStyle(
          textStyle: TextStyle(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black87
                : Colors.white70,
          ),
          trailingDatesTextStyle: TextStyle(
            fontSize: 10,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
          leadingDatesTextStyle: TextStyle(
            fontSize: 10,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
        ),
      ),
      
       onTap: (CalendarTapDetails details) async {
          if (details.targetElement == CalendarElement.calendarCell &&
              details.date != null) {
            final DateTime tappedDate = details.date!;
            final DateTime dayKey =
                DateTime(tappedDate.year, tappedDate.month, tappedDate.day);
            
            final punchData = punchDurations[dayKey];
            // print('punchData: $punchData');

            if(punchData != null && punchData['presabs'] == 'A') {  
            showCustomSnackBar(
              context,
              'Absent',
              Colors.red.shade400,
              Icons.do_not_step_outlined,
            );
            return;
          }

            if (punchData != null && (punchData['weekoffs'] == 1 || punchData['presabs'] == 'WO')) {
            showCustomSnackBar(
              context,
              'Week Off',
              Colors.grey,
              Icons.weekend,
            );
            return; 
          }

            final isPresent = punchDurations.containsKey(dayKey);
            final isLeave = leaveDurations.containsKey(dayKey);

            if (!isPresent && !isLeave) {
              showCustomSnackBar(
                context,
                'No attendance or leave data available.',
                Colors.orange,
                Icons.warning_amber_outlined,
              );
              return;
            }
            _showBottomSheet(context, tappedDate, dayKey);
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
          buildLegendItem(Colors.red.shade300, 'Absent'),
          buildLegendItem(Colors.yellow.shade500, 'Half Day'),
          buildLegendItem(Colors.orangeAccent, 'Leave'),
          buildLegendItem(Colors.blueAccent, 'On Duty'),
          buildLegendItem(Colors.purple.shade400, 'Holiday'),
          buildLegendItem(Colors.grey, 'Week Off'),
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
        width: 8,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 10),
      ),
    ],
  );
}

      Widget buildDrawer() {
      return Drawer(
        child: Container(
          decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? const LinearGradient(
                  colors: [Color(0xFF121212), Color(0xFF121212)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                )
              : const LinearGradient(
                  colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)], 
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
        ),
         child: Column(
        children: [
          Expanded(
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
                    radius: 32,
                    backgroundImage: NetworkImage(
                      image?? '', 
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              // decoration: TextDecoration.underline,
                            ),
                          ),
                          // const SizedBox(height: 4),
                          // GestureDetector(
                          //   onTap: () {
                          //     Navigator.pop(context); // Close the drawer
                          //     Navigator.push(
                          //       context,
                          //       MaterialPageRoute(builder: (context) => const UserInfo()),
                          //     );
                          //   },
                            // child: const Text(
                            //   'View Profile',
                            //   style: TextStyle(
                            //     fontSize: 12,
                            //     color: Colors.black26,
                            //     // decoration: TextDecoration.underline,
                            //   ),
                            // ),
                        //   ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SwipFunction ()),
                  ),
                child: Container(
                 padding: const EdgeInsets.only(left: 18.0, right: 25.0, top: 10.0, bottom: 12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Padding(
                        padding: EdgeInsets.only(left: 8.0), 
                        child: Text(
                          'Profile',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                       ),
                      ),
                        
                      // const SizedBox(width: 8),
                      // SizedBox(
                      //   width: 24,
                      //   child: Align(
                      //     alignment: Alignment.center,
                      //     child: Icon(Icons.expand_more,color: Colors.grey.shade800),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ), 

            Divider(
            height: 20,
            thickness: 1,
            color: grey300,
            indent: 25,
            endIndent: 25,
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
              // setState(() { _expandedTile = expanded ? Colors.blue : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
              children: [
                ListTile(
                  title: const Text('Check-In'),
                  onTap: () => Navigator.pushNamed(context, '/attendance-in'),
                ),
                ListTile(
                  title: const Text('Check-Out'),
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
              key: Key('Time Tracking${_expandedTile == 'Time Tracking'}'),
              title: const Text('Attendance Report',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.access_time),
              initiallyExpanded: _expandedTile == 'Time Tracking',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'Time Tracking' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
              children: [
                ListTile(
                  title: const Text('Monthly Records'),
                  onTap: () => Navigator.pushNamed(context, '/attendance-record'),
               ),
              ],
             ),
            ),


            if(isVisitAccess)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
            child: ExpansionTile(
              key: Key('VisitEntry_${_expandedTile == 'Visit Entry'}'),
              title: const Text('Visit Entry',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.doorbell_outlined),
              initiallyExpanded: _expandedTile == 'Visit Entry',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'Visit Entry' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
               children: [
                ListTile(
                   title: const Text('Application'),
                  onTap: () => Navigator.pushNamed(context, '/visit-entry-apply'),
                ),
                ListTile(
                   title: const Text('History'),
                  onTap: () => Navigator.pushNamed(context, '/visit-entry-history'),
                ),
                // ListTile(
                //    title: const Text('Summary'),
                //   onTap: () => Navigator.pushNamed(context, '/visit-entry-summary'),
                // ),
              ]
             )
            ),


            if(isGatePassAccess)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
            child: ExpansionTile(
              key: Key('On-Duty${_expandedTile == 'On-Duty'}'),
              title: const Text('On-Duty',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.door_back_door),
              initiallyExpanded: _expandedTile == 'On-Duty',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'On-Duty' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
              children: [
                ListTile(
                  title: const Text('Apply On-Duty'),
                  onTap: () => Navigator.pushNamed(context, '/od-pass'),
                ),
                ListTile(
                  title: const Text('On-Duty History'),
                  onTap: () => Navigator.pushNamed(context, '/od-history'),
                ),
                if (isSupervisor)
                ListTile(
                  title: const Text('OD Request'),
                  onTap: () => Navigator.pushNamed(context, '/od-request'),
                ),
              ]
             )
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
                  title: const Text('Holiday Calendar'),
                  onTap: () => Navigator.pushNamed(context, '/holiday'),
                ),
                ListTile(
                  title: const Text('Apply Leave'),
                  onTap: () => Navigator.pushNamed(context, '/leave'),
                ),
                ListTile(
                  title: const Text('My Leave Requests'),
                  onTap: () => Navigator.pushNamed(context, '/leave-status'),
                ),
                ListTile(
                  title: const Text('Leave Balance'),
                  onTap: () => Navigator.pushNamed(context, '/leave-balance'),
                ),
                if (isSupervisor)
                ListTile(
                  title: const Text('Team Leave Request'),
                  onTap: () => Navigator.pushNamed(context, '/leave-request'),
                ),
              ],
            ),
            ),
            
            // Theme(
            //   data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            //   child: GestureDetector(
            //     onTap: () => Navigator.pushNamed(context, '/holiday'),
            //     child: Container(
            //       padding: const EdgeInsets.only(left: 18.0, right: 25.0, top: 10.0, bottom: 12.0),
            //       child: Row(
            //         children: [
            //           const Icon(Icons.hotel),
            //           const SizedBox(width: 12),
            //           const Expanded(
            //             child: Padding(
            //             padding: EdgeInsets.only(left: 3), 
            //             child: Text(
            //               'Holidays',
            //               style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            //             ),
            //           ),
            //           ),
            //           const SizedBox(width: 8),
            //           SizedBox(
            //             width: 24,
            //             child: Align(
            //               alignment: Alignment.center,
            //               child: Icon(Icons.expand_more,color: Colors.grey.shade800),
            //             ),
            //           ),
            //         ],
            //       ),
            //     ),
            //   ),
            // ), 
            // 
            if(isVisitAccess)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
              child: ExpansionTile(
              key: Key('Expense${_expandedTile == 'Expense'}'),
              title: const Text('Expense',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.currency_rupee),
              initiallyExpanded: _expandedTile == 'Expense',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'Expense' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 5), 
              children: [
                ListTile(
                  title: const Text('Apply Expense'),
                  onTap: () => Navigator.pushNamed(context, '/apply-expense'),
               ),
                ListTile(
                  title: const Text('History'),
                  onTap: () => Navigator.pushNamed(context, '/expense-history'),
               ),
               if(isSupervisor)
                ListTile(
                  title: const Text('Expense Request'),
                  onTap: () => Navigator.pushNamed(context, '/expense-request'),
               ),
              ],
             ),
            ),

            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
              child: ExpansionTile(
              key: Key('Payroll${_expandedTile == 'Payroll'}'),
              title: const Text('Payroll',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(FontAwesomeIcons.wallet),
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

          // Divider(thickness: 0.7, color: Colors.grey.shade300,indent: 25,
          //   endIndent: 25),
          // SizedBox(height: 6),
           ],
              ),
            ),
          ),

          Padding(
          padding: const EdgeInsets.only(bottom: 25.0, left: 16.0, right: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.settings, size: 20, color: Colors.black54),
                title: Text(
                  "Settings",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pushNamed(context, '/settings');
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

                  Text(
                    'v$appVersion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
           ],
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
