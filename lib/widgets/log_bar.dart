import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// LogBar widget matching Python's LogBar class
/// Shows status messages with AQ///bimmer branding and timestamps
class LogBar extends StatefulWidget {
  const LogBar({super.key});

  @override
  State<LogBar> createState() => LogBarState();
}

class LogBarState extends State<LogBar> {
  String _message = '🚀 AQbimmer.com server ready';
  Color _messageColor = const Color(0xFFe5e7eb);
  String _icon = '💫';

  /// Set a status message with automatic icon and color based on content
  void setMessage(String msg) {
    // Replace github references with server (matching Python)
    msg = msg.replaceAll('github', 'server').replaceAll('GitHub', 'server');

    // Determine icon and color based on message content
    String icon;
    Color color;

    final lowerMsg = msg.toLowerCase();
    if (lowerMsg.contains('success') ||
        lowerMsg.contains('completed') ||
        lowerMsg.contains('ready')) {
      icon = '✅';
      color = const Color(0xFF22c55e); // success_color
    } else if (lowerMsg.contains('error') || lowerMsg.contains('failed')) {
      icon = '❌';
      color = const Color(0xFFef4444); // danger_color
    } else if (lowerMsg.contains('loading') ||
        lowerMsg.contains('processing')) {
      icon = '⏳';
      color = const Color(0xFFf59e0b); // warning_color
    } else if (lowerMsg.contains('warning')) {
      icon = '⚠️';
      color = const Color(0xFFf59e0b); // warning_color
    } else if (lowerMsg.contains('authentication') ||
        lowerMsg.contains('login')) {
      icon = '🔐';
      color = const Color(0xFF3b82f6); // info_color
    } else if (lowerMsg.contains('pywinstyles') || lowerMsg.contains('theme')) {
      icon = '🎨';
      color = const Color(0xFF00ffd0); // accent_color
    } else {
      icon = '💫';
      color = const Color(0xFFe5e7eb); // text_color
    }

    setState(() {
      _message = msg;
      _messageColor = color;
      _icon = icon;
    });
  }

  String get _formattedTimestamp {
    return DateFormat('HH:mm:ss').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // glass_primary
        border: Border(
          top: BorderSide(
            color: const Color(0xFF4b5563).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          // Brand identity section (left side) - matching Python
          _buildBrandSection(),
          const SizedBox(width: 15),
          // Status message (center-right)
          Expanded(
            child: Text(
              '$_icon [$_formattedTimestamp] $_message',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                color: _messageColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSection() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AQ part (Blue)
        Text(
          'AQ',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3b82f6), // primary_color
          ),
        ),
        // Slash separator (White)
        Text(
          '///',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        // bimmer part (Red)
        Text(
          'bimmer',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFFef4444), // secondary_color
          ),
        ),
        // .com extension (Cyan)
        Text(
          '.com',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 8,
            color: Color(0xFF00ffd0), // accent_color
          ),
        ),
      ],
    );
  }
}

/// Global key to access LogBar from anywhere
final GlobalKey<LogBarState> logBarKey = GlobalKey<LogBarState>();

/// Helper function to log messages from anywhere
void aqLog(String message) {
  logBarKey.currentState?.setMessage(message);
}
