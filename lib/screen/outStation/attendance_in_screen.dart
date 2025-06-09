import 'package:flutter/material.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';  
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
// import 'dart:typed_data';
// import 'package:image_picker/image_picker.dart';
// import 'package:flutter/services.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';


class AttendanceScreenIN extends StatefulWidget {
  const AttendanceScreenIN({super.key});

  @override
  State<AttendanceScreenIN> createState() => _AttendanceScreenINState();
}

class _AttendanceScreenINState extends State<AttendanceScreenIN> {
   final baseUrl = dotenv.env['API_BASE_URL'];

  String? narration;
  String? field;
  String? emId,emUsername,compFname,compId;
  Position? currentPosition;
  String? base64Image;
  File? _imageFile;
  CameraController? _cameraController;
  // late FaceDetector _faceDetector;
  // bool _isBlinking = false;
  bool _isCapturing = false;
  bool _isProcessing = false;
  // DateTime? _lastSmileTime;
  // bool _eyesClosed = false;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    getEmpCodeFromToken();
    getLocation();
  
  //   _faceDetector = FaceDetector(
  //   options: FaceDetectorOptions(
  //     performanceMode: FaceDetectorMode.fast,
  //     enableContours: false,
  //     enableLandmarks: false,
  //     enableClassification: true,
  //     enableTracking: true,
  //   ),
  // );
  
    _initializeControllerFuture = _initializeCamera();

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


Future<void> _initializeCamera() async {
  final status = await Permission.camera.request();
  if (status.isDenied) {
    throw Exception('Camera permission denied.');
  } else if (status.isPermanentlyDenied) {
    openAppSettings();
    return;
  }

  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
    (cam) => cam.lensDirection == CameraLensDirection.front,
  );

  _cameraController = CameraController(
    frontCamera,
    ResolutionPreset.high,
    imageFormatGroup: ImageFormatGroup.yuv420,
    enableAudio: false,
  );

  await _cameraController!.initialize();

