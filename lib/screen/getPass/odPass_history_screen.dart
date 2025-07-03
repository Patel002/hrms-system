import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:intl/intl.dart';

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

      print('Employee Username: $empId');
      print('Company Name: $compFname');
    
    
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
          return Center(child: CircularProgressIndicator(color: Colors.black87,));
        } else if (snapshot.hasError) {
          return Center(child: Text("Error loading $approved Od-Pass"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No $approved Od-Pass."));
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
                  // final emUsername = decoded['em_username'];
                  // final departmentName = decoded['dep_name'];
                  // print("department name: $departmentName");
                  // print("od pass id,${leave['id']}");
                  final compFname = decoded['comp_fname'];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => OdDetailsPage(
                            emUsername: leave['employee_name'],
                            departmentName: leave['department_name'],
                            compFname: compFname ?? '',
                            fromDate: leave['fromdate'],
                            toDate: leave['todate'],
                            remark: leave['remark'],
                            approved: leave['approved'],
                            date: leave['add_date'],
                            oddays: leave['oddays'],
                            id: leave['id'].toString(),
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
  final String id;

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
    required this.oddays,
    required this.id,
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

  // IconData getStatusIcon(String status) {
  //   switch (status.toLowerCase()) {
  //     case 'approved':
  //       return Icons.check_circle_outline;
  //     case 'rejected':
  //       return Icons.cancel_outlined;
  //     default:
  //       return Icons.hourglass_top;
  //   }
  // }

  final baseUrl = dotenv.env['API_BASE_URL'];
  // final _formKey = GlobalKey<FormState>();
  late TextEditingController remarkController;
  late DateTime fromDate;
  late DateTime toDate;
  late String type;
  double duration = 1.0;
  bool isSubmitting = false;

  @override
void initState() {
  super.initState();
  fromDate = DateTime.parse(widget.fromDate);
  toDate = DateTime.parse(widget.toDate);
  final duration = widget.oddays;

  type = (duration == 0.5 || duration.toString() == '0.5') ? 'Half Day' : 'Full Day';

  remarkController = TextEditingController(text: widget.remark);
}

 double calculateDuration(DateTime from, DateTime to) {
    if (from.isAfter(to)) {
      return -1;
    }

    if (type == 'Half Day') {
      if (from.isAtSameMomentAs(to)) {
        return 0.5;
      } else {
        return (to.difference(from).inDays + 1);
      }
    } else {
      return to.difference(from).inDays + 1;
    }
  }

  Future<void> _pickDate(BuildContext context, bool isFrom) async {
  DateTime now = DateTime.now();
  DateTime firstDate = DateTime(now.year, now.month);
  DateTime lastDate = DateTime(2100);

  DateTime initDate = isFrom ? fromDate : toDate;

  if (initDate.isBefore(firstDate)) {
    initDate = firstDate;
  } else if (initDate.isAfter(lastDate)) {
    initDate = lastDate;
  }

  try {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3C3FD5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color.fromARGB(255, 25, 28, 232),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
          if (toDate.isBefore(fromDate)) {
            toDate = picked;
          }
        } else {
          toDate = picked;
        }
      });
    }
  } catch (e, stack) {
    debugPrint("DatePicker error: $e\n$stack");
  }
}


    Future<void> _saveUpdates() async {

      if(isSubmitting) return;

      setState(() {
        isSubmitting = true;
      });

      final id = (widget.id);
      print('OD-Pass ID: $id');

      final leaveDuration = calculateDuration(fromDate, toDate);
      final int odType = leaveDuration <= 1.0 ? 1 : 2;

      print('Leave Duration: $leaveDuration');
      print('base url: $baseUrl');
 
    if (baseUrl == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("API base URL is not configured.")),
    );
    return;
  }
    try {
    final url = Uri.parse('$baseUrl/api/od-pass/update/$id');
    print("url: $url");

      final response = await http.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fromdate': fromDate.toIso8601String(),
          'todate': toDate.toIso8601String(),
          'remark': remarkController.text,
          'oddays': leaveDuration.toString(),
          'odtype': odType.toString(),
        }),
      );

     final decode = jsonDecode(response.body);
      print(decode['data']);

      if (response.statusCode == 201) {
        _showCustomSnackBar(
          context,
          "Leave submitted successfully",
          Colors.green,
          Icons.check_circle,
        );
      } else {
        final error = jsonDecode(response.body);
        _showCustomSnackBar(
          context,
          "${error['message']}",
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      _showCustomSnackBar(context, 'Unexpected error format', Colors.red, Icons.error);
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }


 void _showCustomSnackBar(BuildContext context, String message, Color color, IconData icon) {

  final scaffoldMessenger = ScaffoldMessenger.of(context);

  scaffoldMessenger.clearSnackBars();

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }


  @override

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isApproved = widget.approved.toLowerCase() == 'approved';
    final isRejected =
        widget.approved.toLowerCase() == 'rejected';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('OD Pass Details',
        style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFFF5F7FA),
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [ 
      Container(
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: const Color(0xFFFDFDFD),
                       elevation: 2,
                      shadowColor: Colors.black26,
                      child: Padding(
                     padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                               decoration: BoxDecoration(
                           color:
                        isApproved
                            ? Colors.green.withOpacity(0.1)
                            : isRejected
                            ? Colors.red.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                      ),
                              child: Text(
                                widget.approved.toUpperCase(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                          isApproved
                              ? Colors.green
                              : isRejected
                              ? Colors.red
                              : Colors.orange,
                      fontWeight: FontWeight.bold,
                              ),
                             ),
                            ),
                            
                            const SizedBox(height: 12),
                            _sectionTitle("Employee Info"),
                            const SizedBox(height: 10),
                            _infoRow("Username", widget.emUsername),
                            _infoRow("Department", widget.departmentName),
                            _infoRow("Company", widget.compFname),
                            const SizedBox(height: 15),

                            Divider(color: Colors.grey.withOpacity(0.5)),
                            const SizedBox(height: 15),

                            _sectionTitle("OD Duration"),
                            const SizedBox(height: 10),
                            _infoRow("Applied Date", widget.date),
                           _editableDateField("From", fromDate, () => _pickDate(context, true)),
                          _editableDateField("To", toDate, () => _pickDate(context, false)),

                          _infoRow("Duration",'${calculateDuration(fromDate, toDate)} days',),

                          if (fromDate.difference(toDate).inDays.abs() == 0) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.access_time),
                              const SizedBox(width: 8),
                              const Text('Type: '),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: type,
                                items:
                              ['Full Day', 'Half Day']
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ),
                                  )
                                  .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    type = val!;
                                    duration = calculateDuration(fromDate, toDate);
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                            const SizedBox(height: 15),

                              Divider(color: Colors.grey.withOpacity(0.5)),

                            const SizedBox(height: 15),
                            _sectionTitle("Reason"),
                             TextFormField(
                            controller: remarkController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: "Enter reason for OD...",
                            ),
                            validator: (val) => val == null || val.isEmpty ? "Remark required" : null,
                          ),

                            const SizedBox(height: 10),

                             if (!isApproved && !isRejected) ...[
                             const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: (duration == -1 || isSubmitting) ? null : ()async {
                                await _saveUpdates();
                              },
                              icon: const Icon(Icons.update),
                              label: const Text("Update"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                           ],
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
      if(isSubmitting)
  Container(
    color: Colors.black54.withOpacity(0.5),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            'Updating Od Pass..',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          )
        ],
      )
    ),
  )
        ]
    ),
    );
  }

  Widget _sectionTitle(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
      color: Colors.black,
        fontWeight: FontWeight.bold,
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
                fontWeight: FontWeight.w400,
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

Widget _editableDateField(String label, DateTime date, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                "$label:",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
