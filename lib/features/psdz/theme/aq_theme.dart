import 'package:fluent_ui/fluent_ui.dart';
import 'dart:ui';
import 'dart:math';

/// AQ///PSDZ Theme - BMW Professional Style with Glass Morphism
/// Based on cheaTool visual identity by AQ///bimmer
class AQColors {
  // Primary Colors - BMW Style
  static const Color primaryBlue = Color(0xFF3b82f6);
  static const Color secondaryRed = Color(0xFFef4444);
  static const Color accentCyan = Color(0xFF00ffd0);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Background Colors - Dark Mode
  static const Color darkBackground = Color(0xFF1a1a2e);
  static const Color cardBackground = Color(0xFF16213e);
  static const Color surfaceBackground = Color(0xFF0f0f1a);
  static const Color glassBackground = Color(0x1AFFFFFF);

  // Background Colors - Light Mode (Classic Windows 98/2000 Style)
  static const Color lightBackground = Color(
    0xFFD4D0C8,
  ); // Classic Windows gray
  static const Color lightCardBackground = Color(0xFFFFFFFF); // White cards
  static const Color lightSurfaceBackground = Color(
    0xFFECE9D8,
  ); // Windows XP surface
  static const Color lightGlassBackground = Color(0x08000000); // Subtle overlay
  static const Color lightBorder = Color(0xFF808080); // Windows border
  static const Color lightNavBackground = Color(
    0xFFECE9D8,
  ); // Nav pane (XP style)
  static const Color lightHighlight = Color(0xFF316AC5); // Windows XP highlight
  static const Color lightButtonFace = Color(0xFFD4D0C8); // Button face

  // BMW M Colors
  static const Color mBlue = Color(0xFF0066B1);
  static const Color mRed = Color(0xFFE31937);
  static const Color mPurple = Color(0xFF5C2D91);

  // Status Colors
  static const Color success = Color(0xFF10b981);
  static const Color warning = Color(0xFFf59e0b);
  static const Color error = Color(0xFFef4444);
  static const Color info = Color(0xFF3b82f6);

  // Text Colors - Dark Mode
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFa0aec0);
  static const Color textMuted = Color(0xFF718096);

  // Text Colors - Light Mode (Classic Windows style - high contrast)
  static const Color lightTextPrimary = Color(0xFF000000); // Pure black
  static const Color lightTextSecondary = Color(0xFF1A1A1A); // Near black
  static const Color lightTextMuted = Color(0xFF404040); // Dark gray
  static const Color lightTextLink = Color(0xFF0000FF); // Classic blue link

  // Gradients
  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryBlue, Color(0xFF2563eb)],
      );

  static LinearGradient get accentGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accentCyan, Color(0xFF06b6d4)],
      );

  static LinearGradient get glassGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [white.withOpacity(0.1), white.withOpacity(0.05)],
      );

  static LinearGradient get mStripesGradient => const LinearGradient(
        colors: [mBlue, mPurple, mRed],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  static RadialGradient get backgroundGlow => RadialGradient(
        center: Alignment.center,
        radius: 1.5,
        colors: [
          primaryBlue.withOpacity(0.15),
          darkBackground,
          surfaceBackground
        ],
      );

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: primaryBlue.withOpacity(0.3),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ];

  static List<BoxShadow> glowShadowColor(Color color) => [
        BoxShadow(
            color: color.withOpacity(0.4), blurRadius: 15, spreadRadius: 2),
      ];
}

