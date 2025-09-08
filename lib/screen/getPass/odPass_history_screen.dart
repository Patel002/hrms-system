import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart';
import 'package:lottie/lottie.dart';
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
  Set<String> selectedLeaves = {};
  bool selectionMode = false;
  final apiToken = dotenv.env['ACCESS_TOKEN'];
  final baseUrl = dotenv.env['API_BASE_URL'];

  late Future<List<Map<String, dynamic>>> _pendingLeavesFuture;
  late Future<List<Map<String, dynamic>>> _approvedLeavesFuture;
  late Future<List<Map<String, dynamic>>> _rejectedLeavesFuture;

   @override
  void initState() {
    _tabController = TabController(length:3, vsync: this);
    super.initState();
    _pendingLeavesFuture = fetchOdHistory("pending");
    _approvedLeavesFuture = fetchOdHistory("approved");
    _rejectedLeavesFuture = fetchOdHistory("rejected");
  }

  Future<List<Map<String, dynamic>>> fetchOdHistory(String approved) async {
    try {

      final token = await UserSession.getToken();

      if(token == null){
        Navigator.pushReplacementNamed(context, '/login');
        return [];
      }

      final empId = await UserSession.getUserId();

      final statusMap = {
        'pending': 'PENDING',
        'approved': 'APPROVED',
        'rejected': 'REJECTED',
      };

      final apiStatus = statusMap[approved.toLowerCase()];
      print('API Status: $apiStatus');

      final url = Uri.parse(
        '$baseUrl/MyApis/odpasstherecords?fetch_type=SELF&approval_status=$apiStatus',
      );
      print('API URL: $url');
      print('Calling fetchOdHistory with approved=$approved');

      final response = await http.get(url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiToken',
        'auth_token': token,
        'user_id': empId!,
      }
      );

       await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );
      
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        print('Od History: $decoded');
        final List<dynamic> dataList = decoded['data_packet'];
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

  Future<bool> deleteLeave(String odId) async {
  try {
    final _token = await UserSession.getToken();
    final _empId = await UserSession.getUserId();

    if (_token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    final url = Uri.parse('$baseUrl/MyApis/odpassthedelete?id=$odId');

    print('URL: $url');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiToken',
        'auth_token': _token,
        'user_id': _empId!,
      },
    );

    await UserSession.checkInvalidAuthToken(
      context,
      json.decode(response.body),
      response.statusCode,
    );

    if (response.statusCode == 200) {
      showCustomSnackBar(context, "Od pass deleted successfully", Colors.green, Icons.check_circle);
      _refreshData();
      return true;
    } else {
      print('Failed to delete Od pass: ${response.body}');
      showCustomSnackBar(context, "Failed to delete Od pass", Colors.red, Icons.error);
      return false;
    }
  } catch (e) {
    showCustomSnackBar(context, "Error: $e", Colors.red, Icons.error);
    return false;
  }
}

 Future<void> deleteMultipleLeaves(List<String> odId) async {
  int successCount = 0;

  print('sccesscount,$successCount');

  for (String id in odId) {
    bool success = await deleteLeave(id);

    print('sccesscount1,$success');
    if (success) successCount++;
  }

  if (mounted) {
    setState(() {
      _pendingLeavesFuture = fetchOdHistory("pending");
      selectionMode = false;
      selectedLeaves.clear();
    });

    if (successCount > 0) {
      showCustomSnackBar(
        context,
        "$successCount Od pass(s) deleted successfully",
        Colors.green,
        Icons.check_circle,
      );
    } else {
      showCustomSnackBar(
        context,
        "Failed to delete selected od pass(s)",
        Colors.red,
        Icons.error,
      );
      print("Failed to delete selected leave(s)");
    }
  }
}

void _refreshData() {
  setState(() {
    _pendingLeavesFuture = fetchOdHistory("pending");
    _approvedLeavesFuture = fetchOdHistory("approved");
    _rejectedLeavesFuture = fetchOdHistory("rejected");
  });
}

