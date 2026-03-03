import 'dart:convert';
import '../utils/api_config.dart';
import '../utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'admin_add_game_page.dart';
import 'admin_add_component_page.dart';
import 'admin_ai_chat_page.dart';
import 'login_page.dart';

// ── colour palette ─────────────────────────────────────────────────────────────
const _bg    = Color(0xFF0D0D1E);
const _card  = Color(0xFF1A1A2E);
const _gold  = Color(0xFFFFA726);
const _purp  = Color(0xFF6C63FF);
const _green = Color(0xFF4CAF50);
const _red   = Color(0xFFF44336);
const _blue  = Color(0xFF2196F3);

class AdminPanelPage extends StatefulWidget {
  final String adminEmail;
  final String adminToken;

  const AdminPanelPage({
    super.key,
    required this.adminEmail,
    this.adminToken = '',
  });

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  static String get _base => ApiConfig.baseUrl;

  // ── state ──────────────────────────────────────────────────────────────────
  int _tab = 0; // 0=Games 1=Components 2=Users 3=Stats
  bool _loading = true;

  // data
  List<dynamic> _games      = [];
  Map<String, dynamic> _comps = {};
  List<dynamic> _users      = [];
  Map<String, dynamic> _stats = {};

  // search
  String _searchGames = '';
  String _searchComps = '';
  String _searchUsers = '';

  // bulk select
  bool _bulkMode  = false;
  final Set<String> _selGames = {};
  final Set<String> _selComps = {}; // "type::name"

