import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';


class UserInfo extends StatefulWidget {
  const UserInfo({super.key});

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {

  final baseUrl = dotenv.env['API_BASE_URL'];
  final _formKey = GlobalKey<FormState>();
  
  String? username,firstname,lastname,email,fathername,address,gender,role,bloodgroup,gstnumber,pannumber,employeeId;
  String? department,companyname,companyid;
  DateTime? dateOfBirth;
  DateTime? dateOfJoining;
  bool isLoading = true;
  bool isSubmitting = false;

@override
void initState() {
  super.initState();
  fetchUserInfo();
}

Future<void> fetchUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token'); 
    
    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    final decodedToken = Jwt.parseJwt(token);
    String? userId = decodedToken['em_id'];

     debugPrint('User ID: $userId');

    try{
      final response = await http.get(Uri.parse('$baseUrl/api/employee/info/$userId'),
        headers: {
          'Content-Type': 'application/json',
        });

        debugPrint('Response Status: ${response.statusCode}');

      if(response.statusCode == 201) {
        final finalData = json.decode(response.body);
        final data = finalData['data']; 

        setState(() {
          employeeId = data['em_id'];
          username = data['em_username'];
          firstname = data['first_name'];
          lastname = data['last_name'];
          email = data['em_email'];
          fathername = data['father_name'];
          address = data['em_address'];
          gender = data['em_gender'];
          role = data['em_role'];
          department = data['department']['dep_name'];
          companyid = data['comp_id'];
          companyname = data['company']['comp_fname'];
          bloodgroup = data['em_blood_group'];
          gstnumber = data['gst_number'];
          pannumber = data['pancard'];
          dateOfBirth = data['em_birthday'] != null ? DateTime.parse(data['em_birthday']) : null;
          dateOfJoining = data['em_joining_date'] != null ? DateTime.parse(data['em_joining_date']) : null; 

          isLoading = false;
        });
      }else {
        setState(() {
          isLoading = false;
        });
      }
    }catch (e) {
  setState(() {
    isLoading = false;
  });
  
  showAboutDialog(
    context: context,
    applicationName: "Error",
    applicationVersion: "1.0.0",
    children: [
      Text("An error occurred while fetching user information: $e"),
    ],
  );
}
}

