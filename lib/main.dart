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
                final compact = constraints.maxHeight < 700;
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
                          _WelcomeBenefits(
                            compact: compact,
                            height: benefitCardHeight,
                          ),
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
                    ? 24.0
                    : 32.0;
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
                      const Spacer(flex: 3),
                      _RegistrationOnboardingCopy(
                        compact: compact,
                        veryCompact: veryCompact,
                      ),
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
                          _OnboardingContinueButton(compact: compact),
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

class _OnboardingContinueButton extends StatelessWidget {
  const _OnboardingContinueButton({required this.compact});

  final bool compact;

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
            onTap: () {},
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
  const _WelcomeBenefits({required this.compact, required this.height});

  final bool compact;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/visitor-feature-card.webp',
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          ),
          Padding(
            padding: const EdgeInsets.all(7),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF080D21).withValues(alpha: 0.97),
                    const Color(0xFF04142B).withValues(alpha: 0.97),
                    const Color(0xFF07152D).withValues(alpha: 0.97),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 20,
              vertical: compact ? 6 : 14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BenefitItem(
                    icon: Icons.verified_user_outlined,
                    label: 'Más\nseguridad',
                    color: const Color(0xFF80C8FF),
                    compact: compact,
                  ),
                ),
                _BenefitDivider(),
                Expanded(
                  child: _BenefitItem(
                    icon: Icons.av_timer_outlined,
                    label: 'Registro\nrápido',
                    color: const Color(0xFFFF4665),
                    compact: compact,
                  ),
                ),
                _BenefitDivider(),
                Expanded(
                  child: _BenefitItem(
                    icon: Icons.groups_2_outlined,
                    label: 'Mejor control\nde accesos',
                    color: const Color(0xFFCC6EFF),
                    compact: compact,
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

class _BenefitItem extends StatelessWidget {
  const _BenefitItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: compact ? 32 : 38,
          color: color,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.65), blurRadius: 12),
          ],
        ),
        SizedBox(height: compact ? 7 : 10),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _white,
            fontSize: compact ? 10 : 12,
            height: 1.25,
            fontWeight: FontWeight.w500,
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

class _BenefitDivider extends StatelessWidget {
  const _BenefitDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 60, color: const Color(0x665C8CC8));
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
