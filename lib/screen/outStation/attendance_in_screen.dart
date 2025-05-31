import 'package:flutter/material.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';  
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:google_ml_kit/google_ml_kit.dart';

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
  late FaceDetector _faceDetector;
  bool _isBlinking = false;
  bool _isCapturing = false;
  bool _isProcessing = false;
  DateTime? _lastBlinkTime; 

  @override
  void initState() {
    super.initState();
    getEmpCodeFromToken();
    getLocation();
    _initializeCamera();
    _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
    ),
  );
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

// Future<String?> captureImage() async {
//   PermissionStatus status = await Permission.camera.request();
  
//     if (status.isDenied) {
//     throw Exception('Camera permission denied by user');
//   } else if (status.isPermanentlyDenied) {
//     openAppSettings();
//     throw Exception('Camera permission permanently denied. Please enable it from settings.');
//   }

//   final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
//   if (pickedFile == null) return null;

//   final file = File(pickedFile.path);
//   final originalBytes = await file.readAsBytes();

//   img.Image? decodedImage = img.decodeImage(originalBytes);
//   if (decodedImage == null) return null;

//   img.Image resizedImage = img.copyResize(decodedImage, width: 250, height: 250);

//   final resizedBytes = img.encodeJpg(resizedImage); 
//   final encoded = base64Encode(resizedBytes);
//   setState(() {
//     _imageFile = file;
//     base64Image =  'data:image/jpeg;base64,$encoded';
//   });
//   return base64Image;
// } 


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

  _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
  await _cameraController!.initialize();

  _cameraController!.startImageStream((CameraImage image) {
    if (!_isCapturing && !_isProcessing) {
      _processCameraImage(image);
    }
  });
}

 Future<void> _processCameraImage(CameraImage image) async {
  _isProcessing = true;
  
  try {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;

    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) return;

    final face = faces.first; 
    await _checkForBlink(face);
  } catch (e) {
    debugPrint('Face detection error: $e');
  } finally {
    _isProcessing = false;
  }
}

InputImage? _inputImageFromCameraImage(CameraImage image) {
  try {
    if (image.format.group == ImageFormatGroup.yuv420) {
      final plane = image.planes[0];
      final bytes = Uint8List(plane.bytes.length);
      bytes.setRange(0, plane.bytes.length, plane.bytes);
      
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation90deg,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );
    }
    else {
      final plane = image.planes[0];
      final bytes = Uint8List(plane.bytes.length);
      bytes.setRange(0, plane.bytes.length, plane.bytes);
      
      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation90deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );
    }
  } catch (e) {
    debugPrint('Error creating InputImage: $e');
    return null;
  }
}


Future<void> _checkForBlink(Face face) async {
  if (face.leftEyeOpenProbability == null || face.rightEyeOpenProbability == null) return;

  final leftOpen = face.leftEyeOpenProbability!;
  final rightOpen = face.rightEyeOpenProbability!;

  debugPrint('left: $leftOpen, right: $rightOpen');

  if (leftOpen < 1.0 && rightOpen < 1.0) {
    final now = DateTime.now();

    if (!_isBlinking && (_lastBlinkTime == null || now.difference(_lastBlinkTime!) > const Duration(seconds: 2))) {
      _isBlinking = true;
      _lastBlinkTime = now;

      setState(() {
        _isCapturing = true;
      });

      await _captureImage();

      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isCapturing = false;
        _isBlinking = false;
      });
    }
  }
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

    final resized = img.copyResize(decoded, width: 250, height: 250);
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
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.grey.shade100,
    appBar: AppBar(
      title: const Text("Attendance Punch",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      centerTitle: false,
      backgroundColor: Color(0XFF213448),
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
          if (_cameraController != null && _cameraController!.value.isInitialized) ...[
          AspectRatio(
            aspectRatio: _cameraController!.value.aspectRatio,
            child: CameraPreview(_cameraController!),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _isCapturing
                  ? 'Capturing image...'
                  : 'Blink your eyes to capture image',
              style: TextStyle(
                fontSize: 16,
                color: _isCapturing ? Colors.red : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
          ElevatedButton.icon(
            onPressed: _captureImage,
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text("Capture Image"),
            style: primaryButtonStyle,
          ),

          if (_imageFile != null) ...[
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
                  child: Image.file(
                    _imageFile!,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: submitAttendance,
            child: const Text("Submit Attendance"),
            style: greenButtonStyle,
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
      Text(label, style: labelStyle),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          value,
          style: inputTextStyle,
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
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.blue, width: 1.5),
  ),
);

final primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Colors.blue.shade700,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(fontSize: 15),
);

final greenButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Colors.green.shade600,
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(50),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);
