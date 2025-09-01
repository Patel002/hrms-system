import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import '../utils/user_session.dart';
import '../helper/top_snackbar.dart';

class VisitEntryScreen extends StatefulWidget {
  const VisitEntryScreen({super.key});

  @override
  State<VisitEntryScreen> createState() => _VisitEntryScreenState();
}

class _VisitEntryScreenState extends State<VisitEntryScreen> {
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _narrationController = TextEditingController();

  String? narration;
  String? travellingMode;
  String? _token;
  String? _emId;
  String? _emUsername;
  // String? _compFname;
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
  bool showDropdown = false;
  bool blockScreen = false;

  String accommodationRequired = 'N';

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  String? is_day_end,travel_mode;

  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;
  DateTime? _nextDayMidnight;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
    await initializePage();
   });
  }

  Future<void> initializePage() async {
  try {
    await getEmpCodeFromToken();
    await fetchDataPacketApi();

    final locationGranted = await requestLocationPermission();
    final cameraGranted = await requestCameraPermission();

    if (!locationGranted || !cameraGranted) {
      _initializeControllerFuture = Future.value();
      return;
    }

    setState(() => isLoading = true);

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
   showCustomSnackBar(context, 'Error: $e', Colors.red, Icons.error);
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
    
      // await fetchDataPacketApi();

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
    showCustomSnackBar(context, 'Location permission is required.', Colors.teal.shade400, Icons.location_on_outlined);
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
    showCustomSnackBar(context, 'Camera permission is required.', Colors.lightBlue.shade200, Icons.camera_alt_outlined);
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
      showCustomSnackBar(context, 'Location permission is Denied.', Colors.yellow.shade900, Icons.location_on_outlined);
    }
  }

  currentPosition = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  print('Latitude: ${currentPosition?.latitude}, Longitude: ${currentPosition?.longitude}, Accuracy: ${currentPosition?.accuracy}');
} 

Future<void> _initializeCamera([int cameraIndex = 0]) async {
  try {
    _cameras = await availableCameras();
    _selectedCameraIndex = cameraIndex;

    _cameraController?.dispose(); 

    _cameraController = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() {});
  } catch (e) {
    debugPrint('Error initializing camera: $e');
  }
}


Future<void> _flipCamera() async {
  if (_cameras.length < 2) return;

  final newIndex = (_selectedCameraIndex + 1) % _cameras.length;
  await _initializeCamera(newIndex);
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

    // final flipped = img.flipHorizontal(decoded);

    final resized = img.copyResize(decoded, width: 400, height: 400);
    final resizedBytes = img.encodePng(resized);
    final base64Str = base64Encode(resizedBytes);

    if (!mounted) return;

    setState(() {
      _imageFile = File(file.path);
      base64Image = 'data:image/png;base64,$base64Str';

      // print('Base64 Image: $base64Image');
    });
    
  } catch (e) {
    debugPrint('Error capturing image: $e');
  }
}


