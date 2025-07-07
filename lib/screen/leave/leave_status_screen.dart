import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  final baseUrl = dotenv.env['API_BASE_URL'];


  @override

  void initState() {
    super.initState();
    fetchLeaveTypes();

    Future.microtask(() {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

       if (args != null) {
      initialTabIndex = args['tabIndex'] ?? 0;
      selectedTypeId = args['leavesTypeId'];
    }
        _tabController = TabController(length: 3, vsync: this, initialIndex: initialTabIndex);
        
      setState(() {
        _isControllerInitialized = true;
      });
    });
    
  }
  

  Future<void> fetchLeaveTypes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/leave-type/list'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // print('Leave Types: $data');
        // print('Leave Types I.d,${data[0]['type_id']}');
        setState(() {
          leaveTypes = [{'type_id': null, 'name': 'All'}, ...data.cast<Map<String, dynamic>>()];
          
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
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final decodedToken = Jwt.parseJwt(token);
      final emUsername = decodedToken['em_username'];
      // final compFname = decodedToken['comp_fname'];
      // final departmentName = decodedToken['dep_name'];

      print('Employee Username: $emUsername');
      // print('Company Name: $compFname');
      // print('Department Name: $departmentName');

      final statusMap = {
        'pending': 'Not Approve',
        'approved': 'Approve',
        'rejected': 'Rejected',
      };

      final apiStatus = statusMap[status.toLowerCase()];
      print('API Status: $apiStatus');

      final queryParams = {
        'em_username': emUsername,
        'status': apiStatus,
      };

      if(selectedTypeId != null) {
        queryParams['leave_type_id'] = selectedTypeId.toString();
      }

      final url = Uri.parse(
        '$baseUrl/api/emp-leave/list/').replace(queryParameters: queryParams,
      );
        print('API URL: $url');

        final response = await http.get(url);

        if (response.statusCode == 200) {

        final decoded = json.decode(response.body);
        print('Leaves: $decoded');

        final List<dynamic> dataList = decoded['leaves'];

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

  Future<void> _refreshData() async {
  await fetchLeaveTypes();
  setState(() {}); 
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
        title: Text("Leave Status",
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
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
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

                final isSelected = type['type_id'] == selectedTypeId;
                
                return ChoiceChip(
                  label: Text(type['name']),
                  selected: isSelected,
                  backgroundColor: Color(0xFFF5F7FA),
                  onSelected: (_) {
                    setState(() {
                      selectedTypeId = type['type_id'];
                    });
                  },
                  selectedColor: Colors.blue.shade400,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
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
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  child: buildLeaveList("pending"),
                ),
                RefreshIndicator(
                  onRefresh: _refreshData,
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  child: buildLeaveList("approved"),
                ),
                RefreshIndicator(
                  onRefresh: _refreshData,
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  child: buildLeaveList("rejected"),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget buildLeaveList(String status) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchLeaves(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator( color: Colors.black,));
        } else if (snapshot.hasError) {
          return Center(child: Text("Error loading $status leaves"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No $status leaves."));
        }

        final leaves = snapshot.data!;
        return ListView.builder(
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            final leave = leaves[index];
            return Card(
              margin: EdgeInsets.all(10),
              color:Color(0xFFF5F7FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: ListTile(
                leading: Icon(Icons.event_note, color: Colors.blue),
                title: Text("${leave['start_date']} → ${leave['end_date']}"),
                subtitle: Text(leave['reason']),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      // backgroundColor: Colors.transparent,
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
                          (context) => LeaveDetailPage(
                            leave: leave,
                            emUsername: emUsername ?? '',
                            departmentName: departmentName ?? '',
                            compFname: compFname ?? '',
                            rejectedReason: leave['rejected_reason'] ?? '',
                      ),
                    ),
                  );
                },
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

class LeaveDetailPage extends StatefulWidget {
  final Map<String, dynamic> leave;
  final String emUsername;
  final String departmentName;
  final String compFname;
  final String rejectedReason;

  const LeaveDetailPage({
    super.key,
    required this.leave,
    required this.emUsername,
    required this.departmentName,
    required this.compFname,
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
  List<String> leaveTypes = [];
  String? selectedLeaveType;
  double leaveDuration = 1.0;
  final baseUrl = dotenv.env['API_BASE_URL'];
  bool isSubmitting = false;

  bool get hasAttachment =>
      widget.leave['leaveattachment'] != null &&
      widget.leave['leaveattachment'].toString().isNotEmpty;

  @override
  void initState() {
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

    selectedLeaveType = widget.leave['leave_type'];
    fetchLeaveTypes();

    
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

  Future<void> selectDate(BuildContext context, bool isFromDate) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: isFromDate ? fromDate : toDate,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF3C3FD5),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: Color(0xFF3C3FD5)),
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked == null) return;

  if (isFromDate) {

    if (picked.isAfter(toDate)) {
      _showCustomSnackBar(
        context,
        "Start date cannot be after end date",
        Colors.orange,
        Icons.warning_amber_outlined,
      );
      return;
    }

    setState(() {
      fromDate = picked;
      leaveDuration = calculateDuration(fromDate, toDate);
    });
  } else {
    if (picked.isBefore(fromDate)) {
      _showCustomSnackBar(
        context,
        "End date cannot be before start date",
        Colors.orange,
        Icons.warning_amber_outlined,
      );
      return;
    }

    setState(() {
      toDate = picked;
      leaveDuration = calculateDuration(fromDate, toDate);
    });
  }
}


  Future<void> fetchLeaveTypes() async {
    if (leaveTypes.isNotEmpty) return;

    if (leaveDuration == -1) {
      _showCustomSnackBar(
        context,
        'Invalid date range',
        Colors.red,
        Icons.error,
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/leave-type/list'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          leaveTypes = List<String>.from(data.map((item) => item['name']));
        });
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
      final uri = Uri.parse('$baseUrl/api/emp-leave/update/$leaveId');
      final request = http.MultipartRequest('PATCH', uri);

      final mimeType = lookupMimeType(file?.path ?? '');
      final mediaType =
          mimeType != null
              ? MediaType.parse(mimeType)
              : MediaType('application', 'octet-stream');

      request.fields['reason'] = reason;
      request.fields['start_date'] = fromDate.toIso8601String();
      request.fields['end_date'] = toDate.toIso8601String();
      request.fields['leave_duration'] = leaveDuration.toString();

      if (selectedLeaveType != null) {
        request.fields['leave_type'] = selectedLeaveType!;
      }

      if (_attachmentFile != null && await _attachmentFile!.exists()) {
       {
        request.files.add(
          await http.MultipartFile.fromPath(
            'leaveattachment',
            _attachmentFile!.path,
            filename: _attachmentFile!.path.split('/').last,
            contentType: mediaType,
          ),
        );
      }
      final response = await request.send();
      print('Status: ${response.statusCode}');
      print('Response: ${response.reasonPhrase}');
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        _showCustomSnackBar(
          context,
          'Leave details updated successfully',
          Colors.green,
          Icons.check,
        );
        
        setState(() {
        widget.leave['reason'] = reason;
        widget.leave['start_date'] = fromDate.toIso8601String();
        widget.leave['end_date'] = toDate.toIso8601String();
        widget.leave['leave_duration'] = leaveDuration;
        widget.leave['leave_type'] = selectedLeaveType;
        
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
          Icons.error,
        );
      }
    }
    } catch (e) {
      print('Error updating leave details: $e');
      _showCustomSnackBar(
        context,
        'Failed to update leave details',
        Colors.red,
        Icons.error,
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
    widget.leave['leave_type'] = selectedLeaveType;
    widget.leave['leaveattachment'] = _attachmentFile?.path;
  }

  Future<void> _refreshPage() async {
    await fetchLeaveTypes();
    _refreshData();
    setState(() {});
  }

  void _showCustomSnackBar(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {

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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      duration: const Duration(seconds: 1),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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


  return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: AppBar(
        title: const Text(
          "Leave Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
       backgroundColor: Colors.transparent, 
        foregroundColor: Colors.black,
        elevation: 0,
      ),
    ),
  ),
      body:Stack( 
     children: [
      Container(
        decoration: const BoxDecoration(
      gradient: LinearGradient(
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
          color: const Color(0xFFFDFDFD),
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
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedLeaveType,
                            hint: const Text(
                              "Select Leave Type",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            iconSize: 22,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            items:
                                leaveTypes.map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(
                                      type,
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
                  color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  icon: Icons.person_outline,
                  title: 'Username',
                  value: widget.emUsername,
                ),
                _buildDetailRow(
                  icon: Icons.work_outline,
                  title: 'Department',
                  value: widget.departmentName,
                ),
                _buildDetailRow(
                  icon: Icons.business_outlined,
                  title: 'Company',
                  value: widget.compFname,
                ),
                const Divider(height: 32),
                Text(
                  'Leave Dates',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.black,
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
                        value: "${fromDate.toLocal()}".split(' ')[0],
                        onTap: isReadOnly ? null : () => selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDetailRow(
                        icon: Icons.date_range_outlined,
                        title: 'To',
                        value: "${toDate.toLocal()}".split(' ')[0],
                        onTap: isReadOnly ? null : () => selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                _buildDetailRow(
                  icon: Icons.timer_outlined,
                  title: 'Duration',
                  value: '${calculateDuration(fromDate, toDate)} days',
                ),
                if (fromDate.difference(toDate).inDays.abs() == 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time),
                      const SizedBox(width: 8),
                      const Text('Leave Type: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: leaveDayType,
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
                            leaveDayType = val!;
                            leaveDuration = calculateDuration(fromDate, toDate);
                          });
                        },
                      ),
                    ],
                  ),
                ],
                const Divider(height: 32),
                Text(
                  'Reason',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
               
               
                const SizedBox(height: 16),
               
                TextField(
                  controller: reasonController,
                  readOnly: isReadOnly,
                  decoration: InputDecoration(
                    labelText: 'Leave Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'Leave Attachment',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                () {
                  if (_attachmentFile != null) {
                    return _attachmentFile!.path.split('/').last;
                  } else if (hasAttachment) {
                    return Uri.parse(widget.leave['leaveattachment'] ?? '').pathSegments.last;
                  } else {
                    return 'No file selected';
                  }
                }(),
                style: theme.textTheme.bodyMedium,
              ),
                
                const SizedBox(height: 8),

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
                            Icons.warning_amber_outlined,
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
                        final result = await OpenFile.open(filePath);
                        if (result.type != ResultType.done) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not open attachment'),
                            ),
                          );
                        }
                      } catch (e) {
                        print('Download/open error: $e');
                        _showCustomSnackBar(context, 'Failed to open attachment', Colors.red.shade400, Icons.error_outline);
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
                              widget.leave['leaveattachment']!,
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
                
                if (isRejected && widget.leave['reject_reason'] != null && widget.leave['reject_reason'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Reject Reason',
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
                    widget.leave['reject_reason'],
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
                  child: Text(value, style: TextStyle(color: Colors.black87)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
