import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LeaveApplicationPage extends StatefulWidget {
const LeaveApplicationPage({super.key});

@override
State<LeaveApplicationPage> createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
final _formKey = GlobalKey<FormState>();

List<dynamic> leaveTypes = [];
String? selectedLeaveType;
String? reason;
DateTime? startDate, endDate;
XFile? selectedFile;
String? emUsername, compFname;
bool isLoading = false;
String? type;
final baseUrl = dotenv.env['API_BASE_URL'];


@override
void initState() {
super.initState();
loadTokenData();
fetchLeaveTypes();
}

Future<void> pickFile() async {
final file = await openFile();
if (file != null) {
setState(() {
selectedFile = file;
});
}
}
Future<void> loadTokenData() async {
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('token');

if (token != null) {
  Map<String, dynamic> payload = Jwt.parseJwt(token);
  setState(() {
    emUsername = payload['em_username'];
    compFname = payload['comp_fname'];
  });
}
}

Future<void> fetchLeaveTypes() async {
if (leaveTypes.isNotEmpty) return;

try {
final response = await http.get(Uri.parse('$baseUrl/api/leave-type/list'));
if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  setState(() {
    leaveTypes = List<Map<String, dynamic>>.from(data);
  });
} else {
  print("Failed to load leave types");
}

} catch (e) {
print("Error fetching leave types: $e");
}
}

//   Future<void> fetchAvailableLeaves() async {
//   //  final leaveDuration = type == 'Half Day' ? 0.5 : (endDate!.difference(startDate!).inDays + 1);

//   final response = await http.get(Uri.parse('[http://192.168.1.5:8071/api/emp-leave/available/?em_username=$emUsername&leave_type=$selectedLeaveType](http://192.168.1.5:8071/api/emp-leave/available/?em_username=$emUsername&leave_type=$selectedLeaveType)'));

//   print("selectedLeaveType: $selectedLeaveType");
//   print("username:- $emUsername");

//     if (response.statusCode == 200) {
//     final data = jsonDecode(response.body);
//     print('Available Leaves Response: $response');
//     print('Available Leaves: $data["remaining"]');
//    setState(() {
//       availableBalance = data['remaining'];
//     });
//   } else {
//     throw Exception('Failed to load available leaves');
//   }

// }

