import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:photo_view/photo_view.dart';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart';
import '../expense/expense_request_details.dart';

class ExpenseRequestScreen extends StatefulWidget {
  const ExpenseRequestScreen({super.key});

  @override
  _ExpenseRequestScreenState createState() => _ExpenseRequestScreenState();
}

class _ExpenseRequestScreenState extends State<ExpenseRequestScreen> with SingleTickerProviderStateMixin {

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

    if(token ==  null){
      Navigator.pushReplacementNamed(context, '/login');
      return [];
    }

    final empId = await UserSession.getUserId();

    final statusMap = {
        'pending': 'PENDING',
        'approved': 'APPROVED',
        'rejected': 'REJECTED',
      }; 

  try{
    final apiStatus = statusMap[status] ?? '';  
    print('API Status: $apiStatus');

    final response = await http.get(Uri.parse('$baseUrl/MyApis/expensetherecords?fetch_type=REQUEST&approval_status=$apiStatus'),
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
      print('Pending Expense(s): $dataList');
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

  Future<void> _sendApproval(String expenseId, {required String action}) async {

    final token = await UserSession.getToken();

    if(token ==  null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final empId = await UserSession.getUserId();

    final url = Uri.parse('$baseUrl/MyApis/expensetheapprove?id=$expenseId');
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
     showCustomSnackBar(context, 'Expense details updated successfully ', Colors.green, Icons.check);
      await initData(); 
    } else {
      final error = jsonDecode(responseBody);
      showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
    }
  }


  Future<void> _sendRejection(String expenseId, {required String action, String? reason}) async {

    final token = await UserSession.getToken();

    if(token == null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final _empId = await UserSession.getUserId();

    final url = Uri.parse('$baseUrl/MyApis/expensethereject?id=$expenseId');
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
     showCustomSnackBar(context, 'Expense details updated successfully ', Colors.green, Icons.check);
      await initData(); 
    } else {
      final error = jsonDecode(responseBody);
      showCustomSnackBar(context,"${error['message']}", Colors.red, Icons.error);
    }
  }

  void _confirmApprove(String expenseId) {
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
              "Approve Expense Request?",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Are you sure you want to approve this expense request?",
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
                      _sendApproval(expenseId, action: 'approve');
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
  

 void _showRejectDialog(String expenseId) {
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
              "Reject Expense Request",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Please provide a reason for rejecting this expense request.",
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
                        _sendRejection(expenseId, action: 'reject', reason: reason);
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


void showImagePreview(BuildContext context, String image) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: PhotoView(
              imageProvider: NetworkImage(image),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained,
              initialScale: PhotoViewComputedScale.contained,
              enableRotation: false,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInQuart,
      );

      final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        ),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      );
    },
  );
}

String formattedDate(String date) {
  return DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
 }


 Widget buildImageOrPlaceholder(String? image, BuildContext context) {
  try {
    if (image != null && image.isNotEmpty) {
      if (image.contains('data:image')) {
        // Base64 image
        final imageBytes = base64Decode(image.split(',').last);
        return GestureDetector(
          onTap: () => showImagePreview(context, image),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              imageBytes,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
            ),
          ),
        );
      } else {
        // URL
        return GestureDetector(
          onTap: () => showImagePreview(context, image),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              image,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderContainer();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 80,
                  width: 80,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).iconTheme.color,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes!)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } else {
      return _buildPlaceholderContainer();
    }
  } catch (e) {
    print("Image load error: $e");
    return _buildPlaceholderContainer();
  }
}

Widget _buildPlaceholderContainer() {
  return Container(
    height: 95,
    width: 95,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.image_not_supported,
      size: 40,
      color: Colors.grey,
    ),
  );
}


Widget _buildList(List<dynamic> list, {bool showActions = false}) {
  if (list.isEmpty) return Center(child: Text("No requests."));

   final statusColor = {
    "APPROVED": Colors.green,
    "REJECTED": Colors.red,
    "PENDING": Colors.orange,
  };

   final statusIcon = {
    "APPROVED": Icons.verified,
    "REJECTED": Icons.cancel_outlined,
    "PENDING": FontAwesomeIcons.clockRotateLeft,
  };

  return ListView.builder(
    padding: EdgeInsets.only(top: 8),
    itemCount: list.length,
    itemBuilder: (_, i) {
      Map<String, dynamic> expense = list[i];
      String status = expense['approval_status'] ?? 'pending';
      String? expenseImage = expense['expense_img']; 

      return InkWell(
      onTap: () async {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExpenseRequestDetails(
              expense: expense,
              onAction: (action, [reason]) {
                Navigator.pop(context);
                _sendRejection(
                  expense['id'].toString(),
                  action: action,
                  reason: reason,
                );
              },
            ),
          ),
        );
      },
      child: Card(
        color: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFF2F5F8)
            : Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        margin: EdgeInsets.all(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "₹${expense['expense_amount'] ?? ''}",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expense['exp_description'] ?? "",
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          expense['expense_name'] ?? "",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          expense['exp_date_formatted'] ?? "",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: statusColor[status]!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon[status],
                          color: statusColor[status],
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor[status],
                          ),
                        ),
                      ],
                    ),
                  ),
                      buildImageOrPlaceholder(expenseImage, context),
                    ],
                  ),
                ],
              ),
              if (showActions && status == 'PENDING')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, right: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.light
                                  ? const Color(0xFFF5F7FA)
                                  : Colors.grey.shade900,
                          foregroundColor: Colors.green,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        onPressed: () =>
                        _confirmApprove(expense['id'].toString()),
                        child:
                        const Icon(Icons.check_circle_rounded, size: 20),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.light
                                  ? const Color(0xFFF5F7FA)
                                  : Colors.grey.shade900,
                          foregroundColor: Colors.red,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () =>
                            _showRejectDialog(expense['id'].toString()),
                        child: const Icon(Icons.cancel_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          title: Text("Expense Requests", style: TextStyle( fontWeight: FontWeight.bold ),),
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
  final cleaned = status.trim();
  switch (cleaned) {
    case 'PENDING': return Colors.orange;
    case 'APPROVED': return Colors.green;
    case 'REJECTED': return Colors.red;
    default: return Colors.grey;
  }
}
}