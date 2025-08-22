import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import '../utils/user_session.dart';
import '../utils/network_failure.dart';

class AttendanceScreenIN extends StatefulWidget {
  const AttendanceScreenIN({super.key});

  @override
  State<AttendanceScreenIN> createState() => _AttendanceScreenINState();
}

class _AttendanceScreenINState extends State<AttendanceScreenIN> {
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _narrationController = TextEditingController();

  String? narration,loadingText;
  String? field;
  String? _token;
  String? _emId,_error;
  String? _emUsername;
  String? _compFname;
  Position? currentPosition;
  String? base64Image;
  File? _imageFile;
  CameraController? _cameraController;
  late Future<void> _initializeControllerFuture = Future.value();
  bool isCameraAvailable = false; 
  final bool _isCapturing = false;
  bool isLoading = false;
  bool isSubmitting = false;
  bool isDataLoading = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
    await initializePage();
   });

_connectivitySubscription = Connectivity()
    .onConnectivityChanged
    .listen((List<ConnectivityResult> results) {
  if (results.contains(ConnectivityResult.none)) {
    if (mounted) {
      setState(() {
        _error = 'No internet connection.';
      });
    }
  } else {
    if (mounted && _error != null) {
      setState(() {
        _error = null;
      });
      fetchDataPacketApi();
    }
  }
});

final initialStatus = Connectivity().checkConnectivity();
initialStatus.then((status) {
  if (status == ConnectivityResult.none) {
    setState(() {
      _error = 'No internet connection.';
    });
  } else {
    fetchDataPacketApi();
  }
});
}
  

  Future<void> initializePage() async {
  try {
    await getEmpCodeFromToken();

    final locationGranted = await requestLocationPermission();
    final cameraGranted = await requestCameraPermission();

    if (!locationGranted || !cameraGranted) {
      _initializeControllerFuture = Future.value();
      return;
    }

    setState(() {
    isLoading = true;
    });

    // await Future.delayed(Duration(milliseconds: 100));
    // if (mounted) {
    //   setState(() {
    //     isLoading = true;
    //   });
    // }

    _initializeControllerFuture = _initializeCamera();

    await getLocation();
   
      setState(() {
        isLoading = false;
      });

  } catch (e) {
    debugPrint('Initialization error: $e');
   _showCustomSnackBar(context, 'Error: $e', Colors.red, Icons.error);
    _initializeControllerFuture = Future.value();
    setState(() {
      isLoading = false;
    });
  }
}


  Future<void> getEmpCodeFromToken() async {
    
   _token = await UserSession.getToken();

    if (_token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
      _emId = await UserSession.getUserId();
      _emUsername = await UserSession.getUserName();
      await fetchDataPacketApi();

      if(mounted){
        setState(() {
          isDataLoading = true;
        });
      }
  }

  Future<bool> requestLocationPermission() async {
  final status = await Permission.location.request();

  if (status.isGranted) {
    return true;
  } else if (status.isPermanentlyDenied) {
    await openAppSettings();
    return false;
  } else {
    _showCustomSnackBar(context, 'Location permission is required.', Colors.teal.shade400, Icons.location_on_outlined);
    return false;
  }
}


Future<bool> requestCameraPermission() async {
  final status = await Permission.camera.request();

  if (status.isGranted) {
    return true;
  } else if (status.isPermanentlyDenied) {
    await openAppSettings();
    return false;
  } else {
    _showCustomSnackBar(context, 'Camera permission is required.', Colors.lightBlue.shade200, Icons.camera_alt_outlined);
    return false;
  }
}

Future<void> getLocation() async {
  bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();

  if (!isLocationEnabled) {
    await Geolocator.openLocationSettings();
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      _showCustomSnackBar(context, 'Location permission is Denied.', Colors.yellow.shade900, Icons.location_on_outlined);
    }
  }

  currentPosition = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  print('Latitude: ${currentPosition?.latitude}, Longitude: ${currentPosition?.longitude}, Accuracy: ${currentPosition?.accuracy}');
} 