  await _cameraController!.startImageStream((CameraImage image) {
    if (!_isCapturing && !_isProcessing) {
      // _processCameraImage(image);
    }
  });
} 
Future<void> _captureImage() async {
  try {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final file = await _cameraController!.takePicture();
    final originalBytes = await File(file.path).readAsBytes();

    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) return;

    final flipped = img.flipHorizontal(decoded);

    final resized = img.copyResize(flipped, width: 250, height: 250);
    final resizedBytes = img.encodeJpg(resized);
    final base64Str = base64Encode(resizedBytes);

    if (!mounted) return;

    setState(() {
      _imageFile = File(file.path);
      base64Image = 'data:image/jpeg;base64,$base64Str';
    });
    
  } catch (e) {
    debugPrint('Error capturing image: $e');
  }
}


 Future<void> submitAttendance() async {
  if (narration == null && field == null) {
    _showCustomSnackBar(context, "Please fill all fields", Colors.yellow.shade900, Icons.warning_amber_outlined);
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
        'punchtype': 'OUTSTATION1',
        'latitude': currentPosition?.latitude,
        'longitude': currentPosition?.longitude,
        'punch_img': base64Image,
        'created_by': emUsername,
      }),
    );

    if (response.statusCode == 201) {
      _showCustomSnackBar(context, 'Attendance marked successfully', Colors.green, Icons.check_circle);
    } else {
      final error = jsonDecode(response.body);
      _showCustomSnackBar(context, "${error['message']}", Colors.red, Icons.error);
    }
  } catch (e) {
     _showCustomSnackBar(context, 'Unexpected error format', Colors.red, Icons.error);
  }
}

 void _showCustomSnackBar(BuildContext context, String message, Color color, IconData icon) {
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


@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
   appBar: PreferredSize(
  preferredSize: const Size.fromHeight(kToolbarHeight),
  child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: AppBar(
                title: const Text(
                  "Attendance In",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              backgroundColor: Colors.transparent, 
                foregroundColor: Colors.black,
                elevation: 0,
              ),
            ),
          ),
    body: SingleChildScrollView(
      // physics: const BouncingScrollPhysics(),
       child: Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
    ),
      // padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildReadOnlyField("Employee ID", emId ?? "N/A"),
          const SizedBox(height: 16),
          buildReadOnlyField("Employee Name", emUsername ?? "N/A"),
          const SizedBox(height: 16),
          buildReadOnlyField("Company Name", compFname ?? "N/A"),
          const SizedBox(height: 24),

          Text("Punch Place*", style: labelStyle),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: field,
            decoration: inputDecoration,
            dropdownColor: Colors.white,
            items: ['OFFICE', 'FIELD'].map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: inputTextStyle),
              );
            }).toList(),
            onChanged: (val) => setState(() => field = val),
          ),

          const SizedBox(height: 24),
          Text("Narration*", style: labelStyle),
          const SizedBox(height: 8),
          TextField(
            maxLines: 3,
            style: inputTextStyle,
            decoration: inputDecoration.copyWith(
              hintText: "Remark",
            ),
            onChanged: (val) => narration = val,
          ),

          const SizedBox(height: 24),
          FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (_cameraController != null && _cameraController!.value.isInitialized) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _cameraController!.value.aspectRatio,
                        child: Transform(
                          alignment: Alignment.center,
                           transform: Matrix4.rotationY(
                      _cameraController!.description.lensDirection == CameraLensDirection.front ? math.pi : 0,
                    ),
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                      // Positioned(
                      //   top: 0,
                      //   bottom: 0,
                      //   left: 0,
                      //   right: 0,
                      //   child: IgnorePointer(
                      //     child: Center(
                      //       child: Container(
                      //         width: 200,
                      //         height: 200,
                      //         decoration: BoxDecoration(
                      //           shape: BoxShape.circle,
                      //           border: Border.all(
                      //             color: Colors.white.withOpacity(0.8),
                      //             width: 3,
                      //           ),
                      //           color: Colors.transparent,
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // // Optional instruction text
                      // Positioned(
                      //   bottom: 16,
                      //   child: Text(
                      //     "Align your face inside the circle",
                      //     style: TextStyle(
                      //       color: Colors.white,
                      //       fontSize: 16,
                      //       shadows: [
                      //         Shadow(
                      //           blurRadius: 8,
                      //           color: Colors.black.withOpacity(0.7),
                      //           offset: Offset(1, 1),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                );
              } else {
                return const Center(
                  child: Text(
                    'Camera not available',
                    style: TextStyle(fontSize: 16, color: Colors.redAccent),
                  ),
                );
              }
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Camera error: ${snapshot.error}',
                  style: const TextStyle(fontSize: 16, color: Colors.red),
                ),
              );
            } else {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          },
        ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              _isCapturing
                  ? 'Capturing image...'
                  : 'Press button to capture image',
              style: TextStyle(
                fontSize: 16,
                color: _isCapturing ? Colors.red : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _captureImage,
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text("Capture Image"),
            style: primaryButtonStyle,
          ),

          if (_imageFile != null) 
            ...[
              const SizedBox(height: 20),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child:Transform(
                    alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                    child: Image.file(
                      _imageFile!,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                    ),
                  ),
                ),
              ),
            ],

          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: submitAttendance,
            label: const Text("Submit Attendance"),
            style: greenButtonStyle,
            icon: const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(5),
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

final labelStyle = TextStyle(
  fontSize: 14,
  color: Colors.grey.shade500,
  fontWeight: FontWeight.w600,
);

final inputTextStyle = const TextStyle(
  fontSize: 15,
  color: Color(0xFF212529),
);

final inputDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: const BorderSide(color: Color.fromARGB(255, 33, 108, 214), width: 1.5),
  ),
);

final primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Colors.blue.shade700,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  ),
  textStyle: const TextStyle(fontSize: 15),
);

final greenButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Color(0XFF123458),
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(30),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  ),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);
