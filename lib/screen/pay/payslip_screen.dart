import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:intl/intl.dart';

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
    fetchPaySlipDate();
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

  void openPdfViewer(int payslipId) {
    final url = '$baseUrl/api/employee/payslip/pdf/$payslipId';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(pdfUrl: url),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (payslipList.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No payslips available.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("My Payslips")),
      body: ListView.builder(
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
    title: Text("🗓 $formattedMonth"),
    subtitle: Text("Salary Date: $salaryDate"),
    trailing: IconButton(
      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
      onPressed: () => openPdfViewer(payslipId),
      tooltip: 'Open Payslip PDF',
    ),
  ),
);

        },
      ),
    );
  }
}

class PdfViewerScreen extends StatelessWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payslip PDF")),
      body: SfPdfViewer.network(pdfUrl),
    );
  }
}
