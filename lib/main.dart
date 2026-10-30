// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _red = Color(0xFFFF1538);
const _blue = Color(0xFF087FFF);
const _white = Color(0xFFF4F7FF);
const _mutedWhite = Color(0xFFD4DDF0);
const _welcomeDescriptionFirstLine = 'Registra tus visitas de forma rápida,';
const _logoArtworkWidthRatio = 0.764;

TextStyle _descriptionTextStyle(bool compact) => TextStyle(
  color: _mutedWhite,
  fontSize: compact ? 13 : 15,
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
      ),
      home: const ReceptionWelcomePage(),
    );
  }
}

class ReceptionWelcomePage extends StatelessWidget {
  const ReceptionWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/reception-welcome-background.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxHeight < 700 || constraints.maxWidth < 500;
                final horizontalPadding = constraints.maxWidth < 360
                    ? 20.0
                    : 28.0;
                final contentWidth =
                    (constraints.maxWidth - horizontalPadding * 2).clamp(
                      0.0,
                      440.0,
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
                final headlineFontSize = _headlineFontSize(
                  descriptionWidth,
                  textDirection,
                );
                final logoWidth = [
                  contentWidth,
                  descriptionWidth / _logoArtworkWidthRatio,
                ].reduce((left, right) => left < right ? left : right);
                final logoScale =
                    (descriptionWidth / (logoWidth * _logoArtworkWidthRatio))
                        .clamp(1.0, 1.6);
                final logoHeight = logoWidth / 1.5 * logoScale;
                final benefitCardHeight = (contentWidth / 2.8).clamp(
                  112.0,
                  148.0,
                );
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
                            offset: const Offset(0, 10),
                            child: _WelcomeMessage(
                              compact: compact,
                              headlineFontSize: headlineFontSize,
                            ),
                          ),
                          _WelcomeBenefits(height: benefitCardHeight),
                          _StartButton(
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
                          const _PageIndicator(),
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
    );
  }
}

class ReceptionOnboardingPage extends StatelessWidget {
  const ReceptionOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/onboarding-register-background.png',
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
                final horizontalPadding = constraints.maxWidth < 360
                    ? 18.0
                    : 38.0;
                final contentWidth =
                    (constraints.maxWidth - horizontalPadding * 2).clamp(
                      0.0,
                      440.0,
                    );
                final logoWidth = (contentWidth * 0.55).clamp(130.0, 175.0);
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: logoHeight,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Image.asset(
                            'assets/images/cymez-reception-logo.png',
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
    );
  }
}

class _RegistrationOnboardingCopy extends StatelessWidget {
  const _RegistrationOnboardingCopy({
    required this.compact,
    required this.veryCompact,
  });

