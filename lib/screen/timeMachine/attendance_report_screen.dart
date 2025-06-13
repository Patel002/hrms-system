import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:accordion/accordion.dart';
import 'dart:convert';

class AttendanceReportPage extends StatefulWidget {
  const AttendanceReportPage({Key? key}) : super(key: key);

  @override
  _AttendanceReportPageState createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  late Future<List<dynamic>> futureAttendance;
  final baseUrl = dotenv.env['API_BASE_URL'];
  List<dynamic> attendanceData = [];
  String? selectedYear;
  String? openSection;

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

  String getFinancialYear(DateTime date) {
    if (date.month >= 4) {
      return '${date.year}-${date.year + 1}';
    } else {
      return '${date.year - 1}-${date.year}';
    }
  }

  Map<String, Map<String, List<dynamic>>> groupByFinancialYear(List<dynamic> data) {
    Map<String, Map<String, List<dynamic>>> grouped = {};

    for (var record in data) {
      DateTime date = DateTime.parse(record['trndate']);
      String finYear = getFinancialYear(date);
      String monthKey = "${date.year}-${date.month.toString().padLeft(2, '0')}";

      if (!grouped.containsKey(finYear)) {
        grouped[finYear] = {};
      }
      if (!grouped[finYear]!.containsKey(monthKey)) {
        grouped[finYear]![monthKey] = [];
      }
      grouped[finYear]![monthKey]!.add(record);
    }

    return grouped;
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AppBar(
                title: const Text(
                  "Attendance Record",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              backgroundColor: Colors.transparent, 
                foregroundColor: Colors.black,
                elevation: 0,
              ),
            ),
          ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
           colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
            begin: Alignment.center,
            end: Alignment.topRight,
          ),
        ) ,
      child: FutureBuilder<List<dynamic>>(
        future: futureAttendance,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No attendance data found.'));
          }

          attendanceData = snapshot.data!;
          final groupedData = groupByFinancialYear(attendanceData);
          final sortedFinYears = groupedData.keys.toList()..sort((a, b) => b.compareTo(a));

          if (selectedYear == null) {
            selectedYear = sortedFinYears.first;
          }

          final months = groupedData[selectedYear] ?? {};
          final sortedMonths = months.keys.toList()..sort((a, b) => b.compareTo(a));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Text('Select Year: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: selectedYear,
                      items: sortedFinYears.map((year) {
                        return DropdownMenuItem<String>(
                          value: year,
                          child: Text(year),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedYear = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
             Expanded(
  child: Accordion(
    maxOpenSections: 1,
    headerBackgroundColor: Color(0xFFCBEEF3),
    headerBackgroundColorOpened:Color(0xFFABC8C0),
    headerBorderColorOpened: Color(0xFFABC8C0),
    contentBorderColor: Color(0xFFABC8C0),  
    scaleWhenAnimating: true,
    openAndCloseAnimation: true,
    headerPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
    children: sortedMonths.map((monthKey) {
      final records = months[monthKey]!;

      final totalPresent = records.where((r) => r['presabs'] == 'P').length;
      final totalAbsent = records.where((r) => r['presabs'] == 'A').length;
      final totalOT = records.fold<double>(0.0, (sum, r) => sum + double.tryParse(r['othrs'])!);
      final totalWorkHrs = records.fold<double>(0.0, (sum, r) => sum + double.tryParse(r['wrkhrs'])!);

      return AccordionSection(
        isOpen: false,
        header: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(DateTime.parse('$monthKey-01')),
              style: const TextStyle(
                color: Colors.black, 
                fontSize: 18, 
                fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text('P: $totalPresent ', style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.green.shade400,
                ),
                const SizedBox(width: 5),
                Chip(
                  label: Text('A: $totalAbsent', style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.redAccent.shade200,
                ),
            const SizedBox(width: 5),
                Chip(
                  label: Text('OT: ${totalOT.toStringAsFixed(2)} hrs', style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.orange,
                ),
                const SizedBox(width: 5),
                Chip(
                  label: Text('Work: ${totalWorkHrs.toStringAsFixed(2)} hrs', style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.blue.shade300,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...records.map((record) {
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
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      presabs == 'P' ? Icons.check_circle : Icons.cancel,
                      color: presabs == 'P' ? Colors.green : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date: $trnDate ($presabs)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'In: ',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: punchIn,
                                      style: const TextStyle(fontWeight: FontWeight.normal),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    const TextSpan(
                                      text: 'Out: ',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    TextSpan(
                                      text: punchOut,
                                      style: const TextStyle(fontWeight: FontWeight.normal),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Work: $wrkhrs hrs',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'OT: $othrs hrs',
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Shift: $shift',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    }).toList(),
  ),
)

            ],
          );
        },
      ),
    ),
    );
  }
}
