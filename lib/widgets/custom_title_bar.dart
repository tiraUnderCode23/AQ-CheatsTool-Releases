import 'package:flutter/material.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';

/// Custom Title Bar widget that replaces Windows default title bar
/// Matches Python's frameless window with custom controls
class CustomTitleBar extends StatefulWidget {
  final Widget child;
  final String title;
  final Color? backgroundColor;
  final bool showMinimize;
  final bool showMaximize;
  final bool showClose;

  const CustomTitleBar({
    super.key,
    required this.child,
    this.title = 'AQ///bimmer Cheats Tool',
    this.backgroundColor,
    this.showMinimize = true,
    this.showMaximize = true,
    this.showClose = true,
  });

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;
  bool _isHoveringClose = false;
  bool _isHoveringMaximize = false;
  bool _isHoveringMinimize = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      _checkMaximized();
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    if (Platform.isWindows) {
      final isMax = await windowManager.isMaximized();
      if (mounted) {
        setState(() => _isMaximized = isMax);
      }
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows) {
      return widget.child;
    }

    return Column(
      children: [
        _buildTitleBar(context),
        Expanded(child: widget.child),
      ],
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final bgColor = widget.backgroundColor ?? const Color(0xFF0a0a0f);

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: _toggleMaximize,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          border: const Border(
            bottom: BorderSide(
              color: Color(0xFF1a1a2e),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            // BMW/AQ Logo and Title
            _buildBrandTitle(),
            const Spacer(),
            // Window Controls
            if (widget.showMinimize) _buildMinimizeButton(),
            if (widget.showMaximize) _buildMaximizeButton(),
            if (widget.showClose) _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BMW Logo icon
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF3b82f6).withOpacity(0.8),
                const Color(0xFF1e40af),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3b82f6).withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'B',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // AQ part (Blue)
        const Text(
          'AQ',
          style: TextStyle(
            color: Color(0xFF3b82f6),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        // Slash separator (White)
        const Text(
          '///',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        // CheatTool part (Red)
        const Text(
          'CheatTool',
          style: TextStyle(
            color: Color(0xFFef4444),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(width: 8),
        // BMW Edition badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00ffd0).withOpacity(0.2),
                const Color(0xFF00ffd0).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: const Color(0xFF00ffd0).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Text(
            'BMW',
            style: TextStyle(
              color: Color(0xFF00ffd0),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinimizeButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringMinimize = true),
      onExit: (_) => setState(() => _isHoveringMinimize = false),
      child: GestureDetector(
        onTap: () => windowManager.minimize(),
        child: Container(
          width: 46,
          height: 40,
          color: _isHoveringMinimize
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          child: Center(
            child: Icon(
              Icons.remove,
              color: _isHoveringMinimize
                  ? Colors.white
                  : Colors.white.withOpacity(0.7),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaximizeButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringMaximize = true),
      onExit: (_) => setState(() => _isHoveringMaximize = false),
      child: GestureDetector(
        onTap: _toggleMaximize,
        child: Container(
          width: 46,
          height: 40,
          color: _isHoveringMaximize
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          child: Center(
            child: Icon(
              _isMaximized ? Icons.filter_none : Icons.crop_square,
              color: _isHoveringMaximize
                  ? Colors.white
                  : Colors.white.withOpacity(0.7),
              size: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHoveringClose = true),
      onExit: (_) => setState(() => _isHoveringClose = false),
      child: GestureDetector(
        onTap: () => windowManager.close(),
        child: Container(
          width: 46,
          height: 40,
          color:
              _isHoveringClose ? const Color(0xFFef4444) : Colors.transparent,
          child: Center(
            child: Icon(
              Icons.close,
              color: _isHoveringClose
                  ? Colors.white
                  : Colors.white.withOpacity(0.7),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }
}

/// Initialize window for frameless mode (call in main())
Future<void> initializeCustomWindow() async {
  if (!Platform.isWindows) return;

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Color(0xFF0a0a0f),
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'AQ///bimmer Cheats Tool',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
