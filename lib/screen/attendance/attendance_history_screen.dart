import 'package:flutter/material.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "package:url_launcher/url_launcher.dart";
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:lottie/lottie.dart';

class AttandanceHistory extends StatefulWidget {
  const AttandanceHistory({super.key});

  @override
  State<AttandanceHistory> createState() => _AttandanceHistoryState();
}

class _AttandanceHistoryState extends State<AttandanceHistory> with TickerProviderStateMixin {
  final baseUrl = dotenv.env['API_BASE_URL'];

  String? emId, emUsername, compFname, compId, department;
  List attendanceList = [];
  DateTime? selectedDate;
  String? errorMessage;
  bool isLoading = true;
  bool isFirstLoadDone = false; 
  // late final AnimationController _animationController;


  @override
  void initState() {
    super.initState();
    gettokenData();
    fetchAttendanceData(DateTime.now());

    //   _animationController = AnimationController(
    //   vsync: this,
    //   duration: const Duration(seconds: 30),
    // )..repeat();

  }

  // @override 
  // void dispose(){
  //    _animationController.dispose();
  //   super.dispose();

  // }

  String getFormattedDate(String dateString) {
    try {
    DateTime parsedDate = DateTime.parse(dateString);
    return DateFormat('dd-MMM').format(parsedDate);
    } catch (e) {
      return "Invalid Date"; 
    }
  }
  String FormattedDate(String timeString) {
  try {
    if (timeString.contains(' ')) {
      DateTime parsed = DateFormat('yyyy-MM-dd HH:mm:ss').parse(timeString);
      return DateFormat('hh:mm a').format(parsed); 
    }

    DateTime parsedTime = DateFormat('HH:mm:ss').parse(timeString);
    return DateFormat('hh:mm a').format(parsedTime);
  } catch (e) {
    return "Invalid Time format"; 
  }
}


  Future<void> gettokenData() async {
    final pref = await SharedPreferences.getInstance();
    final token = pref.getString('token') ?? '';
    final decode = Jwt.parseJwt(token);
    compFname = decode['comp_fname'] ?? '';
    department = decode['dep_name'] ?? '';
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null && picked != selectedDate) {
      setState(() {
        isLoading = true;
        selectedDate = picked;
      });
      
      await fetchAttendanceData(picked);

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchAttendanceData(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final decode = Jwt.parseJwt(token);
      emId = decode['em_id'] ?? '';
      print("emp_id: $emId");

      final formattedDate =
       "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      print("Formatted Date: $formattedDate");

      final url = Uri.parse(
        '$baseUrl/api/attendance/list?emp_id=$emId&punch_date=$formattedDate',
      );
      print("URL: $url");

      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'];
        
         attendanceList = data;

        await Future.delayed(Duration(seconds: 2));

        setState(() {
          isLoading = false;
          isFirstLoadDone = true;
        });
      } else {
        throw Exception(
          "Failed to load attendance data, status code: ${response.statusCode}",
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isFirstLoadDone = true;
        errorMessage = e.toString();
      });
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

  //   Widget buildAnimatedStripe({required double speedFactor, required Color color}) {
  //   return AnimatedBuilder(
  //     animation: _animationController,
  //     builder: (context, child) {
  //       // Move stripe from right to left (diagonally)
  //       return Transform.translate(
  //         offset: Offset(
  //           200 - (_animationController.value * speedFactor * 400),
  //           _animationController.value * speedFactor * 200,
  //         ),
  //         child: child,
  //       );
  //     },
  //     child: Transform.rotate(
  //       angle: -0.6, 
  //       child: Container(
  //         width: 20,
  //         height: 400,
  //         color: color,
  //       ),
  //     ),
  //   );
  // }


void showImagePreview(BuildContext context, String base64Image) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: PhotoView(
              imageProvider: MemoryImage(
                base64Decode(base64Image.split(',').last),
              ),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained,
              initialScale: PhotoViewComputedScale.contained,
              enableRotation: false,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInQuart,
      );

      final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        ),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      );
    },
  );
}

  Widget buildAttendanceCard(Map item) {
    final base64Image = item['punch_img'];
    final latitude = item['latitude'];
    final longitude = item['longitude'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            getFormattedDate(item['punch_date']),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildImageOrPlaceholder(base64Image, context),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            FormattedDate(item['punch_time']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                        item['punchtype'] == 'OUTSTATION1'
                                ? 'In'
                            : item['punchtype'] == 'OUTSTATION2'
                                ? 'Out'
                                : item['punchtype'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            
                            ),
                          ),
                        ),
                      ),
                        Expanded(
                          child: Text(
                            item['punch_place'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        if (latitude != null && longitude != null)
                          GestureDetector(
                            onTap: () => _launchMap(latitude, longitude),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Color.fromARGB(255, 222, 17, 17),
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "View",
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Expanded(
                          child: Text(
                            "Time",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Punch",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Place",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey
                            ),
                          ),
                        ),
                        Text(
                          "Location",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final passedDate = args?['selectedDate'] as DateTime?;

    if (passedDate != null && selectedDate == null) {
    selectedDate = passedDate;
    fetchAttendanceData(passedDate);
  }

    return Scaffold(
       backgroundColor: Color(0xFFF2F5F8),
      appBar: AppBar(
                title: const Text(
                  "Attendance History",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              backgroundColor: Colors.transparent, 
                forceMaterialTransparency: true,
                elevation: 0,
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

          // buildAnimatedStripe(
          //     speedFactor: 1.0, color: Colors.white.withOpacity(0.1)),
          // buildAnimatedStripe(
          //     speedFactor: 1.5, color: Colors.grey.withOpacity(0.1)),
          // buildAnimatedStripe(
          //     speedFactor: 2.0, color: Colors.white.withOpacity(0.07)),
          // buildAnimatedStripe(
          //     speedFactor: 2.5, color: Colors.grey.withOpacity(0.07)),

      Column(
        children: [
         Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft, 
              child: GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4EBF5),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.black87, size: 20),
                      const SizedBox(width: 12),
                      Text(
                      selectedDate == null ?
                      DateFormat('dd MMM yyyy').format(DateTime.now()) 
                    : DateFormat('dd MMM yyyy').format(selectedDate!),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.black,))
                    : isFirstLoadDone
                    ? attendanceList.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/image/Animation.json',
                              width: 180,
                              height: 180,
                              repeat: true,
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "No Attendance Records Found !",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    : RefreshIndicator(
                      color: Colors.black,
                      backgroundColor: Colors.white,
                      onRefresh: () async {
                        await fetchAttendanceData(
                          selectedDate ?? DateTime.now(),
                        );
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: attendanceList.length,
                        itemBuilder: (context, index) {
                          return buildAttendanceCard(attendanceList[index]);
                        },
                      ),
                    )
                    : const SizedBox(), 
          ),
        ],
      )
       ],
      )
    );
  }


Widget buildImageOrPlaceholder(String? base64Image, BuildContext context) {
  try {
    if (base64Image != null &&
        base64Image.isNotEmpty &&
        base64Image.contains(',')) {
      final imageBytes = base64Decode(base64Image.split(',').last);

      return GestureDetector(
        onTap: () => showImagePreview(context, base64Image),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            imageBytes,
            height: 80,
            width: 80,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return _buildPlaceholderContainer();
    }
  } catch (e) {
    return _buildPlaceholderContainer();
  }
}

Widget _buildPlaceholderContainer() {
  return Container(
    height: 130,
    width: 130,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.image_not_supported,
      size: 40,
      color: Colors.grey,
    ),
  );
}
}
