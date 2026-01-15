import 'package:fluent_ui/fluent_ui.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';

import '../theme/aq_theme.dart';
import 'home_screen.dart';

/// AQ///PSDZ Splash Screen - BMW M Style
/// Professional loading screen with glass morphism effects
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _colorController;
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  String _statusText = 'Loading...';
  double _progress = 0.0;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _controller.forward();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // Step 1: Loading resources
    setState(() {
      _statusText = 'Loading resources...';
      _progress = 0.15;
    });
    await Future.delayed(const Duration(milliseconds: 400));

    // Step 2: Loading settings
    setState(() {
      _statusText = 'Loading settings...';
      _progress = 0.30;
    });
    await Future.delayed(const Duration(milliseconds: 350));

    // Step 3: Initializing services
    setState(() {
      _statusText = 'Initializing services...';
      _progress = 0.50;
    });
    await Future.delayed(const Duration(milliseconds: 400));

    // Step 4: Loading vehicle data
    setState(() {
      _statusText = 'Loading vehicle data...';
      _progress = 0.70;
    });
    await Future.delayed(const Duration(milliseconds: 350));

    // Step 5: Preparing interface
    setState(() {
      _statusText = 'Preparing interface...';
      _progress = 0.90;
    });
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 6: Complete
    setState(() {
      _statusText = 'Ready!';
      _progress = 1.0;
      _isInitializing = false;
    });
    await Future.delayed(const Duration(milliseconds: 500));

    // Navigate to home
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _colorController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return ScaffoldPage(
      content: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: isDark
              ? AQColors.backgroundGlow
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AQColors.lightBackground,
                    AQColors.lightSurfaceBackground,
                    const Color(0xFFE0E0E0),
                  ],
                ),
        ),
        child: Stack(
          children: [
            // Grid pattern background (dark mode only)
            if (isDark)
              Positioned.fill(
                child: CustomPaint(painter: GridPatternPainter()),
              ),

            // Animated glow circles (dark mode) or subtle gradients (light mode)
            if (isDark)
              AnimatedBuilder(
                animation: _colorController,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Blue glow - top left
                      Positioned(
                        top: MediaQuery.of(context).size.height * 0.1,
                        left: -100,
                        child: Container(
                          width: 350,
                          height: 350,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AQColors.primaryBlue.withOpacity(
                                  0.25 *
                                      (0.5 +
                                          0.5 *
                                              sin(
                                                _colorController.value * 2 * pi,
                                              )),
                                ),
                                blurRadius: 180,
                                spreadRadius: 60,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Red glow - bottom right
                      Positioned(
                        bottom: MediaQuery.of(context).size.height * 0.1,
                        right: -100,
                        child: Container(
                          width: 350,
                          height: 350,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AQColors.secondaryRed.withOpacity(
                                  0.25 *
                                      (0.5 +
                                          0.5 *
                                              sin(
                                                (_colorController.value +
                                                        0.33) *
                                                    2 *
                                                    pi,
                                              )),
                                ),
                                blurRadius: 180,
                                spreadRadius: 60,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Cyan glow - bottom center
                      Positioned(
                        bottom: -80,
                        left: MediaQuery.of(context).size.width * 0.3,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AQColors.accentCyan.withOpacity(
                                  0.2 *
                                      (0.5 +
                                          0.5 *
                                              sin(
                                                (_colorController.value +
                                                        0.66) *
                                                    2 *
                                                    pi,
                                              )),
                                ),
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
              )
            else
              // Light mode - subtle BMW M stripe effect
              AnimatedBuilder(
                animation: _colorController,
                builder: (context, child) {
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: AQColors.mStripesGradient,
                      ),
                    ),
                  );
                },
              ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // BMW Logo with pulse animation
                  AnimatedBuilder(
                    animation: Listenable.merge([_controller, _logoController]),
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

                  const SizedBox(height: 50),

                  // AQ///PSDZ Branding
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const AQBranding(suffix: 'PSDZ', fontSize: 42),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'BMW Professional Diagnostic Tool',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AQColors.textSecondary
                            : AQColors.lightTextSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  // BMW M Style Progress Bar
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildBMWProgressBar(),
                  ),

                  const SizedBox(height: 24),

                  // Status text
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AQColors.textSecondary
                            : AQColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Version & Copyright footer
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
                        color: isDark
                            ? AQColors.textMuted
                            : AQColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const BrandingFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build BMW Logo
  Widget _buildBMWLogo() {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AQColors.primaryBlue.withOpacity(0.5),
            blurRadius: 50,
            spreadRadius: 15,
          ),
          BoxShadow(
            color: AQColors.accentCyan.withOpacity(0.3),
            blurRadius: 70,
            spreadRadius: 20,
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AQColors.primaryBlue,
                  AQColors.primaryBlue.withOpacity(0.7),
                ],
              ),
              border: Border.all(
                color: AQColors.white.withOpacity(0.3),
                width: 3,
              ),
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AQColors.white, AQColors.accentCyan],
                ).createShader(bounds),
                child: const Text(
                  'BMW',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build BMW M Style Progress Bar with 3 color segments
  Widget _buildBMWProgressBar() {
    const barWidth = 360.0;
    const barHeight = 8.0;
    final progressWidth = barWidth * _progress;

    return Container(
      width: barWidth,
      height: barHeight + 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(barHeight / 2),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Background bar
              Container(
                width: barWidth,
                height: barHeight,
                decoration: BoxDecoration(
                  color: AQColors.white.withOpacity(0.1),
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
                  child: Row(
                    children: [
                      // Blue segment (0-33%)
                      Expanded(
                        flex: 33,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AQColors.mBlue,
                            boxShadow: [
                              BoxShadow(
                                color: AQColors.mBlue.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Purple segment (33-66%)
                      Expanded(
                        flex: 34,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AQColors.mPurple,
                            boxShadow: [
                              BoxShadow(
                                color: AQColors.mPurple.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Red segment (66-100%)
                      Expanded(
                        flex: 33,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AQColors.mRed,
                            boxShadow: [
                              BoxShadow(
                                color: AQColors.mRed.withOpacity(0.5),
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
                  left: progressWidth - 10,
                  child: Container(
                    width: 20,
                    height: barHeight + 10,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: _getProgressColor().withOpacity(0.8),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get current progress color based on progress value
  Color _getProgressColor() {
    if (_progress <= 0.33) {
      return AQColors.mBlue;
    } else if (_progress <= 0.66) {
      return AQColors.mPurple;
    } else {
      return AQColors.mRed;
    }
  }
}
