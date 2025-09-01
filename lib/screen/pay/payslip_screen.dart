import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';  
import 'package:shimmer/shimmer.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  String? empId, emUsername, compId;
  String? selectedYearValue;
  List<Map<String, dynamic>> payslipList = [];
  List<dynamic> yearList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero,() async{
    await fetchPaySlipDate();
  });
  }

  Future<void> fetchPaySlipDate({String? finYear}) async {
    final token = await UserSession.getToken();

    if(token == null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final empId = await UserSession.getUserId();

    try{
      setState(() {
        isLoading = true;
      });

      final uri = Uri.parse(
      finYear != null
        ? '$baseUrl/MyApis/payslipthelist?finyear=$finYear'
        : '$baseUrl/MyApis/payslipthelist',
    );

    print('API URI: $uri');

      final response = await http.get(uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': token,
          'user_id': empId!
        });

         await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
        );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final List<dynamic> data = decoded['data_packet'];
        final List<dynamic> years = decoded['year_list'];
        final String? selectedYear = decoded['selected_year']?.toString();


        print('Payslip List: $data');

        data.sort((a, b) => b['salarydate'].compareTo(a['salarydate']));

        setState(() {
          payslipList = data.cast<Map<String, dynamic>>();
          yearList = years;
          selectedYearValue = selectedYear;
        });

        print('Payslip List: $payslipList');
      } else {
        showCustomSnackBar(context, 'Failed to load payslips', Colors.red, Icons.error);
      }
    }catch(e){
      print(e); 
      showCustomSnackBar(context, '$e', Colors.red, Icons.error);
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
  showCustomSnackBar(context, 'Payslip List Refreshed', Colors.teal.shade400, Icons.refresh);

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
    showCustomSnackBar(context, 'Failed to download PDF', Colors.red, Icons.error);

  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
      appBar:AppBar(
                title: const Text(
                  "Payslips",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              backgroundColor: Colors.transparent, 
              foregroundColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87,
                elevation: 0,
              ),
      body:Container (
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
      child:isLoading
      ? _buildShimmerList()
            : RefreshIndicator(
              onRefresh: _refreshPage,
              color: Colors.black87,
              backgroundColor: Colors.white,
              child: Column(
              children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedYearValue,
                        borderRadius: BorderRadius.circular(10),
                        dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                        hint: const Text("Select Financial Year"),
                        icon: const Icon(Icons.arrow_drop_down),
                        style: TextStyle(    
                          fontSize: 16,
                          color: Theme.of(context).iconTheme.color,
                        ),
                        items: yearList.map<DropdownMenuItem<String>>((year) {
                          return DropdownMenuItem<String>(
                            value: year['year_value'].toString(),
                            child: Text(year['year_name']),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedYearValue = newValue;
                          });
                          fetchPaySlipDate(finYear: newValue);
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Expanded(
              child: payslipList.isEmpty
             ? _buildEmptyState() 
              : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: payslipList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final payslip = payslipList[index];
                final salaryDate = payslip['salarydate'];
                // final payslipId = payslip['id'];

                final formattedMonth =
                    DateFormat('MMMM yyyy').format(DateTime.parse(salaryDate));

                final url = payslip['payslip_url']; 
                
                final fileName =
                    'Payslip_${DateFormat('MM_yyyy').format(DateTime.parse(salaryDate))}.pdf';

              return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Stack(
              clipBehavior: Clip.none,
              children: [
              Card(
                elevation: 4,
                color: Theme.of(context).scaffoldBackgroundColor,
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
                                  // color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Row(
                              //   children: [
                              //     const Icon(Icons.event, size: 16, color: Colors.grey),
                              //     const SizedBox(width: 6),
                              //     Text(
                              //       "Salary Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(salaryDate))}",
                              //       style: TextStyle(
                              //         color: Colors.grey[700],
                              //         fontSize: 14,
                              //       ),
                              //     ),
                              //   ],
                              // ),
                              //   const SizedBox(height: 4),
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

                              const SizedBox(height: 4),
                                Row(
                                children: [
                                  const Icon(FontAwesomeIcons.calendar, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Days: ${payslip['total_days'] ?? '0'}",
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
                                    const Icon(Icons.account_balance, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Earning: ${payslip['earnings'] ?? '0.00'}",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.difference_rounded, size: 16,  color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Deduction: ${payslip['deductions'] ?? '0.00'}",
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
                                    const Icon(Icons.paid, size: 16, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Net Pay: ${payslip['net_pay'] ?? '0.00'}",
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
              ],
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