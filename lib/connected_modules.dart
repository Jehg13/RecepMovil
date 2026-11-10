import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_feedback.dart';
import 'auth_service.dart';
import 'reception_header.dart';
import 'src/timer_notifications.dart';

class _RealtimeRefreshCoordinator {
  _RealtimeRefreshCoordinator(this._authService, this._refresh);

  final AuthService _authService;
  final VoidCallback _refresh;
  StreamSubscription<RealtimeEvent>? _subscription;
  Timer? _reconnectTimer;
  Timer? _fallbackTimer;
  bool _disposed = false;

  void start() => _connect();

  void _connect() {
    if (_disposed) return;
    _subscription = _authService.watchRealtimeUpdates().listen(
      (event) {
        if (event == RealtimeEvent.disconnected) {
          _startFallback();
          return;
        }
        if (event == RealtimeEvent.connected) {
          _fallbackTimer?.cancel();
          _fallbackTimer = null;
        }
        _refresh();
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Se interrumpió la conexión de actualizaciones: $error');
        _scheduleReconnect();
      },
      onDone: _scheduleReconnect,
    );
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) return;
    _startFallback();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      _connect();
    });
  }

  void _startFallback() {
    if (_disposed || _fallbackTimer != null) return;
    _fallbackTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(),
    );
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _fallbackTimer?.cancel();
    unawaited(_subscription?.cancel());
  }
}

const _pageBackground = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
);
const _panelBackground = Color(0xFF111D35);
const _accent = Color(0xFF168BFF);
const _muted = Color(0xFFB5C1D6);

bool _isLightTheme(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light;

Color _primaryTextColor(BuildContext context) =>
    _isLightTheme(context) ? const Color(0xFF17243A) : Colors.white;

Color _secondaryTextColor(BuildContext context) =>
    _isLightTheme(context) ? const Color(0xFF5C6B80) : _muted;

Color _panelColor(BuildContext context) =>
    _isLightTheme(context) ? Colors.white : _panelBackground;

Color _logInsetColor(BuildContext context) =>
    _isLightTheme(context) ? const Color(0xFFF3F6FB) : const Color(0xFF0A1426);

Color _logDialogColor(BuildContext context) =>
    _isLightTheme(context) ? Colors.white : const Color(0xFF101A2D);

Color _logBorderColor(BuildContext context) =>
    _isLightTheme(context) ? const Color(0xFFDCE4EF) : const Color(0x333D9DFF);

BoxDecoration _connectedPageDecoration(BuildContext context) =>
    _isLightTheme(context)
    ? const BoxDecoration(color: Color(0xFFF3F7FC))
    : const BoxDecoration(gradient: _pageBackground);

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _displayDate(Object? value) {
  if (value is! String || value.isEmpty) return 'Sin fecha';
  final date = DateTime.tryParse(value);
  return date == null
      ? value
      : '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/'
            '${date.year}';
}

void _showMessage(
  BuildContext context,
  String message, {
  bool error = false,
  AppFeedbackType type = AppFeedbackType.success,
  String? title,
}) {
  AppFeedback.show(
    context,
    message,
    type: error ? AppFeedbackType.error : type,
    title: title,
  );
}

ButtonStyle _logPrimaryButtonStyle(
  BuildContext context, {
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    horizontal: 18,
    vertical: 13,
  ),
}) {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF087FFF),
    foregroundColor: Colors.white,
    padding: padding,
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
    shape: const StadiumBorder(),
  );
}

ButtonStyle _logOutlinedButtonStyle(
  BuildContext context, {
  EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  ),
}) {
  return OutlinedButton.styleFrom(
    foregroundColor: _isLightTheme(context)
        ? const Color(0xFF1769AA)
        : const Color(0xFF9FCBFF),
    side: BorderSide(
      color: _isLightTheme(context)
          ? const Color(0xFFB8C7D9)
          : const Color(0xFF3B82B8),
    ),
    padding: padding,
    textStyle: const TextStyle(fontWeight: FontWeight.w700),
    shape: const StadiumBorder(),
  );
}

Future<bool> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continuar',
}) async {
  final destructive = RegExp(
    r'eliminar|revocar|cancelar',
    caseSensitive: false,
  ).hasMatch('$title $confirmLabel');
  return showReceptionConfirmDialog(
    context: context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    destructive: destructive,
  );
}

class _ConnectedPage extends StatelessWidget {
  const _ConnectedPage({
    required this.title,
    required this.subtitle,
    required this.child,
    this.user,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final AuthenticatedUser? user;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final userName = user?.name?.trim();
    final displayName = userName != null && userName.isNotEmpty
        ? userName
        : user?.login ?? 'Cuenta';
    final displayRole = user?.role?.trim().isNotEmpty == true
        ? user!.role!.trim()
        : user?.isAdmin == true
        ? 'Administrador'
        : 'Recepción';
    return Container(
      key: const ValueKey('connected-section-root'),
      decoration: _connectedPageDecoration(context),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: ReceptionHeaderBar(
                name: displayName,
                role: displayRole,
                onMenuTap: () => Scaffold.of(context).openDrawer(),
                onProfileTap: () => showReceptionThemeMenu(
                  context: context,
                  name: displayName,
                  role: displayRole,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

Widget _loadingOrError({
  required BuildContext context,
  required bool loading,
  required String? error,
  required VoidCallback onRetry,
}) {
  if (loading) {
    return const Center(child: CircularProgressIndicator(color: _accent));
  }
  if (error != null) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _muted, size: 36),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: _primaryTextColor(context)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
  return const SizedBox.shrink();
}

Widget _panel({
  required BuildContext context,
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(14),
}) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: _panelColor(context),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0x66087FFF)),
  ),
  child: child,
);

Widget _logbookPanel({required BuildContext context, required Widget child}) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isLightTheme(context) ? Colors.white : null,
        gradient: _isLightTheme(context)
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF17243D), Color(0xFF0B1427)],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF087FFF), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220087FF),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

Widget _searchBox({
  required BuildContext context,
  required String hint,
  required ValueChanged<String> onChanged,
  int? maxLength,
}) => TextField(
  maxLength: maxLength,
  onChanged: onChanged,
  style: TextStyle(color: _primaryTextColor(context)),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF8290A8), fontSize: 13),
    prefixIcon: const Icon(Icons.search_rounded, color: _accent),
    filled: true,
    fillColor: _isLightTheme(context)
        ? const Color(0xFFF2F7FD)
        : const Color(0xFF0B1427),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
);

class ConnectedExternalCompaniesPage extends StatefulWidget {
  const ConnectedExternalCompaniesPage({
    required this.authService,
    required this.isAdmin,
    required this.canManage,
    this.user,
    super.key,
  });

  final AuthService authService;
  final bool isAdmin;
  final bool canManage;
  final AuthenticatedUser? user;

  @override
  State<ConnectedExternalCompaniesPage> createState() =>
      _ConnectedExternalCompaniesPageState();
}

class _ConnectedExternalCompaniesPageState
    extends State<ConnectedExternalCompaniesPage> {
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _type = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await widget.authService.getBusinessPartners();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? record]) async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _BusinessPartnerForm(record: record),
    );
    if (result == null) return;
    try {
      final updated = await widget.authService.saveBusinessPartner(
        result,
        id: record?['id'] as int?,
      );
      if (mounted) setState(() => _records = updated);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> record) async {
    if (!await _confirmAction(
      context,
      title: 'Eliminar registro',
      message: '¿Deseas eliminar “${record['name']}”?',
      confirmLabel: 'Eliminar',
    )) {
      return;
    }
    try {
      final updated = await widget.authService.deleteBusinessPartner(
        record['id'] as int,
      );
      if (mounted) setState(() => _records = updated);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = _records.where((item) {
      final queryMatch =
          '${item['name']} ${item['description']} ${item['rfc']} '
                  '${item['category']} ${item['subject']} ${item['registeredBy']}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      return queryMatch && (_type == 'Todos' || item['type'] == _type);
    }).toList();
    return _ConnectedPage(
      title: 'Empresas y visitantes',
      subtitle: 'Contratistas, proveedores y registros externos',
      user: widget.user,
      trailing: IconButton(
        tooltip: 'Actualizar',
        onPressed: _load,
        icon: Icon(
          Icons.refresh_rounded,
          color: _isLightTheme(context)
              ? const Color(0xFF52657D)
              : Colors.white,
        ),
      ),
      child: _loading || _error != null
          ? _loadingOrError(
              context: context,
              loading: _loading,
              error: _error,
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  _ExternalPartnersToolbar(
                    count: _records.length,
                    canManage: widget.canManage,
                    query: _query,
                    selectedType: _type,
                    onQueryChanged: (value) =>
                        setState(() => _query = value.trim()),
                    onTypeChanged: (value) => setState(() => _type = value),
                    onRegister: () => _edit(),
                  ),
                  const SizedBox(height: 12),
                  if (records.isEmpty)
                    const _EmptyRecords(
                      message: 'No hay registros que coincidan.',
                    )
                  else
                    for (final record in records) ...[
                      _ExternalPartnerCard(
                        record: record,
                        canManage: widget.canManage,
                        isAdmin: widget.isAdmin,
                        onEdit: () => _edit(record),
                        onDelete: () => _delete(record),
                      ),
                      const SizedBox(height: 9),
                    ],
                ],
              ),
            ),
    );
  }
}

class _ExternalPartnersToolbar extends StatelessWidget {
  const _ExternalPartnersToolbar({
    required this.count,
    required this.canManage,
    required this.query,
    required this.selectedType,
    required this.onQueryChanged,
    required this.onTypeChanged,
    required this.onRegister,
  });

  final int count;
  final bool canManage;
  final String query;
  final String selectedType;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isLightTheme(context) ? Colors.white : null,
        gradient: _isLightTheme(context)
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF172844), Color(0xFF0C172B)],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x663B9DFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F168BFF),
            blurRadius: 22,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1388FF), Color(0xFF31C4FF)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.domain_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ${count == 1 ? 'registro' : 'registros'}',
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Directorio de externos',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF168BFF), Color(0xFF725CFF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33168BFF),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: onRegister,
                    icon: const Icon(Icons.add_rounded, size: 19),
                    label: const Text('Registrar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            onChanged: onQueryChanged,
            style: TextStyle(color: _primaryTextColor(context), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar nombre, RFC, categoría o asunto',
              hintStyle: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF4AA8FF),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              filled: true,
              fillColor: _isLightTheme(context)
                  ? const Color(0xFFF3F6FB)
                  : const Color(0xFF091426),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0x243D9DFF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFF168BFF)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'FILTRAR POR TIPO',
            style: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final type in const [
                'Todos',
                'Contratista',
                'Proveedor',
                'Visitante',
              ])
                _PartnerFilterChip(
                  label: type,
                  selected: selectedType == type,
                  onTap: () => onTypeChanged(type),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerFilterChip extends StatelessWidget {
  const _PartnerFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _partnerTypeColor(label);
    return Material(
      color: selected
          ? color.withValues(alpha: _isLightTheme(context) ? 0.16 : 0.2)
          : _isLightTheme(context)
          ? const Color(0xFFF3F6FB)
          : const Color(0xFF0B1629),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.8)
                  : _isLightTheme(context)
                  ? const Color(0xFFDCE4EF)
                  : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? _isLightTheme(context)
                        ? const Color(0xFF17243A)
                        : Colors.white
                  : _secondaryTextColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExternalPartnerCard extends StatelessWidget {
  const _ExternalPartnerCard({
    required this.record,
    required this.canManage,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> record;
  final bool canManage;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    final type = '${record['type'] ?? 'Contratista'}';
    final isVisitor = type == 'Visitante';
    final color = _partnerTypeColor(type);
    final status = isVisitor
        ? 'No aplica'
        : '${record['status'] ?? 'Sin estado'}';
    final isActive = status == 'Activa';
    final rfc = '${record['rfc'] ?? ''}'.trim();
    final category = '${record['category'] ?? ''}'.trim();
    final subject = '${record['subject'] ?? ''}'.trim();
    final description = '${record['description'] ?? ''}'.trim();
    final employeeCount = record['employeeCount'] ?? (isVisitor ? 1 : '—');
    final registeredBy = '${record['registeredBy'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF17243D), Color(0xFF0C1628)],
              ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: color.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
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
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Icon(
                  isVisitor
                      ? Icons.person_rounded
                      : type == 'Proveedor'
                      ? Icons.local_shipping_rounded
                      : Icons.handyman_rounded,
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record['name'] ?? 'Sin nombre'}',
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PartnerBadge(label: type, color: color),
                        _PartnerBadge(
                          label: status,
                          color: isActive
                              ? const Color(0xFF4AE3B5)
                              : const Color(0xFF97A5BA),
                          icon: isActive
                              ? Icons.check_circle_rounded
                              : Icons.remove_circle_outline_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _secondaryTextColor(context),
                height: 1.45,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final spacing = 8.0;
              final tileWidth = (constraints.maxWidth - spacing) / 2;
              return Wrap(
                spacing: spacing,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _PartnerDetailTile(
                      label: 'RFC',
                      value: rfc.isEmpty ? 'N/A' : rfc,
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _PartnerDetailTile(
                      label: 'Categoría',
                      value: category.isEmpty
                          ? (isVisitor ? 'Visitante' : 'Sin categoría')
                          : category,
                      icon: Icons.category_outlined,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _PartnerDetailTile(
                      label: isVisitor ? 'Asunto' : 'Empleados',
                      value: isVisitor
                          ? (subject.isEmpty ? 'Sin especificar' : subject)
                          : '$employeeCount',
                      icon: isVisitor
                          ? Icons.event_note_rounded
                          : Icons.groups_2_outlined,
                    ),
                  ),
                  if (isVisitor)
                    SizedBox(
                      width: tileWidth,
                      child: _PartnerDetailTile(
                        label: 'Empleados',
                        value: '$employeeCount',
                        icon: Icons.groups_2_outlined,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          _PartnerDetailTile(
            label: 'Registrado por',
            value: registeredBy.isEmpty ? 'Registro manual' : registeredBy,
            icon: Icons.person_outline_rounded,
          ),
          if (canManage || isAdmin) ...[
            const SizedBox(height: 13),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (canManage)
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF087FFF), Color(0xFF04BCEB)],
                          ),
                        ),
                        child: FilledButton.icon(
                          onPressed: onEdit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 17),
                          label: const Text(
                            'Editar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (canManage && isAdmin) const SizedBox(width: 9),
                if (isAdmin)
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF7189),
                          side: const BorderSide(color: Color(0x66FF7189)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Eliminar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PartnerDetailTile extends StatelessWidget {
  const _PartnerDetailTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 57),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF2F7FD) : const Color(0xFF0B1629),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF62B4FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isLight
                        ? const Color(0xFF65758B)
                        : const Color(0xFF8797B0),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.65,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 11,
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

class _PartnerBadge extends StatelessWidget {
  const _PartnerBadge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: color.withValues(alpha: 0.32)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
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
  );
}

Color _partnerTypeColor(String type) => switch (type) {
  'Visitante' => const Color(0xFFB69CFF),
  'Proveedor' => const Color(0xFF4AE3B5),
  'Todos' => const Color(0xFF73B8FF),
  _ => const Color(0xFF42A5FF),
};

class _BusinessPartnerForm extends StatefulWidget {
  const _BusinessPartnerForm({this.record});
  final Map<String, dynamic>? record;

  @override
  State<_BusinessPartnerForm> createState() => _BusinessPartnerFormState();
}

class _BusinessPartnerFormState extends State<_BusinessPartnerForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.record?['name'] ?? ''}',
  );
  late final _description = TextEditingController(
    text: '${widget.record?['description'] ?? ''}',
  );
  late final _rfc = TextEditingController(
    text: '${widget.record?['rfc'] ?? ''}',
  );
  late final _category = TextEditingController(
    text: '${widget.record?['category'] ?? ''}',
  );
  late final _subject = TextEditingController(
    text: '${widget.record?['subject'] ?? ''}',
  );
  late final _employees = TextEditingController(
    text: '${widget.record?['employeeCount'] ?? 1}',
  );
  late String _type = '${widget.record?['type'] ?? 'Contratista'}';
  late String _status = widget.record?['status'] == 'Inactiva'
      ? 'Inactiva'
      : 'Activa';

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rfc.dispose();
    _category.dispose();
    _subject.dispose();
    _employees.dispose();
    super.dispose();
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool requiredField = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(color: _primaryTextColor(context), fontSize: 14),
      validator:
          validator ??
          (value) => requiredField && (value == null || value.trim().isEmpty)
              ? 'Completa este dato para continuar'
              : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: _secondaryTextColor(context),
          fontSize: 13,
        ),
        hintStyle: TextStyle(color: _secondaryTextColor(context), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF6AB8FF), size: 19),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: _logInsetColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _logBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF168BFF), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF7189)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFFF7189)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: _isLightTheme(context) ? Colors.white : null,
          gradient: _isLightTheme(context)
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172844), Color(0xFF0A1426)],
                ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0x663D9DFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 30,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF168BFF).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isEditing
                            ? Icons.edit_note_rounded
                            : Icons.person_add_alt_1_rounded,
                        color: const Color(0xFF73BEFF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Editar registro'
                                : 'Nuevo registro externo',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Completa la información del registro',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: _secondaryTextColor(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _logBorderColor(context)),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIPO DE REGISTRO',
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final type in const [
                            'Contratista',
                            'Proveedor',
                            'Visitante',
                          ])
                            _PartnerTypeOption(
                              type: type,
                              selected: _type == type,
                              onTap: () => setState(() => _type = type),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _field(
                        label: _type == 'Visitante'
                            ? 'Nombre de la persona'
                            : 'Nombre de la empresa',
                        hint: _type == 'Visitante'
                            ? 'Ej. Mariana López'
                            : 'Ej. Soluciones Industriales',
                        icon: _type == 'Visitante'
                            ? Icons.person_outline_rounded
                            : Icons.business_rounded,
                        controller: _name,
                      ),
                      if (_type == 'Visitante')
                        _field(
                          label: 'Asunto de la visita',
                          hint: 'Ej. Entrevista, entrega o reunión',
                          icon: Icons.event_note_rounded,
                          controller: _subject,
                        )
                      else ...[
                        _field(
                          label: 'Descripción',
                          hint: 'Actividad o servicios que proporciona',
                          icon: Icons.notes_rounded,
                          controller: _description,
                          maxLines: 3,
                          requiredField: false,
                        ),
                        _field(
                          label: 'RFC',
                          hint: 'Identificación fiscal',
                          icon: Icons.badge_outlined,
                          controller: _rfc,
                        ),
                        _field(
                          label: 'Categoría',
                          hint: 'Ej. Mantenimiento industrial',
                          icon: Icons.category_outlined,
                          controller: _category,
                        ),
                        _field(
                          label: 'Número de empleados',
                          hint: 'Cantidad de personas',
                          icon: Icons.groups_2_outlined,
                          controller: _employees,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            final count = int.tryParse(value ?? '');
                            return count == null || count < 1
                                ? 'Ingresa una cantidad válida (mínimo 1)'
                                : null;
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9, top: 1),
                          child: Text(
                            'ESTADO DEL REGISTRO',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final status in const ['Activa', 'Inactiva'])
                              _PartnerStatusOption(
                                status: status,
                                selected: _status == status,
                                onTap: () => setState(() => _status = status),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _secondaryTextColor(context),
                          side: BorderSide(
                            color: _isLightTheme(context)
                                ? const Color(0xFFDCE4EF)
                                : const Color(0x447F94B3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF168BFF), Color(0xFF725CFF)],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: FilledButton.icon(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            final result = <String, Object?>{
                              'name': _name.text.trim(),
                              'type': _type,
                              if (_type == 'Visitante')
                                'subject': _subject.text.trim()
                              else ...{
                                'description': _description.text.trim(),
                                'rfc': _rfc.text.trim(),
                                'category': _category.text.trim(),
                                'employeeCount': int.parse(
                                  _employees.text.trim(),
                                ),
                                'status': _status,
                              },
                            };
                            Navigator.pop(context, result);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            isEditing ? 'Guardar cambios' : 'Guardar',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
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
      ),
    );
  }
}

class _PartnerTypeOption extends StatelessWidget {
  const _PartnerTypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final String type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _partnerTypeColor(type);
    final icon = switch (type) {
      'Proveedor' => Icons.local_shipping_rounded,
      'Visitante' => Icons.person_rounded,
      _ => Icons.handyman_rounded,
    };
    return Material(
      color: selected ? color.withValues(alpha: 0.15) : _logInsetColor(context),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.75)
                  : _logBorderColor(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Text(
                type,
                style: TextStyle(
                  color: selected
                      ? _isLightTheme(context)
                            ? _primaryTextColor(context)
                            : Colors.white
                      : _secondaryTextColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerStatusOption extends StatelessWidget {
  const _PartnerStatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final String status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = status == 'Activa';
    final color = active ? const Color(0xFF4AE3B5) : const Color(0xFFFF8999);
    return Material(
      color: selected ? color.withValues(alpha: 0.13) : _logInsetColor(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.6)
                  : _logBorderColor(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 7),
              Text(
                status,
                style: TextStyle(
                  color: selected
                      ? _primaryTextColor(context)
                      : _secondaryTextColor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectedExternalStaffPage extends StatefulWidget {
  const ConnectedExternalStaffPage({
    required this.authService,
    required this.isAdmin,
    required this.canManage,
    this.user,
    this.appointment,
    super.key,
  });
  final AuthService authService;
  final bool isAdmin;
  final bool canManage;
  final AuthenticatedUser? user;
  final Map<String, dynamic>? appointment;

  @override
  State<ConnectedExternalStaffPage> createState() =>
      _ConnectedExternalStaffPageState();
}

class _ConnectedExternalStaffPageState
    extends State<ConnectedExternalStaffPage> {
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _partners = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int? _selectedPartnerId;

  @override
  void initState() {
    super.initState();
    final partnerId = widget.appointment?['businessPartnerId'];
    if (partnerId is num) _selectedPartnerId = partnerId.toInt();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.authService.getExternalStaff(),
        widget.authService.getBusinessPartners(),
      ]);
      if (mounted) {
        setState(() {
          _staff = results[0];
          _partners = results[1];
          if (_selectedPartnerId == null && widget.appointment != null) {
            final appointmentCompany = '${widget.appointment!['company'] ?? ''}'
                .trim()
                .toLowerCase();
            for (final partner in _partners) {
              if ('${partner['name'] ?? ''}'.trim().toLowerCase() ==
                  appointmentCompany) {
                final id = partner['id'];
                if (id is num) _selectedPartnerId = id.toInt();
                break;
              }
            }
          }
          _loading = false;
        });
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? staff, int? partnerId]) async {
    final partners = _partners
        .where(
          (p) =>
              p['type'] != 'Visitante' &&
              (p['status'] ?? 'Activa') != 'Inactiva',
        )
        .toList();
    if (partners.isEmpty) {
      _showMessage(
        context,
        'Registra primero un contratista o proveedor activo.',
        error: true,
      );
      return;
    }
    final preferredPartnerId =
        partnerId ?? staff?['businessPartnerId'] as int? ?? _selectedPartnerId;
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _ExternalStaffForm(
        partners: partners,
        record: staff,
        initialPartnerId: preferredPartnerId,
      ),
    );
    if (result == null) return;
    try {
      final updated = await widget.authService.saveExternalStaff(
        result,
        id: staff?['id'] as int?,
      );
      if (mounted) setState(() => _staff = updated);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> staff) async {
    if (!await _confirmAction(
      context,
      title: 'Eliminar personal',
      message: '¿Eliminar a ${staff['fullName']}?',
      confirmLabel: 'Eliminar',
    )) {
      return;
    }
    try {
      final records = await widget.authService.deleteExternalStaff(
        staff['id'] as int,
      );
      if (mounted) setState(() => _staff = records);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _sendQr(Map<String, dynamic> staff) async {
    final appointment = widget.appointment;
    final appointmentId = appointment?['id'];
    if (appointmentId is! num) {
      _showMessage(context, 'No se encontró la cita vinculada.', error: true);
      return;
    }
    final email = '${staff['email'] ?? ''}'.trim();
    if (email.isEmpty) return;
    if (!await _confirmAction(
      context,
      title: 'Enviar pase QR',
      message:
          'Se enviará el pase de ${staff['fullName']} a $email. ¿Continuar?',
      confirmLabel: 'Enviar QR',
    )) {
      return;
    }
    try {
      final staffId = staff['id'];
      if (staffId is! num) {
        throw const AuthApiException(
          'El identificador del empleado no es válido.',
        );
      }
      await widget.authService.sendAppointmentQr(
        appointmentId.toInt(),
        employeeId: staffId.toInt(),
      );
      if (mounted) {
        _showMessage(
          context,
          'El pase de ${staff['fullName']} se envió a $email.',
          title: 'QR enviado',
        );
      }
    } on AuthApiException catch (error) {
      if (!mounted) return;
      const legacyContractorError =
          'El envío por empleado solo está disponible para contratistas.';
      if (error.message == legacyContractorError) {
        _showMessage(
          context,
          'El servidor de QR aún usa la validación anterior. Es necesario desplegar la API actualizada para validar la empresa del empleado.',
          error: true,
        );
        return;
      }
      _showMessage(context, error.message, error: true);
    }
  }

  void _showQr(Map<String, dynamic> staff) {
    final appointment = widget.appointment;
    if (appointment == null) return;
    showDialog<void>(
      context: context,
      builder: (_) =>
          _AppointmentPassDialog(appointment: appointment, employee: staff),
    );
  }

  bool _isAppointmentEmployee(Map<String, dynamic> staff) {
    final appointment = widget.appointment;
    if (appointment == null) return false;
    final appointmentEmail = '${appointment['email'] ?? ''}'
        .trim()
        .toLowerCase();
    final staffEmail = '${staff['email'] ?? ''}'.trim().toLowerCase();
    if (appointmentEmail.isNotEmpty && staffEmail.isNotEmpty) {
      return appointmentEmail == staffEmail;
    }
    final appointmentName = '${appointment['visitor'] ?? ''}'
        .trim()
        .toLowerCase();
    final staffName = '${staff['fullName'] ?? ''}'.trim().toLowerCase();
    return appointmentName.isNotEmpty && appointmentName == staffName;
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final company = _selectedPartnerId == null
        ? null
        : _partners.cast<Map<String, dynamic>?>().firstWhere(
            (partner) => partner?['id'] == _selectedPartnerId,
            orElse: () => null,
          );
    final companyStaff = company == null
        ? <Map<String, dynamic>>[]
        : _staff.where((staff) => _belongsToCompany(staff, company)).toList();
    final records = companyStaff
        .where((staff) => _staffMatchesQuery(staff, query))
        .toList();
    final companies = _partners
        .where((partner) => partner['type'] != 'Visitante')
        .where((partner) {
          if (query.isEmpty) return true;
          final companyMatches =
              '${partner['name']} ${partner['type']} ${partner['category']} ${partner['rfc']}'
                  .toLowerCase()
                  .contains(query);
          return companyMatches ||
              _staff.any(
                (staff) =>
                    _belongsToCompany(staff, partner) &&
                    _staffMatchesQuery(staff, query),
              );
        })
        .toList();
    final totalPeople = _staff.length;
    return _ConnectedPage(
      title: 'Personal externo',
      subtitle: 'Empleados vinculados a contratistas y proveedores',
      user: widget.user,
      trailing: IconButton(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      child: _loading || _error != null
          ? _loadingOrError(
              context: context,
              loading: _loading,
              error: _error,
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  if (company == null) ...[
                    _ExternalStaffDirectoryToolbar(
                      companyCount: companies.length,
                      totalPeople: totalPeople,
                      onQueryChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                    const SizedBox(height: 14),
                    if (companies.isEmpty)
                      _StaffEmptyState(
                        icon: Icons.apartment_rounded,
                        title: query.isEmpty
                            ? 'Aún no hay empresas registradas'
                            : 'No encontramos empresas',
                        message: query.isEmpty
                            ? 'Registra un contratista o proveedor para organizar aquí su personal.'
                            : 'Prueba con otro nombre, categoría o contacto.',
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 320 ? 2 : 1;
                          final gap = 11.0;
                          final width =
                              (constraints.maxWidth - gap * (columns - 1)) /
                              columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final partner in companies)
                                SizedBox(
                                  width: width,
                                  child: _ExternalCompanyStaffCard(
                                    partner: partner,
                                    staffCount: _staff
                                        .where(
                                          (staff) =>
                                              _belongsToCompany(staff, partner),
                                        )
                                        .length,
                                    onTap: () => setState(() {
                                      _selectedPartnerId = partner['id'] as int;
                                      _query = '';
                                    }),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ] else ...[
                    _ExternalCompanyStaffDetail(
                      partner: company,
                      staffCount: companyStaff.length,
                      query: _query,
                      canManage: widget.canManage,
                      onQueryChanged: (value) =>
                          setState(() => _query = value.trim()),
                      onBack: () => setState(() {
                        _selectedPartnerId = null;
                        _query = '';
                      }),
                      onAdd: () => _edit(null, _selectedPartnerId),
                    ),
                    const SizedBox(height: 12),
                    if (records.isEmpty)
                      _StaffEmptyState(
                        icon: Icons.badge_outlined,
                        title: _query.isEmpty
                            ? 'Todavía no hay personal registrado'
                            : 'No encontramos personal',
                        message: _query.isEmpty
                            ? 'Agrega empleados para mantener su información vinculada a ${company['name']}.'
                            : 'Prueba con otro nombre, teléfono o correo.',
                        actionLabel: widget.canManage && _query.isEmpty
                            ? 'Registrar empleado'
                            : null,
                        onAction: widget.canManage && _query.isEmpty
                            ? () => _edit(null, _selectedPartnerId)
                            : null,
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 740 ? 2 : 1;
                          final gap = 11.0;
                          final width =
                              (constraints.maxWidth - gap * (columns - 1)) /
                              columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final staff in records)
                                SizedBox(
                                  width: width,
                                  child: _ExternalEmployeeCard(
                                    staff: staff,
                                    company: company,
                                    canManage: widget.canManage,
                                    onEdit: () => _edit(staff),
                                    onDelete: () => _delete(staff),
                                    showQr: _isAppointmentEmployee(staff),
                                    onShowQr: () => _showQr(staff),
                                    onSendQr: () => _sendQr(staff),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
    );
  }

  bool _belongsToCompany(
    Map<String, dynamic> staff,
    Map<String, dynamic> partner,
  ) {
    final partnerId = partner['id'];
    final staffPartnerId = staff['businessPartnerId'];
    if (partnerId != null && staffPartnerId != null) {
      return '$partnerId' == '$staffPartnerId';
    }
    return '${staff['companyName'] ?? ''}'.trim().toLowerCase() ==
        '${partner['name'] ?? ''}'.trim().toLowerCase();
  }

  bool _staffMatchesQuery(Map<String, dynamic> staff, String query) =>
      query.isEmpty ||
      '${staff['fullName']} ${staff['companyName']} ${staff['phone']} ${staff['email']} ${staff['relationshipType']}'
          .toLowerCase()
          .contains(query);
}

class _ExternalStaffDirectoryToolbar extends StatelessWidget {
  const _ExternalStaffDirectoryToolbar({
    required this.companyCount,
    required this.totalPeople,
    required this.onQueryChanged,
  });

  final int companyCount;
  final int totalPeople;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _isLightTheme(context) ? Colors.white : null,
      gradient: _isLightTheme(context)
          ? null
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172844), Color(0xFF0C172B)],
            ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x663B9DFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F168BFF),
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
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF168BFF), Color(0xFF26B8E8)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.groups_2_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$companyCount ${companyCount == 1 ? 'empresa' : 'empresas'}',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$totalPeople ${totalPeople == 1 ? 'persona registrada' : 'personas registradas'}',
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _staffSearchField(
          context: context,
          hint: 'Buscar empresa, empleado o contacto',
          onChanged: onQueryChanged,
        ),
      ],
    ),
  );
}

class _ExternalCompanyStaffCard extends StatelessWidget {
  const _ExternalCompanyStaffCard({
    required this.partner,
    required this.staffCount,
    required this.onTap,
  });

  final Map<String, dynamic> partner;
  final int staffCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    final type = '${partner['type'] ?? 'Contratista'}';
    final color = _partnerTypeColor(type);
    final declaredCount = partner['employeeCount'];
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isLight ? Colors.white : null,
            gradient: isLight
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF172844), Color(0xFF0A1426)],
                  ),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: color.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 7),
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
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.38)),
                    ),
                    child: Icon(
                      type == 'Proveedor'
                          ? Icons.local_shipping_rounded
                          : Icons.handyman_rounded,
                      color: color,
                      size: 21,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFF2F7FD)
                          : const Color(0xFF0A1426),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x333D9DFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$staffCount',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF1769AA)
                                : const Color(0xFF58ACFF),
                            fontSize: 17,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          staffCount == 1 ? 'registrado' : 'registrados',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 9,
                          ),
                        ),
                        if (declaredCount != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$declaredCount contemplados',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                '${partner['name'] ?? 'Empresa sin nombre'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _PartnerBadge(label: type, color: color),
              if ('${partner['category'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${partner['category']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 13),
              Divider(height: 1, color: _logBorderColor(context)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Ver empleados',
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF1769AA)
                          : const Color(0xFF7CCFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: color, size: 19),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExternalCompanyStaffDetail extends StatelessWidget {
  const _ExternalCompanyStaffDetail({
    required this.partner,
    required this.staffCount,
    required this.query,
    required this.canManage,
    required this.onQueryChanged,
    required this.onBack,
    required this.onAdd,
  });

  final Map<String, dynamic> partner;
  final int staffCount;
  final String query;
  final bool canManage;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    final type = '${partner['type'] ?? 'Contratista'}';
    final color = _partnerTypeColor(type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF172844), Color(0xFF0C172B)],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x663B9DFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  type == 'Proveedor'
                      ? Icons.local_shipping_rounded
                      : Icons.handyman_rounded,
                  color: color,
                ),
              ),
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${partner['name'] ?? 'Empresa'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _PartnerBadge(label: type, color: color),
                  ],
                ),
              ),
              _StaffCountBadge(count: staffCount),
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Empresas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _secondaryTextColor(context),
                  side: BorderSide(
                    color: isLight
                        ? const Color(0xFFDCE4EF)
                        : const Color(0x447F94B3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (canManage)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                    label: const Text('Registrar empleado'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 13),
          _staffSearchField(
            context: context,
            hint: 'Buscar por nombre, teléfono o correo',
            onChanged: onQueryChanged,
          ),
        ],
      ),
    );
  }
}

class _StaffCountBadge extends StatelessWidget {
  const _StaffCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: _isLightTheme(context)
          ? const Color(0xFFF3F6FB)
          : const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x333D9DFF)),
    ),
    child: Text(
      '$count ${count == 1 ? 'empleado' : 'empleados'}',
      style: TextStyle(
        color: _isLightTheme(context)
            ? const Color(0xFF1769AA)
            : const Color(0xFF68B7FF),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ExternalEmployeeCard extends StatelessWidget {
  const _ExternalEmployeeCard({
    required this.staff,
    required this.company,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
    required this.showQr,
    required this.onShowQr,
    required this.onSendQr,
  });

  final Map<String, dynamic> staff;
  final Map<String, dynamic> company;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showQr;
  final VoidCallback onShowQr;
  final VoidCallback onSendQr;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    final name = '${staff['fullName'] ?? 'Sin nombre'}';
    final phone = '${staff['phone'] ?? ''}'.trim();
    final email = '${staff['email'] ?? ''}'.trim();
    final relation =
        '${staff['relationshipType'] ?? company['type'] ?? 'Externo'}';
    final color = _partnerTypeColor(relation);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF17243D), Color(0xFF0C1628)],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.31)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  gradient: isLight
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF183D62), Color(0xFF10243D)],
                        ),
                  color: isLight ? const Color(0xFFE9F2FC) : null,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x554AA8FF)),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF73BEFF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PartnerDetailTile(
            label: 'Empresa',
            value: '${company['name'] ?? staff['companyName'] ?? '—'}',
            icon: Icons.apartment_rounded,
          ),
          const SizedBox(height: 8),
          _PartnerDetailTile(
            label: 'Tipo de vínculo',
            value: relation,
            icon: Icons.handshake_outlined,
          ),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PartnerDetailTile(
              label: 'Teléfono',
              value: phone,
              icon: Icons.phone_outlined,
            ),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _PartnerDetailTile(
              label: 'Correo electrónico',
              value: email,
              icon: Icons.mail_outline_rounded,
            ),
          ],
          if (phone.isEmpty && email.isEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'Sin datos de contacto',
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 11,
              ),
            ),
          ],
          if (canManage || showQr) ...[
            const SizedBox(height: 13),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
            const SizedBox(height: 12),
            Column(
              children: [
                if (showQr)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: onShowQr,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF83C7FF),
                              side: const BorderSide(color: Color(0x554AA8FF)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                            label: const Text(
                              'Ver QR',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      if (canManage && email.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF087FFF),
                                    Color(0xFF04BCEB),
                                  ],
                                ),
                              ),
                              child: FilledButton.icon(
                                onPressed: onSendQr,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text(
                                  'Enviar QR',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                if (canManage && showQr) const SizedBox(height: 8),
                if (canManage)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF087FFF), Color(0xFF04BCEB)],
                              ),
                            ),
                            child: FilledButton.icon(
                              onPressed: onEdit,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 17),
                              label: const Text(
                                'Editar',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: onDelete,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF7189),
                              side: const BorderSide(color: Color(0x66FF7189)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Eliminar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StaffEmptyState extends StatelessWidget {
  const _StaffEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
    decoration: BoxDecoration(
      color: _isLightTheme(context)
          ? Colors.white
          : const Color(0xFF101D32).withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x223D9DFF)),
    ),
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF168BFF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(19),
          ),
          child: Icon(icon, color: const Color(0xFF69B8FF), size: 28),
        ),
        const SizedBox(height: 13),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _primaryTextColor(context),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9DACC2),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

Widget _staffSearchField({
  required BuildContext context,
  required String hint,
  required ValueChanged<String> onChanged,
}) => TextField(
  onChanged: onChanged,
  style: TextStyle(color: _primaryTextColor(context), fontSize: 13),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF8290A8), fontSize: 12),
    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF55AAFF)),
    prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
    filled: true,
    fillColor: _isLightTheme(context)
        ? const Color(0xFFF2F7FD)
        : const Color(0xFF091426),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x243D9DFF)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF168BFF)),
    ),
  ),
);

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: TextStyle(
          color: _isLightTheme(context)
              ? const Color(0xFF167C92)
              : const Color(0xFF74C8D1),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(child: Divider(height: 1, color: Color(0x223D9DFF))),
    ],
  );
}

class _ExternalStaffForm extends StatefulWidget {
  const _ExternalStaffForm({
    required this.partners,
    this.record,
    this.initialPartnerId,
  });
  final List<Map<String, dynamic>> partners;
  final Map<String, dynamic>? record;
  final int? initialPartnerId;
  @override
  State<_ExternalStaffForm> createState() => _ExternalStaffFormState();
}

class _ExternalStaffFormState extends State<_ExternalStaffForm> {
  final _formKey = GlobalKey<FormState>();
  late int _partnerId =
      widget.record?['businessPartnerId'] as int? ??
      widget.initialPartnerId ??
      widget.partners.first['id'] as int;
  late final _name = TextEditingController(
    text: '${widget.record?['fullName'] ?? ''}',
  );
  late final _phone = TextEditingController(
    text: '${widget.record?['phone'] ?? ''}',
  );
  late final _email = TextEditingController(
    text: '${widget.record?['email'] ?? ''}',
  );
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _selectedPartner => widget.partners.firstWhere(
    (partner) => partner['id'] == _partnerId,
    orElse: () => widget.partners.first,
  );

  Future<void> _selectPartner() async {
    final partnerId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _logDialogColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleccionar empresa',
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (final partner in widget.partners)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(
                    partner['type'] == 'Proveedor'
                        ? Icons.local_shipping_rounded
                        : Icons.handyman_rounded,
                    color: _partnerTypeColor('${partner['type']}'),
                  ),
                  title: Text(
                    '${partner['name']}',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${partner['type']} · ${partner['category'] ?? 'Sin categoría'}',
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 11,
                    ),
                  ),
                  trailing: partner['id'] == _partnerId
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF4AE3B5),
                        )
                      : null,
                  onTap: () => Navigator.pop(context, partner['id'] as int),
                ),
            ],
          ),
        ),
      ),
    );
    if (partnerId != null) setState(() => _partnerId = partnerId);
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: _primaryTextColor(context), fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: _secondaryTextColor(context),
          fontSize: 12,
        ),
        hintStyle: TextStyle(color: _secondaryTextColor(context), fontSize: 11),
        prefixIcon: Icon(icon, color: const Color(0xFF6AB8FF), size: 18),
        filled: true,
        fillColor: _logInsetColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: _logBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF168BFF), width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFFF7189)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFFF7189)),
        ),
      ),
    ),
  );

  Widget _contactFields() => LayoutBuilder(
    builder: (context, constraints) {
      final phoneField = _field(
        label: 'Teléfono',
        hint: 'Número de contacto',
        icon: Icons.phone_outlined,
        controller: _phone,
        keyboardType: TextInputType.phone,
      );
      final emailField = _field(
        label: 'Correo electrónico',
        hint: 'correo@empresa.com',
        icon: Icons.mail_outline_rounded,
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          final email = value?.trim() ?? '';
          if (email.isNotEmpty &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
            return 'Correo no válido';
          }
          return null;
        },
      );
      if (constraints.maxWidth < 420) {
        return Column(children: [phoneField, emailField]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: phoneField),
          const SizedBox(width: 9),
          Expanded(child: emailField),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: _isLightTheme(context) ? Colors.white : null,
          gradient: _isLightTheme(context)
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172844), Color(0xFF0A1426)],
                ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x663D9DFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 10, 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF168BFF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.groups_2_rounded,
                        color: Color(0xFF73BEFF),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Editar personal externo'
                                : 'Registrar personal externo',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Datos de contacto y empresa vinculada',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: _secondaryTextColor(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _logBorderColor(context)),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FormSectionLabel(label: 'DATOS BÁSICOS'),
                      const SizedBox(height: 12),
                      _field(
                        label: 'Nombre completo',
                        hint: 'Nombre y apellidos',
                        icon: Icons.person_outline_rounded,
                        controller: _name,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Escribe el nombre completo'
                            : null,
                      ),
                      _contactFields(),
                      const SizedBox(height: 4),
                      const _FormSectionLabel(label: 'EMPRESA VINCULADA'),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _selectPartner,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _logInsetColor(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x334AA8FF)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedPartner['type'] == 'Proveedor'
                                    ? Icons.local_shipping_rounded
                                    : Icons.handyman_rounded,
                                color: _partnerTypeColor(
                                  '${_selectedPartner['type']}',
                                ),
                                size: 19,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Empresa contratista o proveedora',
                                      style: TextStyle(
                                        color: _secondaryTextColor(context),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_selectedPartner['name']}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _primaryTextColor(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.unfold_more_rounded,
                                color: _secondaryTextColor(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryTextColor(context),
                          side: BorderSide(color: _logBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: FilledButton.icon(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            Navigator.pop(context, <String, Object?>{
                              'businessPartnerId': _partnerId,
                              'fullName': _name.text.trim(),
                              'phone': _phone.text.trim(),
                              'email': _email.text.trim(),
                            });
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            isEditing
                                ? 'Guardar cambios'
                                : 'Registrar personal',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
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
      ),
    );
  }
}

class ConnectedAppointmentsPage extends StatefulWidget {
  const ConnectedAppointmentsPage({
    required this.authService,
    required this.isAdmin,
    required this.canManage,
    required this.onSendPass,
    this.user,
    super.key,
  });
  final AuthService authService;
  final bool isAdmin;
  final bool canManage;
  final ValueChanged<Map<String, dynamic>> onSendPass;
  final AuthenticatedUser? user;
  @override
  State<ConnectedAppointmentsPage> createState() =>
      _ConnectedAppointmentsPageState();
}

class _ConnectedAppointmentsPageState extends State<ConnectedAppointmentsPage> {
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _showAll = true;
  DateTime _selectedDate = DateTime.now();
  Timer? _attendanceClock;
  late final _RealtimeRefreshCoordinator _realtime;
  bool _loadInProgress = false;
  bool _refreshQueued = false;

  Future<void> _showAppointmentsForDate(DateTime date) async {
    final dayAppointments =
        _appointments
            .where((item) => item['date'] == _dateString(date))
            .toList()
          ..sort(
            (a, b) => '${a['time'] ?? ''}'.compareTo('${b['time'] ?? ''}'),
          );
    setState(() {
      _selectedDate = date;
      _showAll = false;
    });
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _AppointmentsDayDialog(date: date, appointments: dayAppointments),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
    _attendanceClock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _realtime = _RealtimeRefreshCoordinator(
      widget.authService,
      () => _load(silent: true),
    )..start();
  }

  @override
  void dispose() {
    _attendanceClock?.cancel();
    _realtime.dispose();
    super.dispose();
  }

  bool get _isHost =>
      !widget.isAdmin &&
      widget.user?.sectionAccess.contains('anfitriones') == true &&
      widget.user?.canAccessReception != true;

  String? _attendanceStatus(Map<String, dynamic> appointment) {
    if (appointment['status'] != 'Pendiente') return null;
    final date = appointment['date'];
    final time = appointment['time'];
    if (date is! String || time is! String) return null;
    final today = _dateString(DateTime.now());
    if (date.compareTo(today) < 0) return 'No se presentó';
    if (date.compareTo(today) > 0) return null;
    final scheduledAt = DateTime.tryParse('${date}T$time:00');
    if (scheduledAt == null || scheduledAt.isAfter(DateTime.now())) return null;
    return 'Tardía';
  }

  Future<void> _load({bool silent = false}) async {
    if (_loadInProgress) {
      _refreshQueued = true;
      return;
    }
    _loadInProgress = true;
    var showLoader = !silent;
    do {
      _refreshQueued = false;
      if (mounted && showLoader) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
      try {
        final appointments = await widget.authService.getAppointments();
        if (mounted) {
          setState(() {
            _appointments = appointments;
            _loading = false;
            _error = null;
          });
        }
      } on AuthApiException catch (error) {
        if (mounted) {
          setState(() {
            _error = error.message;
            _loading = false;
          });
        }
      }
      showLoader = false;
    } while (_refreshQueued && mounted);
    _loadInProgress = false;
  }

