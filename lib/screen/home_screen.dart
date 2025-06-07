import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  // bool _isLeaveExpanded = false;
  // bool _isOutStationExpanded = false;
  String? userRole;
  String? _expandedTile;
  bool isSupervisor = false;

  @override
void initState() {
  super.initState();
  loadUserPermissions();
}

Future<void> loadUserPermissions() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token != null) {
    final decoded = Jwt.parseJwt(token);
    setState(() {
      userRole = decoded['em_role']; 
      isSupervisor = decoded['isSupervisor'] == true;
    });
  }
}
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundImage: NetworkImage(
                      '', 
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Chim Bro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
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

            const Divider(thickness: 1),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: const Center(child: Text('Welcome to the Dashboard!')),
    );
  }
}
