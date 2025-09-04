import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart'; 
import 'package:top_snackbar_flutter/top_snack_bar.dart';

class LeaveStatusPage extends StatefulWidget {
  const LeaveStatusPage({super.key});

  @override
  _LeaveStatusPageState createState() => _LeaveStatusPageState();
}

class _LeaveStatusPageState extends State<LeaveStatusPage>
    with TickerProviderStateMixin {

  List<Map<String, dynamic>> leaveTypes = [];
  dynamic selectedTypeId;
  late TabController _tabController;
  String? emUsername;
  String? compFname;
  String? rejectedReason;
  String? departmentName;
  int initialTabIndex = 0;
  bool _isControllerInitialized = false;
  Set<String> selectedLeaves = {};
  bool selectionMode = false;

  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  late Future<List<Map<String, dynamic>>> _pendingLeavesFuture;
  late Future<List<Map<String, dynamic>>> _approvedLeavesFuture;
  late Future<List<Map<String, dynamic>>> _rejectedLeavesFuture;


  @override

  void initState() {
    super.initState();
    fetchLeaveTypes();

    Future.microtask(() {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
      initialTabIndex = args['tabIndex'] ?? 0;
      selectedTypeId = int.tryParse(args['leaveTypeId']?.toString() ?? '');

      print('Initial Tab Index: $initialTabIndex, Leaves Type ID: $selectedTypeId');
    }
        _tabController = TabController(length: 3, vsync: this, initialIndex: initialTabIndex);
        
      setState(() {
        _isControllerInitialized = true;
      });
    });

    _pendingLeavesFuture = fetchLeaves("pending");
    _approvedLeavesFuture = fetchLeaves("approved");
    _rejectedLeavesFuture = fetchLeaves("rejected");
    
  }

 String formattedDate(String date) {
  return DateFormat('dd-MM-yyyy').format(DateTime.parse(date));
 }

  Future<void> fetchLeaveTypes() async {

    final _token = await UserSession.getToken();

      if (_token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
  
    final _empId = await UserSession.getUserId();
    
    try {
     final response = await http.get(Uri.parse('$baseUrl/MyApis/leavethetypes?user_id=$_empId'),
      headers: {
       'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': _token,
        },
     );


     await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data_packet'];
        // print('Leave Types: $data');
        // print('Leave Types I.d,${data[0]['type_id']}');
        setState(() {
          leaveTypes = [
          {'type_id': null, 'name': 'All'},
          ...data.map<Map<String, dynamic>>((e) => {
            'type_id': int.tryParse(e['type_id']?.toString() ?? ''),
            'name': e['name']
          }),
        ];
             
        selectedTypeId ??= leaveTypes[0]['type_id'];

        });
      } else {
        print('Failed to load leave types');
      }
    } catch (e) {
      print('Error fetching leave types: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchLeaves(String status) async {
    try {
      
      final _token = await UserSession.getToken();

      if (_token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return Future.value([]);
    }

      final _emId = await UserSession.getUserId();

      final statusMap = {
        'pending': 'Not Approve',
        'approved': 'Approve',
        'rejected': 'Rejected',
      };

      final apiStatus = statusMap[status.toLowerCase()];
      print('API Status: $apiStatus');

      final queryParams = {
        'fetch_type': 'SELF',
        'leave_status': apiStatus,
      };

      if(selectedTypeId != null) {
        queryParams['leave_type_id'] = selectedTypeId.toString();
      }

      final url = Uri.parse(
        '$baseUrl/MyApis/leavetherecords?').replace(queryParameters: queryParams,
      );
        // print('API URL: $url');

        final response = await http.get(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': _token,
          'user_id': _emId!,
        },
        );

       await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

        if (response.statusCode == 200) {

        final decoded = json.decode(response.body);
        print('Leaves: $decoded');

        final List<dynamic> dataList = decoded['data_packet'];
        // final List<Map<String, dynamic>> userInfo = decoded['user_details'];

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


//   for single delete at time

  //   Future<void> deleteLeave(String leaveId) async {
  //   try {
  //     final _token = await UserSession.getToken();
  //     final _empId = await UserSession.getUserId();

  //     if (_token == null) {
  //       Navigator.pushReplacementNamed(context, '/login');
  //       return;
  //     }

  //     final url = Uri.parse('$baseUrl/MyApis/leavethedelete?id=$leaveId');
      
  //     print('  URL: $url');

  //     final response = await http.patch(
  //       url,
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $apiToken',
  //         'auth_token': _token,
  //         'user_id': _empId!,
  //       },
  //     );

  //     await UserSession.checkInvalidAuthToken(
  //       context,
  //       json.decode(response.body),
  //       response.statusCode,
  //     );

  //     if (response.statusCode == 200) {
  //       showCustomSnackBar(
  //         context,
  //         "Leave deleted successfully",
  //         Colors.green,
  //         Icons.check_circle,
  //       );
  //       _refreshData(); 
  //     } else {
  //       print('Failed to delete leave: ${response.body}');
  //       showCustomSnackBar(
  //         context,
  //         "Failed to delete leave",
  //         Colors.red,
  //         Icons.error,
  //       );
  //     }
  //   } catch (e) {
  //     showCustomSnackBar(
  //       context,
  //       "Error: $e",
  //       Colors.red,
  //       Icons.error,
  //     );
  //   }
  // }


  Future<bool> deleteLeave(String leaveId) async {
  try {
    final _token = await UserSession.getToken();
    final _empId = await UserSession.getUserId();

    if (_token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    final url = Uri.parse('$baseUrl/MyApis/leavethedelete?id=$leaveId');

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
      // showCustomSnackBar(context, "Leave deleted successfully", Colors.green, Icons.check_circle);
      _refreshData();
      return true;
    } else {
      print('Failed to delete leave: ${response.body}');
      showCustomSnackBar(context, "Failed to delete leave", Colors.red, Icons.error);
      return false;
    }
  } catch (e) {
    showCustomSnackBar(context, "Error: $e", Colors.red, Icons.error);
    return false;
  }
}

 Future<void> deleteMultipleLeaves(List<String> leaveIds) async {
  int successCount = 0;

  print('sccesscount,$successCount');

  for (String id in leaveIds) {
    bool success = await deleteLeave(id);

    print('sccesscount1,$success');
    if (success) successCount++;
  }

  if (mounted) {
    setState(() {
      _pendingLeavesFuture = fetchLeaves("pending");
      selectionMode = false;
      selectedLeaves.clear();
    });

    if (successCount > 0) {
      showCustomSnackBar(
        context,
        "$successCount leave(s) deleted successfully",
        Colors.green,
        Icons.check_circle,
      );
    } else {
      showCustomSnackBar(
        context,
        "Failed to delete selected leave(s)",
        Colors.red,
        Icons.error,
      );
      print("Failed to delete selected leave(s),$e");
    }
  }
}


  Future<void> _refreshData() async {
  await fetchLeaveTypes();
  setState(() {}); 
}

Future<void> _confirmDelete(List<String> leaveIds) async {
  bool isDeleting = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  "Delete Leave(s)?",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Leave has deleted parmanently from your device.you can't restore them once deleted.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // TextButton(
                    //   onPressed: isDeleting
                    //       ? null
                    //       : () {
                    //           Navigator.pop(context);
                    //         },
                    //   child: const Text("Cancel"),
                    // ),
                    // const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: isDeleting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child:CircularProgressIndicator(color: Theme.of(context).iconTheme.color,)
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
                                await deleteMultipleLeaves(leaveIds);
                                if (mounted) {
                                  Navigator.pop(context);

                                  setState(() {
                                    _pendingLeavesFuture =
                                        fetchLeaves("pending");
                                    selectionMode = false;
                                    selectedLeaves.clear();
                                  });

                                  // ScaffoldMessenger.of(context).showSnackBar(
                                  //   const SnackBar(
                                  //     content:
                                  //         Text("Leave(s) deleted successfully"),
                                  //     backgroundColor: Colors.green,
                                  //   ),
                                  // );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isDeleting = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Failed to delete leave(s): $e"),
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
          title: selectionMode
          ?  Text(
              "${selectedLeaves.length} Selected",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            )
          : Row(
              children: [
                 Text(
                  "Leave History",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
          ),
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
              icon: Icon(FontAwesomeIcons.trashCan),
              onPressed: () async {
              if (selectedLeaves.isNotEmpty) {
              _confirmDelete(selectedLeaves.toList());
            }
              },
            ),
          ]
        : [],
        forceMaterialTransparency: true,
        foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
          elevation: 4,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: leaveTypes.length,
                separatorBuilder: (_, __) => SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final type = leaveTypes[index];

                  final List<Map<String, dynamic>> allLeaveTypes = [
                    {'type_id': null, 'name': 'All'},
                    ...leaveTypes,
                  ];

                  final isSelected = int.tryParse(type['type_id']?.toString() ?? '') == selectedTypeId;

                  return ChoiceChip(
                    label: Text(type['name']),
                    selected: isSelected,
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800] 
                  : const Color(0xFFF5F7FA),
                    onSelected: (_) {
                      setState(() {
                        selectedTypeId = type['type_id'];
                      });
                    },
                    selectedColor: Colors.blue.shade400,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                  );
                },
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: Color(0XFF00A8CC),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: "Pending"),
                Tab(text: "Approved"),
                Tab(text: "Rejected"),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    color: Theme.of(context).iconTheme.color,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    child: buildLeaveList("pending", selectedTypeId),
                  ),
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    color: Theme.of(context).iconTheme.color,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    child: buildLeaveList("approved", selectedTypeId),
                  ),
                  RefreshIndicator(
                    onRefresh: _refreshData,
                    color: Theme.of(context).iconTheme.color,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    child: buildLeaveList("rejected", selectedTypeId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color getCardColor(BuildContext context, bool isSelected) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isSelected) {
    return isDark ? const Color(0xFF2A2D3E) : const Color(0xFFE4EBF5);
  } else {
    return isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF5F7FA);
  }
}


    Widget buildLeaveList(String status, int? selectedTypeId) {

      final future = status == "pending"
        ? _pendingLeavesFuture
        : status == "approved"
            ? _approvedLeavesFuture
            : _rejectedLeavesFuture;


      return FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: Theme.of(context).iconTheme.color,));
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading $status leaves"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No $status leaves."));
          }

             final allLeaves = snapshot.data!;
      
      final filteredLeaves = selectedTypeId == null
          ? allLeaves
          : allLeaves.where((leave) => int.tryParse(leave['typeid']?.toString() ?? '') == selectedTypeId
        ).toList();

      if (filteredLeaves.isEmpty) {
        return Center(child: Text("No $status leaves for this type."));
      }

        return ListView.builder(
          itemCount: filteredLeaves.length,
          itemBuilder: (context, index) {
          final leave = filteredLeaves[index];

          return GestureDetector(
            onLongPress: () {
              if(status == "pending") {
              setState(() {
                selectionMode = true;
                selectedLeaves.add(leave['id'].toString());
              });
            }
            },
            onTap: () {
               if (status == "pending" && selectionMode) {
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
                    builder: (context) => LeaveDetailPage(
                      leave: leave,
                      rejectedReason: leave['rejected_reason'] ?? '',
                    ),
                  ),
                );
              }
            },
            
            child: Card(
            margin: EdgeInsets.all(10),
            color: getCardColor(context, selectedLeaves.contains(leave['id'].toString())),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
             child: ListTile(
              leading: (status == "pending" && selectionMode)
          ? Icon(
              selectedLeaves.contains(leave['id'].toString())
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: selectedLeaves.contains(leave['id'].toString())
                  ? Colors.blue
                  : Colors.grey,
            )
          : Icon(Icons.event_note, color: Colors.blue),
            title: Text("${leave['start_date_formatted']} → ${leave['end_date_formatted']}"),
            subtitle: Text(leave['reason']),
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
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }
}

class LeaveDetailPage extends StatefulWidget {
  final Map<String, dynamic> leave;
  final String rejectedReason;

  const LeaveDetailPage({
    super.key,
    required this.leave,
    required this.rejectedReason,
  });

  @override
  _LeaveDetailPageState createState() => _LeaveDetailPageState();
}

class _LeaveDetailPageState extends State<LeaveDetailPage> {
  late DateTime fromDate, toDate;
  late TextEditingController reasonController;
  File? _attachmentFile;
  TextEditingController attachmentController = TextEditingController();
  late String leaveDayType;
  String? _emId;
  String? _token;
  List<Map<String, dynamic>> leaveTypes = [];
  int? selectedLeaveType;
  double leaveDuration = 1.0;
  final apiToken =  dotenv.env['ACCESS_TOKEN'];
  final baseUrl = dotenv.env['API_BASE_URL'];
  bool isSubmitting = false;

  bool get hasAttachment =>
      widget.leave['leaveattachment'] != null &&
      widget.leave['leaveattachment'].toString().isNotEmpty;

  @override
  void initState(){
    super.initState();
    fromDate = DateTime.parse(widget.leave['start_date']);
    toDate = DateTime.parse(widget.leave['end_date']);
    reasonController = TextEditingController(text: widget.leave['reason']);

    if (hasAttachment) {
      _attachmentFile = File(widget.leave['leaveattachment'].toString());
    } else {
      _attachmentFile = null;
    }

    final duration = widget.leave['leave_duration'];
    leaveDayType =
        (duration == 0.5 || duration.toString() == '0.5')
            ? 'Half Day'
            : 'Full Day';

    selectedLeaveType = int.tryParse(widget.leave['leave_type_name'].toString());

    print('leaveTypeInfo: ${widget.leave['leave_type_name']}');
  _initializeSession();
  }

  double calculateDuration(DateTime from, DateTime to) {
    if (from.isAfter(to)) {
      return -1;
    }

    if (leaveDayType == 'Half Day') {
      if (from.isAtSameMomentAs(to)) {
        return 0.5;
      } else {
        return (to.difference(from).inDays + 1);
      }
    } else {
      return to.difference(from).inDays + 1;
    }
  }

  Future<void> _initializeSession() async {
    _token = await UserSession.getToken();

    print("token:- $_token");

    if (_token != null) {
      _emId = await UserSession.getUserId();
    }else {
      Navigator.pushReplacementNamed(context, '/login');
    }
    _emId = await UserSession.getUserId();
    await fetchLeaveTypes();
  }

  Future<void> selectDate(BuildContext context, bool isFromDate) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: isFromDate ? fromDate : toDate,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
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

  if (picked == null) return;

  // final pickedDateOnly = DateTime(picked.year, picked.month, picked.day);
  // final fromDateOnly = DateTime(fromDate.year, fromDate.month, fromDate.day);
  // final toDateOnly = DateTime(toDate.year, toDate.month, toDate.day);


setState(() {
  if (isFromDate) {
    fromDate = picked;

    if (fromDate.isAfter(toDate)) {
      toDate = fromDate;
      _showCustomSnackBar(
        context,
        "End date adjusted to match start date",
        Colors.blueAccent.shade200,
        'assets/image/Animation1.json',
      );
    }
  } else {
    toDate = picked;

    if (toDate.isBefore(fromDate)) {
      fromDate = toDate;
      _showCustomSnackBar(
        context,
        "Start date adjusted to match end date",
        Colors.blueAccent.shade200,
        'assets/image/Animation1.json',
      );
    }
  }

  leaveDuration = calculateDuration(fromDate, toDate);
});

} 

  Future<void> fetchLeaveTypes() async {
    if (leaveTypes.isNotEmpty) return;

    if (leaveDuration == -1) {
      _showCustomSnackBar(
        context,
        'Invalid date range',
        Colors.red,
        'assets/image/Animation4.json',
      );
      return;
    }
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/MyApis/leavethetypes?user_id=$_emId'),
       headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': _token!,
        },
     );

   final jsonData = json.decode(response.body);

   print("response from page:- $jsonData");

     await UserSession.checkInvalidAuthToken(
            context,
            json.decode(response.body),
            response.statusCode,
          );

      if (response.statusCode == 200) {
        if(jsonData['data_packet'] != null && jsonData['data_packet'] is List){
       final fetchedTypes = (jsonData['data_packet'] as List)
      .map((item) => {
      'id': int.tryParse(item['type_id'].toString()) ?? 0,
      'label': "${item['name']} (${item['leave_short_name']})"
    })
    .toList();

    String leaveTypeName = widget.leave['leave_type_name'].toString();

    final matchedType = fetchedTypes.firstWhere(
      (type) => type['label'] == leaveTypeName,
      orElse: () => {},
    );

    setState(() {
      leaveTypes = fetchedTypes;
      selectedLeaveType = matchedType['id'] as int?;
    });
 }
      } else {
        print("Failed to load leave types");
      }
    } catch (e) {
      print("Error fetching leave types: $e");
    }
  }

  Future<void> updateLeaveDetails() async {

    if(isSubmitting) return;

    setState(() {
      isSubmitting = true;
    });

    final leaveId = widget.leave['id'];
    print('Leave ID: $leaveId');

    final reason = reasonController.text;

    final leaveDuration = calculateDuration(fromDate, toDate);
    print('Leave Duration: $leaveDuration');

    final file = _attachmentFile;
    if (file == null) {
      print("No file selected");
    }

    try {
      final uri = Uri.parse('$baseUrl/MyApis/leavetheedit?id=$leaveId');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $apiToken';
      request.headers['Accept'] = 'application/json';
      request.headers['auth_token'] = _token!;
      request.headers['user_id'] = _emId!;


      request.fields['reason'] = reason;
      request.fields['from_date'] = DateFormat('yyyy-MM-dd').format(fromDate);

      print('fromDate: $fromDate');
      print('toDate: $toDate');

      request.fields['to_date'] = DateFormat('yyyy-MM-dd').format(toDate);
      request.fields['leave_type'] = leaveDayType;
      print('leaveDayType: $leaveDayType');

      if (selectedLeaveType != null) {
        request.fields['leave_type_id'] = selectedLeaveType.toString();

        print('leaveTypeId: $selectedLeaveType');
      }
      

      if (_attachmentFile != null && File(_attachmentFile!.path).existsSync()) {
       {

        final mimeType = lookupMimeType(_attachmentFile!.path);
        final mediaType = mimeType != null
        ? MediaType.parse(mimeType)
        : MediaType('application', 'octet-stream');

        
        request.files.add(
          await http.MultipartFile.fromPath(
            'leaveattachment',
            _attachmentFile!.path,
            filename: _attachmentFile!.path.split('/').last,
            contentType: mediaType,
          ),
        );
      }
    }
      final response = await request.send();
      print('Status: ${response.statusCode}');
      print('Response: ${response.reasonPhrase}');
      final responseBody = await response.stream.bytesToString();

       await UserSession.checkInvalidAuthToken(
            context,
            json.decode(responseBody),
            response.statusCode,
          );


      if (response.statusCode == 200) {
        _showCustomSnackBar(
          context,
          'Leave details updated successfully',
          Colors.green,
          'assets/image/Animation0.json',
        );
        
        setState(() {
        widget.leave['reason'] = reason;
        widget.leave['start_date'] = fromDate.toIso8601String();
        widget.leave['end_date'] = toDate.toIso8601String();
        // widget.leave['leave_duration'] = leaveDuration;
        widget.leave['leave_type_name'] = selectedLeaveType;
        
        if (_attachmentFile != null) {
          widget.leave['leaveattachment'] = _attachmentFile!.path;
        }
      });

      } else {
        final error = jsonDecode(responseBody);
        _showCustomSnackBar(
          context,
          "${error['message']}",
          Colors.red,
          'assets/image/Animation4.json',
        );
      }
    } catch (e) {
      print('Error updating leave details: $e');
      _showCustomSnackBar(
        context,
        'Failed to update leave details',
        Colors.red,
        'assets/image/Animation4.json',
      );
    }finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

  Future<void> _refreshData() async {
    widget.leave['reason'] = reasonController.text;
    widget.leave['start_date'] = fromDate.toIso8601String();
    widget.leave['end_date'] = toDate.toIso8601String();
    widget.leave['leave_duration'] = leaveDuration;
    widget.leave['leave_type_name'] = selectedLeaveType;
    widget.leave['leaveattachment'] = _attachmentFile?.path;
  }

  Future<void> _refreshPage() async {
    await fetchLeaveTypes();
    _refreshData();
    setState(() {});
  }

  void _showCustomSnackBar(BuildContext context, String message, Color bgColor, String LottiePath){
  showTopSnackBar(
    Overlay.of(context),
    Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Lottie.asset(LottiePath, repeat: true, height: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    displayDuration: const Duration(seconds: 2),
    dismissType: DismissType.onTap,
    dismissDirection: [DismissDirection.up], 
  );
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isApproved = widget.leave['leave_status']?.toLowerCase() == 'approve';
    final isRejected =
        widget.leave['leave_status']?.toLowerCase() == 'rejected';
    final hasAttachment =
        widget.leave['leaveattachment'] != null &&
        widget.leave['leaveattachment'] != '';

    final bool isReadOnly = isApproved || isRejected;

    // print('Leave Reject: ${widget.leave['rejected_reason']}');

   return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      extendBody: true,
      appBar: AppBar(
       backgroundColor: Colors.transparent, 
        title: const Text(
          "Leave Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87,
        forceMaterialTransparency: true,
      ),
   
     body:Stack( 
     children: [
      Container(
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
      child: RefreshIndicator(
        onRefresh: _refreshPage,  
        color: Colors.black,
        backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), 
        padding: const EdgeInsets.all(16.0),
        child: Card(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Color(0xFFFDFDFD),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                    widget.leave['leave_status']?.toUpperCase() ?? 'PENDING',
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: selectedLeaveType,
                            hint: Text(
                              "Select Leave Type",
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.brightnessOf(context) == Brightness.dark
                                    ? Colors.white
                                    : Colors.black45,
                              ),
                            ),
                            iconSize: 22,
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.brightnessOf(context) == Brightness.dark
                                    ? Colors.white
                                    : Colors.black54,
                            ),
                            items:
                                leaveTypes.map((type) {
                                  return DropdownMenuItem<int>(
                                    value: type['id'],
                                    child: Text(
                                      type['label'],
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                            onChanged:
                                (isApproved || isRejected)
                                    ? null
                                    : (value) {
                                      setState(() {
                                        selectedLeaveType = value;
                                      });
                                    },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 32),
                Text(
                'Employee Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  // color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.person_outline,
                  title: 'Username',
                  value: widget.leave['empname'],
                ),
                _buildDetailRow(
                  icon: Icons.work_outline,
                  title: 'Department',
                  value: widget.leave['dep_name'],
                ),
                _buildDetailRow(
                  icon: Icons.business_outlined,
                  title: 'Company',
                  value: widget.leave['compname'],
                ),
                const Divider(height: 32),
                Text(
                  'Leave Dates',
                  style: theme.textTheme.titleSmall?.copyWith(
                    // color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailRow(
                        icon: Icons.date_range_outlined,
                        title: 'From',
                        value: ("${fromDate.toLocal()}".split(' ')[0]),
                        onTap: () => isReadOnly ? null : selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailRow(
                        icon: Icons.date_range_outlined,
                        title: 'To',
                        value: "${toDate.toLocal()}".split(' ')[0],
                        onTap: () => isReadOnly ? null : selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                _buildDetailRow(
                  icon: Icons.timer_outlined,
                  title: 'Duration',
                  value: '${calculateDuration(fromDate, toDate)} days',
                ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 8),
                      const Text('Leave Type: '),
                      const SizedBox(width: 8),
                      if (fromDate.difference(toDate).inDays.abs() == 0)
                      DropdownButton<String>(
                        value: leaveDayType,
                        items: ['Full Day', 'Half Day']
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                ))
                            .toList(),
                        onChanged: isReadOnly
                            ? null
                            : (val) {
                                setState(() {
                                  leaveDayType = val!;
                                  leaveDuration = calculateDuration(fromDate, toDate);
                                });
                              },
                      )
                    else
                      Text(
                        'More than one day',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),

                const Divider(height: 32),
                Text(
                  'Reason',
                  style: theme.textTheme.titleSmall?.copyWith(
                    // color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  readOnly: isReadOnly,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Leave Reason',
                    border: OutlineInputBorder(),
                    fillColor: isReadOnly ?  Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[100]
                    : null,
                    filled: isReadOnly,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Leave Attachment',
                  style: theme.textTheme.titleSmall?.copyWith(
                    // color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                if (_attachmentFile == null && !hasAttachment)
                Text(
                  'No file selected',
                  style: theme.textTheme.bodyMedium,
                ),

                // const SizedBox(height: 8),
                if(!isReadOnly) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Select File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFE4EBF5),
                    foregroundColor: Colors.black87,
                  ),
                
                  onPressed:
                      (isApproved || isRejected)
                          ? null
                            : () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'doc', 'docx','jpg','png'],
                              withData: false
                            );
                            if (result != null && result.files.single.path != null) {
                            final file = File(result.files.single.path!);
                            final fileSizeInMB = await file.length() / (1024 * 1024);
  
                            if (fileSizeInMB > 10) {
                          _showCustomSnackBar(
                            context,
                            'File must be less than 10MB (${fileSizeInMB.toStringAsFixed(2)} MB)',
                            Colors.orange.shade700,
                            'assets/image/Animation1.json',
                          );
                          return;
                        }

                        setState(() {
                          _attachmentFile = file;
                          attachmentController.text = file.path;
                        });
                      }
                    },
                  ),
                ],

                if (hasAttachment) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final fileUrl = widget.leave['leaveattachment'];

                      if (fileUrl == null || fileUrl.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No attachment found')),
                        );
                        return;
                      }
                      print('Attachment: ${widget.leave['leaveattachment']}');

                      try {
                        final fileName = Uri.parse(fileUrl).pathSegments.last;
                        final dir = await getTemporaryDirectory();
                        final filePath = '${dir.path}/$fileName';

                        await Dio().download(fileUrl, filePath);
                        final result = await OpenFilex.open(filePath);
                        if (result.type != ResultType.done) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not open attachment'),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Download/open error: $e');
                        _showCustomSnackBar(context, 'Failed to open attachment', Colors.red.shade400, 'assets/image/Animation4.json');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Open Attachment',
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.download,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

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
                    widget.leave['approval_by'],
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
                    widget.leave['approval_at'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
                  ),
                ),
                ],
                
                if (isRejected && widget.leave['reject_reason'] != null && widget.leave['reject_reason'].toString().isNotEmpty) ...[
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
                    widget.leave['reject_reason'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Reject By',
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
                    widget.leave['approval_by'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                  ),
                ),

                const SizedBox(height: 12),
                 Text(
                  'Reject at',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.black,
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
                    widget.leave['approval_at'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                  ),
                ),
              ],

                if (!isApproved && !isRejected) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed:
                        (leaveDuration == -1 || isSubmitting)
                            ? null
                            : () async {
                              await updateLeaveDetails();
                            },
                    icon: const Icon(Icons.update),
                    label: const Text('Update'),       
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      iconColor: Colors.black87,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
//                       child: isSubmitting
//       ? Row(
//           mainAxisSize: MainAxisSize.min,
//           children: const [
//             SizedBox(
//               height: 20,
//               width: 20,
//               child: CircularProgressIndicator(
//                 strokeWidth: 2,
//                 color: Colors.black87,
//               ),
//             ),
//             SizedBox(width: 12),
//             Text(
//               'Updating...',
//               style: TextStyle(color: Colors.black87),
//             ),
//           ],
//         )
//       : Row(
//           mainAxisSize: MainAxisSize.min,
//           children: const [
//             Icon(Icons.update, color: Colors.black87),
//             SizedBox(width: 8),
//             Text('Update'),
        //   ],
        // ),
),


                ],
              ],
            ),
          ),
        ),
      ),
    ),
  ),
  if(isSubmitting)
  Container(
    color: Colors.black87.withOpacity(0.5),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            'Updating Leave...',
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
 ],
)
  );
}

  Widget _buildDetailRow({
    required IconData icon,
    required String title,
    required String value,
    void Function()? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onTap,
                  child: Text(value, style: TextStyle(
                    // color: Colors.black87
                    )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}