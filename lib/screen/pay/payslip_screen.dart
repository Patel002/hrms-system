import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';  
import 'package:shimmer/shimmer.dart';
import 'package:toastification/toastification.dart';
import 'package:open_filex/open_filex.dart';
// import 'dart:io';
import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final baseUrl = dotenv.env['API_BASE_URL'];
  String? empId, emUsername, compId, selectedDate;
  List<Map<String, dynamic>> payslipList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero,() async{
    await fetchPaySlipDate();
  });
  }

  Future<void> fetchPaySlipDate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    // print("token: $token");

    if (token != null) {
      Map<String, dynamic> payload = Jwt.parseJwt(token);
      setState(() {
        empId = payload['em_id'];
        emUsername = payload['first_name'];
        compId = payload['comp_id']; 
      });
    }

    try{
      setState(() {
        isLoading = true;
      });
      final response = await http.get(Uri.parse('$baseUrl/api/payslip/payslip?emp_id=$empId'));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data'];

        // print('Payslip List: $data');

        data.sort((a, b) => b['salarydate'].compareTo(a['salarydate']));

        setState(() {
          payslipList = data.cast<Map<String, dynamic>>();
        });

        print('Payslip List: $payslipList');
      } else {
        showToast("Failed to load payslips", ToastificationType.error);
      }
    }catch(e){
      print(e); 
      showToast("Error: ${e.toString()}", ToastificationType.error);
      setState(() {
        isLoading = false;
      });
    } finally{
      setState(() {
        isLoading = false;
      });
  }
}

Future <void> _refreshPage() async {
  setState(() {
    isLoading = true;
  });
  await fetchPaySlipDate();
  showToast("Payslip list refreshed", ToastificationType.success);

  setState(() {
    isLoading = false;
  });
}

//   void openPdfInDrive(int payslipId) async {

//   final encodedId = base64Url.encode(utf8.encode(payslipId.toString()));

//   final url = 'https://morth.nic.in/sites/default/files/dd12-13_0.pdf';
//   final uri = Uri.parse(url);

//   if (await canLaunchUrl(uri)) {
//     await launchUrl(uri, mode: LaunchMode.externalApplication);
//   } else {
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Could not launch PDF')),
//     );
//   }
// }


Future<void> downloadAndOpenPdf(BuildContext context, String url, String fileName) async {
  try {
    // if (Platform.isAndroid) {
    //  var status = await Permission.manageExternalStorage.request();

    //       if (!status.isGranted) {
    //       openAppSettings();
    //       return;
    //     }
    //   }
      
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';

    await Dio().download(url, filePath);

    await OpenFilex.open(filePath);
  } catch (e) {
    showToast("Failed to open PDF: ${e.toString()}", ToastificationType.error);

  }
}


void showToast(String message, ToastificationType type) {
    if (!mounted) return;
    toastification.show(
      context: context,
      title: Text(message),
      type: type,
      style: ToastificationStyle.flatColored,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 2),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.lightBlueAccent.shade100,
      appBar: PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        child: AppBar(
                title: const Text(
                  "Payslips",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              backgroundColor: Colors.transparent, 
                foregroundColor: Colors.black,
                elevation: 0,
              ),
            ),
          ),
      body:Container (
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
    ),
      child:isLoading
      ? _buildShimmerList()
        : payslipList.isEmpty
          ? _buildEmptyState()
            : RefreshIndicator(
              onRefresh: _refreshPage,
              color: Colors.black87,
              backgroundColor: Colors.white,
              child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: payslipList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final payslip = payslipList[index];
                final salaryDate = payslip['salarydate'];
                final payslipId = payslip['id'];

                final formattedMonth =
                    DateFormat('MMMM yyyy').format(DateTime.parse(salaryDate));

                final url = '$baseUrl/api/od-pass/download/$payslipId'; 
                
                final fileName =
                    'Payslip-${DateFormat('MM-yyyy').format(DateTime.parse(salaryDate))}.pdf';

              return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
              clipBehavior: Clip.none,
              children: [
              Card(
                elevation: 4,
                color: Colors.white,
                shadowColor: Colors.grey.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),

                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 32,
                          color: Colors.indigo,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedMonth,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.event, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Salary Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(salaryDate))}",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.payments_rounded, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Paid Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(payslip['paid_date'] ?? salaryDate))}",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 28),
                            tooltip: 'Download Payslip',
                            onPressed: () => downloadAndOpenPdf(context, url, fileName),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 6,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/image/Animation.json', width: 220, repeat: false),
            const SizedBox(height: 16),
            const Text(
              "No payslips available yet.",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              "Swipe down to refresh or check back later.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}