  final bool compact;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: _white,
      fontSize: veryCompact
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Registra tus', style: titleStyle),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF28BFFF), Color(0xFFFF2D86)],
          ).createShader(bounds),
          child: Text(
            'visitas',
            style: titleStyle.copyWith(
              fontSize: veryCompact
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
          style: TextStyle(
            color: const Color(0xFF36BFFF),
            fontSize: veryCompact
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
          style: TextStyle(
            color: _white,
            fontSize: veryCompact
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/onboarding-control-background.png',
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
                          'assets/images/cymez-reception-logo.png',
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
                      const _PageIndicator(activeIndex: 2),
                      if (kIsWeb) const _WebHomeIndicator(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ReceptionReadyOnboardingPage extends StatelessWidget {
  const ReceptionReadyOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/onboarding-ready-background.png',
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
                          'assets/images/cymez-reception-logo.png',
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
                      const _PageIndicator(activeIndex: 3),
                      if (kIsWeb && !compact) const _WebHomeIndicator(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
            'assets/images/onboarding-benefits-bar.png',
            fit: BoxFit.fill,
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
            const Text(
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login-background.png',
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
                final bottomPadding = veryCompact ? 6.0 : 12.0;
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
                    height: naturalContentHeight,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: topPadding,
                        bottom: bottomPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'assets/images/cymez-reception-logo.png',
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
                                    builder: (_) => const ReceptionHomePage(),
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
                          SizedBox(
                            height: visitorHeight,
                            child: Center(
                              child: SizedBox(
                                width:
                                    (constraints.maxWidth -
                                        horizontalPadding * 2) *
                                    (constraints.maxWidth < 500 ? 0.84 : 1),
                                height: visitorHeight,
                                child: _VisitorRegistrationCard(
                                  compact: compact,
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
  });

  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final bool compact;
  final bool veryCompact;

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
            compact ? 14 : 18,
            compact ? 4 : 18,
            compact ? 14 : 18,
            compact ? 4 : 18,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22.4),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF02A1633), Color(0xF0101834)],
            ),
            image: const DecorationImage(
              image: AssetImage('assets/images/login-card-background.png'),
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
                          children: const [
                            Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 21,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 16),
                      const Text(
                        'Usuario o correo electrónico',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: compact ? 2 : 9),
                      _LoginInput(
                        icon: Icons.person_outline,
                        hint: 'Escribe tu usuario o correo',
                        compact: compact,
                      ),
                      SizedBox(height: compact ? 2 : 16),
                      Row(
                        children: const [
                          Text(
                            'Contraseña',
                            style: TextStyle(
                              color: Colors.white,
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 2 : 9),
                      _LoginInput(
                        icon: Icons.lock_outline_rounded,
                        hint: 'Escribe tu contraseña',
                        obscure: obscurePassword,
                        compact: compact,
                        trailing: IconButton(
                          onPressed: onTogglePassword,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: compact ? 18 : 22,
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
                      SizedBox(height: compact ? 3 : 20),
                      SizedBox(
                        height: compact ? 38 : 54,
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
                                  children: const [
                                    Text(
                                      'Iniciar sesión',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Colors.white,
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
    this.obscure = false,
    this.trailing,
  });

  final IconData icon;
  final String hint;
  final bool compact;
  final bool obscure;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 30 : 50,
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
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: const Color(0xFF8FADFF)),
                suffixIcon: trailing,
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 32,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Color(0xFFB8C2D8),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: compact ? 7 : 14,
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
  const _VisitorRegistrationCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          child: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: Color(0xFF8DC8FF),
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
    return Container(
      width: compact ? 148 : 164,
      height: compact ? 50 : 54,
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
                        fontSize: compact ? 14 : 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: _white,
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
            'assets/images/cymez-reception-logo.png',
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
    required this.headlineFontSize,
  });

  final bool compact;
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
          style: _descriptionTextStyle(compact),
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
        'assets/images/onboarding-benefits-bar.png',
        fit: BoxFit.fill,
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
    return Container(
      width: double.infinity,
      height: compact ? 60 : 68,
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
                    fontSize: compact ? 18 : 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 14),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: _white,
                  size: 25,
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
      label: 'Página ${activeIndex + 1} de 4',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          4,
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

class ReceptionHomePage extends StatelessWidget {
  const ReceptionHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ReceptionDashboardPage();
  }
}

class _ReceptionDashboardPage extends StatelessWidget {
  const _ReceptionDashboardPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101F),
      drawer: const _ReceptionDrawer(),
      body: Container(
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
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                children: const [
                  _DashboardHeader(),
                  SizedBox(height: 12),
                  _DashboardSection(icon: Icons.home_rounded, title: 'Inicio'),
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
                    'assets/images/cymez-reception-logo.png',
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

class _ReceptionDrawer extends StatelessWidget {
  const _ReceptionDrawer();

  @override
  Widget build(BuildContext context) {
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
                          'assets/images/cymez-reception-logo.png',
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
                  const _DrawerLabel('Organización'),
                  const _DrawerItem(
                    icon: Icons.apartment_rounded,
                    label: 'Departamento',
                  ),
                  const _DrawerItem(
                    icon: Icons.meeting_room_rounded,
                    label: 'Anfitriones',
                  ),
                  const _DrawerItem(
                    icon: Icons.vpn_key_rounded,
                    label: 'Accesos',
                  ),
                  const _DrawerLabel('Externos'),
                  const _DrawerItem(
                    icon: Icons.business_rounded,
                    label: 'Contratistas/proveedores y visitantes',
                  ),
                  const _DrawerItem(
                    icon: Icons.badge_rounded,
                    label: 'Personal de externos',
                  ),
                  const _DrawerItem(
                    icon: Icons.handyman_rounded,
                    label: 'Equipo y herramientas',
                  ),
                  const _DrawerItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'Agenda de citas',
                  ),
                  const _DrawerItem(
                    icon: Icons.assignment_rounded,
                    label: 'Bitácora diaria',
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
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => Navigator.of(context).pop(),
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