void startCountdownToMidnight() {
  _countdownTimer?.cancel();

final now = DateTime.now();
  _nextDayMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);

  _countdownTimer = Timer.periodic(Duration(seconds: 1), (_) {
    final remaining = _nextDayMidnight!.difference(DateTime.now());

    if (remaining.isNegative) {
      setState(() {
        is_day_end = 'N';
        blockScreen = false;
      });
      _countdownTimer?.cancel();
    } else {
      setState(() {
        _timeRemaining = remaining;
      });
    }
  });
}

  Future<void> fetchDataPacketApi() async {
    try {

      final uri = Uri.parse('$baseUrl/MyApis/visitthepage');

      print('API URI: $uri');

      final response = await http.get(uri,
      headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': _token!,
          'user_id': _emId!
        },
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body from visitthepage: ${response.body}');

      await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data_packet'];

        if(data is Map<String, dynamic>){
          final travelModeValue = data['travel_mode']?.toString();
          final dayEndValue = data['is_day_end']?.toString() ?? 'N'; 

        if(mounted){ 
        setState(() {
          travel_mode = travelModeValue;
          travellingMode = travel_mode;
          is_day_end = dayEndValue;

          print('is_day_end: $is_day_end');

          if(is_day_end == 'Y'){
            blockScreen = true;
            startCountdownToMidnight();
          }else{
            blockScreen = false;
          }

          if(is_day_end == 'N'){
            showDropdown = true;
          }
        });
        }
      }
    }

    } catch (e) {
      showCustomSnackBar(context, 'Error while fetching data packet: $e', Colors.red, Icons.error);
    }
  }

  Future<void> submitAttendance() async {
    if (isSubmitting) return;

  //   setState(() {
  //   isSubmitting = true;
  // });

    if (!_formKey.currentState!.validate() || narration == null || travellingMode == null) {
      showCustomSnackBar(context, "Please fill all fields", Colors.yellow.shade900, Icons.warning_amber_outlined);
      setState(() {
        isSubmitting = false;
      });
      return;
    }
      
    _formKey.currentState!.save();

   
    if (base64Image == null) {
    showCustomSnackBar(context, 'Please capture an image', Colors.teal.shade400, Icons.camera);
     setState(() {
          isSubmitting = false;
      });
     return;
   }

    if (currentPosition == null) {
      try{
      await getLocation();
      }catch(e){
      showCustomSnackBar(context, 'Please give access of location', const Color.fromARGB(255, 138, 166, 38), Icons.location_disabled);
        setState(() {
          isSubmitting = false;
        });
      return;
      }
    }

    setState(() => isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/MyApis/visittheentry'),
         headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': _token!,
          'user_id': _emId!,
        },
        body: jsonEncode({
          'comments': narration,
          'travel_mode': travellingMode,
          'is_day_end': accommodationRequired,
          'latitude': currentPosition?.latitude,
          'longitude': currentPosition?.longitude,
          'visit_img': base64Image,
        }),
      );

      // print("Response status: ${response.statusCode}");
      // print("Response body: ${response.body}");

      await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      if (response.statusCode == 200) {
        showCustomSnackBar(context, 'Visit entry is marked successfully', Colors.green, Icons.check_circle);

       await _resetForm();
       Navigator.pop(context,true);
       await handlePullToRefresh();

      } else {
        final error = jsonDecode(response.body);
        showCustomSnackBar(context, "${error['message']}", Colors.red, Icons.error);
      }
    } catch (e) {
      showCustomSnackBar(context, 'Unexpected error format,$e', Colors.red, Icons.error);
      print(e);
    } finally {
      setState(() {
        isSubmitting = false;
      });
    }
  }
  Future<void> handlePullToRefresh() async {
    setState(() {
      isLoading = true;
    });

    await _resetForm();
    await fetchDataPacketApi();

    setState(() {
      isLoading = false;
    });
  } 

    Future<void> _resetForm() async {
      _formKey.currentState?.reset();
      _narrationController.clear();
      setState(() {
      narration = null;
      travellingMode = null;
      base64Image = null;
      _imageFile = null;
      currentPosition = null;
      });
    }

    @override
    void dispose() {
    _cameraController?.dispose();
    super.dispose();
    }


