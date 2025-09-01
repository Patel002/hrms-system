import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:jwt_decode/jwt_decode.dart';
import './leave_details_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart';

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
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    initData();
  }

  Future<void> initData() async {
    // await parseToken();
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

  // Future<void> parseToken() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   final token = prefs.getString('token');
  //   if (token != null) {
  //     Map<String, dynamic> decoded = Jwt.parseJwt(token);
  //     employeeCode = decoded['em_code'];
  //     print('Employee Code: $employeeCode');
  //   }
  // }



 String formattedDate(String date) {
  return DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
 }

  Future<List<Map<String, dynamic>>> fetchRequests(String status) async {
    final token = await UserSession.getToken();

    if(token ==  null){
      Navigator.pushReplacementNamed(context, '/login');
      return [];
    }

    final empId = await UserSession.getUserId();

    final statusMap = {
      'pending': 'Not Approve',
      'approved': 'Approve',
      'rejected': 'Rejected',
    };

  try{
    final apiStatus = statusMap[status.toLowerCase()];
    print('API Status: $apiStatus');

    final response = await http.get(Uri.parse('$baseUrl/MyApis/leavetherecords?fetch_type=REQUEST&leave_status=$apiStatus'),
    headers: {
      'Authorization': 'Bearer $apiToken', 
      'auth_token': token,
      'user_id': empId!
    });
    print("res,$response");

    await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      print('Decoded: $decoded');
      final List<dynamic> dataList = decoded['data_packet'];
      print('Pending Leaves: $dataList');
      return dataList.cast<Map<String, dynamic>>();

    } else {
      final error = jsonDecode(response.body);
      showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
     return [];
    }
  }catch(e){
    final error = jsonDecode(e.toString());
    showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
    return [];
  }
  }



  Future<void> _sendApproval(String leaveId, {required String action}) async {

    final token = await UserSession.getToken();

    if(token ==  null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final empId = await UserSession.getUserId();

    final url = Uri.parse('$baseUrl/MyApis/leavetheapprove?id=$leaveId');
    print("url,$url");
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiToken',
      'auth_token': token,
      'user_id': empId!
      }, 
      body: jsonEncode({
        'action': action,
      }),
    );

    final responseBody = response.body;
    print('responseBody,$responseBody');
    
    await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

    if (response.statusCode == 200) {
     showCustomSnackBar(context, 'Leave details updated successfully ', Colors.green, Icons.check);
      await initData(); 
    } else {
      final error = jsonDecode(responseBody);
      showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
    }
  }


  Future<void> _sendRejection(String leaveId, {required String action, String? reason}) async {

    final token = await UserSession.getToken();

    if(token == null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final _empId = await UserSession.getUserId();

    final url = Uri.parse('$baseUrl/MyApis/leavethereject?id=$leaveId');
    print("url,$url");
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiToken',
      'auth_token': token,
      'user_id': _empId!
      }, 
      body: jsonEncode({
        'action': 'reject',
        'reject_reason': reason,
      }),
    );

    final responseBody = response.body;
    print('responseBody,$responseBody');

    await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

    if (response.statusCode == 200) {
     showCustomSnackBar(context, 'Leave details updated successfully ', Colors.green, Icons.check);
      await initData(); 
    } else {
      final error = jsonDecode(responseBody);
      showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
    }
  }

  void _confirmApprove(String leaveId) {
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
              "Approve Leave Request?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Are you sure you want to approve this leave request?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, 
              // color: Colors.black54
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
                      Navigator.pop(context);
                      _sendApproval(leaveId, action: 'approve');
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
  

 void _showRejectDialog(String leaveId) {
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
              "Reject Leave Request",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Please provide a reason for rejecting this leave request.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
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
                        _sendRejection(leaveId, action: 'reject', reason: reason);
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
      Map<String, dynamic> leave = list[i];
      String status = leave['leave_status'] ?? 'pending';
      print('Status: $status');
      
      return Card(
        color:Theme.of(context).brightness == Brightness.light ? Color(0xFFF2F5F8) : Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        margin: EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.event_note, color: Colors.blue),
              title: Text("${formattedDate(leave['start_date'])} → ${formattedDate(leave['end_date'])}"),
              subtitle: Text(
                  "Name: ${leave['empname']}"
                  "\nLeave: ${leave['leave_type_name']}" 
                  "\nDuration: ${leave['leave_duration_formatted']}",
              style: TextStyle(fontWeight: FontWeight.w400,color: Colors.grey)),
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LeaveDetailPage(
                      leave: leave,
                      onAction: (action, [reason]) {
                        Navigator.pop(context);
                        _sendRejection(leave['id'].toString(), 
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
                        backgroundColor: Theme.of(context).brightness == Brightness.light ? Color(0xFFF5F7FA) : Colors.grey.shade900,
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
                        backgroundColor: Theme.of(context).brightness == Brightness.light ? Color(0xFFF5F7FA) : Colors.grey.shade900,
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
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          forceMaterialTransparency: true,
          title: Text("Leave Requests", style: TextStyle( fontWeight: FontWeight.bold ),),
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
        foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: Theme.of(context).iconTheme.color,))
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

