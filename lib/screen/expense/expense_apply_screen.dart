import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import '../helper/top_snackbar.dart';
import '../utils/user_session.dart';
import '../utils/network_failure.dart';

class ExpenseApplyScreen extends StatefulWidget {
  const ExpenseApplyScreen({super.key});

  @override
  State<ExpenseApplyScreen> createState() => _ExpenseScreen();
}

class _ExpenseScreen extends State<ExpenseApplyScreen> {
  final baseUrl = dotenv.env['API_BASE_URL'];
  final apiToken = dotenv.env['ACCESS_TOKEN'];
  
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  List expenseTypes = [];
  String? selectExpenseType;
  String? description,loadingText;
  String? _token;
  String? _emId,_error;
  String? _emUsername;
  String? _compFname;
  int? amount;
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

  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

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

  Future<void> fetchDataPacketApi() async {

    if(expenseTypes.isNotEmpty) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/MyApis/expensethetype'),
      headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiToken',
          'auth_token': _token!,
          'user_id': _emId!
        },
      );
      
      final jsonData = json.decode(response.body);

      await UserSession.checkInvalidAuthToken(
        context,
        json.decode(response.body),
        response.statusCode,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['user_details'];

        if(mounted){ 
        setState(() {
          _compFname = data['comp_fname'];
        });
      }

        print('Company Name: $_compFname');

        if(jsonData['data_packet'] != null && jsonData['data_packet'] is List){
        setState(() {
          expenseTypes = jsonData['data_packet'];
        });
      }

      print('Expense Types: $expenseTypes');
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

  Future<void> submitExpense() async {
  if (isSubmitting) return;

  if (!_formKey.currentState!.validate() || selectExpenseType == null && description == null && amount == null) {
    if (mounted) {
      showCustomSnackBar(
        context,
        "Please fill all field for expense",
        Colors.yellow.shade900,
        Icons.warning_amber_outlined,
      );
      setState(() => isSubmitting = false);
    }
    return;
  }


  if (base64Image == null) {
    if (mounted) {
      showCustomSnackBar(
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
      loadingText = 'Submitting Expense, please wait...';
    });
  }

  try {
    if (currentPosition == null) {
      currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    }

    _formKey.currentState!.save();

    final body = {
      'exp_description': description,
      'expense_type': selectExpenseType,
      'expense_amount': amount,
      'latitude': currentPosition?.latitude,
      'longitude': currentPosition?.longitude,
      'expense_img': base64Image,
    };

    print('Body: $body');

    final uri = Uri.parse('$baseUrl/MyApis/expensetheadd');

    print('URI: $uri');

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
        showCustomSnackBar(
          context,
          'Expense Is Entered successfully',
          Colors.green,
          Icons.check_circle,
        );
        await _resetForm();
      }
    } else {
      if (mounted) {
        showCustomSnackBar(
          context,
          resBody['message'] ?? 'Something went wrong',
          Colors.red,
          Icons.error,
        );
      }
    }
  } catch (e) {
    if (mounted) {
      showCustomSnackBar(
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
      _descriptionController.clear();
      _amountController.clear();
      
      setState(() {
      description = null;
      selectExpenseType = null;
      base64Image = null;
      _imageFile = null;
      });
    }

    @override
    void dispose() {
    _connectivitySubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
    }


//  void _showCustomSnackBar(BuildContext context, String message, Color color, IconData icon) {
//   final scaffoldMessenger = ScaffoldMessenger.of(context);

//     scaffoldMessenger.clearSnackBars();
//     final snackBar = SnackBar(
//       content: Row(
//         children: [
//           Icon(icon, color: Colors.white),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ),
//         ],
//       ),
//       backgroundColor: color,
//       behavior: SnackBarBehavior.floating,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       margin: const EdgeInsets.all(16),
//       duration: const Duration(seconds: 3),
//     );

//     ScaffoldMessenger.of(context).showSnackBar(snackBar);
//   }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Theme.of(context).brightness == Brightness.light
        ? Color(0xFFF2F5F8)
        : Color(0xFF121212),
   appBar:AppBar(
    backgroundColor: Colors.transparent, 
      title: Text(
        "Apply Expense",
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
      ),
      foregroundColor: Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87,
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
          buildReadOnlyField(context,"Employee ID", _emId ?? "N/A"),
          const SizedBox(height: 16),
          buildReadOnlyField(context,"Employee Name", _emUsername ?? "N/A"),
          const SizedBox(height: 16),
          buildReadOnlyField(context,"Company Name", _compFname ?? "N/A"),
          
          const SizedBox(height: 24),

          Text("Expense Type*", style: labelStyle),
          const SizedBox(height: 8),

          expenseTypes.isNotEmpty?
          DropdownButtonFormField<String>(
            value: selectExpenseType,
            decoration: inputDecoration(context),
            dropdownColor: Theme.of(context).scaffoldBackgroundColor,
            icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade500),
            items: expenseTypes.map((e) {
              return DropdownMenuItem<String>(
                value: e["id"].toString(),
                child: Text(e["expense_name"]),
              );
            }).toList(),
            onChanged: (val) => setState(() => selectExpenseType = val),
            validator: (value) => value == null ? 'Select expense type' : null,
            ):CupertinoActivityIndicator(),
        
          const SizedBox(height: 24),

            TextFormField(
              controller: (_amountController),
            keyboardType: TextInputType.number,
            style: inputTextStyle,
            decoration: inputDecoration(context).copyWith(
              hintText: "Amount*",
              prefixText: "\₹ ",
              prefixStyle: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold
              )
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an amount';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                if(value.isNotEmpty){
                  final doubleVal = double.tryParse(value);
                  if(doubleVal != null){
                    amount = doubleVal.round();
                  }
                }
              });
            },
          ),
          
          const SizedBox(height: 8),
        
          // Text("Description*", style: labelStyle),

          const SizedBox(height: 8),

          TextFormField(
            controller: _descriptionController,
            maxLines: 2,
            style: inputTextStyle,
            decoration: inputDecoration(context).copyWith(
              hintText: " Description*",
            ),
            validator: (value) {
            if ((value == null || value.trim().isEmpty)) 
            {
              return 'Please give a description of the expense';
            }
            return null;
          },
            onChanged: (val) {
            setState(() {
              description = val;
            });
          },
        ),

         const SizedBox(height: 24),

          FutureBuilder(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Theme.of(context).iconTheme.color));
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
                      color: _isCapturing ? Colors.red : Theme.of(context).iconTheme.color,
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
                    await submitExpense();
                  },
                  label: const Text("Submit Expense"),
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

 Widget buildReadOnlyField(BuildContext context, String label, String value) {
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
