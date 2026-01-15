import 'package:fluent_ui/fluent_ui.dart';

/// BMW Theme Colors and Styling
class BMWTheme {
  // BMW Brand Colors
  static const Color bmwBlue = Color(0xFF1C69D4);
  static const Color bmwDarkBlue = Color(0xFF0653B6);
  static const Color bmwLightBlue = Color(0xFF4A90D9);
  static const Color bmwBlack = Color(0xFF1A1A1A);
  static const Color bmwGray = Color(0xFF2D2D2D);
  static const Color bmwLightGray = Color(0xFF4A4A4A);
  static const Color bmwWhite = Color(0xFFFFFFFF);
  static const Color bmwRed = Color(0xFFE31937);
  static const Color bmwGreen = Color(0xFF00A651);
  static const Color bmwOrange = Color(0xFFFF6B00);

  // M Performance Colors
  static const Color mBlue = Color(0xFF0066B1);
  static const Color mRed = Color(0xFFE31937);
  static const Color mPurple = Color(0xFF5C2D91);

  // Gradients
  static LinearGradient get bmwGradient => const LinearGradient(
    colors: [bmwBlue, bmwDarkBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get mGradient => const LinearGradient(
    colors: [mBlue, mRed, mPurple],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static FluentThemeData get dark {
    return FluentThemeData(
      brightness: Brightness.dark,
      accentColor: AccentColor.swatch({
        'darkest': bmwDarkBlue,
        'darker': bmwDarkBlue,
        'dark': bmwBlue,
        'normal': bmwBlue,
        'light': bmwLightBlue,
        'lighter': bmwLightBlue,
        'lightest': bmwLightBlue,
      }),
      scaffoldBackgroundColor: bmwBlack,
      cardColor: bmwGray,
      menuColor: bmwGray,
      micaBackgroundColor: bmwBlack,
      activeColor: bmwBlue,
      inactiveColor: bmwLightGray,
      typography: Typography.fromBrightness(
        brightness: Brightness.dark,
        color: bmwWhite,
      ),
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: bmwBlack,
        highlightColor: bmwBlue,
        selectedIconColor: WidgetStateProperty.all(bmwWhite),
        unselectedIconColor: WidgetStateProperty.all(bmwLightGray),
        selectedTextStyle: WidgetStateProperty.all(
          const TextStyle(color: bmwWhite, fontWeight: FontWeight.w600),
        ),
        unselectedTextStyle: WidgetStateProperty.all(
          const TextStyle(color: bmwLightGray),
        ),
      ),
      buttonTheme: ButtonThemeData(
        defaultButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return bmwDarkBlue;
            if (states.contains(WidgetState.hovered)) return bmwLightBlue;
            return bmwBlue;
          }),
          foregroundColor: WidgetStateProperty.all(bmwWhite),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
        filledButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return bmwDarkBlue;
            if (states.contains(WidgetState.hovered)) return bmwLightBlue;
            return bmwBlue;
          }),
          foregroundColor: WidgetStateProperty.all(bmwWhite),
        ),
      ),
      iconTheme: const IconThemeData(color: bmwWhite, size: 20),
    );
  }

  static FluentThemeData get light {
    return FluentThemeData(
      brightness: Brightness.light,
      accentColor: AccentColor.swatch({
        'darkest': bmwDarkBlue,
        'darker': bmwDarkBlue,
        'dark': bmwBlue,
        'normal': bmwBlue,
        'light': bmwLightBlue,
        'lighter': bmwLightBlue,
        'lightest': bmwLightBlue,
      }),
      scaffoldBackgroundColor: const Color(0xFFF0F0F0), // Windows Light Gray
      cardColor: bmwWhite,
      menuColor: const Color(0xFFF5F5F5),
      micaBackgroundColor: const Color(0xFFF0F0F0),
      activeColor: bmwBlue,
      inactiveColor: bmwLightGray,
      typography: Typography.fromBrightness(
        brightness: Brightness.light,
        color: bmwBlack,
      ),
      navigationPaneTheme: NavigationPaneThemeData(
        backgroundColor: const Color(0xFFE0E0E0), // Sidebar Gray
        highlightColor: bmwBlue,
        selectedIconColor: WidgetStateProperty.all(bmwBlue),
        unselectedIconColor: WidgetStateProperty.all(bmwGray),
        selectedTextStyle: WidgetStateProperty.all(
          const TextStyle(color: bmwBlue, fontWeight: FontWeight.w700),
        ),
        unselectedTextStyle: WidgetStateProperty.all(
          const TextStyle(color: bmwGray, fontWeight: FontWeight.w500),
        ),
        itemHeaderTextStyle: const TextStyle(
          color: bmwGray,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      buttonTheme: ButtonThemeData(
        defaultButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return bmwDarkBlue;
            if (states.contains(WidgetState.hovered)) return bmwLightBlue;
            return bmwWhite; // White background for default buttons in light mode
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed) ||
                states.contains(WidgetState.hovered))
              return bmwWhite;
            return bmwBlue;
          }),
          shape: WidgetStateProperty.resolveWith((states) {
            final Color sideColor =
                (states.contains(WidgetState.pressed) ||
                    states.contains(WidgetState.hovered))
                ? bmwWhite
                : bmwBlue;
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: sideColor),
            );
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
        filledButtonStyle: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return bmwDarkBlue;
            if (states.contains(WidgetState.hovered)) return bmwLightBlue;
            return bmwBlue;
          }),
          foregroundColor: WidgetStateProperty.all(bmwWhite),
        ),
      ),
      iconTheme: const IconThemeData(color: bmwGray, size: 20),
    );
  }

  // M Stripes gradient
  static LinearGradient get mStripesGradient => const LinearGradient(
    colors: [mBlue, mPurple, mRed],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// Custom BMW-styled widgets
class BMWCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final IconData? icon;
  final EdgeInsets? padding;
  final VoidCallback? onTap;

  const BMWCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: BMWTheme.bmwGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BMWTheme.bmwLightGray.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: BMWTheme.bmwGradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: BMWTheme.bmwWhite, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      title!,
                      style: const TextStyle(
                        color: BMWTheme.bmwWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: padding ?? const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// M Stripes decoration widget
class MStripes extends StatelessWidget {
  final double height;

  const MStripes({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(gradient: BMWTheme.mStripesGradient),
    );
  }
}

/// BMW-styled progress indicator
class BMWProgressRing extends StatelessWidget {
  final double? value;
  final String? label;

  const BMWProgressRing({super.key, this.value, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressRing(
          value: value,
          strokeWidth: 4,
          activeColor: BMWTheme.bmwBlue,
          backgroundColor: BMWTheme.bmwLightGray,
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(
            label!,
            style: const TextStyle(color: BMWTheme.bmwWhite, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Status indicator widget
class StatusIndicator extends StatelessWidget {
  final bool isActive;
  final String label;

  const StatusIndicator({
    super.key,
    required this.isActive,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive ? BMWTheme.bmwGreen : BMWTheme.bmwRed,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isActive ? BMWTheme.bmwGreen : BMWTheme.bmwRed)
                    .withOpacity(0.5),
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
            color: isActive ? BMWTheme.bmwGreen : BMWTheme.bmwRed,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Branding footer widget
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
            style: TextStyle(color: BMWTheme.bmwLightGray, fontSize: 11),
          ),
          const Text(
            'M A coding',
            style: TextStyle(
              color: BMWTheme.bmwBlue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            ' • ',
            style: TextStyle(color: BMWTheme.bmwLightGray, fontSize: 11),
          ),
          const Text(
            'bmw-az.info',
            style: TextStyle(color: BMWTheme.bmwLightBlue, fontSize: 11),
          ),
          Text(
            ' • ',
            style: TextStyle(color: BMWTheme.bmwLightGray, fontSize: 11),
          ),
          const Text(
            'AQ///bimmer',
            style: TextStyle(
              color: BMWTheme.mRed,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
