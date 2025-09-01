import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart';
class ExpenseHistoryDetails extends StatefulWidget {

  final Map item;

  const ExpenseHistoryDetails({super.key, required this.item});

  @override
  State<ExpenseHistoryDetails> createState() => _ExpenseHistoryDetailsState();
}

class _ExpenseHistoryDetailsState extends State<ExpenseHistoryDetails> {
  final apiToken =  dotenv.env['ACCESS_TOKEN'];
  final baseUrl = dotenv.env['API_BASE_URL'];

  late TextEditingController descriptionController;

  late TextEditingController amountController;

  late DateTime selectedDate = DateTime.parse(widget.item['exp_date']);

  List<Map<String, dynamic>> expenseTypes = [];
  int? selectedExpenseType; 
  String? _emId,empname,departmentName,companyName;
  String? _token,_error;
  Position? currentPosition;
  int? amount;
  String? expenseName;
  bool isLoading = false;
  bool isSubmitting = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    
    fetchExpenseTypes();

    descriptionController = TextEditingController(text: widget.item['exp_description']);
    amountController = TextEditingController(text: widget.item['expense_amount']);

    amount = int.tryParse(widget.item['expense_amount'].toString());
    
    selectedExpenseType = int.tryParse(widget.item['expense_type'].toString());

    _connectivitySubscription = Connectivity()
    .onConnectivityChanged
    .listen((List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
    if (mounted) {
      setState(() {
        _error = 'No internet connection.';
      });
    }
  } else {
    if (mounted && _error != null) {
      setState(() {
        _error = null;
      });
      _initializeSession();
    }
  }
});

final initialStatus = Connectivity().checkConnectivity();
initialStatus.then((status) {
  if (status == ConnectivityResult.none) {
    setState(() {
      _error = 'No internet connection.';
    });
  } else {
    _initializeSession();
  }
});
}

  Future<void> _initializeSession() async {
    _token = await UserSession.getToken();
    final locationGranted = await requestLocationPermission();
     if (!locationGranted ) {
      return;
    }

    print("token:- $_token");

    if (_token != null) {
      _emId = await UserSession.getUserId();
    }else {
      Navigator.pushReplacementNamed(context, '/login');
    }
    await getLocation();
   
      setState(() {
        isLoading = false;
      });
  }

  Future<bool> requestLocationPermission() async {
  final status = await Permission.location.request();

  if (status.isGranted) {
    return true;
  } else if (status.isPermanentlyDenied) {
    await openAppSettings();
    return false;
  } else {
    showCustomSnackBar(context, 'Location permission is required.', Colors.teal.shade400, Icons.location_on_outlined);
    return false;
  }
}

