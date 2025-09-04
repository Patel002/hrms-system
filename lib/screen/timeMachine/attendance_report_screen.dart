import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../utils/user_session.dart';
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
  final apiToken = dotenv.env['ACCESS_TOKEN'];
  List<dynamic> attendanceData = [];
  DateTime? selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month);
    futureAttendance = fetchAttendance(
    fromDate: getFirstDateOfMonth(selectedMonth!),
    toDate: getLastDateOfMonth(selectedMonth!),
    );
  }

  Future<List<dynamic>> fetchAttendance({required DateTime fromDate, required DateTime toDate}) async {

    final token = await UserSession.getToken();

    if(token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return [];
    }
    
    final empId = await UserSession.getUserId();

    final fromDateStr = DateFormat('yyyy-MM-dd').format(fromDate);
    final toDateStr = DateFormat('yyyy-MM-dd').format(toDate);


    try {
      final url = Uri.parse('$baseUrl/MyApis/attendancetherecords?emp_id=$empId&from_date=$fromDateStr&to_date=$toDateStr');

      print('URL: $url');

      final response = await http.get(url, 
      headers: {
        'Authorization': 'Bearer $apiToken',
        'auth_token': token,
        'user_id': empId!
        });

      print('Response Status: ${response.statusCode}');

      await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('JSON Data: $jsonData[data_packet]');
        return jsonData['data_packet'];
      } else {
        final error = json.decode(response.body);
        throw Exception('Failed to load attendance data, status code: ${response.statusCode}, error: $error');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  Map<DateTime, List<dynamic>> groupByMonth(List<dynamic> data) {
    Map<DateTime, List<dynamic>> grouped = {};

    for (var record in data) {
      DateTime date = DateTime.parse(record['date']);
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
      futureAttendance = fetchAttendance(
        fromDate: getFirstDateOfMonth(selectedMonth!),
        toDate: getLastDateOfMonth(selectedMonth!),
      );

    });
  }

DateTime getFirstDateOfMonth(DateTime date) => DateTime(date.year, date.month, 1);
DateTime getLastDateOfMonth(DateTime date) => DateTime(date.year, date.month + 1, 0);


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
    appBar: AppBar(
      backgroundColor: Colors.transparent,  
    title: Text(
      "Monthly Records",
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    ),
    elevation: 0,
    forceMaterialTransparency: true,
    foregroundColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87,
  ),
    body: RefreshIndicator(
      onRefresh: _refreshAttendance, 
      color: Theme.of(context).scaffoldBackgroundColor,
      backgroundColor: Theme.of(context).iconTheme.color,
    child: FutureBuilder<List<dynamic>>(
      future: futureAttendance,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).iconTheme.color,));
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No attendance data found.'));
        }

        attendanceData = snapshot.data!;
        final groupedData = groupByMonth(attendanceData);
        final sortedMonths = groupedData.keys.toList()..sort((a, b) => b.compareTo(a));

        selectedMonth ??= sortedMonths.first;

        final records = groupedData[selectedMonth] ?? [];

        final totalPresent = records.where((r) => r['presabs'] == 'FP').length;
        final totalAbsent = records.where((r) => r['presabs'] == 'A').length;


        double parseToDouble(dynamic value) {
        if (value == null) return 0.0;
        if (value is int) return value.toDouble();
        if (value is double) return value;
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }

        final totalOT = records.fold<double>(
          0.0,
          (sum, r) => sum + parseToDouble(r['othrs']),
        );

        final totalWorkHrs = records.fold<double>(
          0.0,
          (sum, 
          r) => sum + parseToDouble(r['wrkhrs']),
        );

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
                      backgroundColor: Theme.of(context).brightness == Brightness.light ? Color(0xFFE4EBF5) : Color(0xFF121212),
                      foregroundColor: Theme.of(context).iconTheme.color,
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
                        monthPickerDialogSettings: MonthPickerDialogSettings(
                          headerSettings: PickerHeaderSettings(
                            headerBackgroundColor: Colors.black87,
                            headerCurrentPageTextStyle : const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ), 
                        ),
                          
                          dialogSettings: PickerDialogSettings(
                            dialogBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          ),

                          dateButtonsSettings: PickerDateButtonsSettings(
                          selectedMonthBackgroundColor: Theme.of(context).iconTheme.color,
                          selectedMonthTextColor: Theme.of(context).scaffoldBackgroundColor,
                          unselectedMonthsTextColor: Theme.of(context).iconTheme.color,
                          currentMonthTextColor: Colors.green,
                          ),

                          actionBarSettings: PickerActionBarSettings(
                            confirmWidget: Text(
                              'Done',
                              style: TextStyle(
                                color: Theme.of(context).iconTheme.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                           cancelWidget: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Theme.of(context).iconTheme.color,
                              fontWeight: FontWeight.bold,
                            ),
                           )
                          ),
                        )
                      );

                      if (selected != null) {
                        setState(() {
                          selectedMonth = DateTime(selected.year, selected.month);
                          futureAttendance = fetchAttendance(
                          fromDate: getFirstDateOfMonth(selectedMonth!),
                          toDate: getLastDateOfMonth(selectedMonth!),
                        );
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
                      gridData: FlGridData(
                      show: true,
                      ),
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
                        return BarTooltipItem(label, TextStyle(color: Colors.white));
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
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 2,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value % 15 == 0 ? value.toInt().toString() : '',
                              style: const TextStyle(
                                fontSize: 11,
                                // color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            );
                          },
                        ),
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
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.lightGreenAccent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 20,
                      borderRadius: BorderRadius.circular(6),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 0,
                        color: Colors.grey.shade200,
                      ),
                    )
                  ]),
                  BarChartGroupData(x: 1, barRods: [
                    BarChartRodData(
                      toY: totalAbsent.toDouble(),
                      gradient: const LinearGradient(
                        colors: [Colors.redAccent, Colors.red],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 20,
                      borderRadius: BorderRadius.circular(6),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 0,
                        color: Colors.grey.shade200,
                      ),
                    )
                  ]),
                  BarChartGroupData(x: 2, barRods: [
                    BarChartRodData(
                      toY: totalOT,
                      gradient: const LinearGradient(
                        colors: [Colors.orange, Colors.deepOrangeAccent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 20,
                      borderRadius: BorderRadius.circular(6),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 0,
                        color: Colors.grey.shade200,
                      ),
                    )
                  ]),
                  BarChartGroupData(x: 3, barRods: [
                    BarChartRodData(
                      toY: totalWorkHrs,
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.lightBlueAccent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 20,
                      borderRadius: BorderRadius.circular(6),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 0,
                        color: Colors.grey.shade200,
                      ),
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

                        final trnDate = record['date'];
                        final presabs = record['presabs'];
                        final wrkhrs = record['wrkhrs'];
                        final othrs = record['othrs'];
                        final shift = record['shift'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
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
                                  presabs == 'FP'
                                      ? Icons.check_circle              
                                      : presabs == 'WO'
                                       ? Icons.weekend            
                                       : presabs == 'HDA'
                                       ? Icons.hourglass_empty
                                       : presabs == 'A'
                                       ? Icons.cancel
                                       : Icons.check_circle,                
                                  color: presabs == 'FP'
                                      ? Colors.green
                                      : presabs == 'WO'
                                          ? Colors.orange
                                          : presabs == 'HDA'
                                          ? Colors.blue
                                          : presabs == 'A'
                                          ? Colors.redAccent
                                          : Colors.green,
                                  size: 28,
                                ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Date: $trnDate',
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

                              const SizedBox(height: 5),
                              Text('Presabs: $presabs', style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
