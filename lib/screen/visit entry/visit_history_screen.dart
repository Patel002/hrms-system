import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import "package:url_launcher/url_launcher.dart";
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:lottie/lottie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/user_session.dart';

class VisitHistory extends StatefulWidget {
  const VisitHistory({super.key});

  @override
  State<VisitHistory> createState() => _VisitHistoryState();
}

  class _VisitHistoryState extends State<VisitHistory> with TickerProviderStateMixin {
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  String? emId, emUsername, compFname, compId, department;
  List visitList = [];
  Map<String, dynamic> vistorList = {};
  DateTime? selectedDate;
  String? errorMessage,visitorName;
  bool isLoading = true;
  bool isFirstLoadDone = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final passedDate = args?['selectedDate'] as DateTime?;

    if (passedDate != null) {
      setState(() {
        selectedDate = passedDate;
      });
      fetchVisitData(passedDate);
    } else {
      final today = DateTime.now();
      setState(() {
        selectedDate = today;
      });
      fetchVisitData(today);
    }
  });
}

  String getFormattedDate(String dateString) {
    try {
    DateTime parsedDate = DateFormat('dd/MM/yyyy').parse(dateString);
    return DateFormat('dd-MMM').format(parsedDate);
    } catch (e) {
      return "Invalid Date"; 
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (picked != null && picked != selectedDate) {
      setState(() {
        isLoading = true;
        selectedDate = picked;
      });
      
      await fetchVisitData(picked);

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchVisitData(DateTime date) async {
    try {

      final token = await UserSession.getToken();

      if(token == null){
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      emId = await UserSession.getUserId();
     
      print("emp_id: $emId");

      final formattedDate =
       "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      print("Formatted Date: $formattedDate");

      final url = Uri.parse(
        '$baseUrl/MyApis/visittherecords?from_date=$formattedDate&to_date=$formattedDate',
      );
      print("URL: $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': token,
          'user_id': emId!
        },
      );

      print("Response Status Code: ${response.statusCode}");
      print("url: $response");
      print("body: ${response.body}");

      final jsonData = json.decode(response.body);

       await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

     if (response.statusCode == 200) {
        if (jsonData['data_packet'] != null && jsonData['data_packet'] is List) {
          visitList = jsonData['data_packet'];
          vistorList = jsonData['user_details'] ?? {};

        
          visitorName = vistorList['name'] ?? 'N/A';
          // print("Visitor Name: $visitorName");
          // print("Visit List: $visitList");
          // print("image from visit list:${visitList[0]['visit_img']}");
        } else {
          visitList = [];
          vistorList = {};
        }

      await Future.delayed(Duration(seconds: 2));

        setState(() {
          isLoading = false;
          isFirstLoadDone = true;
        });
      } else {
        throw Exception(
          "Failed to load visit entry data, status code: ${response.statusCode}",
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

void showImagePreview(BuildContext context, String image) {
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
              imageProvider: NetworkImage(image),
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

void _showDetailsOfVisit(Map item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[300]
                      : Color(0xFF121212),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Title
                Text(
                  "Visit Details",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).iconTheme.color,
                  ),
                ),
                const SizedBox(height: 16),

                
                _buildDetailRow(FontAwesomeIcons.calendar,"  Date", getFormattedDate(item['day_id_formatted'])),

                _buildDetailRow(FontAwesomeIcons.clock,"  Time", item['visit_time_formatted'] ?? '-'),

                _buildDetailRow(FontAwesomeIcons.user,"  Visitor Name", visitorName ?? '-'),

                _buildDetailRow(FontAwesomeIcons.briefcase,"  Visit Type", item['visit_type'] ?? '-'),

                _buildDetailRow(FontAwesomeIcons.building,"  Visit Company", item['party_name'] ?? '-'),

                _buildDetailRow(FontAwesomeIcons.carSide, "  Travelling Mode", item['travel_mode'] ?? 'None'),

                _buildDetailRow(FontAwesomeIcons.locationCrosshairs,'  To Address', item['to_location'] ?? 'N/A'),

                _buildDetailRow(FontAwesomeIcons.locationArrow,'  From Address', item['from_location'] ?? 'N/A'),

                _buildDetailRow(FontAwesomeIcons.road,"  Distance", item['distance'] ?? '0.0 km'),
                

                const SizedBox(height: 8),

                if (item['latitude'] != null && item['longitude'] != null)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      elevation: 0,
                    ),
                    onPressed: () => _launchMap(item['latitude'], item['longitude']),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text(
                      "View Location",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildDetailRow(IconData icon, String label, String value) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    decoration: BoxDecoration(
    color: Theme.of(context).brightness == Brightness.light
  ? Colors.grey.shade50
  : Color(0xFF121212),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey.withOpacity(0.7)),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade300 : Colors.black87,
            ),
          ),
        ),
      ],
    ),
  );
}



  Widget buildAttendanceCard(Map item) {
    final image = item['visit_img'];
    // final latitude = item['latitude'];
    // final longitude = item['longitude'];

    return GestureDetector(
      onTap: () {
        _showDetailsOfVisit(item);
  },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Color(0xFFF5F7FA),
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
            getFormattedDate(item['day_id_formatted']),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
               color: Theme.of(context).iconTheme.color,
            ),
          ),

          const SizedBox(height: 12),
          Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildImageOrPlaceholder(image, context),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                        child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            (item['visit_time_formatted'] ?? ''),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      Container(
                        height: 16,
                        width: 1,
                        color: Colors.grey.shade400,
                       margin: const EdgeInsets.only(right: 20.0),
                      ),

                        Expanded(
                          child: Padding(
                          padding:  EdgeInsets.symmetric(horizontal: 10.h),
                          child: Text(
                            item['visit_type'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      ],
                    ),
                  
                    const SizedBox(height: 4),
                    Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20.0),
                        child: Text(
                          "Time",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),

                    Container(
                      height: 0, 
                      width: 1,
                      color: Colors.transparent,
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 45.5),
                        child: Text(
                          "Visit",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
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
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      appBar: AppBar(
                title: Text(
                  "Visit History",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              backgroundColor: Colors.transparent, 
                forceMaterialTransparency: true,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87,
                elevation: 0,
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
          ),

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
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Color(0xFFF2F5F8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).iconTheme.color!.withOpacity(0.2),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                    child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, color: Theme.of(context).iconTheme.color, size: 20),
                      const SizedBox(width: 12),
                      Text(
                      selectedDate == null ?
                      DateFormat('dd MMM yyyy').format(DateTime.now()) 
                    : DateFormat('dd MMM yyyy').format(selectedDate!),
                        style:TextStyle(
                          color: Theme.of(context).iconTheme.color,
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
                    ? Center(child:CircularProgressIndicator(color: Theme.of(context).iconTheme.color,))
                    : isFirstLoadDone
                    ? visitList.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Lottie.asset(
                              'assets/image/Animation.json',
                              width: 200,
                              height: 200,
                              repeat: true,
                              fit: BoxFit.cover
                            ),
                            const SizedBox(height: 5),
                             Text(
                              "No Visit Entry Records Found !",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey : Colors.black87,
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
                        await fetchVisitData(
                          selectedDate ?? DateTime.now(),
                        );
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: visitList.length,
                        itemBuilder: (context, index) {
                          return buildAttendanceCard(visitList[index]);
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


Widget buildImageOrPlaceholder(String? image, BuildContext context) {
  try {
    if (image != null && image.isNotEmpty) {
      if (image.contains('data:image')) {
        // Base64 image
        final imageBytes = base64Decode(image.split(',').last);
        return GestureDetector(
          onTap: () => showImagePreview(context, image),
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
        // URL
        return GestureDetector(
          onTap: () => showImagePreview(context, image),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              image,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderContainer();
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 80,
                  width: 80,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.black87,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes!)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    } else {
      return _buildPlaceholderContainer();
    }
  } catch (e) {
    print("Image load error: $e");
    return _buildPlaceholderContainer();
  }
}


Widget _buildPlaceholderContainer() {
  return Container(
    height: 95,
    width: 95,
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade300,
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