 Future<void> updateUserInfo() async {

  if (isSubmitting) return;
  setState(() {
    isSubmitting = true;
  });

   SharedPreferences prefs = await SharedPreferences.getInstance();
   String? token = prefs.getString('token');

   if (token == null) {
     Navigator.pushReplacementNamed(context, '/login');
     return;
   }

   final decodedToken = Jwt.parseJwt(token);
   String? userId = decodedToken['em_id'];

   _formKey.currentState!.save();

   try {
     final response = await http.patch(
       Uri.parse('$baseUrl/api/employee/update/$userId'),
       headers: {
         'Content-Type': 'application/json',
       },
       body: json.encode({
         'em_username': username,
         'first_name': firstname,
         'last_name': lastname,
         'em_email': email,
         'father_name': fathername,
         'em_address': address,
         'em_gender': gender,
         'em_role': role,
         'em_blood_group': bloodgroup,
         'gst_number': gstnumber,
         'pancard': pannumber,
         'em_birthday': dateOfBirth?.toIso8601String(),
         'em_joining_date': dateOfJoining?.toIso8601String(),
       }),
     );

     if (response.statusCode == 200) {
       final data = json.decode(response.body);
       debugPrint('User information updated successfully: $data');
        _showCustomSnackBar(context, 'User information updated successfully', Colors.green, Icons.check_circle);
     } else {
       debugPrint('Failed to update user information: ${response.body}');
       final errorData = json.decode(response.body);
       String errorMessage = errorData['message'] ?? 'An error occurred';
       _showCustomSnackBar(context, errorMessage, Colors.red, Icons.error);
     }
   } catch (e) {
     debugPrint('Error updating user information: $e');
   } finally {
     setState(() {
       isSubmitting = false;
     });
   }
 }

Future<void> onRefresh() async {
    setState(() {
      isLoading = true;
    });
    await fetchUserInfo();
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
    final theme = Theme.of(context);
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
                  "User Information",
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

      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
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
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                     _sectionTitle('Company Information'),
                      _infoRow('Company Name', companyname ?? 'N/A'),
                      _infoRow('Company ID', companyid ?? 'N/A'),
                      _infoRow('Department', department ?? 'N/A'),
                          
                      const SizedBox(height: 15),

                      Divider(color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 15),

                Text(
                'Personal Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                  Row(
                    children: [
                      Expanded(
                        child: _inlineEditableField(
                          icon: Icons.face,
                          title: 'Username',
                          value: username ?? '',
                          onSaved: (value) => username = value,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                    child : _inlineEditableField(
                      icon: Icons.person_2,
                      title: 'First Name',
                      value: firstname ?? '',
                      onSaved: (value) => firstname = value,
                    ),
                  ),
                ],
              ),

                  Row(
                    children: [
                  Expanded(
                  child: _inlineEditableField(
                      icon: Icons.family_restroom,
                      title: 'Father Name',
                      value: fathername ?? '',
                      onSaved: (value) => fathername = value,
                    ),
                  ),
                  const SizedBox(width: 16),
                    Expanded(
                   child: _inlineEditableField(
                      icon: Icons.person_3,
                      title: 'Last Name',
                      value: lastname ?? '',
                      onSaved: (value) => lastname = value,
                    ),
                  ),
                ],
              ),

                   _buildDatePickerField(
                            icon: Icons.calendar_today,
                            title: 'Date of Birth',
                            date: dateOfBirth,
                            onDateSelected: (newDate) {
                              setState(() => dateOfBirth = newDate);
                            },
                          ),

                          _buildGenderDropdown(),

                const SizedBox(height: 15),

              Divider(color: Colors.grey.withOpacity(0.5)),
              const SizedBox(height: 15),
                  
                Text(
                'Contact Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                    _inlineEditableField(
                      icon: Icons.email,
                      title: 'Email',
                      value: email ?? '',
                      onSaved: (value) => email = value,
                    ),

                    _inlineEditableField(
                      icon: Icons.home,
                      title: 'Address',
                      value: address ?? '',
                      onSaved: (value) => address = value,
                    ),

                    const SizedBox(height: 15),

              Divider(color: Colors.grey.withOpacity(0.5)),
              const SizedBox(height: 15),
                    
                  Text(
                'Offical Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                  Row(
                  children: [
                    Expanded(
                      child: _inlineEditableField(
                        icon: Icons.work,
                        title: 'Role',
                        value: role ?? '',
                        onSaved: (value) => role = value,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                    child: _inlineEditableField(
                      icon: Icons.bloodtype,
                      title: 'Blood Group',
                      value: bloodgroup ?? '',
                      onSaved: (value) => bloodgroup = value,
                    ),
                    ),
                  ],
                ),
                    _inlineEditableField(
                      icon: Icons.attach_money,
                      title: 'GST Number',
                      value: gstnumber ?? '',
                      onSaved: (value) => gstnumber = value,
                    ),
                    _inlineEditableField(
                      icon: Icons.credit_card,
                      title: 'PAN Number',
                      value: pannumber ?? '',
                      onSaved: (value) => pannumber = value,
                    ),

                    const SizedBox(height: 15),

                  _buildDatePickerField(
                        icon: Icons.calendar_today,
                        title: 'Date of Joining',
                        date: dateOfJoining,
                        onDateSelected: (newDate) {
                          setState(() => dateOfJoining = newDate);
                        },
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity, 
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : () async {
                           await updateUserInfo();
                          },
                          label: const Text('Update Information'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.send_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
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
                'Updating Information, please wait...',
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

  Widget _sectionTitle(String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
      color: Colors.black,
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
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDatePickerField({
  required IconData icon,
  required String title,
  required DateTime? date,
  required Function(DateTime) onDateSelected,
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  final newDate = await showDatePicker(
                    context: context,
                    initialDate: date ?? DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (newDate != null) {
                    onDateSelected(newDate);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select Date',
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildGenderDropdown() {
  String? validatedGender(){
    const validGenders = ['Male', 'Female'];
    if (validGenders.contains(gender)) {
      return gender;
    }
    return null;
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.transgender, size: 20, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'Gender',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              value: validatedGender(),
              decoration: const InputDecoration(
                isDense: false,
                contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => gender = value),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}


 Widget _inlineEditableField({
  required IconData icon,
  required String title,
  required String value,
  required FormFieldSetter<String> onSaved,
}) {
  final focusNode = FocusNode();
  final controller = TextEditingController(text: value);

  bool isEditing = false;

  return StatefulBuilder(
    builder: (context, setState) {
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                  const SizedBox(height: 4),
                  isEditing
                      ? TextFormField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            border: OutlineInputBorder(),
                          ),
                          onFieldSubmitted: (value) {
                            setState(() => isEditing = false);
                          },
                          onSaved: (newValue) {
                            onSaved(newValue ?? '');
                          },
                        )
                      : InkWell(
                          onTap: () {
                            setState(() => isEditing = true);
                          },
                          child: Text(
                            value.isNotEmpty ? value : 'Tap to edit',
                            style: TextStyle(fontSize: 15, color: value.isNotEmpty ? Colors.black : Colors.grey),
                          ),
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
  void dispose() {
    _formKey.currentState?.dispose();
    super.dispose();
  }
}

