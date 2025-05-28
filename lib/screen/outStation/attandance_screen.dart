import 'package:flutter/material.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';  
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
   final baseUrl = dotenv.env['API_BASE_URL'];

  String? narration;
  String? field;
  String? emId,emUsername,compFname,compId;
  Position? currentPosition;
  String? base64Image;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    getEmpCodeFromToken();
    loadPermissions();
  }

  Future<void> getEmpCodeFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token != null) {
      Map<String, dynamic> payload = Jwt.parseJwt(token);
      setState(() {
        compFname = payload['comp_fname'];
        emId = payload['em_id'];
        emUsername = payload['em_username'];
        compId = payload['comp_id']; 
      });
    }
  }

  Future<void> getLocation() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) {
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
    }
      else if (status.isDenied) {
        throw Exception('Location permission denied by user');
      }
      else if (status.isPermanentlyDenied) {
         openAppSettings();
          throw Exception('Location permission permanently denied. Please enable it from settings.');
      }else {
      throw Exception('Location permission not granted');
    }
      print('Latitude: ${currentPosition?.latitude}, Longitude: ${currentPosition?.longitude}, Accuracy: ${currentPosition?.accuracy}');
     }

Future<String?> captureImage() async {
  PermissionStatus status = await Permission.camera.request();
  
    if (status.isDenied) {
    throw Exception('Camera permission denied by user');
  } else if (status.isPermanentlyDenied) {
    openAppSettings();
    throw Exception('Camera permission permanently denied. Please enable it from settings.');
  }

  final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
  if (pickedFile == null) return null;

  final file = File(pickedFile.path);
  final originalBytes = await file.readAsBytes();

  img.Image? decodedImage = img.decodeImage(originalBytes);
  if (decodedImage == null) return null;

  img.Image resizedImage = img.copyResize(decodedImage, width: 250, height: 250);

  final resizedBytes = img.encodeJpg(resizedImage); 
  final encoded = base64Encode(resizedBytes);
  setState(() {
    _imageFile = file;
    base64Image =  'data:image/jpeg;base64,$encoded';
  });
  return base64Image;
} 

 Future<void> submitAttendance() async {
  if (narration == null && field == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill all fields')),
    );
    return;
  }

  try {
      if (base64Image == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please capture an image')),
    );
    return;
  }

  if (currentPosition == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fetch location')),
    );
    return;
  }
    final response = await http.post(
      Uri.parse('$baseUrl/api/attendance/punch'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'emp_id': emId,
        'comp_id': compId,
        'punch_remark': narration,
        'punch_place': field,
        'latitude': currentPosition?.latitude,
        'longitude': currentPosition?.longitude,
        'punch_img': base64Image,
        'created_by': emUsername,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance submitted successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${response.body}')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

Future<void> loadPermissions() async {
  await getLocation();
  await captureImage();
}

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance Punch")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildReadOnlyField("Employee Id", emId ?? "N/A"),
            buildReadOnlyField("Employee Name", emUsername ?? "N/A"),
            buildReadOnlyField("Company Name", compFname ?? "N/A"),
            DropdownButtonFormField<String>(
              value: field,
              hint: const Text("Select Punch Place*"),
              items: ['OFFICE', 'FIELD'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => field = val);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                labelText: "Narration*",
              ),
              onChanged: (val) => narration = val,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: captureImage,
              icon: const Icon(Icons.camera_alt),
              label: const Text("Capture Image"),
            ),
            if (_imageFile != null)
              Image.file(_imageFile!, height: 100, width: 100),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: submitAttendance,
                child: const Text("Submit Attendance"),
              ),
          ],
        ),
      ),
    );
  }
}

          Widget buildReadOnlyField(String label, String value) {
          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
          label,
          style: TextStyle(
          fontSize: 14,
          color: const Color(0xFF6C757D),
          fontWeight: FontWeight.w500,
        ),
      ),
          const SizedBox(height: 8),
          Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
          children: [
          Expanded(
          child: Text(
          value,
          style: TextStyle(
          fontSize: 15,
          color:  const Color(0xFF212529),
          ),
        ),
        ),
      ],
      ),
    ),
  ],
  );
  }