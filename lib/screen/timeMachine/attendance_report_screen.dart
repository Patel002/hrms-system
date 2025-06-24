import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

class AttendanceReportPage extends StatefulWidget {
  const AttendanceReportPage({super.key});

  @override
  _AttendanceReportPageState createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  late Future<List<dynamic>> futureAttendance;
  final baseUrl = dotenv.env['API_BASE_URL'];
  List<dynamic> attendanceData = [];
  DateTime? selectedMonth;

  @override
  void initState() {
    super.initState();
    futureAttendance = fetchAttendance();
  }

  Future<List<dynamic>> fetchAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final decodedToken = Jwt.parseJwt(token);
    final empId = decodedToken['em_id'];

    try {
      final url = Uri.parse('$baseUrl/api/month-trans/list/$empId');
      final response = await http.get(url, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        throw Exception('Failed to load attendance data');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Map<DateTime, List<dynamic>> groupByMonth(List<dynamic> data) {
    Map<DateTime, List<dynamic>> grouped = {};

    for (var record in data) {
      DateTime date = DateTime.parse(record['trndate']);
      DateTime monthKey = DateTime(date.year, date.month);

      if (!grouped.containsKey(monthKey)) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(record);
    }
    return grouped;
  }

  Future<void> _refreshAttendance() async {
    setState(() {
      futureAttendance = fetchAttendance();
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    appBar: AppBar(
      title: const Text("Attendance Record", style: TextStyle(fontWeight: FontWeight.bold)),
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      foregroundColor: Colors.black,
    ),
    body: RefreshIndicator(
      onRefresh: _refreshAttendance, 
      color: Colors.black,
      backgroundColor: Colors.white,
    child: FutureBuilder<List<dynamic>>(
      future: futureAttendance,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.black,));
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No attendance data found.'));
        }

        attendanceData = snapshot.data!;
        final groupedData = groupByMonth(attendanceData);
        final sortedMonths = groupedData.keys.toList()..sort((a, b) => b.compareTo(a));

        if (selectedMonth == null) {
          selectedMonth = sortedMonths.first;
        }

        final records = groupedData[selectedMonth] ?? [];

        final totalPresent = records.where((r) => r['presabs'] == 'P').length;
        final totalAbsent = records.where((r) => r['presabs'] == 'A').length;
        final totalOT = records.fold<double>(0.0, (sum, r) => sum + double.tryParse(r['othrs'])!);
        final totalWorkHrs = records.fold<double>(0.0, (sum, r) => sum + double.tryParse(r['wrkhrs'])!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFE4EBF5),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    onPressed: () async {
                      final selected = await showMonthPicker(
                        context: context,
                        initialDate: selectedMonth ?? DateTime.now(),
                        firstDate: DateTime(2015),
                        lastDate: DateTime.now(),
                      );

                      if (selected != null) {
                        setState(() {
                          selectedMonth = DateTime(selected.year, selected.month);
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      selectedMonth != null
                          ? DateFormat('MMMM yyyy').format(selectedMonth!)
                          : '',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 30),

            SizedBox(
              height: MediaQuery.of(context).size.height * 0.3, 
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: ([
                        totalPresent.toDouble(),
                        totalAbsent.toDouble(),
                        totalOT,
                        totalWorkHrs,
                      ].reduce((a, b) => a > b ? a : b)) + 2, 
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      // tooltipBgColor: Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label;
                        switch (group.x.toInt()) {
                          case 0:
                            label = 'Present: ${rod.toY.toInt()}';
                            break;
                          case 1:
                            label = 'Absent: ${rod.toY.toInt()}';
                            break;
                          case 2:
                            label = 'OT: ${rod.toY.toStringAsFixed(1)} hrs';
                            break;
                          case 3:
                            label = 'Work: ${rod.toY.toStringAsFixed(1)} hrs';
                            break;
                          default:
                            label = '';
                        }
                        return BarTooltipItem(label, const TextStyle(color: Colors.white));
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return const Text('Present', style: TextStyle(fontSize: 12));
                            case 1:
                              return const Text('Absent', style: TextStyle(fontSize: 12));
                            case 2:
                              return const Text('OT (hrs)', style: TextStyle(fontSize: 12));
                            case 3:
                              return const Text('Work (hrs)', style: TextStyle(fontSize: 12));
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(
                        toY: totalPresent.toDouble(),
                        color: Colors.green,
                        width: 20,
                        borderRadius: BorderRadius.circular(6),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: 0, color: Colors.grey.shade200),
                      )
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(
                        toY: totalAbsent.toDouble(),
                        color: Colors.redAccent,
                        width: 20,
                        borderRadius: BorderRadius.circular(6),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: 0, color: Colors.grey.shade200),
                      )
                    ]),
                    BarChartGroupData(x: 2, barRods: [
                      BarChartRodData(
                        toY: totalOT,
                        color: Colors.orange,
                        width: 20,
                        borderRadius: BorderRadius.circular(6),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: 0, color: Colors.grey.shade200),
                      )
                    ]),
                    BarChartGroupData(x: 3, barRods: [
                      BarChartRodData(
                        toY: totalWorkHrs,
                        color: Colors.blue,
                        width: 20,
                        borderRadius: BorderRadius.circular(6),
                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: 0, color: Colors.grey.shade200),
                      )
                    ]),
                  ],
                ),
                swapAnimationDuration: const Duration(milliseconds: 800), 
                swapAnimationCurve: Curves.easeOutBack, 
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
            Expanded(
              child: records.isEmpty
                  ? const Center(child: Text('No records for this month.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];

                        final punchIn = (record['punchin'] ?? '').isNotEmpty
                            ? DateFormat('HH:mm').format(DateTime.parse(record['punchin']))
                            : '-';

                        final punchOut = (record['punchout'] ?? '').isNotEmpty
                            ? DateFormat('HH:mm').format(DateTime.parse(record['punchout']))
                            : '-';

                        final trnDate = record['trndate'];
                        final presabs = record['presabs'];
                        final wrkhrs = record['wrkhrs'];
                        final othrs = record['othrs'];
                        final shift = record['master_shift'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    presabs == 'P' ? Icons.check_circle : Icons.cancel,
                                    color: presabs == 'P' ? Colors.green : Colors.redAccent,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Date: $trnDate ($presabs)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('In: $punchIn', style: const TextStyle(fontSize: 14)),
                                  Text('Out: $punchOut', style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Work: $wrkhrs hrs', style: const TextStyle(fontSize: 14)),
                                  Text('OT: $othrs hrs', style: const TextStyle(fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Shift: $shift', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        );
                      },
                    ),
                 ),
              ],
            );
          },
        ),
      ),
    );
  }
}