Future<void> submitForm() async {
if (!_formKey.currentState!.validate() || startDate == null || endDate == null) return;
_formKey.currentState!.save();

   showDialog(
    context: context,
    barrierDismissible: false,  
    builder: (BuildContext context) {
      return Center(
        child: CircularProgressIndicator(),
      );
    },
   );

try{
var request = http.MultipartRequest(
'POST',
Uri.parse('$baseUrl/api/emp-leave/leave'),
);

request.fields['em_username'] = emUsername ?? '';
request.fields['leave_type'] = selectedLeaveType ?? '';
request.fields['comp_fname'] = compFname ?? '';
request.fields['start_date'] = startDate!.toIso8601String();
request.fields['end_date'] = endDate!.toIso8601String();
request.fields['apply_date'] = DateTime.now().toIso8601String();
request.fields['reason'] = reason ?? '';
request.fields['leave_status'] = 'Pending';
request.fields['created_by'] = emUsername ?? '';
request.fields['update_id'] = emUsername ?? '';

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
        final response = await request.send();
        // print("Response Status Code: ${response.reasonPhrase}");

        final responseBody = await response.stream.bytesToString();
        print("Response Body: $responseBody");

        Navigator.of(context).pop();
        setState(() {
        isLoading = false;  
      });
      
        if (response.statusCode == 201) {
        _showCustomSnackBar(
          context,
          "Leave submitted successfully",
          Colors.green,
          Icons.check_circle,
        );
         Future.delayed( const Duration(seconds: 2), () {
           setState(() { 
           });
         });

           _resetForm();

      } else {
        final error = jsonDecode(responseBody);
        _showCustomSnackBar(
          context,
          "${error['message']}",
          Colors.red,
          Icons.error,
        );
      }
    }catch(e){
      _showCustomSnackBar(context, 'Unexpected error format', Colors.red, Icons.error);

    }
  }
    Future<void> refreshPage() async {
    setState(() {
     isLoading = true;
    });
    await fetchLeaveTypes();

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
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

@override
Widget build(BuildContext context) {
return Scaffold(
  backgroundColor: Colors.transparent,

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
          "Leave Request",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
       backgroundColor: Colors.transparent, 
        foregroundColor: Colors.black,
        elevation: 0,
      ),
    ),
  ),
  body: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
         begin: Alignment.topRight,
         end: Alignment.bottomLeft,
      ),
    ),
          padding: const EdgeInsets.all(16.0),
          child: emUsername == null || compFname == null
          ? const Center(child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>( Color(0xFF4361EE)),
        ))
      : Form(
          key: _formKey,
          child: RefreshIndicator(
          onRefresh: refreshPage,
          color: const Color(0xFF4361EE),
          child: ListView(
            children: [
               Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildReadOnlyField("Employee Username", emUsername!),
                      buildReadOnlyField("Company Name", compFname!),
                      const SizedBox(height: 10),

                      DropdownButtonFormField<String>(
                        value: selectedLeaveType,
                        decoration: InputDecoration(
                          labelText: 'Leave Type',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                          filled: true,
                          fillColor: Colors.white60
                        ),
                        dropdownColor: Colors.white,
                        icon: Icon(Icons.arrow_drop_down, color: const Color(0xFF4361EE)),
                        style: TextStyle(color: const Color(0xFF212529)),
                        items: leaveTypes.map((e) {
                          return DropdownMenuItem<String>(
                            value: e['name'],
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
                      ),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Reason',
                          filled: true,
                          fillColor: Colors.white60,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        onSaved: (val) => reason = val,
                        validator: (val) => val == null || val.isEmpty ? 'Enter reason' : null,
                      ),
                      const SizedBox(height: 15),
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
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: const Color(0xFF4361EE),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: const Color(0xFF212529),
                                  ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                                ),
                                child: child!,
                              );
                            },
                                );
                                if (picked != null) {
                          setState(() {
                            startDate = picked;
                            if (endDate != null) {
                              final diff = endDate!.difference(startDate!).inDays;
                              if (diff > 0) {
                                type = diff > 1 ? 'More than One Day' : null; 
                              }
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
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: const Color(0xFF4361EE),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: const Color(0xFF212529),
                                  ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                                ),
                                child: child!,
                              );
                            },
                                );
                              if (picked != null) {
                              setState(() {
                                endDate = picked;
                                if (startDate != null) {
                                  final diff = endDate!.difference(startDate!).inDays;
                                  if (diff > 0) {
                                    type = diff > 1 ? 'More than One Day' : null;
                                  }
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
                        color: const Color(0xFF212529),
                      ),
                    ),
                  const SizedBox(height: 18),
               if (startDate != null && endDate != null) ...[
                Builder(
                  builder: (context) {
                    final diff = endDate!.difference(startDate!).inDays;
                    final items = diff == 0
                        ? [
                            DropdownMenuItem(value: 'Full Day', child: Text('Full Day')),
                            DropdownMenuItem(value: 'Half Day', child: Text('Half Day')),
                          ]
                        : [
                            DropdownMenuItem(value: 'More than One Day', child: Text('More than One Day')),
                          ];
                    if (!items.any((item) => item.value == type)) {
                      type = items.first.value;
                    }
                      return DropdownButtonFormField<String>(
                        value: type,
                        decoration: InputDecoration(
                          labelText: "Select Leave Type",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                          filled: true,
                          fillColor: Colors.white60
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
                      const SizedBox(height: 18),
                        Text("Document less than 10MB", style: TextStyle(fontWeight: FontWeight.normal)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: pickFile,
                              icon: const Icon(Icons.attach_file),
                              label: const Text("Upload File"),
                              style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 219, 214, 209),
                              foregroundColor: Color(0xFF030303),
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
                          backgroundColor:  Color(0XFF123458),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          shadowColor: Colors.transparent,
                        ),
                          icon: const Icon(Icons.send),
                          label: const Text(
                            'SUBMIT',
                            style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            ),
                          ),
                          onPressed: submitForm,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    )
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

          Widget buildReadOnlyField(String label, String value) {
          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
          label,
          style: TextStyle(
          fontSize: 14,
          color: const Color(0xFF6C757D),
          fontWeight: FontWeight.w500,
        ),
      ),
          const SizedBox(height: 8),
          Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
          children: [
          Expanded(
          child: Text(
          value,
          style: TextStyle(
          fontSize: 15,
          color:  const Color(0xFF212529),
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
                  color: Colors.white60,
                  ),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Icon(Icons.calendar_today, color: const Color(0xFF4361EE)),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                  date != null ? date.toLocal().toString().split(' ')[0] : 'Select',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF212529)),
                  ),
                  ],
                  ),
                  );
                }
              }