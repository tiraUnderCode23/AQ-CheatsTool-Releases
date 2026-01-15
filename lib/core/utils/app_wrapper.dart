import 'package:flutter/material.dart';
import 'dart:io';
import '../../widgets/custom_title_bar.dart';

/// Wraps the app content with custom title bar on Windows
class AppWrapper extends StatelessWidget {
  final Widget child;

  const AppWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      return CustomTitleBar(
        title: 'AQ///bimmer Cheats Tool',
        backgroundColor: const Color(0xFF0a0a0f),
        child: child,
      );
    }
    return child;
  }
}
