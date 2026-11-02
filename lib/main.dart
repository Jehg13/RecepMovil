// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'dart:ui' as ui;

import 'package:gal/gal.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _red = Color(0xFFFF1538);
const _blue = Color(0xFF087FFF);
const _white = Color(0xFFF4F7FF);
const _mutedWhite = Color(0xFFD4DDF0);
const _welcomeDescriptionFirstLine = 'Registra tus visitas de forma rápida,';
const _logoArtworkWidthRatio = 0.764;

class _TabletLandscapeGuard extends StatelessWidget {
  const _TabletLandscapeGuard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;
    final isPortrait = size.height > size.width;

    if (!isTablet && isPortrait) return child;
    if (isTablet && isPortrait) {
      return _LandscapeOrientationPrompt(
        title: 'Voltea tu tablet',
        message: 'Colócala en horizontal para continuar.',
        child: child,
      );
    }
    if (!isTablet && !isPortrait) {
      return _LandscapeOrientationPrompt(
        title: 'Voltea tu celular',
        message: 'Colócalo en vertical para continuar.',
        child: child,
      );
    }

    return child;
  }
}

class _LandscapeOrientationPrompt extends StatelessWidget {
  const _LandscapeOrientationPrompt({
    required this.child,
    required this.title,
    required this.message,
  });

  final Widget child;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/tablet-welcome-login.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
        Container(color: const Color(0xD0060C1A)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF087FFF),
                        width: 2,
                      ),
                      color: const Color(0xCC07152B),
                    ),
                    child: const Icon(
                      Icons.screen_rotation_alt_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFCFD8EA),
                      fontSize: 17,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _tabletBackground(
  BuildContext context,
  String mobileAsset,
  String tabletAsset,
) {
  return MediaQuery.sizeOf(context).shortestSide >= 600
      ? tabletAsset
      : mobileAsset;
}

double responsivePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 900) return 32;
  if (width >= 600) return 24;
  return 14;
}

double responsiveContentWidth(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 900) return 900;
  if (width >= 600) return 720;
  return width;
}

double responsiveScale(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 900) return 1.12;
  if (width >= 600) return 1.08;
  return 1;
}

TextStyle _descriptionTextStyle(bool compact, {bool tablet = false}) =>
    TextStyle(
      color: _mutedWhite,
      fontSize: tablet ? 30 : (compact ? 13 : 15),
      height: 1.45,
      fontWeight: FontWeight.w400,
      fontFamily: 'Roboto',
      shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 12)],
    );

double _measureTextWidth(
  String text,
  TextStyle style,
  TextDirection direction,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    maxLines: 1,
  )..layout();
  return painter.width;
}

double _headlineFontSize(double targetWidth, TextDirection direction) {
  var low = 22.0;
  var high = 96.0;

  for (var attempt = 0; attempt < 16; attempt++) {
    final size = (low + high) / 2;
    final width = _measureTextWidth(
      'Bienvenido',
      TextStyle(
        fontSize: size,
        height: 1.1,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.5,
        fontFamily: 'Roboto',
      ),
      direction,
    );
    if (width > targetWidth) {
      high = size;
    } else {
      low = size;
    }
  }

  return low;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ReceptionApp());
}

class ReceptionApp extends StatelessWidget {
  const ReceptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CYMEZ Recepción',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF03091A),
        fontFamily: 'Roboto',
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF0D1730),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            return ColoredBox(
              color: const Color(0xFF03091A),
              child: Align(
                alignment: Alignment.topCenter,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      constraints.maxWidth >= 900
                          ? 1.12
                          : constraints.maxWidth >= 600
                          ? 1.08
                          : 1,
                    ),
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
      },
      home: const ReceptionWelcomePage(),
    );
  }
}

class ReceptionWelcomePage extends StatelessWidget {
  const ReceptionWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _TabletLandscapeGuard(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _tabletBackground(
                context,
                'assets/images/reception-welcome-background.webp',
                'assets/images/tablet-welcome-login.png',
              ),
              cacheWidth: 768,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tablet = constraints.maxWidth >= 600;
                  final compact =
                      !tablet &&
                      (constraints.maxHeight < 700 ||
                          constraints.maxWidth < 500);
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 20.0
                      : 28.0;
                  final contentWidth =
                      (constraints.maxWidth - horizontalPadding * 2).clamp(
                        0.0,
                        tablet ? 760.0 : 440.0,
                      );
                  final textDirection = Directionality.of(context);
                  final topPadding = compact ? 12.0 : 20.0;
                  final bottomPadding = compact ? 8.0 : 12.0;
                  final availableHeight =
                      constraints.maxHeight - topPadding - bottomPadding;
                  final heightBasedDescriptionLimit =
                      ((availableHeight - 350).clamp(0.0, 280.0)) * 1.146;
                  final measuredDescriptionWidth = _measureTextWidth(
                    _welcomeDescriptionFirstLine,
                    _descriptionTextStyle(compact),
                    textDirection,
                  );
                  final descriptionWidth = measuredDescriptionWidth.clamp(
                    0.0,
                    [
                      contentWidth < 320 ? contentWidth * 0.92 : 320.0,
                      heightBasedDescriptionLimit,
                    ].reduce((left, right) => left < right ? left : right),
                  );
                  final headlineFontSize = tablet
                      ? (constraints.maxHeight < 700
                            ? 58.0
                            : constraints.maxWidth >= 1200
                            ? 92.0
                            : 78.0)
                      : _headlineFontSize(descriptionWidth, textDirection);
                  final logoWidth = [
                    contentWidth,
                    tablet
                        ? constraints.maxWidth * 0.66
                        : descriptionWidth / _logoArtworkWidthRatio,
                  ].reduce((left, right) => left < right ? left : right);
                  final logoScale =
                      (descriptionWidth / (logoWidth * _logoArtworkWidthRatio))
                          .clamp(1.0, tablet ? 1.9 : 1.6);
                  final logoHeight = tablet
                      ? ((logoWidth / 1.65).clamp(
                          constraints.maxHeight < 700 ? 120.0 : 180.0,
                          constraints.maxHeight < 800
                              ? 220.0
                              : constraints.maxWidth >= 1200
                              ? 390.0
                              : 300.0,
                        )).clamp(120.0, 390.0)
                      : logoWidth / 1.5 * logoScale;
                  final benefitCardHeight = tablet
                      ? (contentWidth * 0.31).clamp(
                          constraints.maxHeight < 700 ? 82.0 : 150.0,
                          constraints.maxHeight < 700 ? 115.0 : 215.0,
                        )
                      : (contentWidth / 2.8).clamp(112.0, 148.0);
                  final contentHeight = availableHeight < 0
                      ? 0.0
                      : availableHeight;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      topPadding,
                      horizontalPadding,
                      bottomPadding,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: contentWidth,
                        height: contentHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, 10),
                              child: _WelcomeLogo(
                                height: logoHeight,
                                width: logoWidth,
                                scale: logoScale,
                              ),
                            ),
                            Transform.translate(
                              offset: Offset(0, tablet ? 0 : 10),
                              child: _WelcomeMessage(
                                compact: compact,
                                tablet: tablet,
                                headlineFontSize: headlineFontSize,
                              ),
                            ),
                            if (!tablet)
                              Center(
                                child: _WelcomeBenefits(
                                  height: benefitCardHeight,
                                ),
                              ),
                            if (tablet)
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: benefitCardHeight,
                                      child: _WelcomeBenefits(
                                        height: benefitCardHeight,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  SizedBox(
                                    width: 300,
                                    child: _StartButton(
                                      compact: compact,
                                      onStart: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const ReceptionOnboardingPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: _StartButton(
                                  compact: compact,
                                  onStart: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const ReceptionOnboardingPage(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (kIsWeb) const _WebHomeIndicator(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceptionOnboardingPage extends StatelessWidget {
  const ReceptionOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      body: _TabletLandscapeGuard(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tablet)
              Row(
                children: [
                  Expanded(
                    child: Image.asset(
                      'assets/images/onboarding-register-background.webp',
                      key: const ValueKey('tablet-onboarding-left-background'),
                      cacheWidth: 768,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                  Expanded(
                    child: Image.asset(
                      'assets/images/login-background.webp',
                      key: const ValueKey('tablet-onboarding-right-background'),
                      cacheWidth: 768,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ],
              )
            else
              Image.asset(
                'assets/images/onboarding-register-background.webp',
                cacheWidth: 768,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF03091A).withValues(alpha: 0.04),
                    Colors.transparent,
                    const Color(0xFF03091A).withValues(alpha: 0.3),
                    const Color(0xFF03091A).withValues(alpha: 0.62),
                  ],
                  stops: const [0, 0.4, 0.62, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  final veryCompact = constraints.maxHeight < 600;
                  final tablet = constraints.maxWidth >= 600;
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 18.0
                      : 38.0;
                  final contentWidth =
                      (constraints.maxWidth - horizontalPadding * 2).clamp(
                        0.0,
                        tablet ? constraints.maxWidth : 440.0,
                      );
                  final logoWidth = tablet
                      ? constraints.maxWidth * 0.16
                      : (contentWidth * 0.55).clamp(130.0, 175.0);
                  final logoHeight = veryCompact
                      ? 104.0
                      : compact
                      ? 132.0
                      : 148.0;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      veryCompact
                          ? 14
                          : compact
                          ? 22
                          : 30,
                      horizontalPadding,
                      veryCompact
                          ? 4
                          : compact
                          ? 8
                          : 12,
                    ),
                    child: tablet
                        ? _TabletRegistrationOnboardingLayout(
                            logoWidth: (constraints.maxWidth * 0.26)
                                .clamp(200.0, 340.0)
                                .toDouble(),
                            onContinue: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const ReceptionControlOnboardingPage(),
                                ),
                              );
                            },
                          )
                        : Column(
                            key: const ValueKey(
                              'mobile-registration-onboarding-layout',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: logoHeight,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Image.asset(
                                    'assets/images/cymez-reception-logo.webp',
                                    cacheWidth: 480,
                                    width: logoWidth,
                                    height: logoWidth / 1.5,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                              const Spacer(flex: 5),
                              _RegistrationOnboardingCopy(
                                compact: compact,
                                veryCompact: veryCompact,
                              ),
                              const Spacer(flex: 1),
                              Row(
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () {},
                                        style: TextButton.styleFrom(
                                          foregroundColor: _mutedWhite,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 12,
                                          ),
                                        ),
                                        child: const Text('Omitir'),
                                      ),
                                    ),
                                  ),
                                  _OnboardingContinueButton(
                                    compact: compact,
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const ReceptionControlOnboardingPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              SizedBox(height: compact ? 8 : 14),
                              const _PageIndicator(activeIndex: 0),
                              if (kIsWeb) const _WebHomeIndicator(),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletRegistrationOnboardingLayout extends StatelessWidget {
  const _TabletRegistrationOnboardingLayout({
    required this.logoWidth,
    required this.onContinue,
  });

  final double logoWidth;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Align(
              alignment: Alignment.topLeft,
              child: Image.asset(
                'assets/images/cymez-reception-logo.webp',
                key: const ValueKey('tablet-registration-onboarding-logo'),
                cacheWidth: 480,
                width: logoWidth,
                height: logoWidth / 1.5,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(44, 36, 32, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, copyConstraints) {
                      return Center(
                        key: const ValueKey('tablet-registration-copy-center'),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: copyConstraints.maxWidth,
                            child: _RegistrationOnboardingCopy(
                              compact: compact,
                              veryCompact: compact,
                              tablet: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: _mutedWhite,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 18,
                            ),
                          ),
                          child: const Text(
                            'Omitir',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const _PageIndicator(activeIndex: 0),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _OnboardingContinueButton(
                          compact: false,
                          onPressed: onContinue,
                        ),
                      ),
                    ],
                  ),
                ),
                if (kIsWeb) const _WebHomeIndicator(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationOnboardingCopy extends StatelessWidget {
  const _RegistrationOnboardingCopy({
    required this.compact,
    required this.veryCompact,
    this.tablet = false,
  });

  final bool compact;
  final bool veryCompact;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: _white,
      fontSize: tablet
          ? compact
                ? 62
                : 78
          : veryCompact
          ? 32
          : compact
          ? 35
          : 40,
      height: 1.08,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
    );

    return Column(
      key: tablet ? const ValueKey('tablet-registration-copy') : null,
      mainAxisSize: tablet ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: tablet
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (tablet) ...[
          Container(
            key: const ValueKey('tablet-onboarding-step-number'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [_red, _blue]),
              border: Border.all(color: const Color(0x99FFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x884A72FF),
                  blurRadius: 20,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Text(
              '01',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(
          'Registra tus',
          textAlign: tablet ? TextAlign.center : TextAlign.start,
          style: titleStyle,
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              const LinearGradient(colors: [_blue, _red]).createShader(bounds),
          child: Text(
            'visitas',
            textAlign: tablet ? TextAlign.center : TextAlign.start,
            style: titleStyle.copyWith(
              fontSize: tablet
                  ? compact
                        ? 70
                        : 86
                  : veryCompact
                  ? 36
                  : compact
                  ? 42
                  : 48,
            ),
          ),
        ),
        SizedBox(
          height: veryCompact
              ? 6
              : compact
              ? 8
              : 10,
        ),
        Text(
          'Entrada de visitantes',
          textAlign: tablet ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: const Color(0xFF36BFFF),
            fontSize: tablet
                ? compact
                      ? 28
                      : 34
                : veryCompact
                ? 15
                : compact
                ? 16
                : 18,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
          ),
        ),
        SizedBox(
          height: veryCompact
              ? 8
              : compact
              ? 10
              : 14,
        ),
        Text(
          'Registra cada ingreso fácilmente y mantén la información de tus visitantes organizada.',
          textAlign: tablet ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: _white,
            fontSize: tablet
                ? compact
                      ? 24
                      : 28
                : veryCompact
                ? 14
                : compact
                ? 15
                : 17,
            height: 1.45,
            shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
          ),
        ),
      ],
    );
  }
}

class ReceptionControlOnboardingPage extends StatelessWidget {
  const ReceptionControlOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _TabletLandscapeGuard(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _tabletBackground(
                context,
                'assets/images/onboarding-control-background.webp',
                'assets/images/tablet-onboarding-2.png',
              ),
              cacheWidth: 768,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0xFF03091A).withValues(alpha: 0.24),
                    const Color(0xFF03091A).withValues(alpha: 0.72),
                  ],
                  stops: const [0, 0.46, 0.64, 1],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxHeight < 700 || constraints.maxWidth < 500;
                  final veryCompact = constraints.maxHeight < 600;
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 18.0
                      : 24.0;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      veryCompact
                          ? 14
                          : compact
                          ? 22
                          : 30,
                      horizontalPadding,
                      veryCompact
                          ? 4
                          : compact
                          ? 8
                          : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Image.asset(
                            'assets/images/cymez-reception-logo.webp',
                            cacheWidth: 480,
                            width: compact ? 170 : 190,
                            height: compact ? 40 : 127,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const Spacer(flex: 5),
                        const _ControlOnboardingCopy(),
                        const Spacer(flex: 1),
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    foregroundColor: _mutedWhite,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Omitir'),
                                ),
                              ),
                            ),
                            _OnboardingContinueButton(
                              compact: compact,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const ReceptionReadyOnboardingPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 8 : 14),
                        const _PageIndicator(activeIndex: 1),
                        if (kIsWeb) const _WebHomeIndicator(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceptionReadyOnboardingPage extends StatelessWidget {
  const ReceptionReadyOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _TabletLandscapeGuard(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _tabletBackground(
                context,
                'assets/images/onboarding-ready-background.webp',
                'assets/images/tablet-onboarding-3.png',
              ),
              cacheWidth: 768,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  final veryCompact = constraints.maxHeight < 600;
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 18.0
                      : 24.0;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      veryCompact
                          ? 12
                          : compact
                          ? 18
                          : 24,
                      horizontalPadding,
                      veryCompact
                          ? 4
                          : compact
                          ? 8
                          : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: Image.asset(
                            'assets/images/cymez-reception-logo.webp',
                            cacheWidth: 480,
                            width: compact ? 170 : 190,
                            height: compact ? 113 : 127,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const Spacer(flex: 6),
                        const _ReadyBenefits(),
                        SizedBox(height: compact ? 10 : 28),
                        const _ReadyOnboardingCopy(),
                        const Spacer(flex: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    foregroundColor: _mutedWhite,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text('Omitir'),
                                ),
                              ),
                            ),
                            const _LoginButton(),
                          ],
                        ),
                        SizedBox(height: compact ? 4 : 14),
                        const _PageIndicator(activeIndex: 2),
                        if (kIsWeb && !compact) const _WebHomeIndicator(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyBenefits extends StatelessWidget {
  const _ReadyBenefits();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return SizedBox(
          height: compact ? 105 : 118,
          child: Image.asset(
            'assets/images/onboarding-benefits-bar.webp',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        );
      },
    );
  }
}

class _ReadyOnboardingCopy extends StatelessWidget {
  const _ReadyOnboardingCopy();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = constraints.maxWidth < 360 ? 32.0 : 36.0;
        final titleStyle = TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('Todo listo para', style: titleStyle),
            ),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF287FFF), Color(0xFFFF2D54)],
              ).createShader(bounds),
              child: Text('comenzar', style: titleStyle),
            ),
            const SizedBox(height: 12),
            Text(
              'Acceso a tu cuenta',
              style: TextStyle(
                color: Color(0xFF36BFFF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu acceso está listo. Ingresa con tu cuenta\ny comienza a gestionar las visitas.',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
            ),
          ],
        );
      },
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 164,
      height: 54,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_red, Color(0xFFD20D77), Color(0xFF355DFF), _blue],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF07152B).withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ReceptionLoginPage(),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReceptionLoginPage extends StatefulWidget {
  const ReceptionLoginPage({super.key});

  @override
  State<ReceptionLoginPage> createState() => _ReceptionLoginPageState();
}

