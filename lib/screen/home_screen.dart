import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;  
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  String? userRole;
  String? username,profileImage;
  String? empId; 
  String? _expandedTile;
  bool isSupervisor = false;
  bool isLoading = false;
  Map<DateTime, List<String>> punchDurations = {};
  final baseUrl = dotenv.env['API_BASE_URL'];
  DateTime? selectedDate;
  Map<DateTime, List<Map<String, dynamic>>> leaveDurations = {};
  bool isDataLoaded = false;
  bool isDateProcessing = false;



  @override
void initState() {
  super.initState();
  loadUserPermissions();
  
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
    await fetchLeaveDurations();
    await fetchPunchDurations();
    await fetchProfileImage();

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

        profileImage = data['em_image'];
        

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
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(5)),),
            
            const SizedBox(height: 16),

            Text('Select Option for', style: TextStyle(fontSize: 18, color: Colors.grey[700])),
            
            Text('${day.day}/${day.month}/${day.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            
            const SizedBox(height: 20),
 
            ListTile(
              leading: const Icon(Icons.access_time, color: Colors.blueAccent),
              title: const Text('View Attendance', style: TextStyle(fontSize: 16)),
              onTap: () async {
                // if (isDateProcessing) return;
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
    backgroundColor: Colors.transparent,
    appBar: PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
      ),
        child: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
       backgroundColor: Colors.transparent, 
        foregroundColor: Colors.black,
        elevation: 0,
      ),
    ),
  ),

    drawer: buildDrawer(),
    body: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
          begin: Alignment.topRight,
         end: Alignment.bottomLeft,
        ),
      ),
      child: !isDataLoaded
          ? const Center(
              child: CircularProgressIndicator(color: Colors.black87),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0), 
              child: Container(
                child: buildCalendar(),
              ),
            ),
          ),
        );
      }

