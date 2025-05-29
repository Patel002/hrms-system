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
      userRole = decoded['role']; 
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Color(0XFF213448)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.account_circle, size: 64, color: Colors.white),
                  SizedBox(height: 8),
                  Text('Welcome!', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),


          Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
           child: ExpansionTile(
              title: const Text('Leave',
              style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.apps),
              initiallyExpanded: _expandedTile == 'Leave',
              onExpansionChanged: (expanded) {
                setState(() => _expandedTile = expanded ? 'Leave' : null);
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 8), 
              children: [
                 ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Holiday'),
                  onTap: () => Navigator.pushNamed(context, '/holiday'),
                ),
                ListTile(
                  leading: const Icon(Icons.eject),
                  title: const Text('leave Application'),
                  onTap: () => Navigator.pushNamed(context, '/leave'),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Leave Status'),
                  onTap: () => Navigator.pushNamed(context, '/leave-status'),
                ),
                ListTile(
                  leading: const Icon(Icons.stacked_bar_chart_sharp),
                  title: const Text('Leave Balance'),
                  onTap: () => Navigator.pushNamed(context, '/leave-balance'),
                ),
                if (userRole == 'super admin' || isSupervisor)
                ListTile(
                  leading: const Icon(Icons.hourglass_bottom),
                  title: const Text('Leave Request'),
                  onTap: () => Navigator.pushNamed(context, '/leave-request'),
                ),
              ],
            ),
            ),

            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),          
            child: ExpansionTile(
              title: const Text('Out Station',style: TextStyle(fontWeight: FontWeight.w600)),
              leading: const Icon(Icons.punch_clock_outlined),
              initiallyExpanded: _expandedTile == 'Out Station',
              onExpansionChanged: (expanded) {
              setState(() { _expandedTile = expanded ? 'Out Station' : null; });
              },
              childrenPadding: const EdgeInsets.only(left: 25, right: 16, bottom: 8), 
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
