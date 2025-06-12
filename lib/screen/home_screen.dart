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
  // bool _isLeaveExpanded = false;
  // bool _isOutStationExpanded = false;
  String? userRole;
  String? username;
  String? empId;  String? _expandedTile;
  bool isSupervisor = false;
  Map<DateTime, List<String>> punchDurations = {};
  final baseUrl = dotenv.env['API_BASE_URL'];


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

    if (hours == 0 && minutes == 0) return '0 min';
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
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
    await fetchPunchDurations();
  }
}

  Future<void> fetchPunchDurations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/attendance/day-duration/$empId'));

      print('Punch Durations Response: $response');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final List data = result['data'];

        print('Punch Durations: $data');

        Map<DateTime, List<String>> tempDurations = {};
        print('Punch Durations: $tempDurations');

        for (var item in data) {
          DateTime date = DateTime.parse(item['punch_in']);
          String duration = item['duration'];

          DateTime key = DateTime(date.year, date.month, date.day);

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

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: buildDrawer(),
      body: punchDurations.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : buildCalendar(),
    );
  }

Widget buildCalendar() {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: TableCalendar(
      firstDay: DateTime.utc(2025, 1, 1),
      lastDay: DateTime.utc(2025, 12, 31),
      focusedDay: DateTime.now(),
      calendarFormat: CalendarFormat.month,
      eventLoader: (day) {
        return punchDurations[DateTime(day.year, day.month, day.day)] ?? [];
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final isSunday = day.weekday == DateTime.sunday;
          final dayKey = DateTime(day.year, day.month, day.day);
          final isPresent = punchDurations.containsKey(dayKey);

          Color backgroundColor;
          Color textColor = Colors.white;

          if (isPresent) {
            backgroundColor = Colors.green.shade100; 
          } else if (isSunday) {
            backgroundColor = Colors.blue.shade50;
            textColor = Colors.black;
          } else if (day.isBefore(DateTime.now())) {
            backgroundColor = Colors.grey.shade200;
            textColor = Colors.black; 
          } else {
            backgroundColor = Colors.white12;
            textColor = Colors.black;
          }

          return Container(
            margin: const EdgeInsets.all(4.0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
        markerBuilder: (context, date, events) {
          if (events.isNotEmpty) {
            return Positioned(
              bottom: 4,
              child: Text(
                formatDuration(events.first as String),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }
          return const SizedBox();
        },
      ),
    ),
  );
}

      Widget buildDrawer() {
      return Drawer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(
                      'https://picsum.photos/200/300', 
                    ),
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
                          ),
                        ),
                        SizedBox(height: 4),
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
              leading: const Icon(Icons.access_time),
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
                  onTap: () => Navigator.pushNamed(context, '/attendance-history'),
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
          ],
        ),
    );
  }
}