  Future<void> _edit({
    Map<String, dynamic>? appointment,
    DateTime? initialDate,
    bool reschedule = false,
  }) async {
    late final List<Map<String, dynamic>> appointmentPartners;
    late final List<Map<String, dynamic>> visitors;
    late final List<Map<String, dynamic>> externalStaff;
    late final List<Map<String, dynamic>> hosts;
    try {
      final options = await Future.wait<Object>([
        widget.authService.getAppointmentBusinessPartners(),
        widget.authService.getHostVisitors(forAppointment: true),
        widget.authService.getExternalStaff(),
        if (!_isHost) widget.authService.getDepartmentHosts(),
      ]);
      appointmentPartners = options[0] as List<Map<String, dynamic>>;
      visitors = options[1] as List<Map<String, dynamic>>;
      externalStaff = options[2] as List<Map<String, dynamic>>;
      hosts = _isHost
          ? const []
          : (options[3] as List<DepartmentHost>)
                .map(
                  (host) => {
                    'id': host.id,
                    'login': host.login,
                    'name': host.name,
                    'departmentId': host.departmentId,
                    'email': host.email,
                  },
                )
                .toList();
    } on AuthApiException catch (error) {
      if (mounted) {
        _showMessage(
          context,
          'No se pudieron cargar tus registros para la cita: ${error.message}',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    if (appointmentPartners.isEmpty && visitors.isEmpty) {
      _showMessage(
        context,
        'Primero registra una empresa o visitante para poder agendar la cita.',
        error: true,
      );
      return;
    }
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _AppointmentForm(
        authService: widget.authService,
        partners: appointmentPartners,
        visitors: visitors,
        externalStaff: externalStaff,
        hosts: hosts,
        user: widget.user,
        isAdmin: widget.isAdmin,
        isHost: _isHost,
        record: appointment,
        initialDate: initialDate ?? _selectedDate,
        reschedule: reschedule,
      ),
    );
    if (result == null) return;
    try {
      final records = await widget.authService.saveAppointment(
        result,
        id: appointment?['id'] as int?,
      );
      if (mounted) setState(() => _appointments = records);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _cancel(Map<String, dynamic> appointment) async {
    if (!await _confirmAction(
      context,
      title: 'Cancelar cita',
      message: '¿Cancelar la cita de ${appointment['visitor']}?',
      confirmLabel: 'Cancelar cita',
    )) {
      return;
    }
    try {
      final records = await widget.authService.updateAppointmentStatus(
        appointment['id'] as int,
        'Cancelada',
      );
      if (mounted) setState(() => _appointments = records);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> appointment) async {
    if (!widget.isAdmin && appointment['status'] != 'Cancelada') {
      _showMessage(
        context,
        'Primero cancela la cita para poder eliminarla.',
        error: true,
      );
      return;
    }
    if (!await _confirmAction(
      context,
      title: 'Eliminar cita',
      message:
          'Esta acción elimina la cita del listado y conserva su historial.',
      confirmLabel: 'Eliminar',
    )) {
      return;
    }
    try {
      final records = await widget.authService.deleteAppointment(
        appointment['id'] as int,
      );
      if (mounted) setState(() => _appointments = records);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _dateString(_selectedDate);
    final appointments = _appointments.where((item) {
      final matchText =
          '${item['visitor']} ${item['company']} ${item['host']} ${item['referenceCode']}'
              .toLowerCase()
              .contains(_query.toLowerCase());
      return matchText && (_showAll || item['date'] == selectedDate);
    }).toList();
    final activeCount = _appointments
        .where(
          (item) =>
              item['status'] != 'Cancelada' && item['status'] != 'Retirado',
        )
        .length;
    return _ConnectedPage(
      title: 'Agenda de citas',
      subtitle: 'Citas registradas en el sistema',
      user: widget.user,
      trailing: IconButton(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      child: _loading || _error != null
          ? _loadingOrError(
              context: context,
              loading: _loading,
              error: _error,
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  _AppointmentsToolbar(
                    activeCount: activeCount,
                    resultCount: appointments.length,
                    selectedDate: _selectedDate,
                    showAll: _showAll,
                    canManage: widget.canManage,
                    onCreate: () => _edit(),
                    onShowAll: () => setState(() => _showAll = true),
                    onShowDay: () => setState(() => _showAll = false),
                    onDateChanged: (date) =>
                        setState(() => _selectedDate = date),
                    onQueryChanged: (value) =>
                        setState(() => _query = value.trim()),
                  ),
                  const SizedBox(height: 12),
                  _AppointmentsCalendar(
                    appointments: _appointments,
                    selectedDate: _selectedDate,
                    onSelectDate: _showAppointmentsForDate,
                  ),
                  const SizedBox(height: 12),
                  if (appointments.isEmpty)
                    _AppointmentEmptyState(
                      showAll: _showAll,
                      selectedDate: _selectedDate,
                      query: _query,
                    )
                  else
                    for (final item in appointments) ...[
                      _AppointmentRecordCard(
                        item: item,
                        displayStatus:
                            _attendanceStatus(item) ??
                            '${item['status'] ?? 'Pendiente'}',
                        canReschedule:
                            _isHost &&
                            _attendanceStatus(item) == 'No se presentó',
                        canManage: widget.canManage,
                        isAdmin: widget.isAdmin,
                        onEdit: () => _edit(appointment: item),
                        onReschedule: () => _edit(
                          appointment: item,
                          initialDate: DateTime.now().add(
                            const Duration(days: 1),
                          ),
                          reschedule: true,
                        ),
                        onCancel: () => _cancel(item),
                        onDelete: () => _delete(item),
                        onSendQr: () => widget.onSendPass(item),
                        onShowCode: () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              _AppointmentPassDialog(appointment: item),
                        ),
                      ),
                      const SizedBox(height: 9),
                    ],
                ],
              ),
            ),
    );
  }
}

class _AppointmentsCalendar extends StatefulWidget {
  const _AppointmentsCalendar({
    required this.appointments,
    required this.selectedDate,
    required this.onSelectDate,
  });

  final List<Map<String, dynamic>> appointments;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  State<_AppointmentsCalendar> createState() => _AppointmentsCalendarState();
}

class _AppointmentsCalendarState extends State<_AppointmentsCalendar> {
  late DateTime _visibleMonth = DateTime(
    widget.selectedDate.year,
    widget.selectedDate.month,
  );

  static const _months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  static const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  void didUpdateWidget(covariant _AppointmentsCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedDate = widget.selectedDate;
    if (oldWidget.selectedDate.year != selectedDate.year ||
        oldWidget.selectedDate.month != selectedDate.month) {
      _visibleMonth = DateTime(selectedDate.year, selectedDate.month);
    }
  }

  void _moveMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    final firstWeekday = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
    ).weekday;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final appointmentCounts = <String, int>{};
    for (final appointment in widget.appointments) {
      final date = appointment['date'];
      if (date is String &&
          date.startsWith(
            '${_visibleMonth.year.toString().padLeft(4, '0')}-'
            '${_visibleMonth.month.toString().padLeft(2, '0')}-',
          )) {
        appointmentCounts.update(date, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF172844), Color(0xFF0C172B)],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x663B9DFF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Color(0xFF68B7FF),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _CalendarMonthButton(
                tooltip: 'Mes anterior',
                icon: Icons.chevron_left_rounded,
                onPressed: () => _moveMonth(-1),
              ),
              const SizedBox(width: 5),
              _CalendarMonthButton(
                tooltip: 'Mes siguiente',
                icon: Icons.chevron_right_rounded,
                onPressed: () => _moveMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var index = 0; index < _weekdays.length; index++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdays[index],
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ((firstWeekday - 1 + daysInMonth + 6) ~/ 7) * 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 3,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final day = index - firstWeekday + 2;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(
                _visibleMonth.year,
                _visibleMonth.month,
                day,
              );
              final dateKey = _dateString(date);
              final count = appointmentCounts[dateKey] ?? 0;
              final selected = dateKey == _dateString(widget.selectedDate);
              final today = dateKey == _dateString(DateTime.now());
              return Semantics(
                button: true,
                label:
                    '$day de ${_months[_visibleMonth.month - 1]}'
                    '${count > 0 ? ', $count ${count == 1 ? 'cita' : 'citas'}' : ''}',
                child: Material(
                  color: selected
                      ? const Color(0xFF168BFF)
                      : count > 0
                      ? const Color(0x2226B8E8)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    key: ValueKey('appointment-calendar-day-$dateKey'),
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => widget.onSelectDate(date),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: today && !selected
                              ? const Color(0xFF68B7FF)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : count > 0
                                  ? const Color(0xFFEAF6FF)
                                  : _secondaryTextColor(context),
                              fontSize: 11,
                              fontWeight: count > 0 || selected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? selected
                                        ? Colors.white
                                        : const Color(0xFF48D5E8)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(Icons.circle, size: 7, color: Color(0xFF48D5E8)),
              SizedBox(width: 6),
              Text(
                'Días con citas',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalendarMonthButton extends StatelessWidget {
  const _CalendarMonthButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    onPressed: onPressed,
    icon: Icon(icon, color: const Color(0xFF9FCBFF), size: 22),
  );
}

class _AppointmentsDayDialog extends StatelessWidget {
  const _AppointmentsDayDialog({
    required this.date,
    required this.appointments,
  });

  final DateTime date;
  final List<Map<String, dynamic>> appointments;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    return Dialog(
      backgroundColor: _panelColor(context),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isLight
              ? const Color(0xFFD8E4F2)
              : const Color(0xFF3B9DFF).withValues(alpha: 0.45),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(18),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF168BFF), Color(0xFF26B8E8)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayDate(_dateString(date)),
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${appointments.length} ${appointments.length == 1 ? 'cita programada' : 'citas programadas'}',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (appointments.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _logInsetColor(context),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _logBorderColor(context)),
                  ),
                  child: Text(
                    'No hay citas programadas para este día.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: appointments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final appointment = appointments[index];
                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: isLight ? const Color(0xFFF3F6FB) : null,
                          gradient: isLight
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF172844),
                                    Color(0xFF0C172B),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _logBorderColor(context)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF168BFF)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                '${appointment['time'] ?? '--:--'}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isLightTheme(context)
                                      ? const Color(0xFF1769AA)
                                      : const Color(0xFF8ACBFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${appointment['visitor'] ?? 'Visitante'}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _primaryTextColor(context),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${appointment['company'] ?? 'Sin empresa'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _secondaryTextColor(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Anfitrión: ${appointment['host'] ?? 'Sin anfitrión'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _secondaryTextColor(context),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            _AppointmentStatusBadge(
                              label: '${appointment['status'] ?? 'Pendiente'}',
                              color: appointment['status'] == 'Cancelada'
                                  ? const Color(0xFFFF7189)
                                  : const Color(0xFFFFC56E),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryTextColor(context),
                    side: BorderSide(color: _logBorderColor(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentsToolbar extends StatelessWidget {
  const _AppointmentsToolbar({
    required this.activeCount,
    required this.resultCount,
    required this.selectedDate,
    required this.showAll,
    required this.canManage,
    required this.onCreate,
    required this.onShowAll,
    required this.onShowDay,
    required this.onDateChanged,
    required this.onQueryChanged,
  });

  final int activeCount;
  final int resultCount;
  final DateTime selectedDate;
  final bool showAll;
  final bool canManage;
  final VoidCallback onCreate;
  final VoidCallback onShowAll;
  final VoidCallback onShowDay;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onQueryChanged;

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Selecciona el día de las citas',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );
    if (date != null) onDateChanged(date);
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _isLightTheme(context) ? Colors.white : null,
      gradient: _isLightTheme(context)
          ? null
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172844), Color(0xFF0C172B)],
            ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x663B9DFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F168BFF),
          blurRadius: 22,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF168BFF), Color(0xFF26B8E8)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$activeCount citas activas',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$resultCount ${resultCount == 1 ? 'resultado' : 'resultados'} · ${showAll ? 'todas las fechas' : _displayDate(_dateString(selectedDate))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            if (canManage)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33168BFF),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Nueva'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _AgendaModeChip(
                label: 'Todas',
                icon: Icons.view_agenda_rounded,
                selected: showAll,
                onTap: onShowAll,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AgendaModeChip(
                label: 'Del día',
                icon: Icons.today_rounded,
                selected: !showAll,
                onTap: onShowDay,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Material(
          color: _isLightTheme(context)
              ? const Color(0xFFF3F6FB)
              : const Color(0xFF0A1426),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _pickDate(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _logBorderColor(context)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_outlined,
                    color: Color(0xFF68B7FF),
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FECHA SELECCIONADA',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 8,
                            letterSpacing: 0.7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _displayDate(_dateString(selectedDate)),
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_calendar_rounded,
                    color: _secondaryTextColor(context),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: onQueryChanged,
          style: TextStyle(color: _primaryTextColor(context), fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar visitante, empresa, anfitrión o folio',
            hintStyle: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 11,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF55AAFF),
            ),
            filled: true,
            fillColor: _isLightTheme(context)
                ? const Color(0xFFF3F6FB)
                : const Color(0xFF091426),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 13,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0x243D9DFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF168BFF)),
            ),
          ),
        ),
      ],
    ),
  );
}

class _AgendaModeChip extends StatelessWidget {
  const _AgendaModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? const Color(0xFF168BFF).withValues(alpha: 0.17)
        : _isLightTheme(context)
        ? const Color(0xFFF3F6FB)
        : const Color(0xFF0A1426),
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? const Color(0xFF168BFF).withValues(alpha: 0.65)
                : _isLightTheme(context)
                ? const Color(0xFFDCE4EF)
                : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected
                  ? const Color(0xFF79C6FF)
                  : _secondaryTextColor(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? _primaryTextColor(context)
                    : _secondaryTextColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AppointmentEmptyState extends StatelessWidget {
  const _AppointmentEmptyState({
    required this.showAll,
    required this.selectedDate,
    required this.query,
  });

  final bool showAll;
  final DateTime selectedDate;
  final String query;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
    decoration: BoxDecoration(
      color: const Color(0xFF101D32).withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x223D9DFF)),
    ),
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF168BFF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(19),
          ),
          child: const Icon(
            Icons.event_busy_rounded,
            color: Color(0xFF69B8FF),
            size: 28,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          query.isNotEmpty
              ? 'No encontramos citas'
              : showAll
              ? 'Aún no hay citas registradas'
              : 'No hay citas para este día',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          query.isNotEmpty
              ? 'Prueba con otro visitante, empresa, anfitrión o folio.'
              : showAll
              ? 'Las nuevas citas aparecerán en tu agenda.'
              : 'No hay visitas programadas para ${_displayDate(_dateString(selectedDate))}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF9DACC2),
            fontSize: 12,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}

class _AppointmentForm extends StatefulWidget {
  const _AppointmentForm({
    required this.authService,
    required this.partners,
    required this.visitors,
    required this.externalStaff,
    required this.hosts,
    required this.user,
    required this.isAdmin,
    required this.isHost,
    required this.initialDate,
    this.reschedule = false,
    this.record,
  });
  final AuthService authService;
  final List<Map<String, dynamic>> partners;
  final List<Map<String, dynamic>> visitors;
  final List<Map<String, dynamic>> externalStaff;
  final List<Map<String, dynamic>> hosts;
  final AuthenticatedUser? user;
  final bool isAdmin;
  final bool isHost;
  final Map<String, dynamic>? record;
  final DateTime initialDate;
  final bool reschedule;

  static const personalVisitorsPartnerId = -1;
  static const otherVisitorSelection = '__otro__';

  @override
  State<_AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<_AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final List<Map<String, dynamic>> _savedVisitors = [...widget.visitors];
  late int _partnerId = _initialPartnerId;
  String _visitorSelection = '';
  String _selectedHostLogin = '';
  late final _visitor = TextEditingController(
    text: '${widget.record?['visitor'] ?? ''}',
  );
  late final _email = TextEditingController(
    text: '${widget.record?['email'] ?? ''}',
  );
  late DateTime _date = widget.reschedule
      ? widget.initialDate
      : DateTime.tryParse('${widget.record?['date'] ?? ''}') ??
            widget.initialDate;
  late String _time = '${widget.record?['time'] ?? '09:00'}';

  @override
  void initState() {
    super.initState();
    final visitorRecordId = widget.record?['visitorRecordId'];
    if (visitorRecordId is num && _canUsePersonalVisitors) {
      _visitorSelection = visitorRecordId.toInt().toString();
    } else if (widget.record != null) {
      final staff = _companyVisitors.where(
        (person) =>
            person['fullName'] == widget.record?['visitor'] &&
            person['businessPartnerId'] == _partnerId,
      );
      _visitorSelection = staff.isNotEmpty
          ? '${staff.first['id']}'
          : _AppointmentForm.otherVisitorSelection;
    }
    if (widget.isHost) {
      _selectedHostLogin = widget.user?.login ?? '';
    } else if (widget.record != null) {
      _selectedHostLogin =
          widget.hosts
              .where((host) => host['name'] == widget.record?['host'])
              .map((host) => '${host['login']}')
              .firstOrNull ??
          '';
    }
  }

  int get _initialPartnerId {
    final visitorRecordId = widget.record?['visitorRecordId'];
    if (visitorRecordId is num && _canUsePersonalVisitors) {
      return _AppointmentForm.personalVisitorsPartnerId;
    }
    final recordPartnerId = widget.record?['businessPartnerId'];
    if (recordPartnerId is num) return recordPartnerId.toInt();
    if (_companyPartners.isNotEmpty) {
      return (_companyPartners.first['id'] as num).toInt();
    }
    return _canUsePersonalVisitors
        ? _AppointmentForm.personalVisitorsPartnerId
        : 0;
  }

  bool get _isPersonalVisitorsPartner =>
      _partnerId == _AppointmentForm.personalVisitorsPartnerId;

  bool get _isOtherVisitor =>
      _visitorSelection == _AppointmentForm.otherVisitorSelection;

  bool get _hasSelectedVisitor =>
      _visitorSelection.isNotEmpty &&
      (_isOtherVisitor
          ? _visitor.text.trim().isNotEmpty
          : _selectedVisitor != null);

  bool get _canUsePersonalVisitors => widget.isAdmin || widget.isHost;

  List<Map<String, dynamic>> get _companyPartners => widget.partners
      .where((partner) => partner['type'] != 'Visitante')
      .toList();

  List<Map<String, dynamic>> get _availablePartners {
    final partners = _companyPartners
        .where(
          (partner) =>
              partner['status'] != 'Inactiva' ||
              partner['id'] == widget.record?['businessPartnerId'],
        )
        .toList();
    if (_canUsePersonalVisitors) {
      partners.insert(0, _personalVisitorsPartner);
    }
    return partners;
  }

  Map<String, dynamic> get _personalVisitorsPartner => {
    'id': _AppointmentForm.personalVisitorsPartnerId,
    'name': 'Visitante registrado',
    'type': 'Visitante',
  };

  Map<String, dynamic> get _selectedPartner => _isPersonalVisitorsPartner
      ? _personalVisitorsPartner
      : widget.partners.firstWhere(
          (partner) => partner['id'] == _partnerId,
          orElse: () => {
            'id': _partnerId,
            'name': 'Empresa no disponible',
            'type': 'Visitante',
          },
        );

  List<Map<String, dynamic>> get _companyVisitors =>
      widget.externalStaff
          .where((person) => person['businessPartnerId'] == _partnerId)
          .toList()
        ..sort(
          (first, second) =>
              '${first['fullName']}'.compareTo('${second['fullName']}'),
        );

  List<Map<String, dynamic>> get _personalVisitorOptions => _savedVisitors
    ..sort(
      (first, second) =>
          '${first['fullName']}'.compareTo('${second['fullName']}'),
    );

  List<Map<String, dynamic>> get _visitorOptions =>
      _isPersonalVisitorsPartner ? _personalVisitorOptions : _companyVisitors;

  Map<String, dynamic>? get _selectedVisitor {
    if (_visitorSelection.isEmpty || _isOtherVisitor) return null;
    final options = _visitorOptions.where(
      (visitor) => '${visitor['id']}' == _visitorSelection,
    );
    return options.isEmpty ? null : options.first;
  }

  List<Map<String, dynamic>> get _appointmentHosts {
    if (!widget.isHost) return widget.hosts;
    final user = widget.user;
    if (user == null) return const [];
    return [
      {
        'id': 0,
        'login': user.login,
        'name': user.name?.trim().isNotEmpty == true
            ? user.name!.trim()
            : user.login,
      },
    ];
  }

  Map<String, dynamic>? get _selectedHost {
    final matches = _appointmentHosts.where(
      (host) => host['login'] == _selectedHostLogin,
    );
    return matches.isEmpty ? null : matches.first;
  }

  @override
  void dispose() {
    _visitor.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _selectPartner() async {
    final id = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _logDialogColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                Text(
                  'Empresa o visitante',
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final partner in _availablePartners)
                        _AppointmentPartnerOption(
                          partner: partner,
                          selected: partner['id'] == _partnerId,
                          onTap: () =>
                              Navigator.pop(context, partner['id'] as int),
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
    if (id != null && id != _partnerId) {
      setState(() {
        _partnerId = id;
        _visitorSelection = '';
        _visitor.clear();
        _email.clear();
      });
    }
  }

  Future<void> _selectVisitor() async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _logDialogColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPersonalVisitorsPartner
                      ? 'Visitantes guardados'
                      : 'Personal de ${_selectedPartner['name']}',
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (_visitorOptions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      _isPersonalVisitorsPartner
                          ? 'Todavía no hay perfiles guardados. Guarda un visitante para seleccionarlo aquí.'
                          : 'Esta empresa todavía no tiene personal registrado. Puedes capturar los datos manualmente.',
                      style: TextStyle(color: _secondaryTextColor(context)),
                    ),
                  )
                else ...[
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final visitor in _visitorOptions)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_outline_rounded),
                            ),
                            title: Text(
                              '${visitor['fullName']}',
                              style: TextStyle(
                                color: _primaryTextColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                    '${visitor['phone'] ?? ''}',
                                    '${visitor['email'] ?? ''}',
                                  ]
                                  .where((value) => value.trim().isNotEmpty)
                                  .join(' · '),
                              style: TextStyle(
                                color: _secondaryTextColor(context),
                                fontSize: 11,
                              ),
                            ),
                            trailing: '${visitor['id']}' == _visitorSelection
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF168BFF),
                                  )
                                : null,
                            onTap: () =>
                                Navigator.pop(context, '${visitor['id']}'),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!_isPersonalVisitorsPartner)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_add_alt_1_rounded),
                    ),
                    title: Text(
                      'Otro (escribir nombre)',
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => Navigator.pop(
                      context,
                      _AppointmentForm.otherVisitorSelection,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selection == null) return;
    setState(() {
      _visitorSelection = selection;
      if (selection != _AppointmentForm.otherVisitorSelection) {
        final visitor = _visitorOptions.firstWhere(
          (option) => '${option['id']}' == selection,
        );
        _visitor.text = '${visitor['fullName']}';
        _email.text = '${visitor['email'] ?? ''}';
      } else {
        _visitor.clear();
        _email.clear();
      }
    });
  }

  Future<void> _selectHost() async {
    final login = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _logDialogColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 17, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anfitrión',
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final host in _appointmentHosts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.badge_outlined),
                          ),
                          title: Text(
                            '${host['name']}',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${host['login']}',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 11,
                            ),
                          ),
                          trailing: host['login'] == _selectedHostLogin
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF168BFF),
                                )
                              : null,
                          onTap: () =>
                              Navigator.pop(context, '${host['login']}'),
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
    if (login != null) setState(() => _selectedHostLogin = login);
  }

  Future<void> _createVisitorProfile() async {
    final draft = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _HostVisitorEditorDialog(),
    );
    if (draft == null) return;
    try {
      final existingIds = _savedVisitors
          .map((visitor) => (visitor['id'] as num).toInt())
          .toSet();
      final visitors = await widget.authService.saveHostVisitor(
        fullName: draft['fullName']!,
        phone: draft['phone']!,
        email: draft['email']!,
      );
      final matchingVisitors = visitors
          .where(
            (visitor) =>
                visitor['fullName'] == draft['fullName'] &&
                visitor['phone'] == draft['phone'] &&
                visitor['email'] == draft['email'],
          )
          .toList();
      final created = matchingVisitors.firstWhere(
        (visitor) => !existingIds.contains((visitor['id'] as num).toInt()),
        orElse: () => matchingVisitors.first,
      );
      if (!mounted) return;
      setState(() {
        _savedVisitors
          ..clear()
          ..addAll(visitors);
        _partnerId = _AppointmentForm.personalVisitorsPartnerId;
        _visitorSelection = '${created['id']}';
        _visitor.text = '${created['fullName']}';
        _email.text = '${created['email']}';
      });
      _showMessage(context, 'Visitante guardado y seleccionado para la cita.');
    } on StateError {
      if (mounted) {
        _showMessage(
          context,
          'No se pudo identificar el perfil recién guardado. Vuelve a cargar los visitantes.',
          error: true,
        );
      }
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Widget _selectorCard({
    required String label,
    required String value,
    required String placeholder,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) => Material(
    color: _logInsetColor(context),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _logBorderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF168BFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: const Color(0xFF68B7FF), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 8,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isEmpty ? placeholder : value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value.isEmpty
                          ? _secondaryTextColor(context)
                          : _primaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (enabled)
              Icon(
                Icons.expand_more_rounded,
                color: _secondaryTextColor(context),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha de la cita',
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(_time.split(':').first) ?? 9,
        minute: int.tryParse(_time.split(':').last) ?? 0,
      ),
      helpText: 'Selecciona la hora de la cita',
    );
    if (value != null) {
      setState(
        () => _time =
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: _primaryTextColor(context), fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: _secondaryTextColor(context),
          fontSize: 12,
        ),
        hintStyle: TextStyle(color: _secondaryTextColor(context), fontSize: 11),
        prefixIcon: Icon(icon, color: const Color(0xFF6AB8FF), size: 18),
        filled: true,
        fillColor: _logInsetColor(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: _logBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF168BFF), width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFFF7189)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFFF7189)),
        ),
      ),
    ),
  );

  Widget _dateTimeSelector({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) => Material(
    color: _logInsetColor(context),
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _logBorderColor(context)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF68B7FF)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 8,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final editing = widget.record != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: _isLightTheme(context) ? Colors.white : null,
          gradient: _isLightTheme(context)
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172844), Color(0xFF091426)],
                ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0x663D9DFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 30,
              offset: Offset(0, 17),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 17, 10, 14),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF168BFF), Color(0xFF26B8E8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.event_available_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            editing ? 'Editar cita' : 'Programar una cita',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Datos de la visita y su anfitrión',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: _secondaryTextColor(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: _logBorderColor(context)),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FormSectionLabel(label: 'EMPRESA Y VISITANTE'),
                      const SizedBox(height: 11),
                      _AppointmentPartnerOption(
                        partner: _selectedPartner,
                        selected: true,
                        onTap: _selectPartner,
                        selector: true,
                      ),
                      const SizedBox(height: 12),
                      _selectorCard(
                        label: 'Visitante',
                        value: _isOtherVisitor
                            ? _visitor.text
                            : '${_selectedVisitor?['fullName'] ?? ''}',
                        placeholder: _isPersonalVisitorsPartner
                            ? 'Selecciona un visitante guardado'
                            : 'Selecciona personal o elige “Otro”',
                        icon: Icons.person_outline_rounded,
                        onTap: _selectVisitor,
                      ),
                      if (_isPersonalVisitorsPartner &&
                          _personalVisitorOptions.isEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          'Registra primero un visitante personal para poder seleccionarlo.',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 10,
                          ),
                        ),
                      ],
                      if (_canUsePersonalVisitors) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _createVisitorProfile,
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 17,
                            ),
                            label: const Text('Guardar visitante'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _isLightTheme(context)
                                  ? const Color(0xFF1769AA)
                                  : const Color(0xFFB8D7FF),
                              side: BorderSide(
                                color: _isLightTheme(context)
                                    ? const Color(0xFFB7D6E8)
                                    : const Color(0x665D9FE4),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_isOtherVisitor) ...[
                        const SizedBox(height: 10),
                        _field(
                          label: 'Nombre completo del visitante',
                          hint: 'Nombre y apellidos',
                          icon: Icons.person_outline_rounded,
                          controller: _visitor,
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Escribe el nombre del visitante'
                              : null,
                        ),
                        _field(
                          label: 'Correo del visitante · opcional',
                          hint: 'correo@ejemplo.com',
                          icon: Icons.mail_outline_rounded,
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (email.isNotEmpty &&
                                !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(email)) {
                              return 'Escribe un correo válido';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 2),
                      _selectorCard(
                        label: 'Anfitrión',
                        value: '${_selectedHost?['name'] ?? ''}',
                        placeholder: widget.isHost
                            ? 'Tu cuenta de anfitrión'
                            : 'Selecciona un anfitrión',
                        icon: Icons.badge_outlined,
                        onTap: _selectHost,
                        enabled: !widget.isHost,
                      ),
                      const SizedBox(height: 14),
                      const _FormSectionLabel(label: 'FECHA Y HORA'),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(
                            child: _dateTimeSelector(
                              label: 'Fecha',
                              value: _displayDate(_dateString(_date)),
                              icon: Icons.calendar_month_rounded,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _dateTimeSelector(
                              label: 'Hora',
                              value: _time,
                              icon: Icons.schedule_rounded,
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'El pase QR se generará al guardar la cita.',
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryTextColor(context),
                          side: BorderSide(color: _logBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: FilledButton.icon(
                          onPressed: () {
                            if (!_hasSelectedVisitor) {
                              _showMessage(
                                context,
                                _isPersonalVisitorsPartner
                                    ? 'Selecciona un visitante guardado o registra uno nuevo.'
                                    : 'Selecciona un visitante registrado o elige “Otro” para capturar sus datos.',
                                error: true,
                              );
                              return;
                            }
                            final selectedHost = _selectedHost;
                            if (selectedHost == null) {
                              _showMessage(
                                context,
                                'Selecciona un anfitrión para la cita.',
                                error: true,
                              );
                              return;
                            }
                            if (!_formKey.currentState!.validate()) return;
                            final personalVisitorId =
                                _isPersonalVisitorsPartner && !_isOtherVisitor
                                ? int.tryParse(_visitorSelection)
                                : null;
                            final appointment = <String, Object?>{
                              'visitorName': _isOtherVisitor
                                  ? _visitor.text.trim()
                                  : '${_selectedVisitor?['fullName'] ?? ''}',
                              'visitorEmail': _isOtherVisitor
                                  ? _email.text.trim()
                                  : '${_selectedVisitor?['email'] ?? ''}',
                              'businessPartnerId': _isPersonalVisitorsPartner
                                  ? null
                                  : _partnerId,
                              'hostName': '${selectedHost['name']}',
                              'date': _dateString(_date),
                              'time': _time,
                            };
                            if (personalVisitorId != null) {
                              appointment['visitorRecordId'] =
                                  personalVisitorId;
                            }
                            Navigator.pop(context, appointment);
                          },
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            editing ? 'Guardar cambios' : 'Crear cita',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
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
      ),
    );
  }
}

class _HostVisitorEditorDialog extends StatefulWidget {
  const _HostVisitorEditorDialog();

  @override
  State<_HostVisitorEditorDialog> createState() =>
      _HostVisitorEditorDialogState();
}

class _HostVisitorEditorDialogState extends State<_HostVisitorEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    final textColor = _primaryTextColor(context);
    final secondaryColor = _secondaryTextColor(context);
    final borderColor = _logBorderColor(context);
    final insetColor = _logInsetColor(context);

    InputDecoration decoration(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF68B7FF), size: 19),
      filled: true,
      fillColor: insetColor,
      labelStyle: TextStyle(color: secondaryColor, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFF168BFF), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFFF7189)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Color(0xFFFF7189)),
      ),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : null,
          gradient: isLight
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172844), Color(0xFF091426)],
                ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0x663D9DFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 30,
              offset: Offset(0, 17),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 17, 10, 14),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF168BFF), Color(0xFF26B8E8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guardar visitante personal',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Guarda sus datos para reutilizarlos en tus citas.',
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: secondaryColor,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 17, 18, 8),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _fullName,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        maxLength: 180,
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: decoration(
                          'Nombre completo',
                          Icons.person_outline_rounded,
                        ).copyWith(counterText: ''),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Escribe el nombre completo'
                            : null,
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        maxLength: 30,
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: decoration(
                          'Teléfono · opcional',
                          Icons.phone_outlined,
                        ).copyWith(counterText: ''),
                      ),
                      const SizedBox(height: 11),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        maxLength: 254,
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: decoration(
                          'Correo electrónico · opcional',
                          Icons.mail_outline_rounded,
                        ).copyWith(counterText: ''),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isNotEmpty &&
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)) {
                            return 'Escribe un correo válido o déjalo vacío';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: FilledButton.icon(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            Navigator.pop(context, {
                              'fullName': _fullName.text.trim(),
                              'phone': _phone.text.trim(),
                              'email': _email.text.trim(),
                            });
                          },
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text(
                            'Guardar y usar',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
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
      ),
    );
  }
}

class _AppointmentPartnerOption extends StatelessWidget {
  const _AppointmentPartnerOption({
    required this.partner,
    required this.selected,
    required this.onTap,
    this.selector = false,
  });

  final Map<String, dynamic> partner;
  final bool selected;
  final VoidCallback onTap;
  final bool selector;

  @override
  Widget build(BuildContext context) {
    final type = '${partner['type'] ?? 'Visitante'}';
    final visitor = type == 'Visitante';
    final color = visitor
        ? const Color(0xFFB69CFF)
        : type == 'Proveedor'
        ? const Color(0xFF4AE3B5)
        : const Color(0xFF62B4FF);
    return Padding(
      padding: EdgeInsets.only(bottom: selector ? 0 : 7),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.12)
            : _logInsetColor(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.45)
                    : _logBorderColor(context),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    visitor
                        ? Icons.person_outline_rounded
                        : type == 'Proveedor'
                        ? Icons.local_shipping_rounded
                        : Icons.apartment_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selector ? 'EMPRESA O VISITANTE' : type,
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 8,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${partner['name'] ?? 'Sin nombre'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _primaryTextColor(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selector)
                  Icon(
                    Icons.expand_more_rounded,
                    color: _secondaryTextColor(context),
                  )
                else if (selected)
                  Icon(Icons.check_circle_rounded, color: color, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentRecordCard extends StatelessWidget {
  const _AppointmentRecordCard({
    required this.item,
    required this.displayStatus,
    required this.canReschedule,
    required this.canManage,
    required this.isAdmin,
    required this.onEdit,
    required this.onReschedule,
    required this.onCancel,
    required this.onDelete,
    required this.onSendQr,
    required this.onShowCode,
  });
  final Map<String, dynamic> item;
  final String displayStatus;
  final bool canReschedule;
  final bool canManage;
  final bool isAdmin;
  final VoidCallback onEdit,
      onReschedule,
      onCancel,
      onDelete,
      onSendQr,
      onShowCode;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    final status = displayStatus;
    final canceled = status == 'Cancelada';
    final withdrawn = status == 'Retirado';
    final statusColor = status == 'No se presentó'
        ? const Color(0xFFFF7189)
        : status == 'Tardía'
        ? const Color(0xFFFFC56E)
        : canceled
        ? const Color(0xFFFF7189)
        : status == 'Dentro' || withdrawn
        ? const Color(0xFF4AE3B5)
        : const Color(0xFFFFC56E);
    final email = '${item['email'] ?? ''}'.trim();
    final reference = '${item['referenceCode'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : null,
        gradient: isLight
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF17243D), Color(0xFF0C1628)],
              ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 6),
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
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFF168BFF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x554AA8FF)),
                ),
                child: const Icon(
                  Icons.person_pin_circle_rounded,
                  color: Color(0xFF73BEFF),
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['visitor'] ?? 'Visitante'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${item['company'] ?? 'Sin empresa'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              _AppointmentStatusBadge(label: status, color: statusColor),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AppointmentInfoTile(
                icon: Icons.schedule_rounded,
                label: 'FECHA Y HORA',
                value: '${_displayDate(item['date'])} · ${item['time'] ?? '—'}',
                accent: const Color(0xFF68B7FF),
              ),
              _AppointmentInfoTile(
                icon: Icons.person_outline_rounded,
                label: 'ANFITRIÓN',
                value: '${item['host'] ?? 'Sin anfitrión'}',
                accent: const Color(0xFF4AE3B5),
              ),
              if (email.isNotEmpty)
                _AppointmentInfoTile(
                  icon: Icons.mail_outline_rounded,
                  label: 'CORREO DEL VISITANTE',
                  value: email,
                  accent: const Color(0xFFB69CFF),
                ),
              if (reference.isNotEmpty)
                _AppointmentInfoTile(
                  icon: Icons.confirmation_number_outlined,
                  label: 'FOLIO',
                  value: reference,
                  accent: const Color(0xFFFFC56E),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Divider(height: 1, color: _logBorderColor(context)),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _AppointmentActionButton(
                label: 'Ver QR',
                icon: Icons.qr_code_2_rounded,
                onPressed: onShowCode,
                primary: true,
              ),
              if (canManage && !canceled && !withdrawn) ...[
                _AppointmentActionButton(
                  label: 'Enviar pase',
                  icon: Icons.send_rounded,
                  onPressed: onSendQr,
                ),
                if (canReschedule)
                  _AppointmentActionButton(
                    label: 'Reagendar',
                    icon: Icons.event_repeat_rounded,
                    onPressed: onReschedule,
                  )
                else if (canReschedule)
                  _AppointmentActionButton(
                    label: 'Reagendar',
                    icon: Icons.event_repeat_rounded,
                    onPressed: onReschedule,
                  )
                else
                  _AppointmentActionButton(
                    label: 'Editar',
                    icon: Icons.edit_rounded,
                    onPressed: onEdit,
                  ),
                _AppointmentActionButton(
                  label: 'Cancelar cita',
                  icon: Icons.event_busy_rounded,
                  onPressed: onCancel,
                  destructive: true,
                ),
              ],
              if (canManage)
                _AppointmentActionButton(
                  label: 'Eliminar',
                  icon: Icons.delete_outline_rounded,
                  onPressed: onDelete,
                  destructive: true,
                  enabled: isAdmin || canceled,
                  tooltip: isAdmin || canceled
                      ? 'Eliminar cita'
                      : 'Primero cancela la cita para poder eliminarla',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppointmentInfoTile extends StatelessWidget {
  const _AppointmentInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 54),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: _isLightTheme(context)
          ? const Color(0xFFF3F6FB)
          : const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _isLightTheme(context)
            ? const Color(0xFFDCE4EF)
            : Colors.white.withValues(alpha: 0.07),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: accent),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 8,
                  letterSpacing: 0.55,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 10,
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

class _AppointmentStatusBadge extends StatelessWidget {
  const _AppointmentStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
            ],
          ),
        ),
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
  );
}

class _AppointmentActionButton extends StatelessWidget {
  const _AppointmentActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
    this.enabled = true,
    this.tooltip,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool destructive;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFFF8294)
        : const Color(0xFF8FC9FF);
    final button = OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: destructive ? color : Colors.white,
        backgroundColor: destructive
            ? const Color(0x16FF3155)
            : const Color(0xFF0C1B30),
        side: BorderSide(
          color: destructive
              ? const Color(0x66FF3155)
              : const Color(0x554AA8FF),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        minimumSize: const Size(0, 38),
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      ),
    );
    if (!primary) {
      return tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 15),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          minimumSize: const Size(0, 38),
          textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
    );
  }
}

class _AppointmentQrPrintableCard extends StatelessWidget {
  const _AppointmentQrPrintableCard({
    required this.name,
    required this.referenceCode,
    required this.qrData,
  });

