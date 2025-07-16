import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';

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
      // extendBody: true,
      backgroundColor: Color(0xFFF2F5F8),
      appBar: AppBar(
              title: const Text(
                "Leave Balance",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            backgroundColor: Colors.transparent, 
            forceMaterialTransparency: true,
            elevation: 0,
            ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: FutureBuilder<List<dynamic>>(
          future: _leaveBalances,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
             return Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView.builder(
          itemCount: 5,
          itemBuilder: (context, index) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[300],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 16,
                              width: double.infinity,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 12,
                              width: 100,
                              color: Colors.grey[300],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
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

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      elevation: 4,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          _showLeaveDetailSheet(context, item);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.blueGrey.shade200,
                                child: Text(
                                  shortName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
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
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Available: $balance days",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}



void _showLeaveDetailSheet(BuildContext context, Map<String, dynamic> leave) {
  final String name = leave['leave_type_name'] ?? 'N/A';
  final String shortName = leave['leave_short_name'] ?? '';
  final balanceRaw = leave['available_balance'] ?? 0;
  final double balance = (balanceRaw is int) ? balanceRaw.toDouble() : balanceRaw;
  final totalLeaves = leave['credit'] ?? '0';
  final usedLeaves = leave['debit'] ?? '0';

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    backgroundColor: Colors.white,
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.blueGrey.shade200,
                  child: Text(
                    shortName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.calendar_month, "Available Balance", "$balance days"),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.add_circle_outline, "Total Leaves", "$totalLeaves days"),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.remove_circle_outline, "Used Leaves", "$usedLeaves days"),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.redAccent),
                label: const Text(
                  'Close',
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}


Widget _buildDetailRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 20, color: Colors.blueGrey),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black,
        ),
      ),
    ],
  );
}
