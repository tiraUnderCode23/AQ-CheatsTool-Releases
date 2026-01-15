import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';

import '../../core/providers/activation_provider.dart';
import '../../core/services/resource_decryptor.dart';
import '../../core/services/auto_update_service.dart';
import '../../widgets/update_dialog.dart';
import '../home/home_screen.dart';
import '../activation/activation_screen.dart';

/// AQ CheatsTool Splash Screen - BMW M Style
/// Matching Python's LoadingScreen with AQ///bimmer branding
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _colorController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  String _statusText = 'Loading...';
  double _progress = 0.0;
  bool _isChecking = false;

  // BMW M Colors - Matching Python's AQ_THEME_CONFIG
  static const Color _bmwBlue = Color(0xFF3b82f6); // primary_blue
  static const Color _bmwRed = Color(0xFFef4444); // secondary_red
  static const Color _bmwWhite = Color(0xFFFFFFFF); // white
  static const Color _bmwCyan = Color(0xFF00ffd0); // accent_cyan

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Color animation cycling through BMW M colors
    _colorController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.5, curve: Curves.elasticOut)),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_isChecking) {
          _controller.repeat(reverse: true, min: 0.5, max: 1.0);
        }
      });

    _controller.forward();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 1: Decrypt resources
    setState(() {
      _statusText = 'Decrypting resources...';
      _progress = 0.1;
    });

    final decryptSuccess = await ResourceDecryptor.initialize();

    // Log extraction info
    print('=== ResourceDecryptor Logs ===');
    for (final log in ResourceDecryptor.logs) {
      print(log);
    }
    print('Attachments Path: ${ResourceDecryptor.attachmentsPath}');
    print('==============================');

    if (!decryptSuccess) {
      setState(() {
        _statusText = 'Error loading resources!';
      });
      return;
    }

    // Update status
    setState(() {
      _statusText = 'Loading settings...';
      _progress = 0.3;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _statusText = 'Verifying license...';
      _progress = 0.5;
      _isChecking = true;
    });

    // Check activation
    final activationProvider = context.read<ActivationProvider>();
    await activationProvider.checkActivationStatus();

    setState(() {
      _statusText = 'Loading data...';
      _progress = 0.7;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    // Check for updates
    setState(() {
      _statusText = 'Checking for updates...';
      _progress = 0.85;
    });

    final updateService = context.read<AutoUpdateService>();
    await updateService.checkForUpdates();

    setState(() {
      _statusText = 'Preparing...';
      _progress = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    // Show update dialog if update is available
    if (mounted && updateService.updateAvailable) {
      await UpdateDialog.show(context);
    }

    // Navigate based on activation status
    if (mounted) {
      if (activationProvider.isActivated) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const HomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const ActivationScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              _bmwBlue.withOpacity(0.15),
              Colors.black,
              Colors.black,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPatternPainter(),
              ),
            ),

            // Animated glow circles
            AnimatedBuilder(
              animation: _colorController,
              builder: (context, child) {
                return Stack(
                  children: [
                    // Blue glow
                    Positioned(
                      top: MediaQuery.of(context).size.height * 0.2,
                      left: -100,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _bmwBlue.withOpacity(0.3 *
                                  (0.5 +
                                      0.5 *
                                          sin(_colorController.value *
                                              2 *
                                              pi))),
                              blurRadius: 150,
                              spreadRadius: 50,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Red glow
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * 0.2,
                      right: -100,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _bmwRed.withOpacity(0.3 *
                                  (0.5 +
                                      0.5 *
                                          sin((_colorController.value + 0.33) *
                                              2 *
                                              pi))),
                              blurRadius: 150,
                              spreadRadius: 50,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Cyan glow
                    Positioned(
                      bottom: -50,
                      left: MediaQuery.of(context).size.width * 0.3,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _bmwCyan.withOpacity(0.3 *
                                  (0.5 +
                                      0.5 *
                                          sin((_colorController.value + 0.66) *
                                              2 *
                                              pi))),
                              blurRadius: 150,
                              spreadRadius: 50,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with pulse animation
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.scale(
                          scale: _scaleAnimation.value * _pulseAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildBMWLogo(),
                  ),

                  const SizedBox(height: 40),

                  // AQ///CheatTool Branding - Matching Python's LogBar
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildAQBranding(),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'BMW Professional Diagnostic Tool',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // BMW M Style Progress Bar with 3 colors
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildBMWProgressBar(),
                  ),

                  const SizedBox(height: 24),

                  // Status text in Arabic
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ],
              ),
            ),

            // Version & Copyright
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Version 2.0.0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '© 2024 ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                        const Text(
                          'AQ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _bmwBlue,
                          ),
                        ),
                        Text(
                          '///',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _bmwWhite.withOpacity(0.8),
                          ),
                        ),
                        const Text(
                          'bimmer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _bmwRed,
                          ),
                        ),
                        const Text(
                          '.com',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _bmwCyan,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build BMW Logo from Image
  Widget _buildBMWLogo() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _bmwBlue.withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: _bmwCyan.withOpacity(0.3),
            blurRadius: 60,
            spreadRadius: 15,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/bmw_logo.png',
          width: 160,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            // Fallback to text logo if image not found
            return Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _bmwBlue,
                    _bmwBlue.withOpacity(0.7),
                  ],
                ),
                border: Border.all(
                  color: _bmwWhite.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _bmwWhite,
                      _bmwCyan,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'BMW',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build AQ///CheatTool branding matching Python's LogBar
  Widget _buildAQBranding() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // AQ in blue
        const Text(
          'AQ',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: _bmwBlue,
            letterSpacing: 1,
          ),
        ),
        // /// in white
        Text(
          '///',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: _bmwWhite.withOpacity(0.9),
            letterSpacing: 0,
          ),
        ),
        // CheatTool in red
        const Text(
          'CheatTool',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: _bmwRed,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// Build BMW M Style Progress Bar with 3 color segments
  Widget _buildBMWProgressBar() {
    const barWidth = 320.0;
    const barHeight = 6.0;
    final progressWidth = barWidth * _progress;

    return SizedBox(
      width: barWidth,
      height: barHeight + 4, // Extra for glow effect
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Background bar
          Container(
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
          ),

          // Progress bar with 3 BMW M color segments
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: progressWidth,
            height: barHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(barHeight / 2),
              child: Stack(
                children: [
                  // Blue segment (0-33%)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: barWidth * 0.33,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _bmwBlue,
                        boxShadow: [
                          BoxShadow(
                            color: _bmwBlue.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // White segment (33-66%)
                  Positioned(
                    left: barWidth * 0.33,
                    top: 0,
                    bottom: 0,
                    width: barWidth * 0.34,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _bmwWhite.withOpacity(0.9),
                        boxShadow: [
                          BoxShadow(
                            color: _bmwWhite.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Red segment (66-100%)
                  Positioned(
                    left: barWidth * 0.67,
                    top: 0,
                    bottom: 0,
                    width: barWidth * 0.33,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _bmwRed,
                        boxShadow: [
                          BoxShadow(
                            color: _bmwRed.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Glow effect at progress end
          if (_progress > 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: progressWidth - 8,
              top: -4,
              child: Container(
                width: 16,
                height: barHeight + 8,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: _getProgressColor().withOpacity(0.8),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Get current progress color based on progress value
  Color _getProgressColor() {
    if (_progress <= 0.33) {
      return _bmwBlue;
    } else if (_progress <= 0.66) {
      return _bmwWhite;
    } else {
      return _bmwRed;
    }
  }
}

/// Grid pattern painter for glass effect
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