@override
Widget build(BuildContext context) {

  return Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
   appBar:AppBar(
    backgroundColor: Colors.transparent,
      title:Text(
        "Visit Application",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        foregroundColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87,
      forceMaterialTransparency: true,
    ),
    body: isDataLoading
    ? Stack(
    children: [
    Container (
    padding: const EdgeInsets.all(20),
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

      child:blockScreen
      ? _buildBlockScreen(_timeRemaining)
      :Form(
        key: _formKey,
        child: RefreshIndicator(
          onRefresh: handlePullToRefresh,
          color: Theme.of(context).iconTheme.color,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor ,
          child: ListView(
            children: [
            Padding(
            padding: const EdgeInsets.all(16.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildReadOnlyField(context,"Employee ID", _emId ?? "N/A"),
          const SizedBox(height: 16),
          buildReadOnlyField(context,"Employee Name", _emUsername ?? "N/A"),
          const SizedBox(height: 16),

          Text("Traveling Mode*", style: labelStyle),
          
          const SizedBox(height: 8),
         
          DropdownButtonFormField<String>(
            value: travel_mode?.isNotEmpty == true ? travel_mode : travellingMode,
            decoration: inputDecoration(context),
            dropdownColor: Theme.of(context).scaffoldBackgroundColor,
            items: (travel_mode != null && travel_mode!.isNotEmpty)
                ? [
                  DropdownMenuItem<String>(
                    value: travellingMode,
                    child: Text(travellingMode!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  ),    
                  )
                  ]
                : ['OWN VEHICLE', 'OTHER SOURCE'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                  )),
                    );
                  }).toList(),
                onChanged: (travel_mode != null && travel_mode!.isNotEmpty)
                    ? null 
                    : (val) => setState(() => travellingMode = val),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a Traveling Mode';
                  }
                  return null;
                },
              ),
        
          const SizedBox(height: 24),

          if(is_day_end == 'N') ... [
          Text('Did this Day End?', style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14),),
          Row(
            children: [
              Radio<String>(
                value: 'Y',
                groupValue: accommodationRequired,
                onChanged: (value) {
                  setState(() {
                    accommodationRequired = value!;
                  });
                },
              ),
              const Text('Yes'),
              const SizedBox(width: 20),
              Radio<String>(
                value: 'N',
                groupValue: accommodationRequired,
                onChanged: (value) {
                  setState(() {
                    accommodationRequired = value!;
                  });
                },
              ),
              const Text('No'),
            ],
          ),
          ],

        const SizedBox(height: 8),
          Text("Comments*", style: labelStyle),
          
          const SizedBox(height: 8),

          TextFormField(
            controller: _narrationController,
            maxLines: 2,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14),
            decoration: inputDecoration(context).copyWith(
              hintText: "Comment",
            ),
             validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a Comment';
            }
            return null;
          },
            onChanged: (val) {
            setState(() {
              narration = val;
            });
          },
        ),

         const SizedBox(height: 24),

          FutureBuilder(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Theme.of(context).iconTheme.color,));
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
                    child: Center(
                      child: Text('Camera will be initialized  please wait', style: TextStyle(color: Theme.of(context).iconTheme.color)),
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
                  child:Center(
                    child: CircularProgressIndicator(color: Theme.of(context).iconTheme.color,),
                  ),
                );
              }
            },
          ),

          const SizedBox(height: 12),
          Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isCapturing
                        ? 'Capturing image...'
                        : (_imageFile != null
                            ? 'Image captured'
                            : 'Press button to flip camera'),
                    style: TextStyle(
                      fontSize: 16,
                      color: _isCapturing ? Colors.red :  Theme.of(context).iconTheme.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12), 
                  IconButton(
                    icon: const Icon(Icons.cameraswitch_rounded),
                    tooltip: 'Flip Camera',
                    onPressed: _flipCamera,
                  ),
                ],
              ),
            ),

          if (_imageFile != null) 
            ...[
              const SizedBox(height: 20
              ),
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
                  ? Colors.green 
                  : const Color.fromARGB(255, 80, 140, 184), 
              foregroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  label: const Text("Submit Visit Entry"),
                  style: greenButtonStyle,
                  icon: const Icon(Icons.send_rounded, size: 20),
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
          child: const Center(
            child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Submitting, please wait...',
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


 Widget buildReadOnlyField(BuildContext context,String label, String value) {
          return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade300 
                  : const Color(0xFF6C757D), 
            ),
      ),
          const SizedBox(height: 8),
          Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
         color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade900
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade700
                : Colors.grey.shade300,
          ),
          ),
          child: Row(
          children: [
          Expanded(
          child: Text(
          value,
          style: TextStyle(
          fontSize: 15,
          color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF212529),
        ),
       ),
      ),
     ],
    ),
   ),
  ],
 );
}

String _formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(d.inHours.remainder(24));
  final minutes = twoDigits(d.inMinutes.remainder(60));
  final seconds = twoDigits(d.inSeconds.remainder(60));
  return "$hours:$minutes:$seconds";
}

Widget _buildBlockScreen(Duration timeRemaining) {
  return Container(
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      gradient: LinearGradient(
        colors: [
          Color(0xFF141E30), 
          Color(0xFF243B55),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),

    child: Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_clock_rounded,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Day Ended',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Next day starts at 12:00 AM',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(timeRemaining),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
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

InputDecoration inputDecoration(BuildContext context){
  return InputDecoration(
  filled: true,
  fillColor: Theme.of(context).brightness == Brightness.dark
      ? Colors.grey.shade900
      : Colors.white,
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
}

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
