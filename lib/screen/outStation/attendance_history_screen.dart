import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import "package:url_launcher/url_launcher.dart";
import 'dart:convert';
import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';  
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AttandanceHistory extends StatefulWidget {
  const AttandanceHistory({super.key});

  @override
  State<AttandanceHistory> createState() => _AttandanceHistoryState();
}

class _AttandanceHistoryState extends State<AttandanceHistory> {
  final baseUrl = dotenv.env['API_BASE_URL'];

  String? emId, emUsername, compFname, compId;
  List attendanceList = [];
  bool isLoading = true;
  DateTime? selectedDate;
  String? errorMessage;
  
  @override
  void initState() {
    super.initState();
    fetchAttendanceData(DateTime.now());
  }

  Future<void> _selectDate(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
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
  final token = prefs.getString('token')?? '';
  final decode = Jwt.parseJwt(token);
  emId = decode['em_id'] ?? '';
  print("emp_id: $emId");

  final formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  print("Formatted Date: $formattedDate");

  final url = Uri.parse('$baseUrl/api/attendance/list?emp_id=$emId&punch_date=$formattedDate');
  print("URL: $url");

  final response = await http.get(url, headers: {
    'Content-Type': 'application/json',
  });

  if (response.statusCode == 200) {
    final List data = jsonDecode(response.body)['data'];
    setState(() {
      attendanceList = data;
      isLoading = false;
    });
  } else {
    throw Exception("Failed to load attendance data, status code: ${response.statusCode}");
  }
}catch(e){
  setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
}
}

  void _launchMap(String latitude, String longitude) async {
    final url = "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open map.")),
      );
    }
  }


  Widget buildAttendanceCard(Map item) {
    final base64Image = item['punch_img'];
    final latitude = item['latitude'];
    final longitude = item['longitude'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date: ${item['punch_date']} - Time: ${item['punch_time']}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text("Place: ${item['punch_place']}", style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            if (base64Image != null && base64Image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(base64Image.split(',').last),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 10),
            if (latitude != null && longitude != null)
              GestureDetector(
                onTap: () => _launchMap(latitude, longitude),
                child: Row(
                  children: const [
                    Icon(Icons.location_pin, color: Colors.red),
                    SizedBox(width: 6),
                    Text(
                      "Location ",
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        centerTitle: false,
        elevation: 1,
      ),
      body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            icon: Icon(Icons.calendar_today),
            label: Text("Select Date"),
            onPressed: () => _selectDate(context),
          ),
        ),

      Expanded(child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text("Error: $errorMessage"))
              : attendanceList.isEmpty
                  ? const Center(child: Text("No attendance records found."))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await fetchAttendanceData(selectedDate ?? DateTime.now());
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