Widget buildCalendar() {
  final today = DateTime.now();
  return SafeArea(
  child: SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.all(8.0),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2025, 12, 31),
        focusedDay: today,
        rowHeight: 80,
        selectedDayPredicate: (day) => isSameDay(selectedDate, day),
        availableGestures: AvailableGestures.all,
       availableCalendarFormats: const {CalendarFormat.month: ''},

      eventLoader: (day) {
        final dayKey = DateTime(day.year, day.month, day.day);
        final events = [];

        if (punchDurations.containsKey(dayKey)) {
          events.addAll(punchDurations[dayKey]!);
        }

        if (leaveDurations.containsKey(dayKey)) {
          events.add(''); 
        }

        return events;
     },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final isSunday = day.weekday == DateTime.sunday;
          final dayKey = DateTime(day.year, day.month, day.day);
          final isToday = DateTime(day.year, day.month, day.day) == DateTime(today.year, today.month, today.day);

          bool sameDay(DateTime a, DateTime b) {
          return a.year == b.year && a.month == b.month && a.day == b.day;
          }

        final punchEntry = punchDurations.entries.firstWhere(
        (entry) => sameDay(entry.key, dayKey),
        orElse: () => MapEntry(DateTime(2000), []),
      );

      final leaveEntry = leaveDurations.entries.firstWhere(
        (entry) => sameDay(entry.key, dayKey),
        orElse: () => MapEntry(DateTime(2000), []),
      );

      final isPresent = punchEntry.value.isNotEmpty;
      final isLeave = leaveEntry.value.isNotEmpty;

      int totalMinutes = 0;

      if (isPresent) {
        totalMinutes = calculateTotalMinutes(punchEntry.value);
      }

      final isHalfDayAttendance = isPresent && totalMinutes < 270;


      final isHalfDayLeave = isLeave && leaveEntry.value.any((leave) => leave['isHalfDay'] == true);

      final isSplitDay = !isSunday && isHalfDayAttendance && isHalfDayLeave;

      print('Punch Entry: ${punchEntry.value}');
      print('; Entry: ${leaveEntry.value}');
      print('Total Minutes: $totalMinutes');
      print('isHalfDayAttendance: $isHalfDayAttendance');
      print('isHalfDayLeave: $isHalfDayLeave');
      print('isSplitDay: $isSplitDay');


          final isFullLeave = isLeave && (
          (!isPresent) ||
          (isHalfDayLeave && !isHalfDayAttendance)
        );

        final isFullAttendance = isPresent && (
          (!isLeave) ||
          (isHalfDayAttendance && !isHalfDayLeave) 
        );

      if (isSplitDay) {
      return GestureDetector(
        onTap: () => _showHalfDayOptions(context, day, dayKey),
        child: Container(
          margin: const EdgeInsets.all(2.0),
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isToday ? Colors.redAccent : Colors.grey.shade300,
              width: isToday ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: AnimatedContainer(
                  height: 6,
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade300, Colors.green.shade200],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: isToday ? 16 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
          Expanded(
            child: AnimatedContainer(
              height: 6,
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade300, Colors.orange.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),

                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
     Color backgroundColor;
          Color textColor = const Color.fromARGB(255, 0, 0, 0);
          BoxBorder? border;

          if (isFullLeave) {
          backgroundColor = Colors.orange.shade200;
        } else if (isFullAttendance) {
          backgroundColor = Colors.green.shade100;
        } else if (isSunday) {
          backgroundColor = Colors.blue.shade50;
        } else if (day.isBefore(today)) {
          backgroundColor = Colors.grey.shade200;
        } else {
          backgroundColor = Colors.white;
        }

        return GestureDetector(
        onTap: () async {
          if(isDateProcessing) return;

          setState(() {
            isDateProcessing = true;
          });

          final color = isFullAttendance ? Colors.green.shade400 : Colors.orange;

         Future.delayed(Duration.zero, (){
          showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(color),
        )),
      );
   });  

        await Future.delayed(const Duration(milliseconds: 600));

        if (isFullLeave && leaveDurations[dayKey] != null && leaveDurations[dayKey]!.isNotEmpty) {
          Navigator.pop(context);
         await Navigator.pushNamed(context, '/leave-status', arguments: {
            'selectedDate': day,
            'leavesTypeId': leaveDurations[dayKey]![0]['leaveTypeId'],
            'tabIndex': 1
          });
          
          debugPrint('Leave Type ID: ${leaveDurations[dayKey]![0]['leaveTypeId']}');

        } else if (isFullAttendance) {
          Navigator.pop(context);
          await Navigator.pushNamed(context, '/attendance-history', arguments: {'selectedDate': day});
        } else if (isSplitDay && punchEntry.value.isNotEmpty && leaveEntry.value.isNotEmpty) {
          _showHalfDayOptions(context, day, dayKey);
        }else {
          Navigator.pop(context);
        }

        setState(() {
          isDateProcessing = false;
        });
      },
    
      child: Container(
          margin: const EdgeInsets.all(2.0),
          height: 50,
          width: 50, 
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6), 
            border: border ?? Border.all(color: Colors.grey.shade300), 
          ),
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${day.day}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
              ),
          ),
          const SizedBox(height: 4),
          if (isFullLeave)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.redAccent, 
                shape: BoxShape.circle,
              ),
            )
          ],
        ),
      ),
    );
  },
        todayBuilder: (context, day, focusedDay) {
          Color backgroundColor = Colors.amber.shade100;
          BoxBorder? border = Border.all(color: Colors.amber.shade700, width: 2);
          Color textColor = Colors.black;

          return Container(
            margin: const EdgeInsets.all(2.0),
            height: 50,
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(6), 
              border: border,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          );
        },

        markerBuilder: (context, date, events) {
          if (events.isNotEmpty && events.first is String && events.first.toString().isNotEmpty) {
            return Positioned(
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  formatDuration(events.first as String),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }
          return const SizedBox();
        },
      ),
    ),
  ),
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
        child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
              child: Row(
                children: [
                   CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(
                      '$baseUrl/api/employee/attachment/$profileImage', 
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/user-info');
                          },
                          child: Text(
                            '$username',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
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
                  title: const Text('leave Application'),
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
           ],
          ),
         ),
        ),
       ),
      );
     }
    }