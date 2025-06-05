import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';

class OdHistory extends StatefulWidget {
  const OdHistory({super.key});

  @override
  _OdHistoryState createState() => _OdHistoryState();
}

class _OdHistoryState extends State<OdHistory> with TickerProviderStateMixin { 

  String? emUsername;
  String? compFname;
  String? departmentName, duration, oddays;
  late TabController _tabController;
  final baseUrl = dotenv.env['API_BASE_URL'];

   @override
  void initState() {
    _tabController = TabController(length:3, vsync: this);
    super.initState();
  }

  Future<List<Map<String, dynamic>>> fetchOdHistory(String approved) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final decodedToken = Jwt.parseJwt(token);
      final empId = decodedToken['em_id'];
      // final compFname = decodedToken['comp_fname'];
      // final departmentName = decodedToken['dep_name'];

      print('Employee Username: $empId');
      print('Company Name: $compFname');
      print('Department Name: $departmentName');

      final statusMap = {
        'pending': 'PENDING',
        'approved': 'APPROVED',
        'rejected': 'REJECTED',
      };

      final apiStatus = statusMap[approved.toLowerCase()];
      print('API Status: $apiStatus');

      final url = Uri.parse(
        '$baseUrl/api/od-pass/history/?emp_id=$empId&approved=$apiStatus',
      );
      print('API URL: $url');
      print('Calling fetchOdHistory with approved=$approved');

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print('Od History: $decoded');
        final List<dynamic> dataList = decoded['odPass'];
        return dataList.cast<Map<String, dynamic>>();
      } else {
        print('Failed to fetch leaves: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching leaves: $e');
      return [];
    }
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
           colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
            begin: Alignment.topRight,
            end: Alignment.center,
          ),
        ),
      child: AppBar(
        title: Text("OD-Pass History",
        style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 4,
      ),
     )
    ),
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
              begin: Alignment.bottomLeft,
              end: Alignment.center,
            ),
          ),
   child: Column(
  children: [
    TabBar(
      controller: _tabController,
      labelColor: Colors.black,
      indicatorColor: Colors.blue,
      tabs: const [
        Tab(text: 'Pending'),
        Tab(text: 'Approved'),
        Tab(text: 'Rejected'),
      ],
    ),
    Expanded(
      child: TabBarView(
        controller: _tabController,
        children: [
          buildOdList('pending'),
          buildOdList('approved'),
          buildOdList('rejected'),
        ],
      ),
      ),
  ],
    ),
),

    );
  }


   Widget buildOdList(String approved) {
     return FutureBuilder<List<Map<String, dynamic>>>(
    future: fetchOdHistory(approved),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error loading $approved leaves"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No $approved leaves."));
        }

        final odPass = snapshot.data!;
        return ListView.builder(
          itemCount: odPass.length,
          itemBuilder: (context, index) {
            final leave = odPass[index];
            return Card(
              margin: EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
              decoration: BoxDecoration(
                 gradient: LinearGradient(
          colors: [Color.fromARGB(255, 240, 240, 235), Color.fromARGB(255, 255, 255, 255), Color.fromARGB(220, 247, 250, 248)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
                borderRadius: BorderRadius.circular(16)
              ),
              child: ListTile(
                leading: Icon(Icons.event_note, color: Colors.blue),
                title: Text("${leave['fromdate']} → ${leave['todate']}"),
                subtitle: Text(leave['remark']),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor(approved),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    approved.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('token') ?? '';
                  final decoded = Jwt.parseJwt(token);
                  final emUsername = decoded['em_username'];
                  final departmentName = decoded['dep_name'];
                  print("department name: $departmentName");
                  final compFname = decoded['comp_fname'];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => OdDetailsPage(
                            emUsername: emUsername ?? '',
                            departmentName: departmentName ?? '',
                            compFname: compFname ?? '',
                            fromDate: leave['fromdate'],
                            toDate: leave['todate'],
                            remark: leave['remark'],
                            approved: leave['approved'],
                            date: leave['add_date'],
                            oddays: leave['oddays']
                          ),
                    ),
                  );
                },
              ),
            ),
            );
          },
        );
      },
    );
  }

   Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class OdDetailsPage extends StatefulWidget {
  final String emUsername;
  final String departmentName;
  final String compFname;
  final String fromDate;
  final String toDate, date;
  final String remark;
  final String approved;
  final String oddays;


  const OdDetailsPage({
    super.key,
    required this.emUsername,
    required this.departmentName,
    required this.compFname,
    required this.fromDate,
    required this.toDate,
    required this.remark,
    required this.approved,
    required this.date,
    required this.oddays
  });

  @override
  _OdDetailsPageState createState() => _OdDetailsPageState();
}

class _OdDetailsPageState extends State<OdDetailsPage> {
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_top;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final statusColor = getStatusColor(widget.approved);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('OD Pass Details',
        style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF5F7FA), Color(0xFFE4EBF5), 
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: screenHeight,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 32, 16, 16),
                child: Column(
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: Colors.black26,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle("Employee Info"),
                            const SizedBox(height: 10),
                            _infoRow("Username", widget.emUsername),
                            _infoRow("Department", widget.departmentName),
                            _infoRow("Company", widget.compFname),
                            const SizedBox(height: 24),
                            _sectionTitle("OD Duration"),
                            const SizedBox(height: 10),
                            _infoRow("Applied Date", widget.date),
                            _infoRow("From", widget.fromDate),
                            _infoRow("To", widget.toDate),
                            _infoRow("Duration", widget.oddays),

                            const SizedBox(height: 24),
                            _sectionTitle("Reason"),
                            _infoRow("Remark", widget.remark),

                            const SizedBox(height: 24),
                            _sectionTitle("Status"),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(getStatusIcon(widget.approved),
                                    color: statusColor, size: 28),
                                const SizedBox(width: 12),
                                Chip(
                                  label: Text(
                                    widget.approved.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  backgroundColor: statusColor,
                                ),
                              ],
                            ),
                          ],
                        ),
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
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
