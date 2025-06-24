import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ODPassScreen extends StatefulWidget {
  const ODPassScreen({super.key});

  @override
  State<ODPassScreen> createState() => _ODPassScreenState();
}

class _ODPassScreenState extends State<ODPassScreen> {


final baseUrl = dotenv.env['API_BASE_URL'];
final _formKey = GlobalKey<FormState>();
String? remark;
DateTime? fromdate, todate;
String? emUsername, compFname, empId, type;
bool isLoading = false;
bool isSubmitting = false;

@override
  void initState() {
super.initState();
loadTokenData();
}

Future<void> loadTokenData() async {
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('token');

    if (token != null) {
      Map<String, dynamic> payload = Jwt.parseJwt(token);
      setState(() {
        emUsername = payload['em_username'];
        compFname = payload['comp_fname'];
        empId = payload['em_id'];
      });
    }
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
try{
   final response = await http.post(
    Uri.parse('$baseUrl/api/od-pass/apply'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'emp_id': empId,
      'comp_fname': compFname,
      'em_username': emUsername,
      'fromdate': fromdate!.toIso8601String(),
      'todate': todate!.toIso8601String(),
      'remark': remark,
      'add_date': DateTime.now().toIso8601String(),
      'created_by': empId,
      'oddays': odDetails['oddays'],
      'odtype': odDetails['odtype'],
      'created_at': DateTime.now().toIso8601String(),
    })
   );

  //  print('body,${response.body}');

   if (response.statusCode == 201) {
      _showCustomSnackBar(context, 'OD-Pass applied successfully', Colors.green, Icons.check);

      _resetForm();
      
      return true;
    } else {
      final body = jsonDecode(response.body);
      _showCustomSnackBar(context, body['message'], Colors.red, Icons.error);
      return false;
    }
  } catch (e) {
    _showCustomSnackBar(context, 'Unexpected error format', Colors.red, Icons.error);
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
      duration: const Duration(seconds: 2),
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
                  "OD-Pass",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              backgroundColor: Colors.transparent, 
                foregroundColor: Colors.black,
                elevation: 0,
              ),
            ),
          ),
        body: Stack(
          children: [ 
        Container(
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
              onRefresh: handlePullToRefresh,
              color: Colors.black87,
              backgroundColor: Colors.white,
              child: ListView(
                children: [
                  Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildReadOnlyField("Employee ID", empId!),
                      buildReadOnlyField("Employee Username", emUsername!),
                      buildReadOnlyField("Company Name", compFname!),
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
                      child: buildDateTile("Start Date", fromdate ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: todate ?? DateTime.now(),
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
                      child: buildDateTile("End Date", todate),
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
                        color: const Color(0xFF212529),
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
                  decoration: InputDecoration(

                    labelText: "Select OD Type",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
                    filled: true,
                    fillColor: Colors.white60,
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
                          filled: true,
                          fillColor: Colors.white60,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5),
                            borderSide: BorderSide(color: Colors.grey.shade300)),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                        onSaved: (val) => remark = val,
                        validator: (val) => val == null || val.isEmpty ? 'Enter remark' : null,
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
                style: TextStyle(color: Colors.white, fontSize: 16),
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