import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LeaveBalancePage extends StatefulWidget {
  const LeaveBalancePage({super.key});

  @override
  _LeaveBalancePageState createState() => _LeaveBalancePageState();
}

class _LeaveBalancePageState extends State<LeaveBalancePage> {
  late Future<List<dynamic>> _leaveBalances;
  final baseUrl = dotenv.env['API_BASE_URL'];
  @override
  void initState() {
    super.initState();
    _leaveBalances = loadLeaveBalances();
  }
Future<String?> getEmpCodeFromToken() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token != null) {
    Map<String, dynamic> payload = Jwt.parseJwt(token);
    return payload['em_code']; 
  }
  return null;
}

Future<List<dynamic>> fetchLeaveBalances(String emCode) async {
  try {
    final response = await Dio().get(
      '$baseUrl/api/balance/balance/$emCode',
    );

    if (response.statusCode == 200) {
      return response.data;
    } else {
      throw Exception('Failed to load leave balances');
    }
  } catch (e) {
    throw Exception('Error fetching leave balances: $e');
  }
}

  Future<List<dynamic>> loadLeaveBalances() async {
    final emCode = await getEmpCodeFromToken();
    if (emCode == null) throw Exception("Invalid token: em_code missing");
    return await fetchLeaveBalances(emCode);
  }
 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text(
        "Leave Availability",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: false,
      backgroundColor: Color(0XFF213448),
      foregroundColor: Colors.white,
    ),
    body: FutureBuilder<List<dynamic>>(
      future: _leaveBalances,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No leave balance data found"));
        }

        final balances = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: ListView.builder(
            itemCount: balances.length,
            itemBuilder: (context, index) {
              final item = balances[index];
              final String name = item['leave_type_name'] ?? '';
              final String shortName = item['leave_short_name'] ?? '';
              final balanceRaw = item['available_balance'] ?? 0;
              final double balance = (balanceRaw is int) ? balanceRaw.toDouble() : balanceRaw;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal.shade100,
                        child: Text(
                          shortName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Available: $balance days",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
}