class _ReceptionLoginPageState extends State<ReceptionLoginPage> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _TabletLandscapeGuard(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _tabletBackground(
                context,
                'assets/images/login-background.webp',
                'assets/images/tablet-welcome-login.png',
              ),
              cacheWidth: 768,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  final veryCompact = constraints.maxHeight < 600;
                  final tablet = constraints.maxWidth >= 600;
                  final horizontalPadding = tablet
                      ? 40.0
                      : constraints.maxWidth < 360
                      ? 18.0
                      : 24.0;
                  final logoHeight = veryCompact
                      ? 40.0
                      : compact
                      ? 84.0
                      : 180.0;
                  final formHeight = veryCompact
                      ? 402.0
                      : compact
                      ? 402.0
                      : 330.0;
                  final visitorHeight = constraints.maxWidth < 500 || compact
                      ? 60.0
                      : 104.0;
                  final topPadding = veryCompact
                      ? 4.0
                      : compact
                      ? 10.0
                      : 18.0;
                  final bottomPadding = tablet
                      ? 80.0
                      : veryCompact
                      ? 6.0
                      : 12.0;
                  final naturalContentHeight =
                      topPadding +
                      logoHeight +
                      (compact ? 8.0 : 18.0) +
                      (compact ? 20.0 : 39.9) +
                      (veryCompact ? 2.0 : 5.0) +
                      18.0 +
                      (compact ? 8.0 : 18.0) +
                      formHeight +
                      (compact ? 6.0 : 14.0) +
                      visitorHeight +
                      bottomPadding +
                      (compact ? 54.0 : 65.0);
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: constraints.maxWidth - horizontalPadding * 2,
                      height: tablet
                          ? constraints.maxHeight
                          : naturalContentHeight,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: topPadding,
                          bottom: bottomPadding,
                        ),
                        child: tablet
                            ? _TabletLoginLayout(
                                obscurePassword: _obscurePassword,
                                onLogin: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ReceptionHomePage(),
                                    ),
                                  );
                                },
                                onTogglePassword: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Image.asset(
                                    'assets/images/cymez-reception-logo.webp',
                                    cacheWidth: 480,
                                    alignment: Alignment.topCenter,
                                    width: compact ? 210 : 240,
                                    height: logoHeight,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                  SizedBox(height: compact ? 8 : 18),
                                  Text(
                                    'Bienvenido de nuevo',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: compact ? 19 : 38,
                                      height: 1.05,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: veryCompact ? 2 : 5),
                                  const Text(
                                    'Inicia sesión para continuar',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFFD0D7E8),
                                      fontSize: 15,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 8 : 18),
                                  SizedBox(
                                    height: formHeight,
                                    child: _LoginFormCard(
                                      obscurePassword: _obscurePassword,
                                      onLogin: () {
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const ReceptionHomePage(),
                                          ),
                                        );
                                      },
                                      onTogglePassword: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      compact: compact,
                                      veryCompact: veryCompact,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 6 : 14),
                                  if (constraints.maxWidth >= 600)
                                    SizedBox(
                                      height: visitorHeight,
                                      child: Center(
                                        child: SizedBox(
                                          width:
                                              (constraints.maxWidth -
                                                  horizontalPadding * 2) *
                                              (constraints.maxWidth < 500
                                                  ? 0.84
                                                  : 1),
                                          height: visitorHeight,
                                          child: _VisitorRegistrationCard(
                                            compact: compact,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                  builder: (_) =>
                                                      const WalkInVisitorPage(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletLoginLayout extends StatelessWidget {
  const _TabletLoginLayout({
    required this.obscurePassword,
    required this.onLogin,
    required this.onTogglePassword,
  });

  final bool obscurePassword;
  final VoidCallback onLogin;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final narrowTablet = MediaQuery.sizeOf(context).width < 1000;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: narrowTablet ? 34 : 43,
                child: Transform.translate(
                  offset: const Offset(0, 42),
                  child: Center(
                    child: Image.asset(
                      'assets/images/cymez-reception-logo.webp',
                      cacheWidth: 720,
                      width: 620,
                      height: 380,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: narrowTablet ? 66 : 57,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 108),
                      const Text(
                        'Bienvenido de nuevo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Inicia sesión para continuar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFD0D7E8),
                          fontSize: 26,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.only(right: 32),
                        child: SizedBox(
                          key: const ValueKey('tablet-login-form-card'),
                          height: 460,
                          child: _LoginFormCard(
                            obscurePassword: obscurePassword,
                            onTogglePassword: onTogglePassword,
                            onLogin: onLogin,
                            compact: false,
                            veryCompact: false,
                            tablet: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          key: ValueKey('tablet-visitor-divider'),
          children: [
            Expanded(
              child: _VisitorDividerLine(
                colors: [Color(0x008DC8FF), Color(0xFF8DC8FF)],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x33101834),
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0x338DC8FF)),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'Registro de visitantes',
                    style: TextStyle(
                      color: Color(0xFFE5EAF5),
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _VisitorDividerLine(
                colors: [Color(0xFF8DC8FF), Color(0x00FF3155)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(
          child: FractionallySizedBox(
            widthFactor: 0.92,
            child: SizedBox(
              key: const ValueKey('tablet-walk-in-card'),
              height: 124,
              child: _VisitorRegistrationCard(
                compact: false,
                tablet: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WalkInVisitorPage(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VisitorDividerLine extends StatelessWidget {
  const _VisitorDividerLine({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.2,
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
    required this.compact,
    required this.veryCompact,
    this.tablet = false,
  });

  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final bool compact;
  final bool veryCompact;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6F789B).withValues(alpha: 0.55),
          width: 1,
        ),
        color: const Color(0xFF11152A),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.6),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            compact
                ? 14
                : tablet
                ? 28
                : 18,
            compact
                ? 4
                : tablet
                ? 24
                : 18,
            compact
                ? 14
                : tablet
                ? 28
                : 18,
            compact
                ? 4
                : tablet
                ? 24
                : 18,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.4),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF02A1633), Color(0xF0101834)],
            ),
            image: const DecorationImage(
              image: AssetImage('assets/images/login-card-background.webp'),
              fit: BoxFit.cover,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, contentConstraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentConstraints.maxWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: tablet ? 30 : 21,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: tablet ? 24 : 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: compact
                            ? 2
                            : tablet
                            ? 22
                            : 16,
                      ),
                      Text(
                        'Usuario o correo electrónico',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: tablet ? 19 : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(
                        height: compact
                            ? 2
                            : tablet
                            ? 12
                            : 9,
                      ),
                      _LoginInput(
                        icon: Icons.person_outline,
                        hint: 'Escribe tu usuario o correo',
                        compact: compact,
                        tablet: tablet,
                      ),
                      SizedBox(
                        height: compact
                            ? 2
                            : tablet
                            ? 22
                            : 16,
                      ),
                      Row(
                        children: [
                          Text(
                            'Contraseña',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: tablet ? 19 : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '¿Olvidaste tu contraseña?',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Color(0xFFFF4A68),
                                  fontSize: tablet ? 15 : 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: compact
                            ? 2
                            : tablet
                            ? 12
                            : 9,
                      ),
                      _LoginInput(
                        icon: Icons.lock_outline_rounded,
                        hint: 'Escribe tu contraseña',
                        obscure: obscurePassword,
                        compact: compact,
                        tablet: tablet,
                        trailing: IconButton(
                          onPressed: onTogglePassword,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: tablet
                                ? 28
                                : compact
                                ? 18
                                : 22,
                          ),
                          constraints: compact
                              ? const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                )
                              : null,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      SizedBox(
                        height: compact
                            ? 3
                            : tablet
                            ? 26
                            : 20,
                      ),
                      SizedBox(
                        height: compact
                            ? 38
                            : tablet
                            ? 68
                            : 54,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: onLogin,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x99FF3155),
                                    blurRadius: 10,
                                    offset: Offset(-2, 0),
                                  ),
                                  BoxShadow(
                                    color: Color(0x992F63FF),
                                    blurRadius: 10,
                                    offset: Offset(2, 0),
                                  ),
                                ],
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF3155),
                                    Color(0xFFB80035),
                                    Color(0xFFFF1744),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Iniciar sesión',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: tablet ? 20 : 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
                                      size: tablet ? 24 : 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginInput extends StatelessWidget {
  const _LoginInput({
    required this.icon,
    required this.hint,
    required this.compact,
    this.tablet = false,
    this.obscure = false,
    this.trailing,
  });

  final IconData icon;
  final String hint;
  final bool compact;
  final bool tablet;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact
          ? 30
          : tablet
          ? 68
          : 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFF3155), Color(0xFFB9218A), Color(0xFF4D7EFF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66284FFF),
            blurRadius: 6,
            offset: Offset(1, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.7),
          child: ColoredBox(
            color: const Color(0xF0171B37),
            child: TextField(
              obscureText: obscure,
              style: TextStyle(
                color: Colors.white,
                fontSize: tablet ? 20 : null,
              ),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: const Color(0xFF8FADFF)),
                suffixIcon: trailing,
                prefixIconConstraints: BoxConstraints(
                  minWidth: tablet ? 52 : 38,
                  minHeight: tablet ? 48 : 32,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                hintText: hint,
                hintStyle: TextStyle(
                  color: Color(0xFFB8C2D8),
                  fontSize: tablet ? 18 : 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: compact
                      ? 7
                      : tablet
                      ? 20
                      : 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitorRegistrationCard extends StatelessWidget {
  const _VisitorRegistrationCard({
    required this.compact,
    required this.onTap,
    this.tablet = false,
  });

  final bool compact;
  final VoidCallback onTap;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF3155), Color(0xFFDC176F), Color(0xFF2870FF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xA8FF3155),
              blurRadius: 14,
              offset: Offset(-3, 2),
            ),
            BoxShadow(
              color: Color(0x99005CFF),
              blurRadius: 14,
              offset: Offset(3, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(1.5),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.5),
                  gradient: const LinearGradient(
                    colors: [Color(0xF0241836), Color(0xF0102340)],
                  ),
                ),
                child: tablet
                    ? Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: Color(0xFF8DC8FF),
                            size: 48,
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Visitas sin cita',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Ingresa tu visita sin iniciar sesión',
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: Color(0xFFD0D7E8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _WalkInRegistrationButton(onTap: onTap),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: const Color(0xFF8DC8FF),
                            size: compact ? 18 : 34,
                          ),
                          SizedBox(width: compact ? 6 : 14),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Registro de visitas sin cita',
                                maxLines: 1,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 11 : 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: compact ? 16 : 24,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WalkInRegistrationButton extends StatelessWidget {
  const _WalkInRegistrationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF4058), Color(0xFFDA123E), Color(0xFFB90D35)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66FF2448),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Iniciar registro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

class _ControlOnboardingCopy extends StatelessWidget {
  const _ControlOnboardingCopy();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final titleStyle = TextStyle(
          color: _white,
          fontSize: compact ? 32 : 38,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controla entradas',
              style: titleStyle.copyWith(color: Colors.white),
              maxLines: 1,
              softWrap: false,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'y ',
                  style: titleStyle.copyWith(color: Colors.white),
                  maxLines: 1,
                  softWrap: false,
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFFF2D54), Color(0xFF287FFF)],
                  ).createShader(bounds),
                  child: Text(
                    'salidas',
                    style: titleStyle.copyWith(color: _white),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Seguimiento y seguridad',
              style: TextStyle(
                color: Color(0xFF36BFFF),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Consulta quién se encuentra dentro\n'
              'de las instalaciones y registra sus salidas\n'
              'para mantener un mejor control.',
              style: TextStyle(
                color: _white,
                fontSize: 15,
                height: 1.45,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
              maxLines: 3,
              textAlign: TextAlign.left,
            ),
          ],
        );
      },
    );
  }
}

class _OnboardingContinueButton extends StatelessWidget {
  const _OnboardingContinueButton({
    required this.compact,
    required this.onPressed,
  });

  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Container(
      width: tablet ? 220 : (compact ? 148 : 164),
      height: tablet ? 68 : (compact ? 50 : 54),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_red, Color(0xFFD20D77), Color(0xFF355DFF), _blue],
        ),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(-3, 2),
          ),
          BoxShadow(
            color: _blue.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(3, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF07152B).withValues(alpha: 0.94),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continuar',
                      style: TextStyle(
                        color: _white,
                        fontSize: tablet ? 18 : (compact ? 14 : 15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: _white,
                      size: tablet ? 24 : 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeLogo extends StatelessWidget {
  const _WelcomeLogo({
    required this.height,
    required this.width,
    required this.scale,
  });

  final double height;
  final double width;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Image.asset(
            'assets/images/cymez-reception-logo.webp',
            cacheWidth: 480,
            key: const ValueKey('reception-logo'),
            width: width,
            height: width / 1.5,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

class _WelcomeMessage extends StatelessWidget {
  const _WelcomeMessage({
    required this.compact,
    required this.tablet,
    required this.headlineFontSize,
  });

  final bool compact;
  final bool tablet;
  final double headlineFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0, 0.48, 0.72, 1],
            colors: [
              Color(0xFFF4F6FC),
              Color(0xFFC8D0E0),
              Color(0xFF4D9CFF),
              Color(0xFFFF354B),
            ],
          ).createShader(bounds),
          child: Text(
            'Bienvenido',
            style: TextStyle(
              fontSize: headlineFontSize,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              fontFamily: 'Roboto',
              color: Colors.white,
              shadows: const [Shadow(color: Color(0x66000000), blurRadius: 16)],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          '$_welcomeDescriptionFirstLine\nsegura y sencilla.',
          textAlign: TextAlign.center,
          style: _descriptionTextStyle(compact, tablet: tablet),
        ),
      ],
    );
  }
}

class _WelcomeBenefits extends StatelessWidget {
  const _WelcomeBenefits({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Image.asset(
        'assets/images/onboarding-benefits-bar.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.compact, required this.onStart});

  final bool compact;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Container(
      width: double.infinity,
      height: tablet ? 82 : (compact ? 60 : 68),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_red, Color(0xFFD20D77), Color(0xFF355DFF), _blue],
        ),
        boxShadow: [
          BoxShadow(
            color: _red.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(-4, 3),
          ),
          BoxShadow(
            color: _blue.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(4, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF351329), Color(0xFF09152B), Color(0xFF09204B)],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onStart,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Comenzar',
                  style: TextStyle(
                    color: _white,
                    fontSize: tablet ? 24 : (compact ? 18 : 20),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: _white,
                  size: tablet ? 32 : 25,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({this.activeIndex = 0});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Página ${activeIndex + 1} de 3',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (index) => Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == activeIndex ? _red : const Color(0xFF486187),
              boxShadow: index == activeIndex
                  ? [
                      BoxShadow(
                        color: _red.withValues(alpha: 0.55),
                        blurRadius: 9,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _WebHomeIndicator extends StatelessWidget {
  const _WebHomeIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Center(
        child: Container(
          width: 108,
          height: 4,
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class WalkInVisitorPage extends StatefulWidget {
  const WalkInVisitorPage({super.key});

  @override
  State<WalkInVisitorPage> createState() => _WalkInVisitorPageState();
}

class _WalkInVisitorPageState extends State<WalkInVisitorPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    SystemChrome.setPreferredOrientations(
      size.shortestSide >= 600
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
    precacheImage(
      const AssetImage('assets/images/walk-in-registration-background.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/walk-in-panel-frame.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/walk-in-tablet.webp'),
      context,
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _back() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817),
      body: const _WalkInLandscapeKiosk(),
    );
  }
}

class _WalkInRotatePrompt extends StatelessWidget {
  const _WalkInRotatePrompt({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/walk-in-registration-background.webp',
          fit: BoxFit.cover,
          cacheWidth: 1400,
          filterQuality: FilterQuality.high,
        ),
        Container(color: const Color(0xD0060C1A)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF087FFF), Color(0xFF053B82)],
                      ),
                      border: Border.all(
                        color: const Color(0xFF5EACFF),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x88087FFF), blurRadius: 28),
                      ],
                    ),
                    child: const Icon(
                      Icons.screen_rotation_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Gira tu celular',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'El registro de visitas sin cita funciona únicamente en orientación horizontal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFBCC8DD),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Volver al inicio de sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WalkInLandscapeKiosk extends StatefulWidget {
  const _WalkInLandscapeKiosk();

  @override
  State<_WalkInLandscapeKiosk> createState() => _WalkInLandscapeKioskState();
}

class _WalkInLandscapeKioskState extends State<_WalkInLandscapeKiosk> {
  bool _started = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 430;
    final portrait = size.height > size.width;
    final tabletWelcome = size.shortestSide >= 600 && !_started;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          tabletWelcome
              ? 'assets/images/tablet-kiosk-welcome.png'
              : 'assets/images/walk-in-registration-background.webp',
          fit: tabletWelcome ? BoxFit.contain : BoxFit.cover,
          cacheWidth: 1400,
          filterQuality: FilterQuality.high,
        ),
        if (!tabletWelcome)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xDE020817),
                  Color(0x99020918),
                  Color(0x5C020817),
                ],
              ),
            ),
          ),
        if (tabletWelcome)
          Positioned(
            left: size.width * 0.045,
            top: size.height * 0.72,
            width: size.width * 0.245,
            height: size.height * 0.085,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _started = true),
              ),
            ),
          ),
        if (tabletWelcome)
          const Opacity(opacity: 0, child: Text('Comenzar registro')),
        SafeArea(
          child: Column(
            children: [
              if (!tabletWelcome)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 18 : 28,
                    compact ? 8 : 16,
                    compact ? 18 : 28,
                    4,
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/cymez-reception-logo.webp',
                        height: compact ? 34 : 46,
                        width: portrait ? 84 : null,
                        fit: BoxFit.contain,
                      ),
                      const Spacer(),
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: portrait
                              ? size.width * 0.48
                              : double.infinity,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC07101F),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x661FA4FF)),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_add_alt_1_rounded,
                                color: Color(0xFF087FFF),
                                size: 17,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Registro de visitantes',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (!tabletWelcome)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.fromLTRB(
                      compact ? 18 : 28,
                      8,
                      compact ? 18 : 28,
                      compact ? 14 : 20,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xB53D8FFF),
                        width: 1.2,
                      ),
                      gradient: const LinearGradient(
                        colors: [Color(0xE5121D38), Color(0xE5081024)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xA8084BB0),
                          blurRadius: 28,
                          spreadRadius: -12,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/walk-in-panel-frame.webp',
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                          Container(color: const Color(0x2607101F)),
                          Row(
                            children: [
                              Expanded(
                                flex: _started || portrait ? 100 : 48,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    portrait ? 14 : (compact ? 22 : 38),
                                    _started
                                        ? (compact ? 18 : 28)
                                        : portrait
                                        ? (compact ? 28 : 44)
                                        : (compact ? 150 : 170),
                                    portrait ? 14 : (compact ? 12 : 24),
                                    compact ? 16 : 28,
                                  ),
                                  child: _started
                                      ? const _WalkInForm(compact: false)
                                      : SingleChildScrollView(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                children: [
                                                  Image.asset(
                                                    'assets/images/walk-in-access-shield.webp',
                                                    width: size.width < 700
                                                        ? 52
                                                        : size.width < 900
                                                        ? 68
                                                        : 82,
                                                    height: size.width < 700
                                                        ? 52
                                                        : size.width < 900
                                                        ? 68
                                                        : 82,
                                                    fit: BoxFit.contain,
                                                  ),
                                                  SizedBox(
                                                    width: compact ? 8 : 14,
                                                  ),
                                                  Flexible(
                                                    child: Text(
                                                      'CONTROL DE ACCESO',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: const Color(
                                                          0xFFD9E2F3,
                                                        ),
                                                        fontSize: portrait
                                                            ? 16
                                                            : (size.width < 700
                                                                  ? 18
                                                                  : size.width <
                                                                        900
                                                                  ? 22
                                                                  : 26),
                                                        letterSpacing: 1.6,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: compact ? 8 : 14,
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Bienvenido a nuestras',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: size.width < 700
                                                          ? 52
                                                          : size.width < 900
                                                          ? 64
                                                          : 62,
                                                      height: 1.18,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                    softWrap: false,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.visible,
                                                  ),
                                                  ShaderMask(
                                                    shaderCallback: (bounds) =>
                                                        const LinearGradient(
                                                          begin: Alignment
                                                              .centerLeft,
                                                          end: Alignment
                                                              .centerRight,
                                                          colors: [
                                                            Color(0xFFF8FAFF),
                                                            Color(0xFFF8FAFF),
                                                            Color(0xFF087FFF),
                                                            Color(0xFFE53E4B),
                                                          ],
                                                          stops: [
                                                            0,
                                                            .43,
                                                            .68,
                                                            1,
                                                          ],
                                                        ).createShader(bounds),
                                                    child: Text(
                                                      'instalaciones',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize:
                                                            size.width < 700
                                                            ? 52
                                                            : size.width < 900
                                                            ? 64
                                                            : 62,
                                                        height: 1.18,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                      softWrap: false,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.visible,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(
                                                height: compact ? 8 : 14,
                                              ),
                                              Text(
                                                'Para ingresar, completa tu registro de visitante.',
                                                style: TextStyle(
                                                  color: Color(0xFFC7D0E3),
                                                  fontSize: size.width < 700
                                                      ? 16
                                                      : size.width < 900
                                                      ? 22
                                                      : 26,
                                                ),
                                              ),
                                              SizedBox(
                                                height: compact ? 12 : 20,
                                              ),
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        begin: Alignment
                                                            .centerLeft,
                                                        end: Alignment
                                                            .centerRight,
                                                        colors: [
                                                          Color(0xFFE53E4B),
                                                          Color(0xFF087FFF),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Color(0x66E53E4B),
                                                      blurRadius: 18,
                                                      offset: Offset(0, 8),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.white,
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    elevation: 0,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              size.width < 700
                                                              ? 22
                                                              : 26,
                                                          vertical:
                                                              size.height < 430
                                                              ? 15
                                                              : 22,
                                                        ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                  ),
                                                  onPressed: () => setState(
                                                    () => _started = true,
                                                  ),
                                                  icon: const Icon(
                                                    Icons
                                                        .person_add_alt_1_rounded,
                                                    size: 24,
                                                  ),
                                                  label: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          'Comenzar registro',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            fontSize: portrait
                                                                ? 14
                                                                : (size.width <
                                                                          700
                                                                      ? 18
                                                                      : 22),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 14),
                                                      const Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 24,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              if (!_started && !portrait)
                                Expanded(
                                  flex: 52,
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: FractionallySizedBox(
                                      widthFactor: compact ? .84 : .78,
                                      heightFactor: compact ? .82 : .86,
                                      child: Transform.translate(
                                        offset: Offset(0, compact ? 4 : 8),
                                        child: Transform.rotate(
                                          angle: -.012,
                                          child: Image.asset(
                                            'assets/images/walk-in-tablet.webp',
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.high,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (!_started && !tabletWelcome)
                            Positioned(
                              left: compact ? 18 : 32,
                              right: compact ? 18 : 32,
                              bottom: compact ? 42 : 54,
                              height: compact ? 58 : 68,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: const [
                                  Expanded(
                                    child: _WalkInBenefit(
                                      icon: Icons.bolt_rounded,
                                      title: 'Proceso rápido',
                                      subtitle: 'En pocos minutos',
                                      color: Color(0xFFFF3155),
                                    ),
                                  ),
                                  Expanded(
                                    child: _WalkInBenefit(
                                      icon: Icons.shield_outlined,
                                      title: 'Seguro y confiable',
                                      subtitle: 'Tu información protegida',
                                      color: Color(0xFF087FFF),
                                    ),
                                  ),
                                  Expanded(
                                    child: _WalkInBenefit(
                                      icon: Icons.person_add_alt_1_rounded,
                                      title: 'Acceso controlado',
                                      subtitle: 'Para tu seguridad',
                                      color: Color(0xFFE7EEF9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalkInBenefit extends StatelessWidget {
  const _WalkInBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height > size.width;
    final iconSize = portrait ? 24.0 : (size.width < 700 ? 34.0 : 44.0);
    final titleSize = portrait ? 12.0 : (size.width < 700 ? 17.0 : 22.0);
    final subtitleSize = portrait ? 10.0 : (size.width < 700 ? 15.0 : 18.0);
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(width: portrait ? 6 : 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFBAC7DE),
                    fontSize: subtitleSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkInForm extends StatelessWidget {
  const _WalkInForm({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 22 : 36,
        compact ? 16 : 24,
        compact ? 22 : 36,
        compact ? 12 : 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PASO 1 DE 4',
              style: TextStyle(
                color: const Color(0xFFBFD7FF),
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 180,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                ),
              ),
            ),
            SizedBox(height: compact ? 16 : 22),
            Row(
              children: [
                Container(
                  width: compact ? 42 : 52,
                  height: compact ? 42 : 52,
                  decoration: BoxDecoration(
                    color: const Color(0xCC07172E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF087FFF)),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF087FFF),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Datos del visitante',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 20 : 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 14 : 20),
            _WalkInTextField(
              label: 'Nombre completo *',
              icon: Icons.person_outline_rounded,
              compact: compact,
            ),
            SizedBox(height: compact ? 10 : 14),
            _WalkInTextField(
              label: 'Empresa o procedencia *',
              icon: Icons.business_outlined,
              compact: compact,
            ),
            SizedBox(height: compact ? 10 : 14),
            _WalkInTextField(
              label: 'Asunto o motivo de la visita *',
              icon: Icons.chat_bubble_outline_rounded,
              compact: compact,
              maxLines: 2,
            ),
            SizedBox(height: compact ? 12 : 18),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                  ),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 24,
                      vertical: compact ? 10 : 14,
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text(
                    'Continuar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkInTextField extends StatelessWidget {
  const _WalkInTextField({
    required this.label,
    required this.icon,
    required this.compact,
    this.maxLines = 1,
  });
  final String label;
  final IconData icon;
  final bool compact;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(color: Colors.white, fontSize: 12),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: const Color(0xFFAAB8D1),
          fontSize: compact ? 11 : 13,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFFFF3155)),
        filled: true,
        fillColor: const Color(0xFF070D1C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF263650)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF263650)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF087FFF)),
        ),
      ),
    );
  }
}

class ReceptionHomePage extends StatelessWidget {
  const ReceptionHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ReceptionDashboardPage();
  }
}

class _ReceptionDashboardPage extends StatefulWidget {
  const _ReceptionDashboardPage();

  @override
  State<_ReceptionDashboardPage> createState() =>
      _ReceptionDashboardPageState();
}

class _ReceptionDashboardPageState extends State<_ReceptionDashboardPage> {
  String _activeSection = 'home';

  void _openDepartments() {
    setState(() => _activeSection = 'departments');
  }

  void _openHome() {
    setState(() => _activeSection = 'home');
  }

  void _openHosts() {
    setState(() => _activeSection = 'hosts');
  }

  void _openAccesses() {
    setState(() => _activeSection = 'accesses');
  }

  void _openExternalCompanies() {
    setState(() => _activeSection = 'external_companies');
  }

  void _openExternalStaff() {
    setState(() => _activeSection = 'external_staff');
  }

  void _openEquipment() {
    setState(() => _activeSection = 'equipment');
  }

  void _openAppointments() {
    setState(() => _activeSection = 'appointments');
  }

  void _openLogbook() {
    setState(() => _activeSection = 'logbook');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101F),
      drawer: _ReceptionDrawer(
        activeSection: _activeSection,
        onHome: _openHome,
        onDepartments: _openDepartments,
        onHosts: _openHosts,
        onAccesses: _openAccesses,
        onExternalCompanies: _openExternalCompanies,
        onExternalStaff: _openExternalStaff,
        onEquipment: _openEquipment,
        onAppointments: _openAppointments,
        onLogbook: _openLogbook,
      ),
      body: switch (_activeSection) {
        'departments' => const _DepartmentsPage(),
        'hosts' => const _HostsPage(),
        'accesses' => const _AccessesPage(),
        'external_companies' => const _ExternalCompaniesPage(),
        'external_staff' => const _ExternalStaffPage(),
        'equipment' => const _EquipmentPage(),
        'appointments' => const _AppointmentsPage(),
        'logbook' => const _DailyLogbookPage(),
        _ => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
              stops: [0, 0.48, 1],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 50,
                right: -90,
                child: Container(
                  width: 230,
                  height: 230,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x300087FF), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 480,
                left: -120,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Color(0x2200D4FF), Colors.transparent],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    responsivePadding(context),
                    10,
                    responsivePadding(context),
                    18,
                  ),
                  children: const [
                    _DashboardHeader(),
                    SizedBox(height: 12),
                    _DashboardSection(
                      icon: Icons.home_rounded,
                      title: 'Inicio',
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DashboardMetricCard(
                            icon: Icons.calendar_month_rounded,
                            accent: Color(0xFFFF3155),
                            title: 'Citas de hoy',
                            value: '0',
                            detail: 'Agenda programada',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _DashboardMetricCard(
                            icon: Icons.person_rounded,
                            accent: Color(0xFF087FFF),
                            title: 'Visitantes dentro',
                            value: '5',
                            detail: 'Según el último movimiento',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DashboardMetricCard(
                            icon: Icons.grid_view_rounded,
                            accent: Color(0xFFFF3155),
                            title: 'Llegadas pendientes',
                            value: '0',
                            detail: 'Citas sin ingreso completado',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _DashboardMetricCard(
                            icon: Icons.business_center_rounded,
                            accent: Color(0xFF087FFF),
                            title: 'Declaraciones de equipo',
                            value: '4',
                            detail: 'Registros en el módulo de equipo',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _MovementHistoryCard(),
                    SizedBox(height: 12),
                    _CompositionCard(),
                    SizedBox(height: 12),
                    _TrendCard(),
                    SizedBox(height: 12),
                    _AgendaPanel(),
                    SizedBox(height: 12),
                    _BitacoraPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}

class _DashboardHeader extends StatefulWidget {
  const _DashboardHeader();

  @override
  State<_DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<_DashboardHeader> {
  OverlayEntry? _profileEntry;

  void _closeProfileMenu() {
    _profileEntry?.remove();
    _profileEntry = null;
  }

  void _toggleProfileMenu() {
    if (_profileEntry != null) {
      _closeProfileMenu();
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final menuTop = offset.dy + renderBox.size.height - 3;
    _profileEntry = OverlayEntry(
      builder: (overlayContext) =>
          _ProfileMenuOverlay(top: menuTop, onClose: _closeProfileMenu),
    );
    Overlay.of(context).insert(_profileEntry!);
  }

  @override
  void dispose() {
    _closeProfileMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF07162E),
          border: Border(
            bottom: BorderSide(color: Color(0xFF263B58), width: 1),
          ),
        ),
        child: Row(
          children: [
            Builder(
              builder: (context) =>
                  _MenuButton(onTap: () => Scaffold.of(context).openDrawer()),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/cymez-reception-logo.webp',
                    cacheWidth: 480,
                    width: 82,
                    height: 52,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 1,
                    height: 31,
                    color: const Color(0xFF3A4A62),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'RECEP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.05,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'CONTROL DE\nVISITANTES',
                    style: TextStyle(
                      color: Color(0xFF9CB5D1),
                      fontSize: 7,
                      height: 1.25,
                      letterSpacing: .55,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            _ProfileButton(onTap: _toggleProfileMenu),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: const Color(0xFF09101D),
          border: Border.all(color: const Color(0xFF263B58)),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.menu_rounded,
          color: Color(0xFFB7C7DA),
          size: 25,
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF111D32), Color(0xFF09101D)],
          ),
          border: Border.all(color: const Color(0xFF263B58)),
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          color: Color(0xFFB7C7DA),
          size: 25,
        ),
      ),
    );
  }
}

class _ProfileMenuOverlay extends StatefulWidget {
  const _ProfileMenuOverlay({required this.top, required this.onClose});

  final double top;
  final VoidCallback onClose;

  @override
  State<_ProfileMenuOverlay> createState() => _ProfileMenuOverlayState();
}

class _ProfileMenuOverlayState extends State<_ProfileMenuOverlay> {
  bool _darkMode = true;

  void _logout() {
    widget.onClose();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ReceptionLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onClose,
            ),
          ),
          Positioned(
            top: widget.top,
            right: 10,
            width: 268,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172442), Color(0xFF090F20)],
                ),
                border: Border.all(color: const Color(0x990087FF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x990087FF),
                    blurRadius: 22,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x140087FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0x260087FF)),
                    ),
                    child: const Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: Color(0xFF087FFF),
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recepción Principal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Administrador',
                                style: TextStyle(
                                  color: Color(0xFF75BFFF),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x190087FF)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _darkMode
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          color: const Color(0xFF75BFFF),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Modo oscuro',
                            style: TextStyle(
                              color: Color(0xFFDDE6F5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          value: _darkMode,
                          activeTrackColor: const Color(0xFF087FFF),
                          activeThumbColor: Colors.white,
                          onChanged: (value) {
                            setState(() => _darkMode = value);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 42,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5A72),
                        side: const BorderSide(color: Color(0x99FF3155)),
                        backgroundColor: const Color(0x18FF3155),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D2B50), Color(0xFF131C35)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF087FFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x6600AEEF),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
          BoxShadow(color: Color(0x220087FF), blurRadius: 18, spreadRadius: 2),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF087FFF), size: 24),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2748), Color(0xFF141A31), Color(0xFF0E1427)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: .82), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .14),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .32),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: .28),
                  const Color(0xFF10172B),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent, width: 1.5),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: .28), blurRadius: 10),
              ],
            ),
            child: Icon(icon, color: accent, size: 23),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFDCE2F0),
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFA9B4CB),
                    fontSize: 10,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: accent, size: 16),
        ],
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2949), Color(0xFF12192F), Color(0xFF0D1325)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF087FFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x550087FF),
            blurRadius: 13,
            offset: Offset(0, 4),
          ),
          BoxShadow(color: Color(0x220087FF), blurRadius: 24, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

class _MovementHistoryCard extends StatelessWidget {
  const _MovementHistoryCard();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF087FFF),
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historial de movimientos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Consulta registros anteriores y actualiza las gráficas por periodo.',
                      style: TextStyle(color: Color(0xFFAEB7CC), fontSize: 10),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF087FFF)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;
              final chips = const Row(
                children: [
                  _PeriodChip('7 días', active: true),
                  _PeriodChip('30 días'),
                  _PeriodChip('Personalizado'),
                ],
              );
              final dateRange = Row(
                mainAxisAlignment: compact
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
                children: const [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF087FFF),
                    size: 15,
                  ),
                  SizedBox(width: 5),
                  Text(
                    '24 oct 2026 - 30 oct 2026',
                    style: TextStyle(color: Colors.white, fontSize: 9),
                  ),
                ],
              );

              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1226),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [chips, const SizedBox(height: 3), dateRange],
                      )
                    : Row(
                        children: [
                          chips,
                          Expanded(child: dateRange),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip(this.label, {this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF087FFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CompositionCard extends StatelessWidget {
  const _CompositionCard();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Composición de movimientos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'Distribución · 24 oct 2026 – 30 oct 2026',
            style: TextStyle(color: Color(0xFFAEB7CC), fontSize: 10),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 130,
                height: 112,
                child: CustomPaint(
                  painter: _DonutPainter(),
                  child: Center(
                    child: Text(
                      '9\nmovimientos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: const [
                    _LegendRow(
                      color: Color(0xFFFF3155),
                      label: 'Llegadas',
                      value: '3',
                    ),
                    _LegendRow(
                      color: Color(0xFF087FFF),
                      label: 'Entradas',
                      value: '5',
                    ),
                    _LegendRow(
                      color: Color(0xFF28C9E8),
                      label: 'Salidas',
                      value: '1',
                    ),
                    _LegendRow(
                      color: Colors.white,
                      label: 'Observaciones',
                      value: '0',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Text(
            'Conteo real de los registros de la bitácora',
            style: TextStyle(color: Color(0xFFAEB7CC), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Tendencia diaria',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '9 total',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Text(
            'Volumen diario · 24 oct 2026 – 30 oct 2026',
            style: TextStyle(color: Color(0xFFAEB7CC), fontSize: 10),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _LegendDot(color: Color(0xFF087FFF), label: 'Llegadas'),
              SizedBox(width: 12),
              _LegendDot(color: Color(0xFF28C9E8), label: 'Entradas'),
              SizedBox(width: 12),
              _LegendDot(color: Color(0xFFFF3155), label: 'Salidas'),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 178,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(0, 6, 4, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1020).withValues(alpha: .72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF087FFF).withValues(alpha: .12),
              ),
            ),
            child: const CustomPaint(
              painter: _LineChartPainter(),
              size: Size(double.infinity, 178),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }
}

class _AgendaPanel extends StatelessWidget {
  const _AgendaPanel();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF087FFF),
                  size: 22,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Agenda de citas de hoy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _MiniDateButton(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF087FFF), Color(0xFF315FEA)],
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 5),
                  Text(
                    'Nueva cita',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: const Color(0xFF0A1021),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Hora',
                    style: TextStyle(color: Color(0xFFBFC8DD), fontSize: 9),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Visitante',
                    style: TextStyle(color: Color(0xFFBFC8DD), fontSize: 9),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Empresa',
                    style: TextStyle(color: Color(0xFFBFC8DD), fontSize: 9),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Estado',
                    style: TextStyle(color: Color(0xFFBFC8DD), fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Text(
              'No hay citas programadas para hoy.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA8C0), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniDateButton extends StatelessWidget {
  const _MiniDateButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF101A2D),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0xFF087FFF).withValues(alpha: .65),
        ),
      ),
      child: const Row(
        children: [
          Text(
            '10/30/2026',
            style: TextStyle(color: Color(0xFFD7DDEE), fontSize: 8),
          ),
          SizedBox(width: 4),
          Icon(
            Icons.calendar_today_outlined,
            color: Color(0xFF087FFF),
            size: 13,
          ),
        ],
      ),
    );
  }
}

class _BitacoraPanel extends StatelessWidget {
  const _BitacoraPanel();

  @override
  Widget build(BuildContext context) {
    return _DashboardPanel(
      padding: EdgeInsets.zero,
      child: const Column(
        children: [
          _BitacoraHeader(),
          _BitacoraEntry(
            date: '29 oct',
            time: '09:04',
            type: 'Ingreso',
            name: 'Abner Alejandro Soto',
            detail: 'Registro manual · Folio 99928727 · Checklist completado',
            color: Color(0xFF087FFF),
            icon: Icons.login_rounded,
          ),
          _BitacoraEntry(
            date: '29 oct',
            time: '08:57',
            type: 'Llegada',
            name: 'Rafael Gonzales Castañeda',
            detail:
                'Registro manual · Folio 53597403 · Pendiente de autorización',
            color: Color(0xFF26E2A7),
            icon: Icons.call_received_rounded,
          ),
          _BitacoraEntry(
            date: '28 oct',
            time: '16:58',
            type: 'Ingreso',
            name: 'Pedro Hernandez',
            detail: 'Soluciones Industriales del Norte S.A. de C.V.',
            color: Color(0xFF087FFF),
            icon: Icons.login_rounded,
          ),
        ],
      ),
    );
  }
}

class _BitacoraHeader extends StatelessWidget {
  const _BitacoraHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF087FFF))),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule_rounded, color: Color(0xFF087FFF), size: 22),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Registros del periodo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            'Ver toda la bitácora  →',
            style: TextStyle(color: Color(0xFF087FFF), fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _BitacoraEntry extends StatelessWidget {
  const _BitacoraEntry({
    required this.date,
    required this.time,
    required this.type,
    required this.name,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String date;
  final String time;
  final String type;
  final String name;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x332B8FFF))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              children: [
                Container(height: 14, width: 1, color: const Color(0xFF087FFF)),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF111A31),
                    border: Border.all(color: color, width: 1.4),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Container(height: 34, width: 1, color: const Color(0xFF087FFF)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 11, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$date  ·  $time',
                    style: const TextStyle(
                      color: Color(0xFFBCC6DA),
                      fontSize: 9,
                    ),
                  ),
                  Text(
                    type,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFAEB7CC),
                      fontSize: 9,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .39;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paints = [
      (const Color(0xFFFF3155), 120.0),
      (const Color(0xFF087FFF), 200.0),
      (const Color(0xFF28C9E8), 40.0),
      (const Color(0xFF2B3350), 360.0 - 120.0 - 200.0 - 40.0),
    ];
    var start = -90.0;
    for (final segment in paints) {
      canvas.drawArc(
        rect,
        start * 3.1415926535 / 180,
        segment.$2 * 3.1415926535 / 180,
        false,
        Paint()
          ..color = segment.$1
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.butt,
      );
      start += segment.$2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const labels = ['24 Oct', '26 Oct', '28 Oct', '30 Oct'];
    final left = 31.0;
    final top = 12.0;
    final bottom = size.height - 28;
    final right = size.width - 12;
    final plotWidth = right - left;
    final plotHeight = bottom - top;
    final gridPaint = Paint()
      ..color = const Color(0xFF2A365B).withValues(alpha: .72)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = bottom - plotHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
      final valuePainter = TextPainter(
        text: TextSpan(
          text: '$i',
          style: const TextStyle(color: Color(0xFFAEB7CC), fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valuePainter.paint(canvas, Offset(7, y - valuePainter.height / 2));
    }
    void drawSeries(List<double> values, Color color) {
      final points = <Offset>[];
      for (var i = 0; i < values.length; i++) {
        final x = left + plotWidth * i / (values.length - 1);
        final y = bottom - values[i] / 3 * plotHeight;
        points.add(Offset(x, y));
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      for (final point in points) {
        canvas.drawCircle(
          point,
          5.2,
          Paint()
            ..color = color.withValues(alpha: .18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        canvas.drawCircle(point, 3.2, Paint()..color = const Color(0xFF07101F));
        canvas.drawCircle(point, 2.2, Paint()..color = color);
      }
    }

    drawSeries([0, 0, 3, 1], const Color(0xFF087FFF));
    drawSeries([0, 1, 1, 2], const Color(0xFF28C9E8));
    drawSeries([0, 1, 0, 0], const Color(0xFFFF3155));
    final labelStyle = const TextStyle(color: Color(0xFFAEB7CC), fontSize: 9);
    for (var i = 0; i < labels.length; i++) {
      final x = left + plotWidth * i / 3;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      final labelX = i == 0
          ? left
          : i == labels.length - 1
          ? right - tp.width
          : x - tp.width / 2;
      tp.paint(canvas, Offset(labelX, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccessesPage extends StatefulWidget {
  const _AccessesPage();

  @override
  State<_AccessesPage> createState() => _AccessesPageState();
}

class _AccessesPageState extends State<_AccessesPage> {
  final _searchController = TextEditingController();
  final _accounts = const [
    _SystemAccount(
      login: 'demo.admin',
      name: 'Administrador de prueba',
      role: 'Administrador',
      email: 'admin.demo@visitas.local',
      phone: '5550000010',
      active: true,
      accessLabel: 'Administrador',
    ),
    _SystemAccount(
      login: 'demo.recepcion',
      name: 'Recepción de prueba',
      role: 'Recepción',
      email: 'recepcion.demo@visitas.local',
      phone: '5550000011',
      active: true,
      accessLabel: 'Recepción',
    ),
    _SystemAccount(
      login: 'jehg13072002',
      name: 'Programador de prueba',
      role: 'Programador',
      email: 'jehg13072002@gmail.com',
      phone: '5550000012',
      active: true,
      accessLabel: 'Administrador',
    ),
  ];

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = _accounts.where((account) {
      final value =
          '${account.login} ${account.name} ${account.role} ${account.email}'
              .toLowerCase();
      return value.contains(_query.toLowerCase());
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accesos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Administra quién puede ingresar al sistema',
                      style: TextStyle(color: Color(0xFFB5C1D6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF17243D), Color(0xFF0B1427)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF087FFF)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                              ),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Accesos al sistema',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Administración de cuentas',
                                  style: TextStyle(
                                    color: Color(0xFF087FFF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x220087FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0x660087FF),
                              ),
                            ),
                            child: Text(
                              '${_accounts.length} cuentas',
                              style: const TextStyle(
                                color: Color(0xFF6DB5FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Buscar usuario, nombre, puesto o correo...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF73809A),
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF087FFF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF111D35),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0x330087FF),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: SliverList.separated(
                itemCount: filteredAccounts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final account = filteredAccounts[index];
                  return _AccessAccountCard(account: account);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemAccount {
  const _SystemAccount({
    required this.login,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.active,
    required this.accessLabel,
  });

  final String login;
  final String name;
  final String role;
  final String email;
  final String phone;
  final bool active;
  final String accessLabel;
}

class _AccessAccountCard extends StatelessWidget {
  const _AccessAccountCard({required this.account});

  final _SystemAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17243D), Color(0xFF0C1527)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x440087FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220087FF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 90,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF087FFF),
                    Color(0xFF00C8FF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                      ),
                      border: Border.all(color: const Color(0xFF8FD5FF)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x660087FF), blurRadius: 12),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.login,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF67ACFF),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: account.active
                            ? const [Color(0xFF153D35), Color(0xFF1D574A)]
                            : const [Color(0xFF3A2430), Color(0xFF572738)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      account.active ? 'Activa' : 'Inactiva',
                      style: TextStyle(
                        color: account.active
                            ? const Color(0xFF4AE3B5)
                            : const Color(0xFFFF7D9B),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0x19087FFF),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0x220087FF)),
                ),
                child: Column(
                  children: [
                    _AccessDetail(
                      Icons.work_outline_rounded,
                      'Puesto',
                      account.role,
                    ),
                    _AccessDetail(
                      Icons.mail_outline_rounded,
                      'Correo',
                      account.email,
                    ),
                    _AccessDetail(
                      Icons.phone_rounded,
                      'Teléfono',
                      account.phone,
                    ),
                    _AccessDetail(
                      Icons.admin_panel_settings_outlined,
                      'Acceso',
                      account.accessLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF087FFF),
                        Color(0xFF3D8FFF),
                        Color(0xFF00C8FF),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x550087FF),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const _AccessEditDialog(),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text(
                      'Editar acceso',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessDetail extends StatelessWidget {
  const _AccessDetail(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF087FFF)),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF7F8CA5), fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFFD7E3F7), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessEditDialog extends StatelessWidget {
  const _AccessEditDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: const Color(0xFF111D35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Editar acceso',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            const _HostFormField('Usuario'),
            const SizedBox(height: 12),
            const _HostFormField('Nombre'),
            const SizedBox(height: 12),
            const _HostFormField('Correo electrónico'),
            const SizedBox(height: 12),
            const _HostFormField('Teléfono', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            const _HostFormField('Puesto / rol'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF087FFF),
                      Color(0xFF3D8FFF),
                      Color(0xFF00C8FF),
                    ],
                  ),
                ),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Guardar cambios',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalCompaniesPage extends StatefulWidget {
  const _ExternalCompaniesPage();

  @override
  State<_ExternalCompaniesPage> createState() => _ExternalCompaniesPageState();
}

class _ExternalCompaniesPageState extends State<_ExternalCompaniesPage> {
  final _companies = const [
    _ExternalCompany(
      name: 'Rafael Gonzales Castañeda',
      description: 'Público General',
      rfc: 'N/A',
      category: 'Visitante',
      subject: 'Entrevista',
      employees: '1',
      type: 'Visitante',
      active: false,
    ),
    _ExternalCompany(
      name: 'Soluciones Industriales del Norte S.A. de C.V.',
      description: 'Empresa especializada en mantenimiento industrial, instalaciones eléctricas y servicios técnicos.',
      rfc: 'PALR051180TSR',
      category: 'Mantenimiento Industrial',
      subject: '',
      employees: '3',
      type: 'Contratista',
      active: true,
    ),
    _ExternalCompany(
      name: 'Suministros Industriales del Norte',
      description: 'Distribución y entrega de materiales, herramientas y equipos de seguridad.',
      rfc: 'SIN260315AB7',
      category: 'Suministros industriales',
      subject: '',
      employees: '3',
      type: 'Proveedor',
      active: true,
    ),
  ];
  String _query = '';
  String _typeFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final records = _companies.where((company) {
      final matchesQuery =
          '${company.name} ${company.description} ${company.rfc} ${company.category}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      final matchesType = _typeFilter == 'Todos' || company.type == _typeFilter;
      return matchesQuery && matchesType;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contratistas, proveedores y visitantes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Empresas y personas externas registradas',
                      style: TextStyle(color: Color(0xFFB5C1D6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF17243D), Color(0xFF0B1427)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF087FFF)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                              ),
                            ),
                            child: const Icon(
                              Icons.apartment_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_companies.length} registros',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          _GradientRegisterButton(
                            label: 'Registrar',
                            onPressed: () => showDialog<void>(
                              context: context,
                              barrierColor: const Color(0xE0000000),
                              builder: (_) =>
                                  const _ExternalCompanyFormDialog(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: _accessSearchDecoration(
                          'Buscar por nombre, RFC, categoría...',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FilterChips(
                        values: const [
                          'Todos',
                          'Contratista',
                          'Proveedor',
                          'Visitante',
                        ],
                        selected: _typeFilter,
                        onSelected: (value) =>
                            setState(() => _typeFilter = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: SliverList.separated(
                itemCount: records.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) =>
                    _ExternalCompanyCard(company: records[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalCompany {
  const _ExternalCompany({
    required this.name,
    required this.description,
    required this.rfc,
    required this.category,
    required this.subject,
    required this.employees,
    required this.type,
    required this.active,
  });

  final String name;
  final String description;
  final String rfc;
  final String category;
  final String subject;
  final String employees;
  final String type;
  final bool active;
}

class _ExternalCompanyCard extends StatelessWidget {
  const _ExternalCompanyCard({required this.company});

  final _ExternalCompany company;

  @override
  Widget build(BuildContext context) {
    final typeColor = switch (company.type) {
      'Visitante' => const Color(0xFFB69CFF),
      'Proveedor' => const Color(0xFF4AE3B5),
      _ => const Color(0xFF087FFF),
    };

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF192846), Color(0xFF0D172A), Color(0xFF09111F)],
              stops: [0, 0.58, 1],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x660087FF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330087FF),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          typeColor.withValues(alpha: 0.38),
                          const Color(0xFF111A31),
                        ],
                      ),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.72),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.18),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Icon(
                      company.type == 'Visitante'
                          ? Icons.person_rounded
                          : Icons.apartment_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _ExternalChip(company.type, typeColor),
                            const Spacer(),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: company.active
                                    ? const Color(0xFF4AE3B5)
                                    : const Color(0xFF8490A5),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (company.active
                                                ? const Color(0xFF4AE3B5)
                                                : const Color(0xFF8490A5))
                                            .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              company.active ? 'Activo' : 'Sin aplicar',
                              style: TextStyle(
                                color: company.active
                                    ? const Color(0xFF4AE3B5)
                                    : const Color(0xFFAAB5C9),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (company.description.isNotEmpty) ...[
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x12FFFFFF),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0x16FFFFFF)),
                  ),
                  child: Text(
                    company.description,
                    style: const TextStyle(
                      color: Color(0xFFC7D1E3),
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _ExternalMetricTile(
                          icon: Icons.badge_outlined,
                          label: 'RFC',
                          value: company.rfc,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _ExternalMetricTile(
                          icon: Icons.people_outline_rounded,
                          label: 'Empleados',
                          value: company.employees,
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _ExternalMetricTile(
                          icon: Icons.category_outlined,
                          label: 'Categoría',
                          value: company.category,
                        ),
                      ),
                      if (company.subject.isNotEmpty)
                        SizedBox(
                          width: constraints.maxWidth,
                          child: _ExternalMetricTile(
                            icon: Icons.event_note_rounded,
                            label: 'Asunto',
                            value: company.subject,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const _ExternalCompanyFormDialog(),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Editar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9BCCFF),
                        side: const BorderSide(color: Color(0x66087FFF)),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Eliminar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF7189),
                        backgroundColor: const Color(0x16FF3155),
                        side: const BorderSide(color: Color(0x66FF3155)),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          top: 0,
          height: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  typeColor.withValues(alpha: 0.2),
                  typeColor,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExternalMetricTile extends StatelessWidget {
  const _ExternalMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111F39), Color(0xFF0D172A)],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0x1F087FFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF087FFF)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8392AD),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFFE1EAF8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalChip extends StatelessWidget {
  const _ExternalChip(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GradientRegisterButton extends StatelessWidget {
  const _GradientRegisterButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          gradient: const LinearGradient(
            colors: [Color(0xFF087FFF), Color(0xFF3D8FFF), Color(0xFF00C8FF)],
          ),
        ),
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          icon: const Icon(Icons.add, size: 17),
          label: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final value in values) ...[
            ChoiceChip(
              label: Text(value),
              selected: selected == value,
              onSelected: (_) => onSelected(value),
              selectedColor: const Color(0xFF087FFF),
              backgroundColor: const Color(0xFF111D35),
              labelStyle: TextStyle(
                color: selected == value
                    ? Colors.white
                    : const Color(0xFFB6C2D8),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              side: const BorderSide(color: Color(0x33087FFF)),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

InputDecoration _accessSearchDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF73809A), fontSize: 12),
    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF087FFF)),
    filled: true,
    fillColor: const Color(0xFF111D35),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x330087FF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF087FFF)),
    ),
  );
}

class _ExternalCompanyFormDialog extends StatelessWidget {
  const _ExternalCompanyFormDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: const Color(0xFF111D35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Registrar registro',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _HostFormField('Tipo'),
              const SizedBox(height: 12),
              const _HostFormField('Nombre de la empresa'),
              const SizedBox(height: 12),
              const _HostFormField('Descripción breve'),
              const SizedBox(height: 12),
              const _HostFormField('RFC'),
              const SizedBox(height: 12),
              const _HostFormField('Categoría'),
              const SizedBox(height: 12),
              const _HostFormField(
                'Número de empleados',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              const _HostFormField('Estado'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF087FFF),
                        Color(0xFF3D8FFF),
                        Color(0xFF00C8FF),
                      ],
                    ),
                  ),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Registrar empresa',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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

class _ExternalStaffPage extends StatefulWidget {
  const _ExternalStaffPage();

  @override
  State<_ExternalStaffPage> createState() => _ExternalStaffPageState();
}

class _ExternalStaffPageState extends State<_ExternalStaffPage> {
  final _companies = const [
    _ExternalStaffCompany(
      name: 'Soluciones Industriales del Norte S.A. de C.V.',
      type: 'Contratista',
      staff: [
        _ExternalStaffMember(
          name: 'Jesus Efren Hinojosa Guerra',
          phone: '8993384002',
          email: 'jefehi13@gmail.com',
          relation: 'Contratista',
        ),
        _ExternalStaffMember(
          name: 'Juan Martínez',
          phone: '',
          email: '',
          relation: 'Contratista',
        ),
        _ExternalStaffMember(
          name: 'Pedro Hernández',
          phone: '',
          email: '',
          relation: 'Contratista',
        ),
      ],
    ),
  ];

  _ExternalStaffCompany? _selectedCompany;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final company = _selectedCompany;
    final visibleCompanies = _companies.where((item) {
      return item.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    final visibleStaff =
        company?.staff.where((member) {
          return '${member.name} ${member.phone} ${member.email}'
              .toLowerCase()
              .contains(_query.toLowerCase());
        }).toList() ??
        const [];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal de externos',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Personal vinculado a empresas externas registradas',
                      style: TextStyle(color: Color(0xFFB5C1D6), fontSize: 12),
                    ),
                    if (company != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF17243D), Color(0xFF0B1427)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x66087FFF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF087FFF),
                                    Color(0xFF00C8FF),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.apartment_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                company.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() {
                                _selectedCompany = null;
                                _query = '';
                              }),
                              child: const Text('Empresas'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF17243D), Color(0xFF0B1427)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF087FFF)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              company == null
                                  ? 'Personal por empresa'
                                  : 'Personal registrado',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x22087FFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${company?.staff.length ?? visibleCompanies.length} ${company == null ? 'empresas' : 'empleados'}',
                              style: const TextStyle(
                                color: Color(0xFF67ACFF),
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (company != null) ...[
                            const SizedBox(width: 8),
                            _GradientRegisterButton(
                              label: 'Empleado',
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) =>
                                    const _ExternalStaffFormDialog(),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: _accessSearchDecoration(
                          company == null
                              ? 'Buscar empresa...'
                              : 'Buscar nombre, contacto o empresa...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: company == null
                  ? SliverList.separated(
                      itemCount: visibleCompanies.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _ExternalCompanyStaffCard(
                        company: visibleCompanies[index],
                        onOpen: () => setState(() {
                          _selectedCompany = visibleCompanies[index];
                          _query = '';
                        }),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: visibleStaff.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) =>
                          _ExternalStaffMemberCard(member: visibleStaff[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExternalStaffCompany {
  const _ExternalStaffCompany({
    required this.name,
    required this.type,
    required this.staff,
  });

  final String name;
  final String type;
  final List<_ExternalStaffMember> staff;
}

class _ExternalStaffMember {
  const _ExternalStaffMember({
    required this.name,
    required this.phone,
    required this.email,
    required this.relation,
  });

  final String name;
  final String phone;
  final String email;
  final String relation;
}

class _ExternalCompanyStaffCard extends StatelessWidget {
  const _ExternalCompanyStaffCard({
    required this.company,
    required this.onOpen,
  });

  final _ExternalStaffCompany company;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B2D50), Color(0xFF111C33), Color(0xFF09111F)],
          stops: [0, 0.62, 1],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x77087FFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330087FF),
            blurRadius: 20,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -16,
            left: 36,
            right: 36,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                gradient: const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0xFF087FFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                      ),
                      border: Border.all(color: const Color(0xFF8CD8FF)),
                      boxShadow: const [
                        BoxShadow(color: Color(0x660087FF), blurRadius: 14),
                      ],
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _ExternalChip(company.type, const Color(0xFF087FFF)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 58,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF087FFF), Color(0xFF163C72)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0x990087FF)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${company.staff.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'empleados',
                          style: TextStyle(
                            color: Color(0xFFD9E9FF),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF087FFF),
                      Color(0xFF3D8FFF),
                      Color(0xFF00C8FF),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x550087FF),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.groups_rounded, size: 19),
                  label: const Text(
                    'Ver personal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExternalStaffMemberCard extends StatelessWidget {
  const _ExternalStaffMemberCard({required this.member});

  final _ExternalStaffMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF192846), Color(0xFF0D172A)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x44087FFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0x22087FFF),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF67ACFF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  member.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              _ExternalChip(member.relation, const Color(0xFF087FFF)),
            ],
          ),
          const SizedBox(height: 12),
          _ExternalMetricTile(
            icon: Icons.phone_outlined,
            label: 'Teléfono',
            value: member.phone.isEmpty ? 'No registrado' : member.phone,
          ),
          const SizedBox(height: 8),
          _ExternalMetricTile(
            icon: Icons.mail_outline_rounded,
            label: 'Correo electrónico',
            value: member.email.isEmpty ? 'No registrado' : member.email,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8CCAFF),
                    side: const BorderSide(color: Color(0x66087FFF)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7189),
                    side: const BorderSide(color: Color(0x66FF3155)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExternalStaffFormDialog extends StatelessWidget {
  const _ExternalStaffFormDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: const Color(0xFF111D35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registrar personal externo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const _HostFormField('Nombre completo'),
              const SizedBox(height: 12),
              const _HostFormField(
                'Teléfono',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              const _HostFormField(
                'Correo electrónico',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              const _HostFormField('Tipo de vínculo'),
              const SizedBox(height: 12),
              const _HostFormField('Empresa contratista o proveedora'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF087FFF),
                        Color(0xFF3D8FFF),
                        Color(0xFF00C8FF),
                      ],
                    ),
                  ),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                    child: const Text(
                      'Registrar personal',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
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

class _AppointmentsPage extends StatefulWidget {
  const _AppointmentsPage();

  @override
  State<_AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<_AppointmentsPage> {
  bool _showAll = false;
  String _query = '';
  int _selectedDay = 27;

  static const _appointments = [
    _Appointment(
      day: 27,
      time: '18:00',
      visitor: 'Jesus Efren Hinojosa Guerra',
      company: 'Soluciones Industriales del Norte S.A. de C.V.',
      host: 'Administrador de prueba',
      status: 'Pendiente',
    ),
    _Appointment(
      day: 27,
      time: '18:00',
      visitor: 'Jesus Hinojosa',
      company: 'Suministros Industriales del Norte',
      host: 'Administrador de prueba',
      status: 'Pendiente',
    ),
    _Appointment(
      day: 27,
      time: '18:00',
      visitor: 'Jesus Efren Hinojosa Guerra',
      company: 'Soluciones Industriales del Norte S.A. de C.V.',
      host: 'Administrador de prueba',
      status: 'Cancelada',
    ),
    _Appointment(
      day: 28,
      time: '18:00',
      visitor: 'Jesus Efren Hinojosa Guerra',
      company: 'Soluciones Industriales del Norte S.A. de C.V.',
      host: 'Administrador de prueba',
      status: 'Dentro',
    ),
  ];

  void _showAppointmentDialog({_Appointment? appointment}) {
    showDialog<void>(
      context: context,
      builder: (_) => _AppointmentDialog(appointment: appointment),
    );
  }

  void _selectCalendarDay(int day) {
    setState(() => _selectedDay = day);
    final appointmentsForDay = _appointments
        .where((appointment) => appointment.day == day)
        .toList();
    showDialog<void>(
      context: context,
      builder: (_) =>
          _AppointmentsDayDialog(day: day, appointments: appointmentsForDay),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _appointments.where((item) {
      final matchesQuery =
          _query.isEmpty ||
          item.visitor.toLowerCase().contains(_query) ||
          item.company.toLowerCase().contains(_query);
      return matchesQuery &&
          item.day == _selectedDay &&
          (_showAll || item.status != 'Cancelada');
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: _DashboardHeader(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agenda de citas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Organiza las visitas y controla cada acceso',
                      style: TextStyle(color: Color(0xFFB5C1D6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _AppointmentSummary(
                  count: filtered.length,
                  onNew: () => _showAppointmentDialog(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: _appointmentPanelDecoration(),
                  child: Column(
                    children: [
                      TextField(
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration:
                            _accessSearchDecoration(
                              'Buscar visitante o empresa...',
                            ).copyWith(
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF087FFF),
                              ),
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _AppointmentFilter(
                              label: 'Citas del día',
                              active: !_showAll,
                              onTap: () => setState(() => _showAll = false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AppointmentFilter(
                              label: 'Todas las citas',
                              active: _showAll,
                              onTap: () => setState(() => _showAll = true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              sliver: filtered.isEmpty
                  ? const SliverToBoxAdapter(child: _AppointmentEmptyState())
                  : SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => _AppointmentCard(
                        appointment: filtered[index],
                        onEdit: () => _showAppointmentDialog(
                          appointment: filtered[index],
                        ),
                        onCancel: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                              const SnackBar(
                                content: Text('Cita cancelada'),
                                backgroundColor: Color(0xFFFF1538),
                              ),
                            ),
                        onDelete: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Solicitud de eliminación enviada',
                                ),
                                backgroundColor: Color(0xFFFF1538),
                              ),
                            ),
                        onSendQr: () => ScaffoldMessenger.of(context)
                            .showSnackBar(
                              const SnackBar(
                                content: Text('Código QR enviado al visitante'),
                                backgroundColor: Color(0xFF087FFF),
                              ),
                            ),
                        onQr: () => showDialog<void>(
                          context: context,
                          builder: (_) => _AppointmentQrDialog(
                            appointment: filtered[index],
                          ),
                        ),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                child: _AppointmentsCalendar(
                  selectedDay: _selectedDay,
                  appointmentDays: const {27: 3, 28: 1},
                  onDaySelected: _selectCalendarDay,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Appointment {
  const _Appointment({
    required this.day,
    required this.time,
    required this.visitor,
    required this.company,
    required this.host,
    required this.status,
  });

  final int day;
  final String time;
  final String visitor;
  final String company;
  final String host;
  final String status;
}

BoxDecoration _appointmentPanelDecoration() {
  return BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF172846), Color(0xFF0B1428)],
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0x66087FFF)),
    boxShadow: const [
      BoxShadow(color: Color(0x22087FFF), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );
}

class _AppointmentSummary extends StatelessWidget {
  const _AppointmentSummary({required this.count, required this.onNew});

  final int count;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _appointmentPanelDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
              ),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count citas activas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Text(
                  '11 de febrero de 2026',
                  style: TextStyle(color: Color(0xFF91A2C0), fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF087FFF), Color(0xFF3D8FFF)],
                ),
              ),
              child: FilledButton.icon(
                onPressed: onNew,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Nueva',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentFilter extends StatelessWidget {
  const _AppointmentFilter({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: Ink(
        height: 38,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0x22087FFF), Color(0x3300C8FF)],
                )
              : null,
          color: active ? null : const Color(0x14087FFF),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? const Color(0xFF087FFF) : const Color(0x33087FFF),
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF91A2C0),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.onEdit,
    required this.onQr,
    required this.onCancel,
    required this.onDelete,
    required this.onSendQr,
  });

  final _Appointment appointment;
  final VoidCallback onEdit;
  final VoidCallback onQr;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final VoidCallback onSendQr;

  @override
  Widget build(BuildContext context) {
    final cancelled = appointment.status == 'Cancelada';
    final inside = appointment.status == 'Dentro';
    final statusColor = cancelled
        ? const Color(0xFFFF4D6D)
        : inside
        ? const Color(0xFF4AE3B5)
        : const Color(0xFFFFC857);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2A49), Color(0xFF0D172A), Color(0xFF09111F)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.11),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  appointment.time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  appointment.visitor,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: statusColor, blurRadius: 8)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _AppointmentInfo(
            icon: Icons.business_rounded,
            label: 'Empresa',
            value: appointment.company,
          ),
          const SizedBox(height: 7),
          _AppointmentInfo(
            icon: Icons.person_rounded,
            label: 'Anfitrión',
            value: appointment.host,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                height: 38,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    appointment.status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              _AppointmentIconButton(
                icon: Icons.edit_rounded,
                color: const Color(0xFF087FFF),
                onTap: onEdit,
              ),
              _AppointmentIconButton(
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFF00C8FF),
                onTap: onQr,
              ),
              _AppointmentActionButton(
                icon: Icons.send_rounded,
                label: 'Enviar QR',
                color: const Color(0xFF087FFF),
                onTap: onSendQr,
              ),
              _AppointmentActionButton(
                icon: Icons.cancel_outlined,
                label: 'Cancelar',
                color: const Color(0xFFFFC857),
                onTap: onCancel,
              ),
              _AppointmentActionButton(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar',
                color: const Color(0xFFFF1538),
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppointmentInfo extends StatelessWidget {
  const _AppointmentInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF087FFF)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: Color(0xFF91A2C0),
                    fontSize: 11,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Color(0xFFDCE8FA),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentIconButton extends StatelessWidget {
  const _AppointmentIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _AppointmentActionButton extends StatelessWidget {
  const _AppointmentActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentEmptyState extends StatelessWidget {
  const _AppointmentEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: _appointmentPanelDecoration(),
      child: const Column(
        children: [
          Icon(Icons.event_busy_rounded, color: Color(0xFF087FFF), size: 38),
          SizedBox(height: 10),
          Text(
            'No hay citas para esta selección',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AppointmentsDayDialog extends StatelessWidget {
  const _AppointmentsDayDialog({required this.day, required this.appointments});

  final int day;
  final List<_Appointment> appointments;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFF111D35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                      ),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Citas del $day de noviembre',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${appointments.length} ${appointments.length == 1 ? 'cita registrada' : 'citas registradas'}',
                style: const TextStyle(color: Color(0xFF91A2C0), fontSize: 12),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: appointments.isEmpty
                    ? const _AppointmentEmptyState()
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: appointments.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => Container(
                          padding: const EdgeInsets.all(12),
                          decoration: _appointmentPanelDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x25087FFF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      appointments[index].time,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      appointments[index].visitor,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                appointments[index].company,
                                style: const TextStyle(
                                  color: Color(0xFF91A2C0),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Anfitrión: ${appointments[index].host}',
                                style: const TextStyle(
                                  color: Color(0xFFCCD6E8),
                                  fontSize: 11,
                                ),
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

class _AppointmentsCalendar extends StatelessWidget {
  const _AppointmentsCalendar({
    required this.selectedDay,
    required this.onDaySelected,
    required this.appointmentDays,
  });

  final int selectedDay;
  final Map<int, int> appointmentDays;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final weeks = const <List<int?>>[
      [26, 27, 28, 29, 30, 31, 1],
      [2, 3, 4, 5, 6, 7, 8],
      [9, 10, 11, 12, 13, 14, 15],
      [16, 17, 18, 19, 20, 21, 22],
      [23, 24, 25, 26, 27, 28, 29],
    ];

    return Container(
      decoration: _appointmentPanelDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calendario',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'noviembre de 2026',
                        style: TextStyle(
                          color: Color(0xFF087FFF),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _AppointmentIconButton(
                  icon: Icons.chevron_left_rounded,
                  color: const Color(0xFF087FFF),
                  onTap: () {},
                ),
                const SizedBox(width: 7),
                _AppointmentIconButton(
                  icon: Icons.chevron_right_rounded,
                  color: const Color(0xFF087FFF),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              children: [
                _CalendarWeekday('Lun'),
                _CalendarWeekday('Mar'),
                _CalendarWeekday('Mié'),
                _CalendarWeekday('Jue'),
                _CalendarWeekday('Vie'),
                _CalendarWeekday('Sáb'),
                _CalendarWeekday('Dom'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 5, 7, 12),
            child: Column(
              children: weeks.map((week) {
                return Row(
                  children: week.map((day) {
                    final active = day == selectedDay;
                    final appointmentCount = appointmentDays[day] ?? 0;
                    return Expanded(
                      child: InkWell(
                        onTap: day == null ? null : () => onDaySelected(day),
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0x14087FFF)),
                              left: BorderSide(color: Color(0x14087FFF)),
                            ),
                          ),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: active
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF087FFF),
                                        Color(0xFF00C8FF),
                                      ],
                                    )
                                  : null,
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  day == null ? '' : '$day',
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : const Color(0xFFBCC8DB),
                                    fontSize: 11,
                                    fontWeight: active
                                        ? FontWeight.w900
                                        : FontWeight.w500,
                                  ),
                                ),
                                if (appointmentCount > 0)
                                  Positioned(
                                    bottom: -8,
                                    child: Container(
                                      width: 18,
                                      height: 14,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: active
                                            ? Colors.white
                                            : const Color(0xFF087FFF),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        '$appointmentCount',
                                        style: TextStyle(
                                          color: active
                                              ? const Color(0xFF087FFF)
                                              : Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarWeekday extends StatelessWidget {
  const _CalendarWeekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF087FFF),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AppointmentDialog extends StatelessWidget {
  const _AppointmentDialog({this.appointment});

  final _Appointment? appointment;

  @override
  Widget build(BuildContext context) {
    final editing = appointment != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: const Color(0xFF111D35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                editing ? 'Editar cita' : 'Nueva cita',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const _HostFormField('Empresa'),
              const SizedBox(height: 12),
              const _HostFormField('Visitante'),
              const SizedBox(height: 12),
              const _HostFormField('Anfitrión'),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: _HostFormField('Fecha')),
                  SizedBox(width: 10),
                  Expanded(child: _HostFormField('Hora')),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF087FFF), Color(0xFF3D8FFF)],
                    ),
                  ),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                    child: Text(
                      editing ? 'Guardar cambios' : 'Agregar cita',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
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

class _AppointmentQrDialog extends StatefulWidget {
  const _AppointmentQrDialog({required this.appointment});

  final _Appointment appointment;

  @override
  State<_AppointmentQrDialog> createState() => _AppointmentQrDialogState();
}

class _AppointmentQrDialogState extends State<_AppointmentQrDialog> {
  final _qrBoundaryKey = GlobalKey();
  bool _downloading = false;

  Future<void> _downloadQr() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final boundary =
          _qrBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name:
            'visita-${widget.appointment.visitor.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-')}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR descargado en la galería')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No fue posible guardar el código QR')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      backgroundColor: const Color(0xFF111D35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.qr_code_2_rounded,
              color: Color(0xFF087FFF),
              size: 34,
            ),
            const SizedBox(height: 10),
            const Text(
              'Código QR de visita',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _qrBoundaryKey,
              child: Container(
                width: 210,
                height: 210,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data:
                      'visita:${widget.appointment.visitor}:${widget.appointment.company}',
                  version: QrVersions.auto,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF07101F),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF07101F),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.appointment.visitor,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _downloading ? null : _downloadQr,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF087FFF),
                ),
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_rounded, color: Colors.white),
                label: Text(
                  _downloading ? 'Descargando...' : 'Descargar QR',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF087FFF),
                ),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyLogbookPage extends StatefulWidget {
  const _DailyLogbookPage();

  @override
  State<_DailyLogbookPage> createState() => _DailyLogbookPageState();
}

class _DailyLogbookPageState extends State<_DailyLogbookPage> {
  String _filter = 'Todos';
  String _query = '';

  static const _movements = [
    _LogbookMovement(
      name: 'Abner Alejandro Soto',
      time: '09:04',
      date: '29 oct',
      type: 'Ingreso',
      folio: '99928727',
      company: 'Registro manual',
      detail: 'Checklist completado',
      color: Color(0xFF087FFF),
      icon: Icons.login_rounded,
    ),
    _LogbookMovement(
      name: 'Rafael Gonzales Castañeda',
      time: '08:57',
      date: '29 oct',
      type: 'Llegada',
      folio: '53597403',
      company: 'Registro manual',
      detail: 'Pendiente de autorización',
      color: Color(0xFF26E2A7),
      icon: Icons.call_received_rounded,
    ),
    _LogbookMovement(
      name: 'Pedro Hernandez',
      time: '08:12',
      date: '29 oct',
      type: 'Ingreso',
      folio: '94174021',
      company: 'Soluciones Industriales del Norte',
      detail: 'Anfitrión: Administrador de prueba',
      color: Color(0xFF087FFF),
      icon: Icons.login_rounded,
    ),
    _LogbookMovement(
      name: 'Jesus Efren Hinojosa Guerra',
      time: '18:58',
      date: '28 oct',
      type: 'Salida',
      folio: '41720855',
      company: 'Soluciones Industriales del Norte',
      detail: 'Salida registrada correctamente',
      color: Color(0xFFE53E4B),
      icon: Icons.logout_rounded,
    ),
  ];

  Future<void> _openReferenceCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _ReferenceCodeDialog(),
    );
    if (code != null && code.trim().isNotEmpty) {
      _openRegister(reference: code.trim());
    }
  }

  Future<void> _openQrScanner() async {
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _QrScannerDialog(),
    );
    if (code != null && code.trim().isNotEmpty) {
      _openRegister(reference: code.trim());
    }
  }

  void _openRegister({String? reference}) {
    showDialog<void>(
      context: context,
      builder: (_) => _LogbookRegisterDialog(reference: reference),
    );
  }

  void _openMovement(_LogbookMovement movement) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogbookMovementSheet(movement: movement),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _movements.where((movement) {
      final matchesFilter = _filter == 'Todos' || movement.type == _filter;
      final normalized = _query.toLowerCase();
      final matchesQuery =
          normalized.isEmpty ||
          movement.name.toLowerCase().contains(normalized) ||
          movement.company.toLowerCase().contains(normalized) ||
          movement.folio.contains(normalized);
      return matchesFilter && matchesQuery;
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bitácora diaria',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Movimientos y registros de recepción',
                      style: TextStyle(color: Color(0xFFB5C1D6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 38) / 2,
                      child: const _LogbookMetric(
                        value: '4',
                        label: 'Personas dentro',
                        icon: Icons.groups_rounded,
                        color: Color(0xFF087FFF),
                      ),
                    ),
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 38) / 2,
                      child: const _LogbookMetric(
                        value: '2',
                        label: 'Llegadas',
                        icon: Icons.call_received_rounded,
                        color: Color(0xFF26E2A7),
                      ),
                    ),
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 38) / 2,
                      child: const _LogbookMetric(
                        value: '1',
                        label: 'Ingresos',
                        icon: Icons.login_rounded,
                        color: Color(0xFF087FFF),
                      ),
                    ),
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 38) / 2,
                      child: const _LogbookMetric(
                        value: '1',
                        label: 'Salidas',
                        icon: Icons.logout_rounded,
                        color: Color(0xFFE53E4B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1730),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x4D087FFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Acceso rápido',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre, folio o empresa',
                          hintStyle: const TextStyle(
                            color: Color(0xFF77829B),
                            fontSize: 12,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF087FFF),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF070D1C),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: (MediaQuery.sizeOf(context).width - 38) / 2,
                            child: _LogbookActionButton(
                              label: 'Nuevo registro',
                              icon: Icons.login_rounded,
                              onTap: () => _openRegister(),
                            ),
                          ),
                          SizedBox(
                            width: (MediaQuery.sizeOf(context).width - 38) / 2,
                            child: _LogbookActionButton(
                              label: 'Introducir código',
                              icon: Icons.pin_rounded,
                              outlined: true,
                              onTap: _openReferenceCode,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _LogbookActionButton(
                          label: 'Escanear código QR',
                          icon: Icons.qr_code_scanner_rounded,
                          outlined: true,
                          onTap: _openQrScanner,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final filter in const [
                      'Todos',
                      'Llegada',
                      'Ingreso',
                      'Salida',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                          selectedColor: const Color(0xFF087FFF),
                          backgroundColor: const Color(0xFF111B31),
                          side: BorderSide(
                            color: _filter == filter
                                ? const Color(0xFF087FFF)
                                : const Color(0x33FFFFFF),
                          ),
                          labelStyle: TextStyle(
                            color: _filter == filter
                                ? Colors.white
                                : const Color(0xFFBFC8DD),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
              sliver: SliverList.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _LogbookMovementCard(
                  movement: filtered[index],
                  onTap: () => _openMovement(filtered[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogbookMovement {
  const _LogbookMovement({
    required this.name,
    required this.time,
    required this.date,
    required this.type,
    required this.folio,
    required this.company,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String name;
  final String time;
  final String date;
  final String type;
  final String folio;
  final String company;
  final String detail;
  final Color color;
  final IconData icon;
}

class _LogbookMetric extends StatelessWidget {
  const _LogbookMetric({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .20), const Color(0xFF101A30)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCBD4E7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogbookActionButton extends StatelessWidget {
  const _LogbookActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: outlined
            ? null
            : const LinearGradient(
                colors: [Color(0xFF087FFF), Color(0xFF0359C8)],
              ),
        borderRadius: BorderRadius.circular(12),
        border: outlined ? Border.all(color: const Color(0xFF087FFF)) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogbookMovementCard extends StatelessWidget {
  const _LogbookMovementCard({required this.movement, required this.onTap});

  final _LogbookMovement movement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1730),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: movement.color.withValues(alpha: .42)),
            boxShadow: [
              BoxShadow(
                color: movement.color.withValues(alpha: .08),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: movement.color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(movement.icon, color: movement.color, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            movement.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${movement.date} · ${movement.time}',
                          style: const TextStyle(
                            color: Color(0xFF9FAAC0),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      movement.company,
                      style: const TextStyle(
                        color: Color(0xFFBBC4D7),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      movement.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8F9AB1),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: movement.color.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      movement.type,
                      style: TextStyle(
                        color: movement.color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF72809D),
                    size: 20,
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

class _LogbookRegisterDialog extends StatelessWidget {
  const _LogbookRegisterDialog({this.reference});

  final String? reference;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: const Color(0xFF0A1530),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x991A74FF)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: width < 400 ? 620 : 680,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF123D7A), Color(0xFF0D1730)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF087FFF).withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x77087FFF)),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: Color(0xFF087FFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registrar nueva visita',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'La llegada inicial se tomará automáticamente',
                            style: TextStyle(
                              color: Color(0xFFBFCBDF),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFAAB7D0),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (reference != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0x1A087FFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x66087FFF)),
                        ),
                        child: Text(
                          'Código encontrado: $reference',
                          style: const TextStyle(
                            color: Color(0xFF8FC6FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    const Text(
                      'Persona registrada como',
                      style: TextStyle(
                        color: Color(0xFFDCE4F5),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: 'Visitante registrado',
                      dropdownColor: const Color(0xFF111B31),
                      decoration: _logbookDialogInputDecoration(),
                      items: const [
                        DropdownMenuItem(
                          value: 'Visitante registrado',
                          child: Text('Visitante registrado'),
                        ),
                        DropdownMenuItem(
                          value: 'Contratista',
                          child: Text('Contratista'),
                        ),
                        DropdownMenuItem(
                          value: 'Proveedor',
                          child: Text('Proveedor'),
                        ),
                      ],
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Selecciona un registro',
                      style: TextStyle(
                        color: Color(0xFFDCE4F5),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      hint: const Text(
                        'Selecciona un registro',
                        style: TextStyle(color: Color(0xFF71809C)),
                      ),
                      dropdownColor: const Color(0xFF111B31),
                      decoration: _logbookDialogInputDecoration(),
                      items: const [],
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Observaciones',
                      style: TextStyle(
                        color: Color(0xFFDCE4F5),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const TextField(
                      maxLines: 3,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Detalle adicional (opcional)',
                        hintStyle: TextStyle(
                          color: Color(0xFF71809C),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Color(0xFF070D1C),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF263650)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF263650)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF087FFF)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111B31),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF263650)),
                      ),
                      child: const Text(
                        'Empresa y anfitrión se mostrarán como N/A para esta visita.',
                        style: TextStyle(
                          color: Color(0xFF9BA8C2),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF087FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          'Registrar llegada',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _logbookDialogInputDecoration() {
  return InputDecoration(
    filled: true,
    fillColor: const Color(0xFF070D1C),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF263650)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF263650)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF087FFF)),
    ),
  );
}

class _ReferenceCodeDialog extends StatefulWidget {
  const _ReferenceCodeDialog();

  @override
  State<_ReferenceCodeDialog> createState() => _ReferenceCodeDialogState();
}

class _ReferenceCodeDialogState extends State<_ReferenceCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pin_rounded, color: Color(0xFF087FFF), size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Introducir código',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Ingresa el código de referencia o folio de la visita.',
              style: TextStyle(color: Color(0xFF9FAAC0), fontSize: 12),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
              decoration: _logbookDialogInputDecoration().copyWith(
                hintText: 'Ej. 00000000',
                hintStyle: const TextStyle(color: Color(0xFF596681)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Color(0xFFAEB8CC)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF087FFF),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, _controller.text),
                    child: const Text('Buscar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScannerDialog extends StatefulWidget {
  const _QrScannerDialog();

  @override
  State<_QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<_QrScannerDialog> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 520,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              onDetect: (capture) {
                if (_handled) return;
                final value = capture.barcodes.firstOrNull?.rawValue;
                if (value == null || value.isEmpty) return;
                _handled = true;
                Navigator.pop(context, value);
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC07101F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Escanea el QR de la visita',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xCC07101F),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFF087FFF), width: 3),
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogbookField extends StatelessWidget {
  const _LogbookField({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9FAAC0)),
        filled: true,
        fillColor: const Color(0xFF070D1C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _LogbookMovementSheet extends StatelessWidget {
  const _LogbookMovementSheet({required this.movement});
  final _LogbookMovement movement;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0A1224),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          12,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF46516A),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              movement.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Folio ${movement.folio} · ${movement.date} · ${movement.time}',
              style: const TextStyle(color: Color(0xFF9FAAC0), fontSize: 11),
            ),
            const SizedBox(height: 18),
            _LogbookDetailRow(
              icon: Icons.business_rounded,
              label: 'Empresa',
              value: movement.company,
            ),
            _LogbookDetailRow(
              icon: movement.icon,
              label: 'Movimiento',
              value: movement.type,
            ),
            _LogbookDetailRow(
              icon: Icons.notes_rounded,
              label: 'Observaciones',
              value: movement.detail,
            ),
            const SizedBox(height: 18),
            if (movement.type != 'Salida')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E4B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Registrar salida'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogbookDetailRow extends StatelessWidget {
  const _LogbookDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111B31),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF087FFF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF7F8CA6), fontSize: 9),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentPage extends StatelessWidget {
  const _EquipmentPage();

  static final _declarations = const [
    _EquipmentDeclaration(
      person: 'Jesus Efren Hinojosa Guerra',
      company: 'Soluciones Industriales del Norte S.A. de C.V.',
      date: '2026-10-28 18:00',
      entryComplete: true,
      exitComplete: false,
      items: 1,
      linked: true,
    ),
    _EquipmentDeclaration(
      person: 'Jesus Efren Hinojosa Guerra',
      company: 'Soluciones Industriales del Norte S.A. de C.V.',
      date: '2026-10-27 18:00',
      entryComplete: true,
      exitComplete: true,
      items: 1,
      linked: true,
    ),
    _EquipmentDeclaration(
      person: 'Jesus Efren Hinojosa Guerra',
      company: 'Soluciones Industriales del Norte S.A. de C.V.',
      date: '2026-10-27 18:00',
      entryComplete: true,
      exitComplete: false,
      items: 1,
      linked: true,
    ),
    _EquipmentDeclaration(
      person: 'Jesus Efren Hinojosa Guerra',
      company: 'Soluciones Industriales del Norte S.A. de C.V.',
      date: 'Sin cita vinculada',
      entryComplete: true,
      exitComplete: true,
      items: 1,
      linked: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equipo y herramientas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Declaraciones y verificaciones de entrada y salida',
                      style: TextStyle(color: Color(0xFFB5C1D6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF17243D), Color(0xFF0B1427)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF087FFF)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                              ),
                            ),
                            child: const Icon(
                              Icons.build_circle_outlined,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_declarations.length} declaraciones',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _GradientRegisterButton(
                            label: 'Nueva',
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  const _EquipmentDeclarationDialog(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: _accessSearchDecoration(
                          'Buscar persona o empresa...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
              sliver: SliverList.separated(
                itemCount: _declarations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _EquipmentDeclarationCard(
                  declaration: _declarations[index],
                  onOpen: () => showDialog<void>(
                    context: context,
                    builder: (_) => _EquipmentDetailDialog(
                      declaration: _declarations[index],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EquipmentDeclaration {
  const _EquipmentDeclaration({
    required this.person,
    required this.company,
    required this.date,
    required this.entryComplete,
    required this.exitComplete,
    required this.items,
    required this.linked,
  });

  final String person;
  final String company;
  final String date;
  final bool entryComplete;
  final bool exitComplete;
  final int items;
  final bool linked;
}

class _EquipmentDeclarationCard extends StatelessWidget {
  const _EquipmentDeclarationCard({
    required this.declaration,
    required this.onOpen,
  });

  final _EquipmentDeclaration declaration;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF192846), Color(0xFF0D172A), Color(0xFF09111F)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66087FFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29087FFF),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                  ),
                ),
                child: const Icon(Icons.handyman_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      declaration.person,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      declaration.company,
                      style: const TextStyle(
                        color: Color(0xFF67ACFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _EquipmentStatus(
                  icon: Icons.login_rounded,
                  label: 'Entrada',
                  complete: declaration.entryComplete,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _EquipmentStatus(
                  icon: Icons.logout_rounded,
                  label: 'Salida',
                  complete: declaration.exitComplete,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ExternalMetricTile(
            icon: Icons.calendar_month_outlined,
            label: declaration.linked ? 'Cita' : 'Cita',
            value: declaration.date,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF087FFF), Color(0xFF3D8FFF)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D087FFF),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text(
                  'Abrir',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentStatus extends StatelessWidget {
  const _EquipmentStatus({
    required this.icon,
    required this.label,
    required this.complete,
  });

  final IconData icon;
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final color = complete ? const Color(0xFF4AE3B5) : const Color(0xFF087FFF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$label: ${complete ? 'Completa' : 'Pendiente'}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentDeclarationDialog extends StatelessWidget {
  const _EquipmentDeclarationDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: const Color(0xFF111D35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crear declaración de equipo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              const _HostFormField('Empresa'),
              const SizedBox(height: 12),
              const _HostFormField('Cita vinculada (opcional)'),
              const SizedBox(height: 12),
              const _HostFormField('Personal externo (opcional)'),
              const SizedBox(height: 12),
              const _HostFormField('Nombre de la persona'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF087FFF),
                        Color(0xFF3D8FFF),
                        Color(0xFF00C8FF),
                      ],
                    ),
                  ),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                    child: const Text(
                      'Crear enlace de declaración',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
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

class _EquipmentDetailDialog extends StatefulWidget {
  const _EquipmentDetailDialog({required this.declaration});

  final _EquipmentDeclaration declaration;

  @override
  State<_EquipmentDetailDialog> createState() => _EquipmentDetailDialogState();
}

class _EquipmentDetailDialogState extends State<_EquipmentDetailDialog> {
  bool _entryChecked = false;
  bool _exitChecked = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      backgroundColor: const Color(0xFF111D35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                      ),
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.declaration.person,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.declaration.company,
                style: const TextStyle(color: Color(0xFF67ACFF), fontSize: 11),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x15087FFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x33087FFF)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Equipo declarado',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Taladro inalámbrico',
                      style: TextStyle(
                        color: Color(0xFFDCE8FA),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'DeWalt · DCD791 · serie DW-24018 · Amarillo',
                      style: TextStyle(color: Color(0xFF94A4BF), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _EquipmentChecklist(
                title: 'Checklist de entrada',
                checked: _entryChecked,
                onChecked: (value) => setState(() => _entryChecked = value),
              ),
              const SizedBox(height: 12),
              _EquipmentChecklist(
                title: 'Checklist de salida',
                checked: _exitChecked,
                onChecked: (value) => setState(() => _exitChecked = value),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF087FFF),
                        Color(0xFF3D8FFF),
                        Color(0xFF00C8FF),
                      ],
                    ),
                  ),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                    child: const Text(
                      'Guardar verificaciones',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
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

class _EquipmentChecklist extends StatelessWidget {
  const _EquipmentChecklist({
    required this.title,
    required this.checked,
    required this.onChecked,
  });

  final String title;
  final bool checked;
  final ValueChanged<bool> onChecked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF091325),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33087FFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                checked ? 'Verificado' : 'Pendiente',
                style: TextStyle(
                  color: checked
                      ? const Color(0xFF4AE3B5)
                      : const Color(0xFF087FFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFF087FFF),
            checkColor: Colors.white,
            title: const Text(
              'Equipo y características revisadas',
              style: TextStyle(color: Color(0xFFCCD6E8), fontSize: 12),
            ),
            value: checked,
            onChanged: (value) => onChecked(value ?? false),
          ),
        ],
      ),
    );
  }
}

class _HostsPage extends StatelessWidget {
  const _HostsPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anfitriones',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Registro de anfitriones de la organización',
                      style: TextStyle(color: Color(0xFFB5C1D6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF17243D), Color(0xFF0B1427)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF087FFF)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFF087FFF),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Anfitriones',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Text(
                            '0 cuentas',
                            style: TextStyle(
                              color: Color(0xFF087FFF),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 38,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(19),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF087FFF),
                                    Color(0xFF3D8FFF),
                                    Color(0xFF00C8FF),
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x660087FF),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FilledButton.icon(
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  barrierColor: const Color(0xE0000000),
                                  builder: (_) => const _HostFormDialog(),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(44, 38),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 17),
                                label: const Text(
                                  'Registrar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por usuario, departamento, puesto o correo...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF73809A),
                            fontSize: 11,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF087FFF),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF091325),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF087FFF),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 210,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1425),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x330087FF)),
                        ),
                        child: const Text(
                          'Todavía no hay anfitriones registrados.',
                          style: TextStyle(
                            color: Color(0xFFB5C1D6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostFormDialog extends StatelessWidget {
  const _HostFormDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF111D32),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFF087FFF)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF087FFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF172747),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Registrar anfitrión',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Selecciona una cuenta de Accesos para copiar sus datos.',
              style: TextStyle(color: Color(0xFFAAB5C7), fontSize: 12),
            ),
            const SizedBox(height: 18),
            const _HostFormField('Nombre completo'),
            const SizedBox(height: 12),
            const _HostFormField('Login (usuario)'),
            const SizedBox(height: 12),
            const _HostFormField('Correo electrónico'),
            const SizedBox(height: 12),
            const _HostFormField('Departamento'),
            const SizedBox(height: 12),
            const _HostFormField('Puesto'),
            const SizedBox(height: 12),
            const _HostFormField('Teléfono', keyboardType: TextInputType.phone),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF087FFF),
                      Color(0xFF3D8FFF),
                      Color(0xFF00C8FF),
                    ],
                  ),
                ),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Registrar anfitrión',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostFormField extends StatelessWidget {
  const _HostFormField(this.label, {this.keyboardType});

  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD8E3F4),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF091325),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF087FFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF087FFF), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _DepartmentsPage extends StatelessWidget {
  const _DepartmentsPage();

  static const departments = [
    'ASUNTOS INTERNOS',
    'AYMSC',
    'CALIDAD',
    'CAPACITACION',
    'COMPRAS',
    'CONTRALORIA',
    'CYM HIDALGO',
    'CYM MT',
    'CYM MTY',
    'CYM NG',
    'CYM NL',
    'CYM TJ',
    'DIRECCION',
    'LEGAL',
    'MONITOREO',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Departamento',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Administra departamentos y consulta los anfitriones vinculados',
                      style: TextStyle(
                        color: const Color(0xFFB5C1D6).withValues(alpha: .85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xE610172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF087FFF)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0x221B8AFF),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: const Color(0xFF087FFF),
                              ),
                            ),
                            child: const Icon(
                              Icons.account_tree_rounded,
                              color: Color(0xFF087FFF),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Departamentos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${departments.length} departamentos',
                            style: const TextStyle(
                              color: Color(0xFF087FFF),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 38,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(19),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF087FFF),
                                    Color(0xFF3D8FFF),
                                    Color(0xFF00C8FF),
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x660087FF),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FilledButton.icon(
                                onPressed: () => _showDepartmentForm(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text(
                                  'Registrar departamento',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.crossAxisExtent;
                  final columns = width >= 720
                      ? 4
                      : width >= 500
                      ? 3
                      : 2;
                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _DepartmentCard(departments[index]),
                      childCount: departments.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 148,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showDepartmentForm(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xE0000000),
      builder: (_) => const _DepartmentFormDialog(),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF087FFF),
            Color(0xFF30D6FF),
            Color(0xFF087FFF),
            Color(0xFFFF3155),
          ],
          stops: [0, .28, .72, 1],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300087FF),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.3),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13.7),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF17243D), Color(0xFF0B1427), Color(0xFF10172D)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0x261B8AFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x660087FF)),
                  ),
                  child: const Icon(
                    Icons.account_tree_outlined,
                    color: Color(0xFF087FFF),
                    size: 18,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0x330087FF), Color(0x1600D4FF)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0x550087FF)),
                  ),
                  child: const Text(
                    '0 anfitriones vinculados',
                    style: TextStyle(
                      color: Color(0xFF7BCBFF),
                      fontSize: 7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _DepartmentActionButton.edit()),
                const SizedBox(width: 6),
                Expanded(child: _DepartmentActionButton.delete()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentActionButton extends StatelessWidget {
  const _DepartmentActionButton({required this.label, required this.gradient});

  factory _DepartmentActionButton.edit() => const _DepartmentActionButton(
    label: 'Editar',
    gradient: [Color(0xFF087FFF), Color(0xFF00B7E8)],
  );

  factory _DepartmentActionButton.delete() => const _DepartmentActionButton(
    label: 'Eliminar',
    gradient: [Color(0xFFFF3155), Color(0xFFD91B50)],
  );

  final String label;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: .32),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C162B),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: gradient.first == const Color(0xFFFF3155)
                  ? const Color(0xFFFF667A)
                  : const Color(0xFF72C8FF),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DepartmentFormDialog extends StatelessWidget {
  const _DepartmentFormDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111D32),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF087FFF)),
          boxShadow: const [
            BoxShadow(color: Color(0x800087FF), blurRadius: 28),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF087FFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_tree_rounded,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF172747),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Registrar departamento',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Captura el nombre del departamento.',
              style: TextStyle(color: Color(0xFFAAB5C7), fontSize: 12),
            ),
            const SizedBox(height: 22),
            const Text(
              'Nombre del departamento',
              style: TextStyle(
                color: Color(0xFFD8E3F4),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF091325),
                hintText: 'Ej. Recursos Humanos',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF087FFF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF087FFF),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF087FFF),
                      Color(0xFF3D8FFF),
                      Color(0xFF00C8FF),
                    ],
                  ),
                ),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Registrar departamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceptionDrawer extends StatelessWidget {
  const _ReceptionDrawer({
    this.activeSection,
    this.onHome,
    this.onDepartments,
    this.onHosts,
    this.onAccesses,
    this.onExternalCompanies,
    this.onExternalStaff,
    this.onEquipment,
    this.onAppointments,
    this.onLogbook,
  });

  final String? activeSection;
  final VoidCallback? onHome;
  final VoidCallback? onDepartments;
  final VoidCallback? onHosts;
  final VoidCallback? onAccesses;
  final VoidCallback? onExternalCompanies;
  final VoidCallback? onExternalStaff;
  final VoidCallback? onEquipment;
  final VoidCallback? onAppointments;
  final VoidCallback? onLogbook;

  @override
  Widget build(BuildContext context) {
    final currentSection = activeSection ?? 'home';
    return Drawer(
      width: 300,
      backgroundColor: Colors.transparent,
      elevation: 24,
      shadowColor: const Color(0xCC087FFF),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10172D), Color(0xFF080D1C), Color(0xFF050713)],
            stops: [0, .48, 1],
          ),
          border: Border(
            right: BorderSide(color: Color(0x9900A8FF), width: .7),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -35,
              right: -70,
              child: Container(
                width: 190,
                height: 190,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x4D087FFF),
                      Color(0x120087FF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 310,
              left: -110,
              child: Container(
                width: 220,
                height: 220,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x2500D4FF), Colors.transparent],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                children: [
                  Container(
                    height: 104,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF202A49), Color(0xFF10172A)],
                      ),
                      border: Border.all(color: const Color(0x4300A8FF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x330087FF),
                          blurRadius: 22,
                          offset: Offset(0, 9),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/images/cymez-reception-logo.webp',
                          cacheWidth: 480,
                          height: 78,
                          fit: BoxFit.contain,
                        ),
                        Positioned(
                          right: 9,
                          top: 9,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0x19FFFFFF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x33B4D9FF),
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 17,
                                color: Color(0xFFC9D7EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _DrawerItem(
                    icon: Icons.home_rounded,
                    label: 'Inicio',
                    active: currentSection == 'home',
                    onTap: onHome,
                  ),
                  const _DrawerLabel('Organización'),
                  _DrawerItem(
                    icon: Icons.apartment_rounded,
                    label: 'Departamento',
                    active: currentSection == 'departments',
                    onTap: onDepartments,
                  ),
                  _DrawerItem(
                    icon: Icons.meeting_room_rounded,
                    label: 'Anfitriones',
                    active: currentSection == 'hosts',
                    onTap: onHosts,
                  ),
                  _DrawerItem(
                    icon: Icons.vpn_key_rounded,
                    label: 'Accesos',
                    active: currentSection == 'accesses',
                    onTap: onAccesses,
                  ),
                  const _DrawerLabel('Externos'),
                  _DrawerItem(
                    icon: Icons.business_rounded,
                    label: 'Contratistas/proveedores y visitantes',
                    active: currentSection == 'external_companies',
                    onTap: onExternalCompanies,
                  ),
                  _DrawerItem(
                    icon: Icons.badge_rounded,
                    label: 'Personal de externos',
                    active: currentSection == 'external_staff',
                    onTap: onExternalStaff,
                  ),
                  _DrawerItem(
                    icon: Icons.handyman_rounded,
                    label: 'Equipo y herramientas',
                    active: currentSection == 'equipment',
                    onTap: onEquipment,
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Agenda de citas',
                    active: currentSection == 'appointments',
                    onTap: onAppointments,
                  ),
                  _DrawerItem(
                    icon: Icons.assignment_rounded,
                    label: 'Bitácora diaria',
                    active: currentSection == 'logbook',
                    onTap: onLogbook,
                  ),
                  const _DrawerLabel('Programador'),
                  const _DrawerItem(
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'Acceso corporativo',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerLabel extends StatelessWidget {
  const _DrawerLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 7),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF087FFF),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Color(0xCC087FFF), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8798B8),
              fontSize: 9.5,
              letterSpacing: 1.55,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x4D087FFF), Colors.transparent],
                ),
              ),
              child: SizedBox(height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.of(context).pop();
        onTap?.call();
      },
      dense: true,
      minVerticalPadding: 9,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.transparent,
      selected: active,
      selectedTileColor: const Color(0x18FF3155),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFFF3155), Color(0xFFCF1741)],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF182441), Color(0xFF11182A)],
                ),
          border: Border.all(
            color: active ? const Color(0xFFFF7189) : const Color(0x260087FF),
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x66FF3155),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 19,
          color: active ? Colors.white : const Color(0xFFC4CEE1),
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFFDDE2EE),
          fontSize: 12.5,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          height: 1.25,
        ),
      ),
      trailing: active
          ? Container(
              width: 5,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFFF3155),
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFFF3155), blurRadius: 10),
                ],
              ),
            )
          : null,
    );
  }
}

class _HomeMetricCard extends StatelessWidget {
  const _HomeMetricCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29344D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFDCE2EF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _HomePanel extends StatelessWidget {
  const _HomePanel({required this.title, required this.child, this.height});

  final String title;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: height == null
          ? null
          : BoxConstraints.tightFor(height: height),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF29344D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({
    required this.initials,
    required this.name,
    required this.detail,
    required this.color,
  });

  final String initials;
  final String name;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Text(
              initials,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF8996B0),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF697996)),
        ],
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  const _DonutChart();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 0.72,
                strokeWidth: 13,
                backgroundColor: const Color(0xFF29324A),
                color: const Color(0xFFFF3155),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '72%',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    'Visitas',
                    style: TextStyle(color: Color(0xFF8D99B1), fontSize: 10),
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

class _ActivityBars extends StatelessWidget {
  const _ActivityBars();

  @override
  Widget build(BuildContext context) {
    const bars = [0.38, 0.58, 0.48, 0.82, 0.66, 0.92];
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: bars
            .map(
              (value) => Container(
                width: 10,
                height: 105 * value,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFF355DFF), Color(0xFFFF3155)],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
