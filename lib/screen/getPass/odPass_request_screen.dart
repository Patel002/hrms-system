import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'odpass_details_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart';

class ODPassRequest extends StatefulWidget {
  const ODPassRequest({super.key});

  @override
  State<ODPassRequest> createState() => _ODPassRequestState();
}

class _ODPassRequestState extends State<ODPassRequest> with SingleTickerProviderStateMixin {
 
 bool isLoading = true;
  String? compFname,departmentName;
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

  String formattedDate(String date) {
  return DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
 }

  Future<void> initData() async {
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


  Future<List<Map<String, dynamic>>> fetchRequests(String status) async {
     
     final token = await UserSession.getToken();

     if(token == null){
       Navigator.pushReplacementNamed(context, '/login');
       return [];
     }

      final empId = await UserSession.getUserId();
      if(empId == null){
        Navigator.pushReplacementNamed(context, '/login');
        return [];
      }

    final statusMap = {
      'pending': 'PENDING',
      'approved': 'APPROVED',
      'rejected': 'REJECTED',
    };

    final apiStatus = statusMap[status.toLowerCase()];
    print('API Status: $apiStatus');

    final res = await http.get(Uri.parse('$baseUrl/MyApis/odpasstherecords?fetch_type=REQUEST&approval_status=$apiStatus'),
    headers: {
      'Authorization': 'Bearer $apiToken',
      'auth_token': token,
      'user_id': empId
    });
    print("response ,$res");

     await UserSession.checkInvalidAuthToken(
        context,
        json.decode(res.body),
        res.statusCode,
      );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      print('Decoded: $decoded');
      final List<dynamic> dataList = decoded['data_packet'];
      print('Pending Od-Pass requests: $dataList');
      return dataList.cast<Map<String, dynamic>>();

    } else {
      final error = jsonDecode(res.body);
      showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
     return [];
    }
  }

  Future<void> _sendApproval(String odPassId, {required String action}) async {

    final token = await UserSession.getToken();

    if(token == null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final empId = await UserSession.getUserId();

    final url = Uri.parse('$baseUrl/MyApis/odpasstheapprove?id=$odPassId');
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

    if (response.statusCode == 200) {
     showCustomSnackBar(context, 'Od pass details updated successfully ', Colors.green, Icons.check);
      await initData(); 
    } else {
      final error = jsonDecode(responseBody);
      showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
    }
  }

  Future<void> _sendRejection(String odPassId, {required String action, String? rejectreason}) async {

    final token = await UserSession.getToken();

    if(token == null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final _empId = await UserSession.getUserId();

    final url = Uri.parse('$baseUrl/MyApis/odpasssthereject?id=$odPassId');
    print("url,$url");
    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiToken',
      'auth_token': token,
      'user_id': _empId!
      }, 
      body: jsonEncode({
        'action': action,
        'reject_reason': rejectreason,
      }),
    );

    final responseBody = response.body;
    print('responseBody,$responseBody');

    if (response.statusCode == 200) {
     showCustomSnackBar(context, 'Od pass details updated successfully ', Colors.green, Icons.check);
      await initData(); 
    } else {
      final error = jsonDecode(responseBody);
      showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
    }
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
              style: TextStyle(fontSize: 16),
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
                      _sendApproval(odPassId, action: 'approve');
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
                        _sendRejection(odPassId, action: 'reject', rejectreason: reason);
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
if (list.isEmpty) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Lottie.asset(
          'assets/image/Animation.json',
          repeat: true,
          height: 200,
          width: 200,
          fit: BoxFit.cover,
        ),
        const Text(
          "No data available",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
}
  return ListView.builder(
    padding: EdgeInsets.only(top: 8),
    itemCount: list.length,
    itemBuilder: (_, i) {
      Map<String, dynamic> od = list[i];
      String status = od['approval_status'] ?? 'pending';
      print('Status: $status');
      
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color:Theme.of(context).brightness == Brightness.light ? Color(0xFFF2F5F8) : Colors.grey.shade900,
        elevation: 4,
        margin: EdgeInsets.all(10),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.event_note, color: Colors.blue),
              title: Text("${formattedDate(od['fromdate'])} → ${formattedDate(od['todate'])}"),
              subtitle: Text("Employee: ${od['empname']}"
              "\nDay: ${od['oddays_formatted']}", 
              style: TextStyle(fontWeight: FontWeight.normal,color: Colors.grey)),
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
                    builder: (context) => OdDetailPage(
                      od: od,
                      onAction: (action, [reason]) {
                        Navigator.pop(context);
                        _sendRejection(od['id'].toString(), 
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
     backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
        appBar: AppBar(
          foregroundColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87,
          backgroundColor: Colors.transparent,
          title: Text("Team On-duty Request", style: TextStyle( fontWeight: FontWeight.bold)),
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