Future<void> getLocation() async {
  bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();

  if (!isLocationEnabled) {
    await Geolocator.openLocationSettings();
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      showCustomSnackBar(context, 'Location permission is Denied.', Colors.yellow.shade900, Icons.location_on_outlined);
    }
  }

  try{
      if(currentPosition != null) return;

    Position? lastPosition = await Geolocator.getLastKnownPosition();
    if (lastPosition != null) {
      currentPosition = lastPosition;
      return;
    }

    
   currentPosition = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  }catch(e){
     print("Location error: $e");
    showCustomSnackBar(
      context,
      'Could not fetch location, please try again.',
      Colors.red,
      Icons.location_on_outlined,
    );
  }
  print('Latitude: ${currentPosition?.latitude}, Longitude: ${currentPosition?.longitude}, Accuracy: ${currentPosition?.accuracy}');
} 

  Future<void> fetchExpenseTypes() async {
    try {
      
      setState(() {
        isLoading = true;
      });

      await getLocation();

      print('Latitude: ${currentPosition?.latitude}, Longitude: ${currentPosition?.longitude}, Accuracy: ${currentPosition?.accuracy}');

    final url = Uri.parse('$baseUrl/MyApis/expensethetype');

    final response = await http.get(url, 
    headers: {
      'Authorization': 'Bearer $apiToken',
      'auth_token': _token!,
      'user_id': _emId!
    });
    
    final jsonData = json.decode(response.body);

    await UserSession.checkInvalidAuthToken(
      context,
      json.decode(response.body),
      response.statusCode,
    );

    if (response.statusCode == 200) {
        if(jsonData['data_packet'] != null && jsonData['data_packet'] is List){
       final fetchedTypes = (jsonData['data_packet'] as List)
      .map((item) => {
      'id': int.tryParse(item['id'].toString()) ?? 0,
      'label': "${item['expense_name']}",
    })
    .toList();

     expenseName = widget.item['expense_name'].toString();

    final matchedType = fetchedTypes.firstWhere(
      (type) => type['label'] == expenseName,
      orElse: () => {},
    );

    setState(() {
      expenseTypes = fetchedTypes;
      selectedExpenseType = matchedType['id'] as int?;
    });
  } else {
        print("Failed to load Expense types");
      }
    }
  }  catch (e) {
    if (e is SocketException) {
    setState(() {
      _error = 'No internet connection.';
    });
  } else {
    setState(() {
      _error = 'Error fetching expense types: $e';
    });
  }
 }finally {
    setState(() {
      isLoading = false;
    });
  }
}

  Future<void> updateExpense() async {  
    setState(() {
      isSubmitting = true;
    });

    final expenseId = widget.item['id'];

    try {

      if (currentPosition == null) {
      await getLocation();
    }
      
      final url = Uri.parse('$baseUrl/MyApis/expensetheedit?id=$expenseId');
        
      final response = await http.patch(url,
        headers: {
        'Authorization': 'Bearer $apiToken',
        'auth_token': _token!,
        'user_id': _emId!
      },
        body: json.encode({
          'exp_description': descriptionController.text,
          'expense_type': selectedExpenseType,
          'expense_amount': amount,
          'latitude': currentPosition?.latitude,
          'longitude': currentPosition?.longitude,
        }),
      );

      // print('body: desc=${descriptionController.text}, type=$selectedExpenseType, amount=$amount, lat=${currentPosition?.latitude}, lon=${currentPosition?.longitude}');

      await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      final decode = jsonDecode(response.body);
      print('decode,$decode');

      if (decode['error'] == true) {
        showCustomSnackBar(
          context,
          decode['message'],
          Colors.red,
          FontAwesomeIcons.exclamationTriangle,
        );
        return;
      }

      if (response.statusCode == 200) {

        setState(() {
          isSubmitting = false;
        });

        final message = 'Expense Successfully Updated';
        showCustomSnackBar(
          context,
          message,
          Colors.green,
          FontAwesomeIcons.checkCircle,
        );
        await _refreshPage();
        Navigator.pop(context);
      }
    }catch (e) {
      print('Error updating expense details: $e');
      showCustomSnackBar(
        context,
        'Failed to update Expense details',
        Colors.red,
        FontAwesomeIcons.exclamationTriangle,
      );
    }finally {
      if (mounted && isSubmitting) {
        setState(() {
        isSubmitting = false;
      });
     }
    }
  }

  void _launchMap(String latitude, String longitude) async {
    final url =
        "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Could not open map.")));
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }


  Future<void> _refreshPage() async {
    await fetchExpenseTypes();
    setState(() {
      isLoading = false;
    });
  }

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (widget.item['approval_status'] ?? '').toString().toUpperCase();

    final isApproved = status == 'APPROVED';
    final isRejected = status == 'REJECTED';

    final bool isReadOnly = isApproved || isRejected;

   return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      extendBody: true,
      appBar: AppBar(
       backgroundColor: Colors.transparent, 
        title: Text(
          "Expense Details",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
        ),
        foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
        forceMaterialTransparency: true,
      ),
   
     body:Stack( 
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
      child: RefreshIndicator(
        onRefresh: _refreshPage,  
        color: Theme.of(context).iconTheme.color,
       backgroundColor: Theme.of(context).scaffoldBackgroundColor ,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(), 
        padding: const EdgeInsets.all(16.0),
        child: Card(
         color: Theme.of(context).brightness == Brightness.light
                      ? Color(0xFFFDFDFD)
                      : Color(0xFF121212),
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
                    widget.item['approval_status']?.toUpperCase() ?? 'PENDING',
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
                            value: selectedExpenseType,
                            hint: Text(
                              "Select Expesne Type",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            iconSize: 22,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                            ),
                              items:
                                expenseTypes.map((type) {
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
                                        selectedExpenseType = value;
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
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context: context,
                  icon: Icons.person_outline,
                  title: 'Username',
                  value: widget.item['empname'],
                ),
                _buildDetailRow(
                  context: context,
                  icon: Icons.work_outline,
                  title: 'Department',
                  value: widget.item['dep_name'],
                ),
                _buildDetailRow(
                  context: context,
                  icon: Icons.business_outlined,
                  title: 'Company',
                  value: widget.item['compname'],
                ),

                const Divider(height: 32),
                Text(
                  'Expense',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  readOnly: isReadOnly,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    fillColor: isReadOnly
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? Colors.black45  
                        : Colors.grey[100])
                    : null,
                filled: isReadOnly,
              ),
                validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                if(value.isNotEmpty){
                  final doubleVal = double.tryParse(value);
                  if(doubleVal != null){
                    amount = doubleVal.round();
                  }
                }
              });
            },
          ),

                const SizedBox(height: 23),
                TextField(
                  controller: descriptionController,
                  readOnly: isReadOnly,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    fillColor: isReadOnly
                    ? (Theme.of(context).brightness == Brightness.dark
                        ? Colors.black45  
                        : Colors.grey[100])
                    : null,
                    filled: isReadOnly,
                  ),
                ),

                const SizedBox(height: 16),

                 if (widget.item['latitude'] != null && widget.item['longitude'] != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      elevation: 2,
                    ),
                    onPressed: () => _launchMap(widget.item['latitude'], widget.item['longitude']),
                    icon: const Icon(FontAwesomeIcons.locationCrosshairs, size: 16),
                    label: const Text(
                      "View Location",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                if(isApproved) ...[
                const SizedBox(height: 12),
                Text(
                  'Approved By',
                  style: theme.textTheme.titleSmall?.copyWith(
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
                    widget.item['approval_by'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
                  ),
                ),

                 const SizedBox(height: 12),
                Text(
                  'Approved At',
                  style: theme.textTheme.titleSmall?.copyWith(
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
                    widget.item['approval_at'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green.shade700),
                  ),
                ),
                ],
                
                if (isRejected && widget.item['rejectreason'] != null && widget.item['rejectreason'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Reject Reason',
                  style: theme.textTheme.titleSmall?.copyWith(
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
                    widget.item['rejectreason'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                  ),
                ),

                const SizedBox(height: 12),
                Text(
                  'Reject By',
                  style: theme.textTheme.titleSmall?.copyWith(
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
                    widget.item['approval_by'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                  ),
                ),

                const SizedBox(height: 12),
                 Text(
                  'Reject at',
                  style: theme.textTheme.titleSmall?.copyWith(
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
                    widget.item['approval_at'],
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
                  ),
                ),
              ],
              if (!isApproved && !isRejected) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: isSubmitting ? null : () async {
                    await updateExpense();
                    },
                    icon: const Icon(FontAwesomeIcons.upload),
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
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Updating Expense...',
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
    ),
   );
  }    
}

  Widget _buildDetailRow({
    required BuildContext context,
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
          Icon(icon, size: 20, color: Theme.of(context).iconTheme.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onTap,
                  child: Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }