import 'package:flutter/material.dart';

class ReceptionThemeScope extends InheritedWidget {
  const ReceptionThemeScope({
    required this.isDarkMode,
    required this.onChanged,
    required this.onLogout,
    required super.child,
    super.key,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onChanged;
  final Future<void> Function() onLogout;

  static ReceptionThemeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReceptionThemeScope>();

  @override
  bool updateShouldNotify(ReceptionThemeScope oldWidget) =>
      isDarkMode != oldWidget.isDarkMode;
}

Future<void> showReceptionThemeMenu({
  required BuildContext context,
  required String name,
  required String role,
}) {
  final themeScope = ReceptionThemeScope.maybeOf(context);
  if (themeScope == null) return Future<void>.value();

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar menú de usuario',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(dialogContext).top + 72,
            right: 10,
            width: 268,
            child: _ReceptionProfileDropdown(
              name: name,
              role: role,
              isDarkMode: themeScope.isDarkMode,
              onThemeChanged: themeScope.onChanged,
              onLogout: themeScope.onLogout,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ],
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.035),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
  );
}

class _ReceptionProfileDropdown extends StatefulWidget {
  const _ReceptionProfileDropdown({
    required this.name,
    required this.role,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onLogout,
    required this.onClose,
  });

  final String name;
  final String role;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final Future<void> Function() onLogout;
  final VoidCallback onClose;

  @override
  State<_ReceptionProfileDropdown> createState() =>
      _ReceptionProfileDropdownState();
}

class _ReceptionProfileDropdownState extends State<_ReceptionProfileDropdown> {
  late bool _isDarkMode = widget.isDarkMode;
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    widget.onClose();
    await widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = _isDarkMode ? Colors.white : const Color(0xFF17243A);
    final secondaryText = _isDarkMode
        ? const Color(0xFFDDE6F5)
        : const Color(0xFF33435C);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isDarkMode
                ? const [Color(0xFF172442), Color(0xFF090F20)]
                : const [Color(0xFFFFFFFF), Color(0xFFEAF3FF)],
          ),
          border: Border.all(
            color: _isDarkMode
                ? const Color(0x990087FF)
                : const Color(0xFFB8D8FA),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF087FFF)
                  .withValues(alpha: _isDarkMode ? 0.32 : 0.16),
              blurRadius: 22,
              offset: const Offset(0, 10),
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
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFF087FFF),
                    child: Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF168BFF),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDarkMode
                      ? const Color(0x190087FF)
                      : const Color(0x332D76B8),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: const Color(0xFF168BFF),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modo oscuro',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    key: const ValueKey('dashboard-theme-switch'),
                    value: _isDarkMode,
                    activeTrackColor: const Color(0xFF087FFF),
                    activeThumbColor: Colors.white,
                    onChanged: (value) {
                      setState(() => _isDarkMode = value);
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
                key: const ValueKey('connected-profile-logout'),
                onPressed: _isLoggingOut ? null : _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD52F4A),
                  side: BorderSide(
                    color: const Color(0xFFD52F4A).withValues(alpha: 0.55),
                  ),
                  backgroundColor: const Color(0x18FF3155),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  _isLoggingOut ? 'Cerrando sesión...' : 'Cerrar sesión',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

