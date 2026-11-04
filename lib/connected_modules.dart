import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'auth_service.dart';

const _pageBackground = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
);
const _panelBackground = Color(0xFF111D35);
const _accent = Color(0xFF168BFF);
const _muted = Color(0xFFB5C1D6);

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

void _showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? const Color(0xFFB4233B)
            : const Color(0xFF087FFF),
      ),
    );
}

Future<bool> _confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Continuar',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panelBackground,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: _muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

class _ConnectedPage extends StatelessWidget {
  const _ConnectedPage({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: _pageBackground),
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 14, 8),
            child: Row(
              children: [
                Builder(
                  builder: (context) => IconButton(
                    tooltip: 'Abrir menú',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(color: _muted, fontSize: 11),
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

Widget _loadingOrError({
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
              style: const TextStyle(color: Colors.white),
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
  required Widget child,
  EdgeInsets padding = const EdgeInsets.all(14),
}) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: _panelBackground,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0x66087FFF)),
  ),
  child: child,
);

Widget _searchBox({
  required String hint,
  required ValueChanged<String> onChanged,
  int? maxLength,
}) => TextField(
  maxLength: maxLength,
  onChanged: onChanged,
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF8290A8), fontSize: 13),
    prefixIcon: const Icon(Icons.search_rounded, color: _accent),
    filled: true,
    fillColor: const Color(0xFF0B1427),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
);

Widget _recordTile({
  required String title,
  required String subtitle,
  required IconData icon,
  List<Widget> actions = const [],
  Widget? trailing,
}) => _panel(
  child: Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0x33168BFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF68B7FF)),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ),
      ?trailing,
      ...actions,
    ],
  ),
);

class ConnectedExternalCompaniesPage extends StatefulWidget {
  const ConnectedExternalCompaniesPage({
    required this.authService,
    required this.isAdmin,
    required this.canManage,
    super.key,
  });

