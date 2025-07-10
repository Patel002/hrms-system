import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';  
import 'package:shimmer/shimmer.dart';
import 'package:toastification/toastification.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
    Future.delayed(Duration.zero,(){
    fetchPaySlipDate();
  });
  }

  Future<void> fetchPaySlipDate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    print("token: $token");

    if (token != null) {
      Map<String, dynamic> payload = Jwt.parseJwt(token);
      setState(() {
        empId = payload['em_id'];
        emUsername = payload['em_username'];
        compId = payload['comp_id']; 
      });
    }

    try{
      setState(() {
        isLoading = true;
      });
      final response = await http.get(Uri.parse('$baseUrl/api/payslip/payslip?emp_id=$empId'));
      final decoded = json.decode(response.body);
      final List<dynamic> data = decoded['data'];


      print("pay slip data: $data");

      data.sort((a, b) => b['salarydate'].compareTo(a['salarydate']));

      setState(() {
        payslipList = data.cast<Map<String, dynamic>>();
        isLoading = false;
      });
    }catch(e){
      print(e); 
      setState(() {
        isLoading = false;
      });
    } finally{
      setState(() {
        isLoading = false;
      });
  }
}

Future <void> _refeshPage() async {
  setState(() {
    isLoading = true;
  });
  await fetchPaySlipDate();
   if (context != null && mounted) {
      toastification.show(
        context: context,
        title: const Text('Payslip Refreshed'),
        type: ToastificationType.success,
        style: ToastificationStyle.flatColored,
        alignment: Alignment.bottomCenter,
        autoCloseDuration: const Duration(seconds: 2),
        icon: const Icon(Icons.check_circle, color: Colors.white),
        showProgressBar: true,
      );
    }
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
    if (Platform.isAndroid) {
     var status = await Permission.manageExternalStorage.request();

      if (status.isDenied || status.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

      if (!status.isGranted) {
        toastification.show(
          context: context,
          title: const Text("Permission Denied"),
          description: const Text("Storage access is required to save the file."),
          type: ToastificationType.error,
        );
        return;
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/$fileName';

    await Dio().download(url, filePath);

    // toastification.show(
    //   context: context,
    //   title: const Text("Download Complete"),
    //   description: Text("File saved to:\n$filePath"),
    //   type: ToastificationType.success,
    //   autoCloseDuration: const Duration(seconds: 3),
    // );

    await OpenFilex.open(filePath);
  } catch (e) {
    toastification.show(
      context: context,
      title: const Text("Download Failed"),
      description: Text(e.toString()),
      type: ToastificationType.error,
    );
  }
}




  @override
  Widget build(BuildContext context) {
   if (isLoading) {
  return Scaffold(
    body: ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Card(
              child: ListTile(
                leading: Container(width: 40, height: 40, color: Colors.white),
                title: Container(height: 16, width: double.infinity, color: Colors.white),
                subtitle: Container(height: 12, width: 100, color: Colors.white),
                trailing: Container(width: 30, height: 30, color: Colors.white),
              ),
            ),
          ),
        );
      },
    ),
  );
}


if (payslipList.isEmpty) {
  return Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/image/Animation.json',
            width: 250,
          ),
          const SizedBox(height: 20),
          const Text(
            "No payslips available.",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

    return Scaffold(
      appBar: AppBar(title: const Text("Payslips")),

      body:RefreshIndicator(
      onRefresh: _refeshPage,
      color: Colors.black87,
      backgroundColor: Colors.white,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: payslipList.length,
        itemBuilder: (context, index) {
          final payslip = payslipList[index];
          final salaryDate = payslip['salarydate'];
          final payslipId = payslip['id'];
          final formattedMonth = DateFormat('MMMM yyyy').format(DateTime.parse(salaryDate));

          return Card(
          margin: const EdgeInsets.all(12),
          child: ListTile(
            leading: const Icon(Icons.calendar_month),
            title: Text("$formattedMonth"),
            subtitle: Text("Salary Date: $salaryDate"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                tooltip: 'Download Payslip',
                onPressed: () {
                  final encodedId = base64Url.encode(utf8.encode(payslipId.toString()));
                  final url = 'https://morth.nic.in/sites/default/files/dd12-13_0.pdf';
                  final fileName = 'Payslip_${DateFormat('MM-yyyy').format(DateTime.parse(salaryDate))}.pdf';

                  downloadAndOpenPdf(context, url, fileName);
                },
               ),
              ]
             ),
            ),
           );
          },
         ),
        ),
       );
      }
     }

// class PdfViewerScreen extends StatelessWidget {
//   final String pdfUrl;

//   const PdfViewerScreen({super.key, required this.pdfUrl});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Payslip PDF")),
//       body: SfPdfViewer.network(pdfUrl),
//     );
//   }
// }
