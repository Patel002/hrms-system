import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../helper/top_snackbar.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../utils/network_failure.dart';
import '../utils/user_session.dart';

class LeaveApplicationPage extends StatefulWidget {
const LeaveApplicationPage({super.key});

@override
State<LeaveApplicationPage> createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
final _formKey = GlobalKey<FormState>();

List leaveTypes = [];
String? selectedLeaveType;
String? reason;
DateTime? startDate, endDate;
XFile? selectedFile;
String? _token;
String? _empId,_error;
String? _emUsername;
String? _compFname;
bool isLoading = false;
String? type;
bool isSubmitting = false;
final baseUrl = dotenv.env['API_BASE_URL'];
final apiToken = dotenv.env['ACCESS_TOKEN'];


@override
void initState() {
super.initState();
loadTokenData();
// fetchLeaveTypes();
}

Future<void> pickFile() async {
  try{

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx','jpg','png'],
      withData: false
    );

    if (result != null && result.files.single.path != null) {
      final fileName = File(result.files.single.path!);
      final fileSizeInMB  = await fileName.length()/(1024*1024); 

      if (fileSizeInMB > 4) {
        showCustomSnackBar(
          context,
          'File must be less than 4MB (${fileSizeInMB.toStringAsFixed(2)} MB)',
          Colors.orange,
          Icons.warning,
        );
        return;
      }

    setState(() {
    selectedFile = XFile(fileName.path);
    });
    }
  }catch(e){
  debugPrint('File selection error: $e');
      showCustomSnackBar(context,'Error selecting file', Colors.red, Icons.error);

  }
}

Future<void> loadTokenData() async {
 _token = await UserSession.getToken();

if (_token != null) {
    _empId = await UserSession.getUserId();
    _emUsername = await UserSession.getUserName();
}
    await fetchDataPacketApi();
    await fetchLeaveTypes();
}

Future<void> fetchLeaveTypes() async {
    if (leaveTypes.isNotEmpty) return;

    try {
    final response = await http.get(Uri.parse('$baseUrl/MyApis/leavethetypes?user_id=$_empId'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiToken',
      'auth_token': _token!,
            },
    );

      print("response:- $response");

      final jsonData = json.decode(response.body);

      await UserSession.checkInvalidAuthToken(
            context,
            json.decode(response.body),
            response.statusCode,
          );

      if (response.statusCode == 200) {
        if(jsonData['data_packet'] != null && jsonData['data_packet'] is List){
        setState(() {
          leaveTypes = jsonData['data_packet'];
        });
        }
      } else {
        print("Failed to load leave types");
      }

    } catch (e) {
  if (e is SocketException) {
    setState(() {
      _error = 'No internet connection.';
    });
  } else {
    setState(() {
      _error = 'Error fetching leave types: $e';
    });
  }
}
    }

Future<void> fetchDataPacketApi() async {

    try {
      final response = await http.get(Uri.parse('$baseUrl/MyApis/userinfo?user_id=$_empId'),
      headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': _token!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data_packet'];

        if(mounted){ 
        setState(() {
          _compFname = data['comp_fname'];
        });
        }
      }

    } catch (e) {
  if (e is SocketException) {
    setState(() {
      _error = 'No internet connection.';
    });
  } else {
    setState(() {
      _error = 'Error fetching user info: $e';
    });
  }
}

  }