  final AuthService authService;
  final bool isAdmin;
  final bool canManage;

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
      trailing: IconButton(
        tooltip: 'Actualizar',
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      child: _loading || _error != null
          ? _loadingOrError(loading: _loading, error: _error, onRetry: _load)
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Directorio de externos',
                    style: TextStyle(color: _muted, fontSize: 11),
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
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Buscar nombre, RFC, categoría o asunto',
            hintStyle: const TextStyle(color: Color(0xFF8290A8), fontSize: 12),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF4AA8FF),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
            ),
            filled: true,
            fillColor: const Color(0xFF091426),
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
        const Text(
          'FILTRAR POR TIPO',
          style: TextStyle(
            color: Color(0xFF8F9FB9),
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
      color: selected ? color.withValues(alpha: 0.2) : const Color(0xFF0B1629),
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
              color: selected ? color.withValues(alpha: 0.8) : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFFA8B6CC),
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
        gradient: const LinearGradient(
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
                      style: const TextStyle(
                        color: Colors.white,
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
              if (canManage || isAdmin)
                PopupMenuButton<String>(
                  tooltip: 'Acciones del registro',
                  color: const Color(0xFF15233B),
                  icon: const Icon(Icons.more_vert_rounded, color: _muted),
                  onSelected: (action) {
                    if (action == 'edit') onEdit();
                    if (action == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    if (canManage)
                      const PopupMenuItem(
                        value: 'edit',
                        child: _PartnerMenuItem(
                          icon: Icons.edit_rounded,
                          label: 'Editar',
                        ),
                      ),
                    if (isAdmin)
                      const PopupMenuItem(
                        value: 'delete',
                        child: _PartnerMenuItem(
                          icon: Icons.delete_outline_rounded,
                          label: 'Eliminar',
                          destructive: true,
                        ),
                      ),
                  ],
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFB7C4D8),
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
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 57),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFF0B1629),
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
                style: const TextStyle(
                  color: Color(0xFF8797B0),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.65,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE0E9F7),
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

class _PartnerMenuItem extends StatelessWidget {
  const _PartnerMenuItem({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 18,
        color: destructive ? const Color(0xFFFF7189) : const Color(0xFF9BCCFF),
      ),
      const SizedBox(width: 10),
      Text(
        label,
        style: TextStyle(
          color: destructive ? const Color(0xFFFF9AAA) : Colors.white,
        ),
      ),
    ],
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
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator:
          validator ??
          (value) => requiredField && (value == null || value.trim().isEmpty)
              ? 'Completa este dato para continuar'
              : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFFA7B6CD), fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFF687993), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF6AB8FF), size: 19),
        alignLabelWithHint: maxLines > 1,
        filled: true,
        fillColor: const Color(0xFF0A1426),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x223D9DFF)),
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
          gradient: const LinearGradient(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Completa la información del registro',
                            style: TextStyle(color: _muted, fontSize: 11),
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
              ),
              const Divider(height: 1, color: Color(0x223D9DFF)),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIPO DE REGISTRO',
                        style: TextStyle(
                          color: Color(0xFF8F9FB9),
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
                        const Padding(
                          padding: EdgeInsets.only(bottom: 9, top: 1),
                          child: Text(
                            'ESTADO DEL REGISTRO',
                            style: TextStyle(
                              color: Color(0xFF8F9FB9),
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
                          foregroundColor: const Color(0xFFB6C5DA),
                          side: const BorderSide(color: Color(0x447F94B3)),
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
      color: selected ? color.withValues(alpha: 0.15) : const Color(0xFF0A1426),
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
              color: selected ? color.withValues(alpha: 0.75) : Colors.white12,
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
                  color: selected ? Colors.white : const Color(0xFFA8B6CC),
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
      color: selected ? color.withValues(alpha: 0.13) : const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.6) : Colors.white12,
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
                  color: selected ? Colors.white : const Color(0xFFA8B6CC),
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
    super.key,
  });
  final AuthService authService;
  final bool isAdmin;
  final bool canManage;

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
      trailing: IconButton(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      child: _loading || _error != null
          ? _loadingOrError(loading: _loading, error: _error, onRetry: _load)
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
      gradient: const LinearGradient(
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$totalPeople ${totalPeople == 1 ? 'persona registrada' : 'personas registradas'}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _staffSearchField(
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
            gradient: const LinearGradient(
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
                      color: const Color(0xFF0A1426),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x333D9DFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$staffCount',
                          style: const TextStyle(
                            color: Color(0xFF58ACFF),
                            fontSize: 17,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          staffCount == 1 ? 'registrado' : 'registrados',
                          style: const TextStyle(
                            color: Color(0xFF9EADC3),
                            fontSize: 9,
                          ),
                        ),
                        if (declaredCount != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$declaredCount contemplados',
                            style: const TextStyle(
                              color: Color(0xFF7487A3),
                              fontSize: 8,
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
                style: const TextStyle(
                  color: Colors.white,
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
                  style: const TextStyle(
                    color: Color(0xFFA8B6CC),
                    fontSize: 11,
                  ),
                ),
              ],
              const SizedBox(height: 13),
              const Divider(height: 1, color: Color(0x223D9DFF)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'Ver empleados',
                    style: TextStyle(
                      color: Color(0xFF7CCFFF),
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
    final type = '${partner['type'] ?? 'Contratista'}';
    final color = _partnerTypeColor(type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
                      style: const TextStyle(
                        color: Colors.white,
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
                  foregroundColor: const Color(0xFFB6C5DA),
                  side: const BorderSide(color: Color(0x447F94B3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (canManage)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF168BFF), Color(0xFFFF3155)],
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
      color: const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0x333D9DFF)),
    ),
    child: Text(
      '$count ${count == 1 ? 'empleado' : 'empleados'}',
      style: const TextStyle(
        color: Color(0xFF68B7FF),
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
  });

  final Map<String, dynamic> staff;
  final Map<String, dynamic> company;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = '${staff['fullName'] ?? 'Sin nombre'}';
    final phone = '${staff['phone'] ?? ''}'.trim();
    final email = '${staff['email'] ?? ''}'.trim();
    final relation =
        '${staff['relationshipType'] ?? company['type'] ?? 'Externo'}';
    final color = _partnerTypeColor(relation);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF183D62), Color(0xFF10243D)],
                  ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PartnerBadge(label: relation, color: color),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Acciones del empleado',
                  color: const Color(0xFF15233B),
                  icon: const Icon(Icons.more_vert_rounded, color: _muted),
                  onSelected: (action) {
                    if (action == 'edit') onEdit();
                    if (action == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: _PartnerMenuItem(
                        icon: Icons.edit_rounded,
                        label: 'Editar',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: _PartnerMenuItem(
                        icon: Icons.delete_outline_rounded,
                        label: 'Eliminar',
                        destructive: true,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PartnerDetailTile(
            label: 'Empresa',
            value: '${company['name'] ?? staff['companyName'] ?? '—'}',
            icon: Icons.apartment_rounded,
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
            const Text(
              'Sin datos de contacto',
              style: TextStyle(color: Color(0xFF8290A8), fontSize: 11),
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
          child: Icon(icon, color: const Color(0xFF69B8FF), size: 28),
        ),
        const SizedBox(height: 13),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
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
  required String hint,
  required ValueChanged<String> onChanged,
}) => TextField(
  onChanged: onChanged,
  style: const TextStyle(color: Colors.white, fontSize: 13),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF8290A8), fontSize: 12),
    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF55AAFF)),
    prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 46),
    filled: true,
    fillColor: const Color(0xFF091426),
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
        style: const TextStyle(
          color: Color(0xFF74C8D1),
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
      backgroundColor: const Color(0xFF101D32),
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
              const Text(
                'Seleccionar empresa',
                style: TextStyle(
                  color: Colors.white,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${partner['type']} · ${partner['category'] ?? 'Sin categoría'}',
                    style: const TextStyle(color: _muted, fontSize: 11),
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
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFFA7B6CD), fontSize: 12),
        hintStyle: const TextStyle(color: Color(0xFF687993), fontSize: 11),
        prefixIcon: Icon(icon, color: const Color(0xFF6AB8FF), size: 18),
        filled: true,
        fillColor: const Color(0xFF0A1426),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0x223D9DFF)),
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
          gradient: const LinearGradient(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Datos de contacto y empresa vinculada',
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
              ),
              const Divider(height: 1, color: Color(0x223D9DFF)),
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
                            color: const Color(0xFF0A1426),
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
                                    const Text(
                                      'Empresa contratista o proveedora',
                                      style: TextStyle(
                                        color: Color(0xFF8797B0),
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_selectedPartner['name']}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.unfold_more_rounded,
                                color: Color(0xFF91A4BF),
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
                          foregroundColor: const Color(0xFFB6C5DA),
                          side: const BorderSide(color: Color(0x447F94B3)),
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
                            colors: [Color(0xFF168BFF), Color(0xFFFF3155)],
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
    super.key,
  });
  final AuthService authService;
  final bool isAdmin;
  final bool canManage;
  @override
  State<ConnectedAppointmentsPage> createState() =>
      _ConnectedAppointmentsPageState();
}

class _ConnectedAppointmentsPageState extends State<ConnectedAppointmentsPage> {
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _partners = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _showAll = true;
  DateTime _selectedDate = DateTime.now();

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
      final result = await Future.wait([
        widget.authService.getAppointments(),
        widget.authService.getBusinessPartners(),
      ]);
      if (mounted) {
        setState(() {
          _appointments = result[0];
          _partners = result[1];
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

  Future<void> _edit([Map<String, dynamic>? appointment]) async {
    if (_partners.isEmpty) {
      _showMessage(
        context,
        'Registra primero una empresa o visitante.',
        error: true,
      );
      return;
    }
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _AppointmentForm(
        partners: _partners,
        record: appointment,
        initialDate: _selectedDate,
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
    if (!await _confirmAction(
      context,
      title: 'Eliminar cita cancelada',
      message: 'Esta acción elimina la cita del listado.',
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

  Future<void> _sendQr(Map<String, dynamic> appointment) async {
    try {
      final message = await widget.authService.sendAppointmentQr(
        appointment['id'] as int,
      );
      if (mounted) _showMessage(context, message);
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
      trailing: IconButton(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      child: _loading || _error != null
          ? _loadingOrError(loading: _loading, error: _error, onRetry: _load)
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
                  if (appointments.isEmpty)
                    _AppointmentEmptyState(
                      showAll: _showAll,
                      selectedDate: _selectedDate,
                      query: _query,
                      canManage: widget.canManage,
                      onCreate: () => _edit(),
                    )
                  else
                    for (final item in appointments) ...[
                      _AppointmentRecordCard(
                        item: item,
                        canManage: widget.canManage,
                        onEdit: () => _edit(item),
                        onCancel: () => _cancel(item),
                        onDelete: () => _delete(item),
                        onSendQr: () => _sendQr(item),
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
      gradient: const LinearGradient(
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$resultCount ${resultCount == 1 ? 'resultado' : 'resultados'} · ${showAll ? 'todas las fechas' : _displayDate(_dateString(selectedDate))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ],
              ),
            ),
            if (canManage)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF168BFF), Color(0xFFFF3155)],
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
          color: const Color(0xFF0A1426),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _pickDate(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x293D9DFF)),
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
                        const Text(
                          'FECHA SELECCIONADA',
                          style: TextStyle(
                            color: Color(0xFF8292AA),
                            fontSize: 8,
                            letterSpacing: 0.7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _displayDate(_dateString(selectedDate)),
                          style: const TextStyle(
                            color: Color(0xFFE0E9F7),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_calendar_rounded,
                    color: Color(0xFF8292AA),
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
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar visitante, empresa, anfitrión o folio',
            hintStyle: const TextStyle(color: Color(0xFF8290A8), fontSize: 11),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF55AAFF),
            ),
            filled: true,
            fillColor: const Color(0xFF091426),
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
                  : const Color(0xFF91A2BA),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFA8B6CC),
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
    required this.canManage,
    required this.onCreate,
  });

  final bool showAll;
  final DateTime selectedDate;
  final String query;
  final bool canManage;
  final VoidCallback onCreate;

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
        if (canManage && query.isEmpty) ...[
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Crear cita'),
          ),
        ],
      ],
    ),
  );
}

class _AppointmentForm extends StatefulWidget {
  const _AppointmentForm({
    required this.partners,
    required this.initialDate,
    this.record,
  });
  final List<Map<String, dynamic>> partners;
  final Map<String, dynamic>? record;
  final DateTime initialDate;
  @override
  State<_AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<_AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _visitor = TextEditingController(
    text: '${widget.record?['visitor'] ?? ''}',
  );
  late final _email = TextEditingController(
    text: '${widget.record?['email'] ?? ''}',
  );
  late final _host = TextEditingController(
    text: '${widget.record?['host'] ?? ''}',
  );
  late int _partnerId =
      widget.record?['businessPartnerId'] as int? ??
      widget.partners.first['id'] as int;
  late DateTime _date =
      DateTime.tryParse('${widget.record?['date'] ?? ''}') ??
      widget.initialDate;
  late String _time = '${widget.record?['time'] ?? '09:00'}';

  List<Map<String, dynamic>> get _availablePartners => widget.partners
      .where(
        (partner) =>
            partner['status'] != 'Inactiva' || partner['id'] == _partnerId,
      )
      .toList();

  Map<String, dynamic> get _selectedPartner => widget.partners.firstWhere(
    (partner) => partner['id'] == _partnerId,
    orElse: () => widget.partners.first,
  );

  @override
  void dispose() {
    _visitor.dispose();
    _email.dispose();
    _host.dispose();
    super.dispose();
  }

  Future<void> _selectPartner() async {
    final id = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF101D32),
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
                const Text(
                  'Empresa o visitante',
                  style: TextStyle(
                    color: Colors.white,
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
    if (id != null) setState(() => _partnerId = id);
  }

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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Color(0xFFA7B6CD), fontSize: 12),
        hintStyle: const TextStyle(color: Color(0xFF687993), fontSize: 11),
        prefixIcon: Icon(icon, color: const Color(0xFF6AB8FF), size: 18),
        filled: true,
        fillColor: const Color(0xFF0A1426),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0x223D9DFF)),
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
    color: const Color(0xFF0A1426),
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0x293D9DFF)),
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
                    style: const TextStyle(
                      color: Color(0xFF8292AA),
                      fontSize: 8,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFE0E9F7),
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
          gradient: const LinearGradient(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Datos de la visita y su anfitrión',
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
              ),
              const Divider(height: 1, color: Color(0x223D9DFF)),
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
                      _field(
                        label: 'Nombre del visitante',
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
                      _field(
                        label: 'Anfitrión',
                        hint: 'Nombre del anfitrión que recibirá la visita',
                        icon: Icons.badge_outlined,
                        controller: _host,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Escribe el nombre del anfitrión'
                            : null,
                      ),
                      const SizedBox(height: 2),
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
                      const Text(
                        'El pase QR se generará al guardar la cita.',
                        style: TextStyle(
                          color: Color(0xFF8292AA),
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
                          foregroundColor: const Color(0xFFB6C5DA),
                          side: const BorderSide(color: Color(0x447F94B3)),
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
                            colors: [Color(0xFF168BFF), Color(0xFFFF3155)],
                          ),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: FilledButton.icon(
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            Navigator.pop(context, <String, Object?>{
                              'visitorName': _visitor.text.trim(),
                              'visitorEmail': _email.text.trim(),
                              'businessPartnerId': _partnerId,
                              'hostName': _host.text.trim(),
                              'date': _dateString(_date),
                              'time': _time,
                            });
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
            : const Color(0xFF0A1426),
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
                    : const Color(0x293D9DFF),
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
                        style: const TextStyle(
                          color: Color(0xFF8292AA),
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
                        style: const TextStyle(
                          color: Color(0xFFE0E9F7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selector)
                  const Icon(
                    Icons.expand_more_rounded,
                    color: Color(0xFF91A4BF),
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
    required this.canManage,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
    required this.onSendQr,
    required this.onShowCode,
  });
  final Map<String, dynamic> item;
  final bool canManage;
  final VoidCallback onEdit, onCancel, onDelete, onSendQr, onShowCode;

  @override
  Widget build(BuildContext context) {
    final status = '${item['status'] ?? 'Pendiente'}';
    final canceled = status == 'Cancelada';
    final withdrawn = status == 'Retirado';
    final statusColor = canceled
        ? const Color(0xFFFF7189)
        : status == 'Dentro' || withdrawn
        ? const Color(0xFF4AE3B5)
        : const Color(0xFFFFC56E);
    final email = '${item['email'] ?? ''}'.trim();
    final reference = '${item['referenceCode'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
                      style: const TextStyle(
                        color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF9FB2CD),
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
          const Divider(height: 1, color: Color(0x223D9DFF)),
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
              if (canManage && canceled)
                _AppointmentActionButton(
                  label: 'Eliminar',
                  icon: Icons.delete_outline_rounded,
                  onPressed: onDelete,
                  destructive: true,
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
      color: const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                style: const TextStyle(
                  color: Color(0xFF8292AA),
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
                style: const TextStyle(
                  color: Color(0xFFE0E9F7),
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
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFFF8294)
        : const Color(0xFF8FC9FF);
    final button = OutlinedButton.icon(
      onPressed: onPressed,
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
    if (!primary) return button;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF168BFF), Color(0xFFFF3155)],
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
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

class _AppointmentPassDialog extends StatelessWidget {
  const _AppointmentPassDialog({required this.appointment});
  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    final payload = <String, Object?>{
      'type': 'visitas-appointment',
      'id': appointment['id'],
      'referenceCode': appointment['referenceCode'],
      'visitor': appointment['visitor'],
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
          gradient: const LinearGradient(
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33168BFF),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: jsonEncode(payload),
                  size: 220,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  eyeStyle: const QrEyeStyle(color: Color(0xFF10243A)),
                  dataModuleStyle: const QrDataModuleStyle(
                    color: Color(0xFF10243A),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1426),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x293D9DFF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${appointment['visitor'] ?? ''}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${appointment['company'] ?? ''}',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _AppointmentStatusBadge(
                          label:
                              '${_displayDate(appointment['date'])} · ${appointment['time'] ?? ''}',
                          color: const Color(0xFF68B7FF),
                        ),
                        if ('${appointment['host'] ?? ''}'.isNotEmpty)
                          _AppointmentStatusBadge(
                            label: 'Anfitrión: ${appointment['host']}',
                            color: const Color(0xFF4AE3B5),
                          ),
                      ],
                    ),
                    if ('${appointment['referenceCode'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        'FOLIO  ${appointment['referenceCode']}',
                        style: const TextStyle(
                          color: Color(0xFF70B9FF),
                          fontSize: 10,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 13),
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
    super.key,
  });
  final AuthService authService;
  final bool isAdmin;
  @override
  State<ConnectedDailyLogbookPage> createState() =>
      _ConnectedDailyLogbookPageState();
}

class _ConnectedDailyLogbookPageState extends State<ConnectedDailyLogbookPage> {
  Timer? _searchDebounce;
  DateTime _date = DateTime.now();
  String _query = '';
  String _event = '';
  int _page = 1;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};
  List<Map<String, dynamic>> _appointments = [];

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
    final date = _dateString(_date);
    try {
      final result = await Future.wait([
        widget.authService.getDailyLog(
          from: date,
          to: date,
          query: _query,
          event: _event,
          page: _page,
        ),
        widget.authService.getAppointments(),
      ]);
      if (mounted) {
        setState(() {
          _data = result[0] as Map<String, dynamic>;
          _appointments = result[1] as List<Map<String, dynamic>>;
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

  Future<void> _register() async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) =>
          _DailyLogEntryForm(appointments: _appointments, date: _date),
    );
    if (result == null) return;
    try {
      await widget.authService.createDailyLogEntry(result);
      if (!mounted) return;
      _showMessage(context, 'Movimiento registrado.');
      await _load();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(context, error.message, error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> entry) async {
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

  @override
  Widget build(BuildContext context) {
    final entries = (_data['entries'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final summary = _data['summary'] as Map<String, dynamic>? ?? const {};
    final pages = (_data['pages'] as num?)?.toInt() ?? 1;
    return _ConnectedPage(
      title: 'Bitácora diaria',
      subtitle: 'Movimientos consultados desde el registro central',
      trailing: IconButton(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
      child: _loading || _error != null
          ? _loadingOrError(loading: _loading, error: _error, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  _panel(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _date,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) {
                                    setState(() {
                                      _date = date;
                                      _page = 1;
                                    });
                                  }
                                  if (date != null) _load();
                                },
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(
                                  _displayDate(_date.toIso8601String()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _register,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Registrar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _LogMetric(
                              label: 'Movimientos',
                              value: '${summary['movementCount'] ?? 0}',
                            ),
                            _LogMetric(
                              label: 'Dentro ahora',
                              value: '${summary['insideNow'] ?? 0}',
                            ),
                            _LogMetric(
                              label: 'Pendientes',
                              value: '${summary['pendingArrivals'] ?? 0}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _searchBox(
                          hint: 'Buscar persona, empresa, anfitrión o folio',
                          maxLength: 180,
                          onChanged: (value) {
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
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _event,
                          dropdownColor: _panelBackground,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Tipo de movimiento',
                            labelStyle: TextStyle(color: _muted),
                          ),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('Todos')),
                            DropdownMenuItem(
                              value: 'Llegada',
                              child: Text('Llegada'),
                            ),
                            DropdownMenuItem(
                              value: 'Ingreso',
                              child: Text('Ingreso'),
                            ),
                            DropdownMenuItem(
                              value: 'Retiro',
                              child: Text('Retiro'),
                            ),
                            DropdownMenuItem(
                              value: 'Observaciones',
                              child: Text('Observaciones'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _event = value ?? '';
                              _page = 1;
                            });
                            _load();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (entries.isEmpty)
                    const _EmptyRecords(
                      message: 'No hay movimientos para este día.',
                    )
                  else
                    for (final entry in entries) ...[
                      _recordTile(
                        title:
                            '${entry['person'] ?? ''} · ${entry['event'] ?? ''}',
                        subtitle:
                            '${entry['time'] ?? ''} · ${entry['company'] ?? ''}\n${entry['details'] ?? ''}\nRegistró: ${entry['actorName'] ?? ''}',
                        icon: switch (entry['event']) {
                          'Ingreso' => Icons.login_rounded,
                          'Retiro' => Icons.logout_rounded,
                          'Llegada' => Icons.call_received_rounded,
                          _ => Icons.notes_rounded,
                        },
                        actions: [
                          if (widget.isAdmin)
                            IconButton(
                              tooltip: 'Eliminar movimiento',
                              onPressed: () => _delete(entry),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFFF647C),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                    ],
                  if (pages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Página anterior',
                          onPressed: _page > 1
                              ? () {
                                  setState(() => _page--);
                                  _load();
                                }
                              : null,
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '$_page de $pages',
                          style: const TextStyle(color: Colors.white),
                        ),
                        IconButton(
                          tooltip: 'Página siguiente',
                          onPressed: _page < pages
                              ? () {
                                  setState(() => _page++);
                                  _load();
                                }
                              : null,
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
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

class _LogMetric extends StatelessWidget {
  const _LogMetric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x22168BFF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$label: $value',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DailyLogEntryForm extends StatefulWidget {
  const _DailyLogEntryForm({required this.appointments, required this.date});
  final List<Map<String, dynamic>> appointments;
  final DateTime date;
  @override
  State<_DailyLogEntryForm> createState() => _DailyLogEntryFormState();
}

class _DailyLogEntryFormState extends State<_DailyLogEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _person = TextEditingController();
  final _details = TextEditingController();
  String _event = 'Llegada';
  int? _appointmentId;
  @override
  void dispose() {
    _person.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _panelBackground,
    title: const Text(
      'Registrar movimiento',
      style: TextStyle(color: Colors.white),
    ),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _event,
                dropdownColor: _panelBackground,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Movimiento',
                  labelStyle: TextStyle(color: _muted),
                ),
                items: const ['Llegada', 'Ingreso', 'Retiro', 'Observaciones']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (value) => setState(() => _event = value ?? _event),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: _appointmentId,
                dropdownColor: _panelBackground,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Vincular cita (opcional)',
                  labelStyle: TextStyle(color: _muted),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Registro manual'),
                  ),
                  ...widget.appointments
                      .where(
                        (a) =>
                            a['status'] != 'Cancelada' &&
                            a['status'] != 'Retirado',
                      )
                      .map(
                        (a) => DropdownMenuItem<int?>(
                          value: a['id'] as int,
                          child: Text(
                            '${a['visitor']} · ${a['date']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => _appointmentId = value),
              ),
              if (_appointmentId == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextFormField(
                    controller: _person,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la persona',
                      labelStyle: TextStyle(color: _muted),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Indica el nombre o vincula una cita'
                        : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _details,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    labelStyle: TextStyle(color: _muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final now = TimeOfDay.now();
          Navigator.pop(context, <String, Object?>{
            'event': _event,
            'date': _dateString(widget.date),
            'time':
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
            'personName': _person.text.trim(),
            'details': _details.text.trim(),
            'appointmentId': _appointmentId,
            'externalStaffId': null,
            'visitorRecordId': null,
            'sourceEntryId': null,
          });
        },
        child: const Text('Guardar movimiento'),
      ),
    ],
  );
}

class ConnectedEquipmentPage extends StatefulWidget {
  const ConnectedEquipmentPage({
    required this.authService,
    required this.isAdmin,
    required this.canManage,
    super.key,
  });
  final AuthService authService;
  final bool isAdmin;
  final bool canManage;
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
      final values = await Future.wait([
        widget.authService.getEquipmentDeclarations(query: _query, page: _page),
        widget.authService.getEquipmentOptions(),
      ]);
      if (mounted) {
        setState(() {
          _declarations = values[0] as List<Map<String, dynamic>>;
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
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _panelBackground,
          title: const Text(
            'Enlace generado',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Declaración #${created['id']} para ${created['personName'] ?? ''}. Comparte este token con la persona:',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              SelectableText(
                '${created['token'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Vigencia: ${created['expiresInDays'] ?? 30} días',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: '${created['token'] ?? ''}'),
                );
                if (!mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Copiar token'),
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
    trailing: IconButton(
      onPressed: _load,
      icon: const Icon(Icons.refresh_rounded, color: Colors.white),
    ),
    child: _loading || _error != null
        ? _loadingOrError(loading: _loading, error: _error, onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              children: [
                _EquipmentDeclarationsToolbar(
                  count: _declarations.length,
                  page: _page,
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
                  onPreviousPage: _page > 1
                      ? () {
                          setState(() => _page--);
                          _load();
                        }
                      : null,
                  onNextPage: _declarations.length >= 7
                      ? () {
                          setState(() => _page++);
                          _load();
                        }
                      : null,
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
                      canDelete: widget.isAdmin,
                      onOpen: () => _open(item),
                      onDelete: () => _delete(item),
                    ),
                    const SizedBox(height: 9),
                  ],
              ],
            ),
          ),
  );
}

class _EquipmentDeclarationsToolbar extends StatelessWidget {
  const _EquipmentDeclarationsToolbar({
    required this.count,
    required this.page,
    required this.canManage,
    required this.onCreate,
    required this.onQueryChanged,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int count;
  final int page;
  final bool canManage;
  final VoidCallback onCreate;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Historial · página $page',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (canManage)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF168BFF), Color(0xFFFF3155)],
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
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Buscar persona o empresa',
            hintStyle: const TextStyle(color: Color(0xFF8290A8), fontSize: 12),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF55AAFF),
            ),
            filled: true,
            fillColor: const Color(0xFF091426),
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
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Página anterior',
              onPressed: onPreviousPage,
              icon: const Icon(Icons.chevron_left_rounded),
              color: Colors.white,
            ),
            Text(
              'Página $page',
              style: const TextStyle(
                color: Color(0xFFC1CDE0),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              tooltip: 'Página siguiente',
              onPressed: onNextPage,
              icon: const Icon(Icons.chevron_right_rounded),
              color: Colors.white,
            ),
          ],
        ),
      ],
    ),
  );
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17243D), Color(0xFF0C1628)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x443D9DFF)),
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
                      style: const TextStyle(
                        color: Colors.white,
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
                      style: const TextStyle(
                        color: Color(0xFF9FB2CD),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (canDelete)
                PopupMenuButton<String>(
                  tooltip: 'Acciones de declaración',
                  color: const Color(0xFF15233B),
                  icon: const Icon(Icons.more_vert_rounded, color: _muted),
                  onSelected: (value) {
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: _PartnerMenuItem(
                        icon: Icons.delete_outline_rounded,
                        label: 'Eliminar',
                        destructive: true,
                      ),
                    ),
                  ],
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
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF168BFF), Color(0xFFFF3155)],
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
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
      color: const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
              style: const TextStyle(
                color: Color(0xFF8292AA),
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
                  style: const TextStyle(
                    color: Color(0xFFE0E9F7),
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
                  style: const TextStyle(
                    color: Color(0xFF8292AA),
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
    backgroundColor: const Color(0xFF101D32),
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
                title,
                style: const TextStyle(
                  color: Colors.white,
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
      final selected = _findById(options, id);
      if (selected != null) {
        _name.text = '${selected['fullName'] ?? ''}';
      }
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
      final selected = _findById(options, id);
      if (selected != null && _staffId == null) {
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
          color: const Color(0xFF0A1426),
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
                    style: const TextStyle(
                      color: Color(0xFF8292AA),
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
                          ? const Color(0xFFE0E9F7)
                          : const Color(0xFF8290A8),
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
              color: const Color(0xFF8292AA),
              size: 21,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _personNameField() => TextFormField(
    controller: _name,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Escribe el nombre de la persona'
        : null,
    decoration: InputDecoration(
      labelText: 'Nombre de la persona',
      hintText: 'Nombre y apellidos',
      labelStyle: const TextStyle(color: Color(0xFFA7B6CD), fontSize: 12),
      hintStyle: const TextStyle(color: Color(0xFF687993), fontSize: 11),
      prefixIcon: const Icon(
        Icons.badge_outlined,
        color: Color(0xFF6AB8FF),
        size: 19,
      ),
      filled: true,
      fillColor: const Color(0xFF0A1426),
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
          gradient: const LinearGradient(
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crear declaración de equipo',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Vincula la empresa, la cita y la persona.',
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
              ),
              const Divider(height: 1, color: Color(0x223D9DFF)),
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
                          foregroundColor: const Color(0xFFB6C5DA),
                          side: const BorderSide(color: Color(0x447F94B3)),
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
                            colors: [Color(0xFF168BFF), Color(0xFFFF3155)],
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
      color: selected ? color.withValues(alpha: 0.13) : const Color(0xFF0A1426),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.42) : Colors.white10,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8797B0),
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
    return AlertDialog(
      backgroundColor: _panelBackground,
      title: Text(
        '${widget.declaration['personName'] ?? 'Declaración'}',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.declaration['companyName'] ?? ''} · ${widget.declaration['status'] ?? ''}',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Text(
                  'La persona aún no envía sus artículos.',
                  style: TextStyle(color: _muted),
                ),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _panel(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      '${item['itemType'] ?? ''} · ${item['quantity'] ?? 0} × ${item['product'] ?? ''}\n${item['brand'] ?? ''} · ${item['model'] ?? ''} · Serie: ${item['serialNumber'] ?? ''} · ${item['color'] ?? ''}\n${item['notes'] ?? ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Entrada: ${entryDone ? 'Completada' : 'Pendiente'} · Salida: ${exitDone ? 'Completada' : 'Pendiente'}',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.declaration['status'] == 'Pendiente')
          TextButton.icon(
            onPressed: _saving ? null : _regenerateLink,
            icon: const Icon(Icons.link_rounded),
            label: const Text('Renovar enlace'),
          ),
        if (widget.declaration['status'] == 'Pendiente')
          TextButton.icon(
            onPressed: _saving ? null : _revokeLink,
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Revocar enlace'),
          ),
        if (canInspect && !entryDone)
          FilledButton.tonal(
            onPressed: _saving ? null : () => _inspect('entrada', items),
            child: const Text('Verificar entrada'),
          ),
        if (canInspect && entryDone && !exitDone)
          FilledButton.tonal(
            onPressed: _saving ? null : () => _inspect('salida', items),
            child: const Text('Verificar salida'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Future<void> _regenerateLink() async {
    try {
      final token = await widget.authService.createEquipmentDeclarationLink(
        widget.declaration['id'] as int,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: _panelBackground,
          title: const Text(
            'Enlace renovado',
            style: TextStyle(color: Colors.white),
          ),
          content: SelectableText(
            token,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: token));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Copiar token'),
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
