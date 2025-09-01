import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/user_session.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';

class DocumentScreen extends StatefulWidget {
  const DocumentScreen({super.key});

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> {

  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];

  List<Map<String, dynamic>> documents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDocuments();
  }

  Future<void> fetchDocuments() async {
    final token = await UserSession.getToken();

    if(token == null){
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final empId = await UserSession.getUserId();

    try {
    final uri = Uri.parse('$baseUrl/MyApis/getthedocuments');

    print("uri of documents,$uri");

    final response = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiToken',
      'auth_token': token,
      'user_id': empId!
    });

    print('responseBody: ${response.body}');
    
    await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data_packet'] as List;
      setState(() {
          documents =
          data.map((e) => e as Map<String, dynamic>).toList();
          isLoading = false;
        });

    }else {
      debugPrint('Failed to load documents: ${response.body}');
      final errorData = json.decode(response.body);
      String errorMessage = errorData['message'] ?? 'An error occurred';
      _showCustomSnackBar(context, errorMessage, Colors.red, Icons.error);
      setState(() => isLoading = false);
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
          Icon(icon, color: Theme.of(context).iconTheme.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).iconTheme.color, fontSize: 16),
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

Future<void> openFile(String url, String fileName) async {

final dir = await getApplicationDocumentsDirectory();
final filePath = '${dir.path}/$fileName';

await Dio().download(url, filePath);

await OpenFilex.open(filePath);
}
  

Widget _buildDocumentCard(Map<String, dynamic> doc) {
    final fileName = doc['file_title'] ?? "Untitled Document";
    final fileUrl = doc['file_url_formatted'];
    final formattedDate = doc['add_date_formatted'] ?? "-";
    final file = doc['file_url'];

    IconData fileIcon;
    Color iconColor;

  if (file.toLowerCase().endsWith(".pdf")) {
    fileIcon = FontAwesomeIcons.filePdf;
    iconColor = Colors.red;
  } else if (file.toLowerCase().endsWith(".doc") ||
      file.toLowerCase().endsWith(".docx")) {
    fileIcon = FontAwesomeIcons.fileWord;
    iconColor = Colors.blue;
  } else if (file.toLowerCase().endsWith(".xls") ||
      file.toLowerCase().endsWith(".xlsx")) {
    fileIcon = FontAwesomeIcons.fileExcel;
    iconColor = Colors.green;
  } else if (file.toLowerCase().endsWith(".jpg") ||
      file.toLowerCase().endsWith(".jpeg") ||
      file.toLowerCase().endsWith(".png") ||
      file.toLowerCase().endsWith(".bmp")) {
    fileIcon = FontAwesomeIcons.fileImage;
    iconColor = Colors.orange;
  }else if (file.toLowerCase().endsWith(".ppt")){
    fileIcon = Icons.tv_outlined;
    iconColor = Colors.orange.shade800;
  }
   else {
    fileIcon = Icons.insert_drive_file;
    iconColor = Colors.grey;
  }

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
            backgroundColor: iconColor.withOpacity(0.2),
            child: Icon(fileIcon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
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
                  style: const TextStyle(
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
              backgroundColor: iconColor.withOpacity(0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: fileUrl == null
                ? null
                : () {
                    openFile(fileUrl,file);
                  },
              icon:Icon(Icons.open_in_new, size: 18, color: Colors.white),
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
            : documents.isEmpty
                ?Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset('assets/image/Animation.json', width: 220, repeat: true),
                  Text(
                      "No documents found",
                      style: TextStyle(fontSize: 16, color: Theme.of(context).iconTheme.color, fontWeight: FontWeight.w600),
                    ),
                    ],
                  )
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.only(top: 20, bottom: 40),
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      return _buildDocumentCard(documents[index]);
                    },
                  ),
                ),
              );
            }
          }
