import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart';

class ODPassScreen extends StatefulWidget {
  const ODPassScreen({super.key});

  @override
  State<ODPassScreen> createState() => _ODPassScreenState();
}

class _ODPassScreenState extends State<ODPassScreen> {

final baseUrl = dotenv.env['API_BASE_URL'];
final apiToken = dotenv.env['ACCESS_TOKEN'];
final _formKey = GlobalKey<FormState>();
String? remark;
DateTime? fromdate, todate;
String? _emUsername, _empId, type;
String? _token;
bool isLoading = false;
bool isSubmitting = false;

@override
void initState() {
super.initState();
loadTokenData();
}

Future<void> loadTokenData() async {
    _emUsername = await UserSession.getUserName();
    _empId = await UserSession.getUserId();

    setState(() {
      _emUsername = _emUsername;
      _empId = _empId;
    });
  } 


Map<String, dynamic> getODDetails() {
  int odtype;
  double oddays;

  if (fromdate == null || todate == null || type == null) {
    return {'oddays': 0.0, 'odtype': 0};
  }
  
  final diff = todate!.difference(fromdate!).inDays + 1;

  if (type == 'Half Day') {
    oddays = 0.5;
    odtype = 1;
  } else if (type == 'Full Day') {
    oddays = 1.0;
    odtype = 1;
  } else {
    oddays = diff.toDouble();
    odtype = 2;
  }

  return {
    'oddays': oddays,
    'odtype': odtype,
  };
}

 Future<bool> submitOdPass() async {
    if (isSubmitting) return false;

  if (!_formKey.currentState!.validate() || fromdate == null || todate == null) return false; 

  _formKey.currentState!.save();

   setState(() {
      isSubmitting = true;
    });

  final odDetails = getODDetails(); 

  _token = await UserSession.getToken();

  print('odDetails,$odDetails');
  print('token,$_token');
  print('empId,$_empId');
   try{
   final response = await http.post(
    Uri.parse('$baseUrl/MyApis/odpasstheadd'),
    headers: {
      'Content-Type': 'application/json',
      'auth_token': _token!,
      'user_id': _empId!,
      'Authorization': 'Bearer $apiToken',
      },
    body: jsonEncode({
      // 'emp_id': empId,
      // 'comp_fname': compFname,
      // 'em_username': emUsername,
      'from_date': DateFormat('yyyy-MM-dd').format(fromdate!),
      'to_date': DateFormat('yyyy-MM-dd').format(todate!),
      'remark': remark,
      // 'add_date': DateTime.now().toIso8601String(),
      // 'created_by': empId,
      // 'oddays': odDetails['oddays'],
      'od_type': odDetails['odtype'],
      // 'created_at': DateTime.now().toIso8601String(),
    })
   );

    await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

   if (response.statusCode == 200) {
      showCustomSnackBar(context, 'OD-Pass applied successfully', Colors.green, Icons.check);

      _resetForm();
      
      return true;
    } else {
      final body = jsonDecode(response.body);
      showCustomSnackBar(context, body['message'], Colors.red, Icons.error);
      return false;
    }
  } catch (e) {
    showCustomSnackBar(context, 'Unexpected error format:-$e', Colors.red, Icons.error);
    return false;

  } finally {
    setState(() {
      isSubmitting = false;
    });
  }
}
Future<void> handlePullToRefresh() async {
  setState(() {
    isLoading = true;
  });

  _resetForm();

  setState(() {
    isLoading = false;
  });
}