Future<void> _confirmDelete(List<String> odId) async {
  bool isDeleting = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
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
               Lottie.asset(
                  'assets/icon/trash.json',
                  repeat: true,
                  height: 125,
                  ),
                const SizedBox(height: 16),
                const Text(
                  "Delete gate pass(s)?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Gate pass will be deleted parmanently from your device.you can't restore them once deleted.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.delete),
                      label: Text(isDeleting ? "Deleting..." : "Delete"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: isDeleting
                          ? null
                          : () async {
                              setModalState(() {
                                isDeleting = true;
                              });

                              try {
                                await deleteMultipleLeaves(odId);
                                if (mounted) {
                                  Navigator.pop(context);

                                  setState(() {
                                    _pendingLeavesFuture =
                                    fetchOdHistory("pending");
                                    selectionMode = false;
                                    selectedLeaves.clear();
                                  });
                                }
                              } catch (e) {
                                setModalState(() {
                                  isDeleting = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Failed to delete gatepass(s): $e"),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

@override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.light
    ? Color(0xFFF2F5F8)
    : Color(0xFF121212),
    appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text("On-Duty History",
        style: TextStyle(fontWeight: FontWeight.bold)),
        forceMaterialTransparency: true,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
        leading: selectionMode
        ? IconButton(
            icon: Icon(Icons.close),
            onPressed: () {
              setState(() {
                selectionMode = false;
                selectedLeaves.clear();
              });
            },
          )
        : null,
        actions: selectionMode
        ? [
            IconButton(
              icon: Icon(FontAwesomeIcons.trashCan,size: 18.5,),
              onPressed: () async {
              if (selectedLeaves.isNotEmpty) {
              _confirmDelete(selectedLeaves.toList());
            }
              },
            ),
          ]
        : [],
    ),
      body: Container(
        decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? const LinearGradient(
                      colors: [Color(0xFF121212), Color(0xFF121212)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)], 
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
            ),
   child: Column(
  children: [
    TabBar(
    controller: _tabController,
      indicatorColor: Colors.blue,
      labelColor: Theme.of(context).iconTheme.color,
      unselectedLabelColor: Colors.grey,
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
    final future = approved == "pending"
        ? _pendingLeavesFuture
        : approved == "approved"
            ? _approvedLeavesFuture
            : _rejectedLeavesFuture;

    return FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.black87,));
        } 
        else if (snapshot.hasError) {
      return Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Lottie.asset(
              'assets/image/error.json', 
              height: 250,
              width: 250,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text("Error loading $approved Od-Pass"),
          ],
        ),
      );
    }
    else if (!snapshot.hasData || snapshot.data!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/image/Animation.json', 
              height: 200,
              width: 200,
              fit: BoxFit.fill,
            ),
            const SizedBox(height: 16),
            Text("No $approved Od-Pass", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          ],
        ),
      );
    }

        final odPass = snapshot.data!;
        return ListView.builder(
          itemCount: odPass.length,
          itemBuilder: (context, index) {
            final leave = odPass[index];
            return GestureDetector(
            onLongPress: () {
              if(approved == "pending") {
              setState(() {
                selectionMode = true;
                selectedLeaves.add(leave['id'].toString());
              });
            }
            },
            onTap: () {
               if (approved == "pending" && selectionMode) {
                setState(() {
                  final id = leave['id'].toString();
                  if (selectedLeaves.contains(id)) {
                    selectedLeaves.remove(id);
                    if (selectedLeaves.isEmpty) selectionMode = false;
                  } else {
                    selectedLeaves.add(id);
                  }
                });
              } else {
                Navigator.push(
                  context,
                   MaterialPageRoute(
                      builder:
                          (context) => OdDetailsPage(
                            emUsername: leave['empname'],
                            departmentName: leave['dep_name'],
                            compFname: leave['compname'],
                            fromDate: leave['fromdate'],
                            toDate: leave['todate'],
                            remark: leave['remark'],
                            rejectreason: leave['rejectreason'],
                            approved: leave['approval_status'],
                            approval_by: leave['approval_by'],
                            approval_at: leave['approval_at'],
                            date: leave['add_date_formatted'],
                            oddays: leave['oddays'],
                            id: leave['id'].toString(),
                          ),
                    ),
                );
              }
            },
            child: Card(
              margin: EdgeInsets.all(10),
             color:Theme.of(context).brightness == Brightness.light ? Color(0xFFF2F5F8) : Colors.grey.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
              child: ListTile(
                leading: (approved == "pending" && selectionMode)
          ? Icon(
              selectedLeaves.contains(leave['id'].toString())
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: selectedLeaves.contains(leave['id'].toString())
                  ? Colors.blue
                  : Colors.grey,
            )
          : Icon(Icons.event_note, color: Colors.blue),
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
              ),
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
  final String approval_by;
  final String approval_at;
  final String oddays;
  final String id;
  final String rejectreason;

  const OdDetailsPage({
    super.key,
    required this.emUsername,
    required this.departmentName,
    required this.compFname,
    required this.fromDate,
    required this.toDate,
    required this.remark,
    required this.approved,
    required this.approval_by,
    required this.approval_at,
    required this.date,
    required this.oddays,
    required this.id,
    required this.rejectreason,
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
  final apiToken = dotenv.env['ACCESS_TOKEN'];
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
           final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
                ? const ColorScheme.dark(
                    primary: Color(0xFF3C3FD5),
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF3C3FD5),
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                  ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3C3FD5),
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

      final token = await UserSession.getToken();

      if(token == null){
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final empId = await UserSession.getUserId();

      if(isSubmitting) return;

      setState(() {
        isSubmitting = true;
      });

      final id = (widget.id);
      print('OD-Pass ID: $id');

      final leaveDuration = calculateDuration(fromDate, toDate);
      // final int odType = leaveDuration <= 1.0 ? 1 : 2;

      print('Leave Duration: $leaveDuration');
      print('base url: $baseUrl');

      final DateFormat apiFormat = DateFormat('yyyy-MM-dd');

      final fromDateStr = apiFormat.format(fromDate);
      final toDateStr = apiFormat.format(toDate);

      print('From Date: $fromDateStr');
 
    if (baseUrl == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("API base URL is not configured.")),
    );
    return;
  }
    try {
    final url = Uri.parse('$baseUrl/MyApis/odpasstheedit?id=$id');

    print("url: $url");

      final response = await http.patch(
        url,
        headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiToken',
        'auth_token': token,
        'user_id': empId!,
        },
        body: jsonEncode({
          'from_date': fromDateStr,
          'to_date': toDateStr,
          'remark': remarkController.text,
          'od_type': leaveDuration.toString(),
          // 'od_type': odType.toString(),
        }),
      );

     final decode = jsonDecode(response.body);
      print(decode);

      if (response.statusCode == 200) {
        showCustomSnackBar(
          context,
          "Od Pass submitted successfully",
          Colors.green,
          Icons.check_circle,
        );
      } else {
        final error = jsonDecode(response.body);
        showCustomSnackBar(
          context,
          "${error['message']}",
          Colors.red,
          Icons.error,
        );
      }
    } catch (e) {
      showCustomSnackBar(context, 'Unexpected error format', Colors.red, Icons.error);
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }


//  void showCustomSnackBar(BuildContext context, String message, Color color, IconData icon) {

//   final scaffoldMessenger = ScaffoldMessenger.of(context);

//   scaffoldMessenger.clearSnackBars();

//     final snackBar = SnackBar(
//       content: Row(
//         children: [
//           Icon(icon, color: Colors.white),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ),
//         ],
//       ),
//       backgroundColor: color,
//       behavior: SnackBarBehavior.floating,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       margin: const EdgeInsets.all(16),
//       duration: const Duration(seconds: 2),
//     );

//     ScaffoldMessenger.of(context).showSnackBar(snackBar);
//   }


  @override

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final isApproved = widget.approved.toLowerCase() == 'approved';
    final isRejected = widget.approved.toLowerCase() == 'rejected';
    final bool isReadOnly = isApproved || isRejected;

    return Scaffold(
      extendBodyBehindAppBar: true,
       backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      appBar: AppBar(
        title: const Text('On-Duty Details',
        style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
       foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
      ),
      body: Stack(
        children: [ 
      Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
              gradient: Theme.of(context).brightness == Brightness.dark
                  ? const LinearGradient(
                      colors: [Color(0xFF121212), Color(0xFF121212)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)], 
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
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
                     color:Theme.of(context).brightness == Brightness.light ? Color(0xFFF2F5F8) : Colors.grey.shade900,
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
                           _editableDateField(context,"From", fromDate, () => _pickDate(context, true),isReadOnly: isReadOnly),
                          _editableDateField(context,"To", toDate, () => _pickDate(context, false),isReadOnly: isReadOnly),

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
                                dropdownColor: Theme.of(context).canvasColor,
                                items:
                              ['Full Day', 'Half Day']
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ),
                                  )
                                  .toList(),
                                onChanged: isReadOnly
                                ? null
                                : (val) {
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
                            readOnly: isReadOnly,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: "Enter reason for OD...",
                            ),
                            validator: (val) => val == null || val.isEmpty ? "Remark required" : null,
                          ),

                            const SizedBox(height: 10),

                            if(isApproved) ...[
                              const SizedBox(height: 12),
                            Text(
                              'Approved By',
                              style: theme.textTheme.titleSmall?.copyWith(
                                // color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.approval_by,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
                          ),
                        ),
                              const SizedBox(height: 12),
                            Text(
                              'Approved At',
                              style: theme.textTheme.titleSmall?.copyWith(
                                // color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.approval_at,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
                          ),
                        ),
                            ],

                            if(isRejected &&  widget.rejectreason.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Reject Reason',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  // color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.05),
                                  border: Border.all(color: Colors.red.shade200),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.rejectreason,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Text(
                              'Rejected By',
                              style: theme.textTheme.titleSmall?.copyWith(
                                // color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.approval_by,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                          ),
                        ),
                            const SizedBox(height: 12),
                            Text(
                              'Rejected At',
                              style: theme.textTheme.titleSmall?.copyWith(
                                // color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.approval_at,
                            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                          ),
                        ),

                            ],

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
                                foregroundColor: Colors.black87,
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
      // color: Colors.black,
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
                // color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                // color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _editableDateField(BuildContext context, String label, DateTime date, VoidCallback onTap,{bool isReadOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: InkWell(
        onTap: isReadOnly ? null : onTap,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                "$label:",
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.grey.shade50,
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
