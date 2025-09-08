import 'package:flutter/material.dart';
import 'package:flutter_application_3/screen/user/account_screen.dart';
import 'package:flutter_application_3/screen/user/document_screen.dart';
import 'package:flutter_application_3/screen/user/letter_screen.dart';
import 'package:flutter_application_3/screen/user/salary_screen.dart';
import './user_info_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class SwipFunction extends StatefulWidget {
  const SwipFunction({super.key});

  @override
  State<SwipFunction> createState() => _SwipFunctionState();
}

class _SwipFunctionState extends State<SwipFunction> with TickerProviderStateMixin {

  int _currentIndex = 0;
  bool _isMenuOpen = false;

  late PageController _pageController;

  final List<String> sections = ['Profile', 'Bank Account','Documents','Salary','Letter'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  // Future<void> _showSwipePreviewIfNeeded() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final hasSeenGuide = prefs.getBool('seen_swipe_preview') ?? false;

  //   if (!hasSeenGuide && mounted) {
  //     setState(() => _showOverlay = true);

  //     Future.delayed(const Duration(milliseconds: 800), () {
  //       _pageController.animateToPage(1,
  //           duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
  //     });

  //     Future.delayed(const Duration(milliseconds: 2000), () {
  //       _pageController.animateToPage(2,
  //           duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
  //     });

  //     Future.delayed(const Duration(milliseconds: 3200), () {
  //       _pageController.animateToPage(0,
  //           duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
  //     });

  //     // await prefs.setBool('seen_swipe_preview', true);

  //     // Future.delayed(const Duration(seconds: 5), () async {
  //     //   if (mounted) {
  //     //     setState(() => _showOverlay = false);
  //     //     await prefs.setBool('seen_swipe_preview', true);
  //     //   }
  //     // });
  //   }
  // }

final Map<String, IconData> sectionIcons = {
  "Profile": Icons.person,
  "Bank Account": Icons.account_balance,
  "Documents": FontAwesomeIcons.file,
  "Salary": FontAwesomeIcons.wallet,
  "Letter": FontAwesomeIcons.letterboxd
};

 void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
      Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFFF2F5F8)
              : const Color(0xFF121212),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title: PopupMenuButton<String>(
              color: Theme.of(context).scaffoldBackgroundColor,
              onOpened: () {
                setState(() => _isMenuOpen = true);
              },
              onCanceled: () {
                setState(() => _isMenuOpen = false);
              },
              onSelected: (String newValue) {
                final index = sections.indexOf(newValue);
                setState(() {
                  _currentIndex = index;
                  _isMenuOpen = false;
                });
                _pageController.jumpToPage(index);
              },
              itemBuilder: (context) => sections.map((String section) {
                return PopupMenuItem<String>(
                  value: section,
                  child: Row(
                    children: [
                      Icon(
                        sectionIcons[section] ?? Icons.circle,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      const SizedBox(width: 10),
                      Text(section, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                );
              }).toList(),
              offset: const Offset(0, kToolbarHeight),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reddit-like title transition
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      final offsetAnim = Tween<Offset>(
                        begin: const Offset(0.2, 0),
                        end: Offset.zero,
                      ).animate(animation);

                      return SlideTransition(
                        position: offsetAnim,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      sections[_currentIndex],
                      key: ValueKey(_currentIndex),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _currentIndex == 0
                            ? Colors.blue.shade800
                            : Theme.of(context).iconTheme.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Arrow rotation
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: _isMenuOpen ? 0.5 : 0, // 0 = ▼, 0.5 = ▲
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
            UserInfo(),
            AccountScreen(),
            DocumentScreen(),
            SalaryScreen(),
            LetterScreen()  
        ]
      ),
    ),
//    if (_showOverlay)
//   Positioned.fill(
//     child: AnimatedOpacity(
//       opacity: 1.0,
//       duration: const Duration(milliseconds: 500),
//       child: Container(
//         color: Colors.black.withOpacity(0.7),
//         child: Center(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24.0),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 TweenAnimationBuilder<double>(
//                   tween: Tween(begin: -20, end: 20),
//                   duration: const Duration(milliseconds: 1000),
//                   curve: Curves.easeInOut,
//                   builder: (context, value, child) {
//                     return Transform.translate(
//                       offset: Offset(value, 0),
//                       child: child,
//                     );
//                   },
//                   onEnd: () {
//                     if (_showOverlay) {
//                       setState(() {
//                       });
//                     }
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.white.withOpacity(0.1),
//                       border: Border.all(
//                         color: Colors.white.withOpacity(0.3),
//                         width: 2,
//                       ),
//                     ),
//                     child: const Icon(
//                       Icons.swipe,
//                       size: 80,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 30),

//                 Text(
//                   "Swipe left or right",
//                   style: TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white.withOpacity(0.95),
//                     decoration: TextDecoration.none, 
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   "Navigate between sections",
//                   textAlign: TextAlign.center,
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: Colors.white.withOpacity(0.8),
//                     decoration: TextDecoration.none,
//                   ),
//                 ),

//                 const SizedBox(height: 25),

//                 TweenAnimationBuilder<double>(
//                   tween: Tween(begin: 0, end: 20),
//                   duration: const Duration(milliseconds: 800),
//                   curve: Curves.easeInOut,
//                   builder: (context, value, child) {
//                     return Transform.translate(
//                       offset: Offset(value, 0),
//                       child: child,
//                     );
//                   },
//                   onEnd: () {
//                     if (_showOverlay) {
//                       setState(() {});
//                     }
//                   },
//                   child: const Icon(
//                     Icons.arrow_forward,
//                     size: 40,
//                     color: Colors.white,
//                   ),
//                 ),

//                 const SizedBox(height: 20),

//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.white.withOpacity(0.9),
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 30, vertical: 12),
//                   ),
//                   onPressed: () async {
//                   final prefs = await SharedPreferences.getInstance();
//                   await prefs.setBool('seen_swipe_preview', true);
//                   if (mounted) setState(() => _showOverlay = false);
//                   },
//                   child: const Text(
//                     "Got it",
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                       decoration: TextDecoration.none, 
//                     ),
//                   ),
//                 )
//               ],
//             ),
//           ),
//         ),
//       ),
//     ),
//   ),
]
);
}
}
