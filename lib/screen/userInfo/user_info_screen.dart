import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class UserInfo extends StatefulWidget {
  const UserInfo({super.key});

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> {

  final baseUrl = dotenv.env['API_BASE_URL'];
  final _formKey = GlobalKey<FormState>();
  
  String? username,firstname,lastname,email,fathername,address,gender,role,bloodgroup,gstnumber,pannumber,employeeId,profileImage;
  String? department,companyname,companyid;
  DateTime? dateOfBirth;
  DateTime? dateOfJoining;
  bool isLoading = true;
  bool isSubmitting = false;  
  XFile? _imageFile;

@override
void initState() {
  super.initState();
  fetchUserInfo();
}

Future<void> updateProfileImage() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile != null) {
    setState(() {
      _imageFile = pickedFile;
    });

    await updateUserInfo();
  } else {
    debugPrint("No image selected.");
  }
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
          profileImage = data['em_image'] ?? '';
          role = data['em_role'];
          department = data['department']?['dep_name'];
          companyid = data['comp_id'];
          companyname = data['company']?['comp_fname'];
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
    barrierColor: Color(0xFF000000),
    barrierDismissible: true,
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
    //This is use without any image/documant ecetra ecetra... used for only update user info which have text field
     
    //  final response = await http.patch(
    //    Uri.parse('$baseUrl/api/employee/update/$userId'),
    //    headers: {
    //      'Content-Type': 'application/json',
    //    },
    //    body: json.encode({
    //      'em_username': username,
    //      'first_name': firstname,
    //      'last_name': lastname,
    //      'em_email': email,
    //      'father_name': fathername,
    //      'em_address': address,
    //      'em_gender': gender,
    //      'em_role': role,
    //      'em_blood_group': bloodgroup,
    //      'gst_number': gstnumber,
    //      'pancard': pannumber,
    //      'em_birthday': dateOfBirth?.toIso8601String(),
    //      'em_joining_date': dateOfJoining?.toIso8601String(),
    //    }),
    //  );



    //This method of update user info use when user have multiparted form/profile like image/video/documant along with text field like name,address,pin etc etc...

    final uri = Uri.parse('$baseUrl/api/employee/update/$userId');
    final request = http.MultipartRequest('PATCH', uri);

    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'application/json';

    request.fields['em_username'] = username ?? '';
    request.fields['first_name'] = firstname ?? '';
    request.fields['last_name'] = lastname ?? '';
    request.fields['em_email'] = email ?? '';
    request.fields['father_name'] = fathername ?? '';
    request.fields['em_address'] = address ?? '';
    request.fields['em_gender'] = gender ?? '';
    request.fields['em_role'] = role ?? '';
    request.fields['em_blood_group'] = bloodgroup ?? '';
    request.fields['gst_number'] = gstnumber ?? '';
    request.fields['pancard'] = pannumber ?? '';
    request.fields['em_birthday'] = dateOfBirth?.toIso8601String() ?? '';
    request.fields['em_joining_date'] = dateOfJoining?.toIso8601String() ?? '';

    if (_imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'em_image', 
        _imageFile!.path,
      ));
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);


     if (response.statusCode == 200) {
       final data = json.decode(response.body);
       debugPrint('User information updated successfully: $data');
        _showCustomSnackBar(context, 'User information updated successfully', Colors.green, Icons.check_circle);

        setState(() {
        profileImage = data['em_image'] ?? profileImage;
      });


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

Future<void> _onRefresh() async {
    setState(() {
      isLoading = true;
    });

    await fetchUserInfo();

    setState(() {
      isLoading = false;
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
    ),

      isLoading ? const Center(child: CircularProgressIndicator(color: Colors.black,)) 
      : RefreshIndicator(
        onRefresh: _onRefresh,
        backgroundColor: Colors.white,
        color: Colors.black,
            child : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 60),
                      child: Card(
                        color: const Color(0xFFFDFDFD),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),

                child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 95, 16, 16),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                     _sectionTitle('Company Information'),
                     
                     const SizedBox(height: 8),

                      _infoRow('Company Name', companyname ?? 'N/A'),
                      _infoRow('Company ID', companyid ?? 'N/A'),
                      _infoRow('Department', department ?? 'N/A'),
                          
                      const SizedBox(height: 12),

                      Divider(color: Colors.grey.withOpacity(0.3)),
                      const SizedBox(height: 12),

                    Text(
                    'Personal Information',
                    style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                      ),
                    ),

                const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _inlineEditableField(
                          icon: Icons.face,
                          title: 'Username',
                          value: username ?? '',
                          onSaved: (value) => username = value,
                          enabled: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                    child : _inlineEditableField(
                      icon: Icons.person_2,
                      title: 'First Name',
                      value: firstname ?? '',
                      onSaved: (value) => firstname = value,
                      enabled: false,
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
                      enabled: false,
                    ),
                  ),
                  const SizedBox(width: 16),
                    Expanded(
                   child: _inlineEditableField(
                      icon: Icons.person_3,
                      title: 'Last Name',
                      value: lastname ?? '',
                      onSaved: (value) => lastname = value,
                      enabled: false,
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
                  enabled: false
                ),

                _buildGenderDropdown(),

              const SizedBox(height: 12),

              Divider(color: Colors.grey.withOpacity(0.3)),
              const SizedBox(height: 12),
                  
                Text(
                'Contact Information',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                    _inlineEditableField(
                      icon: Icons.email,
                      title: 'Email',
                      value: email ?? '',
                      onSaved: (value) => email = value,
                      enabled: false
                    ),

                    _inlineEditableField(
                      icon: Icons.home,
                      title: 'Address',
                      value: address ?? '',
                      onSaved: (value) => address = value,
                      enabled: false
                    ),

                    const SizedBox(height: 12),

                    Divider(color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    
                    Text(
                    'Offical Details',
                    style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    ),
                  ),

                const SizedBox(height: 8),

                  Row(
                  children: [
                    Expanded(
                      child: _inlineEditableField(
                        icon: Icons.work,
                        title: 'Role',
                        value: role ?? '',
                        onSaved: (value) => role = value,
                        enabled: false
                      ),
                    ),
                    _buildBloodGroupDropdown(),
                  ],
                ),
                    // _inlineEditableField(
                    //   icon: Icons.attach_money,
                    //   title: 'GST Number',
                    //   value: gstnumber ?? '',
                    //   onSaved: (value) => gstnumber = value,
                    //   enabled: false
                    // ),

                    _inlineEditableField(
                      icon: Icons.credit_card,
                      title: 'PAN Number',
                      value: pannumber ?? '',
                      onSaved: (value) => pannumber = value,
                      enabled: false
                    ),

                    const SizedBox(height: 15),

                  _buildDatePickerField(
                        icon: Icons.calendar_today,
                        title: 'Date of Joining',
                        date: dateOfJoining,
                        onDateSelected: (newDate) {
                          setState(() => dateOfJoining = newDate);
                        },
                        enabled: false,
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity, 
                        child: ElevatedButton.icon(
                          onPressed: isSubmitting ? null : () async {
                           await updateUserInfo();
                          },
                          label: const Text('Update Information',style: TextStyle(color: Colors.black87),),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Color.fromARGB(255, 245, 247, 250),
                            iconColor: Colors.black,
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

      Positioned( 
         child: GestureDetector(
        onTap: () {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'ImageView',
        barrierColor: Colors.black.withOpacity(0.6),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Center(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PhotoView(
        imageProvider: NetworkImage('$baseUrl/api/employee/attachment/$profileImage'),
        backgroundDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        enableRotation: false,
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.contained,
        initialScale: PhotoViewComputedScale.contained,
      ),
    ),
  ),
);

        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
      );
    },

    child: Stack(
    children: [
     Container(
      padding: const EdgeInsets.all(4), 
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.blueGrey,
          width: 2,               
        ),    
    ),
        child: CircleAvatar(
          radius: 70,
          backgroundColor: Colors.white,
          backgroundImage: NetworkImage('$baseUrl/api/employee/attachment/$profileImage'),
          ),
      ),
      Positioned(
      bottom: 11,
      right: 11,
      child: GestureDetector(
        onTap: updateProfileImage,
        child: CircleAvatar(
          radius: 13,
          backgroundColor: Colors.blueGrey,
          child: const Icon(Icons.edit, size: 16, color: Colors.white),
          ),
        ),
        ),
      ],
    ),
      ),
      ),
      ],  
    ),
  ),
),

    if (isSubmitting)
    Positioned.fill(
     child: Container(
        color: Colors.black.withOpacity(0.3), 
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
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color.fromARGB(221, 0, 0, 0),
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
  bool enabled = true,
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
                onTap: enabled ? () async {
                  final newDate = await showDatePicker(
                    context: context,
                    initialDate: date ?? DateTime.now(),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (newDate != null) {
                    onDateSelected(newDate);
                  }
                }
                : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    date != null ? DateFormat('dd MMM yyyy').format(date) : 'Select Date',
                    style: TextStyle(fontSize: 15, color: enabled ? Colors.black87 : Colors.grey,),
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
              dropdownColor: Colors.white,
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

Widget _buildBloodGroupDropdown() {
  String? validatedBloodGroup(){
    const validBloodGroups = ['A+','A-','B+','B-','O+','O-','AB+','OB+'];
    if (validBloodGroups.contains(bloodgroup)) {
      return bloodgroup;
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
              'Blood Group',
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
              value: validatedBloodGroup(),
              decoration: const InputDecoration(
                isDense: false,
                contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                border: OutlineInputBorder(),
              ),
              dropdownColor: Colors.white,
              onChanged: (value) => setState(() => bloodgroup = value),
              items: const [
                DropdownMenuItem(value: 'A+', child: Text('A+')),
                DropdownMenuItem(value: 'A-', child: Text('A-')),
                DropdownMenuItem(value: 'B+', child: Text('B+')),
                DropdownMenuItem(value: 'B-', child: Text('B-')),
                DropdownMenuItem(value: 'O+', child: Text('O+')),
                DropdownMenuItem(value: 'O-', child: Text('O-')),
                DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                DropdownMenuItem(value: 'OB+', child: Text('OB+')),
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
  bool enabled = true, 
}) {
  final controller = TextEditingController(text: value);

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
              TextFormField(
                controller: controller,
                readOnly: !enabled, 
                enabled: enabled,
                style: TextStyle(fontSize: 15,
                color: enabled ? Colors.black : Colors.blueGrey.shade900,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  border: enabled ?  OutlineInputBorder() : InputBorder.none, 
                  filled: !enabled,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: const OutlineInputBorder( 
                    borderSide: BorderSide(color: Colors.deepPurple, width: 1.5),
                  ),
                  fillColor: Colors.transparent,
                ),
                onSaved: (newValue) => onSaved(newValue ?? ''),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  @override
  void dispose() {
    _formKey.currentState?.dispose();
    super.dispose();
  }
}