  final String name;
  final String referenceCode;
  final String qrData;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFFCFCFD),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF071A36), width: 3),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _PassCardAccentPainter())),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Image.asset(
                'assets/images/cymez-pass-logo.png',
                height: 126,
                fit: BoxFit.contain,
                semanticLabel: 'Logo CyMEZ',
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF071A36),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE21B2D), width: 3),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 9),
                    Container(width: 2, height: 29, color: Colors.white70),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        name,
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'CÓDIGO DE REFERENCIA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF071A36),
                  fontSize: 11,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                constraints: const BoxConstraints(minWidth: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD20D1B),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  referenceCode.isEmpty ? 'SIN REFERENCIA' : referenceCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF071A36),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33D20D1B),
                            blurRadius: 0,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: qrData,
                        semanticsLabel:
                            'Código QR de $name · referencia $referenceCode',
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        eyeStyle: const QrEyeStyle(color: Color(0xFF10243A)),
                        dataModuleStyle: const QrDataModuleStyle(
                          color: Color(0xFF10243A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ESCANEA EL CÓDIGO QR\nPARA REGISTRAR TU VISITA',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF071A36),
                  fontSize: 9,
                  height: 1.45,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PassCardAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final navy = Paint()..color = const Color(0xFF071A36);
    final red = Paint()..color = const Color(0xFFE21B2D);
    final pale = Paint()..color = const Color(0xFFE8ECF2);
    final topLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * .32, 0)
      ..lineTo(0, size.height * .27)
      ..close();
    canvas.drawPath(topLeft, navy);
    final topRed = Path()
      ..moveTo(size.width * .27, 0)
      ..lineTo(size.width * .36, 0)
      ..lineTo(0, size.height * .34)
      ..lineTo(0, size.height * .26)
      ..close();
    canvas.drawPath(topRed, red);
    final bottomRight = Path()
      ..moveTo(size.width, size.height * .72)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * .64, size.height)
      ..close();
    canvas.drawPath(bottomRight, navy);
    final bottomRed = Path()
      ..moveTo(size.width, size.height * .68)
      ..lineTo(size.width, size.height * .75)
      ..lineTo(size.width * .72, size.height)
      ..lineTo(size.width * .64, size.height)
      ..close();
    canvas.drawPath(bottomRed, red);
    final accent = Path()
      ..moveTo(0, size.height * .29)
      ..lineTo(size.width * .29, 0)
      ..lineTo(size.width * .33, 0)
      ..lineTo(0, size.height * .34)
      ..close();
    canvas.drawPath(accent, pale);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppointmentPassDialog extends StatefulWidget {
  const _AppointmentPassDialog({required this.appointment, this.employee});
  final Map<String, dynamic> appointment;
  final Map<String, dynamic>? employee;

  @override
  State<_AppointmentPassDialog> createState() => _AppointmentPassDialogState();
}

class _AppointmentPassDialogState extends State<_AppointmentPassDialog> {
  final _qrBoundaryKey = GlobalKey();
  bool _isDownloading = false;

