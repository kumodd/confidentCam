import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global design tokens supporting both Light and Dark themes
/// (auto-selected from the system theme).
class AppColors {
  AppColors._();

  static bool _isDark = false;
  static bool get isDark => _isDark;

  static void setDark(bool value) {
    _isDark = value;
  }

  // Light Palette (Reference Benchmark)
  static const Color lightBackground = Color(0xFFF7F8F0);
  static const Color lightCardSurface = Color(0xFFECEFE5);
  static const Color lightCardSurfaceElevated = Color(0xFFE3E7DA);
  static const Color lightInputSurface = Color(0xFFE6EAE0);
  static const Color lightPrimaryOlive = Color(0xFF74712E);
  static const Color lightPrimaryOliveLight = Color(0xFF8C8940);
  static const Color lightOlivePillFill = Color(0xFFE6E8D6);
  static const Color lightOlivePillBorder = Color(0xFFB5B48B);
  static const Color lightArcTrack = Color(0xFFE0E4D9);
  static const Color lightSecondaryGreen = Color(0xFF386B45);
  static const Color lightNavPill = Color(0xFFD5E6D6);
  static const Color lightSoftGreenTint = Color(0xFFDCEAD9);
  static const Color lightPrimaryText = Color(0xFF191C19);
  static const Color lightSecondaryText = Color(0xFF555B52);
  static const Color lightMutedText = Color(0xFF92978D);
  static const Color lightDivider = Color(0xFFDCE1D5);
  static const Color lightSubtleBorder = Color(0xFFD5DBD0);
  static const Color lightSuccess = Color(0xFF39734A);
  static const Color lightError = Color(0xFFB52D2D);
  static const Color lightErrorTint = Color(0xFFF5E4E4);
  static const Color lightWarning = Color(0xFF8F6B24);

  // Dark Palette (Harmonious Sage & Olive Dark Mode)
  static const Color darkBackground = Color(0xFF121512);
  static const Color darkCardSurface = Color(0xFF1C211C);
  static const Color darkCardSurfaceElevated = Color(0xFF242A24);
  static const Color darkInputSurface = Color(0xFF171B17);
  static const Color darkPrimaryOlive = Color(0xFFB8B45A);
  static const Color darkPrimaryOliveLight = Color(0xFFCBC770);
  static const Color darkOlivePillFill = Color(0xFF282A1D);
  static const Color darkOlivePillBorder = Color(0xFF5E5C38);
  static const Color darkArcTrack = Color(0xFF2A302A);
  static const Color darkSecondaryGreen = Color(0xFF66AD78);
  static const Color darkNavPill = Color(0xFF243829);
  static const Color darkSoftGreenTint = Color(0xFF1F3023);
  static const Color darkPrimaryText = Color(0xFFECEFE5);
  static const Color darkSecondaryText = Color(0xFFA8B0A4);
  static const Color darkMutedText = Color(0xFF737B70);
  static const Color darkDivider = Color(0xFF2B322B);
  static const Color darkSubtleBorder = Color(0xFF313931);
  static const Color darkSuccess = Color(0xFF58A86D);
  static const Color darkError = Color(0xFFE05C5C);
  static const Color darkErrorTint = Color(0xFF361C1C);
  static const Color darkWarning = Color(0xFFC89B42);

  // Adaptive Getters
  static Color get background => _isDark ? darkBackground : lightBackground;
  static Color get cardSurface => _isDark ? darkCardSurface : lightCardSurface;
  static Color get cardSurfaceElevated =>
      _isDark ? darkCardSurfaceElevated : lightCardSurfaceElevated;
  static Color get inputSurface =>
      _isDark ? darkInputSurface : lightInputSurface;

  static Color get primaryOlive =>
      _isDark ? darkPrimaryOlive : lightPrimaryOlive;
  static Color get primaryOliveLight =>
      _isDark ? darkPrimaryOliveLight : lightPrimaryOliveLight;
  static Color get olivePillFill =>
      _isDark ? darkOlivePillFill : lightOlivePillFill;
  static Color get olivePillBorder =>
      _isDark ? darkOlivePillBorder : lightOlivePillBorder;
  static Color get arcTrack => _isDark ? darkArcTrack : lightArcTrack;

