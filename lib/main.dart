// ignore_for_file: unused_element, unused_element_parameter

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kDebugMode, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:gal/gal.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'auth_service.dart';
import 'app_feedback.dart';
import 'connected_modules.dart';
import 'reception_header.dart';
import 'src/timer_notifications.dart';

const _red = Color(0xFFFF1538);
const _blue = Color(0xFF087FFF);
const _white = Color(0xFFF4F7FF);
const _mutedWhite = Color(0xFFD4DDF0);
const _welcomeDescriptionFirstLine = 'Registra tus visitas de forma rápida,';
const _logoArtworkWidthRatio = 0.764;
final _appUpdateNavigatorKey = GlobalKey<NavigatorState>();

class _MobileAppUpdateCoordinator extends StatefulWidget {
  const _MobileAppUpdateCoordinator({
    required this.authService,
    required this.child,
  });

  final AuthService authService;
  final Widget child;

  @override
  State<_MobileAppUpdateCoordinator> createState() =>
      _MobileAppUpdateCoordinatorState();
}

class _MobileAppUpdateCoordinatorState
    extends State<_MobileAppUpdateCoordinator>
    with WidgetsBindingObserver {
  final Set<int> _notifiedBuilds = {};
  StreamSubscription<void>? _loginSubscription;
  bool _checking = false;
  bool _initialCheckScheduled = false;
  bool _startupReady = false;
  Timer? _retryTimer;

  bool get _enabled =>
      !kIsWeb && !kDebugMode && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForSuccessfulLogins();
  }

  @override
  void didUpdateWidget(covariant _MobileAppUpdateCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) {
      _listenForSuccessfulLogins();
    }
  }

  void _listenForSuccessfulLogins() {
    unawaited(_loginSubscription?.cancel());
    _loginSubscription = widget.authService.successfulLoginEvents.listen((_) {
      _notifiedBuilds.clear();
      _checkForUpdate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled || _initialCheckScheduled) return;
    _initialCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startupReady = true;
      _checkForUpdate();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _startupReady) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (!mounted || !_enabled || _checking) return;
    _checking = true;
    try {
      final size = MediaQuery.sizeOf(context);
      final channel = size.shortestSide >= 600 || size.width > size.height
          ? 'tablet'
          : 'phone';
      final update = await widget.authService.checkForMobileAppUpdate(
        channel: channel,
      );
      if (!mounted ||
          update == null ||
          _notifiedBuilds.contains(update.build)) {
        return;
      }
      _retryTimer?.cancel();
      if (!mounted) return;
      final overlayContext =
          _appUpdateNavigatorKey.currentState?.overlay?.context;
      if (overlayContext == null || !overlayContext.mounted) return;
      final shouldDownload = await showDialog<bool>(
        context: overlayContext,
        barrierDismissible: false,
        builder: (dialogContext) =>
            _MobileAppUpdateDialog(update: update, channel: channel),
      );
      if (shouldDownload == null) return;
      _notifiedBuilds.add(update.build);
      if (shouldDownload != true) return;
      final opened = await launchUrl(
        update.downloadUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        final latestOverlayContext =
            _appUpdateNavigatorKey.currentState?.overlay?.context;
        if (latestOverlayContext == null || !latestOverlayContext.mounted) {
          return;
        }
        await showDialog<void>(
          context: latestOverlayContext,
          builder: (dialogContext) => AlertDialog(
            title: const Text('No se pudo abrir la descarga'),
            content: const Text(
              'Verifica tu conexión e inténtalo de nuevo más tarde.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('No se pudo comprobar la actualización móvil: $error');
      debugPrintStack(stackTrace: stackTrace);
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 15), () {
        if (mounted &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
          _checkForUpdate();
        }
      });
    } finally {
      _checking = false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    unawaited(_loginSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _MobileAppUpdateDialog extends StatelessWidget {
  const _MobileAppUpdateDialog({required this.update, required this.channel});

  final MobileAppUpdate update;
  final String channel;

  @override
  Widget build(BuildContext context) {
    final isTablet = channel == 'tablet';
    const surface = Color(0xFF0D1832);
    const secondarySurface = Color(0xFF111F3D);
    const muted = Color(0xFFB7C5DC);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF29466C)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x70000000),
                  blurRadius: 38,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -90,
                  right: -72,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _blue.withValues(alpha: 0.2),
                          _blue.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_red, Color(0xFF663CFF), _blue],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(17),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF163F72),
                                      Color(0xFF102A4E),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: const Color(0xFF3B72AC),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.system_update_alt_rounded,
                                  color: Color(0xFF92C9FF),
                                  size: 27,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF163B66),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF2D5C8D),
                                        ),
                                      ),
                                      child: Text(
                                        isTablet
                                            ? 'ACTUALIZACIÓN PARA TABLET'
                                            : 'ACTUALIZACIÓN PARA CELULAR',
                                        style: const TextStyle(
                                          color: Color(0xFFA8D4FF),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.7,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Nueva versión disponible',
                                      style: TextStyle(
                                        color: _white,
                                        fontSize: 20,
                                        height: 1.15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: secondarySurface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF223A60),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 19,
                                  color: Color(0xFF65C8BC),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Versión ${update.version}',
                                    style: const TextStyle(
                                      color: _white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  'BUILD ${update.build}',
                                  style: const TextStyle(
                                    color: Color(0xFF91A9C9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (update.notes.trim().isNotEmpty) ...[
                            const SizedBox(height: 18),
                            const Text(
                              'NOVEDADES',
                              style: TextStyle(
                                color: Color(0xFF89BFFF),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              update.notes.trim(),
                              style: const TextStyle(
                                color: muted,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 17,
                                color: Color(0xFF91A9C9),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Descarga el APK y confirma la instalación cuando Android lo solicite.',
                                  style: TextStyle(
                                    color: Color(0xFF9EADC4),
                                    fontSize: 12,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFC1CEE2),
                                  minimumSize: const Size(110, 46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text(
                                  'Más tarde',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                icon: const Icon(
                                  Icons.download_rounded,
                                  size: 19,
                                ),
                                label: const Text('Descargar'),
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(0xFF126DC2),
                                  minimumSize: const Size(150, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

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

double responsiveBottomScrollPadding(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide < 600 ? 88 : 32;

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
      fontSize: tablet ? 30 : (compact ? 15 : 17),
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

Future<ui.Image> _loadSplashImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var tabletStartup = false;
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    tabletStartup =
        view.physicalSize.shortestSide / view.devicePixelRatio >= 600;
    await SystemChrome.setPreferredOrientations(
      tabletStartup
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }
  await SystemChrome.setEnabledSystemUIMode(
    tabletStartup ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final mobileSplashImage = await _loadSplashImage(
    'assets/images/reception-mobile-splash.png',
  );
  final tabletSplashImage = await _loadSplashImage(
    'assets/images/reception-tablet-splash.png',
  );
  runApp(
    ReceptionApp(
      authService: AuthService.shared,
      onboardingStorage: SecureMobileOnboardingStorage(),
      visitorKioskDraftStorage: SecureVisitorKioskDraftStorage(),
      mobileSplashImage: mobileSplashImage,
      tabletSplashImage: tabletSplashImage,
    ),
  );
}

class ReceptionApp extends StatelessWidget {
  const ReceptionApp({
    super.key,
    this.showSplash = true,
    this.authService,
    this.onboardingStorage,
    this.visitorKioskDraftStorage,
    this.mobileSplashImage,
    this.tabletSplashImage,
  });

  final bool showSplash;
  final AuthService? authService;
  final MobileOnboardingStorage? onboardingStorage;
  final VisitorKioskDraftStorage? visitorKioskDraftStorage;
  final ui.Image? mobileSplashImage;
  final ui.Image? tabletSplashImage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _appUpdateNavigatorKey,
      title: 'Cymez Recep',
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
              child: SizedBox.expand(
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
      home: showSplash && !kIsWeb
          ? _ReceptionStartupPage(
              authService: authService,
              onboardingStorage: onboardingStorage,
              visitorKioskDraftStorage: visitorKioskDraftStorage,
              mobileSplashImage: mobileSplashImage,
              tabletSplashImage: tabletSplashImage,
            )
          : _MobileAppUpdateCoordinator(
              authService: authService ?? AuthService.shared,
              child: _ResponsiveReceptionEntry(
                authService: authService,
                onboardingStorage: onboardingStorage,
                visitorKioskDraftStorage: visitorKioskDraftStorage,
              ),
            ),
    );
  }
}

class _ResponsiveReceptionEntry extends StatelessWidget {
  const _ResponsiveReceptionEntry({
    this.authService,
    this.onboardingStorage,
    this.visitorKioskDraftStorage,
  });

  final AuthService? authService;
  final MobileOnboardingStorage? onboardingStorage;
  final VisitorKioskDraftStorage? visitorKioskDraftStorage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!kIsWeb && constraints.biggest.shortestSide >= 600) {
          return _TabletVisitorLandingPage(
            authService: authService ?? AuthService.shared,
            draftStorage: visitorKioskDraftStorage,
          );
        }
        return authService == null
            ? ReceptionWelcomePage(onboardingStorage: onboardingStorage)
            : _ReceptionSessionGate(
                authService: authService!,
                onboardingStorage: onboardingStorage,
              );
      },
    );
  }
}

class _TabletVisitorLandingPage extends StatefulWidget {
  const _TabletVisitorLandingPage({
    required this.authService,
    this.draftStorage,
  });

  final AuthService authService;
  final VisitorKioskDraftStorage? draftStorage;

  @override
  State<_TabletVisitorLandingPage> createState() =>
      _TabletVisitorLandingPageState();
}

class _TabletVisitorLandingPageState extends State<_TabletVisitorLandingPage> {
  bool _landscapeRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_landscapeRequested) {
      _landscapeRequested = true;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  Future<void> _openWalkInRegistration() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => WalkInVisitorPage(
          authService: widget.authService,
          draftStorage: widget.draftStorage,
          allowExit: false,
        ),
      ),
    );
    if (mounted) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.height > size.width) {
      return const Scaffold(
        backgroundColor: Color(0xFF020817),
        body: _WalkInRotatePrompt(tablet: true, allowExit: false),
      );
    }
    return Scaffold(
      key: const ValueKey('tablet-visitor-landing'),
      backgroundColor: const Color(0xFF020817),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/tablet-visitor-landing-background.webp',
            key: const ValueKey('tablet-visitor-landing-background'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final buttonWidth = math.min(width * .68, 980.0).toDouble();
                final buttonHeight = (height * .208)
                    .clamp(110.0, 174.0)
                    .toDouble();
                return Stack(
                  children: [
                    Positioned(
                      top: height * .655 - buttonHeight / 2,
                      left: (width - buttonWidth) / 2,
                      width: buttonWidth,
                      height: buttonHeight,
                      child: _TabletVisitorLandingButton(
                        onTap: _openWalkInRegistration,
                        width: buttonWidth,
                        height: buttonHeight,
                      ),
                    ),
                    Positioned(
                      right: width * .08,
                      bottom: height * .1,
                      left: width * .08,
                      child: const _TabletVisitorLandingFooter(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletVisitorLandingButton extends StatelessWidget {
  const _TabletVisitorLandingButton({
    required this.onTap,
    required this.width,
    required this.height,
  });

  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scale = (width / 696).clamp(.65, 1.4).toDouble();
    final radius = 30 * scale;
    return Container(
      padding: EdgeInsets.all(2 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF00AFFF), Color(0xFF62C8FF), Color(0xFFFF193B)],
          stops: [0, .48, 1],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xCC00AFFF), blurRadius: 18, spreadRadius: -3),
          BoxShadow(color: Color(0xAAFF193B), blurRadius: 22, spreadRadius: -5),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius - scale),
        child: InkWell(
          key: const ValueKey('tablet-visitor-landing-cta'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius - scale),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius - scale),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF2020D24),
                  Color(0xED03132D),
                  Color(0xF20A0D23),
                ],
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: width * .2,
                  height: height * .76,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFF42C3FF), width: 1.5),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(10 * scale),
                      child: Image.asset(
                        'assets/images/tablet-visitor-exit-icon.webp',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20 * scale),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Visitas sin cita',
                            maxLines: 1,
                            style: TextStyle(
                              color: const Color(0xFFF5F7FC),
                              fontSize: 44 * scale,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.8 * scale,
                            ),
                          ),
                        ),
                        SizedBox(height: 4 * scale),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Registra tu visita aquí',
                            maxLines: 1,
                            style: TextStyle(
                              color: const Color(0xFFA9BFDC),
                              fontSize: 26 * scale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(right: 24 * scale),
                  child: Container(
                    width: 68 * scale,
                    height: 68 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x77434D78),
                      border: Border.all(color: const Color(0x336E83BB)),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 52 * scale,
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

class _TabletVisitorLandingFooter extends StatelessWidget {
  const _TabletVisitorLandingFooter();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = (width / 1024).clamp(.65, 1.3).toDouble();
    return Row(
      children: [
        const Expanded(child: _TabletVisitorLandingFooterLine(reverse: false)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 26 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CYMEZ RECEP',
                style: TextStyle(
                  color: const Color(0xFFB6C8E1),
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4 * scale,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 22 * scale),
                child: Container(
                  width: 7 * scale,
                  height: 7 * scale,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF193B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Text(
                'CONTROL DE VISITAS',
                style: TextStyle(
                  color: const Color(0xFFB6C8E1),
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 4 * scale,
                ),
              ),
            ],
          ),
        ),
        const Expanded(child: _TabletVisitorLandingFooterLine(reverse: true)),
      ],
    );
  }
}

class _TabletVisitorLandingFooterLine extends StatelessWidget {
  const _TabletVisitorLandingFooterLine({required this.reverse});

  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
          end: reverse ? Alignment.centerLeft : Alignment.centerRight,
          colors: const [Color(0x000080FF), Color(0xFF287CBA)],
        ),
      ),
    );
  }
}

class _ReceptionStartupPage extends StatefulWidget {
  const _ReceptionStartupPage({
    this.authService,
    this.onboardingStorage,
    this.visitorKioskDraftStorage,
    this.mobileSplashImage,
    this.tabletSplashImage,
  });

  final AuthService? authService;
  final MobileOnboardingStorage? onboardingStorage;
  final VisitorKioskDraftStorage? visitorKioskDraftStorage;
  final ui.Image? mobileSplashImage;
  final ui.Image? tabletSplashImage;

  @override
  State<_ReceptionStartupPage> createState() => _ReceptionStartupPageState();
}