Future<void> _initializeCamera() async {
  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
    (cam) => cam.lensDirection == CameraLensDirection.front,
  );

  _cameraController = CameraController(
    frontCamera,
    ResolutionPreset.medium,
    enableAudio: false,
  );

  await _cameraController!.initialize();
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

    final resized = img.copyResize(flipped, width: 400, height: 400);
    final resizedBytes = img.encodePng(resized);
    final base64Str = base64Encode(resizedBytes);

    if (!mounted) return;

    setState(() {
      _imageFile = File(file.path);
      base64Image = 'data:image/png;base64,$base64Str';
    });
    
  } catch (e) {
    debugPrint('Error capturing image: $e');
  }
}

  Future<void> fetchDataPacketApi() async {

    try {
      final response = await http.get(Uri.parse('$baseUrl/MyApis/userinfo?user_id=$_emId'),
      headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': _token!,
        },
      );

      await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data_packet'];

        if(mounted){ 
        setState(() {
          _compFname = data['comp_fname'];
        });
        }
      }

    } catch (e) {
  if (e is SocketException) {
    setState(() {
      _error = 'No internet connection.';
    });
  } else {
    setState(() {
      _error = 'Error fetching user info: $e';
    });
  }
}
  }

  Future<void> submitAttendance() async {
  if (isSubmitting) return;

  if (!_formKey.currentState!.validate() || field == null) {
    if (mounted) {
      _showCustomSnackBar(
        context,
        "Please fill all fields",
        Colors.yellow.shade900,
        Icons.warning_amber_outlined,
      );
      setState(() => isSubmitting = false);
    }
    return;
  }

  if (field == 'FIELD' && (narration?.trim().isEmpty ?? true)) {
    if (mounted) {
      _showCustomSnackBar(
        context,
        'Please enter a remark for Field work',
        Colors.orange,
        Icons.edit_note,
      );
      setState(() => isSubmitting = false);
    }
    return;
  }

  if (base64Image == null) {
    if (mounted) {
      _showCustomSnackBar(
        context,
        'Please capture an image',
        Colors.teal.shade400,
        Icons.camera_alt_outlined,
      );
      setState(() => isSubmitting = false);
    }
    return;
  }

 
  if (mounted) {
    setState(() {
      isSubmitting = true;
      loadingText = 'Submitting, please wait...';
    });
  }

  try {
    if (currentPosition == null) {
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    }

    _formKey.currentState!.save();

    if (field == 'OFFICE') narration = '';

    final body = {
      'punch_remark': narration,
      'punch_place': field,
      'punch_type': 'IN',
      'latitude': currentPosition?.latitude,
      'longitude': currentPosition?.longitude,
      'punch_img': base64Image,
    };

    final uri = Uri.parse('$baseUrl/MyApis/punchthein');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiToken',
        'auth_token': _token!,
        'user_id': _emId!,
      },
      body: jsonEncode(body),
    );

    final resBody = jsonDecode(response.body);

    await UserSession.checkInvalidAuthToken(context, resBody, response.statusCode);

    if (response.statusCode == 200) {
      if (mounted) {
        _showCustomSnackBar(
          context,
          'Punch In marked successfully',
          Colors.green,
          Icons.check_circle,
        );
        await _resetForm();
      }
    } else {
      if (mounted) {
        _showCustomSnackBar(
          context,
          resBody['message'] ?? 'Something went wrong',
          Colors.red,
          Icons.error,
        );
      }
    }
  } catch (e) {
    if (mounted) {
      _showCustomSnackBar(
        context,
        'An unexpected error occurred: $e',
        Colors.red,
        Icons.error,
      );
    }
  } finally {
    if (mounted) {
      setState(() => isSubmitting = false);
    }
  }
}


  Future<void> handlePullToRefresh() async {
    setState(() {
      isLoading = true;
      _error = null;
    });

    await _resetForm();

    setState(() {
      isLoading = false;
    });
  } 

    Future<void> _resetForm() async{
      _formKey.currentState?.reset();
      _narrationController.clear();
      setState(() {
      narration = null;
      field = null;
      base64Image = null;
      _imageFile = null;
      currentPosition = null;
      });
    }

    @override
    void dispose() {
    // _connectionSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
    }


 void _showCustomSnackBar(BuildContext context, String message, Color color, IconData icon) {
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

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Color(0xFFF2F5F8),
   appBar:AppBar(
    backgroundColor: Colors.transparent, 
      title: const Text(
        "Check-In",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      forceMaterialTransparency: true,
    ),

    body:_error != null
     ? NoInternetWidget(
      onRetry: () async{
        setState(() { 
          _error = null;
        });
        await fetchDataPacketApi();
      },
    ) : isDataLoading
    ? Stack(
    children: [
    Container (
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF5F7FA), Color(0xFFE4EBF5)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ),
    ),

      child:Form(
        key: _formKey,
        child: RefreshIndicator(
          onRefresh: handlePullToRefresh,
          color: Colors.black,
          backgroundColor: Colors.white ,
          child: ListView(
            children: [
            Padding(
            padding: const EdgeInsets.all(16.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildReadOnlyField("Employee ID", _emId ?? "N/A"),
          const SizedBox(height: 16),
          buildReadOnlyField("Employee Name", _emUsername ?? "N/A"),
          const SizedBox(height: 16),
          buildReadOnlyField("Company Name", _compFname ?? "N/A"),
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
            validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a punch place';
            }
            return null;
          },
        ),

          const SizedBox(height: 24),
        
          if(field == 'FIELD') ...[
          Text("Narration*", style: labelStyle),

          const SizedBox(height: 8),

          TextFormField(
            controller: _narrationController,
            maxLines: 2,
            style: inputTextStyle,
            decoration: inputDecoration.copyWith(
              hintText: "Remark",
            ),
            validator: (value) {
            if (field == 'FIELD' && (value == null || value.trim().isEmpty)) 
            {
              return 'Please enter a remark';
            }
            return null;
          },
            onChanged: (val) {
            setState(() {
              narration = val;
            });
          },
        ),
        ],

         const SizedBox(height: 24),

        if (_imageFile == null) ...[
          FutureBuilder(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.connectionState == ConnectionState.done) {
                if (_cameraController != null && _cameraController!.value.isInitialized) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.black,
                      child: AspectRatio(
                        aspectRatio: _cameraController!.value.aspectRatio,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  );
                } else {
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('Camera will be initialized  please wait', style: TextStyle(color: Colors.black54)),
                    ),
                  );
                }
              } else if (snapshot.hasError) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('Camera error', style: TextStyle(color: Colors.red)),
                  ),
                );
              } else {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              _isCapturing
                  ? 'Capturing image...'
                  : (_imageFile != null
                      ? 'Image captured'
                      : 'Press button to capture image'),
              style: TextStyle(
                fontSize: 16,
                color: _isCapturing ? Colors.red : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

          if (_imageFile != null) 
            ...[
              // const SizedBox(height: 20),
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
            

         const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              if (_imageFile != null) {
                setState(() => _imageFile = null);
              } else {
                await _captureImage();
              }
            },
            icon: Icon(
              _imageFile != null ? Icons.refresh : Icons.camera_alt,
              size: 20,
            ),
            label: Text(
              _imageFile != null ? "Retake" : "Capture Image",
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _imageFile != null
                  ? Colors.redAccent.shade200
                  : const Color.fromARGB(255, 80, 140, 184), 
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(fontSize: 15),
            ),
          ),

              const SizedBox(height: 32),
                
                ElevatedButton.icon(
                  onPressed: isSubmitting? null : () async {
                    await submitAttendance();
                  },
                  label: const Text("Submit"),
                  style: greenButtonStyle,
                  icon: const Icon(Icons.send_outlined, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
),
    if (isSubmitting)
        Container(
          color: Colors.black.withOpacity(0.5), 
          child: Center(
            child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                loadingText ?? 'Submitting, please wait...',
                style: TextStyle(color: Colors.white, fontSize: 16,),
                textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ): const Center(
          child: CircularProgressIndicator(
            color: Colors.black87,
          ),
      )
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
    borderSide: const BorderSide(color: Colors.blueGrey, width: 1.5),
  ),
);

final primaryButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Colors.blue.shade50,
  foregroundColor: Colors.blue.shade300,
  minimumSize: const Size.fromHeight(48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  ),
  textStyle: const TextStyle(fontSize: 15),
);

final greenButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: Color.fromARGB(255, 245, 247, 250),
  foregroundColor: Colors.black87,
  minimumSize: const Size.fromHeight(48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
  ),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);