  static Color get secondaryGreen =>
      _isDark ? darkSecondaryGreen : lightSecondaryGreen;
  static Color get navPill => _isDark ? darkNavPill : lightNavPill;
  static Color get softGreenTint =>
      _isDark ? darkSoftGreenTint : lightSoftGreenTint;

  static Color get primaryText => _isDark ? darkPrimaryText : lightPrimaryText;
  static Color get secondaryText =>
      _isDark ? darkSecondaryText : lightSecondaryText;
  static Color get mutedText => _isDark ? darkMutedText : lightMutedText;

  static Color get divider => _isDark ? darkDivider : lightDivider;
  static Color get subtleBorder =>
      _isDark ? darkSubtleBorder : lightSubtleBorder;

  static Color get success => _isDark ? darkSuccess : lightSuccess;
  static Color get error => _isDark ? darkError : lightError;
  static Color get errorTint => _isDark ? darkErrorTint : lightErrorTint;
  static Color get warning => _isDark ? darkWarning : lightWarning;
}

class AppRadii {
  AppRadii._();

  static const double card = 24.0;
  static const double cardLarge = 28.0;
  static const double button = 18.0;
  static const double input = 18.0;
  static const double pill = 999.0;

  static BorderRadius get cardBorder => BorderRadius.circular(card);
  static BorderRadius get cardLargeBorder => BorderRadius.circular(cardLarge);
  static BorderRadius get buttonBorder => BorderRadius.circular(button);
  static BorderRadius get inputBorder => BorderRadius.circular(input);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppTypography {
  AppTypography._();

  static TextStyle displayMetric({
    double fontSize = 52,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: color ?? AppColors.primaryText,
      letterSpacing: -1.5,
      height: 1.05,
    );
  }

  static TextStyle headingLarge({
    double fontSize = 26,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? AppColors.primaryText,
      letterSpacing: -0.5,
    );
  }

  static TextStyle headingMedium({
    double fontSize = 20,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? AppColors.primaryText,
      letterSpacing: -0.3,
    );
  }

  static TextStyle sectionTitle({
    double fontSize = 17,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? AppColors.primaryText,
      letterSpacing: -0.2,
    );
  }

  static TextStyle metricValue({
    double fontSize = 23,
    Color? color,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      color: color ?? AppColors.primaryText,
      letterSpacing: -0.4,
    );
  }

  static TextStyle uppercaseLabel({
    double fontSize = 11.5,
    Color? color,
    double letterSpacing = 1.6,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.secondaryText,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double fontSize = 14.5,
    Color? color,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.secondaryText,
      height: 1.45,
    );
  }

  static TextStyle bodyStrong({
    double fontSize = 15,
    Color? color,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.primaryText,
      height: 1.4,
    );
  }
}

class AppTheme {
  AppTheme._();

  static SystemUiOverlayStyle get systemOverlayStyle =>
      AppColors.isDark ? darkSystemOverlayStyle : lightSystemOverlayStyle;

  static const SystemUiOverlayStyle lightSystemOverlayStyle =
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.lightCardSurface,
        systemNavigationBarIconBrightness: Brightness.dark,
      );