Future<void> submitForm() async {

bool hasError = false;

if (isSubmitting) return;

  if (!_formKey.currentState!.validate()) {
      hasError = true;
    }

  if (startDate == null && endDate == null) {
  showCustomSnackBar(context, "Please select a date", Colors.yellow.shade900, Icons.date_range_outlined);
  hasError = true;
}


  if (hasError) return;
  _formKey.currentState!.save();

 setState(() {
      isSubmitting = true;
    });


try{
var request = http.MultipartRequest(
'POST',
Uri.parse('$baseUrl/MyApis/leavetheadd'),
);

request.headers['Authorization'] = 'Bearer $apiToken';
request.headers['Accept'] = 'application/json';
request.headers['auth_token'] = _token!;
request.headers['user_id'] = _empId!;

request.fields['leave_type_id'] = int.parse(selectedLeaveType!).toString();

print("selectedLeaveType:- $selectedLeaveType");

request.fields['leave_type'] = type ?? '';  

print("type:- $type");

// request.fields['comp_fname'] = _compFname ?? '';
request.fields['from_date'] = DateFormat('yyyy-MM-dd').format(startDate!);

print("startDate:- $startDate");

request.fields['to_date'] = DateFormat('yyyy-MM-dd').format(endDate!);
print("endDate:- $endDate");
// request.fields['apply_date'] = DateTime.now().toIso8601String();
request.fields['reason'] = reason ?? '';

print("reason:- $reason");
request.fields['leave_status'] = 'Pending';
request.fields['created_by'] = _empId ?? '';
request.fields['update_id'] = _empId ?? '';

if(startDate !=null && endDate !=null){
  if(type == 'Half Day'){
    request.fields['leave_duration'] = '0.5';
  }else{
  int diffDays = endDate!.difference(startDate!).inDays + 1;
  request.fields['leave_duration'] = diffDays.toString();
  }
}

    if (selectedFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'leaveattachment',  
        selectedFile!.path,
      ));
  }
  else {
  request.fields['leaveattachment'] = '';
}


  print("Request Fields: ${request.fields}");
  print("Request Files: ${request.files}");
        final response = await request.send();
        print("Response Status Code: ${response.reasonPhrase}");


        final responseBody = await response.stream.bytesToString();
        print("Response Body: $responseBody");

      //   setState(() {
      //   isLoading = false;  
      // });
          setState(() {
      isSubmitting = false; 
    });
      
        if (response.statusCode == 200) {
        showCustomSnackBar(
          context,
          "Leave submitted successfully",
          Colors.green,
          Icons.check_circle,
        );

        await Future.delayed(const Duration(seconds: 1));

           _resetForm();
           await refreshPage();

      } else {
        final error = jsonDecode(responseBody);
        // print("error:- $error");
        showCustomSnackBar(
          context,
          "${error['message']}",
          Colors.red,
          Icons.error,
        );

       await Future.delayed(const Duration(seconds: 1));

      }
    }catch(e){
      showCustomSnackBar(context,'Unexpected error format', Colors.red, Icons.error);
      await Future.delayed(const Duration(seconds: 1));
    }finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

    Future<void> refreshPage() async {
    setState(() {
     isLoading = true;
     _error = null;
    });

    await fetchLeaveTypes();

    _resetForm();

    setState(() {
      isLoading = false;
    });
  }

  void _resetForm() {
  setState(() {
    _formKey.currentState?.reset();
    selectedLeaveType = null;
    reason = null;
    startDate = null;
    endDate = null;
    selectedFile = null;
    type = null;
  });
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
appBar: AppBar(
  backgroundColor: Colors.transparent, 
        title: const Text(
          "Leave Application",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
       foregroundColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87,
      forceMaterialTransparency: true,
      ),

  body:_error != null
  ? NoInternetWidget(
      onRetry: () {
        setState(() {
          _error = null;
        });
        loadTokenData();
      },
    )
  :  Stack(
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
          padding: const EdgeInsets.all(16.0),
          child: _emUsername == null || _compFname == null
          ? Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>( Theme.of(context).iconTheme.color ?? Colors.black),
        ))
      : Form(
          key: _formKey,
          child: RefreshIndicator(
          onRefresh: refreshPage,
          color: Theme.of(context).iconTheme.color,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor ,
          child: ListView(
            children: [
               Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildReadOnlyField(context,"Employee Username", _emUsername!),
                      buildReadOnlyField(context,"Company Name", _compFname!),
                      const SizedBox(height: 10),

                      leaveTypes.isNotEmpty?
                      DropdownButtonFormField<String>(
                        value: selectedLeaveType,
                        decoration: InputDecoration(
                          labelText: 'Leave Type',
                         labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey.shade900
                          : Colors.white,
                          enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF123458), width: 1.5),
                        ),
                      ),
                        dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade500),
                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                         fontSize: 14,
                      ),
                        items: leaveTypes.map((e) {
                          return DropdownMenuItem<String>(
                            value: e['type_id'],
                            child: Text(e['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedLeaveType = value;
                          });
                            // fetchAvailableLeaves();
                        },
                        validator: (value) => value == null ? 'Select leave type' : null,
                      ):CupertinoActivityIndicator(),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate ?? DateTime.now(),
                                  firstDate: DateTime(1947),
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
                           if (picked != null) {
                              if (endDate != null && picked.isAfter(endDate!)) {
                                showCustomSnackBar(context, "Start date cannot be after end date", Colors.yellow.shade900, Icons.date_range_outlined);

                                setState(() {
                                  startDate = null;
                                });
                                
                                return;
                              } 
                                setState(() {
                                  startDate = picked;
                                  if (endDate != null) {
                                    final diff = endDate!.difference(startDate!).inDays;
                                    type = diff > 1 ? 'More than One Day' : null;
                                  }
                                });
                              }
                            },
                          child: buildDateTile("Start Date", startDate ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate ?? DateTime.now(),
                                  firstDate: DateTime(1947),
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
                              if (picked != null) {
                                if (startDate != null && picked.isBefore(startDate!)) {
                                  showCustomSnackBar(context, "End date cannot be before start date", Colors.yellow.shade900, Icons.date_range_outlined);

                                  setState(() {
                                    endDate = null;
                                  });

                                  return;
                                } 
                                  setState(() {
                                    endDate = picked;
                                    if (startDate != null) {
                                      final diff = endDate!.difference(startDate!).inDays;
                                      type = diff > 1 ? 'More than One Day' : null;
                                    }
                                  });
                                }
                              },
                      child: buildDateTile("End Date", endDate),
                    ),
                  ),
                ],
              ),
                  const SizedBox(height: 18),
                     Text(
                      startDate != null && endDate != null
                          ? (type == 'Half Day'
                              ? 'Leave Duration: 0.5 days'
                              : 'Leave Duration: ${endDate!.difference(startDate!).inDays + 1} days')
                          : 'Leave Duration: 0 days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        // color: const Color(0xFF212529),
                      ),
                    ),
                  const SizedBox(height: 18),
               if (startDate != null && endDate != null) ...[
                Builder(
                  builder: (context) {
                    final diff = endDate!.difference(startDate!).inDays;
                    final items = diff == 0
                        ? [
                            DropdownMenuItem(value: 'Full-Day', child: Text('Full-Day')),
                            DropdownMenuItem(value: 'Half-Day', child: Text('Half-Day')),
                          ]
                        : [
                            DropdownMenuItem(value: 'More than One Day', child: Text('More than One Day')),
                          ];
                    if (!items.any((item) => item.value == type)) {
                      type = items.first.value;
                    }
                      return DropdownButtonFormField<String>(
                        value: type,
                        dropdownColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.white,
                        decoration: InputDecoration(
                          labelText: "Select Leave Type",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.white,
                        ),
                        items: items,
                        onChanged: (value) {
                          setState(() {
                            type = value;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a leave type' : null,
                          );
                        },
                      ),
                    ],

                    const SizedBox(height: 12),

                    TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Reason',
                          labelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          // color: Color(0xFF555555),
                        ),
                          filled: true,
                          fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                          alignLabelWithHint: true,
                        
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF123458), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                        maxLines: 3,
                        onSaved: (val) => reason = val,
                        validator: (val) => val == null || val.isEmpty ? 'Enter reason' : null,
                      ),
                      
                      const SizedBox(height: 18),
                        Text("Document less than 4MB", style: TextStyle(fontWeight: FontWeight.normal)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: pickFile,
                              icon: const Icon(Icons.attach_file),
                              label: const Text("Upload File"),
                              style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).iconTheme.color,
                              foregroundColor: Theme.of(context).scaffoldBackgroundColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      selectedFile != null
                                          ? selectedFile!.name
                                          : "Tap to upload file",
                                      style: TextStyle(
                                        color: selectedFile != null
                                            ? const Color(0xFF6C757D)
                                            : const Color(0xFF6C757D),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (selectedFile != null)
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        color: const Color(0xFFF44336),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          selectedFile = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Theme.of(context).colorScheme.primary, 
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          shadowColor: Color(0XFF123458),
                        ),
                          icon: const Icon(Icons.send),
                          label: const Text(
                            'SUBMIT',
                            style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            ),
                          ),
                          onPressed: isSubmitting ? null : submitForm,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    if (isSubmitting)
        Container(
          color: Colors.black.withOpacity(0.5), 
          child: const Center(
            child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Submitting, please wait...',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  } 

// Widget buildReadOnlyField(String label, String value) {
//   return Padding(
//     padding: const EdgeInsets.only(bottom: 12),
//     child: TextFormField(
//       initialValue: value,
//       enabled: false,
//       decoration: InputDecoration(
//         labelText: label,
//         disabledBorder: OutlineInputBorder(
//           borderSide: BorderSide(color: Colors.grey.shade300),
//           borderRadius: BorderRadius.circular(10),
//         ),
//       ),
//     ),
//   );
// }

          Widget buildReadOnlyField(BuildContext context, String label, String value) {
          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade300 
                  : const Color(0xFF6C757D), 
            ),
         ),
          const SizedBox(height: 8),
          Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade900
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade700
                : Colors.grey.shade300,
          ),),
          child: Row(
          children: [
          Expanded(
          child: Text(
          value,
          style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF212529),
          ),
        ),
        ),
      ],
      ),
    ),
  ],
  );
  }

        Widget buildDateTile(String label, DateTime? date) {
        return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(5),
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade900
            : Colors.grey.shade50,
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
        Icon(Icons.calendar_today, color: Theme.of(context).brightness == Brightness.light ? Color(0xFF4361EE) : Colors.white),

        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
        date != null ? DateFormat('dd-MM-yyyy').format(date) : 'Select',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
       ],
      ),
     );
    }
   }