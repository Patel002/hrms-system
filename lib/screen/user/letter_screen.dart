import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/user_session.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class LetterScreen extends StatefulWidget {
  
  const LetterScreen({super.key});

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {

  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  List<Map<String, dynamic>> letters = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchLetters();
  }

 Future<void> fetchLetters() async{
  
  final token = await UserSession.getToken();

    if(token == null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

  final empId = await UserSession.getUserId();

  try {

    final uri = Uri.parse('$baseUrl/MyApis/gettheletters');

    print("uri of letters,$uri");

    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiToken',
      'auth_token': token,
      'user_id': empId!
    });

    if(response.statusCode == 200){
      final data = json.decode(response.body)['data_packet'] as List;
      setState(() {
          letters =
          data.map((e) => e as Map<String, dynamic>).toList();
          isLoading = false;
        });
    }    
  } catch (e) {
    _showCustomSnackBar(context, e.toString(), Colors.red, Icons.error);
       setState(() => isLoading = false);
  }
 }

 void _showCustomSnackBar(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.clearSnackBars();

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

  Widget _buildShimmerTile() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

Future<void> openFile(BuildContext context,String url, String fileName) async {

final dir = await getApplicationDocumentsDirectory();
final filePath = '${dir.path}/$fileName';

final file = File(filePath);

  if (!await file.exists()) {
  await Dio().download(url, filePath);
  }

  await OpenFilex.open(filePath);

}

Widget _buildDocumentCard(Map<String, dynamic> letter) {
    final letterType = letter['letter_type'] ?? "Untitled Letters";
    final fileUrl = letter['letter_url'];
    final formattedDate = letter['letter_date_formatted'] ?? "-";
    final fileName ='${(letterType).toLowerCase()}_${DateFormat('MM_yyyy').format(DateTime.now())}.pdf';

      return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.85),
            Colors.white.withOpacity(0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.red.withOpacity(0.2),
            child: Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  letterType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  "Uploaded on: $formattedDate",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => openFile(context, fileUrl, fileName),
              icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
              label: const Text("Open", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: isLoading
            ? ListView.builder(
                padding: const EdgeInsets.only(top: 20),
                itemCount: 3,
                itemBuilder: (context, index) => _buildShimmerTile(),
              )
            : letters.isEmpty
                ? Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Lottie.asset('assets/image/Animation.json', width: 220, repeat: false),
                    Text(
                      "No documents found",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              )
                : ListView.builder(
                    padding:
                        const EdgeInsets.only(top: 20, bottom: 40),
                    itemCount: letters.length,
                    itemBuilder: (context, index) {
                      return _buildDocumentCard(letters[index]);
                    },
                  ),
                ),
              );
            }
          }
