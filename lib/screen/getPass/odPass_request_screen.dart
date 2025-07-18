import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decode/jwt_decode.dart';
import './odPass_details_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ODPassRequest extends StatefulWidget {
  const ODPassRequest({super.key});

  @override
  State<ODPassRequest> createState() => _ODPassRequestState();
}

class _ODPassRequestState extends State<ODPassRequest> with SingleTickerProviderStateMixin {
 
 bool isLoading = true;
  String? employeeCode,compFname,departmentName;
  List<dynamic> pendingRequests = [];
  List<dynamic> approvedRequests = [];
  List<dynamic> rejectedRequests = [];
  late TabController _tabController;

  final baseUrl = dotenv.env['API_BASE_URL'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    initData();
  }

  Future<void> initData() async {
    await parseToken();
     final pending = await fetchRequests('pending');
    final approved = await fetchRequests('approved');
    final rejected = await fetchRequests('rejected');

    setState(() {
      pendingRequests = pending;
      approvedRequests = approved;
      rejectedRequests = rejected;
      isLoading = false;
    });

  }

  Future<void> parseToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      Map<String, dynamic> decoded = Jwt.parseJwt(token);
      employeeCode = decoded['em_code'];
      print('Employee Code: $employeeCode');
      // compFname = decoded['comp_fname'];
      // departmentName = decoded['dep_name'];
    }
  }

  Future<List<Map<String, dynamic>>> fetchRequests(String status) async {
    if (employeeCode == null) return [];  
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token'); 
       if (token == null) return [];


    final statusMap = {
      'pending': 'PENDING',
      'approved': 'APPROVED',
      'rejected': 'REJECTED',
    };

    final apiStatus = statusMap[status.toLowerCase()];
    print('API Status: $apiStatus');

    final res = await http.get(Uri.parse('$baseUrl/api/od-pass/list/$apiStatus'),
    headers: {
      'Authorization': 'Bearer $token', 
    });
    print("res,$res");

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      print('Decoded: $decoded');
      final List<dynamic> dataList = decoded['pendingOdRequests'];
      print('Pending Od-Pass requests: $dataList');
      return dataList.cast<Map<String, dynamic>>();

    } else {
      final error = jsonDecode(res.body);
      _showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
     return [];
    }
  }

  Future<void> _sendApprovalOrRejection(String odPassId, {required String action, String? rejectreason}) async {

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = Uri.parse('$baseUrl/api/od-pass/approve-reject/$odPassId');
    print("url,$url");
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
      }, 
      body: jsonEncode({
        'action': action,
        if (action == 'reject') 'reject_reason': rejectreason,
      }),
    );

    final responseBody = response.body;
    print('responseBody,$responseBody');

    if (response.statusCode == 200) {
     _showCustomSnackBar(context, 'Od pass details updated successfully ', Colors.green, Icons.check);
      await initData(); 
    } else {
      final error = jsonDecode(responseBody);
      _showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
    }
  }

  void _showCustomSnackBar(BuildContext context, String message, Color color, IconData icon) {
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          duration: const Duration(seconds: 2),
        );

        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      }

  void _confirmApprove(String odPassId) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: false,
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, color: Colors.green.shade400, size: 50),
            SizedBox(height: 16),
            Text(
              "Approve Od Pass Request?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Are you sure you want to approve this Od pass request?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[800],
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: TextStyle(fontSize: 16),
                    ),
                    child: Text("Cancel"),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _sendApprovalOrRejection(odPassId, action: 'Approved');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: Text("Approve",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
  

 void _showRejectDialog(String odPassId) {
  final TextEditingController reasonController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 50),
            SizedBox(height: 16),
            Text(
              "Reject Od Pass Request",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Please provide a reason for rejecting this Od pass request.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Enter rejection reason',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[800],
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: TextStyle(fontSize: 16),
                    ),
                    child: Text("Cancel"),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final reason = reasonController.text.trim();
                      if (reason.isNotEmpty) {
                        Navigator.pop(context);
                        _sendApprovalOrRejection(odPassId, action: 'reject', rejectreason: reason);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: Text("Reject",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}


Widget _buildList(List<dynamic> list, {bool showActions = false}) {
  if (list.isEmpty) return Center(child: Text("No requests."));
  return ListView.builder(
    padding: EdgeInsets.only(top: 8),
    itemCount: list.length,
    itemBuilder: (_, i) {
      Map<String, dynamic> od = list[i];
      String status = od['approved'] ?? 'pending';
      print('Status: $status');
      
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        elevation: 4,
        margin: EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.event_note, color: Colors.blue),
              title: Text("${od['fromdate']} → ${od['todate']}"),
              subtitle: Text("Employee: ${od['emp_id']}", 
              style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              onTap: () async {
                // final pref = await SharedPreferences.getInstance();
                // final token = pref.getString('token');
                // final decoded = Jwt.parseJwt(token!);
                // final employeeCode = decoded['em_code'];
                // final departmentName = decoded['dep_name'];
                // final compFname = decoded['comp_fname'];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OdDetailPage(
                      od: od,
                      // departmentName: departmentName ?? '',
                      // employeeCode: employeeCode ?? '',
                      // compFname: compFname ?? '',
                      onAction: (action, [reason]) {
                        Navigator.pop(context);
                        _sendApprovalOrRejection(od['id'].toString(), 
                            action: action, rejectreason: reason);
                      },
                      showActions: false
                    ),
                  ),
                );
              },
            ),
            if (showActions && status.trim().toUpperCase() == 'PENDING')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF5F7FA),
                        foregroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                           ),
                          // contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => _confirmApprove(od['id'].toString()),
                      child: Icon(Icons.check_circle_rounded, size: 20),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFF5F7FA),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => _showRejectDialog(od['id'].toString()),
                      child: Icon(Icons.cancel_rounded, size: 20),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
      backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text("Od Pass Requests", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Color(0XFF00A8CC),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator( color: Colors.black87,))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(pendingRequests, showActions: true),
                  _buildList(approvedRequests),
                  _buildList(rejectedRequests),
                ],
              ),
      ),
    );
  }

  Color statusColor(String status) {
  final cleaned = status.trim().toLowerCase();
  switch (cleaned) {
    case 'pending': return Colors.orange;
    case 'approved': return Colors.green;
    case 'rejected': return Colors.red;
    default: return Colors.grey;
  }
}
  
}
