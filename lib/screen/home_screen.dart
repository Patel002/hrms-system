import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLeaveExpanded = false;
  String? userRole;
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
            // Optional: Header
            DrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.account_circle, size: 64, color: Colors.white),
                  SizedBox(height: 8),
                  Text('Welcome!', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),

            ExpansionTile(
              title: const Text('Leave'),
              leading: const Icon(Icons.beach_access),
              initiallyExpanded: _isLeaveExpanded,
              onExpansionChanged: (expanded) {
                setState(() => _isLeaveExpanded = expanded);
              },
              children: [
                 ListTile(
                  leading: const Icon(Icons.holiday_village),
                  title: const Text('Holiday'),
                  onTap: () => Navigator.pushNamed(context, '/holiday'),
                ),
                ListTile(
                  leading: const Icon(Icons.send),
                  title: const Text('leave Application'),
                  onTap: () => Navigator.pushNamed(context, '/leave'),
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Leave Status'),
                  onTap: () => Navigator.pushNamed(context, '/leave-status'),
                ),
                if (userRole == 'super admin' || isSupervisor)
                ListTile(
                  leading: const Icon(Icons.request_page),
                  title: const Text('Leave Request'),
                  onTap: () => Navigator.pushNamed(context, '/leave-request'),
                ),
              ],
            ),

            const Divider(),

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
