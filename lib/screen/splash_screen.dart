// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';


// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _scaleAnimation;

//   @override
//   void initState() {
//     super.initState();

//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1000),
//     );

//     _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeOut),
//     );


//     Future.delayed(const Duration(milliseconds: 300), () {
//       _controller.forward();
//     });

    
//     Future.delayed(const Duration(seconds: 2), () {
//       _checkLogin();
//     });
//   }

//   Future<void> _checkLogin() async {
//     final prefs = await SharedPreferences.getInstance();
//     final token = prefs.getString('auth_token');

//     if (token != null && token.isNotEmpty) {
//       Navigator.pushReplacementNamed(context, '/home');
//     } else {
//       Navigator.pushReplacementNamed(context, '/login');
//     }
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0XFFFFFFFF),
//       body: SafeArea(
//         child: Center(
//           child: ScaleTransition(
//             scale: _scaleAnimation,
//             child: Image.asset(
//               'assets/icon/image.png',
//               width: MediaQuery.of(context).size.width/2.5,
//             ),
//           ),  
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:safe_device/safe_device.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _ringController;

  static const _minDisplay = Duration(milliseconds: 1400);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _hasNavigated = false;
 
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/icon/image.png'), context);
  }

Future<bool> _hasActiveInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
  } catch (_) {
  }
  return false;
}


  Future<void> _init() async {
    final startedAt = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final connectivityResult = await Connectivity().checkConnectivity();

    print('connectivityResult: $connectivityResult');

    final hasNetwork = connectivityResult != ConnectivityResult.none && await _hasActiveInternet();

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = _minDisplay - elapsed;
    if (remaining.inMilliseconds > 0) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    if(hasNetwork) {
      _navigateBasedOnToken(token);
    }else{
      _showNoInternetDialog();
      _listenToConnectivity(token);
    }
  }


   void _navigateBasedOnToken(String? token) {
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

void _listenToConnectivity(String? token) {
  _connectivitySubscription = Connectivity()
      .onConnectivityChanged
      .listen((List<ConnectivityResult> results) async {
    final result = results.firstWhere(
      (res) => res != ConnectivityResult.none,
      orElse: () => ConnectivityResult.none,
    );

    if (!_hasNavigated && result != ConnectivityResult.none && await _hasActiveInternet()) {
      _hasNavigated = true;

       if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted) {
            _navigateBasedOnToken(token);
          }
        });
      });
    }
  });
}

   void _showNoInternetDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      elevation: 12,
      title: Row(
        children: const [
          Icon(Icons.wifi_off, color: Colors.redAccent),
          SizedBox(width: 10),
          Text(
            'No Internet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 20,
            ),
          ),
        ],
      ),
      content: const Text(
        'Please check your connection.\nWaiting for network...',
        style: TextStyle(
          fontSize: 16,
          color: Colors.black54,
        ),
      ),
    ),
  );
}

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0F0F10), Color(0xFF1C1C1E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF2F6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final logo = Image.asset(
      'assets/icon/image.png',
      width: size.width / 2.5,
      fit: BoxFit.contain,
    );

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: bg),
        child: Stack(
          children: [
            IgnorePointer(
              ignoring: true,
              child: Center(
                child: AnimatedBuilder(
                  animation: _ringController,
                  builder: (context, _) {
                    final ringColor =
                        (isDark ? Colors.white : Colors.black).withOpacity(0.8);
                    final boxSize = size.shortestSide * 0.78;
                    return SizedBox(
                      width: boxSize,
                      height: boxSize,
                      child: CustomPaint(
                        painter: _ExpandingRingsPainter(
                          t: _ringController.value,
                          color: ringColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final wave = math.sin(_pulseController.value * 2 * math.pi);
                  final dy = wave * 4; 
                  final scale = 1.0 + (_pulseController.value * 0.03);

                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: isDark ? 0.35 : 0.5,
                            child: Transform.scale(
                              scale: 1.06,
                              child: ImageFiltered(
                                imageFilter: ImageFilter.blur(
                                  sigmaX: 16,
                                  sigmaY: 16,
                                ),
                                child: logo,
                              ),
                            ),
                          ),
                             logo .animate()
                              .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                              .scale(
                                begin: const Offset(0.92, 0.92),
                                end: const Offset(1.0, 1.0),
                                duration: 600.ms,
                                curve: Curves.easeOutBack,
                              )
                              .shimmer(
                                duration: 1200.ms,
                                delay: 200.ms,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black26,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

            // Positioned(
            //   left: 24,
            //   right: 24,
            //   bottom: 40,
            //   child: Text(
            //     'Loading...',
            //     textAlign: TextAlign.center,
            //     style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            //           color: Theme.of(context)
            //               .textTheme
            //               .bodyMedium
            //               ?.color
            //               ?.withOpacity(0.65),
            //         ),
            //   ).animate(delay: 150.ms).fadeIn(duration: 500.ms),
            // ),
          ],
        ),
      ),
    );
  }
}

class _ExpandingRingsPainter extends CustomPainter {
  final double t; // 0..1
  final Color color;

  _ExpandingRingsPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;

    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3.0) % 1.0;
      final radius = lerpDouble(maxR * 0.25, maxR, phase)!;
      final opacity = (1.0 - phase) * 0.18; 
      final stroke = lerpDouble(2.5, 0.8, phase)!;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = color.withOpacity(opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpandingRingsPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.color != color;
  }
}
