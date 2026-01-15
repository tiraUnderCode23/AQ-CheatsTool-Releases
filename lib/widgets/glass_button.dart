import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// A glass-morphism styled button widget
class GlassButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;

  const GlassButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 44,
    this.borderRadius = 10,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AQColors.accent;
    final fgColor = widget.textColor ?? Colors.black;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: widget.isOutlined
              ? null
              : LinearGradient(
                  colors: [
                    bgColor.withOpacity(_isHovered ? 0.9 : 0.8),
                    bgColor.withOpacity(_isHovered ? 0.7 : 0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: widget.isOutlined
                ? bgColor.withOpacity(_isHovered ? 0.8 : 0.5)
                : bgColor.withOpacity(0.3),
            width: widget.isOutlined ? 1.5 : 1,
          ),
          boxShadow: widget.isOutlined
              ? null
              : [
                  BoxShadow(
                    color: bgColor.withOpacity(_isHovered ? 0.4 : 0.2),
                    blurRadius: _isHovered ? 12 : 8,
                    spreadRadius: _isHovered ? 2 : 0,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.isOutlined ? bgColor : fgColor,
                      ),
                    )
                  else if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 18,
                      color: widget.isOutlined
                          ? bgColor.withOpacity(_isHovered ? 1 : 0.8)
                          : fgColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.text,
                    style: TextStyle(
                      color: widget.isOutlined
                          ? bgColor.withOpacity(_isHovered ? 1 : 0.8)
                          : fgColor,
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
    );
  }
}

/// Small action button for inline actions
class GlassActionButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const GlassActionButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.color,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AQColors.accent;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: buttonColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: buttonColor.withOpacity(0.3),
              ),
            ),
            child: Icon(
              icon,
              size: size * 0.5,
              color: buttonColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggle button with glass effect
class GlassToggleButton extends StatelessWidget {
  final bool isSelected;
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;

  const GlassToggleButton({
    super.key,
    required this.isSelected,
    required this.text,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AQColors.accent.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AQColors.accent : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isSelected ? AQColors.accent : Colors.white70,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                color: isSelected ? AQColors.accent : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
