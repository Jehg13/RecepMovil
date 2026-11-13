import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';

const _managementBlue = Color(0xFF087FFF);
const _managementText = Color(0xFFF4F7FF);
const _managementMuted = Color(0xFFD4DDF0);

class CompanyManagementPage extends StatefulWidget {
  const CompanyManagementPage({
    super.key,
    required this.section,
    required this.authService,
    required this.user,
    this.dashboardHeader,
  });

  final String section;
  final AuthService authService;
  final AuthenticatedUser? user;
  final Widget? dashboardHeader;

  @override
  State<CompanyManagementPage> createState() => _CompanyManagementPageState();
}

class _CompanyManagementPageState extends State<CompanyManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _companies = [];
  List<Department> _departments = [];
  List<DepartmentHost> _departmentHosts = [];
  List<Map<String, dynamic>> _companyUsers = [];
  int? _selectedCompanyId;
  int? _directoryCompanyId;
  int? _selectedDepartmentId;
  int? _directoryUsersCompanyId;
  bool _directoryMembersLoaded = false;
  bool _loading = true;
  bool _directoryDetailsLoading = false;
  bool _generatingCode = false;
  String _searchQuery = '';
  String? _generatedCode;
  String? _generatedCodeCompany;
  String? _generatedCodeExpiresAt;
  String? _error;
  String? _directoryDetailsError;

  String get _title => switch (widget.section) {
    'companies' => 'Empresas',
    'departments' => 'Departamentos',
    'company_admins' => 'Administradores de empresa',
    'company_users' => 'Usuarios de empresa',
    'tablets' => 'Tablets',
    _ => 'Administración',
  };

  bool get _isGlobalAdmin => widget.user?.isAdmin == true;
  bool get _isCompanyAdmin => widget.user?.isCompanyAdmin == true;
  bool get _isDirectorySection =>
      widget.section == 'companies' || widget.section == 'departments';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _directoryCompany => _companies
      .where((company) => company['id'] == _directoryCompanyId)
      .firstOrNull;

  Department? get _selectedDepartment => _departments
      .where((department) => department.id == _selectedDepartmentId)
      .firstOrNull;

  List<Map<String, dynamic>> get _visibleRows {
    Iterable<Map<String, dynamic>> rows = _rows;
    if (_isGlobalAdmin &&
        _selectedCompanyId != null &&
        const {'company_admins', 'company_users', 'tablets'}.contains(
          widget.section,
        )) {
      rows = rows.where((row) => row['companyId'] == _selectedCompanyId);
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      rows = rows.where(
        (row) => row.values.any(
          (value) => value != null && value.toString().toLowerCase().contains(query),
        ),
      );
    }
    return rows.toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedCompanyId = widget.user?.companyId;
    _reload();
  }

  @override
  void didUpdateWidget(covariant CompanyManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section ||
        oldWidget.user?.login != widget.user?.login) {
      _searchController.clear();
      _searchQuery = '';
      _selectedCompanyId = widget.user?.companyId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _directoryDetailsError = null;
    });
    try {
      if (_isGlobalAdmin &&
          const {
            'company_admins',
            'company_users',
            'tablets',
          }.contains(widget.section)) {
        _companies = await widget.authService.getCompanies();
      }

      switch (widget.section) {
        case 'companies':
          _companies = await widget.authService.getCompanies();
          _rows = _companies;
          if (_directoryCompanyId != null &&
              _companies.any(
                (company) => company['id'] == _directoryCompanyId,
              )) {
            await _loadCompanyDirectory(_directoryCompanyId!);
          } else {
            _directoryCompanyId = null;
            _selectedDepartmentId = null;
            _clearDirectoryMembers();
          }
        case 'departments':
          _departments = await widget.authService.getDepartments();
          if (_isGlobalAdmin) {
            _companies = await widget.authService.getCompanies();
            if (_selectedCompanyId == null && _companies.isNotEmpty) {
              _selectedCompanyId = _companies.first['id'] as int;
            }
          } else if (_isCompanyAdmin) {
            final companyId = widget.user?.companyId;
            if (companyId == null) {
              throw const AuthApiException(
                'La cuenta no tiene una empresa asignada.',
              );
            }
            _selectedCompanyId = companyId;
            _departments = _departments
                .where((department) => department.companyId == companyId)
                .toList();
          }
          _rows = _departments
              .map(
                (department) => {
                  'id': department.id,
                  'name': department.name,
                  'companyId': department.companyId,
                },
              )
              .toList();
          final selectedDepartment = _selectedDepartment;
          if (selectedDepartment != null) {
            await _loadDepartmentMembers(selectedDepartment);
          } else {
            _clearDirectoryMembers();
          }
        case 'company_admins':
          _rows = await widget.authService.getCompanyAdministrators();
        case 'company_users':
          final companyId = _isCompanyAdmin
              ? widget.user?.companyId
              : _selectedCompanyId;
          if (_isCompanyAdmin && companyId == null) {
            throw const AuthApiException(
              'La cuenta no tiene una empresa asignada.',
            );
          }
          _rows = await widget.authService.getCompanyUsers(companyId);
          _departments = await widget.authService.getDepartments();
        case 'tablets':
          final data = await widget.authService.getTabletPairingCodes();
          final codes = data['codes'];
          if (codes is! List ||
              codes.any((item) => item is! Map<String, dynamic>)) {
            throw const AuthApiException(
              'La respuesta de códigos para tablets no es válida.',
            );
          }
          _rows = codes.cast<Map<String, dynamic>>();
      }
    } on AuthApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _directoryDetailsLoading = false;
        });
      }
    }
  }

  Future<void> _loadCompanyDirectory(int companyId) async {
    final results = await Future.wait<Object>([
      widget.authService.getDepartments(),
      widget.authService.getDepartmentHosts(),
      widget.authService.getCompanyUsers(companyId),
    ]);
    final departments = results[0] as List<Department>;
    final departmentIds = departments
        .where((department) => department.companyId == companyId)
        .map((department) => department.id)
        .toSet();
    _departments = departments
        .where((department) => department.companyId == companyId)
        .toList();
    _departmentHosts = (results[1] as List<DepartmentHost>)
        .where((host) => departmentIds.contains(host.departmentId))
        .toList();
    _companyUsers = (results[2] as List<Map<String, dynamic>>)
        .where((user) => user['companyId'] == companyId)
        .toList();
    _directoryUsersCompanyId = companyId;
    _directoryMembersLoaded = true;
    if (_selectedDepartmentId != null &&
        !_departments.any(
          (department) => department.id == _selectedDepartmentId,
        )) {
      _selectedDepartmentId = null;
    }
  }

  Future<void> _loadDepartmentMembers(Department department) async {
    final companyId = department.companyId;
    final results = await Future.wait<Object>([
      widget.authService.getDepartmentHosts(),
      if (companyId != null) widget.authService.getCompanyUsers(companyId),
    ]);
    _departmentHosts = results[0] as List<DepartmentHost>;
    _companyUsers = companyId == null
        ? []
        : results[1] as List<Map<String, dynamic>>;
    _directoryUsersCompanyId = companyId;
    _directoryMembersLoaded = true;
  }

  void _clearDirectoryMembers() {
    _departmentHosts = [];
    _companyUsers = [];
    _directoryUsersCompanyId = null;
    _directoryMembersLoaded = false;
  }

  Future<void> _selectCompany(int companyId) async {
    setState(() {
      _directoryCompanyId = companyId;
      _selectedDepartmentId = null;
      _directoryDetailsLoading = true;
      _directoryDetailsError = null;
      _clearDirectoryMembers();
    });
    try {
      await _loadCompanyDirectory(companyId);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _directoryDetailsError = error.message);
    } finally {
      if (mounted) setState(() => _directoryDetailsLoading = false);
    }
  }

  Future<void> _selectDepartment(Department department) async {
    setState(() {
      _selectedDepartmentId = department.id;
      if (_isGlobalAdmin) _selectedCompanyId = department.companyId;
      _directoryDetailsLoading = true;
      _directoryDetailsError = null;
    });
    try {
      if (!_directoryMembersLoaded ||
          _directoryUsersCompanyId != department.companyId) {
        await _loadDepartmentMembers(department);
      }
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _directoryDetailsError = error.message);
    } finally {
      if (mounted) setState(() => _directoryDetailsLoading = false);
    }
  }

  void _goBackInDirectory() {
    setState(() {
      _directoryDetailsError = null;
      if (_selectedDepartmentId != null) {
        _selectedDepartmentId = null;
      } else if (widget.section == 'companies') {
        _directoryCompanyId = null;
        _clearDirectoryMembers();
      }
    });
  }

  String _companyName(int? companyId) {
    if (companyId == null) return 'Empresa no disponible';
    final company = _companies
        .where((item) => item['id'] == companyId)
        .firstOrNull;
    if (company != null) return '${company['name']}';
    if (_isCompanyAdmin && companyId == widget.user?.companyId) {
      return 'Mi empresa';
    }
    return 'Empresa no disponible';
  }

  Future<bool?> _confirmManagementAction({
    required String title,
    required String description,
    required String confirmLabel,
    required IconData icon,
  }) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14243D), Color(0xFF091426)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x6653AFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x440087FF),
              blurRadius: 28,
              offset: Offset(0, 12),
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
                    color: const Color(0x22FF637A),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0x66FF637A)),
                  ),
                  child: Icon(icon, color: const Color(0xFFFF8B9D)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _managementText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  tooltip: 'Cerrar',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: _managementMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                color: _managementMuted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _managementMuted,
                      side: const BorderSide(color: Color(0x557A9BB8)),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD8435B), Color(0xFFFF687A)],
                        ),
                      ),
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          confirmLabel,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
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
  );

  List<_DepartmentMember> _membersForDepartment(Department department) {
    final departmentHosts = _departmentHosts
        .where((host) => host.departmentId == department.id)
        .toList();
    final hostLogins = departmentHosts
        .map((host) => host.login.trim().toLowerCase())
        .toSet();
    final hosts = departmentHosts.map(
      (host) => _DepartmentMember(
        id: 'host:${host.id}',
        name: host.name,
        login: host.login,
        role: host.role.isEmpty ? 'Anfitrión' : host.role,
        contact: host.email,
        access: host.accessRoles.isEmpty
            ? 'Anfitriones'
            : host.accessRoles.join(' · '),
      ),
    );
    final receptionUsers = _companyUsers
        .where((user) {
          final login = '${user['login'] ?? ''}'.trim().toLowerCase();
          return user['departmentId'] == department.id &&
              user['companyId'] == department.companyId &&
              const {
                'recepcion',
                'anfitrion',
                'anfitriones',
              }.contains(user['applicationRole']) &&
              !hostLogins.contains(login);
        })
        .map(
          (user) => _DepartmentMember(
            id: 'reception:${user['login']}',
            name: '${user['name'] ?? user['login'] ?? 'Usuario'}',
            login: '${user['login'] ?? ''}',
            role: '${user['role'] ?? ''}'.trim().isEmpty
                ? (user['applicationRole'] == 'recepcion'
                      ? 'Recepción'
                      : 'Anfitrión')
                : '${user['role']}',
            contact: '${user['email'] ?? ''}',
            access: user['applicationRole'] == 'recepcion'
                ? 'Recepción'
                : 'Anfitrión',
            isActive: user['active'] != 'N' && user['active'] != '0',
          ),
        );
    return [...hosts, ...receptionUsers];
  }

  int _departmentMemberCount(Department department) {
    if (_directoryMembersLoaded &&
        _directoryUsersCompanyId == department.companyId) {
      return _membersForDepartment(department).length;
    }
    return department.hostCount;
  }

  String _departmentCountLabel(Department department) =>
      _directoryMembersLoaded &&
          _directoryUsersCompanyId == department.companyId
      ? 'personas'
      : 'anfitriones';

  Future<void> _delete(
    Map<String, dynamic> row, {
    String? sectionOverride,
  }) async {
    final section = sectionOverride ?? widget.section;
    final identifier = section == 'company_admins' || section == 'company_users'
        ? '${row['login'] ?? ''}'
        : '${row['id'] ?? ''}';
    final recordName = '${row['name'] ?? row['login'] ?? identifier}';
    final confirmed = await _confirmManagementAction(
      title: switch (section) {
        'companies' => 'Eliminar empresa',
        'departments' => 'Eliminar departamento',
        'company_admins' => 'Eliminar administrador',
        'company_users' => 'Eliminar usuario',
        'tablets' => 'Eliminar código',
        _ => 'Eliminar registro',
      },
      description: section == 'tablets'
          ? 'Se eliminará el código de ${row['companyName'] ?? 'la empresa'} del historial. Si ya se utilizó, la tablet vinculada no se desvinculará.'
          : 'Se eliminará "$recordName". Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed != true) return;
    try {
      switch (section) {
        case 'companies':
          await widget.authService.deleteCompany(row['id'] as int);
        case 'departments':
          await widget.authService.deleteDepartment(row['id'] as int);
        case 'company_admins':
          await widget.authService.deleteCompanyAdministrator(
            row['login'] as String,
          );
        case 'company_users':
          await widget.authService.deleteCompanyUser(
            _selectedCompanyId!,
            row['login'] as String,
          );
        case 'tablets':
          await widget.authService.deleteTabletPairingCode(row['id'] as int);
      }
      await _reload();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createPairingCode() async {
    if (_generatingCode) return;
    final companyId = _selectedCompanyId;
    if (companyId == null) {
      _showMessage('Selecciona una empresa.');
      return;
    }
    setState(() {
      _generatingCode = true;
      _generatedCode = null;
    });
    try {
      final result = await widget.authService.createTabletPairingCode(
        companyId,
      );
      final code = result['code'];
      if (code is! String) {
        throw const AuthApiException(
          'El servidor no devolvió el código de vinculación.',
        );
      }
      final pairingCode = result['pairingCode'];
      if (pairingCode is! Map<String, dynamic> ||
          pairingCode['companyName'] is! String ||
          pairingCode['expiresAt'] is! String) {
        throw const AuthApiException(
          'El servidor devolvió datos incompletos del código de vinculación.',
        );
      }
      if (!mounted) return;
      setState(() {
        _generatedCode = code;
        _generatedCodeCompany = pairingCode['companyName'] as String;
        _generatedCodeExpiresAt = pairingCode['expiresAt'] as String;
      });
      await _reload();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  Future<void> _copyGeneratedCode() async {
    final code = _generatedCode;
    if (code == null) return;
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) _showMessage('Código copiado.');
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage(
          'No se pudo copiar el código: ${error.message ?? 'error desconocido'}.',
        );
      }
    }
  }

  Future<void> _revokeCode(int id) async {
    final confirmed = await _confirmManagementAction(
      title: 'Revocar código',
      description: 'El código dejará de poder vincular una tablet. Esta acción no se puede deshacer.',
      confirmLabel: 'Revocar',
      icon: Icons.link_off_rounded,
    );
    if (confirmed != true) return;
    try {
      await widget.authService.revokeTabletPairingCode(id);
      await _reload();
    } on AuthApiException catch (error) {
      if (mounted) _showMessage(error.message);
    }
  }

  Future<void> _editTabletName(Map<String, dynamic> row) async {
    final id = row['id'];
    if (id is! int || row['status'] != 'redeemed') {
      _showMessage('Solo puedes cambiar el nombre de una tablet vinculada.');
      return;
    }

    final controller = TextEditingController(
      text: '${row['deviceName'] ?? ''}',
    );
    var saving = false;
    var errorMessage = '';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF14243D), Color(0xFF091426)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x6653AFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x440087FF),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(19),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF087FFF), Color(0xFF14B8E8)],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.tablet_android_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IDENTIFICACIÓN',
                              style: TextStyle(
                                color: Color(0xFF69C9E9),
                                fontSize: 9,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Nombre de la tablet',
                              style: TextStyle(
                                color: _managementText,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close_rounded),
                        color: _managementMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  Text(
                    'Asigna un nombre fácil de reconocer en ${row['companyName'] ?? 'la empresa'}. El cambio no altera la vinculación.',
                    style: const TextStyle(
                      color: _managementMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(color: _managementText),
                    decoration: _formDecoration(
                      'Nombre de la tablet',
                      Icons.edit_outlined,
                      hint: 'Ej. Recepción principal',
                    ),
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Color(0xFFFFA0AF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _managementMuted,
                              side: const BorderSide(color: Color(0x557A9BB8)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _primaryButton(
                          label: saving ? 'Guardando…' : 'Guardar nombre',
                          icon: Icons.check_rounded,
                          busy: saving,
                          onPressed: saving
                              ? null
                              : () async {
                                  final name = controller.text.trim();
                                  if (name.isEmpty) {
                                    setDialogState(
                                      () => errorMessage =
                                          'Escribe un nombre para la tablet.',
                                    );
                                    return;
                                  }
                                  setDialogState(() {
                                    saving = true;
                                    errorMessage = '';
                                  });
                                  try {
                                    await widget.authService
                                        .updateTabletDeviceName(id, name);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext, true);
                                    }
                                  } on AuthApiException catch (error) {
                                    setDialogState(() {
                                      saving = false;
                                      errorMessage = error.message;
                                    });
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    controller.dispose();
    if (saved == true) await _reload();
  }

  IconData _formIcon(String section) => switch (section) {
    'companies' => Icons.business_rounded,
    'departments' => Icons.apartment_rounded,
    'company_admins' => Icons.admin_panel_settings_rounded,
    'company_users' => Icons.people_alt_rounded,
    _ => Icons.edit_note_rounded,
  };

  InputDecoration _formDecoration(
    String label,
    IconData icon, {
    String? hint,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: _managementMuted, fontSize: 13),
    hintStyle: const TextStyle(color: Color(0xFF71829D), fontSize: 12),
    prefixIcon: Icon(icon, color: const Color(0xFF55B7FF), size: 19),
    filled: true,
    fillColor: const Color(0xFF091325),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x334A93D5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF168BFF), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFFF7389)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFFF7389), width: 1.5),
    ),
  );

  Widget _managementDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<_ManagementDropdownOption<T>> options,
    required ValueChanged<T?>? onChanged,
  }) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    itemHeight: 56,
    menuMaxHeight: 340,
    dropdownColor: const Color(0xFF101D32),
    borderRadius: BorderRadius.circular(18),
    elevation: 16,
    icon: const Icon(
      Icons.keyboard_arrow_down_rounded,
      color: Color(0xFF74C5FF),
      size: 23,
    ),
    style: const TextStyle(
      color: _managementText,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
    decoration: _formDecoration(label, icon),
    selectedItemBuilder: (context) => options
        .map(
          (option) => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _managementText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        )
        .toList(),
    items: options
        .map(
          (option) => DropdownMenuItem<T>(
            value: option.value,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                gradient: option.value == value
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0x44258BEB), Color(0x2214B8E8)],
                      )
                    : null,
                color: option.value == value ? null : const Color(0xFF111F35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: option.value == value
                      ? const Color(0x884AABF4)
                      : const Color(0x334A9FEA),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0x332D83D1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      option.icon,
                      size: 17,
                      color: const Color(0xFF75C5FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _managementText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (option.value == value) ...[
                    const SizedBox(width: 7),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Color(0xFF64D7C0),
                    ),
                  ],
                ],
              ),
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool busy = false,
    double? width,
  }) => SizedBox(
    width: width,
    height: 48,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF087FFF), Color(0xFF3D8FFF), Color(0xFF00C8FF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330087FF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white54,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    ),
  );

  Future<void> _edit({
    Map<String, dynamic>? row,
    String? sectionOverride,
  }) async {
    final section = sectionOverride ?? widget.section;
    final sectionTitle = switch (section) {
      'companies' => 'Empresa',
      'departments' => 'Departamento',
      'company_admins' => 'Administrador de empresa',
      'company_users' => 'Usuario de empresa',
      _ => _title,
    };
    final isEditing = row != null;
    final name = TextEditingController(text: '${row?['name'] ?? ''}');
    final login = TextEditingController(text: '${row?['login'] ?? ''}');
    final email = TextEditingController(text: '${row?['email'] ?? ''}');
    final role = TextEditingController(text: '${row?['role'] ?? ''}');
    final phone = TextEditingController(text: '${row?['phone'] ?? ''}');
    final newPassword = TextEditingController();
    var selectedCompany =
        (row?['companyId'] as int?) ??
        _directoryCompanyId ??
        _selectedCompanyId;
    var selectedDepartment = row?['departmentId'] as int?;
    var selectedAccessRole = row?['applicationRole'] as String? ?? 'recepcion';
    var active = row?['active'] != 'N';
    var resetPassword = false;
    var formError = '';
    var isSaving = false;

    if (_isGlobalAdmin &&
        const {
          'companies',
          'departments',
          'company_admins',
        }.contains(section) &&
        _companies.isEmpty) {
      _companies = await widget.authService.getCompanies();
      if (selectedCompany == null && _companies.isNotEmpty) {
        selectedCompany = _companies.first['id'] as int;
      }
    }
    if (section == 'company_users' &&
        selectedCompany != null &&
        _departments.isEmpty) {
      _departments = await widget.authService.getDepartments();
    }
    if (!mounted) {
      name.dispose();
      login.dispose();
      email.dispose();
      role.dispose();
      phone.dispose();
      newPassword.dispose();
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final fields = <Widget>[];
          if (section == 'companies' || section == 'departments') {
            fields.add(
              TextField(
                controller: name,
                autofocus: true,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: _managementText),
                decoration: _formDecoration(
                  section == 'companies'
                      ? 'Nombre de empresa'
                      : 'Nombre del departamento',
                  section == 'companies'
                      ? Icons.business_outlined
                      : Icons.apartment_rounded,
                  hint: section == 'companies'
                      ? 'Ej. Cymez'
                      : 'Ej. Recursos Humanos',
                ),
              ),
            );
          }
          if (section == 'departments' && _isGlobalAdmin) {
            fields.add(
              _managementDropdown<int>(
                label: 'Empresa',
                icon: Icons.business_outlined,
                value: selectedCompany,
                options: _companies
                    .map(
                      (company) => _ManagementDropdownOption<int>(
                        value: company['id'] as int,
                        label: '${company['name']}',
                        icon: Icons.business_rounded,
                      ),
                    )
                    .toList(),
                onChanged: isEditing
                    ? null
                    : (value) => setDialogState(() => selectedCompany = value),
              ),
            );
          }
          if (section == 'company_admins' || section == 'company_users') {
            fields.addAll([
              TextField(
                controller: login,
                enabled: !isEditing,
                style: const TextStyle(color: _managementText),
                textCapitalization: TextCapitalization.none,
                decoration: _formDecoration(
                  'Usuario',
                  Icons.person_outline_rounded,
                  hint: 'Nombre de usuario',
                ),
              ),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: _managementText),
                decoration: _formDecoration(
                  'Nombre completo',
                  Icons.badge_outlined,
                ),
              ),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: _managementText),
                decoration: _formDecoration(
                  'Correo electrónico',
                  Icons.mail_outline_rounded,
                ),
              ),
              TextField(
                controller: role,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: _managementText),
                decoration: _formDecoration(
                  'Puesto',
                  Icons.work_outline_rounded,
                ),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: _managementText),
                decoration: _formDecoration('Teléfono', Icons.phone_outlined),
              ),
            ]);
            if (section == 'company_users' && _isGlobalAdmin) {
              fields.add(
                _managementDropdown<int>(
                  label: 'Empresa',
                  icon: Icons.business_outlined,
                  value: selectedCompany,
                  options: _companies
                      .map(
                        (company) => _ManagementDropdownOption<int>(
                          value: company['id'] as int,
                          label: '${company['name']}',
                          icon: Icons.business_rounded,
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    selectedCompany = value;
                    selectedDepartment = null;
                  }),
                ),
              );
            }
            if (section == 'company_admins') {
              if (isEditing) {
                fields.add(
                  TextField(
                    controller: newPassword,
                    obscureText: true,
                    style: const TextStyle(color: _managementText),
                    decoration: _formDecoration(
                      'Nueva contraseña temporal (opcional)',
                      Icons.lock_outline_rounded,
                    ),
                  ),
                );
              }
              fields.add(
                _managementDropdown<int>(
                  label: 'Empresa',
                  icon: Icons.business_outlined,
                  value: selectedCompany,
                  options: _companies
                      .map(
                        (company) => _ManagementDropdownOption<int>(
                          value: company['id'] as int,
                          label: '${company['name']}',
                          icon: Icons.business_rounded,
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedCompany = value),
                ),
              );
            } else {
              fields.add(
                _managementDropdown<String>(
                  label: 'Perfil de acceso',
                  icon: Icons.shield_outlined,
                  value: selectedAccessRole,
                  options: const [
                    _ManagementDropdownOption(
                      value: 'recepcion',
                      label: 'Recepción',
                      icon: Icons.support_agent_rounded,
                    ),
                    _ManagementDropdownOption(
                      value: 'anfitrion',
                      label: 'Anfitrión',
                      icon: Icons.handshake_outlined,
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => selectedAccessRole = value ?? 'recepcion',
                  ),
                ),
              );
              fields.add(
                _managementDropdown<int>(
                  label: 'Departamento',
                  icon: Icons.apartment_rounded,
                  value: selectedDepartment,
                  options: _departments
                      .where(
                        (department) =>
                            department.companyId == null ||
                            department.companyId == selectedCompany,
                      )
                      .map(
                        (department) => _ManagementDropdownOption<int>(
                          value: department.id,
                          label: department.name,
                          icon: Icons.apartment_rounded,
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedDepartment = value),
                ),
              );
            }
            fields.add(
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text('Cuenta activa'),
                value: active,
                activeThumbColor: const Color(0xFF18B7D8),
                onChanged: (value) => setDialogState(() => active = value),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: const Color(0xFF101D32),
              ),
            );
            if (section == 'company_users' && isEditing) {
              fields.add(
                CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('Restablecer contraseña temporal'),
                  value: resetPassword,
                  activeColor: const Color(0xFF168BFF),
                  onChanged: (value) =>
                      setDialogState(() => resetPassword = value ?? false),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  tileColor: const Color(0xFF101D32),
                ),
              );
            }
          }
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 22,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: 480,
                maxHeight: MediaQuery.sizeOf(context).height * 0.9,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF14243D), Color(0xFF091426)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x6653AFFF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x440087FF),
                    blurRadius: 30,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 19, 13, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF087FFF), Color(0xFF14B8E8)],
                            ),
                            borderRadius: BorderRadius.circular(17),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x440087FF),
                                blurRadius: 14,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            _formIcon(section),
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ADMINISTRACIÓN',
                                style: TextStyle(
                                  color: Color(0xFF69C9E9),
                                  fontSize: 9,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${isEditing ? 'Editar' : 'Registrar'} $sectionTitle',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _managementText,
                                  fontSize: 18,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEditing
                                    ? 'Actualiza la información y guarda los cambios.'
                                    : 'Completa los datos para dar de alta el registro.',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _managementMuted,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(context, false),
                          tooltip: 'Cerrar',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0x221E88D5),
                            foregroundColor: _managementMuted,
                          ),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0x223D9DFF)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(19, 17, 19, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final field in fields) ...[
                            field,
                            const SizedBox(height: 12),
                          ],
                          if (formError.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x33FF516A),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: const Color(0x77FF7389),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: Color(0xFFFF9AAA),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      formError,
                                      style: const TextStyle(
                                        color: Color(0xFFFFC2CB),
                                        fontSize: 12,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(19, 9, 19, 18),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _managementMuted,
                                side: const BorderSide(
                                  color: Color(0x557A9BB8),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _primaryButton(
                            label: isEditing ? 'Guardar cambios' : 'Registrar',
                            icon: Icons.check_rounded,
                            busy: isSaving,
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isSaving = true;
                                      formError = '';
                                    });
                                    try {
                                      switch (section) {
                                        case 'companies':
                                          await widget.authService.saveCompany(
                                            name.text,
                                            id: row?['id'] as int?,
                                          );
                                        case 'departments':
                                          if (isEditing) {
                                            await widget.authService
                                                .updateDepartment(
                                                  row['id'] as int,
                                                  name.text,
                                                );
                                          } else {
                                            await widget.authService
                                                .createDepartment(
                                                  name.text,
                                                  companyId: selectedCompany,
                                                );
                                          }
                                        case 'company_admins':
                                          if (selectedCompany == null) {
                                            throw const AuthApiException(
                                              'Selecciona una empresa.',
                                            );
                                          }
                                          final result = await widget
                                              .authService
                                              .saveCompanyAdministrator(
                                                {
                                                  'login': login.text.trim(),
                                                  'name': name.text.trim(),
                                                  'email': email.text.trim(),
                                                  'role': role.text.trim(),
                                                  'phone': phone.text.trim(),
                                                  'active': active ? 'Y' : 'N',
                                                  'companyId': selectedCompany,
                                                  if (newPassword
                                                      .text
                                                      .isNotEmpty)
                                                    'password':
                                                        newPassword.text,
                                                },
                                                login: row?['login'] as String?,
                                              );
                                          await _showTemporaryPassword(result);
                                        case 'company_users':
                                          if (selectedCompany == null ||
                                              selectedDepartment == null) {
                                            throw const AuthApiException(
                                              'Selecciona una empresa y un departamento.',
                                            );
                                          }
                                          final result = await widget
                                              .authService
                                              .saveCompanyUser(
                                                selectedCompany!,
                                                {
                                                  'login': login.text.trim(),
                                                  'name': name.text.trim(),
                                                  'email': email.text.trim(),
                                                  'role': role.text.trim(),
                                                  'phone': phone.text.trim(),
                                                  'active': active ? 'Y' : 'N',
                                                  'applicationRole':
                                                      selectedAccessRole,
                                                  'departmentId':
                                                      selectedDepartment,
                                                  'resetPassword':
                                                      resetPassword,
                                                },
                                                login: row?['login'] as String?,
                                              );
                                          await _showTemporaryPassword(result);
                                      }
                                      if (context.mounted) {
                                        Navigator.pop(context, true);
                                      }
                                    } on AuthApiException catch (error) {
                                      setDialogState(() {
                                        isSaving = false;
                                        formError = error.message;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    await Future<void>.delayed(kThemeAnimationDuration);
    name.dispose();
    login.dispose();
    email.dispose();
    role.dispose();
    phone.dispose();
    newPassword.dispose();
    if (saved == true) await _reload();
  }

  Future<void> _showTemporaryPassword(Map<String, dynamic> result) async {
    final temporaryPassword = result['temporaryPassword'];
    if (temporaryPassword is! String || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF14243D), Color(0xFF091426)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x6653AFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x440087FF),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF087FFF), Color(0xFF14B8E8)],
                  ),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'CONTRASEÑA TEMPORAL',
                style: TextStyle(
                  color: Color(0xFF69C9E9),
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Acceso creado',
                style: TextStyle(
                  color: _managementText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Comparte esta contraseña de forma segura. El usuario deberá cambiarla al iniciar sesión.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _managementMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF081326),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0x554A9BE0)),
                ),
                child: SelectableText(
                  temporaryPassword,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF83C9FF),
                    fontSize: 21,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _managementMuted,
                        side: const BorderSide(color: Color(0x557A9BB8)),
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Listo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _primaryButton(
                      label: 'Copiar',
                      icon: Icons.copy_rounded,
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: temporaryPassword),
                          );
                          if (mounted) _showMessage('Contraseña copiada.');
                        } on PlatformException catch (error) {
                          if (mounted) {
                            _showMessage(
                              'No se pudo copiar la contraseña: ${error.message ?? 'error desconocido'}.',
                            );
                          }
                        }
                      },
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

  String _statusLabel(Object? status) => switch ('$status') {
    'active' => 'Pendiente',
    'redeemed' => 'Vinculada',
    'expired' => 'Vencido',
    'revoked' => 'Revocado',
    'Y' || '1' => 'Activo',
    'N' || '0' => 'Inactivo',
    _ => '—',
  };

  String _formatDateTime(BuildContext context, Object? value) {
    if (value is! String || value.trim().isEmpty) return '—';
    final parsed = DateTime.tryParse(
      value.contains('T') ? value : value.replaceFirst(' ', 'T'),
    );
    if (parsed == null) return value;
    final date = parsed.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final time = TimeOfDay.fromDateTime(date);
    return '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(time)}';
  }

  Widget _cardShell({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF14243D), Color(0xFF0B1528)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x664A9FEA)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x200087FF),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, Object? value) {
    final text = value == null || '$value'.trim().isEmpty ? '—' : '$value';
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF55B7FF)),
          const SizedBox(width: 9),
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(color: _managementMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _managementText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, {required bool active}) {
    final color = active ? const Color(0xFF4AE3B5) : const Color(0xFFFF9AAE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _cardActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool destructive = false,
  }) {
    final color = destructive
        ? const Color(0xFFFFA0AF)
        : const Color(0xFF8FD1FF);
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor: destructive
              ? const Color(0x22FF516A)
              : const Color(0x22168BFF),
          side: BorderSide(
            color: destructive
                ? const Color(0x66FF7389)
                : const Color(0x6655B7FF),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _cardActionRow({
    required String primaryLabel,
    required IconData primaryIcon,
    required VoidCallback onPrimary,
    required String destructiveLabel,
    required VoidCallback onDelete,
  }) => Row(
    children: [
      Expanded(
        child: _cardActionButton(
          label: primaryLabel,
          icon: primaryIcon,
          onPressed: onPrimary,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _cardActionButton(
          label: destructiveLabel,
          icon: Icons.delete_outline_rounded,
          onPressed: onDelete,
          destructive: true,
        ),
      ),
    ],
  );

  Widget _rowActions(Map<String, dynamic> row) => _cardActionRow(
    primaryLabel: 'Editar',
    primaryIcon: Icons.edit_outlined,
    onPrimary: () => _edit(row: row),
    destructiveLabel: 'Eliminar',
    onDelete: () => _delete(row),
  );

  Widget _entityCard(Map<String, dynamic> row, BuildContext context) {
    if (widget.section == 'tablets') {
      final status = '${row['status'] ?? ''}';
      final deviceName = row['deviceName'];
      final isLinked = status == 'redeemed';
      return _cardShell(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D3C70), Color(0xFF105CA4)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0x554A9FEA)),
                  ),
                  child: const Icon(
                    Icons.tablet_android_rounded,
                    color: Color(0xFF75C5FF),
                    size: 23,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLinked &&
                                deviceName is String &&
                                deviceName.isNotEmpty
                            ? deviceName
                            : 'Código de vinculación',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _managementText,
                          fontSize: 15,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${row['companyName'] ?? 'Empresa'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _managementMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(
                  _statusLabel(status),
                  active: status == 'redeemed',
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0x334A9FEA)),
            ),
            if (deviceName is String && deviceName.isNotEmpty)
              _detailRow(
                Icons.label_outline_rounded,
                'Dispositivo',
                deviceName,
              ),
            _detailRow(
              Icons.person_outline_rounded,
              'Generado por',
              row['createdBy'],
            ),
            _detailRow(
              Icons.schedule_rounded,
              'Creación',
              _formatDateTime(context, row['createdAt']),
            ),
            _detailRow(
              Icons.event_outlined,
              'Vencimiento',
              _formatDateTime(context, row['expiresAt']),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0x334A9FEA)),
            ),
            Row(
              children: [
                if (status == 'active') ...[
                  Expanded(
                    child: _cardActionButton(
                      label: 'Revocar',
                      icon: Icons.link_off_rounded,
                      onPressed: () => _revokeCode(row['id'] as int),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else if (isLinked) ...[
                  Expanded(
                    child: _cardActionButton(
                      label: 'Editar nombre',
                      icon: Icons.edit_outlined,
                      onPressed: () => _editTabletName(row),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  const Spacer(),
                ],
                Expanded(
                  child: _cardActionButton(
                    label: 'Eliminar',
                    icon: Icons.delete_outline_rounded,
                    onPressed: () => _delete(row),
                    destructive: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final isCompanyUser = widget.section == 'company_users';
    final title = '${row['name'] ?? row['login'] ?? 'Usuario'}';
    final active = row['active'] != 'N' && row['active'] != '0';
    return _cardShell(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
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
                    colors: [Color(0xFF168BFF), Color(0xFF18B7D8)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  isCompanyUser
                      ? Icons.person_outline_rounded
                      : Icons.admin_panel_settings_outlined,
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _managementText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Usuario · ${row['login'] ?? '—'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7ABEFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(active ? 'Activo' : 'Inactivo', active: active),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0x334A9FEA)),
          ),
          _detailRow(
            Icons.badge_outlined,
            isCompanyUser ? 'Perfil' : 'Puesto',
            isCompanyUser
                ? (row['applicationRole'] == 'anfitrion'
                      ? 'Anfitrión'
                      : 'Recepción')
                : (row['role'] ?? 'Administrador'),
          ),
          if (isCompanyUser)
            _detailRow(
              Icons.apartment_rounded,
              'Departamento',
              row['departmentName'],
            ),
          _detailRow(
            Icons.business_outlined,
            'Empresa',
            row['companyName'] ?? _companyName(row['companyId'] as int?),
          ),
          _detailRow(Icons.mail_outline_rounded, 'Correo', row['email']),
          if (row['phone'] != null && '${row['phone']}'.isNotEmpty)
            _detailRow(Icons.phone_outlined, 'Teléfono', row['phone']),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0x334A9FEA)),
          ),
          _rowActions(row),
        ],
      ),
    );
  }

  Widget _directoryActions({
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) => PopupMenuButton<String>(
    tooltip: 'Acciones del registro',
    icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94CFFF)),
    color: const Color(0xFF12223A),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    onSelected: (action) {
      if (action == 'edit') onEdit();
      if (action == 'delete') onDelete();
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: 'edit',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.edit_outlined),
          title: Text('Editar'),
        ),
      ),
      PopupMenuItem(
        value: 'delete',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.delete_outline_rounded),
          title: Text('Eliminar'),
        ),
      ),
    ],
  );

  Widget _companyCard(Map<String, dynamic> company) => _cardShell(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _selectCompany(company['id'] as int),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D3C70), Color(0xFF105CA4)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x334A9FEA)),
              ),
              child: const Icon(
                Icons.business_rounded,
                color: Color(0xFF57B8FF),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${company['name'] ?? 'Empresa'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _managementText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Ver departamentos y empleados',
                    style: TextStyle(color: _managementMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF75BFFF)),
            _directoryActions(
              onEdit: () => _edit(row: company),
              onDelete: () => _delete(company, sectionOverride: 'companies'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _departmentCard(Department department) => _cardShell(
    padding: EdgeInsets.zero,
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _selectDepartment(department),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D3C70), Color(0xFF105CA4)],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0x334A9FEA)),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                color: Color(0xFF57B8FF),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    department.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _managementText,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isGlobalAdmin
                        ? _companyName(department.companyId)
                        : 'Mi empresa',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _managementMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  '${_departmentMemberCount(department)}',
                  style: const TextStyle(
                    color: Color(0xFF73C6FF),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _departmentCountLabel(department),
                  style: const TextStyle(color: _managementMuted, fontSize: 9),
                ),
              ],
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF75BFFF)),
            _directoryActions(
              onEdit: () => _edit(
                row: {
                  'id': department.id,
                  'name': department.name,
                  'companyId': department.companyId,
                },
                sectionOverride: 'departments',
              ),
              onDelete: () => _delete({
                'id': department.id,
                'name': department.name,
                'companyId': department.companyId,
              }, sectionOverride: 'departments'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _memberCard(_DepartmentMember member) => _cardShell(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0x332D83D1),
              child: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF55B7FF),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _managementText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    member.login,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7ABEFF),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _statusBadge(
              member.isActive ? 'Activo' : 'Inactivo',
              active: member.isActive,
            ),
          ],
        ),
        _detailRow(Icons.work_outline_rounded, 'Puesto', member.role),
        _detailRow(Icons.shield_outlined, 'Perfil', member.access),
        _detailRow(Icons.mail_outline_rounded, 'Correo', member.contact),
      ],
    ),
  );

  List<Widget> _directoryCards(double width) {
    final children = <Widget>[];
    if (widget.section == 'companies' && _directoryCompany == null) {
      children.addAll(_companies.map(_companyCard));
    } else if (widget.section == 'companies' && _selectedDepartmentId == null) {
      children.addAll(_departments.map(_departmentCard));
    } else if (_selectedDepartment != null) {
      children.addAll(
        _membersForDepartment(_selectedDepartment!).map(_memberCard),
      );
    } else {
      children.addAll(_departments.map(_departmentCard));
    }
    if (children.isEmpty) {
      final message = widget.section == 'companies' && _directoryCompany == null
          ? 'Aún no hay empresas registradas.'
          : _selectedDepartment != null
          ? 'No hay empleados vinculados a este departamento.'
          : 'Esta empresa todavía no tiene departamentos.';
      return [
        _cardShell(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _managementMuted),
              ),
            ),
          ),
        ),
      ];
    }
    final cardWidth = width >= 720 ? (width - 12) / 2 : width;
    return children
        .map((child) => SizedBox(width: cardWidth, child: child))
        .toList();
  }

  Widget _directoryHeading() {
    final department = _selectedDepartment;
    final company = _directoryCompany;
    final canGoBack =
        _selectedDepartmentId != null ||
        (widget.section == 'companies' && company != null);
    if (!canGoBack) return const SizedBox.shrink();
    final label = department != null
        ? 'Volver a departamentos'
        : 'Volver a empresas';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _goBackInDirectory,
            icon: const Icon(Icons.arrow_back_rounded),
            color: const Color(0xFF69B8FF),
            tooltip: label,
          ),
          Expanded(
            child: Text(
              department != null
                  ? '${_directoryCompany?['name'] ?? _companyName(department.companyId)} · ${department.name}'
                  : '${company?['name'] ?? 'Empresa'} · Departamentos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _managementMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _generatedCodeCard(BuildContext context) {
    final code = _generatedCode;
    if (code == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _cardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Código para vincular tablet',
              style: TextStyle(
                color: _managementText,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Empresa: ${_generatedCodeCompany ?? '—'} · Vence ${_formatDateTime(context, _generatedCodeExpiresAt)}',
              style: const TextStyle(color: _managementMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      color: Color(0xFF73C6FF),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                ),
                _primaryButton(
                  width: 120,
                  label: 'Copiar',
                  icon: Icons.copy_rounded,
                  onPressed: _copyGeneratedCode,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Es de un solo uso y vence en 10 minutos. Si se pierde, revócalo y genera otro.',
              style: TextStyle(color: _managementMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabletInstructionsCard() => _cardShell(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF63B8FF)),
        const SizedBox(width: 11),
        const Expanded(
          child: Text(
            'El código se usa una sola vez, vence en 10 minutos y queda asignado a la empresa seleccionada. Al vincular la tablet puedes cambiar su nombre desde esta tarjeta.',
            style: TextStyle(
              color: _managementMuted,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );

  String get _directoryTitle {
    if (_selectedDepartment != null) return _selectedDepartment!.name;
    if (_directoryCompany != null) {
      return '${_directoryCompany!['name'] ?? 'Empresa'}';
    }
    return _title;
  }

  String get _directorySubtitle {
    if (_selectedDepartment != null) return 'Empleados de este departamento';
    if (_directoryCompany != null) return 'Departamentos de esta empresa';
    if (widget.section == 'companies') {
      return 'Selecciona una empresa para consultar sus departamentos y empleados.';
    }
    return _isCompanyAdmin
        ? 'Departamentos y empleados de tu empresa.'
        : 'Explora los departamentos disponibles.';
  }

  IconData get _sectionIcon {
    if (_selectedDepartment != null) return Icons.people_alt_rounded;
    return switch (widget.section) {
      'companies' => Icons.business_rounded,
      'departments' => Icons.apartment_rounded,
      'company_admins' => Icons.admin_panel_settings_rounded,
      'company_users' => Icons.people_alt_rounded,
      'tablets' => Icons.tablet_android_rounded,
      _ => Icons.dashboard_customize_rounded,
    };
  }

  String get _sectionEyebrow => switch (widget.section) {
    'companies' || 'departments' => 'ORGANIZACIÓN',
    'company_admins' => 'ADMINISTRACIÓN',
    'company_users' => 'CUENTAS DE EMPRESA',
    'tablets' => 'VISITAS SIN CITA',
    _ => 'GESTIÓN',
  };

  @override
  Widget build(BuildContext context) {
    final visibleRows = _visibleRows;
    final userManagement = const {
      'company_admins',
      'company_users',
      'tablets',
    }.contains(widget.section);
    final canAdd = switch (widget.section) {
      'companies' => _directoryCompany == null || _selectedDepartmentId == null,
      'departments' => _selectedDepartmentId == null,
      'company_admins' || 'company_users' => true,
      _ => false,
    };
    final addLabel = widget.section == 'companies' && _directoryCompany != null
        ? 'Agregar departamento'
        : switch (widget.section) {
            'companies' => 'Agregar empresa',
            'departments' => 'Agregar departamento',
            'company_admins' => 'Agregar administrador',
            'company_users' => 'Agregar usuario',
            _ => 'Agregar',
          };
    final sectionTitle = _isDirectorySection ? _directoryTitle : _title;
    final sectionSubtitle = _isDirectorySection
        ? _directorySubtitle
        : switch (widget.section) {
            'company_users' => 'Cuentas, perfiles y departamentos asignados.',
            'company_admins' => 'Administradores y empresa a su cargo.',
            'tablets' => 'Códigos de vinculación para visitas sin cita.',
            _ => '',
          };

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101936), Color(0xFF091329), Color(0xFF050A16)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (widget.dashboardHeader != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: widget.dashboardHeader!,
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                      color: _managementText,
                      tooltip: 'Abrir menú',
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _loading ? null : _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      color: const Color(0xFF68B8FF),
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D3C70), Color(0xFF105CA4)],
                      ),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: const Color(0x554CAFFF)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x220087FF),
                          blurRadius: 16,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      _sectionIcon,
                      color: const Color(0xFF75C5FF),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sectionEyebrow,
                          style: const TextStyle(
                            color: Color(0xFF68BCEB),
                            fontSize: 9,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sectionTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _managementText,
                            fontSize: 21,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (sectionSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            sectionSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _managementMuted,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF123052),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x553D9DFF)),
                    ),
                    child: IconButton(
                      onPressed: _loading ? null : _reload,
                      tooltip: 'Actualizar',
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      color: const Color(0xFF70C2FF),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            if (userManagement && _isGlobalAdmin)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 3, 16, 8),
                child: _cardShell(
                  padding: const EdgeInsets.all(12),
                  child: _managementDropdown<int?>(
                    label: widget.section == 'tablets'
                        ? 'Filtrar o asignar empresa'
                        : 'Filtrar por empresa',
                    icon: Icons.business_outlined,
                    value:
                        _companies.any(
                          (company) => company['id'] == _selectedCompanyId,
                        )
                        ? _selectedCompanyId
                        : null,
                    options: [
                      const _ManagementDropdownOption<int?>(
                        value: null,
                        label: 'Todas las empresas',
                        icon: Icons.business_center_rounded,
                      ),
                      ..._companies.map(
                        (company) => _ManagementDropdownOption<int?>(
                          value: company['id'] as int,
                          label: '${company['name']}',
                          icon: Icons.business_rounded,
                        ),
                      ),
                    ],
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCompanyId = value;
                              _generatedCode = null;
                            });
                            _reload();
                          },
                  ),
                ),
              ),
            if (userManagement)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _cardShell(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    style: const TextStyle(
                      color: _managementText,
                      fontSize: 13,
                    ),
                    decoration: _formDecoration(
                      'Buscar registros',
                      Icons.search_rounded,
                      hint: 'Nombre, usuario, correo o empresa',
                    ).copyWith(
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              }),
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: _managementMuted,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            if (canAdd || widget.section == 'tablets')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _primaryButton(
                    width: 220,
                    label: widget.section == 'tablets'
                        ? (_generatingCode ? 'Generando…' : 'Generar código')
                        : addLabel,
                    icon: widget.section == 'tablets'
                        ? Icons.add_link_rounded
                        : Icons.add_rounded,
                    busy: _generatingCode,
                    onPressed:
                        _loading ||
                            (widget.section == 'tablets' &&
                                (_selectedCompanyId == null ||
                                    _generatingCode)) ||
                            (widget.section == 'company_users' &&
                                _departments.isEmpty)
                        ? null
                        : widget.section == 'tablets'
                        ? _createPairingCode
                        : widget.section == 'companies' &&
                              _directoryCompany != null
                        ? () => _edit(sectionOverride: 'departments')
                        : () => _edit(),
                  ),
                ),
              ),
            if (_isDirectorySection)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _directoryHeading(),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _managementBlue),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _cardShell(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: _managementMuted),
                              ),
                              TextButton.icon(
                                onPressed: _reload,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final contentWidth = constraints.maxWidth - 28;
                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              14,
                              5,
                              14,
                              MediaQuery.paddingOf(context).bottom + 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.section == 'tablets')
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _tabletInstructionsCard(),
                                  ),
                                if (widget.section == 'tablets')
                                  _generatedCodeCard(context),
                                if (_directoryDetailsLoading)
                                  const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: _managementBlue,
                                      ),
                                    ),
                                  ),
                                if (_directoryDetailsError != null)
                                  _cardShell(
                                    child: Text(
                                      _directoryDetailsError!,
                                      style: const TextStyle(
                                        color: _managementMuted,
                                      ),
                                    ),
                                  ),
                                if (_isDirectorySection)
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _directoryCards(contentWidth),
                                  )
                                else if (visibleRows.isEmpty)
                                  _cardShell(
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 22,
                                        ),
                                        child: Text(
                                          _rows.isNotEmpty
                                              ? 'No hay registros que coincidan con la búsqueda o empresa seleccionada.'
                                              : widget.section ==
                                                        'company_users' &&
                                                    _departments.isEmpty
                                              ? 'Registra departamentos antes de crear usuarios.'
                                              : widget.section == 'tablets'
                                              ? 'Aún no hay códigos de vinculación.'
                                              : 'No hay registros para mostrar.',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: _managementMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: visibleRows
                                        .map(
                                          (row) => SizedBox(
                                            width: contentWidth >= 720
                                                ? (contentWidth - 12) / 2
                                                : contentWidth,
                                            child: _entityCard(row, context),
                                          ),
                                        )
                                        .toList(),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepartmentMember {
  const _DepartmentMember({
    required this.id,
    required this.name,
    required this.login,
    required this.role,
    required this.contact,
    required this.access,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String login;
  final String role;
  final String contact;
  final String access;
  final bool isActive;
}

class _ManagementDropdownOption<T> {
  const _ManagementDropdownOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}
