import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

class GlobalKeyboardDismiss extends StatefulWidget {
  final Widget child;
  const GlobalKeyboardDismiss({super.key, required this.child});

  @override
  State<GlobalKeyboardDismiss> createState() => _GlobalKeyboardDismissState();
}

class _GlobalKeyboardDismissState extends State<GlobalKeyboardDismiss> {
  late final KeyboardVisibilityController _controller;
  late final StreamSubscription<bool> _subscription;

  @override
  void initState() {
    super.initState();
    _controller = KeyboardVisibilityController();
    _subscription = _controller.onChange.listen((visible) {
      if (!visible) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: widget.child,
    );
  }
}