  void _resetForm() {
  _formKey.currentState?.reset();
  
  setState(() {
    remark = null;
    fromdate = null;
    todate = null;
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
        "On-Duty Apply",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      foregroundColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : Colors.black87,
      forceMaterialTransparency: true,
    ),

        body: Stack(
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
              child: Form(
              key: _formKey,
              child: RefreshIndicator(
              onRefresh: handlePullToRefresh,
              color: Theme.of(context).iconTheme.color,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor ,
              child: ListView(
                children: [
                  Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildReadOnlyField(context,"Employee ID", _empId ?? '-'),
                      buildReadOnlyField(context, "Employee Username", _emUsername??'-'),
                      // buildReadOnlyField("Company Name", compFname!),
                      const SizedBox(height: 10),
                       Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: fromdate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
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
                                 if (todate != null && picked.isAfter(todate!)) {
                                showCustomSnackBar(context, "Start date cannot be after end date", Colors.yellow.shade900, Icons.date_range_outlined);

                                setState(() {
                                  fromdate = null;
                                });
                                
                                return;
                              } 
                          setState(() {
                            fromdate = picked;
                            if (todate != null) {
                              final diff = todate!.difference(fromdate!).inDays;
                              if (diff > 0) {
                                type = diff > 1 ? 'More than One Day' : null; 
                              }
                            }
                          });
                        }
                      },
                      child: buildDateTile(context,"Start Date", fromdate ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: todate ?? DateTime.now(),
                                  firstDate: DateTime.now(),
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
                                if (fromdate != null && picked.isBefore(fromdate!)) {
                                  showCustomSnackBar(context, "End date cannot be before start date", Colors.yellow.shade900, Icons.date_range_outlined);

                                  setState(() {
                                    todate = null;
                                  });

                                  return;
                                } 
                              setState(() {
                                todate = picked;
                                if (fromdate != null) {
                                  final diff = todate!.difference(fromdate!).inDays;
                                  if (diff > 0) {
                                    type = diff > 1 ? 'More than One Day' : null;
                                  }
                                }
                              });
                            }
                          },
                      child: buildDateTile(context,"End Date", todate),
                    ),
                  ),
                ],
              ),
                  const SizedBox(height: 18),
                     Text(
                      fromdate != null && todate != null
                          ? (type == 'Half Day'
                              ? 'OD-Days : 0.5 days'
                              : 'OD-Days : ${todate!.difference(fromdate!).inDays + 1} days')
                          : 'OD-Days : 0 days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        // color: const Color(0xFF212529),
                      ),
                    ),
                  const SizedBox(height: 18),
               if (fromdate != null && todate != null) ...[
                Builder(
                  builder: (context) {
                    final diff = todate!.difference(fromdate!).inDays;
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
                  // icon: const Icon(Icons.expand_circle_down, size: 20),
                  dropdownColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.white,
                  decoration: InputDecoration(
                    labelText: "Select OD Type",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.white60,
                  ),

                  items: fromdate != null && todate != null && fromdate == todate
                      ? [
                          DropdownMenuItem(value: 'Full Day', child: Text('Full Day')),
                          DropdownMenuItem(value: 'Half Day', child: Text('Half Day')),
                        ]
                      : [
                          DropdownMenuItem(value: 'More than One Day', child: Text('More than One Day')),
                        ],
                  onChanged: (fromdate != null && todate != null && fromdate == todate)
                      ? (value) {
                          setState(() {
                            type = value;
                          });
                        }
                      : null, 
                        validator: (value) => value == null ? 'Please select a OD type' : null,
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                     TextFormField(
                    decoration: InputDecoration(
                        labelText: 'Remark',
                        labelStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          // color: Color(0xFF555555),
                        ),
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade900
                        : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF123458), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        alignLabelWithHint: true,
                      ),
                      style: const TextStyle(fontSize: 15),
                      maxLines: 2,
                      onSaved: (val) => remark = val,
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Enter remark' : null,
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
                          label: Text(
                            'Submit',
                            style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            ),
                          ),
                          onPressed: isSubmitting ? null : submitOdPass,
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
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold ),
                textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          ]
    ),
    );
  }
}

 Widget buildReadOnlyField(BuildContext context, String label, String value) {
          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
          label,
          style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade300 
                  : const Color(0xFF6C757D), 
          fontWeight: FontWeight.w500,
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
          border: Border.all(color: Colors.grey.shade300),
          ),
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

      Widget buildDateTile(BuildContext context, String label, DateTime? date) {
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

                  const SizedBox(height: 4),
                  Text(
                  date != null ? date.toLocal().toString().split(' ')[0] : 'Select',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  ],
                  ),
                  );
                }