  Future<void> _downloadQr() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final renderObject = _qrBoundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('No se pudo preparar la imagen del código QR.');
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('No se pudo convertir el código QR a PNG.');
      }
      final personName =
          '${widget.employee?['fullName'] ?? widget.appointment['visitor'] ?? 'visita'}';
      final fileName = personName
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'pase-qr-${fileName.isEmpty ? 'visita' : fileName}',
      );
      if (mounted) {
        _showMessage(context, 'Código QR descargado en la galería.');
      }
    } on PlatformException catch (error) {
      debugPrint('No se pudo guardar el pase QR: ${error.message}');
      if (mounted) {
        _showMessage(
          context,
          'No fue posible guardar el código QR.',
          error: true,
        );
      }
    } catch (error) {
      debugPrint('No se pudo generar el PNG del pase QR: $error');
      if (mounted) {
        _showMessage(
          context,
          'No fue posible guardar el código QR.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final employee = widget.employee;
    final payload = <String, Object?>{
      'type': 'visitas-appointment',
      'id': appointment['id'],
      if (employee != null) 'externalStaffId': employee['id'],
      'referenceCode': appointment['referenceCode'],
      'visitor': employee?['fullName'] ?? appointment['visitor'],
      'company': appointment['company'],
      'host': appointment['host'],
      'date': appointment['date'],
      'time': appointment['time'],
    };
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: _isLightTheme(context) ? Colors.white : null,
          gradient: _isLightTheme(context)
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172844), Color(0xFF091426)],
                ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0x663D9DFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF168BFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: Color(0xFF73BEFF),
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pase de visita',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Presenta este código en recepción',
                          style: TextStyle(color: _muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: _muted,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 80).clamp(
                  240.0,
                  360.0,
                ),
                child: AspectRatio(
                  aspectRatio: 0.56,
                  child: RepaintBoundary(
                    key: _qrBoundaryKey,
                    child: _AppointmentQrPrintableCard(
                      name:
                          '${employee?['fullName'] ?? appointment['visitor'] ?? 'Visitante'}',
                      referenceCode: '${appointment['referenceCode'] ?? ''}',
                      qrData: jsonEncode(payload),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isDownloading ? null : _downloadQr,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF087FFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    _isDownloading ? 'Guardando PNG...' : 'Descargar PNG',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x554AA8FF)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectedDailyLogbookPage extends StatefulWidget {
  const ConnectedDailyLogbookPage({
    required this.authService,
    required this.isAdmin,
    this.user,
    super.key,
  });
  final AuthService authService;
  final bool isAdmin;
  final AuthenticatedUser? user;
  @override
  State<ConnectedDailyLogbookPage> createState() =>
      _ConnectedDailyLogbookPageState();
}

class _ConnectedDailyLogbookPageState extends State<ConnectedDailyLogbookPage>
    with WidgetsBindingObserver {
  Timer? _searchDebounce;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _query = '';
  String _event = '';
  String _category = '';
  String _host = '';
  int _page = 1;
  int _recentPage = 1;
  int _appointmentPage = 1;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _appointments = [];
  String _appointmentQuery = '';
  bool _filtersExpanded = false;
  late final _RealtimeRefreshCoordinator _realtime;
  bool _loadInProgress = false;
  bool _refreshQueued = false;
  final List<Map<String, dynamic>> _visitTimers = [];
  final Map<int, String> _lastTimerAlertAt = {};
  int _timerPage = 1;
  static const _timersPerPage = 8;
  final TimerNotificationService _notificationService =
      TimerNotificationService.instance;
  Timer? _timerPoll;
  Timer? _timerTicker;
  bool _timerRequestInProgress = false;
  bool _isForeground = true;
  String? _timerError;
  DateTime? _timerLastUpdatedAt;
  String _notificationStatus = 'Verificando notificaciones…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationService.dailyLogRefreshes.addListener(_onNotificationOpened);
    _load();
    _refreshTimers();
    _timerPoll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshTimers(),
    );
    _timerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isForeground || _visitTimers.isEmpty) return;
      _checkOverdueTimers();
      setState(() {});
    });
    _configureNotifications();
    _realtime = _RealtimeRefreshCoordinator(
      widget.authService,
      () => _load(silent: true),
    )..start();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _timerPoll?.cancel();
    _timerTicker?.cancel();
    _notificationService.dailyLogRefreshes.removeListener(
      _onNotificationOpened,
    );
    WidgetsBinding.instance.removeObserver(this);
    _realtime.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) {
      _load(silent: true);
      _refreshTimers();
    }
  }

  void _onNotificationOpened() => _load(silent: true);

  Future<void> _configureNotifications() async {
    if (widget.user?.canAccessReception != true) {
      _notificationStatus = 'El registro de notificaciones está disponible para dispositivos de recepción.';
      return;
    }
    await _notificationService.configureAndRegister(widget.authService);
    if (mounted) {
      setState(() => _notificationStatus = _notificationService.statusMessage);
    }
  }

  Future<void> _refreshTimers() async {
    if (_timerRequestInProgress) return;
    _timerRequestInProgress = true;
    try {
      final timers = await widget.authService.getDailyLogTimers();
      if (!mounted) return;
      setState(() {
        _visitTimers
          ..clear()
          ..addAll(timers);
        final totalPages = _timerPageCount;
        if (_timerPage > totalPages) _timerPage = totalPages;
        _timerError = null;
        _timerLastUpdatedAt = DateTime.now();
        final activeIds = timers
            .map((timer) => (timer['id'] as num).toInt())
            .toSet();
        _lastTimerAlertAt.removeWhere((id, _) => !activeIds.contains(id));
      });
      _checkOverdueTimers();
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _timerError = error.message);
    } finally {
      _timerRequestInProgress = false;
    }
  }

  void _checkOverdueTimers() {
    if (!_isForeground || _visitTimers.isEmpty) return;
    final now = DateTime.now();
    for (final timer in _visitTimers) {
      final dueAt = DateTime.tryParse('${timer['dueAt'] ?? ''}')?.toLocal();
      if (dueAt == null || !now.isAfter(dueAt)) continue;
      final id = (timer['id'] as num).toInt();
      final dueKey = '${timer['dueAt']}';
      if (_lastTimerAlertAt[id] == dueKey) continue;
      _lastTimerAlertAt[id] = dueKey;
      unawaited(SystemSound.play(SystemSoundType.alert).catchError((_) {}));
      unawaited(HapticFeedback.vibrate().catchError((_) {}));
      break;
    }
  }

  Future<void> _actOnVisitTimer(
    Map<String, dynamic> timer, {
    required String action,
  }) async {
    final id = (timer['id'] as num).toInt();
    try {
      final timers = await widget.authService.actOnDailyLogTimer(
        id,
        action: action,
      );
      if (!mounted) return;
      setState(() {
        _visitTimers
          ..clear()
          ..addAll(timers);
        _lastTimerAlertAt.remove(id);
        _timerError = null;
        _timerLastUpdatedAt = DateTime.now();
      });
      _checkOverdueTimers();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  String _timerTimeLabel(Map<String, dynamic> timer) {
    final dueAt = DateTime.tryParse('${timer['dueAt'] ?? ''}')?.toLocal();
    if (dueAt == null) return 'Hora de vencimiento no disponible';
    final remainingSeconds = dueAt.difference(DateTime.now()).inSeconds;
    final duration = Duration(seconds: remainingSeconds.abs());
    final clock =
        '${duration.inHours.toString().padLeft(2, '0')}:'
        '${(duration.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    if (remainingSeconds <= 0) return 'VENCIDO · $clock';
    return 'Vence ${dueAt.hour.toString().padLeft(2, '0')}:'
        '${dueAt.minute.toString().padLeft(2, '0')} · faltan $clock';
  }

  String _timerElapsedLabel(Map<String, dynamic> timer) {
    final startedAt = DateTime.tryParse('${timer['startedAt'] ?? ''}')
        ?.toLocal();
    if (startedAt == null) return 'Tiempo transcurrido no disponible';
    final elapsed = DateTime.now().difference(startedAt);
    final duration = Duration(
      seconds: elapsed.isNegative ? 0 : elapsed.inSeconds,
    );
    final clock =
        '${duration.inHours.toString().padLeft(2, '0')}:'
        '${(duration.inMinutes % 60).toString().padLeft(2, '0')}:'
        '${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
    return 'Lleva $clock';
  }

  String _timerLastUpdatedLabel() {
    final updatedAt = _timerLastUpdatedAt;
    if (updatedAt == null) return 'Aún no se han confirmado temporizadores';
    final time =
        '${updatedAt.hour.toString().padLeft(2, '0')}:'
        '${updatedAt.minute.toString().padLeft(2, '0')}:'
        '${updatedAt.second.toString().padLeft(2, '0')}';
    return _timerError == null
        ? 'Temporizadores verificados a las $time · actualiza cada 30 s'
        : 'Mostrando datos de las $time; no se pudo actualizar';
  }

  List<Map<String, dynamic>> get _overdueVisitTimers =>
      _visitTimers.where((timer) {
        final dueAt = DateTime.tryParse('${timer['dueAt'] ?? ''}')?.toLocal();
        return dueAt != null && DateTime.now().isAfter(dueAt);
      }).toList();

  int get _timerPageCount =>
      (_visitTimers.length / _timersPerPage).ceil().clamp(1, 1 << 30).toInt();

  List<Map<String, dynamic>> get _visibleVisitTimers {
    final start = (_timerPage - 1) * _timersPerPage;
    return _visitTimers.skip(start).take(_timersPerPage).toList();
  }

  double _timerProgress(Map<String, dynamic> timer) {
    final dueAt = DateTime.tryParse('${timer['dueAt'] ?? ''}')?.toLocal();
    final interval = (timer['intervalMinutes'] as num).toInt();
    if (dueAt == null || interval <= 0) return 0;
    final intervalStart = dueAt.subtract(Duration(minutes: interval));
    final elapsedSeconds = DateTime.now().difference(intervalStart).inSeconds;
    return (elapsedSeconds / (interval * 60)).clamp(0, 1).toDouble();
  }

  Widget _overdueTimerBanner(BuildContext context) => _logbookPanel(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.alarm_on_rounded, color: Color(0xFFFF7189), size: 20),
            SizedBox(width: 8),
            Text(
              'ALERTA DE SEGUIMIENTO VENCIDA',
              style: TextStyle(
                color: Color(0xFFFF7189),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final timer in _overdueVisitTimers) ...[
          Text(
            '${timer['personName']} · ${timer['phase']} · ${_timerTimeLabel(timer)}',
            style: TextStyle(
              color: _primaryTextColor(context),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (widget.isAdmin)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _actOnVisitTimer(timer, action: 'snooze'),
                    icon: const Icon(Icons.replay_rounded, size: 16),
                    label: Text(
                      'Repetir ${(timer['intervalMinutes'] as num).toInt()} min',
                    ),
                    style: _logOutlinedButtonStyle(
                      context,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _actOnVisitTimer(timer, action: 'cancel'),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Cancelar alerta'),
                    style: _logOutlinedButtonStyle(
                      context,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ],
    ),
  );

  Future<void> _load({bool silent = false}) async {
    if (_loadInProgress) {
      _refreshQueued = true;
      return;
    }
    _loadInProgress = true;
    var showLoader = !silent;
    do {
      _refreshQueued = false;
      if (mounted && showLoader) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
      try {
        final result = await Future.wait([
          widget.authService.getDailyLog(
            from: _dateString(_fromDate),
            to: _dateString(_toDate),
            query: _query,
            event: _event,
            category: _category,
            host: _host,
            page: _page,
            pageSize: 5,
            recentPage: _recentPage,
            recentPageSize: 5,
          ),
          widget.authService.getAppointments(),
        ]);
        if (mounted) {
          setState(() {
            _data = result[0] as Map<String, dynamic>;
            _appointments = result[1] as List<Map<String, dynamic>>;
            _loading = false;
            _error = null;
          });
        }
      } on AuthApiException catch (error) {
        if (mounted) {
          setState(() {
            _error = error.message;
            _loading = false;
          });
        }
      }
      showLoader = false;
    } while (_refreshQueued && mounted);
    _loadInProgress = false;
  }

  List<Map<String, dynamic>> get _todaysAppointments {
    final today = _dateString(DateTime.now());
    return _appointments.where((item) {
        final date = item['date']?.toString();
        return date != null &&
            date.startsWith(today) &&
            item['status'] != 'Cancelada' &&
            item['status'] != 'Retirado';
      }).toList()
      ..sort((a, b) => '${a['time'] ?? ''}'.compareTo('${b['time'] ?? ''}'));
  }

  List<Map<String, dynamic>> get _filteredQuickAppointments {
    final query = _appointmentQuery.trim().toLowerCase();
    final filtered = _todaysAppointments.where((item) {
      return query.isEmpty ||
          '${item['visitor'] ?? ''} ${item['company'] ?? ''}'
              .toLowerCase()
              .contains(query);
    }).toList();
    return filtered.skip((_appointmentPage - 1) * 5).take(5).toList();
  }

  int get _filteredAppointmentPages {
    final query = _appointmentQuery.trim().toLowerCase();
    final count = _todaysAppointments.where((item) {
      return query.isEmpty ||
          '${item['visitor'] ?? ''} ${item['company'] ?? ''}'
              .toLowerCase()
              .contains(query);
    }).length;
    return (count / 5).ceil().clamp(1, 999999);
  }

  int get _activeFilterCount =>
      (_event.isEmpty ? 0 : 1) +
      (_category.isEmpty ? 0 : 1) +
      (_host.isEmpty ? 0 : 1);

  void _clearFilters() {
    setState(() {
      _event = '';
      _category = '';
      _host = '';
      _page = 1;
      _recentPage = 1;
    });
    _load();
  }

  Future<void> _pickDate({required bool start}) async {
    final selectedDate = start ? _fromDate : _toDate;
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: start
          ? 'Selecciona la fecha inicial'
          : 'Selecciona la fecha final',
    );
    if (date == null || !mounted) return;
    if ((start && date.isAfter(_toDate)) ||
        (!start && date.isBefore(_fromDate))) {
      _showMessage(
        context,
        'El rango de fechas seleccionado no es válido.',
        error: true,
      );
      return;
    }
    setState(() {
      if (start) {
        _fromDate = date;
      } else {
        _toDate = date;
      }
      _page = 1;
      _recentPage = 1;
    });
    await _load();
  }

  Future<void> _showHistory() async {
    final range = _data['historyRange'];
    final firstDate = range is Map<String, dynamic>
        ? DateTime.tryParse('${range['firstDate'] ?? ''}')
        : null;
    final lastDate = range is Map<String, dynamic>
        ? DateTime.tryParse('${range['lastDate'] ?? ''}')
        : null;
    if (firstDate == null || lastDate == null) {
      _showMessage(
        context,
        'Aún no hay registros para consultar el historial.',
      );
      return;
    }
    setState(() {
      _fromDate = firstDate;
      _toDate = lastDate;
      _page = 1;
      _recentPage = 1;
    });
    await _load();
  }

  Future<void> _showCurrentDay() async {
    final today = DateTime.now();
    setState(() {
      _fromDate = DateTime(today.year, today.month, today.day);
      _toDate = DateTime(today.year, today.month, today.day);
      _page = 1;
      _recentPage = 1;
    });
    await _load();
  }

  bool _isPastEntry(Map<String, dynamic> entry) {
    if (widget.isAdmin) return false;
    final date = entry['date']?.toString();
    if (date == null || date.length < 10) return true;
    return date.substring(0, 10).compareTo(_dateString(DateTime.now())) < 0;
  }

  Future<void> _register() async {
    try {
      final options = await Future.wait([
        widget.authService.getExternalStaff(),
        widget.authService.getGeneralVisitors(),
      ]);
      if (!mounted) return;
      final result = await showDialog<Map<String, Object?>>(
        context: context,
        builder: (_) => _DailyLogEntryForm(
          staff: options[0],
          visitors: options[1],
          date: DateTime.now(),
        ),
      );
      if (result == null) return;
      await widget.authService.createDailyLogEntry(result);
      if (!mounted) return;
      _showMessage(context, 'Llegada registrada correctamente.');
      setState(() {
        _fromDate = DateTime.now();
        _toDate = DateTime.now();
        _page = 1;
        _recentPage = 1;
      });
      await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<bool> _recordMovement({
    required String event,
    required String person,
    int? appointmentId,
    int? externalStaffId,
    int? visitorRecordId,
    int? sourceEntryId,
    String details = '',
  }) async {
    final now = DateTime.now();
    try {
      await widget.authService.createDailyLogEntry({
        'event': event,
        'date': _dateString(now),
        'time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'personName': person,
        'details': details.trim(),
        'appointmentId': appointmentId,
        'externalStaffId': externalStaffId,
        'visitorRecordId': visitorRecordId,
        'sourceEntryId': sourceEntryId,
      });
      if (!mounted) return false;
      _showMessage(
        context,
        '$person: ${event == 'Ingreso'
            ? 'entrada'
            : event == 'Retiro'
            ? 'salida'
            : 'llegada'} registrada.',
      );
      setState(() {
        _fromDate = now;
        _toDate = now;
        _page = 1;
        _recentPage = 1;
      });
      await _load();
      return true;
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
      return false;
    }
  }

  Future<void> _openAppointment(
    Map<String, dynamic> appointment, {
    int? externalStaffId,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AppointmentReceptionDialog(
        appointment: appointment,
        authService: widget.authService,
        externalStaffId: externalStaffId,
        onRecordMovement: (event, person, {externalStaffId}) => _recordMovement(
          event: event,
          person: person,
          appointmentId: appointment['id'] as int?,
          externalStaffId: externalStaffId,
          visitorRecordId: appointment['visitorRecordId'] as int?,
        ),
      ),
    );
  }

  Future<void> _openVisitorRegistration(
    Map<String, dynamic> registration, {
    bool readOnly = false,
  }) async {
    bool? isInside;
    final items = (registration['items'] as List? ?? const []);
    if (!readOnly &&
        registration['authorizationStatus'] == 'Autorizada' &&
        items.isEmpty) {
      try {
        final today = _dateString(DateTime.now());
        final data = await widget.authService.getDailyLog(
          from: today,
          to: today,
          query: '${registration['visitorName'] ?? ''}',
          pageSize: 100,
          recentPageSize: 5,
        );
        final visitorRecordId = registration['visitorRecordId'];
        final movements =
            (data['entries'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()
                .where((entry) => entry['visitorRecordId'] == visitorRecordId)
                .toList()
              ..sort((a, b) {
                final aTimestamp = '${a['date'] ?? ''} ${a['time'] ?? ''}';
                final bTimestamp = '${b['date'] ?? ''} ${b['time'] ?? ''}';
                final timestampOrder = bTimestamp.compareTo(aTimestamp);
                if (timestampOrder != 0) return timestampOrder;
                final aId = a['id'] is num ? (a['id'] as num).toInt() : 0;
                final bId = b['id'] is num ? (b['id'] as num).toInt() : 0;
                return bId.compareTo(aId);
              });
        isInside = movements.firstOrNull?['event'] == 'Ingreso';
      } on AuthApiException catch (error) {
        if (!mounted) return;
        _showMessage(context, error.message, error: true);
      }
    }
    if (!mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _VisitorRegistrationReceptionDialog(
        registration: registration,
        authService: widget.authService,
        isAdmin: widget.isAdmin,
        isInside: isInside,
        forceReadOnly: readOnly,
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _lookupCode(String value) async {
    final code = value.trim();
    if (code.isEmpty) return;
    String? registrationLookupError;
    dynamic decoded;
    try {
      decoded = jsonDecode(code);
    } on FormatException {
      decoded = null;
    }
    final referenceCode =
        decoded is Map && decoded['type'] == 'visitas-appointment'
        ? decoded['referenceCode']?.toString()
        : code;
    final appointmentId =
        decoded is Map && decoded['type'] == 'visitas-appointment'
        ? decoded['id']
        : null;
    final externalStaffId =
        decoded is Map && decoded['type'] == 'visitas-appointment'
        ? decoded['externalStaffId']
        : null;
    if (decoded is! Map || decoded['type'] != 'visitas-appointment') {
      try {
        final registrations = await widget.authService
            .getVisitorKioskRegistrations();
        final registration = registrations
            .where((item) => item['folio']?.toString() == referenceCode)
            .firstOrNull;
        if (registration != null) {
          await _openVisitorRegistration(registration);
          return;
        }
      } on AuthApiException catch (error) {
        registrationLookupError = error.message;
      }
    }
    final appointment = _todaysAppointments.where((item) {
      return (appointmentId is num && item['id'] == appointmentId) ||
          item['referenceCode']?.toString() == referenceCode;
    }).firstOrNull;
    if (appointment != null) {
      await _openAppointment(
        appointment,
        externalStaffId: externalStaffId is num
            ? externalStaffId.toInt()
            : null,
      );
      return;
    }
    if (mounted) {
      _showMessage(
        context,
        registrationLookupError ??
            'Verifica el folio o vuelve a escanear el pase de visita.',
        error: true,
        title: registrationLookupError == null
            ? 'Código no encontrado'
            : 'No se pudo verificar el código',
      );
    }
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        final isLight = _isLightTheme(context);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _panelColor(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isLight
                    ? const Color(0xFFD8E4F2)
                    : const Color(0x554AA8FF),
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
                        Icons.confirmation_number_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BITÁCORA DIARIA',
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
                            'Buscar visita',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: _secondaryTextColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  'Ingresa el código de referencia o folio para localizar el registro.',
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 8,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Código de referencia',
                    hintText: '00000000',
                    labelStyle: TextStyle(color: _secondaryTextColor(context)),
                    hintStyle: TextStyle(
                      color: _secondaryTextColor(context).withValues(alpha: .5),
                      letterSpacing: 4,
                    ),
                    counterStyle: TextStyle(
                      color: _secondaryTextColor(context),
                    ),
                    filled: true,
                    fillColor: _logInsetColor(context),
                    prefixIcon: const Icon(
                      Icons.tag_rounded,
                      color: Color(0xFF168BFF),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _logBorderColor(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF168BFF),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryTextColor(context),
                          side: BorderSide(color: _logBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
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
                        onPressed: () =>
                            Navigator.pop(context, controller.text.trim()),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF087FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: const Icon(Icons.search_rounded, size: 18),
                        label: const Text('Buscar'),
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
    controller.dispose();
    if (value != null) await _lookupCode(value);
  }

  Future<void> _scanQr() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const _DailyLogQrScanner(),
    );
    if (value != null) await _lookupCode(value);
  }

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    final readOnly = _isPastEntry(entry);
    final visitorRecordId = entry['visitorRecordId'];
    if (visitorRecordId is num) {
      try {
        final registrations = await widget.authService
            .getVisitorKioskRegistrations();
        final registration = registrations
            .where((item) => item['visitorRecordId'] == visitorRecordId)
            .firstOrNull;
        if (registration != null) {
          await _openVisitorRegistration(registration, readOnly: readOnly);
          return;
        }
      } on AuthApiException catch (error) {
        if (!mounted) return;
        _showMessage(context, error.message, error: true);
        return;
      }
    }
    if (!mounted) return;
    final appointmentId = entry['appointmentId'];
    final appointment = appointmentId is num
        ? _appointments.where((item) => item['id'] == appointmentId).firstOrNull
        : null;
    await showDialog<void>(
      context: context,
      builder: (context) => _DailyLogEntryDetailDialog(
        entry: entry,
        appointment: appointment,
        authService: widget.authService,
        showRegisteredBy: widget.isAdmin,
        readOnly: readOnly,
        onRecordMovement: (event) => _recordMovement(
          event: event,
          person: '${entry['person'] ?? 'Visitante'}',
          appointmentId: appointmentId is num ? appointmentId.toInt() : null,
          externalStaffId: entry['externalStaffId'] is num
              ? (entry['externalStaffId'] as num).toInt()
              : null,
          visitorRecordId: visitorRecordId is num
              ? visitorRecordId.toInt()
              : null,
          sourceEntryId: entry['id'] is num
              ? (entry['id'] as num).toInt()
              : null,
        ),
      ),
    );
  }

  Future<void> _openEntryQr(Map<String, dynamic> entry) async {
    final appointmentId = entry['appointmentId'];
    final appointment = appointmentId is num
        ? _appointments.where((item) => item['id'] == appointmentId).firstOrNull
        : null;
    if (appointment == null) {
      _showMessage(
        context,
        'Este movimiento no está vinculado a una cita.',
        error: true,
      );
      return;
    }
    final qrData = jsonEncode({
      'type': 'visitas-appointment',
      'id': appointment['id'],
      if (entry['externalStaffId'] is num)
        'externalStaffId': (entry['externalStaffId'] as num).toInt(),
      'referenceCode': appointment['referenceCode'],
    });
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panelColor(context),
        title: Text(
          'Pase de ${entry['person'] ?? 'visita'}',
          style: TextStyle(color: _primaryTextColor(context)),
        ),
        content: Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: QrImageView(
            data: qrData,
            size: 220,
            semanticsLabel: 'Código QR de la cita',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
    if (_isPastEntry(entry)) {
      _showMessage(
        context,
        'Los movimientos de días anteriores son de solo lectura.',
        error: true,
      );
      return;
    }
    final id = entry['id'];
    if (id is! num || id <= 0) {
      _showMessage(
        context,
        'El movimiento seleccionado no es válido.',
        error: true,
      );
      return;
    }
    if (!await _confirmAction(
      context,
      title: 'Eliminar movimiento',
      message:
          '¿Eliminar el movimiento de ${entry['person'] ?? 'esta persona'}?',
      confirmLabel: 'Eliminar',
    )) {
      return;
    }
    try {
      await widget.authService.deleteDailyLogEntry(id.toInt());
      if (!mounted) return;
      _showMessage(context, 'Movimiento eliminado.');
      await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Widget _visitTimersPanel(BuildContext context) => _logbookPanel(
    context: context,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFF68B7FF),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Temporizadores de seguimiento · ${_visitTimers.length}',
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Actualizar temporizadores',
              onPressed: _refreshTimers,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _timerLastUpdatedLabel(),
            style: TextStyle(
              color: _timerError == null
                  ? _secondaryTextColor(context)
                  : const Color(0xFFFF8394),
              fontSize: 10,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _logInsetColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _logBorderColor(context)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF68B7FF),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _notificationStatus,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 10,
                  ),
                ),
              ),
              TextButton(
                onPressed: _configureNotifications,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        if (_timerError != null) ...[
          const SizedBox(height: 8),
          Text(
            'No se pudieron cargar los temporizadores: $_timerError',
            style: const TextStyle(color: Color(0xFFFF8394), fontSize: 11),
          ),
        ],
        if (_visitTimers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _timerError == null
                  ? 'No hay temporizadores activos para las visitas de hoy.'
                  : 'Las citas y la bitácora siguen disponibles mientras se recupera el servicio de temporizadores.',
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 11,
              ),
            ),
          )
        else ...[
          const SizedBox(height: 9),
          Text(
            widget.isAdmin
                ? 'Recepción puede consultarlos; solo administración puede repetir o cancelar una alerta.'
                : 'Solo administración puede repetir o cancelar las alertas.',
            style: TextStyle(color: _secondaryTextColor(context), fontSize: 10),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 600
                  ? 2
                  : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _visibleVisitTimers.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: columns == 1
                      ? 2.45
                      : columns == 2
                      ? 1.55
                      : 1.16,
                ),
                itemBuilder: (context, index) {
                  final timer = _visibleVisitTimers[index];
                  final dueAt = DateTime.tryParse('${timer['dueAt'] ?? ''}')
                      ?.toLocal();
                  final overdue =
                      dueAt != null && DateTime.now().isAfter(dueAt);
                  final color = overdue
                      ? const Color(0xFFFF7189)
                      : const Color(0xFF68B7FF);
                  final interval = (timer['intervalMinutes'] as num).toInt();
                  return Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: overdue
                          ? const Color(0x22FF526F)
                          : _logInsetColor(context),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: color.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              overdue
                                  ? Icons.alarm_on_rounded
                                  : Icons.alarm_outlined,
                              color: color,
                              size: 17,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '${timer['personName']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _primaryTextColor(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '$interval min',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${timer['phase']} · ${_timerElapsedLabel(timer)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: overdue
                                ? color
                                : _secondaryTextColor(context),
                            fontSize: 10,
                            fontWeight: overdue
                                ? FontWeight.w800
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: _timerProgress(timer),
                            minHeight: 5,
                            backgroundColor: _logBorderColor(context),
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _timerTimeLabel(timer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 9,
                          ),
                        ),
                        if (widget.isAdmin && overdue) ...[
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _actOnVisitTimer(timer, action: 'snooze'),
                                  style: _logOutlinedButtonStyle(
                                    context,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 6,
                                    ),
                                  ),
                                  child: Text(
                                    'Repetir $interval min',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              IconButton(
                                tooltip: 'Cancelar alerta',
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _actOnVisitTimer(timer, action: 'cancel'),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
          if (_visitTimers.length > _timersPerPage) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mostrando ${(_timerPage - 1) * _timersPerPage + 1}–'
                    '${(_timerPage * _timersPerPage).clamp(0, _visitTimers.length)}'
                    ' de ${_visitTimers.length}',
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 10,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('daily-log-timers-previous-page'),
                  tooltip: 'Página anterior',
                  onPressed: _timerPage > 1
                      ? () => setState(() => _timerPage--)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '$_timerPage / $_timerPageCount',
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  key: const ValueKey('daily-log-timers-next-page'),
                  tooltip: 'Página siguiente',
                  onPressed: _timerPage < _timerPageCount
                      ? () => setState(() => _timerPage++)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final entries = (_data['entries'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final recentEntries = (_data['recentEntries'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final summary = _data['summary'] as Map<String, dynamic>? ?? const {};
    final pages = (_data['pages'] as num?)?.toInt() ?? 1;
    final recentPages = (_data['recentPages'] as num?)?.toInt() ?? 1;
    final total = (_data['total'] as num?)?.toInt() ?? entries.length;
    final recentTotal =
        (_data['recentTotal'] as num?)?.toInt() ?? recentEntries.length;
    final hosts = (_data['hosts'] as List? ?? const [])
        .whereType<String>()
        .toList();
    return _ConnectedPage(
      title: 'Bitácora diaria',
      subtitle: 'Control de llegadas, entradas y salidas',
      user: widget.user,
      trailing: IconButton(
        tooltip: 'Actualizar bitácora',
        onPressed: _loading ? null : _load,
        icon: Icon(
          Icons.refresh_rounded,
          color: _isLightTheme(context)
              ? const Color(0xFF52657D)
              : Colors.white,
        ),
      ),
      child: _loading || _error != null
          ? _loadingOrError(
              context: context,
              loading: _loading,
              error: _error,
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  if (widget.isAdmin && _overdueVisitTimers.isNotEmpty) ...[
                    _overdueTimerBanner(context),
                    const SizedBox(height: 12),
                  ],
                  _logbookPanel(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF087FFF),
                                    Color(0xFF00B8F4),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.flash_on_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Registro rápido',
                                style: TextStyle(
                                  color: _primaryTextColor(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Escanear código QR',
                              onPressed: _scanQr,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Color(0xFF8ACBFF),
                              ),
                            ),
                          ],
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final buttons = [
                              OutlinedButton.icon(
                                onPressed: _enterCode,
                                icon: const Icon(Icons.pin_rounded, size: 17),
                                label: const Text('Introducir código'),
                                style: _logOutlinedButtonStyle(
                                  context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _register,
                                icon: const Icon(Icons.add_rounded, size: 17),
                                label: const Text('Nuevo registro'),
                                style: _logPrimaryButtonStyle(
                                  context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ];
                            if (constraints.maxWidth < 390) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buttons[0],
                                  const SizedBox(height: 8),
                                  buttons[1],
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: buttons[0]),
                                const SizedBox(width: 8),
                                Expanded(child: buttons[1]),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          onChanged: (value) => setState(() {
                            _appointmentQuery = value;
                            _appointmentPage = 1;
                          }),
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar cita de hoy por nombre o empresa',
                            hintStyle: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 11,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF68B7FF),
                            ),
                            filled: true,
                            fillColor: _isLightTheme(context)
                                ? const Color(0xFFF3F6FB)
                                : const Color(0xFF091426),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(13),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_todaysAppointments.length} citas activas para hoy',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 11,
                          ),
                        ),
                        if (_filteredQuickAppointments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No hay citas que coincidan. Para visitas sin cita usa Nuevo registro.',
                              style: TextStyle(
                                color: _secondaryTextColor(context),
                                fontSize: 12,
                              ),
                            ),
                          )
                        else ...[
                          const SizedBox(height: 8),
                          for (final appointment
                              in _filteredQuickAppointments) ...[
                            _QuickAppointmentTile(
                              appointment: appointment,
                              onTap: () => _openAppointment(appointment),
                            ),
                            const SizedBox(height: 7),
                          ],
                          if (_filteredAppointmentPages > 1)
                            _DailyLogPagination(
                              label: 'Citas',
                              total: _todaysAppointments.length,
                              page: _appointmentPage,
                              pages: _filteredAppointmentPages,
                              onPrevious: _appointmentPage > 1
                                  ? () => setState(() => _appointmentPage--)
                                  : null,
                              onNext:
                                  _appointmentPage < _filteredAppointmentPages
                                  ? () => setState(() => _appointmentPage++)
                                  : null,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _logbookPanel(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: Color(0xFF68B7FF),
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Periodo y resumen',
                                style: TextStyle(
                                  color: _primaryTextColor(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: _showHistory,
                                icon: const Icon(
                                  Icons.history_rounded,
                                  size: 16,
                                ),
                                label: const Text('Historial'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _isLightTheme(context)
                                      ? const Color(0xFF1769AA)
                                      : const Color(0xFF8ACBFF),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _showCurrentDay,
                                icon: const Icon(Icons.today_rounded, size: 16),
                                label: const Text('Actualmente'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _isLightTheme(context)
                                      ? const Color(0xFF1769AA)
                                      : const Color(0xFF8ACBFF),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDate(start: true),
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'DESDE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        letterSpacing: .6,
                                      ),
                                    ),
                                    Text(
                                      _displayDate(_dateString(_fromDate)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                style: _logOutlinedButtonStyle(
                                  context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickDate(start: false),
                                icon: const Icon(Icons.event_rounded),
                                label: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'HASTA',
                                      style: TextStyle(
                                        fontSize: 9,
                                        letterSpacing: .6,
                                      ),
                                    ),
                                    Text(
                                      _displayDate(_dateString(_toDate)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                style: _logOutlinedButtonStyle(
                                  context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 7,
                          crossAxisSpacing: 7,
                          childAspectRatio: 2.65,
                          children: [
                            _LogMetric(
                              label: 'Movimientos',
                              value: '${summary['movementCount'] ?? 0}',
                              icon: Icons.swap_horiz_rounded,
                              accent: const Color(0xFF168BFF),
                            ),
                            _LogMetric(
                              label: 'Dentro ahora',
                              value: '${summary['insideNow'] ?? 0}',
                              icon: Icons.groups_rounded,
                              accent: const Color(0xFF00C8D7),
                            ),
                            _LogMetric(
                              label: 'Pendientes',
                              value: '${summary['pendingArrivals'] ?? 0}',
                              icon: Icons.schedule_rounded,
                              accent: const Color(0xFFFFB547),
                            ),
                            _LogMetric(
                              label: 'Salidas',
                              value: '${summary['exits'] ?? 0}',
                              icon: Icons.logout_rounded,
                              accent: const Color(0xFFFF536D),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _logbookPanel(
                    context: context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _searchBox(
                          context: context,
                          hint: 'Buscar persona, empresa, anfitrión o folio',
                          maxLength: 180,
                          onChanged: (value) {
                            setState(() {
                              _query = value;
                              _page = 1;
                              _recentPage = 1;
                            });
                            _searchDebounce?.cancel();
                            _searchDebounce = Timer(
                              const Duration(milliseconds: 300),
                              _load,
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF087FFF)
                                    .withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0x66087FFF),
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Color(0xFF78BFFF),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Filtrar registros',
                                    style: TextStyle(
                                      color: _primaryTextColor(context),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    _activeFilterCount == 0
                                        ? 'Tipo de movimiento, categoría y anfitrión'
                                        : '$_activeFilterCount filtros aplicados',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _secondaryTextColor(context),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_activeFilterCount > 0)
                              IconButton(
                                tooltip: 'Limpiar filtros',
                                visualDensity: VisualDensity.compact,
                                onPressed: _clearFilters,
                                icon: const Icon(
                                  Icons.filter_alt_off_rounded,
                                  size: 17,
                                ),
                                color: const Color(0xFFFF7189),
                              ),
                            IconButton(
                              tooltip: _filtersExpanded
                                  ? 'Ocultar filtros'
                                  : 'Mostrar filtros',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(
                                () => _filtersExpanded = !_filtersExpanded,
                              ),
                              icon: Icon(
                                _filtersExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: const Color(0xFF8ACBFF),
                              ),
                            ),
                          ],
                        ),
                        if (_filtersExpanded) ...[
                          const SizedBox(height: 15),
                          const Divider(color: Color(0x332D83C7), height: 1),
                          const SizedBox(height: 13),
                          Text(
                            'TIPO DE MOVIMIENTO',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in const [
                                ('', 'Todos'),
                                ('Llegada', 'Llegadas'),
                                ('Ingreso', 'Entradas'),
                                ('Retiro', 'Salidas'),
                                ('Observaciones', 'Observaciones'),
                              ])
                                _LogFilterChip(
                                  label: option.$2,
                                  selected: _event == option.$1,
                                  onTap: () {
                                    setState(() {
                                      _event = option.$1;
                                      _page = 1;
                                      _recentPage = 1;
                                    });
                                    _load();
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'CATEGORÍA',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in const [
                                ('', 'Todas'),
                                ('Visitante', 'Visitantes'),
                                ('Contratista', 'Contratistas'),
                                ('Proveedor', 'Proveedores'),
                              ])
                                _LogFilterChip(
                                  label: option.$2,
                                  selected: _category == option.$1,
                                  onTap: () {
                                    setState(() {
                                      _category = option.$1;
                                      _page = 1;
                                      _recentPage = 1;
                                    });
                                    _load();
                                  },
                                ),
                            ],
                          ),
                          if (hosts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'ANFITRIÓN',
                              style: TextStyle(
                                color: _secondaryTextColor(context),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _LogFilterChip(
                                  label: 'Todos',
                                  selected: _host.isEmpty,
                                  onTap: () {
                                    setState(() {
                                      _host = '';
                                      _page = 1;
                                    });
                                    _load();
                                  },
                                ),
                                for (final host in hosts)
                                  _LogFilterChip(
                                    label: host,
                                    selected: _host == host,
                                    onTap: () {
                                      setState(() {
                                        _host = host;
                                        _page = 1;
                                      });
                                      _load();
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DailyLogSectionHeading(
                    kicker: 'REGISTRO OPERATIVO',
                    title: 'Movimientos del periodo',
                    count: '$total ${total == 1 ? 'registro' : 'registros'}',
                  ),
                  const SizedBox(height: 14),
                  if (entries.isEmpty)
                    const _EmptyRecords(
                      message: 'No hay movimientos para este periodo.',
                    )
                  else
                    for (final entry in entries) ...[
                      _DailyLogMovementCard(
                        entry: entry,
                        onTap: () => _openEntry(entry),
                        onQr: () => _openEntryQr(entry),
                        showRegisteredBy: widget.isAdmin,
                        onDelete: widget.isAdmin && !_isPastEntry(entry)
                            ? () => _delete(entry)
                            : null,
                      ),
                      const SizedBox(height: 9),
                    ],
                  if (entries.isNotEmpty)
                    _DailyLogPagination(
                      label: 'Movimientos',
                      total: total,
                      page: _page,
                      pages: pages,
                      onPrevious: _page > 1
                          ? () {
                              setState(() => _page--);
                              _load();
                            }
                          : null,
                      onNext: _page < pages
                          ? () {
                              setState(() => _page++);
                              _load();
                            }
                          : null,
                    ),
                  const SizedBox(height: 12),
                  _DailyLogSectionHeading(
                    kicker: 'EN TIEMPO REAL',
                    title: 'Actividad reciente',
                    count: '$recentTotal movimientos',
                  ),
                  const SizedBox(height: 8),
                  if (recentEntries.isEmpty)
                    const _EmptyRecords(
                      message: 'Aún no hay movimientos recientes.',
                    )
                  else
                    for (final entry in recentEntries) ...[
                      _DailyLogMovementCard(
                        entry: entry,
                        onTap: () => _openEntry(entry),
                        onQr: () => _openEntryQr(entry),
                        showRegisteredBy: widget.isAdmin,
                        onDelete: null,
                      ),
                      const SizedBox(height: 8),
                    ],
                  if (recentPages > 1)
                    _DailyLogPagination(
                      label: 'Actividad reciente',
                      total: recentTotal,
                      page: _recentPage,
                      pages: recentPages,
                      onPrevious: _recentPage > 1
                          ? () {
                              setState(() => _recentPage--);
                              _load();
                            }
                          : null,
                      onNext: _recentPage < recentPages
                          ? () {
                              setState(() => _recentPage++);
                              _load();
                            }
                          : null,
                    ),
                  const SizedBox(height: 12),
                  _visitTimersPanel(context),
                ],
              ),
            ),
    );
  }
}

class _LogFilterChip extends StatelessWidget {
  const _LogFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF087FFF), Color(0xFF00A8E8)],
                )
              : null,
          color: selected ? null : _logInsetColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF40B8FF) : const Color(0x333D9DFF),
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x330087FF),
                    blurRadius: 9,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _secondaryTextColor(context),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _DailyLogSectionHeading extends StatelessWidget {
  const _DailyLogSectionHeading({
    required this.kicker,
    required this.title,
    required this.count,
  });

  final String kicker;
  final String title;
  final String count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
    decoration: BoxDecoration(
      color: _isLightTheme(context) ? Colors.white : null,
      gradient: _isLightTheme(context)
          ? null
          : const LinearGradient(
              colors: [Color(0xFF172844), Color(0xFF0C172B)],
            ),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0x443B9DFF)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker,
                style: const TextStyle(
                  color: Color(0xFF68B7FF),
                  fontSize: 9,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF168BFF).withValues(alpha: .13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x443B9DFF)),
          ),
          child: Text(
            count,
            style: TextStyle(
              color: _isLightTheme(context)
                  ? const Color(0xFF1769AA)
                  : const Color(0xFF9FCBFF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DailyLogPagination extends StatelessWidget {
  const _DailyLogPagination({
    required this.label,
    required this.total,
    required this.page,
    required this.pages,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final int total;
  final int page;
  final int pages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _logDialogColor(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x293D9DFF)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$label: $total',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _secondaryTextColor(context), fontSize: 10),
          ),
        ),
        IconButton(
          tooltip: 'Página anterior',
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
          icon: Icon(
            Icons.chevron_left_rounded,
            color: _isLightTheme(context)
                ? const Color(0xFF1769AA)
                : const Color(0xFF9FCBFF),
          ),
        ),
        Text(
          '$page de $pages',
          style: TextStyle(
            color: _primaryTextColor(context),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
          icon: Icon(
            Icons.chevron_right_rounded,
            color: _isLightTheme(context)
                ? const Color(0xFF1769AA)
                : const Color(0xFF9FCBFF),
          ),
        ),
      ],
    ),
  );
}

class _QuickAppointmentTile extends StatelessWidget {
  const _QuickAppointmentTile({required this.appointment, required this.onTap});

  final Map<String, dynamic> appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _isLightTheme(context)
        ? const Color(0xFFF3F6FB)
        : const Color(0xFF0A1426),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x333B9DFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF168BFF).withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${appointment['time'] ?? '--:--'}',
                style: const TextStyle(
                  color: Color(0xFF8ACBFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${appointment['visitor'] ?? 'Visitante'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${appointment['company'] ?? 'Sin empresa'} · ${appointment['host'] ?? 'Sin anfitrión'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: _isLightTheme(context)
                  ? const Color(0xFF1769AA)
                  : const Color(0xFF8ACBFF),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DailyLogMovementCard extends StatelessWidget {
  const _DailyLogMovementCard({
    required this.entry,
    required this.onTap,
    required this.onQr,
    required this.onDelete,
    this.showRegisteredBy = false,
  });

  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  final VoidCallback onQr;
  final VoidCallback? onDelete;
  final bool showRegisteredBy;

  @override
  Widget build(BuildContext context) {
    final isLight = _isLightTheme(context);
    final event = '${entry['event'] ?? 'Observaciones'}';
    final accent = switch (event) {
      'Ingreso' => const Color(0xFF60C6FF),
      'Retiro' => const Color(0xFFFF7189),
      'Llegada' => const Color(0xFF54D6B2),
      _ => const Color(0xFF8ACBFF),
    };
    final reference = '${entry['details'] ?? ''}'.contains('Folio ')
        ? '${entry['details']}'.split('Folio ').last.split(' ').first
        : '';
    final appointmentId = entry['appointmentId'];
    return Material(
      color: isLight ? Colors.white : const Color(0xFF111D35),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: accent.withValues(alpha: .32)),
            color: isLight ? Colors.white : null,
            gradient: isLight
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF17243D), Color(0xFF0C1628)],
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      switch (event) {
                        'Ingreso' => Icons.login_rounded,
                        'Retiro' => Icons.logout_rounded,
                        'Llegada' => Icons.call_received_rounded,
                        _ => Icons.notes_rounded,
                      },
                      color: accent,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry['person'] ?? 'Visitante'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${entry['company'] ?? 'Público general'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 10,
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
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: .38)),
                    ),
                    child: Text(
                      event == 'Ingreso'
                          ? 'Entrada'
                          : event == 'Retiro'
                          ? 'Salida'
                          : event,
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _LogInfoBadge(
                    icon: Icons.schedule_rounded,
                    label: '${entry['date'] ?? ''} · ${entry['time'] ?? ''}',
                  ),
                  _LogInfoBadge(
                    icon: Icons.person_outline_rounded,
                    label: 'Anfitrión: ${entry['host'] ?? 'N/A'}',
                  ),
                  if (reference.isNotEmpty)
                    _LogInfoBadge(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Folio $reference',
                    ),
                ],
              ),
              if ('${entry['details'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  '${entry['details']}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 10,
                  ),
                ),
              ],
              if (showRegisteredBy &&
                  '${entry['actorName'] ?? ''}'.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Registró: ${entry['actorName']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (appointmentId is num)
                      IconButton(
                        tooltip: 'Ver QR de visita',
                        visualDensity: VisualDensity.compact,
                        onPressed: onQr,
                        icon: const Icon(
                          Icons.qr_code_2_rounded,
                          color: Color(0xFF8ACBFF),
                          size: 20,
                        ),
                      ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Eliminar movimiento',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFFF7189),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ] else if (appointmentId is num || onDelete != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (appointmentId is num)
                      IconButton(
                        tooltip: 'Ver QR de visita',
                        visualDensity: VisualDensity.compact,
                        onPressed: onQr,
                        icon: const Icon(
                          Icons.qr_code_2_rounded,
                          color: Color(0xFF8ACBFF),
                          size: 20,
                        ),
                      ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Eliminar movimiento',
                        visualDensity: VisualDensity.compact,
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFFF7189),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LogInfoBadge extends StatelessWidget {
  const _LogInfoBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: _isLightTheme(context)
          ? const Color(0xFFF3F6FB)
          : const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0x223D9DFF)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF68B7FF)),
        const SizedBox(width: 5),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _secondaryTextColor(context), fontSize: 9),
        ),
      ],
    ),
  );
}

class _LogMetric extends StatelessWidget {
  const _LogMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label, value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: _isLightTheme(context) ? const Color(0xFFF3F7FC) : null,
      gradient: _isLightTheme(context)
          ? null
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF142B49), Color(0xFF0D1D33)],
            ),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: accent.withValues(alpha: .42)),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: .09),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          key: ValueKey('log-metric-icon-$label'),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 17,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: accent.withValues(alpha: .45), blurRadius: 9),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DailyLogEntryForm extends StatefulWidget {
  const _DailyLogEntryForm({
    required this.staff,
    required this.visitors,
    required this.date,
  });
  final List<Map<String, dynamic>> staff;
  final List<Map<String, dynamic>> visitors;
  final DateTime date;
  @override
  State<_DailyLogEntryForm> createState() => _DailyLogEntryFormState();
}

class _DailyLogEntryFormState extends State<_DailyLogEntryForm> {
  final _person = TextEditingController();
  final _details = TextEditingController();
  String _kind = 'Externo';
  Map<String, dynamic>? _selectedStaff;
  Map<String, dynamic>? _selectedVisitor;

  String get _selectedPerson => _kind == 'Externo'
      ? '${_selectedStaff?['fullName'] ?? ''}'
      : _kind == 'Visitante'
      ? '${_selectedVisitor?['fullName'] ?? ''}'
      : _person.text.trim();

  Future<void> _selectRecord(
    List<Map<String, dynamic>> options, {
    required bool staff,
  }) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _LogRecordPicker(
        title: staff ? 'Personal externo' : 'Visitante registrado',
        subtitle: staff
            ? 'Selecciona a la persona que llega'
            : 'Selecciona a la persona visitante',
        records: options,
        companyKey: staff ? 'companyName' : null,
        metaKey: staff ? 'relationshipType' : 'phone',
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (staff) {
        _selectedStaff = selected;
      } else {
        _selectedVisitor = selected;
      }
    });
  }

  @override
  void dispose() {
    _person.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRecord = _kind == 'Externo'
        ? _selectedStaff
        : _selectedVisitor;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        decoration: BoxDecoration(
          color: _isLightTheme(context) ? Colors.white : null,
          gradient: _isLightTheme(context)
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172844), Color(0xFF091426)],
                ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0x663D9DFF)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _LogDialogHeader(
                icon: Icons.how_to_reg_rounded,
                title: 'Registrar llegada',
                subtitle: 'Captura una visita sin cita programada.',
              ),
              const SizedBox(height: 16),
              Text(
                '¿A quién vas a registrar?',
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final option in const [
                    ('Externo', Icons.badge_outlined),
                    ('Visitante', Icons.person_outline_rounded),
                    ('Manual', Icons.edit_note_rounded),
                  ])
                    _LogChoiceChip(
                      label: option.$1,
                      icon: option.$2,
                      selected: _kind == option.$1,
                      onTap: () => setState(() {
                        _kind = option.$1;
                        _selectedStaff = null;
                        _selectedVisitor = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_kind == 'Externo')
                _LogRecordSelector(
                  icon: Icons.engineering_outlined,
                  title: _selectedStaff == null
                      ? 'Elegir personal externo'
                      : '${_selectedStaff!['fullName']}',
                  subtitle: _selectedStaff == null
                      ? '${widget.staff.length} personas disponibles'
                      : '${_selectedStaff!['companyName'] ?? 'Empresa externa'} · ${_selectedStaff!['relationshipType'] ?? 'Contratista'}',
                  onTap: widget.staff.isEmpty
                      ? null
                      : () => _selectRecord(widget.staff, staff: true),
                )
              else if (_kind == 'Visitante')
                _LogRecordSelector(
                  icon: Icons.person_search_rounded,
                  title: _selectedVisitor == null
                      ? 'Elegir visitante registrado'
                      : '${_selectedVisitor!['fullName']}',
                  subtitle: _selectedVisitor == null
                      ? '${widget.visitors.length} personas disponibles'
                      : '${_selectedVisitor!['phone'] ?? 'Sin teléfono'} · Público general',
                  onTap: widget.visitors.isEmpty
                      ? null
                      : () => _selectRecord(widget.visitors, staff: false),
                )
              else
                _LogTextField(
                  controller: _person,
                  label: 'Nombre de la persona',
                  hint: 'Escribe el nombre completo',
                  icon: Icons.person_outline_rounded,
                  onChanged: (_) => setState(() {}),
                ),
              if (selectedRecord == null &&
                  _kind != 'Manual' &&
                  (_kind == 'Externo' ? widget.staff : widget.visitors).isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No hay registros disponibles. Usa captura manual para continuar.',
                    style: const TextStyle(
                      color: Color(0xFFFFC078),
                      fontSize: 11,
                    ),
                  ),
                ),
              const SizedBox(height: 11),
              _LogTextField(
                controller: _details,
                label: 'Motivo o notas',
                hint: 'Agrega un detalle para recepción (opcional)',
                icon: Icons.notes_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: 11),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _logInsetColor(context),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0x293D9DFF)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFF68B7FF),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este registro crea una llegada; la entrada se confirma por separado.',
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: _logOutlinedButtonStyle(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _selectedPerson.isEmpty
                          ? null
                          : () {
                              final now = TimeOfDay.now();
                              Navigator.pop(context, <String, Object?>{
                                'event': 'Llegada',
                                'date': _dateString(widget.date),
                                'time':
                                    '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                                'personName': _selectedPerson,
                                'details': _details.text.trim(),
                                'appointmentId': null,
                                'externalStaffId': _kind == 'Externo'
                                    ? (_selectedStaff?['id'])
                                    : null,
                                'visitorRecordId': _kind == 'Visitante'
                                    ? (_selectedVisitor?['id'])
                                    : null,
                                'sourceEntryId': null,
                              });
                            },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Registrar'),
                      style: _logPrimaryButtonStyle(context),
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

class _LogDialogHeader extends StatelessWidget {
  const _LogDialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF168BFF).withValues(alpha: .15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xFF73BEFF)),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: _primaryTextColor(context),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: 'Cerrar',
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.close_rounded, color: _secondaryTextColor(context)),
      ),
    ],
  );
}

class _LogChoiceChip extends StatelessWidget {
  const _LogChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : _logInsetColor(context),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? colors.primary : const Color(0x333D9DFF),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected
                    ? colors.onPrimary
                    : _isLightTheme(context)
                    ? const Color(0xFF1769AA)
                    : const Color(0xFFB4DFFF),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? colors.onPrimary
                      : _primaryTextColor(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogRecordSelector extends StatelessWidget {
  const _LogRecordSelector({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: _logInsetColor(context),
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x443D9DFF)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF69B8FF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8ACBFF)),
          ],
        ),
      ),
    ),
  );
}

class _LogTextField extends StatelessWidget {
  const _LogTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: _secondaryTextColor(context),
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        style: TextStyle(color: _primaryTextColor(context), fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _secondaryTextColor(context),
            fontSize: 11,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF68B7FF), size: 19),
          filled: true,
          fillColor: _logInsetColor(context),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: _logBorderColor(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: _logBorderColor(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFF4AA8FF)),
          ),
        ),
      ),
    ],
  );
}

class _LogRecordPicker extends StatefulWidget {
  const _LogRecordPicker({
    required this.title,
    required this.subtitle,
    required this.records,
    required this.companyKey,
    required this.metaKey,
  });

  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> records;
  final String? companyKey;
  final String? metaKey;

