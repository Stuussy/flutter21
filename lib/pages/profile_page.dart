import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'add_pc_page.dart';
import 'game_info_page.dart';
import 'settings_page.dart';
import 'about_page.dart';
import '../utils/session_manager.dart';
import '../utils/api_config.dart';
import '../utils/theme_manager.dart';
import '../utils/favorites_manager.dart';
import '../utils/app_colors.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final String userEmail;
  const ProfilePage({super.key, required this.userEmail});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? userData;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isRefreshing = false;
  bool _showAllHistory = false;

  List<Map<String, dynamic>> checkHistory = [];
  int _favoritesCount = 0;
  Timer? _refreshTimer;

  static const _purple  = Color(0xFF6C63FF);
  static const _green   = Color(0xFF4CAF50);
  static const _amber   = Color(0xFFFFB300);
  static const _orange  = Color(0xFFFFA726);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    FavoritesManager.changeCount.addListener(_loadFavCount);
    SessionManager.pcChangeCount.addListener(_onPCChanged);
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => fetchUserData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    FavoritesManager.changeCount.removeListener(_loadFavCount);
    SessionManager.pcChangeCount.removeListener(_onPCChanged);
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([fetchUserData(), _loadFavCount()]);
  }

  void _onPCChanged() => fetchUserData();

  Future<void> _loadFavCount() async {
    final favs = await FavoritesManager.getFavorites();
    if (mounted) setState(() => _favoritesCount = favs.length);
  }

  Future<void> fetchUserData({bool silent = false}) async {
    if (_isRefreshing) return;
    if (!silent && mounted) setState(() => _isRefreshing = true);
    try {
      final token = await SessionManager.getAuthToken() ?? '';
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/${widget.userEmail}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 401) {
        await SessionManager.handleUnauthorized(context);
        return;
      } else if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && mounted) {
          final raw = (data['user']['checkHistory'] as List<dynamic>? ?? []);
          setState(() {
            userData = data['user'];
            checkHistory = raw.reversed.map((e) {
              final s = e['status'] as String? ?? '';
              return {
                'game':   e['game'] as String? ?? '',
                'fps':    e['fps'] ?? 0,
                'result': _statusText(s),
                'icon':   _statusIcon(s),
                'color':  _statusColor(s),
              };
            }).toList();
            _isRefreshing = false;
          });
        }
      } else {
        if (mounted) setState(() => _isRefreshing = false);
      }
    } catch (e) {
      debugPrint('Ошибка профиля: $e');
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ── status helpers ───────────────────────────────────────────────────────────
  String _statusText(String s) {
    switch (s) {
      case 'excellent':   return 'Отлично';
      case 'good':        return 'Хорошо';
      case 'playable':    return 'Играбельно';
      case 'insufficient':return 'Недостаточно';
      default:            return 'Неизвестно';
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'excellent':   return Icons.check_circle_rounded;
      case 'good':        return Icons.thumb_up_rounded;
      case 'playable':    return Icons.warning_rounded;
      case 'insufficient':return Icons.cancel_rounded;
      default:            return Icons.help_rounded;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'excellent':   return _green;
      case 'good':        return _purple;
      case 'playable':    return _orange;
      case 'insufficient':return Colors.red;
      default:            return Colors.grey;
    }
  }

  // ── misc ─────────────────────────────────────────────────────────────────────
  String _initials() {
    final name = (userData?['username'] as String? ?? '').trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  bool get _hasPc {
    final pc = userData?['pcSpecs'];
    return pc != null && (pc['cpu'] as String? ?? '').isNotEmpty;
  }

  int get _bestFps => checkHistory.isEmpty
      ? 0
      : checkHistory
          .map((c) => c['fps'] as int)
          .reduce((a, b) => a > b ? a : b);

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── dialogs ──────────────────────────────────────────────────────────────────
  void _showEditUsernameDialog() {
    final ctrl = TextEditingController(text: userData?['username'] ?? '');
    bool saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final dac = AppColors.of(ctx);
          return AlertDialog(
          backgroundColor: dac.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.edit_rounded, color: _purple, size: 22),
            const SizedBox(width: 10),
            Text('Изменить имя',
                style: TextStyle(color: dac.text, fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          content: _dialogField(ctrl, 'Новое имя', Icons.person_outline),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text('Отмена', style: TextStyle(color: dac.textMuted)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = ctrl.text.trim();
                      if (name.isEmpty) return;
                      set(() => saving = true);
                      try {
                        final token = await SessionManager.getAuthToken() ?? '';
                        final r = await http.post(
                          Uri.parse('${ApiConfig.baseUrl}/update-profile'),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode({'email': widget.userEmail, 'username': name}),
                        );
                        if (!mounted) return;
                        if (r.statusCode == 401) {
                          Navigator.pop(ctx);
                          await SessionManager.handleUnauthorized(context);
                          return;
                        }
                        final d = jsonDecode(r.body);
                        if (d['success'] == true) {
                          Navigator.pop(ctx);
                          await fetchUserData();
                          _snack('Имя успешно изменено', _green);
                        } else {
                          _snack(d['message'] ?? 'Ошибка', Colors.red);
                        }
                      } catch (_) {
                        _snack('Ошибка соединения', Colors.red);
                      } finally {
                        set(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Сохранить', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
        },
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldCtrl  = TextEditingController();
    final newCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    bool saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final dac = AppColors.of(ctx);
          return AlertDialog(
          backgroundColor: dac.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.lock_outline, color: _purple, size: 22),
            const SizedBox(width: 10),
            Text('Смена пароля',
                style: TextStyle(color: dac.text, fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(oldCtrl,  'Текущий пароль',    Icons.lock_outline, obscure: true),
            const SizedBox(height: 10),
            _dialogField(newCtrl,  'Новый пароль',       Icons.lock_reset,  obscure: true),
            const SizedBox(height: 10),
            _dialogField(confCtrl, 'Подтвердите пароль', Icons.lock_reset,  obscure: true),
          ]),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: Text('Отмена', style: TextStyle(color: dac.textMuted)),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) {
                        _snack('Заполните все поля', Colors.orange); return;
                      }
                      if (newCtrl.text.length < 8) {
                        _snack('Пароль минимум 8 символов', Colors.orange); return;
                      }
                      if (newCtrl.text != confCtrl.text) {
                        _snack('Пароли не совпадают', Colors.red); return;
                      }
                      set(() => saving = true);
                      try {
                        final token = await SessionManager.getAuthToken() ?? '';
                        final r = await http.post(
                          Uri.parse('${ApiConfig.baseUrl}/change-password'),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $token',
                          },
                          body: jsonEncode({
                            'email': widget.userEmail,
                            'oldPassword': oldCtrl.text,
                            'newPassword': newCtrl.text,
                          }),
                        );
                        if (!mounted) return;
                        if (r.statusCode == 401) {
                          Navigator.pop(ctx);
                          await SessionManager.handleUnauthorized(context);
                          return;
                        }
                        final d = jsonDecode(r.body);
                        if (d['success'] == true) {
                          Navigator.pop(ctx);
                          _snack('Пароль успешно изменён', _green);
                        } else {
                          _snack(d['message'] ?? 'Ошибка', Colors.red);
                        }
                      } catch (_) {
                        _snack('Ошибка соединения', Colors.red);
                      } finally {
                        set(() => saving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Изменить', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
        },
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final dac = AppColors.of(ctx);
        return AlertDialog(
        backgroundColor: dac.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.logout_rounded, color: Colors.red, size: 22),
          const SizedBox(width: 10),
          Text('Выйти из аккаунта?',
              style: TextStyle(color: dac.text, fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          'Вы уверены? Потребуется повторный вход.',
          style: TextStyle(color: dac.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: dac.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              await SessionManager.logout();
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (r) => false,
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Выйти', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
      },
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false}) {
    final ac = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ac.inputBorder),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(color: ac.text, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: _purple, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: ac.textHint, fontSize: 14),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: userData == null
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : RefreshIndicator(
              color: _purple,
              backgroundColor: ac.card,
              onRefresh: _loadAll,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeroHeader()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _buildStatsRow(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildPcSection(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildHistorySection(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSettingsSection(),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildLogoutButton(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 40 + MediaQuery.of(context).padding.bottom + 72,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── hero header ──────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1A3E), Color(0xFF0D0D1E)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            children: [
              // Avatar circle with gradient
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_purple, Color(0xFF9C8ADE)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withValues(alpha: 0.45),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Name
              Text(
                userData!['username'] ?? 'Пользователь',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 5),

              // Email
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.email_outlined,
                      size: 13, color: Colors.white.withValues(alpha: 0.4)),
                  const SizedBox(width: 5),
                  Text(
                    widget.userEmail,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // PC status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (_hasPc ? _green : _orange).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (_hasPc ? _green : _orange).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _hasPc
                          ? Icons.check_circle_outline_rounded
                          : Icons.computer_outlined,
                      color: _hasPc ? _green : _orange,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _hasPc ? 'ПК настроен' : 'ПК не добавлен',
                      style: TextStyle(
                          color: _hasPc ? _green : _orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
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

  // ── stats row ─────────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard(
          icon: Icons.history_rounded,
          label: 'Проверок',
          value: '${checkHistory.length}',
          color: _purple,
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.star_rounded,
          label: 'Избранных',
          value: '$_favoritesCount / 5',
          color: _amber,
        ),
        const SizedBox(width: 10),
        _statCard(
          icon: Icons.speed_rounded,
          label: 'Лучший FPS',
          value: checkHistory.isEmpty ? '—' : '$_bestFps',
          color: _green,
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final ac = AppColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: ac.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ac.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── PC section ────────────────────────────────────────────────────────────────
  Widget _buildPcSection() {
    final pc = userData?['pcSpecs'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.computer_rounded,
          'Мой компьютер',
          trailing: _editPill(
            label: 'Изменить',
            icon: Icons.edit_rounded,
            onTap: _isRefreshing
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AddPcPage(userEmail: widget.userEmail)),
                    );
                    if (result == true && mounted) await fetchUserData();
                  },
          ),
        ),
        const SizedBox(height: 12),
        if (!_hasPc) _noPcCard() else _pcSpecsCard(pc!),
      ],
    );
  }

  Widget _noPcCard() {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddPcPage(userEmail: widget.userEmail)),
        );
        if (result == true && mounted) await fetchUserData();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: ac.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.add_circle_outline_rounded,
                  color: _orange, size: 32),
            ),
            const SizedBox(height: 14),
            Text('Добавьте характеристики ПК',
                style: TextStyle(
                    color: ac.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Укажите CPU, GPU и ОЗУ, чтобы проверять совместимость с играми',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: ac.textMuted,
                  fontSize: 12,
                  height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _orange.withValues(alpha: 0.4)),
              ),
              child: const Text('Добавить ПК',
                  style: TextStyle(
                      color: _orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pcSpecsCard(Map<String, dynamic> pc) {
    final ac = AppColors.of(context);
    final specs = [
      _Spec(Icons.memory_rounded,          'Процессор',  pc['cpu']     ?? '—', const Color(0xFF6C63FF)),
      _Spec(Icons.videogame_asset_rounded, 'Видеокарта', pc['gpu']     ?? '—', const Color(0xFF4CAF50)),
      _Spec(Icons.storage_rounded,         'ОЗУ',        pc['ram']     ?? '—', const Color(0xFFFF9800)),
      _Spec(Icons.save_rounded,            'Хранилище',  pc['storage'] ?? '—', const Color(0xFF00BCD4)),
      _Spec(Icons.laptop_windows_rounded,  'ОС',         pc['os']      ?? '—', const Color(0xFF9C27B0)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.divider),
      ),
      child: Column(
        children: List.generate(specs.length, (i) {
          return Column(
            children: [
              _specRow(specs[i]),
              if (i < specs.length - 1)
                Divider(height: 18, color: ac.divider, thickness: 1),
            ],
          );
        }),
      ),
    );
  }

  Widget _specRow(_Spec s) {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: s.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(s.icon, color: s.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.label,
                  style: TextStyle(
                      color: ac.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(s.value,
                  style: TextStyle(
                      color: ac.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  // ── history section ───────────────────────────────────────────────────────────
  Widget _buildHistorySection() {
    const preview = 5;
    final visible = _showAllHistory
        ? checkHistory
        : checkHistory.take(preview).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.history_rounded, 'История проверок'),
        const SizedBox(height: 12),
        if (checkHistory.isEmpty)
          _emptyHistory()
        else ...[
          ...visible.map((c) => _historyCard(c)),
          if (checkHistory.length > preview) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _showAllHistory = !_showAllHistory),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.of(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.of(context).divider),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _showAllHistory
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _purple,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showAllHistory
                          ? 'Свернуть'
                          : 'Показать все (${checkHistory.length})',
                      style: const TextStyle(
                          color: _purple,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _emptyHistory() {
    final ac = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ac.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.gamepad_outlined, color: ac.textMuted, size: 42),
          const SizedBox(height: 10),
          Text('Проверок ещё не было',
              style: TextStyle(
                  color: ac.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Зайдите на главную и выберите игру',
              style: TextStyle(
                  color: ac.text.withValues(alpha: 0.25), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> c) {
    final color = c['color'] as Color;
    final fps   = c['fps'] as int;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameInfoPage(
            title: c['game'] as String,
            image: '',
            userEmail: widget.userEmail,
          ),
        ),
      ),
      child: Builder(builder: (ctx) {
        final ac = AppColors.of(ctx);
        return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: ac.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(c['icon'] as IconData, color: color, size: 22),
            ),
            const SizedBox(width: 12),

            // Game + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['game'] as String,
                      style: TextStyle(
                          color: ac.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(c['result'] as String,
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.speed_rounded,
                          color: ac.textMuted, size: 12),
                      const SizedBox(width: 3),
                      Text('$fps FPS',
                          style: TextStyle(
                              color: ac.textMuted,
                              fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),

            Icon(Icons.chevron_right_rounded,
                color: ac.text.withValues(alpha: 0.2), size: 20),
          ],
        ),
      );
      }),
    );
  }

  // ── settings section ──────────────────────────────────────────────────────────
  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.tune_rounded, 'Настройки'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.of(context).card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.of(context).divider),
          ),
          child: Column(
            children: [
              // Theme toggle
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeManager.notifier,
                builder: (_, mode, __) {
                  final isDark = mode == ThemeMode.dark;
                  return _settingsTile(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    iconColor: isDark ? _purple : _amber,
                    label: isDark ? 'Тёмная тема' : 'Светлая тема',
                    subtitle: 'Переключить оформление',
                    trailing: Switch(
                      value: isDark,
                      onChanged: (v) => ThemeManager.setDarkMode(v),
                      activeColor: _purple,
                      inactiveThumbColor: _amber,
                      inactiveTrackColor: _amber.withValues(alpha: 0.3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    showDivider: true,
                  );
                },
              ),

              // Edit username
              _settingsTile(
                icon: Icons.badge_rounded,
                iconColor: const Color(0xFF4CAF50),
                label: 'Изменить имя',
                subtitle: userData?['username'] ?? '',
                onTap: _showEditUsernameDialog,
                showDivider: true,
              ),

              // Change password
              _settingsTile(
                icon: Icons.lock_rounded,
                iconColor: const Color(0xFFFF9800),
                label: 'Сменить пароль',
                subtitle: 'Обновить пароль аккаунта',
                onTap: _showChangePasswordDialog,
                showDivider: true,
              ),

              // Edit PC
              _settingsTile(
                icon: Icons.computer_rounded,
                iconColor: const Color(0xFF00BCD4),
                label: 'Характеристики ПК',
                subtitle: _hasPc ? 'Обновить конфигурацию' : 'Добавить ПК',
                onTap: _isRefreshing
                    ? null
                    : () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddPcPage(userEmail: widget.userEmail)),
                        );
                        if (result == true && mounted) await fetchUserData();
                      },
                showDivider: true,
              ),

              // Настройки приложения
              _settingsTile(
                icon: Icons.settings_rounded,
                iconColor: const Color(0xFF6C63FF),
                label: 'Настройки',
                subtitle: 'Тема, кэш, версия приложения',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
                showDivider: true,
              ),

              // О приложении
              _settingsTile(
                icon: Icons.info_outline_rounded,
                iconColor: const Color(0xFFFFB300),
                label: 'О приложении',
                subtitle: 'Как работает расчёт FPS, FAQ',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutPage()),
                ),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool showDivider = true,
  }) {
    final ac = AppColors.of(context);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: TextStyle(
                                color: ac.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(
                                  color: ac.textMuted,
                                  fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(Icons.chevron_right_rounded,
                          color: ac.text.withValues(alpha: 0.22), size: 20),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 70, right: 16),
            child: Divider(
                height: 1,
                color: ac.divider,
                thickness: 1),
          ),
      ],
    );
  }

  // ── logout button ─────────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _showLogoutDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.red.withValues(alpha: 0.28)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 20),
            SizedBox(width: 10),
            Text('Выйти из аккаунта',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ── shared helpers ────────────────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title, {Widget? trailing}) {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, color: _purple, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  color: ac.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _editPill({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _purple.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _purple, size: 13),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: _purple, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── data holder ───────────────────────────────────────────────────────────────
class _Spec {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;
  const _Spec(this.icon, this.label, this.value, this.color);
}