/// AQ Theme for Fluent UI
class AQTheme {
  static FluentThemeData get dark {
    return FluentThemeData(
      brightness: Brightness.dark,
      accentColor: AccentColor.swatch({
        'darkest': const Color(0xFF1d4ed8),
        'darker': const Color(0xFF2563eb),
        'dark': AQColors.primaryBlue,
        'normal': AQColors.primaryBlue,
        'light': const Color(0xFF60a5fa),
        'lighter': const Color(0xFF93c5fd),
        'lightest': const Color(0xFFbfdbfe),
      }),
      scaffoldBackgroundColor: AQColors.darkBackground,
      cardColor: AQColors.cardBackground,
      menuColor: AQColors.cardBackground,
      micaBackgroundColor: AQColors.surfaceBackground,
      activeColor: AQColors.primaryBlue,
      inactiveColor: AQColors.textMuted,
      typography: Typography.fromBrightness(
        brightness: Brightness.dark,
        color: AQColors.textPrimary,
      ),
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: AQColors.surfaceBackground,
        highlightColor: AQColors.primaryBlue,
        selectedIconColor: WidgetStateProperty.all(AQColors.accentCyan),
        unselectedIconColor: WidgetStateProperty.all(AQColors.textSecondary),
        selectedTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: AQColors.accentCyan,
            fontWeight: FontWeight.w600,
          ),
        ),
        unselectedTextStyle: WidgetStateProperty.all(
          const TextStyle(color: AQColors.textSecondary),
        ),
      ),
      buttonTheme: ButtonThemeData(
        defaultButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AQColors.primaryBlue.withOpacity(0.8);
            }
            if (states.contains(WidgetState.hovered)) {
              return AQColors.primaryBlue.withOpacity(0.9);
            }
            return AQColors.primaryBlue;
          }),
          foregroundColor: WidgetStateProperty.all(AQColors.white),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        filledButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AQColors.primaryBlue.withOpacity(0.8);
            }
            if (states.contains(WidgetState.hovered)) {
              return AQColors.primaryBlue.withOpacity(0.9);
            }
            return AQColors.primaryBlue;
          }),
          foregroundColor: WidgetStateProperty.all(AQColors.white),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: AQColors.textPrimary, size: 20),
    );
  }

  /// Light Theme - E-Sys Ultra inspired
  static FluentThemeData get light {
    return FluentThemeData(
      brightness: Brightness.light,
      accentColor: AccentColor.swatch({
        'darkest': const Color(0xFF1d4ed8),
        'darker': const Color(0xFF2563eb),
        'dark': AQColors.primaryBlue,
        'normal': AQColors.primaryBlue,
        'light': const Color(0xFF60a5fa),
        'lighter': const Color(0xFF93c5fd),
        'lightest': const Color(0xFFbfdbfe),
      }),
      scaffoldBackgroundColor: AQColors.lightBackground,
      cardColor: AQColors.lightCardBackground,
      menuColor: AQColors.lightCardBackground,
      micaBackgroundColor: AQColors.lightSurfaceBackground,
      activeColor: AQColors.lightHighlight,
      inactiveColor: AQColors.lightTextMuted,
      typography: Typography.fromBrightness(
        brightness: Brightness.light,
        color: AQColors.lightTextPrimary,
      ),
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: AQColors.lightNavBackground,
        highlightColor: AQColors.lightHighlight,
        selectedIconColor: WidgetStateProperty.all(AQColors.lightHighlight),
        unselectedIconColor: WidgetStateProperty.all(AQColors.lightTextPrimary),
        selectedTextStyle: WidgetStateProperty.all(
          const TextStyle(
            color: AQColors.lightHighlight,
            fontWeight: FontWeight.w600,
          ),
        ),
        unselectedTextStyle: WidgetStateProperty.all(
          const TextStyle(color: AQColors.lightTextPrimary),
        ),
      ),
      buttonTheme: ButtonThemeData(
        defaultButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AQColors.lightHighlight.withOpacity(0.9);
            }
            if (states.contains(WidgetState.hovered)) {
              return AQColors.lightHighlight;
            }
            return AQColors.lightButtonFace;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return AQColors.white;
            }
            return AQColors.lightTextPrimary;
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        filledButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return AQColors.lightHighlight.withOpacity(0.8);
            }
            if (states.contains(WidgetState.hovered)) {
              return AQColors.lightHighlight.withOpacity(0.9);
            }
            return AQColors.lightHighlight;
          }),
          foregroundColor: WidgetStateProperty.all(AQColors.white),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AQColors.lightTextPrimary,
        size: 18,
      ),
    );
  }
}