class _ReceptionStartupPageState extends State<_ReceptionStartupPage>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 2400);
  static const _progressDuration = Duration(milliseconds: 2000);
  late final Future<void> _splashDelay;
  late final AnimationController _loadingAnimation;
  bool _tabletOrientationRequested = false;
  bool _systemUiRestored = false;

  @override
  void initState() {
    super.initState();
    _splashDelay = Future<void>.delayed(_splashDuration);
    _loadingAnimation = AnimationController(
      vsync: this,
      duration: _progressDuration,
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabletOrientationRequested ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        MediaQuery.sizeOf(context).shortestSide < 600) {
      return;
    }
    _tabletOrientationRequested = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _loadingAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _splashDelay,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (_tabletOrientationRequested && !_systemUiRestored) {
            _systemUiRestored = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              }
            });
          }
          return _MobileAppUpdateCoordinator(
            authService: widget.authService ?? AuthService.shared,
            child: _ResponsiveReceptionEntry(
              authService: widget.authService,
              onboardingStorage: widget.onboardingStorage,
              visitorKioskDraftStorage: widget.visitorKioskDraftStorage,
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFF020817),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final tablet = constraints.biggest.shortestSide >= 600;
              final splashAsset = tablet
                  ? 'assets/images/reception-tablet-splash.png'
                  : 'assets/images/reception-mobile-splash.png';
              final splashImage = tablet
                  ? widget.tabletSplashImage
                  : widget.mobileSplashImage;
              const splashFit = BoxFit.cover;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (splashImage == null)
                    Image.asset(
                      splashAsset,
                      fit: splashFit,
                      filterQuality: FilterQuality.high,
                      semanticLabel: 'CYMEZ Recepción, control de acceso',
                    )
                  else
                    Semantics(
                      label: 'CYMEZ Recepción, control de acceso',
                      child: RawImage(
                        image: splashImage,
                        fit: splashFit,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  Positioned(
                    left: constraints.maxWidth * 0.29,
                    right: constraints.maxWidth * 0.29,
                    bottom: constraints.maxHeight * 0.027,
                    child: AnimatedBuilder(
                      animation: _loadingAnimation,
                      builder: (context, child) {
                        final percentage = (_loadingAnimation.value * 100)
                            .round()
                            .clamp(0, 100);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: SizedBox(
                                key: const ValueKey(
                                  'startup-splash-loading-bar',
                                ),
                                height: 6,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    const ColoredBox(color: Color(0xE61F395B)),
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: _loadingAnimation.value,
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [_red, _white, _blue],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$percentage%',
                              key: const ValueKey('startup-splash-progress'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    color: Color(0xCC020817),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ReceptionSessionGate extends StatefulWidget {
  const _ReceptionSessionGate({
    required this.authService,
    this.onboardingStorage,
  });

  final AuthService authService;
  final MobileOnboardingStorage? onboardingStorage;

  @override
  State<_ReceptionSessionGate> createState() => _ReceptionSessionGateState();
}

class _ReceptionSessionGateState extends State<_ReceptionSessionGate> {
  late Future<AuthenticatedUser?> _session;
  bool _continueWithoutSession = false;

  @override
  void initState() {
    super.initState();
    _session = _restoreSession();
  }

  Future<AuthenticatedUser?> _restoreSession() async {
    final user = await widget.authService.restoreSession();
    if (user != null &&
        (user.canAccessReception ||
            user.sectionAccess.contains('anfitriones'))) {
      unawaited(
        TimerNotificationService.instance.configureAndRegister(
          widget.authService,
        ),
      );
    }
    return user;
  }

  void _retry() {
    setState(() {
      _continueWithoutSession = false;
      _session = _restoreSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_continueWithoutSession) {
      return ReceptionWelcomePage(onboardingStorage: widget.onboardingStorage);
    }

    return FutureBuilder<AuthenticatedUser?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF03091A),
            body: Center(child: CircularProgressIndicator(color: _blue)),
          );
        }

        if (snapshot.hasError) {
          final message = snapshot.error is AuthApiException
              ? (snapshot.error as AuthApiException).message
              : 'No se pudo comprobar la sesión. Inténtalo de nuevo.';
          return Scaffold(
            backgroundColor: const Color(0xFF03091A),
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: Color(0xFFFF5A72),
                        size: 44,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No se pudo validar la sesión',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _mutedWhite),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _retry,
                        child: const Text('Reintentar'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() => _continueWithoutSession = true);
                        },
                        child: const Text('Continuar sin sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return ReceptionWelcomePage(
            onboardingStorage: widget.onboardingStorage,
          );
        }
        return ReceptionHomePage(authService: widget.authService, user: user);
      },
    );
  }
}

class ReceptionWelcomePage extends StatelessWidget {
  const ReceptionWelcomePage({super.key, this.onboardingStorage});

  final MobileOnboardingStorage? onboardingStorage;

  bool _isPhone(BuildContext context) =>
      !kIsWeb && MediaQuery.sizeOf(context).shortestSide < 600;

  Future<void> _startOnboarding(BuildContext context) async {
    final storage = onboardingStorage;
    if (_isPhone(context) &&
        storage != null &&
        await storage.hasSeenOnboarding()) {
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReceptionLoginPage()),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReceptionOnboardingPage(onboardingStorage: onboardingStorage),
      ),
    );
  }

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
                  final veryCompact = !tablet && constraints.maxHeight < 600;
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
                  final bottomPadding = veryCompact
                      ? 20.0
                      : compact
                      ? 30.0
                      : 20.0;
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
                      : math.max(
                          _headlineFontSize(
                            math.min(contentWidth, descriptionWidth * 1.4),
                            textDirection,
                          ),
                          contentWidth * 0.15,
                        );
                  final logoWidth = [
                    contentWidth,
                    tablet
                        ? constraints.maxWidth * 0.66
                        : descriptionWidth / _logoArtworkWidthRatio,
                  ].reduce((left, right) => left < right ? left : right);
                  final logoScale =
                      ((descriptionWidth /
                                  (logoWidth * _logoArtworkWidthRatio)) *
                              (tablet || veryCompact ? 1 : 1.12))
                          .clamp(1.0, tablet ? 1.9 : 1.75);
                  final logoHeight = tablet
                      ? ((logoWidth / 1.65).clamp(
                          constraints.maxHeight < 700 ? 120.0 : 180.0,
                          constraints.maxHeight < 800
                              ? 220.0
                              : constraints.maxWidth >= 1200
                              ? 390.0
                              : 300.0,
                        )).clamp(120.0, 390.0)
                      : math
                            .min(
                              logoWidth / 1.5 * logoScale,
                              constraints.maxHeight * 0.36,
                            )
                            .toDouble();
                  final benefitCardHeight = tablet
                      ? (contentWidth * 0.31).clamp(
                          constraints.maxHeight < 700 ? 82.0 : 150.0,
                          constraints.maxHeight < 700 ? 115.0 : 215.0,
                        )
                      : (contentWidth / 2.5).clamp(
                          122.0,
                          compact ? 140.0 : 160.0,
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
                                      veryCompact: veryCompact,
                                      onStart: () => _startOnboarding(context),
                                    ),
                                  ),
                                ],
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                child: _StartButton(
                                  compact: compact,
                                  veryCompact: veryCompact,
                                  onStart: () => _startOnboarding(context),
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
  const ReceptionOnboardingPage({super.key, this.onboardingStorage});

  final MobileOnboardingStorage? onboardingStorage;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      body: _OnboardingSwipeDetector(
        activeIndex: 0,
        onboardingStorage: onboardingStorage,
        child: _TabletLandscapeGuard(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (tablet)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Image.asset(
                        'assets/images/onboarding-register-background.webp',
                        key: const ValueKey(
                          'tablet-onboarding-left-background',
                        ),
                        cacheWidth: 768,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Image.asset(
                        'assets/images/login-background.webp',
                        key: const ValueKey(
                          'tablet-onboarding-right-background',
                        ),
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
                        : (contentWidth * 0.62).clamp(150.0, 205.0);
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
                            ? 18
                            : compact
                            ? 22
                            : 24,
                      ),
                      child: tablet
                          ? _TabletRegistrationOnboardingLayout(
                              logoWidth: (constraints.maxWidth * 0.17)
                                  .clamp(140.0, 220.0)
                                  .toDouble(),
                              onboardingStorage: onboardingStorage,
                              onContinue: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ReceptionControlOnboardingPage(
                                          onboardingStorage: onboardingStorage,
                                        ),
                                  ),
                                );
                              },
                              onSkip: () =>
                                  _finishOnboarding(context, onboardingStorage),
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
                                      key: const ValueKey(
                                        'mobile-registration-onboarding-logo',
                                      ),
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
                                          onPressed: () => _finishOnboarding(
                                            context,
                                            onboardingStorage,
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: _mutedWhite,
                                            padding: EdgeInsets.symmetric(
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
                                                ReceptionControlOnboardingPage(
                                                  onboardingStorage:
                                                      onboardingStorage,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                SizedBox(height: compact ? 8 : 14),
                                _PageIndicator(
                                  activeIndex: 0,
                                  onSelected: (index) =>
                                      _navigateToOnboardingPage(
                                        context,
                                        0,
                                        index,
                                        onboardingStorage: onboardingStorage,
                                      ),
                                ),
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
      ),
    );
  }
}

class _TabletRegistrationOnboardingLayout extends StatelessWidget {
  const _TabletRegistrationOnboardingLayout({
    required this.logoWidth,
    required this.onboardingStorage,
    required this.onContinue,
    required this.onSkip,
  });

  final double logoWidth;
  final MobileOnboardingStorage? onboardingStorage;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700 || size.width < 1100;

    return Row(
      children: [
        Expanded(
          key: const ValueKey('tablet-registration-left-panel'),
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(8),
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
          key: const ValueKey('tablet-registration-right-panel'),
          flex: 2,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 44,
              36,
              compact ? 20 : 32,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: compact ? 12 : 0),
                    child: LayoutBuilder(
                      builder: (context, copyConstraints) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          key: const ValueKey(
                            'tablet-registration-copy-center',
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
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
                ),
                SizedBox(
                  height: 70,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: onSkip,
                            style: TextButton.styleFrom(
                              foregroundColor: _mutedWhite,
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Omitir',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: _PageIndicator(
                            key: ValueKey('tablet-registration-page-indicator'),
                            activeIndex: 0,
                            onSelected: (index) => _navigateToOnboardingPage(
                              context,
                              0,
                              index,
                              onboardingStorage: onboardingStorage,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        key: const ValueKey(
                          'tablet-registration-continue-button',
                        ),
                        child: _OnboardingContinueButton(
                          compact: false,
                          width: compact ? 112 : 148,
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

class _TabletOnboardingSplitLayout extends StatelessWidget {
  const _TabletOnboardingSplitLayout({
    required this.step,
    required this.activeIndex,
    required this.onboardingStorage,
    required this.onSkip,
    required this.content,
    required this.action,
    required this.logoWidth,
  });

  final String step;
  final int activeIndex;
  final MobileOnboardingStorage? onboardingStorage;
  final VoidCallback onSkip;
  final Widget content;
  final Widget action;
  final double logoWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.topLeft,
              child: Image.asset(
                'assets/images/cymez-reception-logo.webp',
                key: ValueKey('tablet-onboarding-$step-logo'),
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
          flex: 2,
          child: LayoutBuilder(
            builder: (context, panelConstraints) {
              final leftInset = (panelConstraints.maxWidth * 0.1)
                  .clamp(28.0, 44.0)
                  .toDouble();
              final rightInset = (panelConstraints.maxWidth * 0.075)
                  .clamp(20.0, 40.0)
                  .toDouble();
              final compact = panelConstraints.maxWidth < 360;
              return Padding(
                padding: EdgeInsets.fromLTRB(leftInset, 16, rightInset, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) {
                          return Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: contentConstraints.maxWidth,
                                child: Column(
                                  key: ValueKey(
                                    'tablet-onboarding-$step-content',
                                  ),
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _OnboardingStepBadge(step: step),
                                    const SizedBox(height: 16),
                                    content,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      height: 70,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 72,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: onSkip,
                                style: TextButton.styleFrom(
                                  foregroundColor: _mutedWhite,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Omitir',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: _PageIndicator(
                                activeIndex: activeIndex,
                                onSelected: (index) =>
                                    _navigateToOnboardingPage(
                                      context,
                                      activeIndex,
                                      index,
                                      onboardingStorage: onboardingStorage,
                                    ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact ? 112 : 148,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: action,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (kIsWeb) const _WebHomeIndicator(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OnboardingStepBadge extends StatelessWidget {
  const _OnboardingStepBadge({required this.step});

  final String step;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('tablet-onboarding-step-$step'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
      child: Text(
        step,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabletScale = tablet
            ? (constraints.maxWidth / 480).clamp(0.52, 1.0).toDouble()
            : 1.0;
        final titleStyle = TextStyle(
          color: _white,
          fontSize: tablet
              ? (compact ? 62 : 78) * tabletScale
              : veryCompact
              ? 32
              : compact
              ? 37
              : 40,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
        );

        return Column(
          key: tablet ? const ValueKey('tablet-registration-copy') : null,
          mainAxisSize: tablet ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tablet) ...[
              Container(
                key: const ValueKey('tablet-onboarding-step-number'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
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
                child: Text(
                  '01',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28 * tabletScale,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text('Registra tus', textAlign: TextAlign.start, style: titleStyle),
            ShaderMask(
              key: const ValueKey('registration-onboarding-gradient-word'),
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFFF4563), Color(0xFF35BFFF)],
              ).createShader(bounds),
              child: Text(
                'visitas',
                textAlign: TextAlign.start,
                style: titleStyle.copyWith(
                  fontSize: tablet
                      ? (compact ? 70 : 86) * tabletScale
                      : veryCompact
                      ? 36
                      : compact
                      ? 45
                      : 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  shadows: const [
                    Shadow(
                      color: Color(0xB3071020),
                      offset: Offset(0, 2),
                      blurRadius: 2,
                    ),
                  ],
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
              textAlign: TextAlign.start,
              style: TextStyle(
                color: const Color(0xFF36BFFF),
                fontSize: tablet
                    ? (compact ? 28 : 34) * tabletScale
                    : veryCompact
                    ? 15
                    : compact
                    ? 17
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
              textAlign: TextAlign.start,
              style: TextStyle(
                color: _white,
                fontSize: tablet
                    ? (compact ? 24 : 28) * tabletScale
                    : veryCompact
                    ? 14
                    : compact
                    ? 16
                    : 17,
                height: 1.45,
                shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
          ],
        );
      },
    );
  }
}

class ReceptionControlOnboardingPage extends StatelessWidget {
  const ReceptionControlOnboardingPage({super.key, this.onboardingStorage});

  final MobileOnboardingStorage? onboardingStorage;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Scaffold(
      body: _OnboardingSwipeDetector(
        activeIndex: 1,
        onboardingStorage: onboardingStorage,
        child: _TabletLandscapeGuard(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (tablet)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Image.asset(
                        'assets/images/onboarding-control-background.webp',
                        key: const ValueKey('tablet-control-left-background'),
                        cacheWidth: 768,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Image.asset(
                        'assets/images/login-background.webp',
                        key: const ValueKey('tablet-control-right-background'),
                        cacheWidth: 768,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                )
              else
                Image.asset(
                  'assets/images/onboarding-control-background.webp',
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
                        constraints.maxHeight < 700 ||
                        constraints.maxWidth < 500;
                    final compactLogo = constraints.maxHeight < 700;
                    final veryCompact = constraints.maxHeight < 600;
                    final horizontalPadding = constraints.maxWidth < 360
                        ? 18.0
                        : 24.0;
                    if (tablet) {
                      return _TabletOnboardingSplitLayout(
                        step: '02',
                        activeIndex: 1,
                        onboardingStorage: onboardingStorage,
                        onSkip: () =>
                            _finishOnboarding(context, onboardingStorage),
                        content: const _ControlOnboardingCopy(tablet: true),
                        action: _OnboardingContinueButton(
                          compact: compact,
                          width: compact ? 112 : 148,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ReceptionReadyOnboardingPage(
                                  onboardingStorage: onboardingStorage,
                                ),
                              ),
                            );
                          },
                        ),
                        logoWidth: (constraints.maxWidth * 0.17)
                            .clamp(140.0, 220.0)
                            .toDouble(),
                      );
                    }
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
                            ? 18
                            : compact
                            ? 22
                            : 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: Image.asset(
                              'assets/images/cymez-reception-logo.webp',
                              key: const ValueKey(
                                'mobile-control-onboarding-logo',
                              ),
                              cacheWidth: 480,
                              width: compactLogo ? 195 : 220,
                              height: compactLogo ? 128 : 148,
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
                                    onPressed: () => _finishOnboarding(
                                      context,
                                      onboardingStorage,
                                    ),
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
                                          ReceptionReadyOnboardingPage(
                                            onboardingStorage:
                                                onboardingStorage,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 8 : 14),
                          _PageIndicator(
                            activeIndex: 1,
                            onSelected: (index) => _navigateToOnboardingPage(
                              context,
                              1,
                              index,
                              onboardingStorage: onboardingStorage,
                            ),
                          ),
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
      ),
    );
  }
}

class ReceptionReadyOnboardingPage extends StatelessWidget {
  const ReceptionReadyOnboardingPage({super.key, this.onboardingStorage});

  final MobileOnboardingStorage? onboardingStorage;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Scaffold(
      body: _OnboardingSwipeDetector(
        activeIndex: 2,
        onboardingStorage: onboardingStorage,
        child: _TabletLandscapeGuard(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (tablet)
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Image.asset(
                        'assets/images/onboarding-ready-background.webp',
                        key: const ValueKey('tablet-ready-left-background'),
                        cacheWidth: 768,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Image.asset(
                        'assets/images/login-background.webp',
                        key: const ValueKey('tablet-ready-right-background'),
                        cacheWidth: 768,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                )
              else
                Image.asset(
                  'assets/images/onboarding-ready-background.webp',
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
                    if (tablet) {
                      return _TabletOnboardingSplitLayout(
                        step: '03',
                        activeIndex: 2,
                        onboardingStorage: onboardingStorage,
                        onSkip: () =>
                            _finishOnboarding(context, onboardingStorage),
                        content: const _ReadyOnboardingCopy(tablet: true),
                        action: _LoginButton(
                          onboardingStorage: onboardingStorage,
                        ),
                        logoWidth: (constraints.maxWidth * 0.17)
                            .clamp(140.0, 220.0)
                            .toDouble(),
                      );
                    }

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
                            ? 18
                            : compact
                            ? 22
                            : 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: Image.asset(
                              'assets/images/cymez-reception-logo.webp',
                              key: const ValueKey(
                                'mobile-ready-onboarding-logo',
                              ),
                              cacheWidth: 480,
                              width: compact ? 195 : 220,
                              height: compact ? 128 : 148,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          const Spacer(flex: 6),
                          const _ReadyOnboardingCopy(),
                          const Spacer(flex: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () => _finishOnboarding(
                                      context,
                                      onboardingStorage,
                                    ),
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
                              _LoginButton(
                                onboardingStorage: onboardingStorage,
                              ),
                            ],
                          ),
                          SizedBox(height: compact ? 4 : 14),
                          _PageIndicator(
                            activeIndex: 2,
                            onSelected: (index) => _navigateToOnboardingPage(
                              context,
                              2,
                              index,
                              onboardingStorage: onboardingStorage,
                            ),
                          ),
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
      ),
    );
  }
}

class _ReadyOnboardingCopy extends StatelessWidget {
  const _ReadyOnboardingCopy({this.tablet = false});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = tablet
            ? (constraints.maxWidth / 300).clamp(0.72, 1.45).toDouble()
            : 1.0;
        final titleScale = tablet
            ? (constraints.maxWidth / 260).clamp(0.72, 1.7).toDouble()
            : 1.0;
        final fontSize =
            (tablet
                ? (constraints.maxWidth < 360 ? 38.0 : 44.0)
                : (constraints.maxWidth < 360 ? 42.0 : 48.0)) *
            titleScale;
        final titleStyle = TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
        );
        const description =
            'Tu acceso está listo. Ingresa con tu cuenta\n'
            'y comienza a gestionar las visitas.';
        final descriptionFontSize = (tablet ? 14 : 17) * scale;
        var fittedDescriptionFontSize = descriptionFontSize;
        if (tablet) {
          final descriptionPainter = TextPainter(
            text: TextSpan(
              text: description,
              style: TextStyle(
                color: Colors.white,
                fontSize: descriptionFontSize,
                height: 1.45,
              ),
            ),
            textDirection: Directionality.of(context),
          )..layout();
          final longestLineWidth = descriptionPainter
              .computeLineMetrics()
              .fold<double>(
                0,
                (width, line) => width > line.width ? width : line.width,
              );
          if (longestLineWidth > constraints.maxWidth) {
            fittedDescriptionFontSize *=
                constraints.maxWidth / longestLineWidth;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('Todo listo para', style: titleStyle),
            ),
            ShaderMask(
              key: const ValueKey('ready-onboarding-gradient-word'),
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFFF4563), Color(0xFF35BFFF)],
              ).createShader(bounds),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'comenzar',
                  style: titleStyle.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    shadows: const [
                      Shadow(
                        color: Color(0xB3071020),
                        offset: Offset(0, 2),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 12 * scale),
            Text(
              'Acceso a tu cuenta',
              style: TextStyle(
                color: Color(0xFF36BFFF),
                fontSize: (tablet ? 18 : 18) * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8 * scale),
            Text(
              description,
              style: TextStyle(
                color: Colors.white,
                fontSize: fittedDescriptionFontSize,
                height: 1.45,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({this.onboardingStorage});

  final MobileOnboardingStorage? onboardingStorage;

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
            onTap: () => _finishOnboarding(context, onboardingStorage),
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
  const ReceptionLoginPage({super.key, this.authService});

  final AuthService? authService;

  @override
  State<ReceptionLoginPage> createState() => _ReceptionLoginPageState();
}

class _ReceptionLoginPageState extends State<ReceptionLoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  int _loginLockoutSeconds = 0;
  DateTime? _loginLockoutEndsAt;
  Timer? _loginLockoutTimer;
  String? _errorMessage;

  @override
  void dispose() {
    _loginLockoutTimer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startLoginLockout(int retryAfterSeconds) {
    if (retryAfterSeconds <= 0) return;
    _loginLockoutTimer?.cancel();
    _loginLockoutEndsAt = DateTime.now().add(
      Duration(seconds: retryAfterSeconds),
    );
    setState(() => _loginLockoutSeconds = retryAfterSeconds);
    _loginLockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _loginLockoutEndsAt!
          .difference(DateTime.now())
          .inSeconds;
      if (!mounted || remaining <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _loginLockoutSeconds = 0;
            _loginLockoutEndsAt = null;
            _errorMessage = null;
          });
        }
        return;
      }
      setState(() => _loginLockoutSeconds = remaining);
    });
  }

  String get _loginLockoutLabel {
    final minutes = (_loginLockoutSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_loginLockoutSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _openPasswordRecovery() async {
    if (MediaQuery.sizeOf(context).shortestSide >= 600) return;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xC8010814),
      builder: (_) => _PasswordRecoveryDialog(
        authService: widget.authService ?? AuthService.shared,
      ),
    );
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting || _loginLockoutSeconds > 0) return;
    if (_identifierController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Ingresa tu usuario o correo y tu contraseña.';
      });
      return;
    }

    final service = widget.authService ?? AuthService.shared;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = await service.login(
        _identifierController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      if (user.canAccessReception ||
          user.sectionAccess.contains('anfitriones')) {
        unawaited(
          TimerNotificationService.instance.configureAndRegister(service),
        );
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReceptionHomePage(authService: service, user: user),
        ),
      );
    } on AuthApiException catch (error) {
      if (mounted) {
        if (error.statusCode == 429 && error.retryAfterSeconds != null) {
          _startLoginLockout(error.retryAfterSeconds!);
        }
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                      ? (constraints.maxWidth * 0.035).clamp(16.0, 40.0)
                      : constraints.maxWidth < 360
                      ? 16.0
                      : constraints.maxWidth < 400
                      ? 20.0
                      : 24.0;
                  final logoHeight = tablet
                      ? veryCompact
                            ? 40.0
                            : compact
                            ? 84.0
                            : 180.0
                      : veryCompact
                      ? 70.0
                      : compact
                      ? 92.0
                      : 112.0;
                  final formHeight = tablet
                      ? veryCompact
                            ? 402.0
                            : compact
                            ? 402.0
                            : 330.0
                      : (constraints.maxHeight * 0.59).clamp(385.0, 400.0);
                  final mobileTitleSize = constraints.maxWidth < 360
                      ? 18.0
                      : constraints.maxWidth < 400
                      ? 21.0
                      : 26.0;
                  final visitorHeight = constraints.maxWidth < 500 || compact
                      ? 60.0
                      : 104.0;
                  final topPadding = veryCompact
                      ? 4.0
                      : compact
                      ? 10.0
                      : 18.0;
                  final bottomPadding = tablet
                      ? 16.0
                      : veryCompact
                      ? 6.0
                      : 12.0;
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: tablet ? Alignment.topCenter : Alignment.center,
                    child: SizedBox(
                      width: constraints.maxWidth - horizontalPadding * 2,
                      height: tablet ? constraints.maxHeight : null,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: topPadding,
                          bottom: bottomPadding,
                        ),
                        child: tablet
                            ? _TabletLoginLayout(
                                obscurePassword: _obscurePassword,
                                identifierController: _identifierController,
                                passwordController: _passwordController,
                                isSubmitting: _isSubmitting,
                                loginLockoutSeconds: _loginLockoutSeconds,
                                loginLockoutLabel: _loginLockoutLabel,
                                errorMessage: _errorMessage,
                                onLogin: _submitLogin,
                                onTogglePassword: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Image.asset(
                                    'assets/images/cymez-reception-logo.webp',
                                    key: const ValueKey('mobile-login-logo'),
                                    cacheWidth: 480,
                                    alignment: Alignment.topCenter,
                                    width: veryCompact
                                        ? 235
                                        : compact
                                        ? 260
                                        : 290,
                                    height: logoHeight,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                  SizedBox(height: compact ? 8 : 18),
                                  Text(
                                    'Bienvenido de nuevo',
                                    key: const ValueKey(
                                      'mobile-login-welcome-title',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: mobileTitleSize,
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
                                    key: const ValueKey(
                                      'mobile-login-form-card',
                                    ),
                                    height: formHeight,
                                    child: _LoginFormCard(
                                      obscurePassword: _obscurePassword,
                                      identifierController:
                                          _identifierController,
                                      passwordController: _passwordController,
                                      isSubmitting: _isSubmitting,
                                      loginLockoutSeconds: _loginLockoutSeconds,
                                      loginLockoutLabel: _loginLockoutLabel,
                                      errorMessage: _errorMessage,
                                      onForgotPassword: _openPasswordRecovery,
                                      onLogin: _submitLogin,
                                      onTogglePassword: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      compact: false,
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
                                                  builder: (_) => WalkInVisitorPage(
                                                    authService:
                                                        AuthService.shared,
                                                    draftStorage:
                                                        SecureVisitorKioskDraftStorage(),
                                                  ),
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

class _PasswordRecoveryDialog extends StatefulWidget {
  const _PasswordRecoveryDialog({required this.authService});

  final AuthService authService;

  @override
  State<_PasswordRecoveryDialog> createState() =>
      _PasswordRecoveryDialogState();
}

class _PasswordRecoveryDialogState extends State<_PasswordRecoveryDialog> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _message;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() {
        _errorMessage = 'Escribe un correo electrónico válido.';
        _message = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _message = null;
    });
    try {
      final message = await widget.authService.requestPasswordRecovery(email);
      if (!mounted) return;
      setState(() => _message = message);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .9;
    return Dialog(
      key: const ValueKey('password-recovery-dialog'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 650, maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: const LinearGradient(
              colors: [Color(0xFF087FFF), Color(0xFF294B82), Color(0xFFD9263F)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 34,
                offset: Offset(0, 20),
              ),
              BoxShadow(color: Color(0x220087FF), blurRadius: 28),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF061831),
                  Color(0xFF07152C),
                  Color(0xFF141327),
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    heightFactor: 0,
                    child: IconButton(
                      key: const ValueKey('password-recovery-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        foregroundColor: const Color(0xFFBAD1EE),
                        backgroundColor: const Color(0xFF0A2141),
                        side: const BorderSide(color: Color(0xFF24446A)),
                        minimumSize: const Size(36, 36),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF7F5E9F),
                            width: 1.6,
                          ),
                          color: const Color(0xFF071831),
                          boxShadow: const [
                            BoxShadow(color: Color(0x552A8DFF), blurRadius: 16),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFF4F8FF),
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Recuperar contraseña',
                              key: ValueKey('password-recovery-title'),
                              style: TextStyle(
                                color: Color(0xFFF7F9FD),
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'No te preocupes, te ayudaremos a restablecerla. Ingresa el correo electrónico asociado a tu cuenta.',
                              style: TextStyle(
                                color: Color(0xFFB7C9DF),
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Divider(height: 1, color: Color(0xFF1B385D)),
                  ),
                  const Text(
                    'Correo electrónico',
                    style: TextStyle(
                      color: Color(0xFFD9E8FB),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xD0020D1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _errorMessage == null
                            ? const Color(0xFF345B88)
                            : const Color(0xFFD34B60),
                      ),
                    ),
                    child: TextField(
                      key: const ValueKey('password-recovery-email'),
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.send,
                      autocorrect: false,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(
                        color: Color(0xFFF0F6FF),
                        fontSize: 14,
                      ),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(
                          Icons.mail_outline_rounded,
                          color: Color(0xFF9DCAFF),
                          size: 21,
                        ),
                        hintText: 'Escribe tu correo electrónico',
                        hintStyle: TextStyle(
                          color: Color(0xFF849BB6),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 9),
                    _PasswordRecoveryMessage(
                      message: _errorMessage!,
                      isError: true,
                    ),
                  ],
                  if (_message != null) ...[
                    const SizedBox(height: 9),
                    _PasswordRecoveryMessage(message: _message!),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC91439), Color(0xFFED1742)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x44C51338),
                            blurRadius: 15,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        key: const ValueKey('password-recovery-submit'),
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 19),
                        label: Text(
                          _isSubmitting
                              ? 'Enviando…'
                              : 'Enviar enlace de recuperación',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xB80F315B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF214572)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF70B4FF),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Si el correo está asociado a una cuenta activa, recibirás un enlace válido por 10 minutos. Puedes solicitar uno nuevo cada 2 minutos, con un máximo de 3 solicitudes por hora.',
                            style: TextStyle(
                              color: Color(0xFFBFD0E6),
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    key: const ValueKey('password-recovery-back'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF88BFFF),
                    ),
                    child: const Text(
                      'Volver al inicio de sesión',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
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

class _PasswordRecoveryMessage extends StatelessWidget {
  const _PasswordRecoveryMessage({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFFF9EAC) : const Color(0xFF9BE0C3);
    return Container(
      key: ValueKey(
        isError ? 'password-recovery-error' : 'password-recovery-success',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? const Color(0x22D9263F) : const Color(0x2216704F),
        border: Border.all(
          color: isError ? const Color(0xFF983B4C) : const Color(0xFF24765C),
        ),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 12, height: 1.45),
      ),
    );
  }
}

class _TabletLoginLayout extends StatelessWidget {
  const _TabletLoginLayout({
    required this.obscurePassword,
    required this.identifierController,
    required this.passwordController,
    required this.isSubmitting,
    required this.loginLockoutSeconds,
    required this.loginLockoutLabel,
    required this.errorMessage,
    required this.onLogin,
    required this.onTogglePassword,
  });

  final bool obscurePassword;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final int loginLockoutSeconds;
  final String loginLockoutLabel;
  final String? errorMessage;
  final VoidCallback onLogin;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final narrowTablet = width < 1000;
        final compact = width < 900 || height < 700;
        final formHeight = (height * 0.5).clamp(270.0, 460.0).toDouble();
        final visitorHeight = (height * 0.15).clamp(88.0, 124.0).toDouble();
        final sectionGap = height < 700 ? 12.0 : 20.0;
        final columnGap = (width * 0.025).clamp(12.0, 32.0).toDouble();
        final leftFlex = narrowTablet ? 35 : 43;
        final rightFlex = 100 - leftFlex;
        final rightWidth =
            (width - columnGap) * rightFlex / (leftFlex + rightFlex);
        final titleFontSize = (rightWidth * 0.085).clamp(26.0, 48.0).toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: leftFlex,
                    child: Center(
                      child: Image.asset(
                        'assets/images/cymez-reception-logo.webp',
                        cacheWidth: 720,
                        width: width * leftFlex / 100,
                        height: height * 0.78,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  SizedBox(width: columnGap),
                  Expanded(
                    flex: rightFlex,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(height: compact ? 8 : 32),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Bienvenido de nuevo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: titleFontSize,
                                height: 1.05,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 4 : 10),
                          Text(
                            'Inicia sesión para continuar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFFD0D7E8),
                              fontSize: (titleFontSize * 0.52)
                                  .clamp(15.0, 26.0)
                                  .toDouble(),
                            ),
                          ),
                          SizedBox(height: compact ? 10 : 24),
                          Padding(
                            padding: EdgeInsets.only(right: compact ? 8 : 20),
                            child: SizedBox(
                              key: const ValueKey('tablet-login-form-card'),
                              height: formHeight,
                              child: _LoginFormCard(
                                obscurePassword: obscurePassword,
                                identifierController: identifierController,
                                passwordController: passwordController,
                                isSubmitting: isSubmitting,
                                loginLockoutSeconds: loginLockoutSeconds,
                                loginLockoutLabel: loginLockoutLabel,
                                errorMessage: errorMessage,
                                onTogglePassword: onTogglePassword,
                                onLogin: onLogin,
                                compact: compact,
                                veryCompact: compact,
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
            SizedBox(height: sectionGap),
            Row(
              key: const ValueKey('tablet-visitor-divider'),
              children: [
                const Expanded(
                  child: _VisitorDividerLine(
                    colors: [Color(0x008DC8FF), Color(0xFF8DC8FF)],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x33101834),
                      borderRadius: const BorderRadius.all(Radius.circular(20)),
                      border: Border.all(color: const Color(0x338DC8FF)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 16,
                        vertical: 6,
                      ),
                      child: Text(
                        'Registro de visitantes',
                        style: TextStyle(
                          color: const Color(0xFFE5EAF5),
                          fontSize: compact ? 16 : 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: _VisitorDividerLine(
                    colors: [Color(0xFF8DC8FF), Color(0x00FF3155)],
                  ),
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            Center(
              child: FractionallySizedBox(
                widthFactor: compact ? 0.96 : 0.92,
                child: SizedBox(
                  key: const ValueKey('tablet-walk-in-card'),
                  height: visitorHeight,
                  child: _VisitorRegistrationCard(
                    compact: compact,
                    tablet: true,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WalkInVisitorPage(
                            authService: AuthService.shared,
                            draftStorage: SecureVisitorKioskDraftStorage(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    required this.identifierController,
    required this.passwordController,
    required this.isSubmitting,
    required this.loginLockoutSeconds,
    required this.loginLockoutLabel,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onLogin,
    this.onForgotPassword,
    required this.compact,
    required this.veryCompact,
    this.tablet = false,
  });

  final bool obscurePassword;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool isSubmitting;
  final int loginLockoutSeconds;
  final String loginLockoutLabel;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;
  final VoidCallback? onForgotPassword;
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
              final content = SizedBox(
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
                          : 12,
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
                      controller: identifierController,
                      icon: Icons.person_outline,
                      hint: 'Escribe tu usuario o correo',
                      compact: compact,
                      tablet: tablet,
                      textInputAction: TextInputAction.next,
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
                      controller: passwordController,
                      icon: Icons.lock_outline_rounded,
                      hint: 'Escribe tu contraseña',
                      obscure: obscurePassword,
                      compact: compact,
                      tablet: tablet,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onLogin(),
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
                    if (!tablet) ...[
                      SizedBox(height: compact ? 2 : 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const ValueKey('login-forgot-password'),
                          onPressed: onForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF7189),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(
                      height: compact
                          ? 3
                          : tablet
                          ? 26
                          : 12,
                    ),
                    if (errorMessage != null) ...[
                      Container(
                        key: const ValueKey('login-error-message'),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: loginLockoutSeconds > 0 ? 4 : 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF3155),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x88FF5A72)),
                        ),
                        child: Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          maxLines: loginLockoutSeconds > 0 ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFFFFB8C2),
                            fontSize: tablet
                                ? 14
                                : loginLockoutSeconds > 0
                                ? 11
                                : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 3 : 8),
                    ],
                    SizedBox(
                      height: compact
                          ? 38
                          : tablet
                          ? 68
                          : 54,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const ValueKey('login-submit-action'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: isSubmitting || loginLockoutSeconds > 0
                              ? null
                              : onLogin,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: loginLockoutSeconds > 0
                                  ? null
                                  : const [
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
                              gradient: loginLockoutSeconds > 0
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFF4D566A),
                                        Color(0xFF353D50),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFFFF3155),
                                        Color(0xFFB80035),
                                        Color(0xFFFF1744),
                                      ],
                                    ),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSubmitting) ...[
                                      SizedBox(
                                        width: tablet ? 21 : 18,
                                        height: tablet ? 21 : 18,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Validando...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: tablet ? 20 : 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ] else if (loginLockoutSeconds > 0) ...[
                                      Icon(
                                        Icons.lock_clock_rounded,
                                        color: Colors.white,
                                        size: tablet ? 24 : 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Intenta de nuevo en $loginLockoutLabel',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: tablet ? 17 : 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        'Iniciar sesión',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: tablet ? 20 : 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: tablet ? 24 : 24,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
              return tablet
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: content,
                    )
                  : content;
            },
          ),
        ),
      ),
    );
  }
}

class _LoginInput extends StatelessWidget {
  const _LoginInput({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.compact,
    this.tablet = false,
    this.obscure = false,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool compact;
  final bool tablet;
  final bool obscure;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
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
              controller: controller,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: !obscure,
              keyboardType: obscure
                  ? TextInputType.visiblePassword
                  : TextInputType.emailAddress,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
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
  const _ControlOnboardingCopy({this.tablet = false});

  final bool tablet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 400 ||
            (tablet && constraints.maxHeight < 500);
        final scale = tablet
            ? (constraints.maxWidth / 300).clamp(0.72, 1.45).toDouble()
            : 1.0;
        final titleScale = tablet
            ? (constraints.maxWidth / 260).clamp(0.72, 1.7).toDouble()
            : 1.0;
        final titleStyle = TextStyle(
          color: _white,
          fontSize:
              (tablet ? (compact ? 34 : 42) : (compact ? 38 : 46)) * titleScale,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 12)],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Controla entradas',
                style: titleStyle.copyWith(color: Colors.white),
                maxLines: 1,
                softWrap: false,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'y ',
                    style: titleStyle.copyWith(color: Colors.white),
                    maxLines: 1,
                    softWrap: false,
                  ),
                  ShaderMask(
                    key: const ValueKey('control-onboarding-gradient-word'),
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFFFF4563), Color(0xFF35BFFF)],
                    ).createShader(bounds),
                    child: Text(
                      'salidas',
                      style: titleStyle.copyWith(
                        color: _white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        shadows: const [
                          Shadow(
                            color: Color(0xB3071020),
                            offset: Offset(0, 2),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tablet ? 12 * scale : 12),
            Text(
              'Seguimiento y seguridad',
              style: TextStyle(
                color: Color(0xFF36BFFF),
                fontSize: (tablet ? 18 : 16) * scale,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
            SizedBox(height: tablet ? 14 * scale : 14),
            Text(
              'Consulta quién se encuentra dentro\n'
              'de las instalaciones y registra sus salidas\n'
              'para mantener un mejor control.',
              style: TextStyle(
                color: _white,
                fontSize: (tablet ? 16 : (compact ? 16 : 17)) * scale,
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
    this.width,
  });

  final bool compact;
  final VoidCallback onPressed;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Container(
      width: width ?? (tablet ? 220 : (compact ? 160 : 176)),
      height: tablet ? 68 : (compact ? 56 : 60),
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
                        fontSize: tablet ? 18 : (compact ? 15 : 17),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: _white,
                      size: tablet ? 24 : (compact ? 22 : 24),
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
  const _StartButton({
    required this.compact,
    required this.onStart,
    this.veryCompact = false,
  });

  final bool compact;
  final VoidCallback onStart;
  final bool veryCompact;

  @override
  Widget build(BuildContext context) {
    final tablet = MediaQuery.sizeOf(context).shortestSide >= 600;
    return Container(
      width: double.infinity,
      height: tablet ? 82 : (veryCompact ? 58 : (compact ? 70 : 76)),
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
                    fontSize: tablet
                        ? 24
                        : (veryCompact ? 18 : (compact ? 20 : 22)),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: _white,
                  size: tablet ? 32 : (veryCompact ? 23 : (compact ? 27 : 29)),
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
  const _PageIndicator({super.key, this.activeIndex = 0, this.onSelected});

  final int activeIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Página ${activeIndex + 1} de 3',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          3,
          (index) => Semantics(
            button: onSelected != null,
            selected: index == activeIndex,
            label: 'Ir a la página ${index + 1}',
            child: GestureDetector(
              key: ValueKey('onboarding-page-indicator-dot-$index'),
              behavior: HitTestBehavior.opaque,
              onTap: onSelected == null ? null : () => onSelected!(index),
              child: SizedBox(
                width: 21,
                height: 44,
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == activeIndex
                          ? _red
                          : const Color(0xFF486187),
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
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _finishOnboarding(
  BuildContext context,
  MobileOnboardingStorage? storage,
) async {
  final isPhone = !kIsWeb && MediaQuery.sizeOf(context).shortestSide < 600;
  if (isPhone && storage != null) {
    await storage.markOnboardingSeen();
  }
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const ReceptionLoginPage()),
    (_) => false,
  );
}

void _navigateToOnboardingPage(
  BuildContext context,
  int currentIndex,
  int targetIndex, {
  MobileOnboardingStorage? onboardingStorage,
}) {
  if (targetIndex == currentIndex || targetIndex < 0 || targetIndex > 2) {
    return;
  }

  final page = switch (targetIndex) {
    0 => ReceptionOnboardingPage(onboardingStorage: onboardingStorage),
    1 => ReceptionControlOnboardingPage(onboardingStorage: onboardingStorage),
    _ => ReceptionReadyOnboardingPage(onboardingStorage: onboardingStorage),
  };
  final route = MaterialPageRoute<void>(builder: (_) => page);
  final navigator = Navigator.of(context);
  if (targetIndex > currentIndex) {
    navigator.push(route);
  } else if (currentIndex - targetIndex == 1 && navigator.canPop()) {
    navigator.pop();
  } else {
    navigator.pushReplacement(route);
  }
}

class _OnboardingSwipeDetector extends StatefulWidget {
  const _OnboardingSwipeDetector({
    required this.activeIndex,
    required this.child,
    this.onboardingStorage,
  });

  final int activeIndex;
  final Widget child;
  final MobileOnboardingStorage? onboardingStorage;

  @override
  State<_OnboardingSwipeDetector> createState() =>
      _OnboardingSwipeDetectorState();
}

class _OnboardingSwipeDetectorState extends State<_OnboardingSwipeDetector> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) => _dragDistance += details.delta.dx,
      onHorizontalDragEnd: (_) {
        if (_dragDistance > 72 && widget.activeIndex < 2) {
          _navigateToOnboardingPage(
            context,
            widget.activeIndex,
            widget.activeIndex + 1,
            onboardingStorage: widget.onboardingStorage,
          );
        } else if (_dragDistance < -72 && widget.activeIndex > 0) {
          _navigateToOnboardingPage(
            context,
            widget.activeIndex,
            widget.activeIndex - 1,
            onboardingStorage: widget.onboardingStorage,
          );
        }
      },
      child: widget.child,
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
  const WalkInVisitorPage({
    super.key,
    this.authService,
    this.draftStorage,
    this.allowExit = true,
  });

  final AuthService? authService;
  final VisitorKioskDraftStorage? draftStorage;
  final bool allowExit;

  @override
  State<WalkInVisitorPage> createState() => _WalkInVisitorPageState();
}

class _WalkInVisitorPageState extends State<WalkInVisitorPage> {
  bool _walkInAssetsPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_walkInAssetsPrecached) {
      _walkInAssetsPrecached = true;
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
  }

  void _back() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF020817),
      body: size.shortestSide >= 600 && size.height > size.width
          ? _WalkInRotatePrompt(
              onExit: _back,
              tablet: true,
              allowExit: widget.allowExit,
            )
          : _WalkInLandscapeKiosk(
              authService: widget.authService,
              draftStorage: widget.draftStorage,
            ),
    );
  }
}

class _WalkInRotatePrompt extends StatelessWidget {
  const _WalkInRotatePrompt({
    this.onExit,
    this.tablet = false,
    this.allowExit = true,
  });

  final VoidCallback? onExit;
  final bool tablet;
  final bool allowExit;

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
                  Text(
                    'Gira tu ${tablet ? 'tablet' : 'celular'}',
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
                  if (allowExit && onExit != null) ...[
                    const SizedBox(height: 26),
                    TextButton.icon(
                      onPressed: onExit,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Volver al inicio de sesión'),
                    ),
                  ],
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
  const _WalkInLandscapeKiosk({this.authService, this.draftStorage});

  final AuthService? authService;
  final VisitorKioskDraftStorage? draftStorage;

  @override
  State<_WalkInLandscapeKiosk> createState() => _WalkInLandscapeKioskState();
}

class _TabletKioskWelcomeCopy extends StatelessWidget {
  const _TabletKioskWelcomeCopy({required this.scale, required this.onStart});

  final double scale;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 44 * scale,
      height: 1,
      fontWeight: FontWeight.w900,
    );

    return Column(
      key: const ValueKey('tablet-kiosk-welcome-copy'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/walk-in-access-shield.webp',
              width: 42 * scale,
              height: 42 * scale,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 14 * scale),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'CONTROL DE ACCESO',
                  style: TextStyle(
                    color: const Color(0xFFD9E2F3),
                    fontSize: 22 * scale,
                    letterSpacing: 1.4 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 18 * scale),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Bienvenido a nuestras', style: titleStyle),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFF8FAFF),
              Color(0xFFF8FAFF),
              Color(0xFF087FFF),
              Color(0xFFE53E4B),
            ],
            stops: [0, .43, .68, 1],
          ).createShader(bounds),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('instalaciones', style: titleStyle),
          ),
        ),
        SizedBox(height: 18 * scale),
        Text(
          'Para ingresar, completa tu registro de\nvisitante.',
          style: TextStyle(
            color: const Color(0xFFC7D0E3),
            fontSize: 16 * scale,
            height: 1.45,
          ),
        ),
        SizedBox(height: 18 * scale),
        Container(
          width: 205 * scale,
          height: 40 * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10 * scale),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFE53E4B), Color(0xFF087FFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x66E53E4B),
                blurRadius: 18 * scale,
                offset: Offset(0, 8 * scale),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('tablet-kiosk-welcome-start-button'),
              onTap: onStart,
              borderRadius: BorderRadius.circular(10 * scale),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 18 * scale,
                      ),
                      SizedBox(width: 7 * scale),
                      Text(
                        'Comenzar registro',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * scale,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18 * scale,
                      ),
                    ],
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

class _WalkInLandscapeKioskState extends State<_WalkInLandscapeKiosk> {
  bool _started = false;
  int _tabletStep = 1;
  bool _restoringDraft = true;
  bool _submitting = false;
  bool _publicGeneral = false;
  bool? _carriesItems;
  List<String> _identificationTypes = [];
  String? _errorMessage;
  String _idempotencyKey = '';
  String? _folio;
  String _authorizationStatus = 'Pendiente';
  bool _entryChecklistComplete = false;
  bool _entered = false;
  List<Map<String, Object?>> _items = [];
  Map<String, Object?> _editingItem = {};
  Timer? _statusTimer;
  Timer? _realtimeReconnectTimer;
  Timer? _draftSaveTimer;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  bool _statusRefreshInProgress = false;
  final _visitorNameController = TextEditingController();
  final _companyController = TextEditingController();
  final _reasonController = TextEditingController();

  VisitorKioskDraftStorage? get _draftStorage => widget.draftStorage;
  AuthService get _authService => widget.authService ?? AuthService.shared;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    _visitorNameController.addListener(_scheduleDraftSave);
    _companyController.addListener(_scheduleDraftSave);
    _reasonController.addListener(_scheduleDraftSave);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _realtimeReconnectTimer?.cancel();
    _realtimeSubscription?.cancel();
    _draftSaveTimer?.cancel();
    _visitorNameController.dispose();
    _companyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final storage = _draftStorage;
    if (storage == null) {
      if (mounted) setState(() => _restoringDraft = false);
      return;
    }
    var hasSubmittedRegistration = false;
    try {
      final draft = await storage.readDraft();
      if (!mounted) return;
      if (draft != null) {
        _visitorNameController.text = '${draft['visitorName'] ?? ''}';
        _companyController.text = '${draft['companyName'] ?? ''}';
        _reasonController.text = '${draft['visitReason'] ?? ''}';
        _started = draft['started'] == true;
        _tabletStep =
            (draft['step'] is num ? (draft['step'] as num).toInt() : 1).clamp(
              1,
              5,
            );
        _publicGeneral = draft['publicGeneral'] == true;
        _carriesItems = draft['carriesItems'] as bool?;
        final savedIdentificationTypes = draft['identificationTypes'];
        _identificationTypes = savedIdentificationTypes is List
            ? savedIdentificationTypes.whereType<String>().toList()
            : draft['identificationType'] is String
            ? [draft['identificationType'] as String]
            : [];
        _idempotencyKey = '${draft['idempotencyKey'] ?? ''}';
        _folio = draft['folio'] as String?;
        _authorizationStatus = '${draft['authorizationStatus'] ?? 'Pendiente'}';
        _entryChecklistComplete = draft['entryChecklistComplete'] == true;
        _entered = draft['entered'] == true;
        _items = (draft['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, Object?>.from(item))
            .toList();
        _editingItem = Map<String, Object?>.from(
          draft['editingItem'] as Map? ?? const {},
        );
        _started = _started || _tabletStep > 1;
        if (_idempotencyKey.isNotEmpty && _folio != null) {
          _tabletStep = 5;
          hasSubmittedRegistration = true;
        }
      }
    } on PlatformException {
      if (mounted) {
        setState(() {
          _restoringDraft = false;
          _errorMessage =
              'No se pudo recuperar el avance guardado en este dispositivo.';
        });
      }
      return;
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() {
          _restoringDraft = false;
          _errorMessage = error.message;
        });
      }
      return;
    } on FormatException {
      if (mounted) {
        setState(() {
          _restoringDraft = false;
          _errorMessage =
              'El avance guardado está dañado. Inicia un registro nuevo.';
        });
      }
      return;
    } on TypeError {
      if (mounted) {
        setState(() {
          _restoringDraft = false;
          _errorMessage =
              'El avance guardado no es válido. Inicia un registro nuevo.';
        });
      }
      return;
    }

    if (!mounted) return;
    if (hasSubmittedRegistration) {
      if (!_registrationIsFinished) {
        await _refreshRegistrationStatus();
      }
      if (!mounted) return;
      if (_registrationIsFinished) {
        await _startNewWalkIn();
      } else {
        _pollRegistrationStatus(refreshImmediately: false);
      }
    }
    if (mounted) setState(() => _restoringDraft = false);
  }

  bool get _registrationIsFinished =>
      (_authorizationStatus == 'Autorizada' && _entryChecklistComplete) ||
      _authorizationStatus == 'Rechazada';

  Map<String, dynamic> _draftData() => {
    'started': _started,
    'step': _tabletStep,
    'visitorName': _visitorNameController.text,
    'companyName': _companyController.text,
    'visitReason': _reasonController.text,
    'publicGeneral': _publicGeneral,
    'carriesItems': _carriesItems,
    'items': _items,
    'editingItem': _editingItem,
    'identificationTypes': _identificationTypes,
    'idempotencyKey': _idempotencyKey,
    'folio': _folio,
    'authorizationStatus': _authorizationStatus,
    'entryChecklistComplete': _entryChecklistComplete,
    'entered': _entered,
  };

  void _scheduleDraftSave() {
    if (_draftStorage == null || _restoringDraft || _tabletStep == 5) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 350), _saveDraft);
  }

  Future<bool> _saveDraft() async {
    final storage = _draftStorage;
    if (storage == null) return true;
    try {
      await storage.saveDraft(_draftData());
      return true;
    } on PlatformException {
      if (!mounted) return false;
      setState(() {
        _errorMessage =
            'No se pudo guardar el avance. Mantén esta pantalla abierta.';
      });
      return false;
    }
  }

  Future<void> _advanceTo(int step) async {
    final previousStep = _tabletStep;
    setState(() {
      _tabletStep = step;
      _errorMessage = null;
    });
    if (!await _saveDraft()) {
      if (mounted) setState(() => _tabletStep = previousStep);
      return;
    }
  }

  Future<void> _submitRegistration() async {
    if (_submitting) return;
    if (_visitorNameController.text.trim().isEmpty ||
        _companyController.text.trim().isEmpty ||
        _reasonController.text.trim().isEmpty ||
        _carriesItems == null ||
        (_carriesItems == true && _items.isEmpty) ||
        _identificationTypes.isEmpty) {
      setState(() {
        _errorMessage = 'Completa los datos obligatorios antes de enviar.';
      });
      return;
    }
    if (_idempotencyKey.isEmpty) _idempotencyKey = _newIdempotencyKey();
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    if (!await _saveDraft()) {
      if (mounted) setState(() => _submitting = false);
      return;
    }
    try {
      final result = await _authService.createVisitorKioskRegistration(
        idempotencyKey: _idempotencyKey,
        registration: {
          'visitorName': _visitorNameController.text.trim(),
          'companyName': _companyController.text.trim(),
          'visitReason': _reasonController.text.trim(),
          'carriesItems': _carriesItems,
          'items': _items,
          'identificationTypes': _identificationTypes,
        },
      );
      if (!mounted) return;
      setState(() {
        _folio = result['folio'] as String;
        _visitorNameController.text = result['visitorName'] as String;
        _tabletStep = 5;
        _submitting = false;
      });
      await _saveDraft();
      _pollRegistrationStatus();
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = error.message;
      });
    }
  }

  String _newIdempotencyKey() {
    final bytes = List<int>.generate(
      16,
      (_) => math.Random.secure().nextInt(256),
    );
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  void _pollRegistrationStatus({bool refreshImmediately = true}) {
    _statusTimer?.cancel();
    _connectRealtimeUpdates();
    if (refreshImmediately) unawaited(_refreshRegistrationStatus());
    _statusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshRegistrationStatus(),
    );
  }

  void _connectRealtimeUpdates() {
    if (!mounted || _idempotencyKey.isEmpty) return;
    _realtimeReconnectTimer?.cancel();
    _realtimeSubscription?.cancel();
    try {
      _realtimeSubscription = _authService
          .watchVisitorKioskUpdates(_idempotencyKey)
          .listen(
            (event) {
              if (event == RealtimeEvent.update) _refreshRegistrationStatus();
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Se interrumpió la actualización del kiosco: $error');
              _scheduleRealtimeReconnect();
            },
            onDone: _scheduleRealtimeReconnect,
          );
    } on AuthApiException catch (error) {
      setState(() => _errorMessage = error.message);
      _scheduleRealtimeReconnect();
    }
  }

  void _scheduleRealtimeReconnect() {
    if (!mounted ||
        _idempotencyKey.isEmpty ||
        _realtimeReconnectTimer != null) {
      return;
    }
    _realtimeReconnectTimer = Timer(const Duration(seconds: 3), () {
      _realtimeReconnectTimer = null;
      _connectRealtimeUpdates();
    });
  }

  Future<void> _refreshRegistrationStatus() async {
    if (_idempotencyKey.isEmpty || !mounted || _statusRefreshInProgress) {
      return;
    }
    final requestKey = _idempotencyKey;
    _statusRefreshInProgress = true;
    try {
      final status = await _authService.getVisitorKioskStatus(requestKey);
      if (!mounted || requestKey != _idempotencyKey) return;
      setState(() {
        _folio = status['folio'] as String;
        _authorizationStatus = status['authorizationStatus'] as String;
        _entryChecklistComplete = status['entryChecklistComplete'] as bool;
        _entered = status['entered'] as bool;
        _visitorNameController.text = status['visitorName'] as String;
        _errorMessage = null;
      });
      await _saveDraft();
    } on AuthApiException catch (error) {
      if (!mounted || requestKey != _idempotencyKey) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (requestKey == _idempotencyKey) {
        _statusRefreshInProgress = false;
      }
    }
  }

  Future<void> _startNewWalkIn() async {
    _statusTimer?.cancel();
    _statusTimer = null;
    _realtimeReconnectTimer?.cancel();
    _realtimeReconnectTimer = null;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = null;
    final previousSubscription = _realtimeSubscription;
    _realtimeSubscription = null;
    if (previousSubscription != null) {
      unawaited(
        previousSubscription.cancel().catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('No se pudo cerrar la actualización del kiosco: $error');
          debugPrintStack(stackTrace: stackTrace);
        }),
      );
    }
    _statusRefreshInProgress = false;
    if (!mounted) return;
    setState(() {
      _started = false;
      _tabletStep = 1;
      _visitorNameController.clear();
      _companyController.clear();
      _reasonController.clear();
      _publicGeneral = false;
      _carriesItems = null;
      _items = [];
      _editingItem = {};
      _identificationTypes = [];
      _idempotencyKey = '';
      _folio = null;
      _authorizationStatus = 'Pendiente';
      _entryChecklistComplete = false;
      _entered = false;
      _errorMessage = null;
    });
    try {
      await _draftStorage?.clearDraft();
    } on PlatformException {
      if (mounted) {
        const message = 'No se pudo borrar el avance anterior del dispositivo.';
        setState(() => _errorMessage = message);
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _goHome() async {
    await _startNewWalkIn();
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringDraft) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF168BFF)),
      );
    }
    final size = MediaQuery.sizeOf(context);
    if (size.width < 240 || size.height < 160) {
      return const SizedBox.expand();
    }
    final compact = size.height < 430;
    final portrait = size.height > size.width;
    final tabletForm = size.shortestSide >= 600 && _started;
    final tabletWelcome = size.shortestSide >= 600 && !_started;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/images/walk-in-registration-background.webp',
          fit: BoxFit.cover,
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
          SafeArea(
            child: Column(
              children: [
                _WalkInTabletHeader(width: size.width),
                Expanded(
                  child: _TabletKioskWelcomePanel(
                    onStart: () => setState(() => _started = true),
                  ),
                ),
              ],
            ),
          ),
        if (tabletForm)
          SafeArea(
            child: Column(
              children: [
                _WalkInTabletHeader(width: size.width),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = math.min(
                        constraints.maxWidth * .92,
                        math.min(constraints.maxHeight * 1.52, 1180.0),
                      );
                      final cardHeight = cardWidth / (1191 / 719);
                      final formContent = _tabletStep == 1
                          ? _TabletWalkInForm(
                              nameController: _visitorNameController,
                              companyController: _companyController,
                              reasonController: _reasonController,
                              publicGeneral: _publicGeneral,
                              onPublicGeneral: () {
                                setState(() {
                                  _publicGeneral = !_publicGeneral;
                                  _companyController.text = _publicGeneral
                                      ? 'Público general'
                                      : '';
                                });
                              },
                              onPrevious: _startNewWalkIn,
                              onContinue: () {
                                if (_visitorNameController.text
                                        .trim()
                                        .isEmpty ||
                                    _companyController.text.trim().isEmpty ||
                                    _reasonController.text.trim().isEmpty) {
                                  setState(() {
                                    _errorMessage = 'Completa tu nombre, empresa o procedencia y motivo de visita.';
                                  });
                                  return;
                                }
                                _advanceTo(2);
                              },
                              errorMessage: _errorMessage,
                            )
                          : _tabletStep == 2
                          ? _TabletWalkInEquipmentStep(
                              initialCarriesItems: _carriesItems,
                              initialItems: _items,
                              initialEditingItem: _editingItem,
                              onChanged: (carriesItems, items, editingItem) {
                                _carriesItems = carriesItems;
                                _items = items;
                                _editingItem = editingItem;
                                _scheduleDraftSave();
                              },
                              onPrevious: () => _advanceTo(1),
                              onContinue: () {
                                if (_carriesItems == null ||
                                    (_carriesItems == true && _items.isEmpty)) {
                                  setState(() {
                                    _errorMessage = 'Indica si llevas artículos y agrega al menos uno si seleccionaste que sí.';
                                  });
                                  return;
                                }
                                _advanceTo(3);
                              },
                            )
                          : _tabletStep == 3
                          ? _TabletWalkInIdentificationStep(
                              initialTypes: _identificationTypes,
                              onChanged: (types) {
                                _identificationTypes = types;
                                _scheduleDraftSave();
                              },
                              onPrevious: () => _advanceTo(2),
                              onContinue: () {
                                if (_identificationTypes.isEmpty) {
                                  setState(() {
                                    _errorMessage = 'Selecciona al menos un tipo de identificación.';
                                  });
                                  return;
                                }
                                _advanceTo(4);
                              },
                            )
                          : _tabletStep == 4
                          ? _TabletWalkInReviewStep(
                              onPrevious: () => _advanceTo(3),
                              onSubmit: _submitRegistration,
                              submitting: _submitting,
                              errorMessage: _errorMessage,
                              summary: [
                                (
                                  label: 'NOMBRE',
                                  value: _visitorNameController.text.trim(),
                                ),
                                (
                                  label: 'EMPRESA O PROCEDENCIA',
                                  value: _companyController.text.trim(),
                                ),
                                (
                                  label: 'ASUNTO',
                                  value: _reasonController.text.trim(),
                                ),
                                (
                                  label: 'EQUIPO Y HERRAMIENTAS',
                                  value: _carriesItems == true
                                      ? '${_items.length} artículo(s)'
                                      : 'No lleva artículos',
                                ),
                                (
                                  label: 'IDENTIFICACIÓN',
                                  value: _identificationTypes.join(', '),
                                ),
                              ],
                            )
                          : _TabletWalkInConfirmationStep(
                              visitorName: _visitorNameController.text,
                              folio: _folio ?? '',
                              authorizationStatus: _authorizationStatus,
                              entryChecklistComplete: _entryChecklistComplete,
                              entered: _entered,
                              hasItems: _carriesItems == true,
                              errorMessage: _errorMessage,
                              onHome: _goHome,
                            );
                      final card = Container(
                        key: const ValueKey('tablet-walk-in-form-card'),
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          image: const DecorationImage(
                            image: AssetImage(
                              'assets/images/visitor-feature-card.webp',
                            ),
                            fit: BoxFit.fill,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66087FFF),
                              blurRadius: 28,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: formContent,
                        ),
                      );
                      return Center(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          alignment: Alignment.center,
                          child: _tabletStep == 1
                              ? SizedBox(
                                  width: cardWidth,
                                  height: cardHeight,
                                  child: card,
                                )
                              : ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: cardWidth,
                                    maxHeight: constraints.maxHeight,
                                  ),
                                  child: SizedBox(
                                    width: cardWidth,
                                    child: card,
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
        if (!tabletForm)
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
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: const Color(
                                                            0xFFD9E2F3,
                                                          ),
                                                          fontSize: portrait
                                                              ? 16
                                                              : (size.width <
                                                                        700
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
                                                          ).createShader(
                                                            bounds,
                                                          ),
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
                                                        overflow: TextOverflow
                                                            .visible,
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
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    boxShadow: const [
                                                      BoxShadow(
                                                        color: Color(
                                                          0x66E53E4B,
                                                        ),
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
                                                                size.height <
                                                                    430
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
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                              fontSize: portrait
                                                                  ? 14
                                                                  : (size.width <
                                                                            700
                                                                        ? 18
                                                                        : 22),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 14,
                                                        ),
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

class _TabletWalkInConfirmationStep extends StatelessWidget {
  const _TabletWalkInConfirmationStep({
    required this.visitorName,
    required this.folio,
    required this.authorizationStatus,
    required this.entryChecklistComplete,
    required this.entered,
    required this.hasItems,
    required this.onHome,
    this.errorMessage,
  });

  final String visitorName;
  final String folio;
  final String authorizationStatus;
  final bool entryChecklistComplete;
  final bool entered;
  final bool hasItems;
  final String? errorMessage;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 1180).clamp(.62, 1.08);
        final rejected = authorizationStatus == 'Rechazada';
        final complete =
            authorizationStatus == 'Autorizada' && entryChecklistComplete;
        final waitingChecklist =
            authorizationStatus == 'Autorizada' &&
            hasItems &&
            !entryChecklistComplete;
        final title = rejected
            ? 'Visita no autorizada'
            : complete
            ? 'Visita registrada correctamente'
            : waitingChecklist
            ? 'Esperando revisión del checklist'
            : 'Esperando autorización de entrada';
        final detail = rejected
            ? 'Recepción no autorizó el ingreso. Acércate al personal para recibir indicaciones.'
            : complete
            ? 'Tu registro y la revisión de entrada quedaron confirmados. Sigue las indicaciones del personal de recepción.'
            : waitingChecklist
            ? 'Recepción autorizó la visita. Ahora está verificando el equipo y las herramientas declaradas.'
            : 'Tu llegada quedó anotada. Espera mientras recepción revisa tu registro${hasItems ? ' y el checklist de equipos' : ''}.';
        final accent = rejected
            ? const Color(0xFFFF7189)
            : complete
            ? const Color(0xFF55D6B2)
            : const Color(0xFF72C2FF);

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  54 * scale,
                  30 * scale,
                  54 * scale,
                  16 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76 * scale,
                      height: 76 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xB8071A32),
                        borderRadius: BorderRadius.circular(20 * scale),
                        border: Border.all(
                          color: accent.withValues(alpha: .75),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: .22),
                            blurRadius: 22 * scale,
                          ),
                        ],
                      ),
                      child: Icon(
                        rejected
                            ? Icons.cancel_outlined
                            : complete
                            ? Icons.verified_rounded
                            : Icons.schedule_rounded,
                        color: accent,
                        size: 42 * scale,
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                    Text(
                      rejected
                          ? 'ESTADO DE LA VISITA'
                          : complete
                          ? 'REGISTRO CONFIRMADO'
                          : 'AUTORIZACIÓN EN PROCESO',
                      style: TextStyle(
                        color: const Color(0xFFBFD7FF),
                        fontSize: 12 * scale,
                        letterSpacing: 1.3 * scale,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 18 * scale),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(
                        title,
                        key: const ValueKey('tablet-walk-in-status-title'),
                        style: TextStyle(
                          color: const Color(0xFFF4F7FF),
                          fontSize: 48 * scale,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2 * scale,
                        ),
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(
                        top: 18 * scale,
                        bottom: 20 * scale,
                      ),
                      width: 134 * scale,
                      height: 4 * scale,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8 * scale),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20 * scale,
                        vertical: 13 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xD50A1E37),
                        borderRadius: BorderRadius.circular(12 * scale),
                        border: Border.all(color: const Color(0xAA2878B4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FOLIO DE VISITANTE',
                            style: TextStyle(
                              color: const Color(0xFF7DBDF3),
                              fontSize: 10 * scale,
                              letterSpacing: 1.3 * scale,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            folio.isEmpty
                                ? '— — — — — — — —'
                                : folio.split('').join(' '),
                            key: const ValueKey('tablet-walk-in-folio'),
                            style: TextStyle(
                              color: const Color(0xFFF4F7FF),
                              fontSize: 28 * scale,
                              letterSpacing: 3 * scale,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                    Text(
                      visitorName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: Text(
                        detail,
                        style: TextStyle(
                          color: const Color(0xFFCBD8EB),
                          fontSize: 14 * scale,
                          height: 1.55,
                        ),
                      ),
                    ),
                    SizedBox(height: 15 * scale),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 10 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xAA0A2039),
                        borderRadius: BorderRadius.circular(9 * scale),
                        border: Border.all(color: accent.withValues(alpha: .5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!complete && !rejected)
                            SizedBox(
                              width: 18 * scale,
                              height: 18 * scale,
                              child: CircularProgressIndicator(
                                strokeWidth: 2 * scale,
                                color: accent,
                              ),
                            )
                          else
                            Icon(
                              complete
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.info_outline_rounded,
                              color: accent,
                              size: 19 * scale,
                            ),
                          SizedBox(width: 10 * scale),
                          Flexible(
                            child: Text(
                              errorMessage ??
                                  (complete
                                      ? 'Autorización y checklist completados por recepción.'
                                      : rejected
                                      ? 'Consulta con recepción para continuar.'
                                      : waitingChecklist
                                      ? 'Esperando checklist de entrada por recepción…'
                                      : 'Esperando autorización de entrada por recepción…'),
                              style: TextStyle(
                                color: const Color(0xFFD8E4F6),
                                fontSize: 12 * scale,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (entered && complete)
                      Padding(
                        padding: EdgeInsets.only(top: 10 * scale),
                        child: Text(
                          'Tu entrada ya quedó registrada.',
                          style: TextStyle(
                            color: const Color(0xFF68E0BD),
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(height: 1, color: const Color(0x553C8DDB)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                54 * scale,
                16 * scale,
                54 * scale,
                18 * scale,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11 * scale),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF087FFF), Color(0xFFFF3155)],
                    ),
                  ),
                  child: ElevatedButton.icon(
                    key: const ValueKey('tablet-walk-in-home-button'),
                    onPressed: onHome,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: 18 * scale,
                        vertical: 13 * scale,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10 * scale),
                      ),
                    ),
                    icon: Icon(Icons.home_rounded, size: 19 * scale),
                    label: Text(
                      'Inicio',
                      style: TextStyle(
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabletKioskWelcomePanel extends StatelessWidget {
  const _TabletKioskWelcomePanel({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = (width / 1180).clamp(.68, 1.25);
        final benefitsScale =
            ((width - 64 * scale - 24) / 3 / 270).clamp(.52, 1.0) *
            (width / 1024).clamp(.72, 1.0);
        final benefitsHeight = 112 * scale;
        return Container(
          key: const ValueKey('tablet-kiosk-welcome-panel'),
          margin: EdgeInsets.fromLTRB(
            width * .055,
            0,
            width * .055,
            14 * scale,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22 * scale),
            border: Border.all(
              color: const Color(0xB53D8FFF),
              width: 1.2 * scale,
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
            borderRadius: BorderRadius.circular(21 * scale),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/walk-in-panel-frame.webp',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
                Container(color: const Color(0x2607101F)),
                Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) {
                          final contentScale =
                              (contentConstraints.maxHeight / 500).clamp(
                                .62,
                                scale,
                              );
                          return Row(
                            children: [
                              Expanded(
                                flex: 58,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    52 * contentScale,
                                    24 * contentScale,
                                    12 * contentScale,
                                    12 * contentScale,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Transform.translate(
                                      offset: Offset(0, -20 * contentScale),
                                      child: _TabletKioskWelcomeCopy(
                                        scale: contentScale,
                                        onStart: onStart,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 42,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    0,
                                    10 * contentScale,
                                    22 * contentScale,
                                    8 * contentScale,
                                  ),
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
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      key: const ValueKey('tablet-kiosk-benefits'),
                      height: benefitsHeight,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 28 * scale,
                          vertical: 6 * scale,
                        ),
                        child: Transform.translate(
                          key: const ValueKey('tablet-kiosk-benefits-content'),
                          offset: Offset(0, -16 * scale),
                          child: Row(
                            children: [
                              Expanded(
                                child: _WalkInBenefit(
                                  icon: Icons.bolt_rounded,
                                  title: 'Proceso rápido',
                                  subtitle: 'En pocos minutos',
                                  color: Color(0xFFFF3155),
                                  scale: benefitsScale,
                                ),
                              ),
                              _WalkInBenefitDivider(),
                              Expanded(
                                child: _WalkInBenefit(
                                  icon: Icons.shield_outlined,
                                  title: 'Seguro y confiable',
                                  subtitle: 'Tu información protegida',
                                  color: Color(0xFF087FFF),
                                  scale: benefitsScale,
                                ),
                              ),
                              _WalkInBenefitDivider(),
                              Expanded(
                                child: _WalkInBenefit(
                                  icon: Icons.person_add_alt_1_rounded,
                                  title: 'Acceso controlado',
                                  subtitle: 'Para tu seguridad',
                                  color: Color(0xFFE7EEF9),
                                  scale: benefitsScale,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WalkInTabletHeader extends StatelessWidget {
  const _WalkInTabletHeader({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final scale = (width / 1024).clamp(.75, 1.25);
    return SizedBox(
      key: const ValueKey('walk-in-tablet-header'),
      height: 88 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 44 * scale),
        child: Row(
          children: [
            SizedBox(
              width: 64 * scale,
              height: 72 * scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: -8 * scale,
                    top: -8 * scale,
                    right: -8 * scale,
                    bottom: -8 * scale,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: 6 * scale,
                        sigmaY: 6 * scale,
                      ),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xB3006FFF),
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/images/cymez-visitor-logo.webp',
                          width: 80 * scale,
                          height: 88 * scale,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/images/cymez-visitor-logo.webp',
                    key: const ValueKey('walk-in-tablet-brand-logo'),
                    width: 64 * scale,
                    height: 72 * scale,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12 * scale),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 18 * scale,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1 * scale,
                    ),
                    children: const [
                      TextSpan(
                        text: 'CYMEZ ',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextSpan(
                        text: 'RECEP',
                        style: TextStyle(color: Color(0xFFFF3155)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  'VISITAS · CONTROL · SEGURIDAD',
                  style: TextStyle(
                    color: const Color(0xFFDCE6F7),
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2 * scale,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.only(right: 6 * scale),
              child: Icon(
                Icons.people_outline_rounded,
                color: const Color(0xFFDCE6F7),
                size: 23 * scale,
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'REGISTRO DE VISITANTES',
                  style: TextStyle(
                    color: const Color(0xFFDCE6F7),
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1 * scale,
                  ),
                ),
                SizedBox(height: 7 * scale),
                Container(
                  width: 28 * scale,
                  height: 3 * scale,
                  color: const Color(0xFFFF3155),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WalkInBenefit extends StatelessWidget {
  const _WalkInBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.scale,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final double? scale;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final portrait = size.height > size.width;
    final benefitScale = scale;
    final iconSize = benefitScale != null
        ? 38 * benefitScale
        : portrait
        ? 24.0
        : (size.width < 700 ? 34.0 : 44.0);
    final titleSize = benefitScale != null
        ? 20 * benefitScale
        : portrait
        ? 12.0
        : (size.width < 700 ? 17.0 : 22.0);
    final subtitleSize = benefitScale != null
        ? 16 * benefitScale
        : portrait
        ? 10.0
        : (size.width < 700 ? 15.0 : 18.0);
    return Container(
      key: ValueKey('walk-in-benefit-$title'),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(
            width: benefitScale != null
                ? 8 * benefitScale
                : portrait
                ? 6
                : 12,
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    key: ValueKey('walk-in-benefit-title-$title'),
                    title,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    key: ValueKey('walk-in-benefit-subtitle-$title'),
                    subtitle,
                    maxLines: 1,
                    style: TextStyle(
                      color: const Color(0xFFBAC7DE),
                      fontSize: subtitleSize,
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

class _WalkInBenefitDivider extends StatelessWidget {
  const _WalkInBenefitDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0x333D8FFF),
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

class _TabletWalkInForm extends StatelessWidget {
  const _TabletWalkInForm({
    required this.nameController,
    required this.companyController,
    required this.reasonController,
    required this.publicGeneral,
    required this.onPublicGeneral,
    required this.onPrevious,
    required this.onContinue,
    this.errorMessage,
  });

  final TextEditingController nameController;
  final TextEditingController companyController;
  final TextEditingController reasonController;
  final bool publicGeneral;
  final VoidCallback onPublicGeneral;
  final VoidCallback onPrevious;
  final VoidCallback onContinue;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math
            .min(constraints.maxWidth / 1180, constraints.maxHeight / 650)
            .clamp(0.62, 1.08);
        final horizontalPadding = 42 * scale;
        final verticalPadding = 34 * scale;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            30 * scale,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                0,
                constraints.maxHeight - verticalPadding - 30 * scale,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PASO 1 DE 4',
                  style: TextStyle(
                    color: const Color(0xFFBFD7FF),
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1 * scale,
                  ),
                ),
                SizedBox(height: 10 * scale),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8 * scale),
                  child: Stack(
                    children: [
                      Container(
                        height: 6 * scale,
                        color: const Color(0x99233048),
                      ),
                      FractionallySizedBox(
                        widthFactor: .25,
                        child: Container(
                          height: 6 * scale,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                            ),
                            borderRadius: BorderRadius.circular(8 * scale),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 34 * scale),
                Text(
                  'IDENTIFICACIÓN DE VISITA',
                  style: TextStyle(
                    color: const Color(0xFFBFD7FF),
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2 * scale,
                  ),
                ),
                SizedBox(height: 10 * scale),
                Row(
                  children: [
                    Container(
                      width: 62 * scale,
                      height: 62 * scale,
                      decoration: BoxDecoration(
                        color: const Color(0xCC07172E),
                        borderRadius: BorderRadius.circular(16 * scale),
                        border: Border.all(
                          color: const Color(0xFF087FFF),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.account_box_outlined,
                        color: const Color(0xFF63AEFF),
                        size: 34 * scale,
                      ),
                    ),
                    SizedBox(width: 18 * scale),
                    Expanded(
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFFF8FAFF),
                            Color(0xFFF8FAFF),
                            Color(0xFF087FFF),
                            Color(0xFFE53E4B),
                          ],
                          stops: [0, .66, .84, 1],
                        ).createShader(bounds),
                        child: Text(
                          'Datos del visitante',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 44 * scale,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2 * scale,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24 * scale),
                _TabletWalkInField(
                  label: 'Nombre completo',
                  hint: 'Escribe el nombre completo',
                  icon: Icons.person_outline_rounded,
                  scale: scale,
                  controller: nameController,
                ),
                SizedBox(height: 18 * scale),
                _TabletWalkInField(
                  label: 'Empresa o procedencia',
                  hint: 'Escribe empresa o procedencia',
                  icon: Icons.business_outlined,
                  scale: scale,
                  controller: companyController,
                ),
                SizedBox(height: 10 * scale),
                Text(
                  'Si no perteneces a una empresa o vienes por un asunto personal o ajeno a una empresa, selecciona:',
                  style: TextStyle(
                    color: const Color(0xFFBFD7FF),
                    fontSize: 12 * scale,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 10 * scale),
                OutlinedButton.icon(
                  key: const ValueKey('tablet-walk-in-public-general'),
                  onPressed: onPublicGeneral,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: publicGeneral
                          ? const Color(0xFFFF3155)
                          : const Color(0xFF087FFF),
                    ),
                    backgroundColor: publicGeneral
                        ? const Color(0xCC3A172E)
                        : const Color(0xCC07172E),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16 * scale,
                      vertical: 10 * scale,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10 * scale),
                    ),
                  ),
                  icon: Icon(
                    Icons.people_outline_rounded,
                    color: const Color(0xFF63AEFF),
                    size: 18 * scale,
                  ),
                  label: Text(
                    publicGeneral
                        ? 'Público general seleccionado'
                        : 'Soy público general',
                    style: TextStyle(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(height: 18 * scale),
                _TabletWalkInField(
                  label: 'Asunto o motivo de la visita',
                  hint: 'Describe el motivo de tu visita',
                  icon: Icons.chat_bubble_outline_rounded,
                  maxLines: 2,
                  scale: scale,
                  controller: reasonController,
                ),
                if (errorMessage != null) ...[
                  SizedBox(height: 12 * scale),
                  Text(
                    errorMessage!,
                    style: TextStyle(
                      color: const Color(0xFFFF7189),
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                SizedBox(height: 24 * scale),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onPrevious,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF087FFF)),
                        backgroundColor: const Color(0xCC07172E),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20 * scale,
                          vertical: 14 * scale,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10 * scale),
                        ),
                      ),
                      icon: Icon(Icons.arrow_back_rounded, size: 18 * scale),
                      label: Text(
                        'Anterior',
                        style: TextStyle(
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10 * scale),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                        ),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: onContinue,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            horizontal: 22 * scale,
                            vertical: 14 * scale,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10 * scale),
                          ),
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18 * scale,
                        ),
                        label: Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabletWalkInEquipmentStep extends StatefulWidget {
  const _TabletWalkInEquipmentStep({
    required this.onPrevious,
    required this.onContinue,
    required this.initialCarriesItems,
    required this.initialItems,
    required this.initialEditingItem,
    required this.onChanged,
  });

  final VoidCallback onPrevious;
  final VoidCallback onContinue;
  final bool? initialCarriesItems;
  final List<Map<String, Object?>> initialItems;
  final Map<String, Object?> initialEditingItem;
  final void Function(
    bool? carriesItems,
    List<Map<String, Object?>> items,
    Map<String, Object?> editingItem,
  )
  onChanged;

  @override
  State<_TabletWalkInEquipmentStep> createState() =>
      _TabletWalkInEquipmentStepState();
}

class _TabletWalkInEquipmentStepState
    extends State<_TabletWalkInEquipmentStep> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _colorController = TextEditingController();
  final List<Map<String, Object?>> _items = [];
  String _type = 'Equipo';
  bool? _bringsEquipment;
  String? _validationMessage;
  int? _editingItemIndex;

  @override
  void initState() {
    super.initState();
    _bringsEquipment = widget.initialCarriesItems;
    _items.addAll(
      widget.initialItems.map((item) => Map<String, Object?>.from(item)),
    );
    _editingItemIndex = widget.initialEditingItem['index'] as int?;
    _type = '${widget.initialEditingItem['type'] ?? 'Equipo'}';
    _nameController.text = '${widget.initialEditingItem['description'] ?? ''}';
    _quantityController.text =
        '${widget.initialEditingItem['quantity'] ?? '1'}';
    _brandController.text = '${widget.initialEditingItem['brand'] ?? ''}';
    _modelController.text = '${widget.initialEditingItem['model'] ?? ''}';
    _serialController.text =
        '${widget.initialEditingItem['serialNumber'] ?? ''}';
    _colorController.text = '${widget.initialEditingItem['color'] ?? ''}';
    for (final controller in [
      _nameController,
      _quantityController,
      _brandController,
      _modelController,
      _serialController,
      _colorController,
    ]) {
      controller.addListener(_notifyDraft);
    }
  }

  void _notifyDraft() {
    widget.onChanged(
      _bringsEquipment,
      _items.map((item) => Map<String, Object?>.from(item)).toList(),
      {
        'type': _type,
        'description': _nameController.text,
        'quantity': _quantityController.text,
        'brand': _brandController.text,
        'model': _modelController.text,
        'serialNumber': _serialController.text,
        'color': _colorController.text,
        if (_editingItemIndex != null) 'index': _editingItemIndex,
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());
    if (name.isEmpty || quantity == null || quantity < 1) {
      setState(() {
        _validationMessage = name.isEmpty
            ? 'Escribe el nombre o la descripción del artículo.'
            : 'La cantidad debe ser un número mayor que cero.';
      });
      return;
    }

    final item = <String, Object?>{
      'type': _type,
      'description': name,
      'quantity': quantity,
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'serialNumber': _serialController.text.trim(),
      'color': _colorController.text.trim(),
    };
    setState(() {
      final editingIndex = _editingItemIndex;
      if (editingIndex != null) {
        _items[editingIndex] = item;
        _editingItemIndex = null;
      } else {
        _items.add(item);
      }
      _nameController.clear();
      _quantityController.text = '1';
      _brandController.clear();
      _modelController.clear();
      _serialController.clear();
      _colorController.clear();
      _validationMessage = null;
      _notifyDraft();
    });
  }

  void _editItem(int index) {
    final item = _items[index];
    setState(() {
      _editingItemIndex = index;
      _type = '${item['type'] ?? 'Equipo'}';
      _nameController.text = '${item['description'] ?? ''}';
      _quantityController.text = '${item['quantity'] ?? 1}';
      _brandController.text = '${item['brand'] ?? ''}';
      _modelController.text = '${item['model'] ?? ''}';
      _serialController.text = '${item['serialNumber'] ?? ''}';
      _colorController.text = '${item['color'] ?? ''}';
      _validationMessage = null;
    });
    _notifyDraft();
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (_editingItemIndex == index) {
        _editingItemIndex = null;
        _nameController.clear();
        _quantityController.text = '1';
        _brandController.clear();
        _modelController.clear();
        _serialController.clear();
        _colorController.clear();
        _type = 'Equipo';
      } else if (_editingItemIndex != null && _editingItemIndex! > index) {
        _editingItemIndex = _editingItemIndex! - 1;
      }
      _validationMessage = null;
    });
    _notifyDraft();
  }

  void _cancelEditing() {
    setState(() {
      _editingItemIndex = null;
      _nameController.clear();
      _quantityController.text = '1';
      _brandController.clear();
      _modelController.clear();
      _serialController.clear();
      _colorController.clear();
      _type = 'Equipo';
      _validationMessage = null;
    });
    _notifyDraft();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math
            .min(constraints.maxWidth / 1180, constraints.maxHeight / 620)
            .clamp(.58, 1.08);
        final horizontalPadding = 42 * scale;
        final verticalPadding = 30 * scale;

        return CustomScrollView(
          shrinkWrap: true,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  28 * scale,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PASO 2 DE 4',
                      style: TextStyle(
                        color: const Color(0xFFBFD7FF),
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1 * scale,
                      ),
                    ),
                    SizedBox(height: 10 * scale),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8 * scale),
                      child: Stack(
                        children: [
                          Container(
                            height: 6 * scale,
                            color: const Color(0x99233048),
                          ),
                          FractionallySizedBox(
                            widthFactor: .5,
                            child: Container(
                              height: 6 * scale,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF3155),
                                    Color(0xFF087FFF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8 * scale),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 28 * scale),
                    Text(
                      'DECLARACIÓN DE ARTÍCULOS',
                      style: TextStyle(
                        color: const Color(0xFFBFD7FF),
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2 * scale,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      'Equipo y herramientas',
                      key: const ValueKey('tablet-equipment-title'),
                      style: TextStyle(
                        color: const Color(0xFFF4F7FF),
                        fontSize: 38 * scale,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1 * scale,
                      ),
                    ),
                    SizedBox(height: 10 * scale),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 14 * scale,
                        vertical: 10 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xAA261514),
                        border: Border.all(
                          color: const Color(0xAAFFAB35),
                          width: 1 * scale,
                        ),
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      child: Text(
                        'Declara todo el equipo y las herramientas que ingresarás a las instalaciones. Solo se permite el ingreso de artículos registrados; lo que no registres no podrá ingresar.',
                        style: TextStyle(
                          color: const Color(0xFFD8E4F6),
                          fontSize: 14 * scale,
                          height: 1.45,
                        ),
                      ),
                    ),
                    SizedBox(height: 12 * scale),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 9 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xAA071C36),
                        border: Border.all(color: const Color(0x553C8DDB)),
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      child: Text(
                        'Selecciona si ingresarás equipo o herramientas para continuar.',
                        style: TextStyle(
                          color: const Color(0xFFBFD7FF),
                          fontSize: 11 * scale,
                        ),
                      ),
                    ),
                    SizedBox(height: 16 * scale),
                    Row(
                      children: [
                        Expanded(
                          child: _TabletEquipmentChoice(
                            key: const ValueKey('tablet-equipment-yes'),
                            selected: _bringsEquipment == true,
                            icon: Icons.handyman_outlined,
                            title: 'Sí, llevo equipo o herramientas',
                            subtitle: 'Agrega los artículos que ingresarás.',
                            color: const Color(0xFF00AFFF),
                            scale: scale,
                            onTap: () {
                              setState(() {
                                _bringsEquipment = true;
                                _validationMessage = null;
                              });
                              _notifyDraft();
                            },
                          ),
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: _TabletEquipmentChoice(
                            key: const ValueKey('tablet-equipment-no'),
                            selected: _bringsEquipment == false,
                            icon: Icons.block_rounded,
                            title: 'No llevo equipo ni herramientas',
                            subtitle: 'Continuarás sin declarar artículos.',
                            color: const Color(0xFFFF318B),
                            scale: scale,
                            onTap: () {
                              setState(() {
                                _bringsEquipment = false;
                                _items.clear();
                                _editingItemIndex = null;
                                _nameController.clear();
                                _quantityController.text = '1';
                                _brandController.clear();
                                _modelController.clear();
                                _serialController.clear();
                                _colorController.clear();
                                _type = 'Equipo';
                                _validationMessage = null;
                              });
                              _notifyDraft();
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_bringsEquipment == true) ...[
                      SizedBox(height: 12 * scale),
                      _TabletEquipmentEntryForm(
                        scale: scale,
                        type: _type,
                        onTypeChanged: (value) {
                          setState(() => _type = value);
                          _notifyDraft();
                        },
                        nameController: _nameController,
                        quantityController: _quantityController,
                        brandController: _brandController,
                        modelController: _modelController,
                        serialController: _serialController,
                        colorController: _colorController,
                        onAdd: _addItem,
                        onEdit: _editItem,
                        onDelete: _deleteItem,
                        items: _items,
                        editingItemIndex: _editingItemIndex,
                        onCancelEditing: _cancelEditing,
                        validationMessage: _validationMessage,
                      ),
                    ] else if (_bringsEquipment == false) ...[
                      SizedBox(height: 12 * scale),
                      Container(
                        key: const ValueKey('tablet-equipment-none-message'),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 14 * scale,
                          vertical: 12 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xAA061C39),
                          border: Border.all(color: const Color(0xAA087FFF)),
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: const Color(0xFF42A5FF),
                              size: 20 * scale,
                            ),
                            SizedBox(width: 10 * scale),
                            Expanded(
                              child: Text(
                                'Has indicado que no llevas artículos.',
                                style: TextStyle(
                                  color: const Color(0xFFD8E4F6),
                                  fontSize: 12 * scale,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 16 * scale),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onPrevious,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF087FFF)),
                            backgroundColor: const Color(0xCC07172E),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20 * scale,
                              vertical: 13 * scale,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9 * scale),
                            ),
                          ),
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            size: 17 * scale,
                          ),
                          label: Text(
                            'Anterior',
                            style: TextStyle(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9 * scale),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                            ),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: widget.onContinue,
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(
                                horizontal: 22 * scale,
                                vertical: 13 * scale,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9 * scale),
                              ),
                            ),
                            iconAlignment: IconAlignment.end,
                            icon: Icon(
                              Icons.arrow_forward_rounded,
                              size: 17 * scale,
                            ),
                            label: Text(
                              'Continuar',
                              style: TextStyle(
                                fontSize: 13 * scale,
                                fontWeight: FontWeight.w900,
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
          ],
        );
      },
    );
  }
}

class _TabletWalkInIdentificationStep extends StatefulWidget {
  const _TabletWalkInIdentificationStep({
    required this.onPrevious,
    required this.onContinue,
    required this.initialTypes,
    required this.onChanged,
  });

  final VoidCallback onPrevious;
  final VoidCallback onContinue;
  final List<String> initialTypes;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TabletWalkInIdentificationStep> createState() =>
      _TabletWalkInIdentificationStepState();
}

class _TabletWalkInIdentificationStepState
    extends State<_TabletWalkInIdentificationStep> {
  late final Set<String> _identificationTypes = widget.initialTypes.toSet();

  void _toggleType(String type) {
    setState(() {
      if (!_identificationTypes.add(type)) {
        _identificationTypes.remove(type);
      }
    });
    widget.onChanged(_identificationTypes.toList());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math
            .min(constraints.maxWidth / 1180, constraints.maxHeight / 620)
            .clamp(.58, 1.08);
        final horizontalPadding = 42 * scale;
        final verticalPadding = 30 * scale;
        final identificationOptions = [
          (title: 'INE', icon: Icons.badge_outlined),
          (title: 'Gafete', icon: Icons.shield_outlined),
          (title: 'Pasaporte', icon: Icons.contact_page_outlined),
          (title: 'Licencia de conducir', icon: Icons.badge_outlined),
          (title: 'Otra identificación', icon: Icons.add_moderator_outlined),
        ];

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            28 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PASO 3 DE 4',
                style: TextStyle(
                  color: const Color(0xFFBFD7FF),
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1 * scale,
                ),
              ),
              SizedBox(height: 10 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Stack(
                  children: [
                    Container(
                      height: 6 * scale,
                      color: const Color(0x99233048),
                    ),
                    FractionallySizedBox(
                      widthFactor: .75,
                      child: Container(
                        height: 6 * scale,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                          ),
                          borderRadius: BorderRadius.circular(8 * scale),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 28 * scale),
              Text(
                'CONTROL DE IDENTIDAD',
                style: TextStyle(
                  color: const Color(0xFFBFD7FF),
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2 * scale,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                'Identificación',
                key: const ValueKey('tablet-identification-title'),
                style: TextStyle(
                  color: const Color(0xFFF4F7FF),
                  fontSize: 38 * scale,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1 * scale,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                'Selecciona uno o varios tipos de identificación presentados. No captures números ni fotografías del documento.',
                style: TextStyle(
                  color: const Color(0xFFD8E4F6),
                  fontSize: 14 * scale,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 12 * scale),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 9 * scale,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xAA071C36),
                  border: Border.all(color: const Color(0x553C8DDB)),
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: Text(
                  'Recuperamos tu avance. Si vuelves a recargar esta pestaña, se conservará.',
                  style: TextStyle(
                    color: const Color(0xFFBFD7FF),
                    fontSize: 11 * scale,
                  ),
                ),
              ),
              SizedBox(height: 18 * scale),
              Text(
                'Tipo de identificación presentada *',
                style: TextStyle(
                  color: const Color(0xFFE7EEF9),
                  fontSize: 13 * scale,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 10 * scale),
              Row(
                children: [
                  for (
                    var index = 0;
                    index < identificationOptions.length;
                    index++
                  ) ...[
                    if (index > 0) SizedBox(width: 10 * scale),
                    Expanded(
                      child: _TabletIdentificationOption(
                        key: ValueKey(
                          'tablet-identification-option-${identificationOptions[index].title}',
                        ),
                        title: identificationOptions[index].title,
                        icon: identificationOptions[index].icon,
                        selected: _identificationTypes.contains(
                          identificationOptions[index].title,
                        ),
                        scale: scale,
                        onTap: () =>
                            _toggleType(identificationOptions[index].title),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 16 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onPrevious,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF087FFF)),
                      backgroundColor: const Color(0xCC07172E),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20 * scale,
                        vertical: 13 * scale,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9 * scale),
                      ),
                    ),
                    icon: Icon(Icons.arrow_back_rounded, size: 17 * scale),
                    label: Text(
                      'Anterior',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9 * scale),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: widget.onContinue,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          horizontal: 22 * scale,
                          vertical: 13 * scale,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9 * scale),
                        ),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: Icon(Icons.arrow_forward_rounded, size: 17 * scale),
                      label: Text(
                        'Continuar',
                        style: TextStyle(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabletWalkInReviewStep extends StatefulWidget {
  const _TabletWalkInReviewStep({
    required this.onPrevious,
    required this.onSubmit,
    required this.summary,
    required this.submitting,
    this.errorMessage,
  });

  final VoidCallback onPrevious;
  final VoidCallback onSubmit;
  final List<({String label, String value})> summary;
  final bool submitting;
  final String? errorMessage;

  @override
  State<_TabletWalkInReviewStep> createState() =>
      _TabletWalkInReviewStepState();
}

class _TabletWalkInReviewStepState extends State<_TabletWalkInReviewStep> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math
            .min(constraints.maxWidth / 1180, constraints.maxHeight / 620)
            .clamp(.58, 1.08);
        final horizontalPadding = 42 * scale;
        final verticalPadding = 30 * scale;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            28 * scale,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PASO 4 DE 4',
                style: TextStyle(
                  color: const Color(0xFFBFD7FF),
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1 * scale,
                ),
              ),
              SizedBox(height: 10 * scale),
              ClipRRect(
                borderRadius: BorderRadius.circular(8 * scale),
                child: Container(
                  height: 6 * scale,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 28 * scale),
              Text(
                'ÚLTIMA REVISIÓN',
                style: TextStyle(
                  color: const Color(0xFFBFD7FF),
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2 * scale,
                ),
              ),
              SizedBox(height: 8 * scale),
              Text(
                'Revisa tu registro',
                key: const ValueKey('tablet-review-title'),
                style: TextStyle(
                  color: const Color(0xFFF4F7FF),
                  fontSize: 38 * scale,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1 * scale,
                ),
              ),
              SizedBox(height: 18 * scale),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 12 * scale,
                  vertical: 9 * scale,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xAA071C36),
                  border: Border.all(color: const Color(0x553C8DDB)),
                  borderRadius: BorderRadius.circular(8 * scale),
                ),
                child: Text(
                  'Recuperamos tu avance. Si vuelves a recargar esta pestaña, se conservará.',
                  style: TextStyle(
                    color: const Color(0xFFBFD7FF),
                    fontSize: 11 * scale,
                  ),
                ),
              ),
              SizedBox(height: 16 * scale),
              LayoutBuilder(
                builder: (context, gridConstraints) {
                  final gap = 10 * scale;
                  final cellWidth = (gridConstraints.maxWidth - gap) / 2;
                  final cellHeight = 62 * scale;
                  return Wrap(
                    spacing: gap,
                    runSpacing: 10 * scale,
                    children: [
                      for (final item in widget.summary)
                        SizedBox(
                          width: cellWidth,
                          height: cellHeight,
                          child: _TabletReviewSummaryCard(
                            label: item.label,
                            value: item.value,
                            scale: scale,
                          ),
                        ),
                    ],
                  );
                },
              ),
              SizedBox(height: 16 * scale),
              Material(
                color: const Color(0xB8071830),
                borderRadius: BorderRadius.circular(10 * scale),
                child: InkWell(
                  key: const ValueKey('tablet-review-confirmation'),
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  borderRadius: BorderRadius.circular(10 * scale),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14 * scale),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0x553C8DDB)),
                      borderRadius: BorderRadius.circular(10 * scale),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _confirmed
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          key: const ValueKey('tablet-review-checkbox-icon'),
                          color: _confirmed
                              ? const Color(0xFF36A4FF)
                              : const Color(0xFF78B7FF),
                          size: 23 * scale,
                        ),
                        SizedBox(width: 12 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confirmo que la información proporcionada es correcta.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13 * scale,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 5 * scale),
                              Text(
                                'Verifica tus datos antes de enviar el registro.',
                                style: TextStyle(
                                  color: const Color(0xFFBFD7FF),
                                  fontSize: 11 * scale,
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
              SizedBox(height: 16 * scale),
              if (widget.errorMessage != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 12 * scale),
                  child: Text(
                    widget.errorMessage!,
                    style: TextStyle(
                      color: const Color(0xFFFF7189),
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onPrevious,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF087FFF)),
                      backgroundColor: const Color(0xCC07172E),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20 * scale,
                        vertical: 13 * scale,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9 * scale),
                      ),
                    ),
                    icon: Icon(Icons.arrow_back_rounded, size: 17 * scale),
                    label: Text(
                      'Anterior',
                      style: TextStyle(
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9 * scale),
                      gradient: _confirmed
                          ? const LinearGradient(
                              colors: [Color(0xFFFF3155), Color(0xFF087FFF)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF596274), Color(0xFF596274)],
                            ),
                    ),
                    child: ElevatedButton.icon(
                      key: const ValueKey('tablet-review-submit'),
                      onPressed: _confirmed && !widget.submitting
                          ? widget.onSubmit
                          : null,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(
                          horizontal: 22 * scale,
                          vertical: 13 * scale,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9 * scale),
                        ),
                      ),
                      icon: widget.submitting
                          ? SizedBox(
                              width: 16 * scale,
                              height: 16 * scale,
                              child: CircularProgressIndicator(
                                strokeWidth: 2 * scale,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.send_rounded, size: 16 * scale),
                      label: Text(
                        widget.submitting ? 'Enviando…' : 'Enviar registro',
                        style: TextStyle(
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TabletReviewSummaryCard extends StatelessWidget {
  const _TabletReviewSummaryCard({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('tablet-review-summary-$label'),
      padding: EdgeInsets.symmetric(
        horizontal: 14 * scale,
        vertical: 9 * scale,
      ),
      decoration: BoxDecoration(
        color: const Color(0xCC07182D),
        border: Border.all(color: const Color(0x553C8DDB)),
        borderRadius: BorderRadius.circular(9 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF61B7FF),
              fontSize: 10 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: .45 * scale,
            ),
          ),
          SizedBox(height: 5 * scale),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletIdentificationOption extends StatelessWidget {
  const _TabletIdentificationOption({
    super.key,
    required this.title,
    required this.icon,
    required this.selected,
    required this.scale,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10 * scale),
        gradient: LinearGradient(
          colors: selected
              ? const [Color(0xFFFF3155), Color(0xFF087FFF)]
              : const [Color(0x774A82B9), Color(0x774A82B9)],
        ),
      ),
      padding: EdgeInsets.all(1 * scale),
      child: Material(
        color: const Color(0xF0071123),
        borderRadius: BorderRadius.circular(9 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9 * scale),
          child: SizedBox(
            height: 104 * scale,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        color: selected
                            ? const Color(0xFF60B4FF)
                            : const Color(0xFF78B7FF),
                        size: 29 * scale,
                      ),
                      SizedBox(height: 10 * scale),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            key: ValueKey('tablet-identification-label-$title'),
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12 * scale,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 7 * scale,
                    right: 7 * scale,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: const Color(0xFF6CC2FF),
                      size: 17 * scale,
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

class _TabletEquipmentChoice extends StatelessWidget {
  const _TabletEquipmentChoice({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.scale,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12 * scale),
        gradient: LinearGradient(
          colors: [
            selected ? color : const Color(0x99FF3155),
            selected ? color : const Color(0x990087FF),
          ],
        ),
        boxShadow: selected
            ? [BoxShadow(color: color.withValues(alpha: .25), blurRadius: 16)]
            : null,
      ),
      padding: EdgeInsets.all(1 * scale),
      child: Material(
        color: const Color(0xF0071123),
        borderRadius: BorderRadius.circular(11 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11 * scale),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14 * scale,
              vertical: 12 * scale,
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 30 * scale),
                SizedBox(width: 12 * scale),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5 * scale),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: const Color(0xFFBFD7FF),
                          fontSize: 11 * scale,
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
    );
  }
}

class _TabletEquipmentEntryForm extends StatelessWidget {
  const _TabletEquipmentEntryForm({
    required this.scale,
    required this.type,
    required this.onTypeChanged,
    required this.nameController,
    required this.quantityController,
    required this.brandController,
    required this.modelController,
    required this.serialController,
    required this.colorController,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.items,
    required this.editingItemIndex,
    required this.onCancelEditing,
    required this.validationMessage,
  });

  final double scale;
  final String type;
  final ValueChanged<String> onTypeChanged;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController brandController;
  final TextEditingController modelController;
  final TextEditingController serialController;
  final TextEditingController colorController;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;
  final List<Map<String, Object?>> items;
  final int? editingItemIndex;
  final VoidCallback onCancelEditing;
  final String? validationMessage;

  InputDecoration _decoration() => InputDecoration(
    filled: true,
    fillColor: const Color(0xF0061020),
    contentPadding: EdgeInsets.symmetric(
      horizontal: 12 * scale,
      vertical: 9 * scale,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8 * scale),
      borderSide: const BorderSide(color: Color(0xFF24405F)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8 * scale),
      borderSide: BorderSide(
        color: const Color(0xFF168BFF),
        width: 1.2 * scale,
      ),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * scale)),
  );

  Widget _field(String label, Widget input) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.only(left: 2 * scale, bottom: 5 * scale),
        child: Text(
          label,
          key: ValueKey('tablet-equipment-label-$label'),
          style: TextStyle(
            color: const Color(0xFFE2EBFA),
            fontSize: 11 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      input,
    ],
  );

  Widget _input(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return _field(
      label,
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12 * scale,
          fontWeight: FontWeight.w600,
        ),
        decoration: _decoration(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('tablet-equipment-entry-form'),
      width: double.infinity,
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: const Color(0xC9071020),
        border: Border.all(color: const Color(0xAA087FFF)),
        borderRadius: BorderRadius.circular(9 * scale),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _field(
                  'Tipo',
                  DropdownButtonFormField<String>(
                    key: const ValueKey('tablet-equipment-type-select'),
                    initialValue: type,
                    dropdownColor: const Color(0xFF0C1830),
                    borderRadius: BorderRadius.circular(12 * scale),
                    menuMaxHeight: 220 * scale,
                    icon: Icon(
                      Icons.expand_more_rounded,
                      color: const Color(0xFF71B9FF),
                      size: 22 * scale,
                    ),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: _decoration(),
                    items: const [
                      DropdownMenuItem(
                        value: 'Equipo',
                        child: Row(
                          children: [
                            Icon(
                              Icons.devices_other_rounded,
                              color: Color(0xFF58B8FF),
                              size: 17,
                            ),
                            SizedBox(width: 9),
                            Text('Equipo'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Herramienta',
                        child: Row(
                          children: [
                            Icon(
                              Icons.handyman_outlined,
                              color: Color(0xFFFF5B83),
                              size: 17,
                            ),
                            SizedBox(width: 9),
                            Text('Herramienta'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onTypeChanged(value);
                    },
                  ),
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                flex: 2,
                child: _input('Nombre o descripción *', nameController),
              ),
            ],
          ),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              Expanded(
                child: _input(
                  'Cantidad',
                  quantityController,
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(child: _input('Marca', brandController)),
              SizedBox(width: 10 * scale),
              Expanded(child: _input('Modelo', modelController)),
            ],
          ),
          SizedBox(height: 10 * scale),
          Row(
            children: [
              Expanded(child: _input('Número de serie', serialController)),
              SizedBox(width: 10 * scale),
              Expanded(child: _input('Color', colorController)),
              SizedBox(width: 10 * scale),
              Expanded(
                child: SizedBox(
                  height: 42 * scale,
                  child: OutlinedButton.icon(
                    onPressed: onAdd,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF087FFF)),
                      backgroundColor: const Color(0xAA07172E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7 * scale),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                    ),
                    icon: Icon(
                      Icons.add_rounded,
                      color: const Color(0xFF64B6FF),
                      size: 18 * scale,
                    ),
                    label: Text(
                      editingItemIndex == null
                          ? 'Agregar artículo'
                          : 'Guardar cambios',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11 * scale,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (editingItemIndex != null) ...[
            SizedBox(height: 7 * scale),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('tablet-equipment-cancel-edit'),
                onPressed: onCancelEditing,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFBFD7FF),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(Icons.close_rounded, size: 15 * scale),
                label: Text(
                  'Cancelar edición',
                  style: TextStyle(fontSize: 10 * scale),
                ),
              ),
            ),
          ],
          if (validationMessage != null) ...[
            SizedBox(height: 7 * scale),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                validationMessage!,
                style: TextStyle(
                  color: const Color(0xFFFF7189),
                  fontSize: 10 * scale,
                ),
              ),
            ),
          ],
          if (items.isNotEmpty) ...[
            SizedBox(height: 10 * scale),
            for (var index = 0; index < items.length; index++)
              Padding(
                key: ValueKey('tablet-equipment-item-$index'),
                padding: EdgeInsets.only(bottom: 5 * scale),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: const Color(0xFF45A5FF),
                      size: 16 * scale,
                    ),
                    SizedBox(width: 8 * scale),
                    Expanded(
                      child: Text(
                        '${items[index]['type']}: ${items[index]['description']}'
                        '${(items[index]['quantity'] as num?)?.toInt() == 1 ? '' : ' · ${items[index]['quantity']} pzas.'}',
                        style: TextStyle(
                          color: const Color(0xFFD8E4F6),
                          fontSize: 11 * scale,
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('tablet-equipment-edit-$index'),
                      onPressed: () => onEdit(index),
                      tooltip: 'Editar artículo',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: const Color(0xFF70B8FF),
                        size: 17 * scale,
                      ),
                    ),
                    IconButton(
                      key: ValueKey('tablet-equipment-delete-$index'),
                      onPressed: () => onDelete(index),
                      tooltip: 'Eliminar artículo',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: const Color(0xFFFF7189),
                        size: 18 * scale,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TabletWalkInField extends StatelessWidget {
  const _TabletWalkInField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.scale,
    this.maxLines = 1,
    this.controller,
    this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final double scale;
  final int maxLines;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17 * scale, color: const Color(0xFFFF4564)),
            SizedBox(width: 10 * scale),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 5 * scale),
            Text(
              '*',
              style: TextStyle(
                color: const Color(0xFFFF4564),
                fontSize: 14 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        SizedBox(height: 9 * scale),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10 * scale),
            gradient: const LinearGradient(
              colors: [Color(0xFFE53E4B), Color(0xFF087FFF)],
            ),
          ),
          padding: EdgeInsets.all(1 * scale),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: maxLines,
            minLines: maxLines,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF93A3BD),
                fontSize: 14 * scale,
              ),
              prefixIcon: Icon(
                icon,
                color: const Color(0xFFDCE6F7),
                size: 21 * scale,
              ),
              filled: true,
              fillColor: const Color(0xF0071020),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16 * scale,
                vertical: 13 * scale,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9 * scale),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9 * scale),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9 * scale),
                borderSide: BorderSide(
                  color: const Color(0xFF53A6FF),
                  width: 1.2 * scale,
                ),
              ),
            ),
          ),
        ),
      ],
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
  const ReceptionHomePage({super.key, this.authService, this.user});

  final AuthService? authService;
  final AuthenticatedUser? user;

  @override
  Widget build(BuildContext context) {
    return _ReceptionDashboardPage(authService: authService, user: user);
  }
}

class _ReceptionDashboardPage extends StatefulWidget {
  const _ReceptionDashboardPage({this.authService, this.user});

  final AuthService? authService;
  final AuthenticatedUser? user;

  @override
  State<_ReceptionDashboardPage> createState() =>
      _ReceptionDashboardPageState();
}

class _ReceptionDashboardPageState extends State<_ReceptionDashboardPage> {
  late String _activeSection;
  Map<String, dynamic>? _externalStaffAppointment;
  bool _isLoggingOut = false;
  bool _isDarkMode = true;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _activeSection = user?.isAdmin == true
        ? 'home'
        : user?.sectionAccess.contains('recepcion') == true ||
              user?.sectionAccess.contains('anfitriones') == true
        ? 'appointments'
        : 'access_denied';
  }

  bool _canAccessSection(String section) {
    final user = widget.user;
    if (user?.isAdmin == true) return true;
    if (user?.sectionAccess.contains('recepcion') == true) {
      return section == 'appointments' || section == 'logbook';
    }
    if (user?.sectionAccess.contains('anfitriones') == true) {
      return section == 'external_companies' ||
          section == 'external_staff' ||
          section == 'appointments' ||
          section == 'equipment';
    }
    return false;
  }

  bool get _canManageExternalModules {
    final user = widget.user;
    return user != null &&
        (user.isAdmin ||
            (user.sectionAccess.contains('anfitriones') &&
                !user.sectionAccess.contains('recepcion')));
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    final authService = widget.authService ?? AuthService.shared;
    try {
      await authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReceptionLoginPage(authService: authService),
        ),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      AppFeedback.show(context, error.message, type: AppFeedbackType.error);
    }
  }

  Widget _withAuthService(
    Widget Function(AuthService authService, AuthenticatedUser? user) builder,
  ) {
    final authService = widget.authService;
    if (authService == null) {
      return const Center(
        child: Text(
          'No hay una sesión disponible para consultar esta sección.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    return builder(authService, widget.user);
  }

  void _openSection(String section) {
    if (!_canAccessSection(section)) return;
    setState(() => _activeSection = section);
  }

  void _openDepartments() => _openSection('departments');

  void _openHome() => _openSection('home');

  void _openHosts() => _openSection('hosts');

  void _openAccesses() => _openSection('accesses');

  void _openExternalCompanies() => _openSection('external_companies');

  void _openExternalStaff([Map<String, dynamic>? appointment]) {
    if (!_canAccessSection('external_staff')) return;
    setState(() {
      _externalStaffAppointment = appointment;
      _activeSection = 'external_staff';
    });
  }

  void _openEquipment() => _openSection('equipment');

  void _openAppointments() => _openSection('appointments');

  void _openLogbook() => _openSection('logbook');

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: _isDarkMode
          ? const Color(0xFF07101F)
          : const Color(0xFFF3F7FC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF087FFF),
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      fontFamily: 'Roboto',
      dialogTheme: DialogThemeData(
        backgroundColor: _isDarkMode ? const Color(0xFF0D1730) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
    );
    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 220),
      child: _DashboardThemeScope(
        isDarkMode: _isDarkMode,
        onChanged: (value) => setState(() => _isDarkMode = value),
        child: ReceptionThemeScope(
          isDarkMode: _isDarkMode,
          onChanged: (value) => setState(() => _isDarkMode = value),
          onLogout: _logout,
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            key: const ValueKey('reception-dashboard-scaffold'),
            backgroundColor: theme.scaffoldBackgroundColor,
            drawer: _ReceptionDrawer(
              activeSection: _activeSection,
              user: widget.user,
              isLoggingOut: _isLoggingOut,
              onLogout: _logout,
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
            body: _ReceptionSessionScope(
              user: widget.user,
              child: _activeSection == 'home'
                  ? _HomeDashboardContent(
                      authService: widget.authService,
                      user: widget.user,
                      onOpenAppointments: _openAppointments,
                      onOpenLogbook: _openLogbook,
                    )
                  : switch (_activeSection) {
                      'departments' => _DepartmentsPage(
                        authService: widget.authService,
                        isAdmin: widget.user?.isAdmin ?? false,
                        user: widget.user,
                      ),
                      'hosts' => _HostsPage(
                        authService: widget.authService,
                        isAdmin: widget.user?.isAdmin ?? false,
                        user: widget.user,
                      ),
                      'accesses' => _AccessesPage(
                        authService: widget.authService,
                        isAdmin: widget.user?.isAdmin ?? false,
                        user: widget.user,
                      ),
                      'external_companies' => _withAuthService(
                        (authService, user) => ConnectedExternalCompaniesPage(
                          authService: authService,
                          isAdmin: user?.isAdmin ?? false,
                          canManage: _canManageExternalModules,
                          user: user,
                        ),
                      ),
                      'external_staff' => _withAuthService(
                        (authService, user) => ConnectedExternalStaffPage(
                          authService: authService,
                          isAdmin: user?.isAdmin ?? false,
                          canManage: _canManageExternalModules,
                          user: user,
                          appointment: _externalStaffAppointment,
                        ),
                      ),
                      'equipment' => _withAuthService(
                        (authService, user) => ConnectedEquipmentPage(
                          authService: authService,
                          isAdmin: user?.isAdmin ?? false,
                          canManage: _canManageExternalModules,
                          user: user,
                        ),
                      ),
                      'appointments' => _withAuthService(
                        (authService, user) => ConnectedAppointmentsPage(
                          authService: authService,
                          isAdmin: user?.isAdmin ?? false,
                          canManage: _canManageExternalModules,
                          onSendPass: _openExternalStaff,
                          user: user,
                        ),
                      ),
                      'logbook' => _withAuthService(
                        (authService, user) => ConnectedDailyLogbookPage(
                          authService: authService,
                          isAdmin: user?.isAdmin ?? false,
                          user: user,
                        ),
                      ),
                      'access_denied' => const Center(
                        child: Text(
                          'Tu cuenta no tiene secciones habilitadas.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      _ => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF101936),
                              Color(0xFF091329),
                              Color(0xFF050A16),
                            ],
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
                                    colors: [
                                      Color(0x300087FF),
                                      Colors.transparent,
                                    ],
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
                                    colors: [
                                      Color(0x2200D4FF),
                                      Colors.transparent,
                                    ],
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
                                  responsiveBottomScrollPadding(context),
                                ),
                                children: [
                                  _DashboardHeader(
                                    authService: widget.authService,
                                    user: widget.user,
                                  ),
                                  const SizedBox(height: 12),
                                  const Row(
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
                                  const SizedBox(height: 12),
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: _DashboardMetricCard(
                                          icon: Icons.grid_view_rounded,
                                          accent: Color(0xFFFF3155),
                                          title: 'Llegadas pendientes',
                                          value: '0',
                                          detail:
                                              'Citas sin ingreso completado',
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
                                  const SizedBox(height: 12),
                                  const _MovementHistoryCard(),
                                  const SizedBox(height: 12),
                                  const _CompositionCard(),
                                  const SizedBox(height: 12),
                                  const _TrendCard(),
                                  const SizedBox(height: 12),
                                  const _AgendaPanel(),
                                  const SizedBox(height: 12),
                                  const _BitacoraPanel(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    },
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceptionSessionScope extends InheritedWidget {
  const _ReceptionSessionScope({required this.user, required super.child});

  final AuthenticatedUser? user;

  static AuthenticatedUser? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ReceptionSessionScope>()
      ?.user;

  @override
  bool updateShouldNotify(_ReceptionSessionScope oldWidget) =>
      user != oldWidget.user;
}

bool _isLightDashboard(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color _dashboardPrimaryText(BuildContext context) =>
    _isLightDashboard(context) ? const Color(0xFF17243A) : Colors.white;

Color _dashboardSecondaryText(BuildContext context) =>
    _isLightDashboard(context)
    ? const Color(0xFF5C6B80)
    : const Color(0xFFAEB7CC);

BoxDecoration _dashboardPageDecoration(BuildContext context) =>
    _isLightDashboard(context)
    ? const BoxDecoration(color: Color(0xFFF3F7FC))
    : const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      );

Color _dashboardSurfaceColor(BuildContext context) =>
    _isLightDashboard(context) ? Colors.white : const Color(0xFF111D35);

class _DashboardThemeScope extends InheritedWidget {
  const _DashboardThemeScope({
    required this.isDarkMode,
    required this.onChanged,
    required super.child,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  static _DashboardThemeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DashboardThemeScope>();

  @override
  bool updateShouldNotify(_DashboardThemeScope oldWidget) =>
      isDarkMode != oldWidget.isDarkMode;
}

class _HomeDashboardContent extends StatefulWidget {
  const _HomeDashboardContent({
    required this.authService,
    required this.user,
    required this.onOpenAppointments,
    required this.onOpenLogbook,
  });

  final AuthService? authService;
  final AuthenticatedUser? user;
  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenLogbook;

  @override
  State<_HomeDashboardContent> createState() => _HomeDashboardContentState();
}

class _HomeDashboardContentState extends State<_HomeDashboardContent> {
  late final AuthService _authService =
      widget.authService ?? AuthService.shared;
  late Future<DashboardData> _dashboardFuture = _authService.getDashboardData(
    DateTime.now(),
  );

  void _reload() {
    setState(() {
      _dashboardFuture = _authService.getDashboardData(DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('dashboard-home-background'),
      decoration: BoxDecoration(
        color: _isLightDashboard(context) ? const Color(0xFFF3F7FC) : null,
        gradient: _isLightDashboard(context)
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF101936),
                  Color(0xFF091329),
                  Color(0xFF050A16),
                ],
                stops: [0, 0.48, 1],
              ),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            responsivePadding(context),
            10,
            responsivePadding(context),
            responsiveBottomScrollPadding(context),
          ),
          children: [
            _DashboardHeader(
              authService: widget.authService,
              user: widget.user,
            ),
            const SizedBox(height: 12),
            FutureBuilder<DashboardData>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  final error = snapshot.error;
                  final message = error is AuthApiException
                      ? error.message
                      : 'No se pudieron cargar los datos de Inicio.';
                  return _DashboardPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFFFFA9B6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _reload,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Intentar de nuevo'),
                        ),
                      ],
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const _DashboardPanel(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                return _HomeDashboardData(
                  data: snapshot.requireData,
                  onOpenAppointments: widget.onOpenAppointments,
                  onOpenLogbook: widget.onOpenLogbook,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboardData extends StatelessWidget {
  const _HomeDashboardData({
    required this.data,
    required this.onOpenAppointments,
    required this.onOpenLogbook,
  });

  final DashboardData data;
  final VoidCallback onOpenAppointments;
  final VoidCallback onOpenLogbook;

  @override
  Widget build(BuildContext context) {
    final equipmentDeclarations = data.appointments
        .where((appointment) => appointment.equipmentChecklistRequired)
        .length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DashboardMetricCard(
                icon: Icons.calendar_month_rounded,
                accent: const Color(0xFF00C8FF),
                title: 'Citas de hoy',
                value: '${data.appointments.length}',
                detail: 'Agenda programada',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardMetricCard(
                icon: Icons.person_rounded,
                accent: const Color(0xFF087FFF),
                title: 'Visitantes dentro',
                value: '${data.insideNow}',
                detail: 'Según la bitácora actual',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DashboardMetricCard(
                icon: Icons.grid_view_rounded,
                accent: const Color(0xFF00C8FF),
                title: 'Llegadas pendientes',
                value: '${data.pendingArrivals}',
                detail: 'Citas sin ingreso completado',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardMetricCard(
                icon: Icons.business_center_rounded,
                accent: const Color(0xFF087FFF),
                title: 'Declaraciones de equipo',
                value: '$equipmentDeclarations',
                detail: 'Citas de hoy con equipo declarado',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _CompositionCard(dailyActivity: data.dailyActivity),
        const SizedBox(height: 12),
        _TrendCard(dailyActivity: data.dailyActivity),
        const SizedBox(height: 12),
        _HomeAppointmentsPanel(
          appointments: data.appointments,
          onOpenAppointments: onOpenAppointments,
        ),
        const SizedBox(height: 12),
        _HomeLogbookPanel(
          entries: data.recentEntries,
          onOpenLogbook: onOpenLogbook,
        ),
      ],
    );
  }
}

class _HomeAppointmentsPanel extends StatelessWidget {
  const _HomeAppointmentsPanel({
    required this.appointments,
    required this.onOpenAppointments,
  });

  final List<DashboardAppointment> appointments;
  final VoidCallback onOpenAppointments;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    final todayAppointments = [...appointments]
      ..sort((a, b) => a.time.compareTo(b.time));
    return _DashboardPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF55B7FF),
                  size: 21,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Agenda de citas de hoy',
                    style: TextStyle(
                      color: _dashboardPrimaryText(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenAppointments,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF087FFF),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Abrir agenda'),
                ),
              ],
            ),
          ),
          if (todayAppointments.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
              child: Text(
                'No hay citas programadas para hoy.',
                style: TextStyle(
                  color: _dashboardSecondaryText(context),
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 780,
                child: Column(
                  children: [
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isLight ? const Color(0xFFE7F0FC) : null,
                        gradient: isLight
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF0D2A4A), Color(0xFF0A1D35)],
                              ),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: isLight
                                ? const Color(0xFFC9D8EA)
                                : const Color(0xFF164C7C),
                          ),
                        ),
                      ),
                      child: const Row(
                        children: [
                          _HomeAppointmentColumn(label: 'Hora', width: 68),
                          _HomeAppointmentColumn(
                            label: 'Visitante',
                            width: 156,
                          ),
                          _HomeAppointmentColumn(label: 'Empresa', width: 162),
                          _HomeAppointmentColumn(
                            label: 'Anfitrión',
                            width: 145,
                          ),
                          _HomeAppointmentColumn(label: 'Estado', width: 112),
                          _HomeAppointmentColumn(label: 'Acciones', width: 95),
                        ],
                      ),
                    ),
                    for (final appointment in todayAppointments.take(6))
                      Container(
                        constraints: const BoxConstraints(minHeight: 58),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0x222C75B2)),
                          ),
                        ),
                        child: Row(
                          children: [
                            _HomeAppointmentColumn(
                              label: appointment.time,
                              width: 68,
                              color: const Color(0xFF087FFF),
                              strong: true,
                            ),
                            _HomeAppointmentColumn(
                              label: appointment.visitor,
                              width: 156,
                              strong: true,
                            ),
                            _HomeAppointmentColumn(
                              label: appointment.company.isEmpty
                                  ? 'Público general'
                                  : appointment.company,
                              width: 162,
                            ),
                            _HomeAppointmentColumn(
                              label: appointment.host.isEmpty
                                  ? 'Sin anfitrión'
                                  : appointment.host,
                              width: 145,
                            ),
                            SizedBox(
                              width: 112,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _HomeAppointmentStatus(
                                  status: appointment.status,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 95,
                              child: TextButton.icon(
                                onPressed: onOpenAppointments,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF087FFF),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Abrir',
                                  style: TextStyle(fontSize: 11),
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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpenAppointments,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF75BFFF),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ver agenda completa'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeAppointmentColumn extends StatelessWidget {
  const _HomeAppointmentColumn({
    required this.label,
    required this.width,
    this.color,
    this.strong = false,
  });

  final String label;
  final double width;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? _dashboardPrimaryText(context),
          fontSize: 11,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _HomeAppointmentStatus extends StatelessWidget {
  const _HomeAppointmentStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Cancelada' => const Color(0xFFFF7189),
      'Dentro' || 'Retirado' => const Color(0xFF55D8B0),
      _ => const Color(0xFFFFC56E),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        border: Border.all(color: color.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HomeLogbookPanel extends StatelessWidget {
  const _HomeLogbookPanel({required this.entries, required this.onOpenLogbook});

  final List<DashboardLogEntry> entries;
  final VoidCallback onOpenLogbook;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    return _DashboardPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF55B7FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Registros del periodo',
                    style: TextStyle(
                      color: _dashboardPrimaryText(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenLogbook,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF9FCBFF),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text(
                    'Ver toda la bitácora  →',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isLight ? const Color(0xFFD8E2EF) : const Color(0x443B78AB),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: Text(
                'No hay movimientos en el periodo seleccionado.',
                style: TextStyle(
                  color: _dashboardSecondaryText(context),
                  fontSize: 12,
                ),
              ),
            )
          else
            ...entries
                .take(6)
                .map(
                  (entry) =>
                      _HomePeriodEntry(entry: entry, onTap: onOpenLogbook),
                ),
        ],
      ),
    );
  }
}

class _HomePeriodEntry extends StatelessWidget {
  const _HomePeriodEntry({required this.entry, required this.onTap});

  final DashboardLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    final (icon, accent) = switch (entry.event) {
      'Llegada' => (Icons.call_received_rounded, const Color(0xFF43D6AC)),
      'Ingreso' => (Icons.login_rounded, const Color(0xFF52AFFF)),
      'Retiro' => (Icons.logout_rounded, const Color(0xFFFF4968)),
      _ => (Icons.notes_rounded, const Color(0xFF9AAEC5)),
    };
    final company = entry.company.trim();
    final details = entry.details.trim();
    final date = DateTime.tryParse(entry.date);
    final dateLabel = date == null
        ? entry.date
        : '${date.day} ${_chartDateLabel(entry.date).split(' ').last}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: .1),
                border: Border.all(color: accent.withValues(alpha: .75)),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF65758B)
                            : const Color(0xFF8DA8C8),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.time,
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF52657D)
                            : const Color(0xFFB7C8DD),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.event,
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 5,
                    children: [
                      Text(
                        entry.person,
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF17243A)
                              : const Color(0xFFE7EEF9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (company.isNotEmpty) ...[
                        Text(
                          '•',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF65758B)
                                : const Color(0xFF8DA8C8),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          company,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF52657D)
                                : const Color(0xFFB7C8DD),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF65758B)
                            : const Color(0xFF8DA8C8),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF76B8F4),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomePanelHeader extends StatelessWidget {
  const _HomePanelHeader({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF087FFF), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Abrir $title',
          onPressed: onTap,
          icon: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF087FFF),
          ),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatefulWidget {
  const _DashboardHeader({this.authService, this.user});

  final AuthService? authService;
  final AuthenticatedUser? user;

  @override
  State<_DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<_DashboardHeader> {
  AuthenticatedUser? get _currentUser =>
      widget.user ?? _ReceptionSessionScope.maybeOf(context);

  void _toggleProfileMenu() {
    final user = _currentUser;
    final userName = user?.name?.trim();
    showReceptionThemeMenu(
      context: context,
      name: userName != null && userName.isNotEmpty
          ? userName
          : user?.login ?? 'Cuenta',
      role: user?.role?.trim().isNotEmpty == true
          ? user!.role!.trim()
          : user?.isAdmin == true
          ? 'Administrador'
          : 'Recepción',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final userName = user?.name?.trim();
    final displayName = userName != null && userName.isNotEmpty
        ? userName
        : user?.login ?? 'Cuenta';
    final displayRole = user?.role?.trim().isNotEmpty == true
        ? user!.role!.trim()
        : user?.isAdmin == true
        ? 'Administrador'
        : 'Recepción';
    return ReceptionHeaderBar(
      name: displayName,
      role: displayRole,
      onMenuTap: () => Scaffold.of(context).openDrawer(),
      onProfileTap: _toggleProfileMenu,
    );
  }
}

class _ProfileMenuOverlay extends StatefulWidget {
  const _ProfileMenuOverlay({
    required this.top,
    required this.onClose,
    required this.authService,
    required this.user,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  final double top;
  final VoidCallback onClose;
  final AuthService authService;
  final AuthenticatedUser? user;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<_ProfileMenuOverlay> createState() => _ProfileMenuOverlayState();
}

class _ProfileMenuOverlayState extends State<_ProfileMenuOverlay> {
  late bool _darkMode = widget.isDarkMode;
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await widget.authService.logout();
      if (!mounted) return;
      widget.onClose();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReceptionLoginPage(authService: widget.authService),
        ),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      AppFeedback.show(context, error.message, type: AppFeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user?.name?.trim();
    final displayName = userName != null && userName.isNotEmpty
        ? userName
        : widget.user?.login ?? 'Cuenta';
    final displayRole = widget.user?.role?.trim().isNotEmpty == true
        ? widget.user!.role!.trim()
        : widget.user?.isAdmin == true
        ? 'Administrador'
        : 'Recepción';
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _darkMode
                      ? const [Color(0xFF172442), Color(0xFF090F20)]
                      : const [Color(0xFFFFFFFF), Color(0xFFEAF3FF)],
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
                    child: Row(
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
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _darkMode
                                      ? Colors.white
                                      : const Color(0xFF17243A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                displayRole,
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
                        Expanded(
                          child: Text(
                            'Modo oscuro',
                            style: TextStyle(
                              color: _darkMode
                                  ? const Color(0xFFDDE6F5)
                                  : const Color(0xFF33435C),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Switch.adaptive(
                          key: const ValueKey('dashboard-theme-switch'),
                          value: _darkMode,
                          activeTrackColor: const Color(0xFF087FFF),
                          activeThumbColor: Colors.white,
                          onChanged: (value) {
                            setState(() => _darkMode = value);
                            widget.onThemeChanged(value);
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
                      onPressed: _isLoggingOut ? null : _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5A72),
                        side: const BorderSide(color: Color(0x99FF3155)),
                        backgroundColor: const Color(0x18FF3155),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        _isLoggingOut ? 'Cerrando sesión...' : 'Cerrar sesión',
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
    final isLight = _isLightDashboard(context);
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? const [Color(0xFFFFFFFF), Color(0xFFF1F6FD), Color(0xFFEAF2FC)]
              : const [Color(0xFF1B2748), Color(0xFF141A31), Color(0xFF0E1427)],
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
                  isLight ? Colors.white : const Color(0xFF10172B),
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
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF53647D)
                        : const Color(0xFFDCE2F0),
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: isLight ? const Color(0xFF17243A) : Colors.white,
                    fontSize: 23,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF65758B)
                        : const Color(0xFFA9B4CB),
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
    final isLight = _isLightDashboard(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B2949),
                  Color(0xFF12192F),
                  Color(0xFF0D1325),
                ],
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
    final isLight = _isLightDashboard(context);
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
        style: TextStyle(
          color: active || !isLight ? Colors.white : const Color(0xFF53647D),
          fontSize: 8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _chartDateLabel(String date) {
  final value = DateTime.parse(date);
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${value.day} ${months[value.month - 1]}';
}

class _CompositionCard extends StatelessWidget {
  const _CompositionCard({this.dailyActivity = const []});

  final List<DashboardDailyActivity> dailyActivity;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    final arrivals = dailyActivity.fold(0, (sum, day) => sum + day.arrivals);
    final entries = dailyActivity.fold(0, (sum, day) => sum + day.entries);
    final exits = dailyActivity.fold(0, (sum, day) => sum + day.exits);
    final observations = dailyActivity.fold(
      0,
      (sum, day) => sum + day.observations,
    );
    final total = arrivals + entries + exits + observations;
    final range = dailyActivity.isEmpty
        ? 'Sin datos'
        : '${_chartDateLabel(dailyActivity.first.date)} – '
              '${_chartDateLabel(dailyActivity.last.date)}';
    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Composición de movimientos',
            style: TextStyle(
              color: _dashboardPrimaryText(context),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Últimos 7 días · $range',
            style: TextStyle(
              color: _dashboardSecondaryText(context),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 112,
                child: CustomPaint(
                  painter: _DonutPainter(
                    values: [arrivals, entries, exits, observations],
                    isLight: isLight,
                  ),
                  child: Center(
                    child: Text(
                      '$total\nmovimientos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _dashboardPrimaryText(context),
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
                  children: [
                    _LegendRow(
                      color: const Color(0xFFFF3155),
                      label: 'Llegadas',
                      value: '$arrivals',
                    ),
                    _LegendRow(
                      color: const Color(0xFF087FFF),
                      label: 'Entradas',
                      value: '$entries',
                    ),
                    _LegendRow(
                      color: const Color(0xFF28C9E8),
                      label: 'Salidas',
                      value: '$exits',
                    ),
                    _LegendRow(
                      color: const Color(0xFFAEB7CC),
                      label: 'Observaciones',
                      value: '$observations',
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            'Conteo real de los registros de la bitácora',
            style: TextStyle(
              color: _dashboardSecondaryText(context),
              fontSize: 10,
            ),
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
    final textColor = _dashboardPrimaryText(context);
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
              style: TextStyle(color: textColor, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
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
  const _TrendCard({this.dailyActivity = const []});

  final List<DashboardDailyActivity> dailyActivity;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    final total = dailyActivity.fold(
      0,
      (sum, day) =>
          sum + day.arrivals + day.entries + day.exits + day.observations,
    );
    final range = dailyActivity.isEmpty
        ? 'Sin datos'
        : '${_chartDateLabel(dailyActivity.first.date)} – '
              '${_chartDateLabel(dailyActivity.last.date)}';
    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tendencia diaria',
                  style: TextStyle(
                    color: _dashboardPrimaryText(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$total total',
                style: TextStyle(
                  color: _dashboardPrimaryText(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            'Volumen diario · últimos 7 días · $range',
            style: TextStyle(
              color: _dashboardSecondaryText(context),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
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
              color: isLight
                  ? const Color(0xFFF3F7FC)
                  : const Color(0xFF0A1020).withValues(alpha: .72),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF087FFF).withValues(alpha: .12),
              ),
            ),
            child: CustomPaint(
              painter: _LineChartPainter(
                dailyActivity: dailyActivity,
                isLight: isLight,
              ),
              size: const Size(double.infinity, 178),
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
  const _DonutPainter({required this.values, this.isLight = false});

  final List<int> values;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .39;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const colors = [
      Color(0xFFFF3155),
      Color(0xFF087FFF),
      Color(0xFF28C9E8),
      Color(0xFFAEB7CC),
    ];
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final stroke = Paint()
      ..color = isLight ? const Color(0xFFDCE5F0) : const Color(0xFF2B3350)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawArc(rect, 0, math.pi * 2, false, stroke);
    if (total == 0) return;
    var start = -90.0;
    for (var index = 0; index < values.length; index++) {
      if (values[index] == 0) continue;
      final sweep = values[index] / total * 360;
      canvas.drawArc(
        rect,
        start * 3.1415926535 / 180,
        sweep * 3.1415926535 / 180,
        false,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.butt,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.isLight != isLight;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.dailyActivity, this.isLight = false});

  final List<DashboardDailyActivity> dailyActivity;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    if (dailyActivity.isEmpty || size.width <= 0 || size.height <= 0) return;
    final left = 31.0;
    final top = 12.0;
    final bottom = size.height - 28;
    final right = size.width - 12;
    final plotWidth = right - left;
    final plotHeight = bottom - top;
    final maxValue = dailyActivity.fold<int>(1, (maximum, day) {
      final dayMaximum = [
        day.arrivals,
        day.entries,
        day.exits,
      ].reduce((first, second) => first > second ? first : second);
      return dayMaximum > maximum ? dayMaximum : maximum;
    });
    final gridPaint = Paint()
      ..color = (isLight ? const Color(0xFFD8E2EF) : const Color(0xFF2A365B))
          .withValues(alpha: .72)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = bottom - plotHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(right, y), gridPaint);
      final value = (maxValue * i / 3).round();
      final valuePainter = TextPainter(
        text: TextSpan(
          text: '$value',
          style: TextStyle(
            color: isLight ? const Color(0xFF65758B) : const Color(0xFFAEB7CC),
            fontSize: 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valuePainter.paint(canvas, Offset(7, y - valuePainter.height / 2));
    }
    void drawSeries(List<int> values, Color color) {
      final points = <Offset>[];
      for (var i = 0; i < values.length; i++) {
        final x = values.length < 2
            ? left + plotWidth / 2
            : left + plotWidth * i / (values.length - 1);
        final y = bottom - values[i] / maxValue * plotHeight;
        points.add(Offset(x, y));
      }
      if (points.length == 1) {
        canvas.drawCircle(points.first, 2.2, Paint()..color = color);
        return;
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
        canvas.drawCircle(
          point,
          3.2,
          Paint()..color = isLight ? Colors.white : const Color(0xFF07101F),
        );
        canvas.drawCircle(point, 2.2, Paint()..color = color);
      }
    }

    drawSeries(
      dailyActivity.map((day) => day.arrivals).toList(),
      const Color(0xFF087FFF),
    );
    drawSeries(
      dailyActivity.map((day) => day.entries).toList(),
      const Color(0xFF28C9E8),
    );
    drawSeries(
      dailyActivity.map((day) => day.exits).toList(),
      const Color(0xFFFF3155),
    );
    final labelStyle = TextStyle(
      color: isLight ? const Color(0xFF65758B) : const Color(0xFFAEB7CC),
      fontSize: 9,
    );
    final labelIndices = <int>{
      0,
      dailyActivity.length ~/ 2,
      dailyActivity.length - 1,
    };
    for (final index in labelIndices) {
      final x = dailyActivity.length < 2
          ? left + plotWidth / 2
          : left + plotWidth * index / (dailyActivity.length - 1);
      final tp = TextPainter(
        text: TextSpan(
          text: _chartDateLabel(dailyActivity[index].date),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      final labelX = index == 0
          ? left
          : index == dailyActivity.length - 1
          ? right - tp.width
          : x - tp.width / 2;
      tp.paint(canvas, Offset(labelX, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.dailyActivity != dailyActivity ||
      oldDelegate.isLight != isLight;
}

class _AccessesPage extends StatefulWidget {
  const _AccessesPage({
    required this.authService,
    required this.isAdmin,
    this.user,
  });

  final AuthService? authService;
  final bool isAdmin;
  final AuthenticatedUser? user;

  @override
  State<_AccessesPage> createState() => _AccessesPageState();
}

class _AccessesPageState extends State<_AccessesPage> {
  final _searchController = TextEditingController();
  late final AuthService _authService =
      widget.authService ?? AuthService.shared;
  List<AccessAccount> _accounts = const [];
  String _query = '';
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isAdmin) {
      unawaited(_loadAccounts());
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final accounts = await _authService.getAccessAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isLoading = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudieron cargar las cuentas. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }

  Future<void> _editAccess(AccessAccount account) async {
    final sections = await showDialog<List<String>>(
      context: context,
      builder: (_) => _AccessEditDialog(account: account),
    );
    if (sections == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final accounts = await _authService.updateAccess(account.login, sections);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _isSaving = false;
      });
      AppFeedback.show(
        context,
        'Permisos actualizados correctamente.',
        type: AppFeedbackType.success,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo guardar el acceso. Inténtalo de nuevo.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = _accounts.where((account) {
      final value =
          '${account.login} ${account.name ?? ''} ${account.role ?? ''} '
                  '${account.email ?? ''} ${account.phone ?? ''} '
                  '${account.accessLabel}'
              .toLowerCase();
      return value.contains(_query.toLowerCase());
    }).toList();

    return Container(
      key: const ValueKey('access-section-root'),
      decoration: _dashboardPageDecoration(context),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(user: widget.user),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Accesos',
                      style: TextStyle(
                        color: _dashboardPrimaryText(context),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Administra quién puede ingresar al sistema',
                      style: TextStyle(
                        color: _dashboardSecondaryText(context),
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
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isLightDashboard(context) ? Colors.white : null,
                        gradient: _isLightDashboard(context)
                            ? null
                            : const LinearGradient(
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
                      style: TextStyle(
                        color: _dashboardPrimaryText(context),
                        fontSize: 13,
                      ),
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
                        fillColor: _dashboardSurfaceColor(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0x330087FF),
                          ),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      _AccessMessageCard(
                        message: _errorMessage!,
                        isError: true,
                        onRetry: _loadAccounts,
                      ),
                    ],
                    if (_isSaving) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(
                        color: Color(0xFF087FFF),
                        backgroundColor: Color(0xFF17243D),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                responsiveBottomScrollPadding(context),
              ),
              sliver: _isLoading
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF087FFF),
                          ),
                        ),
                      ),
                    )
                  : _errorMessage != null
                  ? const SliverToBoxAdapter(child: SizedBox.shrink())
                  : !widget.isAdmin
                  ? const SliverToBoxAdapter(
                      child: _AccessMessageCard(
                        message: 'Inicia sesión con una cuenta administradora para consultar y modificar accesos.',
                      ),
                    )
                  : _accounts.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _AccessMessageCard(
                        message: 'No hay cuentas registradas para mostrar.',
                      ),
                    )
                  : filteredAccounts.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _AccessMessageCard(
                        message:
                            'No hay cuentas que coincidan con la búsqueda.',
                      ),
                    )
                  : SliverList.separated(
                      itemCount: filteredAccounts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final account = filteredAccounts[index];
                        return _AccessAccountCard(
                          account: account,
                          isAdmin: widget.isAdmin,
                          isSaving: _isSaving,
                          onEdit: () => _editAccess(account),
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

class _AccessAccountCard extends StatelessWidget {
  const _AccessAccountCard({
    required this.account,
    required this.isAdmin,
    required this.isSaving,
    required this.onEdit,
  });

  final AccessAccount account;
  final bool isAdmin;
  final bool isSaving;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    return Container(
      key: ValueKey('access-account-card-${account.login}'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14243D), Color(0xFF0B1528)],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x553D9DFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F087FFF),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF24BDF5), Color(0xFF087FFF)],
                  ),
                  border: Border.all(
                    color: const Color(0xFF9ADFFF),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x440087FF),
                      blurRadius: 14,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.login,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _dashboardPrimaryText(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF087FFF)
                            : const Color(0xFF67ACFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: account.isActive
                        ? const [Color(0xFF153D35), Color(0xFF1D574A)]
                        : const [Color(0xFF3A2430), Color(0xFF572738)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: account.isActive
                        ? const Color(0x554AE3B5)
                        : const Color(0x55FF7D9B),
                  ),
                ),
                child: Text(
                  account.isActive ? 'Activa' : 'Inactiva',
                  style: TextStyle(
                    color: account.isActive
                        ? const Color(0xFF4AE3B5)
                        : const Color(0xFFFF7D9B),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 5),
            decoration: BoxDecoration(
              color: isLight
                  ? const Color(0xFFF2F7FD)
                  : const Color(0x241C75C5),
              gradient: isLight
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x241C75C5), Color(0x160D315A)],
                    ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x332D83D1)),
            ),
            child: Column(
              children: [
                _AccessDetail(
                  Icons.work_outline_rounded,
                  'Puesto',
                  account.role ?? '—',
                ),
                _AccessDetail(
                  Icons.mail_outline_rounded,
                  'Correo',
                  account.email ?? '—',
                ),
                _AccessDetail(
                  Icons.phone_rounded,
                  'Teléfono',
                  account.phone ?? '—',
                ),
                _AccessDetail(
                  Icons.admin_panel_settings_outlined,
                  'Acceso',
                  account.accessLabel,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isAdmin)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF087FFF),
                      Color(0xFF168EFF),
                      Color(0xFF04BCEB),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x550087FF),
                      blurRadius: 13,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 18),
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
    final isLight = _isLightDashboard(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 23,
            child: Icon(icon, size: 16, color: const Color(0xFF28A0FF)),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 57,
            child: Text(
              label,
              style: TextStyle(
                color: isLight
                    ? const Color(0xFF65758B)
                    : const Color(0xFF91A4C1),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _dashboardPrimaryText(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessMessageCard extends StatelessWidget {
  const _AccessMessageCard({
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? const Color(0x331A0D1A) : const Color(0xFF111D35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError ? const Color(0x99FF5A72) : const Color(0x440087FF),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD7E3F7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccessEditDialog extends StatefulWidget {
  const _AccessEditDialog({required this.account});

  final AccessAccount account;

  @override
  State<_AccessEditDialog> createState() => _AccessEditDialogState();
}

class _AccessEditDialogState extends State<_AccessEditDialog> {
  late String _selectedAccess =
      widget.account.sectionAccess.contains('administrador')
      ? 'administrador'
      : widget.account.sectionAccess.contains('recepcion')
      ? 'recepcion'
      : 'none';

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _dashboardSurfaceColor(context),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isLight ? const Color(0xFFD8E4F2) : const Color(0x554AA8FF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.35),
              blurRadius: 28,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF087FFF), Color(0xFF18B7D8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PERMISOS DE CUENTA',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF167C92)
                              : const Color(0xFF73CDE0),
                          fontSize: 9,
                          letterSpacing: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Editar acceso',
                        style: TextStyle(
                          color: _dashboardPrimaryText(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: _dashboardSecondaryText(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFEFF6FD)
                    : const Color(0xFF0A1426),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isLight
                      ? const Color(0xFFD7E5F4)
                      : const Color(0x333D9DFF),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    color: isLight
                        ? const Color(0xFF1769AA)
                        : const Color(0xFF67ACFF),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUENTA',
                          style: TextStyle(
                            color: _dashboardSecondaryText(context),
                            fontSize: 9,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.account.login,
                          style: TextStyle(
                            color: _dashboardPrimaryText(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Selecciona el alcance de acceso para esta cuenta.',
              style: TextStyle(
                color: _dashboardSecondaryText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            RadioGroup<String>(
              groupValue: _selectedAccess,
              onChanged: (selected) {
                if (selected != null) {
                  setState(() => _selectedAccess = selected);
                }
              },
              child: Column(
                children: [
                  _accessOption(
                    'administrador',
                    'Administrador',
                    'Acceso completo a la administración.',
                    Icons.admin_panel_settings_rounded,
                    const Color(0xFF168BFF),
                  ),
                  _accessOption(
                    'recepcion',
                    'Recepción',
                    'Agenda de citas y bitácora diaria.',
                    Icons.door_front_door_rounded,
                    const Color(0xFF18A6A1),
                  ),
                  _accessOption(
                    'none',
                    'Sin acceso',
                    'La cuenta no podrá entrar al sistema.',
                    Icons.block_rounded,
                    const Color(0xFFE05A70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _dashboardPrimaryText(context),
                      side: BorderSide(
                        color: isLight
                            ? const Color(0xFFC9D6E6)
                            : const Color(0x557F94B3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(
                      _selectedAccess == 'none'
                          ? <String>[]
                          : <String>[_selectedAccess],
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF087FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text(
                      'Guardar acceso',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _accessOption(
    String value,
    String label,
    String description,
    IconData icon,
    Color accent,
  ) {
    final isSelected = _selectedAccess == value;
    final isLight = _isLightDashboard(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? accent.withValues(alpha: isLight ? 0.09 : 0.14)
            : isLight
            ? const Color(0xFFF7F9FC)
            : const Color(0xFF0B1628),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: () => setState(() => _selectedAccess = value),
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected
                    ? accent.withValues(alpha: 0.56)
                    : isLight
                    ? const Color(0xFFE2E8F0)
                    : const Color(0x223D9DFF),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: _dashboardPrimaryText(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: _dashboardSecondaryText(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Radio<String>(value: value, activeColor: accent),
              ],
            ),
          ),
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
            SliverToBoxAdapter(
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
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                responsiveBottomScrollPadding(context),
              ),
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
            SliverToBoxAdapter(
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
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                responsiveBottomScrollPadding(context),
              ),
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
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                responsiveBottomScrollPadding(context),
              ),
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
                        onCancel: () => AppFeedback.show(
                          context,
                          'Cita cancelada',
                          type: AppFeedbackType.success,
                        ),
                        onDelete: () => AppFeedback.show(
                          context,
                          'Solicitud de eliminación enviada',
                          type: AppFeedbackType.warning,
                        ),
                        onSendQr: () => AppFeedback.show(
                          context,
                          'Código QR enviado al visitante',
                          type: AppFeedbackType.success,
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
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  responsiveBottomScrollPadding(context),
                ),
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
      AppFeedback.show(
        context,
        'QR descargado en la galería',
        type: AppFeedbackType.success,
      );
    } catch (_) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        'No fue posible guardar el código QR',
        type: AppFeedbackType.error,
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
  int _periodPage = 0;
  int _activityPage = 0;
  static const _pageSize = 5;

  static const _periodMovements = [
    _LogbookMovement(
      name: 'Abner Alejandro Soto',
      time: '09:04',
      date: '3 nov',
      type: 'Entrada',
      folio: '99928727',
      company: 'Público general',
      detail: 'Dentro',
      color: Color(0xFF087FFF),
      icon: Icons.login_rounded,
    ),
    _LogbookMovement(
      name: 'Rafael Gonzales Castañeda',
      time: '08:57',
      date: '3 nov',
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
      date: '3 nov',
      type: 'Entrada',
      folio: '94174021',
      company: 'Soluciones Industriales del Norte',
      detail: 'Anfitrión: Administrador de prueba',
      color: Color(0xFF087FFF),
      icon: Icons.login_rounded,
    ),
    _LogbookMovement(
      name: 'Jesus Efren Hinojosa Guerra',
      time: '18:58',
      date: '2 nov',
      type: 'Salida',
      folio: '41720855',
      company: 'Soluciones Industriales del Norte',
      detail: 'Salida registrada correctamente',
      color: Color(0xFFE53E4B),
      icon: Icons.logout_rounded,
    ),
  ];

  static const _recentActivity = [
    _LogbookMovement(
      name: 'Abner Alejandro Soto',
      time: '09:04',
      date: '3 nov',
      type: 'Entrada',
      folio: '99928727',
      company: 'Público general',
      detail: 'Ingreso autorizado sin equipo ni herramientas',
      color: Color(0xFF087FFF),
      icon: Icons.login_rounded,
    ),
    _LogbookMovement(
      name: 'Abner Alejandro Soto',
      time: '08:57',
      date: '3 nov',
      type: 'Llegada',
      folio: '99928727',
      company: 'Público general',
      detail: 'Pendiente de autorización · Motivo: Entrevista',
      color: Color(0xFF26E2A7),
      icon: Icons.call_received_rounded,
    ),
    _LogbookMovement(
      name: 'Rafael Gonzales Castañeda',
      time: '08:57',
      date: '3 nov',
      type: 'Llegada',
      folio: '53597403',
      company: 'Público general',
      detail: 'Pendiente de autorización · Motivo: Entrevista',
      color: Color(0xFF26E2A7),
      icon: Icons.call_received_rounded,
    ),
    _LogbookMovement(
      name: 'Pedro Hernandez',
      time: '08:12',
      date: '3 nov',
      type: 'Entrada',
      folio: '94174021',
      company: 'Soluciones Industriales del Norte',
      detail: 'Anfitrión: Administrador de prueba',
      color: Color(0xFF087FFF),
      icon: Icons.login_rounded,
    ),
    _LogbookMovement(
      name: 'Pedro Hernandez',
      time: '08:01',
      date: '3 nov',
      type: 'Llegada',
      folio: '94174021',
      company: 'Soluciones Industriales del Norte',
      detail: 'Pendiente de autorización',
      color: Color(0xFF26E2A7),
      icon: Icons.call_received_rounded,
    ),
    _LogbookMovement(
      name: 'Jesus Efren Hinojosa Guerra',
      time: '18:58',
      date: '2 nov',
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
    final normalized = _query.trim().toLowerCase();
    bool matches(_LogbookMovement movement) {
      final matchesFilter = _filter == 'Todos' || movement.type == _filter;
      final matchesQuery =
          normalized.isEmpty ||
          movement.name.toLowerCase().contains(normalized) ||
          movement.company.toLowerCase().contains(normalized) ||
          movement.folio.contains(normalized);
      return matchesFilter && matchesQuery;
    }

    final periodItems = _periodMovements.where(matches).toList();
    final activityItems = _recentActivity.where(matches).toList();
    final periodPages = math
        .max(1, (periodItems.length / _pageSize).ceil())
        .toInt();
    final activityPages = math
        .max(1, (activityItems.length / _pageSize).ceil())
        .toInt();
    final periodPage = _periodPage.clamp(0, periodPages - 1).toInt();
    final activityPage = _activityPage.clamp(0, activityPages - 1).toInt();
    final visiblePeriodItems = periodItems
        .skip(periodPage * _pageSize)
        .take(_pageSize)
        .toList();
    final visibleActivityItems = activityItems
        .skip(activityPage * _pageSize)
        .take(_pageSize)
        .toList();

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
                        onChanged: (value) => setState(() {
                          _query = value;
                          _periodPage = 0;
                          _activityPage = 0;
                        }),
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
                      Row(
                        children: [
                          Expanded(
                            child: _LogbookActionButton(
                              label: 'Nuevo registro',
                              icon: Icons.login_rounded,
                              onTap: () => _openRegister(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
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
                      'Entrada',
                      'Salida',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() {
                            _filter = filter;
                            _periodPage = 0;
                            _activityPage = 0;
                          }),
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
            SliverToBoxAdapter(
              child: _LogbookSection(
                title: 'Movimientos del periodo',
                subtitle: 'Un registro por visitante · Estado actual',
                icon: Icons.fact_check_rounded,
                count: periodItems.length,
                children: [
                  if (visiblePeriodItems.isEmpty)
                    const _LogbookEmptyState(
                      message:
                          'No hay movimientos que coincidan con la búsqueda.',
                    )
                  else
                    for (final movement in visiblePeriodItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _LogbookMovementCard(
                          movement: movement,
                          onTap: () => _openMovement(movement),
                        ),
                      ),
                  _LogbookPagination(
                    itemCount: periodItems.length,
                    page: periodPage,
                    pageCount: periodPages,
                    pageSize: _pageSize,
                    onPageChanged: (page) => setState(() => _periodPage = page),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _LogbookSection(
                title: 'Actividad reciente',
                subtitle: 'Cada llegada, entrada y salida con su hora',
                icon: Icons.bolt_rounded,
                count: activityItems.length,
                children: [
                  if (visibleActivityItems.isEmpty)
                    const _LogbookEmptyState(
                      message: 'No hay actividad que coincida con la búsqueda.',
                    )
                  else
                    for (final movement in visibleActivityItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentActivityCard(
                          movement: movement,
                          onTap: () => _openMovement(movement),
                        ),
                      ),
                  _LogbookPagination(
                    itemCount: activityItems.length,
                    page: activityPage,
                    pageCount: activityPages,
                    pageSize: _pageSize,
                    onPageChanged: (page) =>
                        setState(() => _activityPage = page),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).shortestSide < 600 ? 72 : 32,
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

class _LogbookSection extends StatelessWidget {
  const _LogbookSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.count,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE610172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x99087FFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF63B8FF), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9FB2CD),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x1A087FFF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x665DAEFF)),
                ),
                child: Text(
                  '$count ${count == 1 ? 'registro' : 'registros'}',
                  style: const TextStyle(
                    color: Color(0xFFB7D9FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0x332D78C4)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _LogbookEmptyState extends StatelessWidget {
  const _LogbookEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF9FB2CD), fontSize: 12),
        ),
      ),
    );
  }
}

class _LogbookPagination extends StatelessWidget {
  const _LogbookPagination({
    required this.itemCount,
    required this.page,
    required this.pageCount,
    required this.pageSize,
    required this.onPageChanged,
  });

  final int itemCount;
  final int page;
  final int pageCount;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final firstItem = itemCount == 0 ? 0 : page * pageSize + 1;
    final lastItem = math.min(itemCount, (page + 1) * pageSize);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Mostrando $firstItem–$lastItem de $itemCount registros',
            style: const TextStyle(color: Color(0xFF91A2BD), fontSize: 10),
          ),
        ),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded),
          color: const Color(0xFF9FB2CD),
        ),
        Text(
          'Página ${page + 1} de $pageCount',
          style: const TextStyle(color: Color(0xFFB7C7DF), fontSize: 10),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: page + 1 < pageCount
              ? () => onPageChanged(page + 1)
              : null,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded),
          color: const Color(0xFF9FB2CD),
        ),
      ],
    );
  }
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

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.movement, required this.onTap});

  final _LogbookMovement movement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1930),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x332D78C4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: movement.color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: movement.color.withValues(alpha: .46),
                  ),
                ),
                child: Icon(movement.icon, color: movement.color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: movement.color.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            movement.type,
                            style: TextStyle(
                              color: movement.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          movement.time,
                          style: const TextStyle(
                            color: Color(0xFFB7C7DF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${movement.name} · ${movement.company}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD8E1EF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Color(0xFF2479C8), width: 2),
                        ),
                      ),
                      child: Text(
                        'Folio ${movement.folio} · ${movement.detail}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF91ACCD),
                          fontSize: 10,
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
      key: const ValueKey('equipment-section-root'),
      decoration: _dashboardPageDecoration(context),
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
              padding: EdgeInsets.fromLTRB(
                14,
                0,
                14,
                responsiveBottomScrollPadding(context),
              ),
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

class _HostsPage extends StatefulWidget {
  const _HostsPage({this.authService, required this.isAdmin, this.user});

  final AuthService? authService;
  final bool isAdmin;
  final AuthenticatedUser? user;

  @override
  State<_HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends State<_HostsPage> {
  final _searchController = TextEditingController();
  late final AuthService _authService =
      widget.authService ?? AuthService.shared;
  List<DepartmentHost> _hosts = const [];
  List<Department> _departments = const [];
  String _query = '';
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;

  List<DepartmentHost> get _filteredHosts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _hosts;
    return _hosts.where((host) {
      final department = _departmentName(host.departmentId);
      return [
        host.login,
        host.name,
        host.email,
        host.role,
        host.phone,
        department,
      ].any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  String _departmentName(int id) {
    for (final department in _departments) {
      if (department.id == id) return department.name;
    }
    return 'Departamento no disponible';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadHosts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _authService.getDepartmentHosts(),
        _authService.getDepartments(),
      ]);
      if (!mounted) return;
      setState(() {
        _hosts = results[0] as List<DepartmentHost>;
        _departments = results[1] as List<Department>;
        _isLoading = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudieron cargar los anfitriones. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }

  Future<void> _editHostDepartment(DepartmentHost host) async {
    if (!widget.isAdmin || _isSaving || _departments.isEmpty) return;
    final departmentId = await showDialog<int>(
      context: context,
      builder: (context) => _HostDepartmentDialog(
        departments: _departments,
        selectedDepartmentId: host.departmentId,
      ),
    );
    if (departmentId == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final hosts = await _authService.updateDepartmentHostDepartment(
        id: host.id,
        departmentId: departmentId,
      );
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _isSaving = false;
      });
      AppFeedback.show(
        context,
        'Departamento actualizado.',
        type: AppFeedbackType.success,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo actualizar el departamento.';
        _isSaving = false;
      });
    }
  }

  Future<void> _registerHost() async {
    if (!widget.isAdmin || _isSaving) return;
    if (_departments.isEmpty) {
      AppFeedback.show(
        context,
        'Registra primero un departamento para asignar al anfitrión.',
        type: AppFeedbackType.error,
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final allAccounts = await _authService.getHostAccounts();
      if (!mounted) return;
      final registeredLogins = _hosts
          .map((host) => host.login.toLowerCase())
          .toSet();
      final accounts = allAccounts
          .where(
            (account) =>
                !registeredLogins.contains(account.login.toLowerCase()),
          )
          .toList();
      setState(() => _isSaving = false);
      final draft = await showDialog<_DepartmentHostDraft>(
        context: context,
        builder: (context) =>
            _HostFormDialog(departments: _departments, accounts: accounts),
      );
      if (draft == null || !mounted) return;

      setState(() {
        _isSaving = true;
        _errorMessage = null;
      });
      final hosts = await _authService.createDepartmentHost(
        login: draft.login,
        name: draft.name,
        departmentId: draft.departmentId,
        role: draft.role,
        email: draft.email,
        phone: draft.phone,
      );
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _isSaving = false;
      });
      AppFeedback.show(
        context,
        draft.fromAccessAccount
            ? 'Anfitrión registrado y acceso a Anfitriones habilitado.'
            : 'Anfitrión registrado.',
        type: AppFeedbackType.success,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo registrar el anfitrión.';
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteHost(DepartmentHost host) async {
    if (!widget.isAdmin || _isSaving) return;
    final confirmed = await showReceptionConfirmDialog(
      context: context,
      title: 'Eliminar anfitrión',
      message: '¿Quieres eliminar a "${host.name}" de la lista de anfitriones?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final hosts = await _authService.deleteDepartmentHost(host.id);
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _isSaving = false;
      });
      AppFeedback.show(
        context,
        'Anfitrión eliminado.',
        type: AppFeedbackType.success,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudo eliminar el anfitrión.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hosts = _filteredHosts;
    return Container(
      key: const ValueKey('hosts-section-root'),
      decoration: _dashboardPageDecoration(context),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(user: widget.user),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anfitriones',
                      style: TextStyle(
                        color: _dashboardPrimaryText(context),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Registro de anfitriones de la organización',
                      style: TextStyle(
                        color: _dashboardSecondaryText(context),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isLightDashboard(context) ? Colors.white : null,
                    gradient: _isLightDashboard(context)
                        ? null
                        : const LinearGradient(
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
                          Expanded(
                            child: Text(
                              'Anfitriones',
                              style: TextStyle(
                                color: _dashboardPrimaryText(context),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '${hosts.length} ${hosts.length == 1 ? 'cuenta' : 'cuentas'}',
                            style: const TextStyle(
                              color: Color(0xFF63C5FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Actualizar anfitriones',
                            onPressed: _isLoading ? null : _loadHosts,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Color(0xFF8FBFFF),
                            ),
                          ),
                        ],
                      ),
                      if (widget.isAdmin) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            key: const ValueKey('register-host-button'),
                            onPressed: _isSaving ? null : _registerHost,
                            style: FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color(0xFF087FFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text(
                              'Registrar anfitrión',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar anfitrión o departamento...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF73809A),
                            fontSize: 11,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF087FFF),
                          ),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    color: Color(0xFF9BAAC2),
                                  ),
                                ),
                          filled: true,
                          fillColor: _dashboardSurfaceColor(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFF087FFF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                14,
                12,
                14,
                responsiveBottomScrollPadding(context),
              ),
              sliver: _isLoading
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF087FFF),
                          ),
                        ),
                      ),
                    )
                  : _errorMessage != null
                  ? SliverToBoxAdapter(
                      child: _HostMessageCard(
                        message: _errorMessage!,
                        isError: true,
                        onRetry: _loadHosts,
                      ),
                    )
                  : hosts.isEmpty
                  ? SliverToBoxAdapter(
                      child: _HostMessageCard(
                        message: _query.isEmpty
                            ? 'Todavía no hay anfitriones registrados.'
                            : 'No hay anfitriones que coincidan con la búsqueda.',
                      ),
                    )
                  : SliverList.builder(
                      itemCount: hosts.length,
                      itemBuilder: (context, index) {
                        final host = hosts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DepartmentHostCard(
                            host: host,
                            departmentName: _departmentName(host.departmentId),
                            isAdmin: widget.isAdmin,
                            isSaving: _isSaving,
                            onEditDepartment: () => _editHostDepartment(host),
                            onDelete: () => _deleteHost(host),
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

class _HostMessageCard extends StatelessWidget {
  const _HostMessageCard({
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111D32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isError
              ? const Color(0xFFFF3155).withValues(alpha: .55)
              : const Color(0xFF28405E),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isError ? Icons.cloud_off_rounded : Icons.people_outline_rounded,
            size: 30,
            color: isError ? const Color(0xFFFF7185) : const Color(0xFF63C5FF),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB5C1D6), fontSize: 12),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DepartmentHostCard extends StatelessWidget {
  const _DepartmentHostCard({
    required this.host,
    required this.departmentName,
    required this.isAdmin,
    required this.isSaving,
    required this.onEditDepartment,
    required this.onDelete,
  });

  final DepartmentHost host;
  final String departmentName;
  final bool isAdmin;
  final bool isSaving;
  final VoidCallback onEditDepartment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    return Container(
      key: ValueKey('host-card-${host.id}'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14243D), Color(0xFF0B1528)],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x553D9DFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F087FFF),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF24BDF5), Color(0xFF087FFF)],
                  ),
                  border: Border.all(
                    color: const Color(0xFF9ADFFF),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x440087FF),
                      blurRadius: 14,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.login,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _dashboardPrimaryText(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      host.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF087FFF)
                            : const Color(0xFF67ACFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF153D35), Color(0xFF1D574A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x554AE3B5)),
                ),
                child: const Text(
                  'Anfitrión',
                  style: TextStyle(
                    color: Color(0xFF4AE3B5),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 5),
            decoration: BoxDecoration(
              color: isLight
                  ? const Color(0xFFF2F7FD)
                  : const Color(0x241C75C5),
              gradient: isLight
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x241C75C5), Color(0x160D315A)],
                    ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0x332D83D1)),
            ),
            child: Column(
              children: [
                _HostInfoRow(
                  icon: Icons.work_outline_rounded,
                  label: 'Puesto',
                  value: host.role,
                ),
                _HostInfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Correo',
                  value: host.email,
                ),
                _HostInfoRow(
                  icon: Icons.phone_rounded,
                  label: 'Teléfono',
                  value: host.phone,
                ),
                _HostInfoRow(
                  icon: Icons.apartment_rounded,
                  label: 'Departamento',
                  value: departmentName,
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF087FFF),
                      Color(0xFF168EFF),
                      Color(0xFF04BCEB),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x550087FF),
                      blurRadius: 13,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onEditDepartment,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.apartment_rounded, size: 18),
                  label: const Text(
                    'Cambiar departamento',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: isSaving ? null : onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7185),
                  side: const BorderSide(color: Color(0x66FF7185)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text(
                  'Eliminar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HostDepartmentDialog extends StatefulWidget {
  const _HostDepartmentDialog({
    required this.departments,
    required this.selectedDepartmentId,
  });

  final List<Department> departments;
  final int selectedDepartmentId;

  @override
  State<_HostDepartmentDialog> createState() => _HostDepartmentDialogState();
}

class _HostDepartmentDialogState extends State<_HostDepartmentDialog> {
  late int? _departmentId =
      widget.departments.any(
        (department) => department.id == widget.selectedDepartmentId,
      )
      ? widget.selectedDepartmentId
      : null;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          color: _dashboardSurfaceColor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight ? const Color(0xFFD8E4F2) : const Color(0x554AA8FF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.36),
              blurRadius: 28,
              offset: const Offset(0, 15),
            ),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF087FFF), Color(0xFF18B7D8)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORGANIZACIÓN',
                        style: TextStyle(
                          color: isLight
                              ? const Color(0xFF167C92)
                              : const Color(0xFF73CDE0),
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cambiar departamento',
                        style: TextStyle(
                          color: _dashboardPrimaryText(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: _dashboardSecondaryText(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Elige el área a la que pertenece este anfitrión.',
              style: TextStyle(
                color: _dashboardSecondaryText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.departments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 7),
                itemBuilder: (context, index) {
                  final department = widget.departments[index];
                  final selected = department.id == _departmentId;
                  return Material(
                    color: selected
                        ? const Color(0xFF087FFF).withValues(alpha: 0.11)
                        : isLight
                        ? const Color(0xFFF7F9FC)
                        : const Color(0xFF0A1426),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () =>
                          setState(() => _departmentId = department.id),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF168BFF).withValues(alpha: 0.6)
                                : isLight
                                ? const Color(0xFFE2E8F0)
                                : const Color(0x223D9DFF),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.business_rounded,
                              color: selected
                                  ? const Color(0xFF087FFF)
                                  : _dashboardSecondaryText(context),
                              size: 19,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                department.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _dashboardPrimaryText(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF087FFF),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _dashboardPrimaryText(context),
                      side: BorderSide(
                        color: isLight
                            ? const Color(0xFFC9D6E6)
                            : const Color(0x557F94B3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _departmentId == null
                        ? null
                        : () => Navigator.of(context).pop(_departmentId),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF087FFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Guardar'),
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

class _HostInfoRow extends StatelessWidget {
  const _HostInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    final displayValue = value.trim().isEmpty ? 'No disponible' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 23,
            child: Icon(icon, size: 16, color: const Color(0xFF28A0FF)),
          ),
          const SizedBox(width: 7),
          SizedBox(
            width: 88,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isLight
                    ? const Color(0xFF65758B)
                    : const Color(0xFF91A4C1),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _dashboardPrimaryText(context),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentHostDraft {
  const _DepartmentHostDraft({
    required this.login,
    required this.name,
    required this.departmentId,
    required this.role,
    required this.email,
    required this.phone,
    required this.fromAccessAccount,
  });

  final String login;
  final String name;
  final int departmentId;
  final String role;
  final String email;
  final String phone;
  final bool fromAccessAccount;
}

class _HostFormDialog extends StatefulWidget {
  const _HostFormDialog({
    required this.departments,
    required this.accounts,
    this.host,
  });

  final DepartmentHost? host;
  final List<Department> departments;
  final List<HostAccountOption> accounts;

  @override
  State<_HostFormDialog> createState() => _HostFormDialogState();
}

class _HostFormDialogState extends State<_HostFormDialog> {
  static const _otherAccount = '__otro__';
  final _formKey = GlobalKey<FormState>();
  late final _loginController = TextEditingController(
    text: widget.host?.login ?? '',
  );
  late final _nameController = TextEditingController(
    text: widget.host?.name ?? '',
  );
  late final _roleController = TextEditingController(
    text: widget.host?.role ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.host?.email ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.host?.phone ?? '',
  );
  late int? _departmentId =
      widget.host?.departmentId ?? widget.departments.first.id;
  late String _accountSelection =
      widget.accounts.any(
        (account) =>
            account.login.toLowerCase() == widget.host?.login.toLowerCase(),
      )
      ? widget.host!.login
      : _otherAccount;

  bool get _manualEntry => _accountSelection == _otherAccount;

  @override
  void dispose() {
    _loginController.dispose();
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _selectAccount(String? login) {
    if (login == null) return;
    setState(() => _accountSelection = login);
    if (login == _otherAccount) return;
    HostAccountOption? account;
    for (final candidate in widget.accounts) {
      if (candidate.login == login) {
        account = candidate;
        break;
      }
    }
    if (account == null) return;
    _loginController.text = account.login;
    _nameController.text = account.name?.trim().isNotEmpty == true
        ? account.name!.trim()
        : account.login;
    _roleController.text = account.role ?? '';
    _emailController.text = account.email ?? '';
    _phoneController.text = account.phone ?? '';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final departmentId = _departmentId;
    if (departmentId == null) return;
    Navigator.of(context).pop(
      _DepartmentHostDraft(
        login: _loginController.text.trim(),
        name: _nameController.text.trim(),
        departmentId: departmentId,
        role: _roleController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        fromAccessAccount: !_manualEntry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.host != null;
    return Dialog(
      backgroundColor: _dashboardSurfaceColor(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: _isLightDashboard(context)
              ? const Color(0xFFDCE4EF)
              : const Color(0xFF087FFF),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
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
                      foregroundColor: _dashboardSecondaryText(context),
                      backgroundColor: _isLightDashboard(context)
                          ? const Color(0xFFF3F6FB)
                          : const Color(0xFF172747),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                editing ? 'Editar anfitrión' : 'Registrar anfitrión',
                style: TextStyle(
                  color: _dashboardPrimaryText(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                editing ? 'Actualiza los datos y el departamento asignado.' : 'Selecciona una cuenta de Accesos o captura los datos manualmente.',
                style: TextStyle(
                  color: _dashboardSecondaryText(context),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              _DepartmentHostFormField(
                label: 'Cuenta de Accesos',
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('host-access-account-select'),
                  initialValue: _accountSelection,
                  isExpanded: true,
                  dropdownColor: _dashboardSurfaceColor(context),
                  style: TextStyle(
                    color: _dashboardPrimaryText(context),
                    fontSize: 13,
                  ),
                  decoration: _hostInputDecoration(context),
                  items: [
                    ...widget.accounts.map(
                      (account) => DropdownMenuItem(
                        value: account.login,
                        child: Text(
                          '${account.name?.trim().isNotEmpty == true ? account.name : account.login} · ${account.login}',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const DropdownMenuItem(
                      value: _otherAccount,
                      child: Text('Otro (capturar manualmente)'),
                    ),
                  ],
                  onChanged: editing ? null : _selectAccount,
                ),
              ),
              const SizedBox(height: 12),
              _DepartmentHostFormField(
                label: 'Nombre completo',
                child: TextFormField(
                  controller: _nameController,
                  readOnly: !_manualEntry,
                  maxLength: 180,
                  style: TextStyle(color: _dashboardPrimaryText(context)),
                  decoration: _hostInputDecoration(context),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el nombre completo.'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              _DepartmentHostFormField(
                label: 'Login (usuario)',
                child: TextFormField(
                  controller: _loginController,
                  readOnly: !_manualEntry,
                  maxLength: 255,
                  style: TextStyle(color: _dashboardPrimaryText(context)),
                  decoration: _hostInputDecoration(context),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Escribe el login.'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              _DepartmentHostFormField(
                label: 'Departamento',
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('host-department-select'),
                  isExpanded: true,
                  initialValue:
                      widget.departments.any(
                        (department) => department.id == _departmentId,
                      )
                      ? _departmentId
                      : null,
                  dropdownColor: _dashboardSurfaceColor(context),
                  style: TextStyle(
                    color: _dashboardPrimaryText(context),
                    fontSize: 13,
                  ),
                  decoration: _hostInputDecoration(context),
                  items: widget.departments
                      .map(
                        (department) => DropdownMenuItem(
                          value: department.id,
                          child: Text(
                            department.name,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _departmentId = value),
                  validator: (value) =>
                      value == null ? 'Selecciona un departamento.' : null,
                ),
              ),
              const SizedBox(height: 12),
              _DepartmentHostFormField(
                label: 'Correo electrónico',
                child: TextFormField(
                  controller: _emailController,
                  readOnly: !_manualEntry,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: _dashboardPrimaryText(context)),
                  decoration: _hostInputDecoration(context),
                ),
              ),
              const SizedBox(height: 12),
              _DepartmentHostFormField(
                label: 'Puesto',
                child: TextFormField(
                  controller: _roleController,
                  readOnly: !_manualEntry,
                  maxLength: 120,
                  style: TextStyle(color: _dashboardPrimaryText(context)),
                  decoration: _hostInputDecoration(context),
                ),
              ),
              const SizedBox(height: 12),
              _DepartmentHostFormField(
                label: 'Teléfono',
                child: TextFormField(
                  controller: _phoneController,
                  readOnly: !_manualEntry,
                  maxLength: 30,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: _dashboardPrimaryText(context)),
                  decoration: _hostInputDecoration(context),
                ),
              ),
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
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      editing ? 'Guardar cambios' : 'Registrar anfitrión',
                      style: const TextStyle(
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

class _DepartmentHostFormField extends StatelessWidget {
  const _DepartmentHostFormField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _dashboardPrimaryText(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
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
          style: TextStyle(
            color: _dashboardPrimaryText(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          keyboardType: keyboardType,
          style: TextStyle(color: _dashboardPrimaryText(context)),
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

InputDecoration _hostInputDecoration(BuildContext context) => InputDecoration(
  filled: true,
  fillColor: _isLightDashboard(context)
      ? const Color(0xFFF3F6FB)
      : const Color(0xFF091325),
  counterText: '',
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(
      color: _isLightDashboard(context)
          ? const Color(0xFFDCE4EF)
          : const Color(0xFF27476A),
    ),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFF087FFF), width: 2),
  ),
);

class _DepartmentsPage extends StatefulWidget {
  const _DepartmentsPage({
    required this.authService,
    required this.isAdmin,
    this.user,
  });

  final AuthService? authService;
  final bool isAdmin;
  final AuthenticatedUser? user;

  @override
  State<_DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<_DepartmentsPage> {
  late final AuthService _authService =
      widget.authService ?? AuthService.shared;
  List<Department> _departments = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDepartments());
  }

  Future<void> _loadDepartments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final departments = await _authService.getDepartments();
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _isLoading = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudieron cargar los departamentos. Inténtalo de nuevo.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDepartment({Department? department}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _DepartmentFormDialog(department: department),
    );
    if (name == null || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final departments = department == null
          ? await _authService.createDepartment(name)
          : await _authService.updateDepartment(department.id, name);
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _isSaving = false;
      });
      AppFeedback.show(
        context,
        department == null
            ? 'Departamento registrado correctamente.'
            : 'Departamento actualizado correctamente.',
        type: AppFeedbackType.success,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo guardar el departamento. Inténtalo de nuevo.';
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteDepartment(Department department) async {
    final confirmed = await showReceptionConfirmDialog(
      context: context,
      title: 'Eliminar departamento',
      message: '¿Quieres eliminar "${department.name}"?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final departments = await _authService.deleteDepartment(department.id);
      if (!mounted) return;
      setState(() {
        _departments = departments;
        _isSaving = false;
      });
      AppFeedback.show(
        context,
        'Departamento eliminado.',
        type: AppFeedbackType.success,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'No se pudo eliminar el departamento. Inténtalo de nuevo.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('departments-section-root'),
      decoration: _dashboardPageDecoration(context),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _DashboardHeader(
                  authService: _authService,
                  user: widget.user,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Departamento',
                      style: TextStyle(
                        color: _dashboardPrimaryText(context),
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Administra departamentos y consulta los anfitriones vinculados',
                      style: TextStyle(
                        color: _dashboardSecondaryText(context),
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
                    color: _dashboardSurfaceColor(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF087FFF)),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 560;
                      final icon = Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0x221B8AFF),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xFF087FFF)),
                        ),
                        child: const Icon(
                          Icons.account_tree_rounded,
                          color: Color(0xFF087FFF),
                          size: 19,
                        ),
                      );
                      const title = Expanded(
                        child: Text(
                          'Departamentos',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                      final count = Text(
                        '${_departments.length} departamentos',
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF087FFF),
                          fontSize: 10,
                        ),
                      );
                      final registerButton = SizedBox(
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
                            onPressed: !widget.isAdmin || _isSaving
                                ? null
                                : () => _saveDepartment(),
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
                      );

                      if (compact) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                icon,
                                const SizedBox(width: 10),
                                title,
                                const SizedBox(width: 8),
                                count,
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (widget.isAdmin)
                              SizedBox(
                                width: double.infinity,
                                child: registerButton,
                              ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          icon,
                          const SizedBox(width: 10),
                          title,
                          count,
                          if (widget.isAdmin) ...[
                            const SizedBox(width: 8),
                            registerButton,
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_errorMessage != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: _DepartmentMessageCard(
                    message: _errorMessage!,
                    isError: true,
                    onRetry: _loadDepartments,
                  ),
                ),
              ),
            if (_isSaving)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 0),
                  child: LinearProgressIndicator(
                    color: Color(0xFF087FFF),
                    backgroundColor: Color(0xFF17243D),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                14,
                12,
                14,
                responsiveBottomScrollPadding(context),
              ),
              sliver: _isLoading
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF087FFF),
                          ),
                        ),
                      ),
                    )
                  : _errorMessage != null
                  ? const SliverToBoxAdapter(child: SizedBox.shrink())
                  : _departments.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _DepartmentMessageCard(
                        message: 'Aún no hay departamentos. Registra el primero para comenzar.',
                      ),
                    )
                  : SliverLayoutBuilder(
                      builder: (context, constraints) {
                        return SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _DepartmentCard(
                              department: _departments[index],
                              isAdmin: widget.isAdmin,
                              isSaving: _isSaving,
                              onEdit: () => _saveDepartment(
                                department: _departments[index],
                              ),
                              onDelete: () =>
                                  _deleteDepartment(_departments[index]),
                            ),
                            childCount: _departments.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: 196,
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

class _DepartmentMessageCard extends StatelessWidget {
  const _DepartmentMessageCard({
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111D32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isError ? const Color(0x99FF5A72) : const Color(0x550087FF),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isError ? Icons.cloud_off_rounded : Icons.account_tree_rounded,
            size: 32,
            color: isError ? const Color(0xFFFF7187) : const Color(0xFF59B8FF),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD4DDF0),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.isAdmin,
    required this.isSaving,
    required this.onEdit,
    required this.onDelete,
  });

  final Department department;
  final bool isAdmin;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightDashboard(context);
    return Container(
      key: ValueKey('department-card-${department.id}'),
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
          color: isLight ? Colors.white : null,
          gradient: isLight
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF17243D),
                    Color(0xFF0B1427),
                    Color(0xFF10172D),
                  ],
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF087FFF), Color(0xFF00C8FF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x550087FF),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_tree_outlined,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFEAF2FC)
                        : const Color(0xFF102B48),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x664A9DFF)),
                  ),
                  child: Text(
                    '#${department.id}',
                    style: TextStyle(
                      color: Color(0xFF9BCBFF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              department.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _dashboardPrimaryText(context),
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.people_alt_outlined,
                  color: Color(0xFF63C5FF),
                  size: 14,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${department.hostCount} ${department.hostCount == 1 ? 'anfitrión vinculado' : 'anfitriones vinculados'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _dashboardSecondaryText(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (isAdmin)
              Row(
                children: [
                  Expanded(
                    child: _DepartmentActionButton(
                      label: 'Editar',
                      icon: Icons.edit_rounded,
                      gradient: const [Color(0xFF087FFF), Color(0xFF00B7E8)],
                      onPressed: isSaving ? null : onEdit,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DepartmentActionButton(
                      label: 'Eliminar',
                      icon: Icons.delete_outline_rounded,
                      gradient: const [Color(0xFFFF3155), Color(0xFFD91B50)],
                      onPressed: isSaving ? null : onDelete,
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Departamento registrado',
                style: TextStyle(
                  color: Color(0xFF9BCBFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentActionButton extends StatelessWidget {
  const _DepartmentActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onPressed;

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
      child: Material(
        color: const Color(0xFF0C162B),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(7),
          child: Tooltip(
            message: label,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

class _DepartmentFormDialog extends StatefulWidget {
  const _DepartmentFormDialog({this.department});

  final Department? department;

  @override
  State<_DepartmentFormDialog> createState() => _DepartmentFormDialogState();
}

class _DepartmentFormDialogState extends State<_DepartmentFormDialog> {
  late final _nameController = TextEditingController(
    text: widget.department?.name ?? '',
  );
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length > 120) {
      setState(() {
        _errorMessage = 'Escribe un nombre de hasta 120 caracteres.';
      });
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: _dashboardSurfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isLightDashboard(context)
                ? const Color(0xFFDCE4EF)
                : const Color(0xFF087FFF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _isLightDashboard(context) ? .08 : .4,
              ),
              blurRadius: 28,
            ),
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
                    backgroundColor: _isLightDashboard(context)
                        ? const Color(0xFFF3F6FB)
                        : const Color(0xFF172747),
                    foregroundColor: _dashboardSecondaryText(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              widget.department == null
                  ? 'Registrar departamento'
                  : 'Editar departamento',
              style: TextStyle(
                color: _dashboardPrimaryText(context),
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.department == null
                  ? 'Captura el nombre del departamento.'
                  : 'Actualiza el nombre del departamento.',
              style: TextStyle(
                color: _dashboardSecondaryText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Nombre del departamento',
              style: TextStyle(
                color: _dashboardPrimaryText(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => _save(),
              style: TextStyle(color: _dashboardPrimaryText(context)),
              decoration: InputDecoration(
                filled: true,
                fillColor: _isLightDashboard(context)
                    ? const Color(0xFFF3F6FB)
                    : const Color(0xFF091325),
                hintText: 'Ej. Recursos Humanos',
                hintStyle: TextStyle(color: _dashboardSecondaryText(context)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _isLightDashboard(context)
                        ? const Color(0xFFDCE4EF)
                        : const Color(0xFF087FFF),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF087FFF),
                    width: 2,
                  ),
                ),
                errorText: _errorMessage,
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
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    widget.department == null
                        ? 'Registrar departamento'
                        : 'Guardar cambios',
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
    this.user,
    this.isLoggingOut = false,
    this.onLogout,
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
  final AuthenticatedUser? user;
  final bool isLoggingOut;
  final VoidCallback? onLogout;
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
    final isLight = _isLightDashboard(context);
    final currentSection = activeSection ?? 'home';
    final isAdmin = user?.isAdmin == true;
    final hasReceptionAccess =
        user?.sectionAccess.contains('recepcion') == true;
    final isHost =
        !isAdmin &&
        !hasReceptionAccess &&
        user?.sectionAccess.contains('anfitriones') == true;
    final userName = user?.name?.trim();
    final displayName = userName != null && userName.isNotEmpty
        ? userName
        : user?.login ?? 'Cuenta';
    final displayRole = isAdmin
        ? 'Administrador'
        : user?.role?.trim().isNotEmpty == true
        ? user!.role!.trim()
        : hasReceptionAccess
        ? 'Recepción'
        : 'Anfitrión';
    return Drawer(
      width: 300,
      backgroundColor: Colors.transparent,
      elevation: 24,
      shadowColor: const Color(0xCC087FFF),
      child: Container(
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFF3F7FC) : null,
          gradient: isLight
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF10172D),
                    Color(0xFF080D1C),
                    Color(0xFF050713),
                  ],
                  stops: [0, .48, 1],
                ),
          border: Border(
            right: BorderSide(
              color: isLight
                  ? const Color(0xFFD8E2EF)
                  : const Color(0x9900A8FF),
              width: .7,
            ),
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
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      children: [
                        Container(
                          key: const ValueKey('drawer-session-user'),
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isLight
                                  ? const [Colors.white, Color(0xFFEAF2FC)]
                                  : const [
                                      Color(0xFF202A49),
                                      Color(0xFF10172A),
                                    ],
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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  8,
                                  32,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/images/cymez-reception-logo.webp',
                                      cacheWidth: 480,
                                      width: 76,
                                      height: 62,
                                      fit: BoxFit.contain,
                                    ),
                                    Container(
                                      width: 1,
                                      height: 48,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                      ),
                                      color: const Color(0x553D8FFF),
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isLight
                                                  ? const Color(0xFF17243A)
                                                  : Colors.white,
                                              fontSize: 12,
                                              height: 1.15,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            displayRole,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isLight
                                                  ? const Color(0xFF087FFF)
                                                  : const Color(0xFF75BFFF),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
                        if (isAdmin) ...[
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
                        ],
                        if (isAdmin || isHost) ...[
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
                        ],
                        if (isAdmin || hasReceptionAccess || isHost) ...[
                          const _DrawerLabel('Operación'),
                          _DrawerItem(
                            icon: Icons.calendar_month_rounded,
                            label: 'Agenda de citas',
                            active: currentSection == 'appointments',
                            onTap: onAppointments,
                          ),
                        ],
                        if (isAdmin || hasReceptionAccess)
                          _DrawerItem(
                            icon: Icons.assignment_rounded,
                            label: 'Bitácora diaria',
                            active: currentSection == 'logbook',
                            onTap: onLogbook,
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                    child: SizedBox(
                      height: 46,
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('drawer-logout'),
                        onPressed: isLoggingOut ? null : onLogout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF7189),
                          side: const BorderSide(color: Color(0x99FF4565)),
                          backgroundColor: const Color(0x18FF3155),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(
                          isLoggingOut ? 'Cerrando sesión...' : 'Cerrar sesión',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
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
    final isLight = _isLightDashboard(context);
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
            style: TextStyle(
              color: isLight
                  ? const Color(0xFF65758B)
                  : const Color(0xFF8798B8),
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
    final isLight = _isLightDashboard(context);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        key: ValueKey('drawer-item-$label'),
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
        selectedTileColor: isLight
            ? const Color(0xFFFFE6EC)
            : const Color(0x28FF3155),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFFF3155), Color(0xFFCF1741)],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isLight
                        ? const [Color(0xFFE5EEF9), Color(0xFFF7FAFE)]
                        : const [Color(0xFF182441), Color(0xFF11182A)],
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
            color: active
                ? Colors.white
                : isLight
                ? const Color(0xFF53647D)
                : const Color(0xFFC4CEE1),
          ),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: active
                ? (isLight ? const Color(0xFF9E1230) : Colors.white)
                : isLight
                ? const Color(0xFF33435C)
                : const Color(0xFFDDE2EE),
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
      ),
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