Future<bool> showReceptionConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Continuar',
  bool destructive = false,
}) async {
  final isLight = Theme.of(context).brightness == Brightness.light;
  final accent = destructive
      ? const Color(0xFFE44861)
      : const Color(0xFF168BFF);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF101A2D),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accent.withValues(alpha: isLight ? 0.3 : 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isLight ? 0.14 : 0.38),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isLight ? 0.1 : 0.16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        destructive
                            ? Icons.delete_outline_rounded
                            : Icons.fact_check_outlined,
                        color: accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destructive ? 'CONFIRMACIÓN REQUERIDA' : 'REVISIÓN',
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              letterSpacing: 1.15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            title,
                            style: TextStyle(
                              color: isLight
                                  ? const Color(0xFF17243A)
                                  : Colors.white,
                              fontSize: 19,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(dialogContext, false),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isLight
                            ? const Color(0xFF5C6B80)
                            : const Color(0xFFB5C1D6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isLight
                        ? const Color(0xFFF3F6FB)
                        : const Color(0xFF0A1426),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isLight
                          ? const Color(0xFFDCE4EF)
                          : const Color(0x333D9DFF),
                    ),
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF5C6B80)
                          : const Color(0xFFB5C1D6),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isLight
                              ? const Color(0xFF17243A)
                              : Colors.white,
                          side: BorderSide(
                            color: isLight
                                ? const Color(0xFFDCE4EF)
                                : const Color(0x333D9DFF),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('Volver'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: Icon(
                          destructive
                              ? Icons.delete_rounded
                              : Icons.check_rounded,
                          size: 17,
                        ),
                        label: Text(confirmLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}

class ReceptionHeaderBar extends StatelessWidget {
  const ReceptionHeaderBar({
    super.key,
    required this.name,
    required this.role,
    required this.onMenuTap,
    this.onProfileTap,
  });

  final String name;
  final String role;
  final VoidCallback onMenuTap;
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 440;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return SizedBox(
      height: 68,
      child: Container(
        decoration: BoxDecoration(
          color: isLight ? Colors.white : const Color(0xFF07162E),
          border: Border(
            bottom: BorderSide(
              color: isLight
                  ? const Color(0xFFD8E2EF)
                  : const Color(0xFF263B58),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            _ReceptionMenuButton(onTap: onMenuTap, isLight: isLight),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/cymez-reception-logo.webp',
                    cacheWidth: 480,
                    width: compact ? 58 : 82,
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
                  Text(
                    'RECEP',
                    style: TextStyle(
                      color: isLight ? const Color(0xFF17243A) : Colors.white,
                      fontSize: 13,
                      height: 1.05,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 5),
                    Text(
                      'CONTROL DE\nVISITANTES',
                      style: TextStyle(
                        color: isLight
                            ? const Color(0xFF65758B)
                            : const Color(0xFF9CB5D1),
                        fontSize: 7,
                        height: 1.25,
                        letterSpacing: .55,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _ReceptionProfileButton(
              name: name,
              role: role,
              compact: compact,
              onTap: onProfileTap,
              isLight: isLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceptionMenuButton extends StatelessWidget {
  const _ReceptionMenuButton({required this.onTap, required this.isLight});

  final VoidCallback onTap;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: isLight ? const Color(0xFFF1F6FD) : const Color(0xFF09101D),
          border: Border.all(
            color: isLight ? const Color(0xFFD8E2EF) : const Color(0xFF263B58),
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.menu_rounded,
          color: isLight ? const Color(0xFF33435C) : const Color(0xFFB7C7DA),
          size: 25,
        ),
      ),
    );
  }
}

class _ReceptionProfileButton extends StatelessWidget {
  const _ReceptionProfileButton({
    required this.name,
    required this.role,
    required this.compact,
    required this.onTap,
    required this.isLight,
  });

  final String name;
  final String role;
  final bool compact;
  final VoidCallback? onTap;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('connected-session-user'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 100 : 140),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isLight ? const Color(0xFF17243A) : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF75BFFF),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: compact ? 36 : 42,
              height: compact ? 36 : 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isLight
                      ? const [Color(0xFFE7F0FC), Color(0xFFF7FAFE)]
                      : const [Color(0xFF111D32), Color(0xFF09101D)],
                ),
                border: Border.all(
                  color: isLight
                      ? const Color(0xFFD8E2EF)
                      : const Color(0xFF263B58),
                ),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: isLight
                    ? const Color(0xFF52657D)
                    : const Color(0xFFB7C7DA),
                size: compact ? 21 : 25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