/// Glass Card Widget with blur effect (Light/Dark mode aware)
class GlassCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double blur;
  final double borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;

  /// If true, the child will be wrapped in Expanded (use when inside bounded Column/Row).
  /// If false, content will shrink-wrap (use in scrollable/unbounded contexts).
  /// Default is true for backward compatibility.
  final bool expand;

  const GlassCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.padding,
    this.margin,
    this.blur = 10,
    this.borderRadius = 12,
    this.borderColor,
    this.onTap,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      margin: margin,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isDark ? borderRadius : 4),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: isDark ? blur : 0,
              sigmaY: isDark ? blur : 0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? null : AQColors.lightCardBackground,
                gradient: isDark ? AQColors.glassGradient : null,
                borderRadius: BorderRadius.circular(isDark ? borderRadius : 4),
                border: Border.all(
                  color: borderColor ??
                      (isDark
                          ? AQColors.white.withOpacity(0.1)
                          : AQColors.lightBorder),
                  width: isDark ? 1 : 1.5,
                ),
                boxShadow: isDark
                    ? AQColors.cardShadow
                    : [
                        // Classic Windows 3D effect
                        BoxShadow(
                          color: Colors.white,
                          offset: const Offset(-1, -1),
                          blurRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(0xFF808080),
                          offset: const Offset(1, 1),
                          blurRadius: 0,
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (title != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? null : AQColors.lightSurfaceBackground,
                        gradient: isDark ? AQColors.primaryGradient : null,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(isDark ? borderRadius - 1 : 3),
                        ),
                        border: isDark
                            ? null
                            : const Border(
                                bottom: BorderSide(color: AQColors.lightBorder),
                              ),
                      ),
                      child: Row(
                        children: [
                          if (icon != null) ...[
                            Icon(
                              icon,
                              color: isDark ? AQColors.white : AQColors.mBlue,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              title!,
                              style: TextStyle(
                                color: isDark
                                    ? AQColors.white
                                    : AQColors.lightTextPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  expand
                      ? Expanded(
                          child: Padding(
                            padding: padding ?? const EdgeInsets.all(10),
                            child: child,
                          ),
                        )
                      : Padding(
                          padding: padding ?? const EdgeInsets.all(10),
                          child: child,
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass Button with 3D hover effect
class GlassButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final bool isLoading;
  final double? width;
  final double height;

  const GlassButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.color,
    this.textColor,
    this.isLoading = false,
    this.width,
    this.height = 48,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? AQColors.primaryBlue;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withOpacity(0.3 * _glowAnimation.value),
                    blurRadius: 20 * _glowAnimation.value,
                    spreadRadius: 2 * _glowAnimation.value,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: GestureDetector(
              onTap: widget.isLoading ? null : widget.onPressed,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      buttonColor.withOpacity(_isHovered ? 0.9 : 0.8),
                      buttonColor.withOpacity(_isHovered ? 0.7 : 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AQColors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: ProgressRing(
                            strokeWidth: 2,
                            activeColor: AQColors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: widget.textColor ?? AQColors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              widget.text,
                              style: TextStyle(
                                color: widget.textColor ?? AQColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass Icon Button
class GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 40,
    this.tooltip,
  });

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? AQColors.primaryBlue;

    Widget button = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isHovered
              ? buttonColor.withOpacity(0.3)
              : AQColors.glassBackground,
          border: Border.all(
            color: _isHovered
                ? buttonColor.withOpacity(0.5)
                : AQColors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: _isHovered ? AQColors.glowShadowColor(buttonColor) : null,
        ),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Center(
            child: Icon(
              widget.icon,
              color: _isHovered ? buttonColor : AQColors.textSecondary,
              size: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Glass TextField
class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final String? header;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? maxLines;

  const GlassTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.header,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          Text(
            header!,
            style: const TextStyle(
              color: AQColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AQColors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: TextBox(
                controller: controller,
                placeholder: placeholder,
                obscureText: obscureText,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                maxLines: maxLines,
                prefix: prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Icon(
                          prefixIcon,
                          color: AQColors.textSecondary,
                          size: 18,
                        ),
                      )
                    : null,
                suffix: suffix,
                style: const TextStyle(color: AQColors.textPrimary),
                placeholderStyle: TextStyle(
                  color: AQColors.textMuted.withOpacity(0.5),
                ),
                decoration: WidgetStateProperty.all(
                  BoxDecoration(
                    color: AQColors.cardBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Glass Chip
class GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? selectedColor;

  const GlassChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AQColors.primaryBlue;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.3) : AQColors.glassBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AQColors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: selected ? AQColors.glowShadowColor(color) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AQColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Glass Progress Indicator
class GlassProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;
  final bool showBMWStripes;

  const GlassProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.color,
    this.showBMWStripes = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AQColors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: height,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: showBMWStripes
                          ? AQColors.mStripesGradient
                          : (color != null
                              ? LinearGradient(colors: [color!, color!])
                              : AQColors.primaryGradient),
                      borderRadius: BorderRadius.circular(height / 2),
                      boxShadow: [
                        BoxShadow(
                          color: (color ?? AQColors.primaryBlue).withOpacity(
                            0.5,
                          ),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// M Stripes decoration
class MStripes extends StatelessWidget {
  final double height;

  const MStripes({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: AQColors.mStripesGradient,
        boxShadow: [
          BoxShadow(color: AQColors.mPurple.withOpacity(0.3), blurRadius: 8),
        ],
      ),
    );
  }
}

/// Status Indicator
class StatusIndicator extends StatelessWidget {
  final bool isActive;
  final String label;
  final double size;

  const StatusIndicator({
    super.key,
    required this.isActive,
    required this.label,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AQColors.success : AQColors.error;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// AQ Branding Widget
class AQBranding extends StatelessWidget {
  final String suffix;
  final double fontSize;

  const AQBranding({super.key, this.suffix = 'PSDZ', this.fontSize = 24});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AQ',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: AQColors.primaryBlue,
          ),
        ),
        Text(
          '///',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: AQColors.white.withOpacity(0.9),
          ),
        ),
        Text(
          suffix,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: AQColors.secondaryRed,
          ),
        ),
      ],
    );
  }
}

/// Branding Footer
class BrandingFooter extends StatelessWidget {
  const BrandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Designed by ',
            style: TextStyle(color: AQColors.textMuted, fontSize: 11),
          ),
          const Text(
            'M A coding',
            style: TextStyle(
              color: AQColors.primaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            ' • ',
            style: TextStyle(color: AQColors.textMuted, fontSize: 11),
          ),
          const Text(
            'bmw-az.info',
            style: TextStyle(color: AQColors.accentCyan, fontSize: 11),
          ),
          Text(
            ' • ',
            style: TextStyle(color: AQColors.textMuted, fontSize: 11),
          ),
          const Text(
            'AQ',
            style: TextStyle(
              color: AQColors.primaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '///',
            style: TextStyle(
              color: AQColors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'bimmer',
            style: TextStyle(
              color: AQColors.secondaryRed,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid Pattern Painter for glass backgrounds
class GridPatternPainter extends CustomPainter {
  final Color color;
  final double spacing;

  GridPatternPainter({this.color = const Color(0x05FFFFFF), this.spacing = 40});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper function to show a dialog with FluentTheme properly wrapped
/// This fixes the "A FluentTheme widget is necessary to draw this layout" error
Future<T?> showFluentDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
}) {
  final theme = FluentTheme.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => FluentTheme(
      data: theme,
      child: builder(ctx),
    ),
  );
}