  // ── helpers ────────────────────────────────────────────────────────────────
  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.adminToken}',
  };

  int get _totalComps {
    int c = 0;
    _comps.forEach((_, v) { if (v is List) c += v.length; });
    return c;
  }

  // ── lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadGamesComps(), _loadUsers(), _loadStats()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadGamesComps() async {
    try {
      final gRes = await http.get(Uri.parse('$_base/admin/games'),    headers: _authHeaders);
      final cRes = await http.get(Uri.parse('$_base/admin/components'), headers: _authHeaders);
      if (gRes.statusCode == 200) {
        final d = jsonDecode(gRes.body);
        if (d['success'] == true && mounted) setState(() => _games = d['games'] ?? []);
      }
      if (cRes.statusCode == 200) {
        final d = jsonDecode(cRes.body);
        if (d['success'] == true && mounted) setState(() => _comps = d['components'] ?? {});
      }
    } catch (_) {}
  }

  Future<void> _loadUsers() async {
    try {
      final res = await http.get(Uri.parse('$_base/admin/users'), headers: _authHeaders);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['success'] == true && mounted) setState(() => _users = d['users'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final res = await http.get(Uri.parse('$_base/admin/stats'), headers: _authHeaders);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['success'] == true && mounted) setState(() => _stats = d['stats'] ?? {});
      }
    } catch (_) {}
  }

  // ── snack ──────────────────────────────────────────────────────────────────
  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── confirm dialog ─────────────────────────────────────────────────────────
  Future<bool> _confirm(String title, String msg, {Color btnColor = _red}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            content: Text(msg,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Отмена",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Подтвердить"),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── delete game ────────────────────────────────────────────────────────────
  Future<void> _deleteGame(String title) async {
    if (!await _confirm("Удалить игру", "Удалить «$title»?")) return;
    try {
      final r = await http.delete(Uri.parse('$_base/admin/delete-game'),
          headers: _authHeaders, body: jsonEncode({'title': title}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) {
        _snack("Игра удалена", _green);
        _loadGamesComps();
      }
    } catch (_) { _snack("Ошибка удаления", _red); }
  }

  // ── delete component ───────────────────────────────────────────────────────
  Future<void> _deleteComp(String type, String name) async {
    if (!await _confirm("Удалить компонент", "Удалить «$name»?")) return;
    try {
      final r = await http.delete(Uri.parse('$_base/admin/delete-component'),
          headers: _authHeaders, body: jsonEncode({'type': type, 'name': name}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) {
        _snack("Компонент удалён", _green);
        _loadGamesComps();
      }
    } catch (_) { _snack("Ошибка удаления", _red); }
  }

  // ── delete user ────────────────────────────────────────────────────────────
  Future<void> _deleteUser(String email) async {
    if (!await _confirm("Удалить пользователя", "Удалить аккаунт «$email»?")) return;
    try {
      final r = await http.delete(Uri.parse('$_base/admin/delete-user'),
          headers: _authHeaders, body: jsonEncode({'email': email}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) {
        _snack("Пользователь удалён", _green);
        _loadUsers();
        _loadStats();
      }
    } catch (_) { _snack("Ошибка удаления", _red); }
  }

  // ── block/unblock user ─────────────────────────────────────────────────────
  Future<void> _toggleBlock(String email, bool currentlyBlocked) async {
    final block = !currentlyBlocked;
    try {
      final r = await http.post(Uri.parse('$_base/admin/block-user'),
          headers: _authHeaders,
          body: jsonEncode({'email': email, 'block': block}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) {
        _snack(block ? "$email заблокирован" : "$email разблокирован",
            block ? _red : _green);
        _loadUsers();
        _loadStats();
      }
    } catch (_) { _snack("Ошибка", _red); }
  }

  // ── bulk delete games ──────────────────────────────────────────────────────
  Future<void> _bulkDeleteGames() async {
    if (_selGames.isEmpty) return;
    if (!await _confirm("Удалить ${_selGames.length} игр",
        "Это действие необратимо.")) return;
    try {
      final r = await http.delete(Uri.parse('$_base/admin/bulk-delete-games'),
          headers: _authHeaders,
          body: jsonEncode({'titles': _selGames.toList()}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) {
        _snack(d['message'], _green);
        _selGames.clear();
        _bulkMode = false;
        _loadAll();
      }
    } catch (_) { _snack("Ошибка", _red); }
  }

  // ── bulk delete components ─────────────────────────────────────────────────
  Future<void> _bulkDeleteComps() async {
    if (_selComps.isEmpty) return;
    if (!await _confirm("Удалить ${_selComps.length} компонентов",
        "Это действие необратимо.")) return;
    try {
      final comps = _selComps
          .map((k) { final p = k.split('::'); return {'type': p[0], 'name': p[1]}; })
          .toList();
      final r = await http.delete(Uri.parse('$_base/admin/bulk-delete-components'),
          headers: _authHeaders,
          body: jsonEncode({'components': comps}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) {
        _snack(d['message'], _green);
        _selComps.clear();
        _bulkMode = false;
        _loadAll();
      }
    } catch (_) { _snack("Ошибка", _red); }
  }

  // ── ai fill game (used in edit dialog) ────────────────────────────────────
  Future<Map<String, dynamic>?> _aiFillGame(String title) async {
    try {
      final r = await http.post(Uri.parse('$_base/admin/ai-fill-game'),
          headers: _authHeaders, body: jsonEncode({'title': title}));
      final d = jsonDecode(r.body);
      if (d['success'] == true) return d['data'] as Map<String, dynamic>;
      _snack(d['message'] ?? "Ошибка ИИ", _red);
    } catch (_) {
      _snack("Ошибка соединения", _red);
    }
    return null;
  }

  // ── edit game dialog ───────────────────────────────────────────────────────
  void _showEditGameDialog(Map<String, dynamic> game) {
    final titleCtrl    = TextEditingController(text: game['title'] ?? '');
    final imageCtrl    = TextEditingController(text: game['image'] ?? '');
    final subtitleCtrl = TextEditingController(text: game['subtitle'] ?? '');
    final minCpuCtrl   = TextEditingController(text: (game['minimum']?['cpu'] as List?)?.join(', ') ?? '');
    final minGpuCtrl   = TextEditingController(text: (game['minimum']?['gpu'] as List?)?.join(', ') ?? '');
    final minRamCtrl   = TextEditingController(text: game['minimum']?['ram'] ?? '');
    final recCpuCtrl   = TextEditingController(text: (game['recommended']?['cpu'] as List?)?.join(', ') ?? '');
    final recGpuCtrl   = TextEditingController(text: (game['recommended']?['gpu'] as List?)?.join(', ') ?? '');
    final recRamCtrl   = TextEditingController(text: game['recommended']?['ram'] ?? '');
    final highCpuCtrl  = TextEditingController(text: (game['high']?['cpu'] as List?)?.join(', ') ?? '');
    final highGpuCtrl  = TextEditingController(text: (game['high']?['gpu'] as List?)?.join(', ') ?? '');
    final highRamCtrl  = TextEditingController(text: game['high']?['ram'] ?? '');

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          bool aiLoading = false;

          return AlertDialog(
            backgroundColor: _card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Редактировать игру",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dialogField("Название", titleCtrl),
                    _dialogField("URL картинки (необязательно)", imageCtrl),
                    _dialogField("Жанр / описание (необязательно)", subtitleCtrl),
                    const SizedBox(height: 8),
                    // ── AI fill button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: aiLoading ? null : () async {
                          final name = titleCtrl.text.trim();
                          if (name.isEmpty) {
                            _snack("Введите название игры", Colors.orange);
                            return;
                          }
                          setS(() => aiLoading = true);
                          final data = await _aiFillGame(name);
                          setS(() => aiLoading = false);
                          if (data == null) return;
                          List<String> joinList(dynamic v) =>
                              (v as List? ?? []).map((e) => e.toString()).toList();
                          setS(() {
                            if ((data['subtitle'] as String? ?? '').isNotEmpty) {
                              subtitleCtrl.text = data['subtitle'];
                            }
                            minCpuCtrl.text  = joinList(data['minimum']?['cpu']).join(', ');
                            minGpuCtrl.text  = joinList(data['minimum']?['gpu']).join(', ');
                            minRamCtrl.text  = data['minimum']?['ram'] ?? '8 GB';
                            recCpuCtrl.text  = joinList(data['recommended']?['cpu']).join(', ');
                            recGpuCtrl.text  = joinList(data['recommended']?['gpu']).join(', ');
                            recRamCtrl.text  = data['recommended']?['ram'] ?? '16 GB';
                            highCpuCtrl.text = joinList(data['high']?['cpu']).join(', ');
                            highGpuCtrl.text = joinList(data['high']?['gpu']).join(', ');
                            highRamCtrl.text = data['high']?['ram'] ?? '32 GB';
                          });
                          _snack("ИИ заполнил требования!", _green);
                        },
                        icon: aiLoading
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(aiLoading ? "Загрузка..." : "Заполнить автоматически (ИИ)",
                            style: const TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purp,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _tierHeader("Минимальные", _green),
                    _dialogField("CPU (через запятую)", minCpuCtrl),
                    _dialogField("GPU (через запятую)", minGpuCtrl),
                    _dialogField("RAM", minRamCtrl),
                    const SizedBox(height: 6),
                    _tierHeader("Рекомендуемые", _purp),
                    _dialogField("CPU (через запятую)", recCpuCtrl),
                    _dialogField("GPU (через запятую)", recGpuCtrl),
                    _dialogField("RAM", recRamCtrl),
                    const SizedBox(height: 6),
                    _tierHeader("Высокие", _gold),
                    _dialogField("CPU (через запятую)", highCpuCtrl),
                    _dialogField("GPU (через запятую)", highGpuCtrl),
                    _dialogField("RAM", highRamCtrl),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text("Отмена", style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  List<String> splitCsv(TextEditingController c) =>
                      c.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                  try {
                    final r = await http.put(Uri.parse('$_base/admin/edit-game'),
                        headers: _authHeaders,
                        body: jsonEncode({
                          'oldTitle':    game['title'],
                          'title':       titleCtrl.text.trim(),
                          'image':       imageCtrl.text.trim(),
                          'subtitle':    subtitleCtrl.text.trim(),
                          'minimum':     {'cpu': splitCsv(minCpuCtrl),  'gpu': splitCsv(minGpuCtrl),  'ram': minRamCtrl.text.trim()},
                          'recommended': {'cpu': splitCsv(recCpuCtrl),  'gpu': splitCsv(recGpuCtrl),  'ram': recRamCtrl.text.trim()},
                          'high':        {'cpu': splitCsv(highCpuCtrl), 'gpu': splitCsv(highGpuCtrl), 'ram': highRamCtrl.text.trim()},
                        }));
                    final d = jsonDecode(r.body);
                    _snack(d['success'] == true ? "Игра обновлена" : (d['message'] ?? "Ошибка"),
                        d['success'] == true ? _green : _red);
                    if (d['success'] == true) _loadGamesComps();
                  } catch (_) { _snack("Ошибка соединения", _red); }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purp,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Сохранить"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── edit component dialog ──────────────────────────────────────────────────
  void _showEditCompDialog(String type, Map<String, dynamic> comp) {
    final nameCtrl  = TextEditingController(text: comp['name'] ?? '');
    final priceCtrl = TextEditingController(text: '${comp['price'] ?? ''}');
    final linkCtrl  = TextEditingController(text: comp['link'] ?? '');
    final perfCtrl  = TextEditingController(text: '${comp['performance'] ?? 100}');
    String budget   = comp['budget'] ?? 'medium';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Редактировать компонент",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField("Название", nameCtrl),
                _dialogField("Цена (\$)", priceCtrl, type: TextInputType.number),
                _dialogField("Ссылка (опционально)", linkCtrl),
                _dialogField("Производительность", perfCtrl, type: TextInputType.number),
                const SizedBox(height: 10),
                Row(
                  children: ['low', 'medium', 'high'].map((b) {
                    final colors = {'low': _green, 'medium': _purp, 'high': _gold};
                    final labels = {'low': 'Эконом', 'medium': 'Средний', 'high': 'Премиум'};
                    final c = colors[b]!;
                    final sel = budget == b;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setS(() => budget = b),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? c.withValues(alpha: 0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: sel ? c : Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Text(labels[b]!, textAlign: TextAlign.center,
                              style: TextStyle(color: sel ? c : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Отмена", style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final r = await http.put(Uri.parse('$_base/admin/edit-component'),
                      headers: _authHeaders,
                      body: jsonEncode({
                        'type': type,
                        'oldName': comp['name'],
                        'name': nameCtrl.text.trim(),
                        'price': double.tryParse(priceCtrl.text) ?? comp['price'],
                        'link': linkCtrl.text.trim(),
                        'performance': int.tryParse(perfCtrl.text) ?? 100,
                        'budget': budget,
                      }));
                  final d = jsonDecode(r.body);
                  _snack(d['success'] == true ? "Компонент обновлён" : (d['message'] ?? "Ошибка"),
                      d['success'] == true ? _green : _red);
                  if (d['success'] == true) _loadGamesComps();
                } catch (_) { _snack("Ошибка соединения", _red); }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _purp,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Сохранить"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(String hint, TextEditingController ctrl, {TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _purp),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _tierHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── logout ─────────────────────────────────────────────────────────────────
  void _logout() async {
    await SessionManager.clearAdminToken();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: _buildFab(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _gold))
                  : RefreshIndicator(
                      onRefresh: _loadAll,
                      color: _gold,
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          _buildGamesTab(),
                          _buildCompsTab(),
                          _buildUsersTab(),
                          _buildStatsTab(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFab() {
    if (_bulkMode) {
      final count = _tab == 0 ? _selGames.length : _selComps.length;
      return FloatingActionButton.extended(
        onPressed: _tab == 0 ? _bulkDeleteGames : _bulkDeleteComps,
        backgroundColor: _red,
        icon: const Icon(Icons.delete_sweep, color: Colors.white),
        label: Text("Удалить ($count)",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AdminAiChatPage(adminEmail: widget.adminEmail, adminToken: widget.adminToken))),
      backgroundColor: _purp,
      icon: const Icon(Icons.smart_toy, color: Colors.white),
      label: const Text("ИИ помощник",
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  // ── top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _card,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings, color: _gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Панель администратора",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text("${_games.length} игр  |  $_totalComps комп.  |  ${_users.length} польз.",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              ],
            ),
          ),
          if (_bulkMode)
            IconButton(
              icon: const Icon(Icons.close, color: _gold),
              onPressed: () => setState(() { _bulkMode = false; _selGames.clear(); _selComps.clear(); }),
              tooltip: "Выйти из выбора",
            )
          else
            IconButton(
              icon: const Icon(Icons.logout, color: _red, size: 22),
              onPressed: _logout,
              tooltip: "Выйти",
            ),
        ],
      ),
    );
  }

  // ── bottom nav ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final tabs = [
      (Icons.games_rounded, "Игры"),
      (Icons.hardware_rounded, "Компоненты"),
      (Icons.people_rounded, "Пользователи"),
      (Icons.bar_chart_rounded, "Статистика"),
    ];
    return Container(
      color: _card,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final idx = e.key;
            final (icon, label) = e.value;
            final sel = _tab == idx;
            return Expanded(
              child: InkWell(
                onTap: () => setState(() { _tab = idx; _bulkMode = false; _selGames.clear(); _selComps.clear(); }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? _gold.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: sel ? _gold : Colors.white.withValues(alpha: 0.35), size: 22),
                      const SizedBox(height: 3),
                      Text(label,
                          style: TextStyle(
                            color: sel ? _gold : Colors.white.withValues(alpha: 0.35),
                            fontSize: 10,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                          )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── search bar ─────────────────────────────────────────────────────────────
  Widget _searchBar(String hint, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _purp)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GAMES TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGamesTab() {
    final filtered = _games.where((g) {
      final t = (g['title'] ?? '').toString().toLowerCase();
      return t.contains(_searchGames.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.games_rounded, color: _gold, size: 20),
              const SizedBox(width: 8),
              Text("Игры (${filtered.length})",
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (!_bulkMode)
                Row(children: [
                  _smallBtn(Icons.checklist_rounded, "Выбрать", _purp, () => setState(() => _bulkMode = true)),
                  const SizedBox(width: 8),
                  _smallBtn(Icons.add_rounded, "Добавить", _green, () async {
                    final ok = await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AdminAddGamePage(adminToken: widget.adminToken)));
                    if (ok == true) _loadGamesComps();
                  }),
                ]),
            ],
          ),
        ),
        _searchBar("Поиск игр...", (v) => setState(() => _searchGames = v)),
        // Bulk action bar
        if (_bulkMode && _selGames.isNotEmpty)
          _bulkBar("Выбрано: ${_selGames.length}", _bulkDeleteGames),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState(Icons.games_rounded, "Нет игр")
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _gameCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _gameCard(Map<String, dynamic> game) {
    final title    = game['title'] ?? '';
    final image    = (game['image'] as String? ?? '').trim();
    final subtitle = (game['subtitle'] as String? ?? '').trim();
    final sel      = _selGames.contains(title);

    return GestureDetector(
      onLongPress: () => setState(() { _bulkMode = true; _selGames.add(title); }),
      onTap: _bulkMode ? () => setState(() { sel ? _selGames.remove(title) : _selGames.add(title); }) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: sel ? _purp.withValues(alpha: 0.12) : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? _purp : Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── image thumbnail ────────────────────────────────────────
            if (image.isNotEmpty)
              SizedBox(
                height: 100,
                width: double.infinity,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _bg,
                    child: const Center(child: Icon(Icons.broken_image, color: Colors.white24, size: 32)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_bulkMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                              color: sel ? _purp : Colors.white.withValues(alpha: 0.3), size: 20),
                        ),
                      if (image.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(7),
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: _purp.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.games_rounded, color: _purp, size: 18),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            if (subtitle.isNotEmpty)
                              Text(subtitle,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                          ],
                        ),
                      ),
                      if (!_bulkMode) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, color: _gold, size: 18),
                          onPressed: () => _showEditGameDialog(game),
                          tooltip: "Редактировать",
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 18),
                          onPressed: () => _deleteGame(title),
                          tooltip: "Удалить",
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  _tierRow("Мин", game['minimum'], _green),
                  const SizedBox(height: 4),
                  _tierRow("Рек", game['recommended'], _purp),
                  const SizedBox(height: 4),
                  _tierRow("Макс", game['high'], _gold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tierRow(String label, dynamic tier, Color color) {
    if (tier == null) return const SizedBox.shrink();
    final cpu = (tier['cpu'] as List?)?.join(', ') ?? '-';
    final gpu = (tier['gpu'] as List?)?.join(', ') ?? '-';
    final ram = tier['ram'] ?? '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(4)),
            child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text("CPU: $cpu | GPU: $gpu | RAM: $ram",
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENTS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCompsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.hardware_rounded, color: _gold, size: 20),
              const SizedBox(width: 8),
              Text("Компоненты ($_totalComps)",
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (!_bulkMode)
                Row(children: [
                  _smallBtn(Icons.checklist_rounded, "Выбрать", _purp, () => setState(() => _bulkMode = true)),
                  const SizedBox(width: 8),
                  _smallBtn(Icons.add_rounded, "Добавить", _green, () async {
                    final ok = await Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AdminAddComponentPage(adminToken: widget.adminToken)));
                    if (ok == true) _loadGamesComps();
                  }),
                ]),
            ],
          ),
        ),
        _searchBar("Поиск компонентов...", (v) => setState(() => _searchComps = v)),
        if (_bulkMode && _selComps.isNotEmpty)
          _bulkBar("Выбрано: ${_selComps.length}", _bulkDeleteComps),
        Expanded(
          child: _comps.isEmpty
              ? _emptyState(Icons.hardware_rounded, "Нет компонентов")
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  children: [
                    if (_comps['cpu'] != null) _compSection("Процессоры (CPU)", Icons.memory_rounded, 'cpu', _comps['cpu']),
                    if (_comps['gpu'] != null) _compSection("Видеокарты (GPU)", Icons.videogame_asset_rounded, 'gpu', _comps['gpu']),
                    if (_comps['ram'] != null) _compSection("Оперативная память", Icons.storage_rounded, 'ram', _comps['ram']),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _compSection(String title, IconData icon, String type, dynamic items) {
    if (items is! List) return const SizedBox.shrink();
    final filtered = items.where((c) {
      final n = (c['name'] ?? '').toString().toLowerCase();
      return n.contains(_searchComps.toLowerCase());
    }).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Icon(icon, color: _purp, size: 16),
            const SizedBox(width: 6),
            Text("$title (${filtered.length})",
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
        ...filtered.map((c) => _compCard(type, c as Map<String, dynamic>)),
      ],
    );
  }

  Widget _compCard(String type, Map<String, dynamic> comp) {
    final name  = comp['name'] ?? '';
    final key   = '$type::$name';
    final sel   = _selComps.contains(key);
    final budget = comp['budget'] ?? 'medium';
    final bColors = {'low': _green, 'medium': _purp, 'high': _gold};
    final bLabels = {'low': 'Эконом', 'medium': 'Средний', 'high': 'Премиум'};
    final bColor = bColors[budget] ?? _purp;

    return GestureDetector(
      onLongPress: () => setState(() { _bulkMode = true; _selComps.add(key); }),
      onTap: _bulkMode ? () => setState(() { sel ? _selComps.remove(key) : _selComps.add(key); }) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? _purp.withValues(alpha: 0.12) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? _purp : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            if (_bulkMode)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: sel ? _purp : Colors.white.withValues(alpha: 0.3), size: 18),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: bColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(5)),
                      child: Text(bLabels[budget] ?? 'Средний',
                          style: TextStyle(color: bColor, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text("\$${comp['price']}", style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
                    const SizedBox(width: 8),
                    Icon(Icons.speed_rounded, color: Colors.white.withValues(alpha: 0.3), size: 13),
                    const SizedBox(width: 3),
                    Text("${comp['performance']}", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                  ]),
                ],
              ),
            ),
            if (!_bulkMode) ...[
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: _gold, size: 17),
                onPressed: () => _showEditCompDialog(type, comp),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 17),
                onPressed: () => _deleteComp(type, name),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // USERS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildUsersTab() {
    final filtered = _users.where((u) {
      final e = (u['email'] ?? '').toString().toLowerCase();
      final n = (u['username'] ?? '').toString().toLowerCase();
      final q = _searchUsers.toLowerCase();
      return e.contains(q) || n.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            const Icon(Icons.people_rounded, color: _gold, size: 20),
            const SizedBox(width: 8),
            Text("Пользователи (${filtered.length})",
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _gold, size: 20),
              onPressed: () { _loadUsers(); _loadStats(); },
            ),
          ]),
        ),
        _searchBar("Поиск по email или имени...", (v) => setState(() => _searchUsers = v)),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState(Icons.people_rounded, "Нет пользователей")
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _userCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _userCard(dynamic user) {
    final email    = user['email'] ?? '';
    final username = user['username'] ?? '—';
    final blocked  = user['isBlocked'] == true;
    final pc       = user['pcSpecs'];
    final hasPc    = pc != null && ((pc['cpu'] ?? '').isNotEmpty || (pc['gpu'] ?? '').isNotEmpty);
    final checks   = (user['checkHistory'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: blocked ? _red.withValues(alpha: 0.06) : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: blocked ? _red.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: (blocked ? _red : _blue).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  (username.isNotEmpty ? username[0] : email.isNotEmpty ? email[0] : '?').toUpperCase(),
                  style: TextStyle(color: blocked ? _red : _blue, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(username,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (blocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: _red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: const Text("Заблокирован",
                          style: TextStyle(color: _red, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          // PC info
          if (hasPc) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _purp.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _purp.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.computer_rounded, color: _purp, size: 13),
                    const SizedBox(width: 5),
                    Text("Конфигурация ПК",
                        style: TextStyle(color: _purp.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  if ((pc['cpu'] ?? '').isNotEmpty)
                    _pcRow("CPU", pc['cpu']),
                  if ((pc['gpu'] ?? '').isNotEmpty)
                    _pcRow("GPU", pc['gpu']),
                  if ((pc['ram'] ?? '').isNotEmpty)
                    _pcRow("RAM", pc['ram']),
                  if ((pc['storage'] ?? '').isNotEmpty)
                    _pcRow("SSD", pc['storage']),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Stats row + action buttons
          Row(children: [
            Icon(Icons.history_rounded, color: Colors.white.withValues(alpha: 0.35), size: 14),
            const SizedBox(width: 4),
            Text("$checks проверок", style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
            const Spacer(),
            SizedBox(
              height: 34,
              child: OutlinedButton.icon(
                onPressed: () => _toggleBlock(email, blocked),
                icon: Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    size: 14, color: blocked ? _green : _red),
                label: Text(blocked ? "Разблокировать" : "Заблокировать",
                    style: TextStyle(fontSize: 11, color: blocked ? _green : _red)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: blocked ? _green.withValues(alpha: 0.5) : _red.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 36, height: 36,
              child: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: _red, size: 18),
                onPressed: () => _deleteUser(email),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _pcRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATS TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildStatsTab() {
    final userCount    = _stats['userCount'] ?? 0;
    final blockedCount = _stats['blockedCount'] ?? 0;
    final gameCount    = _stats['gameCount'] ?? 0;
    final compCount    = _stats['componentCount'] ?? 0;
    final totalChecks  = _stats['totalChecks'] ?? 0;
    final popular      = (_stats['popularGames'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Summary cards
        Row(children: [
          Expanded(child: _statCard("Пользователей", "$userCount", Icons.people_rounded, _blue)),
          const SizedBox(width: 10),
          Expanded(child: _statCard("Заблокировано", "$blockedCount", Icons.block_rounded, _red)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statCard("Игр", "$gameCount", Icons.games_rounded, _purp)),
          const SizedBox(width: 10),
          Expanded(child: _statCard("Компонентов", "$compCount", Icons.hardware_rounded, _gold)),
        ]),
        const SizedBox(height: 10),
        _statCard("Всего проверок совместимости", "$totalChecks", Icons.checklist_rounded, _green,
            wide: true),
        const SizedBox(height: 20),
        // Popular games
        if (popular.isNotEmpty) ...[
          const Text("Топ игр по проверкам",
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...popular.asMap().entries.map((e) {
            final idx  = e.key;
            final item = e.value;
            final max  = (popular.first['count'] as num).toDouble();
            final cnt  = (item['count'] as num).toDouble();
            final ratio = max > 0 ? cnt / max : 0.0;
            final colors = [_gold, _purp, _blue, _green, Colors.teal];
            final c = colors[idx % colors.length];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(7)),
                      child: Center(child: Text("${idx + 1}",
                          style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(item['game'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
                    Text("${item['count']} проверок",
                        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(c),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () { _loadStats(); _loadUsers(); },
            icon: const Icon(Icons.refresh_rounded, color: _gold, size: 18),
            label: const Text("Обновить статистику",
                style: TextStyle(color: _gold, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _gold.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {bool wide = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(color: color, fontSize: wide ? 22 : 24, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── shared helpers ─────────────────────────────────────────────────────────
  Widget _emptyState(IconData icon, String msg) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.15), size: 64),
        const SizedBox(height: 16),
        Text(msg, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
      ]),
    );
  }

  Widget _bulkBar(String label, VoidCallback onDelete) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _red.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.delete_sweep_rounded, color: _red, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: 13)),
        const Spacer(),
        TextButton(
          onPressed: onDelete,
          child: const Text("Удалить", style: TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _smallBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}
