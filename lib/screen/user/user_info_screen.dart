import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../utils/user_session.dart';
import '../utils/network_failure.dart';
import '../helper/top_snackbar.dart';

class UserInfo extends StatefulWidget {
  const UserInfo({super.key});

  @override
  State<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends State<UserInfo> with SingleTickerProviderStateMixin {
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];
  final _formKey = GlobalKey<FormState>();

  String? username,
      firstname,
      designation,
      email,
      fathername,
      address,
      gender,
      role,
      bloodgroup,
      pannumber,
      employeeId,
      profileImage,
      manager;
  String? department,
      companyname,
      companyid,
      phone,
      city,
      country,
      employeeCode,
      branch,
      category,
      aadhar,
      emergencycontact,
      _error,
      physicallchallenged;
  DateTime? dateOfBirth;
  DateTime? dateOfJoining;
  bool isLoading = true;
  bool isSubmitting = false;
  XFile? _imageFile;

  TextEditingController _newPasswordController = TextEditingController();
  TextEditingController _currentPasswordController = TextEditingController();


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
    final token = await UserSession.getToken();

    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userId = await UserSession.getUserId();

    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/MyApis/userinfo?user_id=$userId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': token,
        },
      );

      // debugPrint('Response Status: ${response.statusCode}');

      await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      if (response.statusCode == 200) {
        final finalData = json.decode(response.body);
        final data = finalData['data_packet'];
        // print('Data: $data');

        setState(() {
          employeeId = data['em_id'];
          employeeCode = data['em_code'];
          firstname = data['name'];
          designation = data['des_name'];
          email = data['em_email'];
          fathername = data['father_name'];
          address = data['address'];
          manager = data['manager_name'];
          city = data['city'];
          country = data['country'];
          phone = data['em_phone'];
          emergencycontact = data['emergencycontact'];
          gender = data['em_gender'];
          profileImage = data['image_url'] ?? '';
          role = data['em_role'];
          category = data['category_name'];
          department = data['dep_name'];
          companyid = data['comp_id'];
          companyname = data['comp_fname'];
          bloodgroup = data['em_blood_group'];
          aadhar = data['em_nid'];
          branch = data['branch_name'];
          pannumber = data['pancard'];
          dateOfBirth =
              data['em_birthday'] != null
                  ? DateTime.parse(data['em_birthday'])
                  : null;
          dateOfJoining =
              data['em_joining_date'] != null
                  ? DateTime.parse(data['em_joining_date'])
                  : null;

          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> updateUserInfo() async {
    if (isSubmitting) return;
    setState(() {
      isSubmitting = true;
    });

    final token = await UserSession.getToken();

    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final userId = await UserSession.getUserId();

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

    /***********************************************************************/


      //This method of update user info use when user have multiparted form/profile like image/video/documant along with text field like name,address,pin etc etc...

      final uri = Uri.parse('$baseUrl/api/employee/update/$userId');
      final request = http.MultipartRequest('PATCH', uri);

      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'application/json';

      request.fields['em_username'] = username ?? '';
      request.fields['first_name'] = firstname ?? '';
      request.fields['em_email'] = email ?? '';
      request.fields['father_name'] = fathername ?? '';
      request.fields['em_address'] = address ?? '';
      request.fields['em_gender'] = gender ?? '';
      request.fields['em_role'] = role ?? '';
      request.fields['em_blood_group'] = bloodgroup ?? '';
      request.fields['pancard'] = pannumber ?? '';
      request.fields['em_birthday'] = dateOfBirth?.toIso8601String() ?? '';
      request.fields['em_joining_date'] = dateOfJoining?.toIso8601String() ?? '';

      // request.fields['last_name'] = lastname ?? '';
      // if (_imageFile != null) {
      //   request.files.add(await http.MultipartFile.fromPath(
      //     'em_image',
      //     _imageFile!.path,
      //   ));
      // }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('User information updated successfully: $data');
        showCustomSnackBar(
          context,
          'User information updated successfully',
          Colors.green,
          Icons.check_circle,
        );

        setState(() {
          profileImage = data['em_image'] ?? profileImage;
        });
      } else {
        debugPrint('Failed to update user information: ${response.body}');
        final errorData = json.decode(response.body);
        String errorMessage = errorData['message'] ?? 'An error occurred';
        showCustomSnackBar(context, errorMessage, Colors.red, Icons.error);
      }
    } catch (e) {
      debugPrint('Error updating user information: $e');
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }

Future<void> updateUserPassword() async {
  if (isSubmitting) return;
  setState(() {
    isSubmitting = true;
  });

  final token = await UserSession.getToken();

  if (token == null) {
    Navigator.pushReplacementNamed(context, '/login');
    return;
  }

  final empId = await UserSession.getUserId();
  
  final currentPassword = _currentPasswordController.text;
  final newPassword = _newPasswordController.text;

  try {
    final url = Uri.parse('$baseUrl/MyApis/changethepassword');

    final response = await http.patch(url, 
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiToken',
      'auth_token': token,
      'user_id': empId!
    },
    body: json.encode({
      'current_password': currentPassword,
      'new_password': newPassword
    }));

    debugPrint("response:-${response.body} current_password:-${currentPassword}}");

    await UserSession.checkInvalidAuthToken(
      context,
      json.decode(response.body),
      response.statusCode,  
    );

    if(response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint('Password updated successfully: $data');
      _currentPasswordController.clear();
      _newPasswordController.clear();
      showCustomSnackBar(
        context,
        'Password updated successfully',
        Colors.green,
        Icons.check_circle,
      );
    } else {
      debugPrint('Failed to update password: ${response.body}');
      final errorData = json.decode(response.body);
      String errorMessage = errorData['message'] ?? 'An error occurred';
      showCustomSnackBar(context, errorMessage, Colors.red, Icons.error);
    }
  } catch (e) {
    showCustomSnackBar(context, e.toString(), Colors.red, Icons.error);
  }finally {
    setState(() {
      isSubmitting = false;
    });
  }

}
  Future<void> _onRefresh() async {
    setState(() {
      isLoading = true;
      _error = null;
    });

    await fetchUserInfo();

    setState(() {
      isLoading = false;
    });
  }


@override
  void dispose() {
    _formKey.currentState?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),

    //    appBar: AppBar(
    //     title: const Text(
    //       "Profile ",
    //       style: TextStyle(fontWeight: FontWeight.bold),
    //     ),
    //   // backgroundColor: Colors.transparent, 
    //   forceMaterialTransparency: true,
    //     elevation: 3,
    // ),

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
    ),

    (_error != null)
      ? NoInternetWidget(onRetry: _onRefresh) 
    :isLoading
        ?  Center(
          child: CircularProgressIndicator(color: Theme.of(context).iconTheme.color),
        )
        : RefreshIndicator(
          onRefresh: _onRefresh,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          color: Theme.of(context).iconTheme.color,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 60),
                  child: Card(
                    color: Theme.of(context).brightness == Brightness.light
                      ? Color(0xFFFDFDFD)
                      : Color(0xFF121212),
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
                          _sectionTitle('Employee Information'),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: _inlineEditableField(
                                  icon: Icons.face,
                                  title: 'Employee Code',
                                  value: employeeCode ?? '',
                                  onSaved:
                                      (value) => employeeCode = value,
                                  enabled: false,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _inlineEditableField(
                                  icon: Icons.developer_mode_rounded,
                                  title: 'Designation',
                                  value: designation ?? '',
                                  onSaved:
                                      (value) => designation = value,
                                  enabled: false,
                                ),
                              ),
                            ],
                          ),

                        Row(
                          children: [
                            Expanded(
                              child: _inlineEditableField(
                                icon: Icons.developer_board,
                                title: 'Department',
                                value: department ?? '',
                                onSaved:
                                    (value) => department = value,
                                enabled: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _inlineEditableField(
                                icon: Icons.design_services_sharp,
                                title: 'Employee Type',
                                value: category ?? '',
                                onSaved:
                                    (value) => category = value,
                                enabled: false,
                              ),
                            ),
                          ],
                        ),

                      _inlineEditableField(
                        icon: Icons.person_2,
                        title: 'Name',
                        value: firstname ?? '',
                        onSaved:
                            (value) => firstname = value,
                        enabled: false,
                          ),

                      const SizedBox(width: 16),

                        _inlineEditableField(
                        icon: Icons.person_4,
                        title: 'Father Name',
                        value: fathername ?? '',
                        onSaved:
                            (value) => fathername = value,
                        enabled: false,
                      ),

                        _inlineEditableField(
                          icon: Icons.apartment,
                          title: 'Company',
                          value: companyname ?? '',
                          onSaved: (value) => companyname = value,
                          enabled: false,
                        ),

                        _inlineEditableField(
                          icon: Icons.location_city_sharp,
                          title: 'Branch',
                          value: branch ?? 'N/A',
                          onSaved: (value) => branch = value,
                          enabled: false,
                        ),
                        _inlineEditableField(
                          icon: Icons.supervisor_account,
                          title: 'Manager',
                          value: manager ?? 'N/A',
                          onSaved: (value) => manager = value,
                          enabled: false,
                        ),

                        const SizedBox(height: 12),

                        Divider(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12), 

                        _sectionTitle('Contact Information'),

                        const SizedBox(height: 8),

                        _inlineEditableField(
                          icon: Icons.call,
                          title: 'Phone',
                          value: phone ?? '',
                          onSaved: (value) => phone = value,
                          enabled: false,
                        ),

                        _inlineEditableField(
                          icon: Icons.emergency_outlined,
                          title: 'Emergency Phone',
                          value: emergencycontact ?? '',
                          onSaved:
                              (value) => emergencycontact = value,
                          enabled: false,
                        ),

                        _inlineEditableField(
                          icon: Icons.email,
                          title: 'Email',
                          value: email ?? '',
                          onSaved: (value) => email = value,
                          enabled: false,
                        ),

                        _inlineEditableField(
                          icon: Icons.home,
                          title: 'Address',
                          value:
                              '${address ?? ''}, ${city ?? ''}, ${country ?? ''}',
                          onSaved: (value) => address = value,
                          enabled: false,
                        ),

                        const SizedBox(height: 12),

                        Divider(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),

                       _sectionTitle('Offical Details'),

                        const SizedBox(height: 8),
                        
                        _inlineEditableField(
                          icon: Icons.credit_score,
                          title: 'Aadhar Number',
                          value: aadhar ?? '',
                          onSaved: (value) => aadhar = value,
                          enabled: false,
                        ),

                        _inlineEditableField(
                          icon: Icons.credit_card,
                          title: 'PAN Number',
                          value: pannumber ?? '',
                          onSaved: (value) => pannumber = value,
                          enabled: false,
                        ),

                        // const SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(child: _buildGenderDropdown()),
                            const SizedBox(width: 12),
                            _buildBloodGroupDropdown(),
                          ],
                        ),

                        const SizedBox(height: 15),

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _buildDatePickerField(
                                context: context,
                                icon: Icons.calendar_today,
                                title: 'Date of Birth',
                                date: dateOfBirth,
                                onDateSelected: (newDate) {
                                  setState(
                                    () => dateOfBirth = newDate,
                                  );
                                },
                                enabled: false,
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: _buildDatePickerField(
                                context: context,
                                icon: Icons.calendar_today,
                                title: 'Date of Joining',
                                date: dateOfJoining,
                                onDateSelected: (newDate) {
                                  setState(
                                    () => dateOfJoining = newDate,
                                  );
                                },
                                enabled: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),

                        _sectionTitle('Change Password'),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.blueGrey, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Colors.blueGrey, width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      ),
                    ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                isSubmitting
                                    ? null
                                    : () async {
                                      await updateUserPassword();
                                    },
                            label: const Text(
                              'Update Password',
                              style: TextStyle(
                                color: Colors.black87,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              backgroundColor: Color.fromARGB(
                                255,
                                245,
                                247,
                                250,
                              ),
                              iconColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  8,
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.send_outlined,
                              size: 20,
                            ),
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
                  transitionDuration: const Duration(
                    milliseconds: 300,
                  ),
                  pageBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                  ) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: PhotoView.customChild(
                          backgroundDecoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          enableRotation: false,
                          minScale:
                              PhotoViewComputedScale.contained,
                          maxScale:
                              PhotoViewComputedScale.contained,
                          initialScale:
                              PhotoViewComputedScale.contained,

                          child: Image.network(
                            profileImage != null &&
                                    profileImage!.isNotEmpty
                                ? '$profileImage'
                                : 'assets/icon/face-id.png',
                            fit: BoxFit.contain,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Image.asset(
                                'assets/icon/face-id.png',
                              );
                            },
                          ),

                          // enableRotation: false,
                          // minScale: PhotoViewComputedScale.contained,
                          // maxScale: PhotoViewComputedScale.contained,
                          // initialScale: PhotoViewComputedScale.contained,
                        ),
                      ),
                    );
                  },
                  transitionBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    return ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
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
                          backgroundImage:
                          profileImage != null &&
                                  profileImage!.isNotEmpty
                              ? NetworkImage('$profileImage')
                              : const AssetImage(
                                    'assets/icon/face-id.png',
                                  )
                                  as ImageProvider,
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
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
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
        // color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // Widget _infoRow(String label, String value) {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 8),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         SizedBox(
  //           width: 120,
  //           child: Text(
  //             "$label:",
  //             style: const TextStyle(
  //               fontWeight: FontWeight.w600,
  //               fontSize: 15,
  //               color: Color.fromARGB(221, 0, 0, 0),
  //             ),
  //           ),
  //         ),
  //         Expanded(
  //           child: Text(
  //             value,
  //             style: const TextStyle(fontSize: 15, color: Colors.black87),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildDatePickerField({
    required BuildContext context, 
    required IconData icon,
    required String title,
    required DateTime? date,
    required Function(DateTime) onDateSelected,
    bool enabled = true,
  }) {

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.iconTheme.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap:
                      enabled
                          ? () async {
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.shade800 
                        : Colors.grey.shade200, 
                    borderRadius: BorderRadius.circular(8),
                  ),
                    child: Text(
                      date != null
                          ? DateFormat('dd MMM yyyy').format(date)
                          : 'Select Date',
                      style: TextStyle(
                        fontSize: 15,
                        color: enabled
                          ? theme.textTheme.bodyLarge?.color
                          : Colors.grey,
                      ),
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
    bool enabled = false;
    String? validatedGender() {
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
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(),
                ),
                onChanged: enabled ?(value) => setState(() => gender = value) : null,
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
    bool enabled = false;
    String? validatedBloodGroup() {
      const validBloodGroups = [
        'A+',
        'A-',
        'B+',
        'B-',
        'O+',
        'O-',
        'AB+',
        'OB+',
      ];
      if (validBloodGroups.contains(bloodgroup)) {
        return bloodgroup;
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
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
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(),
                ),
                dropdownColor: Colors.white,
                onChanged: enabled ? (value) => setState(() => bloodgroup = value) : null ,
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                 SizedBox(height: 4),
                TextFormField(
                  controller: controller,
                  readOnly: !enabled,
                  enabled: enabled,
                  style: TextStyle(
                    fontSize: 15,
                    color: enabled ? Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.blueGrey.shade900 : Colors.grey.shade600,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    border: enabled ? OutlineInputBorder() : InputBorder.none,
                    filled: !enabled,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.deepPurple,
                        width: 1.5,
                      ),
                    ),
                    fillColor: Colors.transparent,
                  ),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  onSaved: (newValue) => onSaved(newValue ?? ''),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 static const fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Colors.grey),
);

  
}
