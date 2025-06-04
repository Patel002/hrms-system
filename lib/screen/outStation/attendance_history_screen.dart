import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import "package:url_launcher/url_launcher.dart";
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class AttandanceHistory extends StatefulWidget {
  const AttandanceHistory({super.key});

  @override
  State<AttandanceHistory> createState() => _AttandanceHistoryState();
}

class _AttandanceHistoryState extends State<AttandanceHistory> {
  final baseUrl = dotenv.env['API_BASE_URL'];

  String? emId, emUsername, compFname, compId, department;
  List attendanceList = [];
  bool isLoading = true;
  DateTime? selectedDate;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    gettokenData();
    fetchAttendanceData(DateTime.now());
  }

  String getFormattedDate(String dateString) {
    try {
    DateTime parsedDate = DateTime.parse(dateString);
    return DateFormat('dd-MMM').format(parsedDate);
    } catch (e) {
      return "Invalid Date"; 
    }
  }
  String FormattedDate(String timeString) {
    try {
    DateTime parseTime = DateFormat('HH:mm').parse(timeString);
    return DateFormat('HH:mm a').format(parseTime);
    } catch (e) {
      return "Invalid Time format"; 
    }
  }

  Future<void> gettokenData() async {
    final pref = await SharedPreferences.getInstance();
    final token = pref.getString('token') ?? '';
    final decode = Jwt.parseJwt(token);
    compFname = decode['comp_fname'] ?? '';
    department = decode['dep_name'] ?? '';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
          builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF3C3FD5),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),

            textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Color(0xFF3C3FD5)),
          ),
        ),
        child: child!,
      );
    },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
      fetchAttendanceData(picked);
    }
  }

  Future<void> fetchAttendanceData(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final decode = Jwt.parseJwt(token);
      emId = decode['em_id'] ?? '';
      print("emp_id: $emId");

      final formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      print("Formatted Date: $formattedDate");

      final url = Uri.parse(
        '$baseUrl/api/attendance/list?emp_id=$emId&punch_date=$formattedDate',
      );
      print("URL: $url");

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'];
        setState(() {
          attendanceList = data;
          isLoading = false;
        });
      } else {
        throw Exception(
          "Failed to load attendance data, status code: ${response.statusCode}",
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  void _launchMap(String latitude, String longitude) async {
    final url =
        "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open map.")));
    }
  }

  Widget buildAttendanceCard(Map item) {
    final base64Image = item['punch_img'];
    final latitude = item['latitude'];
    final longitude = item['longitude'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            getFormattedDate(item['punch_date']),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (base64Image != null && base64Image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(base64Image.split(',').last),
                    height: 80,
                    width: 80,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 130,
                  width: 130,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 40,
                    color: Colors.grey,
                  ),
                ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            FormattedDate(item['punch_time']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                        item['punchtype'] == 'OUTSTATION1'
                                ? 'In'
                            : item['punchtype'] == 'OUTSTATION2'
                                ? 'Out'
                                : item['punchtype'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            
                            ),
                          ),
                        ),
                      ),
                        Expanded(
                          child: Text(
                            item['punch_place'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        if (latitude != null && longitude != null)
                          GestureDetector(
                            onTap: () => _launchMap(latitude, longitude),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Color.fromARGB(255, 222, 17, 17),
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "View",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    /// Second Row: Labels
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Expanded(
                          child: Text(
                            "Time",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Punch",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Place",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey
                            ),
                          ),
                        ),
                        Text(
                          "Location",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
          // Row(
          //   children: [
          //     Expanded(
          //       child: Text(
          //         "$compFname",
          //         style: const TextStyle(
          //           fontSize: 10,
          //           fontWeight: FontWeight.w600,
          //         ),
          //       ),
          //     ),
          //     Expanded(
          //       child: Text(
          //         " $department",
          //         style: const TextStyle(
          //           fontSize: 10,
          //           fontWeight: FontWeight.w400,
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            )),
        elevation: 2,
        backgroundColor: Color(0XFF213448),
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      body: Column(
        children: [
         Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  child: Align(
    alignment: Alignment.centerLeft, 
    child: GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF202A44),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              selectedDate == null
          ?
            DateFormat('dd MMM yyyy').format(DateTime.now()) 
          : DateFormat('dd MMM yyyy').format(selectedDate!),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null
                    ? Center(child: Text("Error: $errorMessage"))
                    : attendanceList.isEmpty
                    ? const Center(child: Text("No attendance records found."))
                    : RefreshIndicator(
                      onRefresh: () async {
                        await fetchAttendanceData(
                          selectedDate ?? DateTime.now(),
                        );
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: attendanceList.length,
                        itemBuilder: (context, index) {
                          return buildAttendanceCard(attendanceList[index]);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
