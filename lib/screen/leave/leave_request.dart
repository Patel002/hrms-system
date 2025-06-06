import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decode/jwt_decode.dart';
import './leave_details_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class LeaveRequestPage extends StatefulWidget {
  const LeaveRequestPage({super.key});

  @override
  _LeaveRequestPageState createState() => _LeaveRequestPageState();
}

class _LeaveRequestPageState extends State<LeaveRequestPage> with SingleTickerProviderStateMixin {
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
      'pending': 'Not Approve',
      'approved': 'Approve',
      'rejected': 'Rejected',
    };

    final apiStatus = statusMap[status.toLowerCase()];
    print('API Status: $apiStatus');

    final res = await http.get(Uri.parse('$baseUrl/api/emp-leave/$apiStatus'),
    headers: {
      'Authorization': 'Bearer $token', 
    });
    print("res,$res");

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      print('Decoded: $decoded');
      final List<dynamic> dataList = decoded['pendingLeaves'];
      print('Pending Leaves: $dataList');
      return dataList.cast<Map<String, dynamic>>();

    } else {
      final error = jsonDecode(res.body);
      _showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
     return [];
    }
  }

  Future<void> _sendApprovalOrRejection(String leaveId, {required String action, String? reason}) async {

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = Uri.parse('$baseUrl/api/emp-leave/approve-reject/$leaveId');
    print("url,$url");
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
      }, 
      body: jsonEncode({
        'action': action,
        if (action == 'reject') 'reject_reason': reason,
      }),
    );

    final responseBody = response.body;
    print('responseBody,$responseBody');

    if (response.statusCode == 200) {
     _showCustomSnackBar(context, 'Leave details updated successfully ', Colors.green, Icons.check);
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

  void _confirmApprove(String leaveId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Confirm Approval"),
        content: Text("Are you sure you want to approve this leave request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text("Approve")),
        ],
      ),
    );

    if (confirm == true) {
      _sendApprovalOrRejection(leaveId, action: 'approve');
    }
  }

  void _showRejectDialog(String leaveId) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Reject Leave"),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: 'Enter reject reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.pop(context);
                _sendApprovalOrRejection(leaveId, action: 'reject', reason: reason);
              }
            },
            child: Text("Reject"),
          ),
        ],
      ),
    );
  }

 Widget _buildList(List<dynamic> list, {bool showActions = false}) {
  if (list.isEmpty) return Center(child: Text("No requests."));
  return ListView.builder(
    padding: EdgeInsets.only(top: 8),
    itemCount: list.length,
    itemBuilder: (_, i) {
      Map<String, dynamic> leave = list[i];
      String status = leave['leave_status'] ?? 'pending';
      print('Status: $status');
      
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        margin: EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.event_note, color: Colors.blue),
              title: Text("${leave['start_date']} → ${leave['end_date']}"),
              subtitle: Text("Employee: ${leave['em_id']}", 
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
                final pref = await SharedPreferences.getInstance();
                final token = pref.getString('token');
                final decoded = Jwt.parseJwt(token!);
                // final employeeCode = decoded['em_code'];
                // final departmentName = decoded['dep_name'];
                final compFname = decoded['comp_fname'];
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LeaveDetailPage(
                      leave: leave,
                      // departmentName: departmentName ?? '',
                      // employeeCode: employeeCode ?? '',
                      compFname: compFname ?? '',
                      onAction: (action, [reason]) {
                        Navigator.pop(context);
                        _sendApprovalOrRejection(leave['id'].toString(), 
                            action: action, reason: reason);
                      },
                    ),
                  ),
                );
              },
            ),
            if (showActions && status.toLowerCase() == 'not approve')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 242, 238, 238),
                        foregroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                           ),
                          // contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => _confirmApprove(leave['id'].toString()),
                      child: Icon(Icons.check_circle_rounded, size: 20),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 242, 238, 238),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => _showRejectDialog(leave['id'].toString()),
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
        appBar: AppBar(
          title: Text("Leave Requests"),
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
            ? Center(child: CircularProgressIndicator())
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
    case 'not approve': return Colors.orange;
    case 'approve': return Colors.green;
    case 'rejected': return Colors.red;
    default: return Colors.grey;
  }
}
}