  @override
  State<_LogRecordPicker> createState() => _LogRecordPickerState();
}

class _LogRecordPickerState extends State<_LogRecordPicker> {
  String _query = '';
  late final TextEditingController _queryController = TextEditingController(
    text: _query,
  );

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.records.where((record) {
      final name = '${record['fullName'] ?? ''}';
      final company = widget.companyKey == null
          ? ''
          : '${record[widget.companyKey] ?? ''}';
      return '$name $company'.toLowerCase().contains(query);
    }).toList();
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        decoration: BoxDecoration(
          color: _logDialogColor(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 15, 17, 10),
              child: _LogDialogHeader(
                icon: Icons.people_alt_outlined,
                title: widget.title,
                subtitle: widget.subtitle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _LogTextField(
                controller: _queryController,
                label: 'Buscar persona',
                hint: 'Nombre o empresa',
                icon: Icons.search_rounded,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 9),
            Flexible(
              child: filtered.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(
                        'No hay personas que coincidan.',
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 7),
                      itemBuilder: (context, index) {
                        final record = filtered[index];
                        return _LogRecordSelector(
                          icon: Icons.person_outline_rounded,
                          title: '${record['fullName'] ?? 'Sin nombre'}',
                          subtitle:
                              '${widget.companyKey == null ? '' : '${record[widget.companyKey] ?? ''} · '}${widget.metaKey == null ? '' : record[widget.metaKey] ?? ''}',
                          onTap: () => Navigator.pop(context, record),
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

class _AppointmentReceptionDialog extends StatefulWidget {
  const _AppointmentReceptionDialog({
    required this.appointment,
    required this.authService,
    required this.onRecordMovement,
    this.externalStaffId,
  });

  final Map<String, dynamic> appointment;
  final AuthService authService;
  final Future<bool> Function(
    String event,
    String person, {
    int? externalStaffId,
  })
  onRecordMovement;
  final int? externalStaffId;

  @override
  State<_AppointmentReceptionDialog> createState() =>
      _AppointmentReceptionDialogState();
}

class _AppointmentReceptionDialogState
    extends State<_AppointmentReceptionDialog> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _employees = [];
  bool _checklistLoading = false;
  bool _checklistSaving = false;
  bool _movementSaving = false;
  String? _checklistError;
  Map<String, dynamic>? _equipmentDeclaration;

  @override
  void initState() {
    super.initState();
    final id = widget.appointment['id'];
    if (widget.appointment['businessPartnerId'] is num && id is num) {
      _loadEmployees(id.toInt());
    }
    final declarationId = widget.appointment['equipmentDeclarationId'];
    if (declarationId is num && declarationId > 0) {
      _loadEquipmentDeclaration(declarationId.toInt());
    }
  }

  Future<void> _loadEquipmentDeclaration(int declarationId) async {
    setState(() {
      _checklistLoading = true;
      _checklistError = null;
    });
    try {
      final response = await widget.authService.getEquipmentDeclaration(
        declarationId,
      );
      final declaration = response['declaration'];
      if (declaration is! Map<String, dynamic>) {
        throw const AuthApiException(
          'No se encontró la declaración de equipo de esta cita.',
        );
      }
      if (!mounted) return;
      setState(() {
        _equipmentDeclaration = declaration;
        _checklistLoading = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _checklistError = error.message;
        _checklistLoading = false;
      });
    }
  }

  bool get _entryChecklistComplete =>
      widget.appointment['equipmentEntryChecklistComplete'] == true;

  bool get _exitChecklistComplete =>
      widget.appointment['equipmentExitChecklistComplete'] == true;

  String? get _pendingChecklistPhase {
    if (_equipmentDeclaration?['status'] != 'Enviada') return null;
    final status = '${widget.appointment['status'] ?? ''}';
    if (status == 'En proceso' && !_entryChecklistComplete) return 'entrada';
    if (status == 'Dentro' &&
        _entryChecklistComplete &&
        !_exitChecklistComplete) {
      return 'salida';
    }
    return null;
  }

  Future<bool> _openChecklist(String phase) async {
    final declaration = _equipmentDeclaration;
    if (declaration == null || _checklistSaving) return false;
    final items = (declaration['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (items.isEmpty) {
      _showMessage(
        context,
        'La declaración todavía no incluye artículos para verificar.',
        error: true,
      );
      return false;
    }
    final inspectionItems = await showDialog<List<Map<String, Object?>>>(
      context: context,
      builder: (_) => _AppointmentEquipmentChecklistDialog(
        declaration: declaration,
        phase: phase,
      ),
    );
    if (inspectionItems == null || !mounted) return false;
    final id = declaration['id'];
    if (id is! num || id <= 0) {
      _showMessage(
        context,
        'La declaración seleccionada no es válida.',
        error: true,
      );
      return false;
    }
    setState(() {
      _checklistSaving = true;
      _checklistError = null;
    });
    try {
      await widget.authService.submitEquipmentInspection(
        id.toInt(),
        phase,
        inspectionItems,
      );
      if (!mounted) return false;
      setState(() {
        if (phase == 'entrada') {
          widget.appointment['equipmentEntryChecklistComplete'] = true;
        } else {
          widget.appointment['equipmentExitChecklistComplete'] = true;
        }
        _equipmentDeclaration = {
          ...declaration,
          'inspections': [
            ...(declaration['inspections'] as List? ?? const []),
            {
              'phase': phase == 'entrada' ? 'Entrada' : 'Salida',
              'status': 'Completada',
            },
          ],
        };
        _checklistSaving = false;
      });
      _showMessage(
        context,
        phase == 'entrada'
            ? 'Checklist de entrada completado.'
            : 'Checklist de salida completado.',
      );
      return true;
    } on AuthApiException catch (error) {
      if (!mounted) return false;
      setState(() {
        _checklistSaving = false;
        _checklistError = error.message;
      });
      _showMessage(context, error.message, error: true);
      return false;
    }
  }

  Future<void> _loadEmployees(int appointmentId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final employees = await widget.authService.getAppointmentEmployees(
        appointmentId,
      );
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _loading = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  String? _eventForStatus(String status) => switch (status) {
    'Pendiente' => 'Llegada',
    'En proceso' => 'Ingreso',
    'Dentro' => 'Retiro',
    _ => null,
  };

  String _actionLabel(String event) => switch (event) {
    'Llegada' => 'Registrar llegada',
    'Ingreso' => 'Dar entrada',
    'Retiro' => 'Registrar salida',
    _ => 'Registrar movimiento',
  };

  bool _canEnter() =>
      widget.appointment['equipmentChecklistRequired'] != true ||
      widget.appointment['equipmentEntryChecklistComplete'] == true;

  bool _canExit() =>
      widget.appointment['equipmentChecklistRequired'] != true ||
      widget.appointment['equipmentExitChecklistComplete'] == true;

  bool _canStartEntry() =>
      widget.appointment['equipmentChecklistRequired'] != true ||
      (_equipmentDeclaration?['status'] == 'Enviada' &&
          !_checklistLoading &&
          !_checklistSaving);

  bool _canStartExit({required bool arrivedWithoutEntry}) =>
      arrivedWithoutEntry ||
      widget.appointment['equipmentChecklistRequired'] != true ||
      (_equipmentDeclaration?['status'] == 'Enviada' &&
          _entryChecklistComplete &&
          !_checklistLoading &&
          !_checklistSaving);

  Future<void> _performMovement({
    required String event,
    required String person,
    int? externalStaffId,
    Map<String, dynamic>? employee,
  }) async {
    if (_movementSaving || _checklistSaving) return;

    final employeeStatus =
        '${employee?['status'] ?? widget.appointment['status'] ?? ''}';
    if (event == 'Ingreso' &&
        widget.appointment['equipmentChecklistRequired'] == true &&
        !_entryChecklistComplete) {
      if (!_canStartEntry()) {
        _showMessage(
          context,
          'El contratista debe enviar su declaración antes de completar la verificación.',
          error: true,
        );
        return;
      }
      if (!await _openChecklist('entrada') || !mounted) return;
    }

    if (event == 'Retiro' &&
        employeeStatus == 'Dentro' &&
        widget.appointment['equipmentChecklistRequired'] == true &&
        !_exitChecklistComplete) {
      if (!_canStartExit(arrivedWithoutEntry: false)) {
        _showMessage(
          context,
          'Completa primero la verificación de entrada para revisar el equipo resguardado.',
          error: true,
        );
        return;
      }
      if (!await _openChecklist('salida')) return;
    }

    setState(() => _movementSaving = true);
    final saved = await widget.onRecordMovement(
      event,
      person,
      externalStaffId: externalStaffId,
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _movementSaving = false);
      return;
    }

    final nextStatus = switch (event) {
      'Llegada' => 'En proceso',
      'Ingreso' => 'Dentro',
      'Retiro' => 'Retirado',
      _ => employeeStatus,
    };
    if (employee != null) {
      employee['status'] = nextStatus;
    } else {
      widget.appointment['status'] = nextStatus;
    }
    setState(() => _movementSaving = false);

    final appointmentId = widget.appointment['id'];
    if (employee != null && appointmentId is num) {
      await _loadEmployees(appointmentId.toInt());
    }
  }

  List<Map<String, dynamic>> get _visibleEmployees {
    final staffId = widget.externalStaffId;
    if (staffId == null) return _employees;
    return _employees.where((employee) => employee['id'] == staffId).toList();
  }

  Widget _movementAction({
    required String status,
    required String person,
    int? externalStaffId,
    Map<String, dynamic>? employee,
  }) {
    if (status == 'En proceso' &&
        widget.appointment['businessPartnerId'] is num) {
      final canEnter = _canStartEntry();
      final canLeave = _canStartExit(arrivedWithoutEntry: true);
      return Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: !canEnter || _movementSaving
                  ? null
                  : () => _performMovement(
                      event: 'Ingreso',
                      person: person,
                      externalStaffId: externalStaffId,
                      employee: employee,
                    ),
              style: _logPrimaryButtonStyle(
                context,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
              ),
              child: const Text(
                'Dar entrada',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: !canLeave || _movementSaving
                  ? null
                  : () => _performMovement(
                      event: 'Retiro',
                      person: person,
                      externalStaffId: externalStaffId,
                      employee: employee,
                    ),
              style: _logOutlinedButtonStyle(
                context,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
              ),
              child: const Text(
                'Registrar salida',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      );
    }
    final event = _eventForStatus(status);
    if (event == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _logInsetColor(context),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          status == 'Retirado' ? 'Visita concluida' : status,
          style: TextStyle(color: _secondaryTextColor(context), fontSize: 9),
        ),
      );
    }
    final blocked =
        (event == 'Ingreso' && !_canStartEntry()) ||
        (event == 'Retiro' &&
            !_canStartExit(arrivedWithoutEntry: status == 'En proceso')) ||
        _movementSaving;
    return FilledButton(
      onPressed: blocked
          ? null
          : () => _performMovement(
              event: event,
              person: person,
              externalStaffId: externalStaffId,
              employee: employee,
            ),
      style: _logPrimaryButtonStyle(
        context,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      ),
      child: Text(
        _actionLabel(event),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointment = widget.appointment;
    final appointmentStatus = '${appointment['status'] ?? 'Pendiente'}';
    final partner = appointment['businessPartnerId'] is num;
    final title = partner
        ? '${appointment['company'] ?? 'Empresa externa'}'
        : '${appointment['visitor'] ?? 'Visitante'}';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * .86,
        ),
        decoration: BoxDecoration(
          color: _logDialogColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _logBorderColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _isLightTheme(context) ? .08 : .4,
              ),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, color: const Color(0xFFE32636)),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 11, 8, 10),
              child: _LogDialogHeader(
                icon: Icons.event_available_rounded,
                title: 'Cita programada',
                subtitle:
                    '${appointment['date'] ?? ''} · ${appointment['time'] ?? ''}',
              ),
            ),
            Divider(height: 1, color: _logBorderColor(context)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _logInsetColor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _logBorderColor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              partner
                                  ? Icons.business_rounded
                                  : Icons.person_rounded,
                              color: const Color(0xFF71BFFF),
                              size: 20,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: _primaryTextColor(context),
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _AppointmentStatusBadge(
                              label: appointmentStatus,
                              color: appointmentStatus == 'Cancelada'
                                  ? const Color(0xFFFF7189)
                                  : const Color(0xFF65C8A6),
                            ),
                          ],
                        ),
                        const SizedBox(height: 11),
                        Divider(height: 1, color: _logBorderColor(context)),
                        const SizedBox(height: 9),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              color: _secondaryTextColor(context),
                              size: 16,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Anfitrión: ${appointment['host'] ?? 'Sin asignar'}',
                                style: TextStyle(
                                  color: _secondaryTextColor(context),
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ('${appointment['reason'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                color: _secondaryTextColor(context),
                                size: 16,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'Motivo: ${appointment['reason']}',
                                  style: TextStyle(
                                    color: _secondaryTextColor(context),
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (appointment['equipmentChecklistRequired'] == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _logInsetColor(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _logBorderColor(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.fact_check_rounded,
                                size: 18,
                                color: Color(0xFF168BFF),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'CHECKLIST DE EQUIPO',
                                  style: TextStyle(
                                    color: _primaryTextColor(context),
                                    fontSize: 10,
                                    letterSpacing: .7,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (_entryChecklistComplete)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: Color(0xFF18A889),
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _checklistLoading
                                ? 'Cargando los artículos de la declaración…'
                                : _checklistError ??
                                      (_equipmentDeclaration == null
                                          ? 'No se encontró la declaración de equipo de esta cita.'
                                          : _equipmentDeclaration!['status'] !=
                                                'Enviada'
                                          ? 'El contratista aún debe enviar su declaración de equipo.'
                                          : _entryChecklistComplete
                                          ? _exitChecklistComplete
                                                ? 'Inspección de entrada y salida completadas.'
                                                : 'Entrada completada${_pendingChecklistPhase == 'salida' ? '. Verifica los artículos antes de registrar la salida.' : '.'}'
                                          : 'Verifica cada artículo antes de autorizar la entrada. Puedes indicar cuáles quedarán resguardados en recepción.'),
                            style: TextStyle(
                              color: _checklistError != null
                                  ? const Color(0xFFFF7189)
                                  : _secondaryTextColor(context),
                              fontSize: 10,
                              height: 1.4,
                            ),
                          ),
                          if (_checklistError != null &&
                              appointment['equipmentDeclarationId'] is num) ...[
                            const SizedBox(height: 7),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _checklistLoading
                                    ? null
                                    : () => _loadEquipmentDeclaration(
                                        (appointment['equipmentDeclarationId']
                                                as num)
                                            .toInt(),
                                      ),
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 15,
                                ),
                                label: const Text('Reintentar'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF168BFF),
                                  textStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_pendingChecklistPhase != null) ...[
                            const SizedBox(height: 9),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _checklistLoading || _checklistSaving
                                    ? null
                                    : () => _openChecklist(
                                        _pendingChecklistPhase!,
                                      ),
                                icon: _checklistSaving
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _pendingChecklistPhase == 'entrada'
                                            ? Icons.login_rounded
                                            : Icons.assignment_return_rounded,
                                        size: 16,
                                      ),
                                label: Text(
                                  _pendingChecklistPhase == 'entrada'
                                      ? 'Completar checklist de entrada'
                                      : 'Completar checklist de salida',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: _logPrimaryButtonStyle(
                                  context,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (appointment['status'] == 'En proceso' &&
                              !_canEnter() &&
                              !_checklistLoading &&
                              _equipmentDeclaration?['status'] == 'Enviada')
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                'El ingreso se habilitará al completar este checklist.',
                                style: TextStyle(
                                  color: const Color(0xFFE0A437),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (appointment['status'] == 'Dentro' &&
                              !_canExit() &&
                              _entryChecklistComplete &&
                              !_checklistLoading &&
                              _equipmentDeclaration?['status'] == 'Enviada')
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                'La salida se habilitará al verificar los artículos resguardados.',
                                style: TextStyle(
                                  color: const Color(0xFFE0A437),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (partner) ...[
                    const SizedBox(height: 13),
                    Text(
                      'PERSONAL EXTERNO',
                      style: TextStyle(
                        color: _isLightTheme(context)
                            ? const Color(0xFF1769AA)
                            : const Color(0xFF78BFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF7189),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          'No se pudo cargar el personal: $_error',
                          style: const TextStyle(
                            color: Color(0xFFFFA1B2),
                            fontSize: 10,
                          ),
                        ),
                      )
                    else if (_visibleEmployees.isEmpty)
                      Text(
                        'No encontramos a esa persona entre el personal asociado a la cita.',
                        style: TextStyle(
                          color: _secondaryTextColor(context),
                          fontSize: 11,
                        ),
                      )
                    else
                      for (final employee in _visibleEmployees) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: _logInsetColor(context),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: _logBorderColor(context)),
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
                                      color: const Color(0xFF168BFF)
                                          .withValues(alpha: .14),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline_rounded,
                                      color: Color(0xFF78BFFF),
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${employee['fullName'] ?? 'Personal externo'}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _primaryTextColor(context),
                                            fontSize: 12,
                                            height: 1.2,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${employee['status'] ?? 'Pendiente'}',
                                          style: TextStyle(
                                            color: _secondaryTextColor(context),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: _movementAction(
                                  status:
                                      '${employee['status'] ?? 'Pendiente'}',
                                  person: '${employee['fullName'] ?? title}',
                                  externalStaffId: employee['id'] is num
                                      ? (employee['id'] as num).toInt()
                                      : null,
                                  employee: employee,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    if (appointment['equipmentChecklistRequired'] == true &&
                        !_canEnter())
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFC078),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Text(
                          'Completa el checklist de equipo de la cita antes de registrar la entrada.',
                          style: TextStyle(
                            color: Color(0xFFFFD29A),
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ] else ...[
                    const SizedBox(height: 13),
                    _movementAction(
                      status: appointmentStatus,
                      person: '${appointment['visitor'] ?? 'Visitante'}',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentEquipmentChecklistDialog extends StatefulWidget {
  const _AppointmentEquipmentChecklistDialog({
    required this.declaration,
    required this.phase,
  });

  final Map<String, dynamic> declaration;
  final String phase;

  @override
  State<_AppointmentEquipmentChecklistDialog> createState() =>
      _AppointmentEquipmentChecklistDialogState();
}

class _AppointmentEquipmentChecklistDialogState
    extends State<_AppointmentEquipmentChecklistDialog> {
  final Set<int> _checkedIds = {};
  final Set<int> _retainedIds = {};
  final Set<int> _returnedIds = {};

  List<Map<String, dynamic>> get _items =>
      (widget.declaration['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  bool _isItemComplete(int id) =>
      _checkedIds.contains(id) ||
      (widget.phase == 'entrada' && _retainedIds.contains(id));

  int get _completedItemCount => _items.where((item) {
    final id = item['id'];
    return id is num && _isItemComplete(id.toInt());
  }).length;

  Set<int> get _itemsKeptAtReception {
    final retained = <int>{};
    for (final inspection
        in (widget.declaration['inspections'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()) {
      if (inspection['phase'] != 'Entrada') continue;
      for (final item
          in (inspection['items'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()) {
        final itemId = item['declarationItemId'];
        if (item['keepAtReception'] == true && itemId is num) {
          retained.add(itemId.toInt());
        }
      }
    }
    return retained;
  }

  List<Map<String, Object?>> _buildInspectionItems() => _items.map((item) {
    final id = (item['id'] as num).toInt();
    return <String, Object?>{
      'declarationItemId': id,
      'quantity': (item['quantity'] as num).toInt(),
      'product': '${item['product'] ?? ''}',
      'brand': '${item['brand'] ?? ''}',
      'model': '${item['model'] ?? ''}',
      'serialNumber': '${item['serialNumber'] ?? ''}',
      'color': '${item['color'] ?? ''}',
      'notes': '',
      'incident': false,
      'checked': _isItemComplete(id),
      'keepAtReception': widget.phase == 'entrada' && _retainedIds.contains(id),
      'returnedToVisitor':
          widget.phase == 'salida' && _returnedIds.contains(id),
    };
  }).toList();

  @override
  Widget build(BuildContext context) {
    final isEntry = widget.phase == 'entrada';
    final retainedAtReception = _itemsKeptAtReception;
    final isLight = _isLightTheme(context);
    final canComplete =
        _items.isNotEmpty &&
        _items.every((item) {
          final id = item['id'];
          return id is num && _isItemComplete(id.toInt());
        });
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * .86,
        ),
        decoration: BoxDecoration(
          color: _logDialogColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _logBorderColor(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? .1 : .38),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, color: const Color(0xFFE32636)),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 15, 10, 13),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF168BFF).withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isEntry
                          ? Icons.login_rounded
                          : Icons.assignment_return_rounded,
                      color: const Color(0xFF168BFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEntry
                              ? 'CHECKLIST DE ENTRADA'
                              : 'CHECKLIST DE SALIDA',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF1769AA)
                                : const Color(0xFF78BFFF),
                            fontSize: 9,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.declaration['personName'] ?? 'Personal externo'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _logBorderColor(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 11, 17, 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEntry
                          ? 'Marca cada artículo como verificado o indica que se resguarda en recepción.'
                          : 'Confirma cada artículo y registra las devoluciones del resguardo.',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_completedItemCount/${_items.length}',
                    style: const TextStyle(
                      color: Color(0xFF168BFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(15, 6, 15, 12),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final rawId = item['id'];
                  if (rawId is! num) return const SizedBox.shrink();
                  final id = rawId.toInt();
                  final retained = retainedAtReception.contains(id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _logInsetColor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isItemComplete(id)
                            ? const Color(0x663EB98E)
                            : _logBorderColor(context),
                      ),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() {
                            if (_checkedIds.remove(id)) return;
                            _checkedIds.add(id);
                            _retainedIds.remove(id);
                          }),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _checkedIds.contains(id),
                                activeColor: const Color(0xFF18A889),
                                onChanged: (value) => setState(() {
                                  if (value == true) {
                                    _checkedIds.add(id);
                                    _retainedIds.remove(id);
                                  } else {
                                    _checkedIds.remove(id);
                                  }
                                }),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['itemType'] ?? 'Artículo'} · ${item['quantity'] ?? 0} × ${item['product'] ?? ''}',
                                      style: TextStyle(
                                        color: _primaryTextColor(context),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${item['brand'] ?? ''} · ${item['model'] ?? ''} · Serie: ${item['serialNumber'] ?? '—'} · ${item['color'] ?? '—'}',
                                      style: TextStyle(
                                        color: _secondaryTextColor(context),
                                        fontSize: 9,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isEntry || retained)
                          Padding(
                            padding: const EdgeInsets.only(left: 44, top: 4),
                            child: InkWell(
                              onTap: () => setState(() {
                                final selection = isEntry
                                    ? _retainedIds
                                    : _returnedIds;
                                if (!selection.add(id)) {
                                  selection.remove(id);
                                } else if (isEntry) {
                                  _checkedIds.remove(id);
                                }
                              }),
                              child: Row(
                                children: [
                                  Icon(
                                    (isEntry ? _retainedIds : _returnedIds)
                                            .contains(id)
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 18,
                                    color: isEntry
                                        ? const Color(0xFFE0A437)
                                        : const Color(0xFF18A889),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      isEntry
                                          ? 'Resguardar en recepción'
                                          : 'Confirmar devolución al visitante',
                                      style: TextStyle(
                                        color: _secondaryTextColor(context),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
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
                },
              ),
            ),
            Divider(height: 1, color: _logBorderColor(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 13),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: _logOutlinedButtonStyle(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: canComplete
                          ? () =>
                                Navigator.pop(context, _buildInspectionItems())
                          : null,
                      icon: const Icon(Icons.verified_rounded, size: 17),
                      label: const Text('Confirmar revisión'),
                      style: _logPrimaryButtonStyle(context),
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

class _DailyLogEntryDetailDialog extends StatefulWidget {
  const _DailyLogEntryDetailDialog({
    required this.entry,
    required this.authService,
    required this.showRegisteredBy,
    required this.onRecordMovement,
    this.readOnly = false,
    this.appointment,
  });

  final Map<String, dynamic> entry;
  final Map<String, dynamic>? appointment;
  final AuthService authService;
  final bool showRegisteredBy;
  final Future<bool> Function(String event) onRecordMovement;
  final bool readOnly;

  @override
  State<_DailyLogEntryDetailDialog> createState() =>
      _DailyLogEntryDetailDialogState();
}

class _DailyLogEntryDetailDialogState
    extends State<_DailyLogEntryDetailDialog> {
  bool _loadingChecklist = false;
  bool _savingChecklist = false;
  bool _savingMovement = false;
  String? _checklistError;
  Map<String, dynamic>? _declaration;

  bool get _requiresChecklist =>
      widget.appointment?['equipmentChecklistRequired'] == true;

  bool get _entryComplete =>
      widget.appointment?['equipmentEntryChecklistComplete'] == true;

  bool get _exitComplete =>
      widget.appointment?['equipmentExitChecklistComplete'] == true;

  String? get _checklistPhase {
    if (widget.readOnly) return null;
    final event = '${widget.entry['event'] ?? ''}';
    if (event == 'Llegada' && !_entryComplete) return 'entrada';
    if (event == 'Ingreso' && _entryComplete && !_exitComplete) return 'salida';
    return null;
  }

  @override
  void initState() {
    super.initState();
    final id = widget.appointment?['equipmentDeclarationId'];
    if (id is num && id > 0) _loadDeclaration(id.toInt());
  }

  Future<void> _loadDeclaration(int id) async {
    setState(() {
      _loadingChecklist = true;
      _checklistError = null;
    });
    try {
      final response = await widget.authService.getEquipmentDeclaration(id);
      final declaration = response['declaration'];
      if (declaration is! Map<String, dynamic>) {
        throw const AuthApiException(
          'No se encontró la declaración de equipo de esta cita.',
        );
      }
      if (!mounted) return;
      setState(() {
        _declaration = declaration;
        _loadingChecklist = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _checklistError = error.message;
        _loadingChecklist = false;
      });
    }
  }

  Future<bool> _completeChecklist(String phase) async {
    final declaration = widget.readOnly ? null : _declaration;
    if (declaration == null || _savingChecklist) return false;
    final items = (declaration['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (items.isEmpty) {
      _showMessage(
        context,
        'La declaración todavía no incluye artículos para verificar.',
        error: true,
      );
      return false;
    }
    final result = await showDialog<List<Map<String, Object?>>>(
      context: context,
      builder: (_) => _AppointmentEquipmentChecklistDialog(
        declaration: declaration,
        phase: phase,
      ),
    );
    if (result == null || !mounted) return false;
    final id = declaration['id'];
    if (id is! num || id <= 0) {
      _showMessage(
        context,
        'La declaración seleccionada no es válida.',
        error: true,
      );
      return false;
    }
    setState(() {
      _savingChecklist = true;
      _checklistError = null;
    });
    try {
      await widget.authService.submitEquipmentInspection(
        id.toInt(),
        phase,
        result,
      );
      if (!mounted) return false;
      setState(() {
        final field = phase == 'entrada'
            ? 'equipmentEntryChecklistComplete'
            : 'equipmentExitChecklistComplete';
        widget.appointment![field] = true;
        _declaration = {
          ...declaration,
          'inspections': [
            ...(declaration['inspections'] as List? ?? const []),
            {
              'phase': phase == 'entrada' ? 'Entrada' : 'Salida',
              'status': 'Completada',
              'items': result
                  .map(
                    (item) => {
                      'declarationItemId': item['declarationItemId'],
                      'keepAtReception': item['keepAtReception'],
                    },
                  )
                  .toList(),
            },
          ],
        };
        _savingChecklist = false;
      });
      _showMessage(
        context,
        phase == 'entrada'
            ? 'Checklist de entrada completado.'
            : 'Checklist de salida completado.',
      );
      return true;
    } on AuthApiException catch (error) {
      if (!mounted) return false;
      setState(() {
        _savingChecklist = false;
        _checklistError = error.message;
      });
      _showMessage(context, error.message, error: true);
      return false;
    }
  }

  Future<void> _performMovement(String event) async {
    if (_savingMovement || _savingChecklist) return;
    if (event == 'Ingreso' && _requiresChecklist && !_entryComplete) {
      if (_declaration?['status'] != 'Enviada') return;
      if (!await _completeChecklist('entrada')) return;
    } else if (event == 'Retiro' &&
        '${widget.entry['event'] ?? ''}' == 'Ingreso' &&
        _requiresChecklist &&
        !_exitComplete) {
      if (_declaration?['status'] != 'Enviada') return;
      if (!await _completeChecklist('salida')) return;
    }

    setState(() => _savingMovement = true);
    final saved = await widget.onRecordMovement(event);
    if (!mounted) return;
    setState(() {
      _savingMovement = false;
      if (saved) {
        widget.entry['event'] = event;
        if (widget.appointment != null) {
          widget.appointment!['status'] = switch (event) {
            'Ingreso' => 'Dentro',
            'Retiro' => 'Retirado',
            _ => 'En proceso',
          };
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final event = '${widget.entry['event'] ?? ''}';
    final nextEvent = event == 'Llegada'
        ? 'Ingreso'
        : event == 'Ingreso'
        ? 'Retiro'
        : null;
    final actionText = nextEvent == 'Ingreso'
        ? 'Dar entrada'
        : nextEvent == 'Retiro'
        ? 'Registrar salida'
        : 'Cerrar';
    final movementNeedsDeclaration =
        _requiresChecklist && (nextEvent == 'Ingreso' || nextEvent == 'Retiro');
    final canPerformMovement =
        nextEvent != null &&
        !widget.readOnly &&
        !_loadingChecklist &&
        !_savingChecklist &&
        !_savingMovement &&
        (!movementNeedsDeclaration || _declaration?['status'] == 'Enviada');
    final canLeaveWithoutEntering =
        event == 'Llegada' &&
        _requiresChecklist &&
        !widget.readOnly &&
        !_loadingChecklist &&
        !_savingChecklist &&
        !_savingMovement;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: _isLightTheme(context) ? Colors.white : null,
          gradient: _isLightTheme(context)
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF172844), Color(0xFF091426)],
                ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x663D9DFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LogDialogHeader(
              icon: Icons.fact_check_outlined,
              title: 'Detalle del movimiento',
              subtitle: 'Consulta la visita y registra el siguiente paso.',
            ),
            const SizedBox(height: 13),
            if (widget.readOnly) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _logInsetColor(context),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _logBorderColor(context)),
                ),
                child: const Text(
                  'Registro histórico · solo lectura',
                  style: TextStyle(
                    color: Color(0xFF8ACBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _DailyLogMovementCard(
              entry: widget.entry,
              onTap: () {},
              onQr: () {},
              onDelete: null,
              showRegisteredBy: widget.showRegisteredBy,
            ),
            if (widget.appointment != null) ...[
              const SizedBox(height: 8),
              Text(
                'Cita · ${widget.appointment!['date'] ?? ''} · ${widget.appointment!['time'] ?? ''}',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 10,
                ),
              ),
            ],
            if (_requiresChecklist) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _logInsetColor(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _logBorderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.fact_check_rounded,
                          size: 18,
                          color: Color(0xFF168BFF),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CHECKLIST DE EQUIPO Y HERRAMIENTAS',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 9,
                              letterSpacing: .45,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (_entryComplete)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 17,
                            color: Color(0xFF18A889),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _loadingChecklist
                          ? 'Cargando la declaración de equipo…'
                          : _checklistError ??
                                (_declaration == null
                                    ? 'No se encontró la declaración asociada a esta cita.'
                                    : _declaration?['status'] != 'Enviada'
                                    ? 'El contratista aún debe enviar su declaración.'
                                    : _entryComplete
                                    ? _exitComplete
                                          ? 'Checklist de entrada y salida completados.'
                                          : 'Entrada verificada. Antes de registrar la salida, confirma las devoluciones del resguardo.'
                                    : 'Verifica los artículos antes de dar entrada. Puedes marcar cuáles se quedan en recepción.'),
                      style: TextStyle(
                        color: _checklistError == null
                            ? _secondaryTextColor(context)
                            : const Color(0xFFFF7189),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                    if (_checklistError != null &&
                        widget.appointment?['equipmentDeclarationId'] is num)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _loadingChecklist
                              ? null
                              : () => _loadDeclaration(
                                  (widget.appointment!['equipmentDeclarationId']
                                          as num)
                                      .toInt(),
                                ),
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('Reintentar'),
                        ),
                      ),
                    if (_checklistPhase != null &&
                        _declaration?['status'] == 'Enviada') ...[
                      const SizedBox(height: 9),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loadingChecklist || _savingChecklist
                              ? null
                              : () => _completeChecklist(_checklistPhase!),
                          icon: _savingChecklist
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _checklistPhase == 'entrada'
                                      ? Icons.login_rounded
                                      : Icons.assignment_return_rounded,
                                  size: 16,
                                ),
                          label: Text(
                            _checklistPhase == 'entrada'
                                ? 'Hacer checklist de entrada'
                                : 'Hacer checklist de salida',
                          ),
                          style: _logPrimaryButtonStyle(context),
                        ),
                      ),
                    ],
                    if (movementNeedsDeclaration &&
                        _declaration?['status'] != 'Enviada')
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Text(
                          'El contratista debe enviar su declaración antes de continuar.',
                          style: TextStyle(
                            color: Color(0xFFE0A437),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: _logOutlinedButtonStyle(context),
                    child: const Text('Cerrar'),
                  ),
                ),
                if (nextEvent != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: canLeaveWithoutEntering ? 1 : 2,
                    child: FilledButton.icon(
                      onPressed: canPerformMovement
                          ? () => _performMovement(nextEvent)
                          : null,
                      icon: Icon(
                        nextEvent == 'Ingreso'
                            ? Icons.login_rounded
                            : Icons.logout_rounded,
                        size: 17,
                      ),
                      label: Text(actionText),
                      style: _logPrimaryButtonStyle(context),
                    ),
                  ),
                  if (canLeaveWithoutEntering) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _performMovement('Retiro'),
                        icon: const Icon(Icons.logout_rounded, size: 17),
                        label: const Text(
                          'Registrar salida',
                          textAlign: TextAlign.center,
                        ),
                        style: _logOutlinedButtonStyle(context),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyLogQrScanner extends StatefulWidget {
  const _DailyLogQrScanner();

  @override
  State<_DailyLogQrScanner> createState() => _DailyLogQrScannerState();
}

class _DailyLogQrScannerState extends State<_DailyLogQrScanner> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(18),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
      decoration: BoxDecoration(
        color: _logDialogColor(context),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _logBorderColor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 9),
            child: _LogDialogHeader(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Escanear pase',
              subtitle: 'Centra el código QR dentro del recuadro.',
            ),
          ),
          Flexible(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    if (_handled) return;
                    final value = capture.barcodes
                        .map((barcode) => barcode.rawValue)
                        .whereType<String>()
                        .firstOrNull;
                    if (value == null || value.isEmpty) return;
                    _handled = true;
                    Navigator.pop(context, value);
                  },
                ),
                IgnorePointer(
                  child: Container(
                    width: 235,
                    height: 235,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF75C4FF),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: _logOutlinedButtonStyle(context),
                child: const Text('Cancelar escaneo'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _VisitorRegistrationReceptionDialog extends StatefulWidget {
  const _VisitorRegistrationReceptionDialog({
    required this.registration,
    required this.authService,
    required this.isAdmin,
    required this.isInside,
    required this.forceReadOnly,
  });

  final Map<String, dynamic> registration;
  final AuthService authService;
  final bool isAdmin;
  final bool? isInside;
  final bool forceReadOnly;

  @override
  State<_VisitorRegistrationReceptionDialog> createState() =>
      _VisitorRegistrationReceptionDialogState();
}

class _VisitorRegistrationReceptionDialogState
    extends State<_VisitorRegistrationReceptionDialog> {
  bool _busy = false;

  Map<String, dynamic> get _registration => widget.registration;
  List<Map<String, dynamic>> get _items =>
      (_registration['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

  bool get _readOnly {
    if (widget.isAdmin && !widget.forceReadOnly) return false;
    if (widget.forceReadOnly) return true;
    final createdAt = '${_registration['createdAt'] ?? ''}';
    return !createdAt.startsWith(_dateString(DateTime.now()));
  }

  Future<void> _process(String action) async {
    List<Map<String, Object?>>? items;
    if (action == 'complete-entry-checklist' ||
        action == 'complete-exit-checklist') {
      final retainedIds = <int>{};
      for (final inspection
          in (_registration['inspections'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()) {
        if (inspection['phase'] != 'Entrada') continue;
        for (final item
            in (inspection['items'] as List? ?? const [])
                .whereType<Map<String, dynamic>>()) {
          if (item['keepAtReception'] == true && item['itemId'] is num) {
            retainedIds.add((item['itemId'] as num).toInt());
          }
        }
      }
      items = await showDialog<List<Map<String, Object?>>>(
        context: context,
        builder: (_) => _VisitorChecklistDialog(
          title: action == 'complete-entry-checklist'
              ? 'Checklist de entrada'
              : 'Checklist de salida',
          phase: action == 'complete-entry-checklist' ? 'Entrada' : 'Salida',
          items: _items,
          retainedIds: retainedIds,
        ),
      );
      if (items == null || !mounted) return;
    } else if (action == 'reject') {
      final confirmed = await _confirmAction(
        context,
        title: 'Rechazar visita',
        message:
            '¿Rechazar el registro de ${_registration['visitorName'] ?? 'esta persona'}?',
        confirmLabel: 'Rechazar',
      );
      if (!confirmed || !mounted) return;
    }

    final id = _registration['id'];
    if (id is! num || id <= 0) {
      _showMessage(
        context,
        'El registro seleccionado no es válido.',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.authService.updateVisitorKioskRegistration(
        id.toInt(),
        action: action,
        items: items,
      );
      if (!mounted) return;
      final successMessage = switch (action) {
        'authorize' => 'Visita autorizada.',
        'reject' => 'Registro rechazado.',
        'complete-entry-checklist' => 'Checklist de entrada completado.',
        _ => 'Checklist de salida completado.',
      };
      _showMessage(context, successMessage);
      Navigator.pop(context, true);
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _showMessage(context, error.message, error: true);
      }
    }
  }

  Future<void> _recordExit() async {
    final visitorRecordId = _registration['visitorRecordId'];
    if (visitorRecordId is! num || visitorRecordId <= 0) {
      _showMessage(
        context,
        'El registro de visitante no es válido.',
        error: true,
      );
      return;
    }
    final now = DateTime.now();
    setState(() => _busy = true);
    try {
      await widget.authService.createDailyLogEntry({
        'event': 'Retiro',
        'date': _dateString(now),
        'time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'personName': '${_registration['visitorName'] ?? 'Visitante'}',
        'details':
            'Registro manual · Folio ${_registration['folio'] ?? ''} · Salida registrada',
        'appointmentId': null,
        'externalStaffId': null,
        'visitorRecordId': visitorRecordId.toInt(),
        'sourceEntryId': null,
      });
      if (!mounted) return;
      _showMessage(context, 'Salida registrada correctamente.');
      Navigator.pop(context, true);
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(context, error.message, error: true);
    }
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool primary = false,
  }) => primary
      ? FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(label),
          style:
              _logPrimaryButtonStyle(
                context,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ).copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
        )
      : OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(label),
          style:
              _logOutlinedButtonStyle(
                context,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ).copyWith(
                foregroundColor: WidgetStatePropertyAll(color),
                side: WidgetStatePropertyAll(
                  BorderSide(color: color.withValues(alpha: .55)),
                ),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
        );

  @override
  Widget build(BuildContext context) {
    final authorization =
        '${_registration['authorizationStatus'] ?? 'Pendiente'}';
    final entryComplete = _registration['entryChecklistComplete'] == true;
    final exitComplete = _registration['exitChecklistComplete'] == true;
    final hasItems = _items.isNotEmpty;
    final isPending = authorization == 'Pendiente';
    final authorizationColor = switch (authorization) {
      'Autorizada' => const Color(0xFF18A889),
      'Rechazada' => const Color(0xFFFF536D),
      _ => const Color(0xFFE0A437),
    };
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: _isLightTheme(context) ? Colors.white : null,
          gradient: _isLightTheme(context)
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2E4C), Color(0xFF0A1426)],
                ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: _isLightTheme(context)
                ? const Color(0xFFD4E3F3)
                : const Color(0x664A9FEA),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: _isLightTheme(context) ? .12 : .42,
              ),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1595FF), Color(0xFF32C6D7)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 8, 10),
              child: _LogDialogHeader(
                icon: Icons.how_to_reg_rounded,
                title: 'Registro de visitante',
                subtitle: 'Folio ${_registration['folio'] ?? 'Sin folio'}',
              ),
            ),
            Divider(height: 1, color: _logBorderColor(context)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isLightTheme(context)
                            ? const [Color(0xFFF7FAFE), Color(0xFFEFF5FC)]
                            : const [Color(0xFF0D1A2E), Color(0xFF0A1425)],
                      ),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: _logBorderColor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF168BFF)
                                    .withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                color: Color(0xFF69B8FF),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${_registration['visitorName'] ?? 'Visitante'}',
                                  style: TextStyle(
                                    color: _primaryTextColor(context),
                                    fontSize: 16,
                                    height: 1.15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            _AppointmentStatusBadge(
                              label: authorization,
                              color: authorizationColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _LogInfoBadge(
                              icon: Icons.business_outlined,
                              label:
                                  '${_registration['companyName'] ?? 'Público general'}',
                            ),
                            _LogInfoBadge(
                              icon: Icons.badge_outlined,
                              label:
                                  'Identificación: ${_registration['identificationType'] ?? 'No indicada'}',
                            ),
                          ],
                        ),
                        if ('${_registration['visitReason'] ?? ''}'
                            .isNotEmpty) ...[
                          const SizedBox(height: 11),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: _logBorderColor(context),
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.short_text_rounded,
                                  size: 17,
                                  color: _secondaryTextColor(context),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Motivo · ${_registration['visitReason']}',
                                    style: TextStyle(
                                      color: _secondaryTextColor(context),
                                      fontSize: 11,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  _VisitorProcessProgress(
                    authorization: authorization,
                    entryComplete: entryComplete,
                    exitComplete: exitComplete,
                    hasItems: hasItems,
                    isInside: widget.isInside == true,
                  ),
                  if (_readOnly) ...[
                    const SizedBox(height: 9),
                    const _LogNotice(
                      text: 'Registro histórico: solo Administración puede realizar cambios.',
                      color: Color(0xFFFFC078),
                    ),
                  ],
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'EQUIPO Y HERRAMIENTAS',
                      style: TextStyle(
                        color: _isLightTheme(context)
                            ? const Color(0xFF1769AA)
                            : const Color(0xFF68B7FF),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .9,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_items.length} ${_items.length == 1 ? 'artículo declarado' : 'artículos declarados'}',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in _items)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: _logInsetColor(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _logBorderColor(context)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF168BFF)
                                    .withValues(alpha: .13),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                item['type'] == 'Herramienta'
                                    ? Icons.handyman_rounded
                                    : Icons.devices_other_rounded,
                                color: const Color(0xFF68B7FF),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['description'] ?? 'Artículo'}',
                                    style: TextStyle(
                                      color: _primaryTextColor(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item['brand'] ?? ''} ${item['model'] ?? ''} · Cantidad ${item['quantity'] ?? 1}',
                                    style: TextStyle(
                                      color: _secondaryTextColor(context),
                                      fontSize: 10,
                                    ),
                                  ),
                                  if ('${item['serialNumber'] ?? ''}'
                                      .isNotEmpty)
                                    Text(
                                      'Serie: ${item['serialNumber']}',
                                      style: TextStyle(
                                        color: _secondaryTextColor(context),
                                        fontSize: 9,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            _AppointmentStatusBadge(
                              label: '${item['type'] ?? 'Equipo'}',
                              color: const Color(0xFF4A9FEA),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (!_readOnly &&
                      authorization == 'Autorizada' &&
                      hasItems) ...[
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            (entryComplete
                                    ? const Color(0xFFFF536D)
                                    : const Color(0xFF168BFF))
                                .withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color:
                              (entryComplete
                                      ? const Color(0xFFFF536D)
                                      : const Color(0xFF168BFF))
                                  .withValues(alpha: .28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                entryComplete
                                    ? Icons.assignment_return_rounded
                                    : Icons.fact_check_rounded,
                                color: entryComplete
                                    ? const Color(0xFFFF647C)
                                    : const Color(0xFF168BFF),
                                size: 18,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  entryComplete
                                      ? 'Revisión de salida'
                                      : 'Inspección de entrada',
                                  style: TextStyle(
                                    color: _primaryTextColor(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                entryComplete ? '2 DE 2' : '1 DE 2',
                                style: TextStyle(
                                  color: entryComplete
                                      ? const Color(0xFFFF647C)
                                      : const Color(0xFF168BFF),
                                  fontSize: 8,
                                  letterSpacing: .6,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            entryComplete
                                ? 'Confirma qué artículos resguardados se devuelven al visitante.'
                                : 'Confirma físicamente los artículos y marca lo que se quedará en recepción.',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 10,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: _actionButton(
                              label: _busy
                                  ? 'Guardando revisión…'
                                  : entryComplete
                                  ? 'Revisar salida'
                                  : 'Revisar entrada',
                              icon: _busy
                                  ? Icons.hourglass_top_rounded
                                  : entryComplete
                                  ? Icons.logout_rounded
                                  : Icons.login_rounded,
                              color: entryComplete
                                  ? const Color(0xFFFF536D)
                                  : const Color(0xFF168BFF),
                              primary: !entryComplete,
                              onPressed: _busy
                                  ? null
                                  : () => _process(
                                      entryComplete
                                          ? 'complete-exit-checklist'
                                          : 'complete-entry-checklist',
                                    ),
                            ),
                          ),
                          if (entryComplete && !exitComplete) ...[
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 13,
                                  color: Color(0xFFFF647C),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'La salida se registra al completar el checklist.',
                                    style: TextStyle(
                                      color: _secondaryTextColor(context),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (!_readOnly &&
                      authorization == 'Autorizada' &&
                      !hasItems) ...[
                    const SizedBox(height: 9),
                    if (widget.isInside == true)
                      _actionButton(
                        label: 'Registrar salida',
                        icon: Icons.logout_rounded,
                        color: const Color(0xFFFF536D),
                        onPressed: _busy ? null : _recordExit,
                      )
                    else
                      _LogNotice(
                        text: widget.isInside == false
                            ? 'No hay una entrada activa para este visitante hoy.'
                            : 'No se pudo confirmar su estado actual; revisa la bitácora antes de registrar la salida.',
                        color: const Color(0xFFFFC078),
                      ),
                  ],
                  if (_registration['audit'] is List &&
                      (_registration['audit'] as List).isNotEmpty) ...[
                    const SizedBox(height: 13),
                    Text(
                      'ACTIVIDAD DEL REGISTRO',
                      style: TextStyle(
                        color: _isLightTheme(context)
                            ? const Color(0xFF1769AA)
                            : const Color(0xFF68B7FF),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final event
                        in (_registration['audit'] as List)
                            .whereType<Map<String, dynamic>>()
                            .take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3C9CFF),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${event['action'] ?? 'Actualización'} · ${event['actorName'] ?? 'Recepción'} · ${event['createdAt'] ?? ''}',
                                style: TextStyle(
                                  color: _secondaryTextColor(context),
                                  fontSize: 9,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (isPending && !_readOnly)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: _actionButton(
                        label: 'Rechazar',
                        icon: Icons.block_rounded,
                        color: const Color(0xFFFF7189),
                        onPressed: _busy ? null : () => _process('reject'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _actionButton(
                        label: 'Autorizar visita',
                        icon: Icons.verified_rounded,
                        color: const Color(0xFF168BFF),
                        primary: true,
                        onPressed: _busy ? null : () => _process('authorize'),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    style: _logOutlinedButtonStyle(context).copyWith(
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: Text(_busy ? 'Procesando...' : 'Listo, cerrar'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogNotice extends StatelessWidget {
  const _LogNotice({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

class _VisitorProcessProgress extends StatelessWidget {
  const _VisitorProcessProgress({
    required this.authorization,
    required this.entryComplete,
    required this.exitComplete,
    required this.hasItems,
    required this.isInside,
  });

  final String authorization;
  final bool entryComplete;
  final bool exitComplete;
  final bool hasItems;
  final bool isInside;

  @override
  Widget build(BuildContext context) {
    final authorized = authorization == 'Autorizada';
    final rejected = authorization == 'Rechazada';
    final inspectedEntry = !hasItems || entryComplete;
    final inspectedExit = !hasItems ? !isInside : exitComplete;
    final currentStep = rejected
        ? 0
        : !authorized
        ? 0
        : inspectedExit
        ? 2
        : inspectedEntry
        ? 2
        : 1;
    final colors = [
      authorization == 'Autorizada'
          ? const Color(0xFF18A889)
          : rejected
          ? const Color(0xFFFF536D)
          : const Color(0xFFE0A437),
      inspectedEntry ? const Color(0xFF18A889) : const Color(0xFF168BFF),
      inspectedExit ? const Color(0xFF18A889) : const Color(0xFFFF536D),
    ];
    final done = [
      authorized || rejected,
      authorized && inspectedEntry,
      authorized && inspectedEntry && inspectedExit,
    ];
    final labels = ['Autorización', 'Entrada', 'Salida'];
    final icons = [
      Icons.verified_user_rounded,
      Icons.fact_check_rounded,
      Icons.logout_rounded,
    ];
    final isLight = _isLightTheme(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
      decoration: BoxDecoration(
        color: _logInsetColor(context),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _logBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.route_rounded,
                size: 15,
                color: isLight
                    ? const Color(0xFF1769AA)
                    : const Color(0xFF68B7FF),
              ),
              const SizedBox(width: 6),
              Text(
                'PROCESO DE VISITA',
                style: TextStyle(
                  color: isLight
                      ? const Color(0xFF1769AA)
                      : const Color(0xFF68B7FF),
                  fontSize: 8,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                rejected
                    ? 'DETENIDO'
                    : done.last
                    ? 'COMPLETADO'
                    : 'PASO ${currentStep + 1} DE 3',
                style: TextStyle(
                  color: rejected
                      ? const Color(0xFFFF536D)
                      : done.last
                      ? const Color(0xFF18A889)
                      : const Color(0xFF168BFF),
                  fontSize: 8,
                  letterSpacing: .45,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var index = 0; index < labels.length; index++) ...[
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 29,
                        height: 29,
                        decoration: BoxDecoration(
                          color: colors[index].withValues(
                            alpha: done[index] ? .18 : .1,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colors[index].withValues(
                              alpha: done[index] || index == currentStep
                                  ? .65
                                  : .25,
                            ),
                          ),
                        ),
                        child: Icon(
                          done[index] ? Icons.check_rounded : icons[index],
                          color: colors[index],
                          size: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: done[index] || index == currentStep
                              ? _primaryTextColor(context)
                              : _secondaryTextColor(context),
                          fontSize: 8,
                          fontWeight: done[index] || index == currentStep
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < labels.length - 1)
                  Container(
                    width: 24,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: done[index]
                          ? const Color(0xFF18A889).withValues(alpha: .7)
                          : _logBorderColor(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _VisitorChecklistDialog extends StatefulWidget {
  const _VisitorChecklistDialog({
    required this.title,
    required this.phase,
    required this.items,
    required this.retainedIds,
  });

  final String title;
  final String phase;
  final List<Map<String, dynamic>> items;
  final Set<int> retainedIds;

  @override
  State<_VisitorChecklistDialog> createState() =>
      _VisitorChecklistDialogState();
}

class _VisitorChecklistDialogState extends State<_VisitorChecklistDialog> {
  late final List<bool> _checked;
  late final List<bool> _kept;
  late final List<bool> _returned;
  late final List<String> _results;
  late final List<TextEditingController> _notes;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.items.length, false);
    _kept = List.filled(widget.items.length, false);
    _returned = List.filled(widget.items.length, false);
    _results = List.filled(widget.items.length, 'Coincide');
    _notes = List.generate(widget.items.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final controller in _notes) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _complete => _checked.isNotEmpty && _checked.every((value) => value);

  @override
  Widget build(BuildContext context) {
    final isEntry = widget.phase == 'Entrada';
    final accent = isEntry ? const Color(0xFF168BFF) : const Color(0xFFFF536D);
    final checkedCount = _checked.where((value) => value).length;
    final progress = _checked.isEmpty ? 0.0 : checkedCount / _checked.length;
    final isLight = _isLightTheme(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: _logDialogColor(context),
          gradient: isLight
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172844), Color(0xFF091426)],
                ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: isLight
                ? const Color(0xFFD4E3F3)
                : accent.withValues(alpha: .48),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? .12 : .4),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: .55)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isEntry
                          ? Icons.login_rounded
                          : Icons.assignment_return_rounded,
                      color: accent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEntry
                              ? 'INSPECCIÓN DE ENTRADA'
                              : 'CONTROL DE SALIDA',
                          style: TextStyle(
                            color: accent,
                            fontSize: 8,
                            letterSpacing: .75,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _logBorderColor(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 7),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isLight ? .07 : .1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: .22)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.rule_rounded, color: accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEntry
                                    ? 'Verificación de artículos'
                                    : 'Devoluciones y revisión final',
                                style: TextStyle(
                                  color: _primaryTextColor(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEntry
                                    ? 'Marca los artículos revisados y define si alguno se resguarda.'
                                    : 'Revisa cada artículo. Confirma la devolución de los resguardados.',
                                style: TextStyle(
                                  color: _secondaryTextColor(context),
                                  fontSize: 9,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$checkedCount/${widget.items.length}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: checkedCount / widget.items.length,
                        minHeight: 5,
                        backgroundColor: _logBorderColor(context),
                        valueColor: AlwaysStoppedAnimation<Color>(accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(15, 3, 15, 12),
                itemCount: widget.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final itemId = item['id'] is num
                      ? (item['id'] as num).toInt()
                      : 0;
                  final canReturn =
                      widget.phase == 'Salida' &&
                      widget.retainedIds.contains(itemId);
                  final checked = _checked[index];
                  final itemAccent = _results[index] == 'Coincide'
                      ? const Color(0xFF18A889)
                      : _results[index] == 'Faltante'
                      ? const Color(0xFFE0A437)
                      : const Color(0xFFFF536D);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: checked
                          ? itemAccent.withValues(alpha: isLight ? .045 : .08)
                          : _logInsetColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: checked
                            ? itemAccent.withValues(alpha: .42)
                            : _logBorderColor(context),
                        width: checked ? 1.2 : 1,
                      ),
                      boxShadow: checked
                          ? [
                              BoxShadow(
                                color: itemAccent.withValues(alpha: .06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
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
                                color: accent.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                item['type'] == 'Herramienta'
                                    ? Icons.handyman_rounded
                                    : Icons.devices_other_rounded,
                                color: accent,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['description'] ?? 'Artículo'}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _primaryTextColor(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item['brand'] ?? 'Sin marca'} ${item['model'] ?? ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _secondaryTextColor(context),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF168BFF)
                                    .withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '× ${item['quantity'] ?? 1}',
                                style: const TextStyle(
                                  color: Color(0xFF168BFF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Checkbox(
                              value: checked,
                              activeColor: const Color(0xFF18A889),
                              onChanged: (value) => setState(
                                () => _checked[index] = value ?? false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isLight
                                ? Colors.white.withValues(alpha: .72)
                                : const Color(0xFF081326)
                                      .withValues(alpha: .62),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                color: _secondaryTextColor(context),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Serie · ${item['serialNumber'] ?? 'No indicada'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _secondaryTextColor(context),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _AppointmentStatusBadge(
                                label: _results[index],
                                color: itemAccent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'RESULTADO DE LA REVISIÓN',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 8,
                            letterSpacing: .6,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final result in const [
                              'Coincide',
                              'Faltante',
                              'Dañado',
                            ])
                              _LogChoiceChip(
                                label: result,
                                icon: result == 'Coincide'
                                    ? Icons.check_circle_outline_rounded
                                    : result == 'Faltante'
                                    ? Icons.help_outline_rounded
                                    : Icons.warning_amber_rounded,
                                selected: _results[index] == result,
                                onTap: () =>
                                    setState(() => _results[index] = result),
                              ),
                          ],
                        ),
                        if (widget.phase == 'Entrada' || canReturn) ...[
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(11),
                              onTap: () => setState(() {
                                if (widget.phase == 'Entrada') {
                                  _kept[index] = !_kept[index];
                                } else {
                                  _returned[index] = !_returned[index];
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (widget.phase == 'Entrada'
                                              ? const Color(0xFFE0A437)
                                              : const Color(0xFF18A889))
                                          .withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color:
                                        (widget.phase == 'Entrada'
                                                ? const Color(0xFFE0A437)
                                                : const Color(0xFF18A889))
                                            .withValues(alpha: .2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      widget.phase == 'Entrada'
                                          ? Icons.inventory_2_outlined
                                          : Icons.assignment_return_rounded,
                                      size: 16,
                                      color: widget.phase == 'Entrada'
                                          ? const Color(0xFFE0A437)
                                          : const Color(0xFF18A889),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.phase == 'Entrada'
                                                ? 'Resguardar en recepción'
                                                : 'Confirmar devolución',
                                            style: TextStyle(
                                              color: _primaryTextColor(context),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            widget.phase == 'Entrada'
                                                ? 'El artículo permanecerá bajo resguardo.'
                                                : 'El artículo vuelve con el visitante.',
                                            style: TextStyle(
                                              color: _secondaryTextColor(
                                                context,
                                              ),
                                              fontSize: 8,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: widget.phase == 'Entrada'
                                          ? _kept[index]
                                          : _returned[index],
                                      activeColor: widget.phase == 'Entrada'
                                          ? const Color(0xFFE0A437)
                                          : const Color(0xFF18A889),
                                      onChanged: (value) => setState(() {
                                        if (widget.phase == 'Entrada') {
                                          _kept[index] = value ?? false;
                                        } else {
                                          _returned[index] = value ?? false;
                                        }
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        TextField(
                          controller: _notes[index],
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 2,
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 10,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Agregar observación (opcional)',
                            hintStyle: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 9,
                            ),
                            prefixIcon: Icon(
                              Icons.edit_note_rounded,
                              color: _secondaryTextColor(context),
                              size: 17,
                            ),
                            counterText: '',
                            isDense: true,
                            filled: true,
                            fillColor: _logDialogColor(context),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide(
                                color: _logBorderColor(context),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                              borderSide: BorderSide(color: accent, width: 1.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: _logBorderColor(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 13),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        _complete
                            ? Icons.verified_rounded
                            : Icons.pending_actions_rounded,
                        color: _complete
                            ? const Color(0xFF18A889)
                            : const Color(0xFFE0A437),
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          _complete
                              ? 'Todos los artículos están revisados'
                              : 'Revisa ${widget.items.length - checkedCount} artículo(s) para continuar',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: _logOutlinedButtonStyle(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _complete
                              ? () => Navigator.pop(
                                  context,
                                  List<Map<String, Object?>>.generate(
                                    widget.items.length,
                                    (index) => {
                                      'itemId':
                                          (widget.items[index]['id'] as num)
                                              .toInt(),
                                      'result': _results[index],
                                      'notes': _notes[index].text.trim(),
                                      'checked': true,
                                      'keepAtReception': _kept[index],
                                      'returnedToVisitor': _returned[index],
                                    },
                                  ),
                                )
                              : null,
                          icon: const Icon(Icons.fact_check_rounded, size: 17),
                          label: const Text('Confirmar inspección'),
                          style: _logPrimaryButtonStyle(context).copyWith(
                            backgroundColor: WidgetStatePropertyAll(accent),
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
      ),
    );
  }
}

class ConnectedEquipmentPage extends StatefulWidget {
  const ConnectedEquipmentPage({
    required this.authService,
    required this.isAdmin,
    required this.canManage,
    this.user,
    super.key,
  });
  final AuthService authService;
  final bool isAdmin;
  final bool canManage;
  final AuthenticatedUser? user;
  @override
  State<ConnectedEquipmentPage> createState() => _ConnectedEquipmentPageState();
}

class _ConnectedEquipmentPageState extends State<ConnectedEquipmentPage> {
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _declarations = [];
  Map<String, dynamic> _options = {};
  bool _loading = true;
  String? _error;
  String _query = '';
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await Future.wait<Object>([
        widget.authService.getEquipmentDeclarations(query: _query, page: _page),
        widget.authService.getEquipmentOptions(),
      ]);
      var declarationsPage = values[0] as EquipmentDeclarationsPage;
      if (_page > declarationsPage.pages) {
        declarationsPage = await widget.authService.getEquipmentDeclarations(
          query: _query,
          page: declarationsPage.pages,
        );
      }
      if (mounted) {
        setState(() {
          _declarations = declarationsPage.declarations;
          _pages = declarationsPage.pages;
          _total = declarationsPage.total;
          _pageSize = declarationsPage.pageSize;
          _page = declarationsPage.page;
          _options = values[1] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final partners = (_options['partners'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (partners.isEmpty) {
      _showMessage(
        context,
        'No hay contratistas activos disponibles.',
        error: true,
      );
      return;
    }
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _EquipmentDeclarationForm(
        partners: partners,
        staff: (_options['staff'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
        appointments: (_options['appointments'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(),
      ),
    );
    if (result == null) return;
    try {
      final created = await widget.authService.createEquipmentDeclaration(
        result,
      );
      if (!mounted) return;
      final token = created['token'];
      if (token is! String || token.isEmpty) {
        throw const AuthApiException('El servidor no generó un enlace válido.');
      }
      final responseLink = created['url'];
      final declarationLink = responseLink is String && responseLink.isNotEmpty
          ? responseLink
          : widget.authService.equipmentDeclarationUrl(token);
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _panelColor(context),
          surfaceTintColor: Colors.transparent,
          icon: const Icon(Icons.link_rounded, size: 28),
          iconColor: const Color(0xFF168BFF),
          title: Text(
            'Enlace generado',
            style: TextStyle(
              color: _primaryTextColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Declaración #${created['id']} para ${created['personName'] ?? ''}. Comparte este enlace con la persona:',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _logInsetColor(context),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _logBorderColor(context)),
                ),
                child: SelectableText(
                  declarationLink,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vigencia: ${created['expiresInDays'] ?? 30} días',
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: declarationLink));
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Copiar enlace'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    try {
      final response = await widget.authService.getEquipmentDeclaration(
        item['id'] as int,
      );
      final declaration = response['declaration'];
      if (declaration is! Map<String, dynamic>) {
        throw const AuthApiException(
          'El detalle de la declaración no es válido.',
        );
      }
      if (!mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _EquipmentDeclarationDetail(
          authService: widget.authService,
          declaration: declaration,
        ),
      );
      if (changed == true) await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final canDelete =
        widget.isAdmin || (widget.canManage && item['status'] == 'Pendiente');
    if (!canDelete) return;
    if (!await _confirmAction(
      context,
      title: 'Eliminar declaración',
      message: 'Se eliminarán también sus verificaciones.',
      confirmLabel: 'Eliminar',
    )) {
      return;
    }
    try {
      await widget.authService.deleteEquipmentDeclaration(item['id'] as int);
      await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => _ConnectedPage(
    title: 'Equipo y herramientas',
    subtitle: 'Declaraciones e inspecciones registradas',
    user: widget.user,
    trailing: IconButton(
      onPressed: _load,
      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
    ),
    child: _loading || _error != null
        ? _loadingOrError(
            context: context,
            loading: _loading,
            error: _error,
            onRetry: _load,
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              children: [
                _EquipmentDeclarationsToolbar(
                  count: _total,
                  canManage: widget.canManage,
                  onCreate: _create,
                  onQueryChanged: (value) {
                    setState(() {
                      _query = value;
                      _page = 1;
                    });
                    _searchDebounce?.cancel();
                    _searchDebounce = Timer(
                      const Duration(milliseconds: 300),
                      _load,
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (_declarations.isEmpty)
                  const _EmptyRecords(
                    message: 'No hay declaraciones registradas.',
                  )
                else
                  for (final item in _declarations) ...[
                    _EquipmentDeclarationCard(
                      declaration: item,
                      canDelete:
                          widget.isAdmin ||
                          (widget.canManage && item['status'] == 'Pendiente'),
                      onOpen: () => _open(item),
                      onDelete: () => _delete(item),
                    ),
                    const SizedBox(height: 9),
                  ],
                if (_pages > 1) ...[
                  const SizedBox(height: 5),
                  _EquipmentDeclarationsPagination(
                    page: _page,
                    pages: _pages,
                    pageSize: _pageSize,
                    total: _total,
                    onPreviousPage: _page > 1
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                    onNextPage: _page < _pages
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                  ),
                ],
              ],
            ),
          ),
  );
}

class _EquipmentDeclarationsToolbar extends StatelessWidget {
  const _EquipmentDeclarationsToolbar({
    required this.count,
    required this.canManage,
    required this.onCreate,
    required this.onQueryChanged,
  });

  final int count;
  final bool canManage;
  final VoidCallback onCreate;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _isLightTheme(context) ? Colors.white : null,
      gradient: _isLightTheme(context)
          ? null
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF172844), Color(0xFF0C172B)],
            ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0x663B9DFF)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F168BFF),
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
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF168BFF), Color(0xFF26B8E8)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.handyman_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count ${count == 1 ? 'declaración' : 'declaraciones'}',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Declaraciones e inspecciones',
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (canManage)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33168BFF),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Nueva'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          maxLength: 180,
          onChanged: onQueryChanged,
          style: TextStyle(color: _primaryTextColor(context), fontSize: 13),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Buscar persona o empresa',
            hintStyle: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 12,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF55AAFF),
            ),
            filled: true,
            fillColor: _isLightTheme(context)
                ? const Color(0xFFF3F6FB)
                : const Color(0xFF091426),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0x243D9DFF)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF168BFF)),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EquipmentDeclarationsPagination extends StatelessWidget {
  const _EquipmentDeclarationsPagination({
    required this.page,
    required this.pages,
    required this.pageSize,
    required this.total,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int page;
  final int pages;
  final int pageSize;
  final int total;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    final firstRecord = (page - 1) * pageSize + 1;
    final lastRecord = (page * pageSize).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isLightTheme(context)
            ? Colors.white
            : const Color(0xFF111D35).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _isLightTheme(context)
              ? const Color(0xFFDCE4EF)
              : const Color(0x333D9DFF),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Registros anteriores',
            onPressed: onPreviousPage,
            icon: const Icon(Icons.chevron_left_rounded),
            color: _isLightTheme(context)
                ? const Color(0xFF1769AA)
                : const Color(0xFF8BCBFF),
            disabledColor: _secondaryTextColor(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Página $page de $pages',
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Registros $firstRecord–$lastRecord de $total',
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Más registros',
            onPressed: onNextPage,
            icon: const Icon(Icons.chevron_right_rounded),
            color: _isLightTheme(context)
                ? const Color(0xFF1769AA)
                : const Color(0xFF8BCBFF),
            disabledColor: _secondaryTextColor(context),
          ),
        ],
      ),
    );
  }
}

class _EquipmentDeclarationCard extends StatelessWidget {
  const _EquipmentDeclarationCard({
    required this.declaration,
    required this.canDelete,
    required this.onOpen,
    required this.onDelete,
  });

  final Map<String, dynamic> declaration;
  final bool canDelete;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final status = '${declaration['status'] ?? 'Pendiente'}';
    final entryStatus = '${declaration['entryStatus'] ?? 'Pendiente'}';
    final exitStatus = '${declaration['exitStatus'] ?? 'Pendiente'}';
    final appointmentId = declaration['appointmentId'];
    final date = declaration['visitDate'];
    final time = '${declaration['visitTime'] ?? ''}'.trim();
    final hasAppointment =
        appointmentId != null ||
        (date is String && date.isNotEmpty) ||
        time.isNotEmpty;
    final appointmentLabel = hasAppointment
        ? '${_displayDate(date)}${time.isEmpty ? '' : ' · $time'}'
        : 'Sin cita vinculada';
    final incidentCount = declaration['incidentCount'] ?? 0;
    final itemCount = declaration['itemCount'] ?? 0;
    final isSent = status == 'Enviada';
    final statusColor = isSent
        ? const Color(0xFF4AE3B5)
        : const Color(0xFFFFC56E);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _isLightTheme(context) ? Colors.white : null,
        gradient: _isLightTheme(context)
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF17243D), Color(0xFF0C1628)],
              ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isLightTheme(context)
              ? const Color(0xFFDCE4EF)
              : const Color(0x443D9DFF),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 6),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF168BFF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x554AA8FF)),
                ),
                child: const Icon(
                  Icons.person_pin_circle_rounded,
                  color: Color(0xFF73BEFF),
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${declaration['personName'] ?? 'Persona sin nombre'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${declaration['companyName'] ?? 'Empresa sin nombre'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EquipmentInfoPill(
                icon: Icons.event_available_rounded,
                label: 'Cita',
                value: appointmentLabel,
              ),
              _EquipmentInfoPill(
                icon: Icons.inventory_2_outlined,
                label: 'Declaración',
                value:
                    '$itemCount ${itemCount == 1 ? 'artículo' : 'artículos'}',
                color: statusColor,
                badge: status,
              ),
              if (incidentCount is num && incidentCount > 0)
                _EquipmentInfoPill(
                  icon: Icons.warning_amber_rounded,
                  label: 'Incidencias',
                  value: '$incidentCount',
                  color: const Color(0xFFFF8999),
                ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: _EquipmentCheckStatus(
                  label: 'Entrada',
                  status: entryStatus,
                  icon: Icons.login_rounded,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _EquipmentCheckStatus(
                  label: 'Salida',
                  status: exitStatus,
                  icon: Icons.logout_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.fact_check_rounded, size: 18),
                    label: const Text('Abrir declaración'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 9),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: FilledButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Eliminar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EquipmentInfoPill extends StatelessWidget {
  const _EquipmentInfoPill({
    required this.icon,
    required this.label,
    required this.value,
    this.color = const Color(0xFF69B8FF),
    this.badge,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? badge;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: _isLightTheme(context)
          ? const Color(0xFFF3F6FB)
          : const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _isLightTheme(context)
            ? const Color(0xFFDCE4EF)
            : Colors.white.withValues(alpha: 0.07),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: _secondaryTextColor(context),
                fontSize: 8,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: _primaryTextColor(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 5),
                  _EquipmentStatusBadge(label: badge!, color: color),
                ],
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _EquipmentStatusBadge extends StatelessWidget {
  const _EquipmentStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800),
    ),
  );
}

class _EquipmentCheckStatus extends StatelessWidget {
  const _EquipmentCheckStatus({
    required this.label,
    required this.status,
    required this.icon,
  });

  final String label;
  final String status;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final complete = status == 'Completada';
    final color = complete ? const Color(0xFF4AE3B5) : const Color(0xFFFFC56E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VERIFICACIÓN DE ${label.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 8,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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

class _EquipmentDeclarationForm extends StatefulWidget {
  const _EquipmentDeclarationForm({
    required this.partners,
    required this.staff,
    required this.appointments,
  });
  final List<Map<String, dynamic>> partners, staff, appointments;
  @override
  State<_EquipmentDeclarationForm> createState() =>
      _EquipmentDeclarationFormState();
}

class _EquipmentDeclarationFormState extends State<_EquipmentDeclarationForm> {
  final _formKey = GlobalKey<FormState>();
  late int _partnerId = widget.partners.first['id'] as int;
  int? _staffId;
  int? _appointmentId;
  final _name = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _staffForPartner =>
      widget.staff.where((s) => s['businessPartnerId'] == _partnerId).toList();
  List<Map<String, dynamic>> get _appointmentsForPartner => widget.appointments
      .where((a) => a['businessPartnerId'] == _partnerId)
      .toList();

  Map<String, dynamic>? _findById(List<Map<String, dynamic>> records, int? id) {
    if (id == null) return null;
    for (final record in records) {
      if (record['id'] == id) return record;
    }
    return null;
  }

  String _appointmentLabel(Map<String, dynamic> appointment) {
    final person =
        '${appointment['visitor'] ?? appointment['visitorName'] ?? 'Visita'}';
    final date = _displayDate(appointment['date']);
    final time = '${appointment['time'] ?? ''}'.trim();
    return '$person · $date${time.isEmpty ? '' : ' · $time'}';
  }

  Future<int?> _chooseOption({
    required String title,
    required String emptyLabel,
    required List<Map<String, dynamic>> options,
    required int? selectedId,
    required String Function(Map<String, dynamic>) titleFor,
    required String Function(Map<String, dynamic>) subtitleFor,
    required IconData icon,
    required Color color,
  }) => showModalBottomSheet<int>(
    context: context,
    backgroundColor: _isLightTheme(context)
        ? Colors.white
        : const Color(0xFF101D32),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 15, 17, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.65,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _isLightTheme(context)
                        ? const Color(0xFFDCE4EF)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Text(
                title,
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _EquipmentOptionTile(
                      title: emptyLabel,
                      subtitle: 'No vincular',
                      icon: Icons.do_not_disturb_on_outlined,
                      color: const Color(0xFF9AA9BE),
                      selected: selectedId == null,
                      onTap: () => Navigator.pop(context),
                    ),
                    for (final option in options)
                      _EquipmentOptionTile(
                        title: titleFor(option),
                        subtitle: subtitleFor(option),
                        icon: icon,
                        color: color,
                        selected: option['id'] == selectedId,
                        onTap: () =>
                            Navigator.pop(context, option['id'] as int),
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

  Future<void> _selectPartner() async {
    final id = await _chooseOption(
      title: 'Seleccionar empresa',
      emptyLabel: 'Seleccionar empresa',
      options: widget.partners,
      selectedId: _partnerId,
      titleFor: (partner) => '${partner['name']}',
      subtitleFor: (partner) =>
          '${partner['type'] ?? 'Contratista'} · ${partner['category'] ?? 'Empresa registrada'}',
      icon: Icons.apartment_rounded,
      color: const Color(0xFF62B4FF),
    );
    if (id == null || id == _partnerId) return;
    setState(() {
      _partnerId = id;
      _staffId = null;
      _appointmentId = null;
      _name.clear();
    });
  }

  Future<void> _selectStaff() async {
    final options = _staffForPartner;
    if (options.isEmpty) {
      _showMessage(
        context,
        'Esta empresa todavía no tiene personal externo registrado.',
      );
      return;
    }
    final id = await _chooseOption(
      title: 'Personal externo',
      emptyLabel: 'Sin personal vinculado',
      options: options,
      selectedId: _staffId,
      titleFor: (staff) => '${staff['fullName']}',
      subtitleFor: (staff) =>
          '${staff['relationshipType'] ?? 'Personal externo'} · ${staff['phone'] ?? staff['email'] ?? 'Sin contacto'}',
      icon: Icons.person_outline_rounded,
      color: const Color(0xFF4AE3B5),
    );
    if (id == null && _staffId == null) return;
    setState(() {
      _staffId = id;
      if (id != null) _appointmentId = null;
      final selected = _findById(options, id);
      if (selected != null) _name.text = '${selected['fullName'] ?? ''}';
    });
  }

  Future<void> _selectAppointment() async {
    final options = _appointmentsForPartner;
    if (options.isEmpty) {
      _showMessage(context, 'No hay citas disponibles para esta empresa.');
      return;
    }
    final id = await _chooseOption(
      title: 'Cita vinculada',
      emptyLabel: 'Sin cita',
      options: options,
      selectedId: _appointmentId,
      titleFor: _appointmentLabel,
      subtitleFor: (appointment) =>
          'Anfitrión: ${appointment['host'] ?? 'Sin anfitrión'} · ${appointment['status'] ?? 'Pendiente'}',
      icon: Icons.event_available_rounded,
      color: const Color(0xFFB69CFF),
    );
    if (id == null && _appointmentId == null) return;
    setState(() {
      _appointmentId = id;
      if (id != null) _staffId = null;
      final selected = _findById(options, id);
      if (selected != null) {
        _name.text = '${selected['visitor'] ?? selected['visitorName'] ?? ''}';
      }
    });
  }

  Widget _selector({
    required String label,
    required String value,
    required String hint,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool selected = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: _isLightTheme(context)
              ? const Color(0xFFF3F6FB)
              : const Color(0xFF0A1426),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.46)
                : const Color(0x293D9DFF),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 9,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected ? value : hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? _primaryTextColor(context)
                          : _secondaryTextColor(context),
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.expand_more_rounded,
              color: _secondaryTextColor(context),
              size: 21,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _personNameField() => TextFormField(
    controller: _name,
    style: TextStyle(color: _primaryTextColor(context), fontSize: 13),
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Escribe el nombre de la persona'
        : null,
    decoration: InputDecoration(
      labelText: 'Nombre de la persona',
      hintText: 'Nombre y apellidos',
      labelStyle: TextStyle(color: _secondaryTextColor(context), fontSize: 12),
      hintStyle: TextStyle(color: _secondaryTextColor(context), fontSize: 11),
      prefixIcon: const Icon(
        Icons.badge_outlined,
        color: Color(0xFF6AB8FF),
        size: 19,
      ),
      filled: true,
      fillColor: _isLightTheme(context)
          ? const Color(0xFFF3F6FB)
          : const Color(0xFF0A1426),
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x293D9DFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF168BFF), width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF7189)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF7189)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final selectedPartner = _findById(widget.partners, _partnerId)!;
    final selectedStaff = _findById(_staffForPartner, _staffId);
    final selectedAppointment = _findById(
      _appointmentsForPartner,
      _appointmentId,
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: _isLightTheme(context) ? Colors.white : null,
          gradient: _isLightTheme(context)
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF172844), Color(0xFF091426)],
                ),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: const Color(0x663D9DFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 30,
              offset: Offset(0, 17),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(19, 17, 10, 14),
                child: Row(
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF168BFF), Color(0xFF26B8E8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.handyman_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crear declaración de equipo',
                            style: TextStyle(
                              color: _primaryTextColor(context),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Vincula la empresa, la cita y la persona.',
                            style: TextStyle(
                              color: _secondaryTextColor(context),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: _secondaryTextColor(context),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: _isLightTheme(context)
                    ? const Color(0xFFDCE4EF)
                    : const Color(0x223D9DFF),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FormSectionLabel(label: 'EMPRESA Y VISITA'),
                      const SizedBox(height: 11),
                      _selector(
                        label: 'Empresa',
                        value: '${selectedPartner['name']}',
                        hint: 'Selecciona una empresa registrada',
                        icon: Icons.apartment_rounded,
                        color: const Color(0xFF62B4FF),
                        selected: true,
                        onTap: _selectPartner,
                      ),
                      _selector(
                        label: 'Cita vinculada · opcional',
                        value: selectedAppointment == null
                            ? ''
                            : _appointmentLabel(selectedAppointment),
                        hint: 'Sin cita',
                        icon: Icons.event_available_rounded,
                        color: const Color(0xFFB69CFF),
                        selected: selectedAppointment != null,
                        onTap: _selectAppointment,
                      ),
                      const SizedBox(height: 2),
                      const _FormSectionLabel(label: 'PERSONA RESPONSABLE'),
                      const SizedBox(height: 11),
                      _selector(
                        label: 'Personal externo registrado · opcional',
                        value: selectedStaff == null
                            ? ''
                            : '${selectedStaff['fullName']}',
                        hint: _staffForPartner.isEmpty
                            ? 'No hay personal registrado'
                            : 'Selecciona personal externo',
                        icon: Icons.person_outline_rounded,
                        color: const Color(0xFF4AE3B5),
                        selected: selectedStaff != null,
                        onTap: _selectStaff,
                      ),
                      _personNameField(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primaryTextColor(context),
                          side: BorderSide(color: _logBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF168BFF), Color(0xFF7657FF)],
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33168BFF),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            Navigator.pop(context, <String, Object?>{
                              'businessPartnerId': _partnerId,
                              'externalStaffId': _staffId,
                              'appointmentId': _appointmentId,
                              'personName': _name.text.trim(),
                            });
                          },
                          icon: const Icon(Icons.link_rounded, size: 17),
                          label: const Text('Crear enlace'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
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
      ),
    );
  }
}

class _EquipmentOptionTile extends StatelessWidget {
  const _EquipmentOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Material(
      color: selected
          ? color.withValues(alpha: 0.13)
          : _isLightTheme(context)
          ? const Color(0xFFF3F6FB)
          : const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.42)
                  : _isLightTheme(context)
                  ? const Color(0xFFDCE4EF)
                  : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: color, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}

class _EquipmentDeclarationDetail extends StatefulWidget {
  const _EquipmentDeclarationDetail({
    required this.authService,
    required this.declaration,
  });
  final AuthService authService;
  final Map<String, dynamic> declaration;
  @override
  State<_EquipmentDeclarationDetail> createState() =>
      _EquipmentDeclarationDetailState();
}

class _EquipmentDeclarationDetailState
    extends State<_EquipmentDeclarationDetail> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final items = (widget.declaration['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final inspections = (widget.declaration['inspections'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final entryDone = inspections.any(
      (i) => i['phase'] == 'Entrada' && i['status'] == 'Completada',
    );
    final exitDone = inspections.any(
      (i) => i['phase'] == 'Salida' && i['status'] == 'Completada',
    );
    final canInspect = widget.declaration['status'] == 'Enviada';
    final status = '${widget.declaration['status'] ?? 'Pendiente'}';
    final statusColor = status == 'Enviada'
        ? const Color(0xFF18A889)
        : status == 'Pendiente'
        ? const Color(0xFFE0A437)
        : const Color(0xFF168BFF);
    final isLight = _isLightTheme(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: _panelColor(context),
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
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 17, 10, 14),
              child: Row(
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
                      Icons.inventory_2_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DECLARACIÓN DE EQUIPO',
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF167C92)
                                : const Color(0xFF73CDE0),
                            fontSize: 9,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.declaration['personName'] ?? 'Declaración'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 3),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context, false),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _logBorderColor(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.business_rounded,
                    size: 17,
                    color: _secondaryTextColor(context),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${widget.declaration['companyName'] ?? 'Empresa sin nombre'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length} ${items.length == 1 ? 'artículo' : 'artículos'}',
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _logInsetColor(context),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _logBorderColor(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.hourglass_empty_rounded,
                              color: Color(0xFFE0A437),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'La persona aún no envía sus artículos.',
                                style: TextStyle(
                                  color: _secondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (var index = 0; index < items.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _panel(
                          context: context,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 31,
                                height: 31,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF168BFF)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF168BFF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${items[index]['itemType'] ?? ''} · ${items[index]['quantity'] ?? 0} × ${items[index]['product'] ?? ''}\n${items[index]['brand'] ?? ''} · ${items[index]['model'] ?? ''} · Serie: ${items[index]['serialNumber'] ?? ''} · ${items[index]['color'] ?? ''}\n${items[index]['notes'] ?? ''}',
                                  style: TextStyle(
                                    color: _primaryTextColor(context),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _logInsetColor(context),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          _inspectionStatus(
                            context,
                            'Entrada',
                            entryDone,
                            Icons.login_rounded,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 30,
                            color: _logBorderColor(context),
                          ),
                          const SizedBox(width: 10),
                          _inspectionStatus(
                            context,
                            'Salida',
                            exitDone,
                            Icons.logout_rounded,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: _logBorderColor(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 16, 14),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (status == 'Pendiente')
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _regenerateLink,
                      icon: const Icon(Icons.link_rounded, size: 17),
                      label: const Text('Renovar enlace'),
                    ),
                  if (status == 'Pendiente')
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _revokeLink,
                      icon: const Icon(Icons.link_off_rounded, size: 17),
                      label: const Text('Revocar'),
                    ),
                  if (canInspect && !entryDone)
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _inspect('entrada', items),
                      icon: const Icon(Icons.login_rounded, size: 17),
                      label: const Text('Verificar entrada'),
                    ),
                  if (canInspect && entryDone && !exitDone)
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _inspect('salida', items),
                      icon: const Icon(Icons.logout_rounded, size: 17),
                      label: const Text('Verificar salida'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inspectionStatus(
    BuildContext context,
    String label,
    bool complete,
    IconData icon,
  ) {
    final color = complete ? const Color(0xFF18A889) : const Color(0xFFE0A437);
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: _secondaryTextColor(context),
                    fontSize: 8,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  complete ? 'Completada' : 'Pendiente',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateLink() async {
    try {
      final link = await widget.authService.createEquipmentDeclarationLink(
        widget.declaration['id'] as int,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _panelColor(dialogContext),
          title: Text(
            'Enlace renovado',
            style: TextStyle(color: _primaryTextColor(dialogContext)),
          ),
          content: SelectableText(
            link,
            style: TextStyle(
              color: _primaryTextColor(dialogContext),
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Copiar enlace'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _revokeLink() async {
    if (!await _confirmAction(
      context,
      title: 'Revocar enlace',
      message: 'La persona ya no podrá enviar su declaración con este enlace.',
      confirmLabel: 'Revocar',
    )) {
      return;
    }
    try {
      await widget.authService.revokeEquipmentDeclarationLink(
        widget.declaration['id'] as int,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _inspect(String phase, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    final confirmed = await _confirmAction(
      context,
      title: phase == 'entrada' ? 'Verificar entrada' : 'Verificar salida',
      message: 'Confirma que cada artículo coincide con la declaración. La verificación se guarda de forma definitiva.',
      confirmLabel: 'Confirmar revisión',
    );
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await widget.authService.submitEquipmentInspection(
        widget.declaration['id'] as int,
        phase,
        items
            .map(
              (item) => <String, Object?>{
                'declarationItemId': item['id'],
                'quantity': item['quantity'],
                'product': item['product'],
                'brand': item['brand'],
                'model': item['model'],
                'serialNumber': item['serialNumber'],
                'color': item['color'],
                'notes': item['notes'] ?? '',
                'incident': false,
                'checked': true,
                'keepAtReception': false,
                'returnedToVisitor': false,
              },
            )
            .toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthApiException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage(context, error.message, error: true);
      }
    }
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Center(
      child: Text(message, style: const TextStyle(color: _muted)),
    ),
  );
}