  static const SystemUiOverlayStyle darkSystemOverlayStyle =
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.darkCardSurface,
        systemNavigationBarIconBrightness: Brightness.light,
      );

  static ThemeData get lightTheme => _buildTheme(isDark: false);
  static ThemeData get darkTheme => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final card =
        isDark ? AppColors.darkCardSurface : AppColors.lightCardSurface;
    final olive =
        isDark ? AppColors.darkPrimaryOlive : AppColors.lightPrimaryOlive;
    final green =
        isDark ? AppColors.darkSecondaryGreen : AppColors.lightSecondaryGreen;
    final textPrimary =
        isDark ? AppColors.darkPrimaryText : AppColors.lightPrimaryText;
    final textSecondary =
        isDark ? AppColors.darkSecondaryText : AppColors.lightSecondaryText;
    final textMuted =
        isDark ? AppColors.darkMutedText : AppColors.lightMutedText;
    final div = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final err = isDark ? AppColors.darkError : AppColors.lightError;
    final pill = isDark ? AppColors.darkNavPill : AppColors.lightNavPill;
    final onPrimaryColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final base = ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      primaryColor: olive,
      canvasColor: bg,
      cardColor: card,
      dividerColor: div,
      colorScheme: (isDark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
            primary: olive,
            onPrimary: onPrimaryColor,
            secondary: green,
            onSecondary: onPrimaryColor,
            tertiary: olive,
            surface: card,
            onSurface: textPrimary,
            error: err,
            onError: Colors.white,
            outline: div,
          ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: AppTypography.displayMetric(color: textPrimary),
        headlineLarge: AppTypography.headingLarge(color: textPrimary),
        headlineMedium: AppTypography.headingMedium(color: textPrimary),
        titleLarge: AppTypography.headingMedium(
          fontSize: 19,
          color: textPrimary,
        ),
        titleMedium: AppTypography.sectionTitle(color: textPrimary),
        bodyLarge: AppTypography.body(fontSize: 16, color: textPrimary),
        bodyMedium: AppTypography.body(color: textSecondary),
        bodySmall: AppTypography.body(fontSize: 12.5, color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle:
            isDark ? darkSystemOverlayStyle : lightSystemOverlayStyle,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 23),
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardBorder),
      ),
      dividerTheme: DividerThemeData(
        color: div,
        thickness: 1.2,
        space: 1.2,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: olive,
          foregroundColor: onPrimaryColor,
          disabledBackgroundColor: div,
          disabledForegroundColor: textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonBorder),
          textStyle: GoogleFonts.manrope(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          backgroundColor: card,
          side: BorderSide(color: div, width: 1.3),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.buttonBorder),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green,
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14.5),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14.5),
        border: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(color: div, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(color: div, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(color: olive, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(color: err, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputBorder,
          borderSide: BorderSide(color: err, width: 1.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardLargeBorder,
          side: BorderSide(color: div, width: 1.2),
        ),
        titleTextStyle: AppTypography.headingMedium(
          fontSize: 20,
          color: textPrimary,
        ),
        contentTextStyle: AppTypography.body(color: textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(
          color: bg,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: pill,
        disabledColor: div,
        side: BorderSide(color: div),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return green;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(bg),
        side: BorderSide(color: textSecondary, width: 1.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: olive,
        linearTrackColor: div,
        circularTrackColor: div,
      ),
    );
  }
}

/// Standard rounded sage card surface (`24px` radius, zero shadow).
class SageCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  const SageCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = AppRadii.card,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardSurface,
        borderRadius: radius,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.3)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Reference-style 2-column metric/action card.
class SageMetricCard extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showWaveAccent;
  final Color? waveColor;

  const SageMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.valueColor,
    this.subtitle,
    this.onTap,
    this.showWaveAccent = false,
    this.waveColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? AppColors.secondaryGreen;
    final resolvedValueColor = valueColor ?? AppColors.primaryText;
    final radius = BorderRadius.circular(AppRadii.card);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Stack(
            children: [
              if (showWaveAccent)
                Positioned.fill(
                  top: 32,
                  child: CustomPaint(
                    painter: _SubtleWavePainter(
                      color: (waveColor ?? resolvedIconColor)
                          .withValues(alpha: 0.35),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
                    child: Row(
                      children: [
                        Icon(icon, size: 19, color: resolvedIconColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label.toUpperCase(),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.uppercaseLabel(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!showWaveAccent)
                    Container(
                      height: 1.5,
                      width: double.infinity,
                      color: AppColors.divider,
                    )
                  else
                    const SizedBox(height: 1.5),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 14, 15),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  value,
                                  maxLines: 1,
                                  style: AppTypography.metricValue(
                                    fontSize: 21,
                                    color: resolvedValueColor,
                                  ),
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                    fontSize: 11.5,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.secondaryText,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtleWavePainter extends CustomPainter {
  final Color color;

  const _SubtleWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.16),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);

    final path = Path();
    final midY = size.height * 0.42;
    path.moveTo(0, midY - 6);
    path.cubicTo(
      size.width * 0.18,
      midY + 14,
      size.width * 0.32,
      midY - 12,
      size.width * 0.50,
      midY + 4,
    );
    path.cubicTo(
      size.width * 0.68,
      midY + 16,
      size.width * 0.82,
      midY - 10,
      size.width,
      midY + 2,
    );

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SubtleWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Reference-style status banner card (`"Monitoring Active"` pattern).
class SageStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onActionTap;
  final Color? statusDotColor;

  const SageStatusCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    this.onActionTap,
    this.statusDotColor,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = statusDotColor ?? AppColors.secondaryGreen;
    return SageCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      onTap: onActionTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.sectionTitle(fontSize: 16.5),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.body(
                    fontSize: 13.5,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            actionLabel,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Signature open circular olive arc gauge from the reference screenshot.
class OliveArcGauge extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String primaryValue;
  final String primaryUnit;
  final String statusLabel;
  final String pillText;
  final VoidCallback? onTap;
  final double size;

  const OliveArcGauge({
    super.key,
    required this.progress,
    required this.primaryValue,
    this.primaryUnit = '%',
    required this.statusLabel,
    required this.pillText,
    this.onTap,
    this.size = 280,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size * 0.90,
        child: CustomPaint(
          painter: _OliveArcPainter(
            progress: progress.clamp(0.0, 1.0),
            activeColor: AppColors.primaryOlive,
            trackColor: AppColors.arcTrack,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(36, 10, 36, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          primaryValue,
                          style: AppTypography.displayMetric(fontSize: 52),
                        ),
                        if (primaryUnit.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Text(
                              primaryUnit,
                              style: GoogleFonts.manrope(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryOlive,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      statusLabel.toUpperCase(),
                      style: AppTypography.uppercaseLabel(
                        fontSize: 11.5,
                        color: AppColors.primaryText,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.olivePillFill,
                      borderRadius: AppRadii.pillBorder,
                      border: Border.all(
                        color: AppColors.olivePillBorder,
                        width: 1.1,
                      ),
                    ),
                    child: Text(
                      pillText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryOlive,
                      ),
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

class _OliveArcPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;

  const _OliveArcPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 17.0;
    final center = Offset(size.width / 2, size.height * 0.54);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth + 4;

    const startAngle = 145 * (math.pi / 180);
    const sweepAngle = 250 * (math.pi / 180);

    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    final activeSweep = sweepAngle * (progress <= 0.05 ? 0.08 : progress);
    canvas.drawArc(rect, startAngle, activeSweep, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _OliveArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.trackColor != trackColor;
}

/// Olive pill badge matching the reference screenshot.
class OlivePillBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;

  const OlivePillBadge({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? AppColors.primaryOlive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.olivePillFill,
        borderRadius: AppRadii.pillBorder,
        border: Border.all(
          color: borderColor ?? AppColors.olivePillBorder,
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uppercase section header with letter spacing.
class SageSectionHeader extends StatelessWidget {
  final String title;
  final String? trailingText;
  final VoidCallback? onTrailingTap;
  final EdgeInsetsGeometry padding;

  const SageSectionHeader({
    super.key,
    required this.title,
    this.trailingText,
    this.onTrailingTap,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTypography.uppercaseLabel(
              fontSize: 11.5,
              color: AppColors.secondaryText,
              letterSpacing: 1.6,
            ),
          ),
          if (trailingText != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: Text(
                trailingText!,
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Minimal bottom navigation bar matching the reference screenshot.
class SageNavItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const SageNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

class SageBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<SageNavItem> items;

  const SageBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = index == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 62,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.navPill
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          isSelected
                              ? (item.activeIcon ?? item.icon)
                              : item.icon,
                          size: 22,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primaryText
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
