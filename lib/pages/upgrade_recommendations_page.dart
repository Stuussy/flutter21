import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'ai_chat_page.dart';
import '../utils/session_manager.dart';
import '../utils/api_config.dart';
import '../utils/app_colors.dart';

class UpgradeRecommendationsPage extends StatefulWidget {
  final String userEmail;
  final String gameTitle;
  final int? currentFps;

  const UpgradeRecommendationsPage({
    super.key,
    required this.userEmail,
    required this.gameTitle,
    this.currentFps,
  });

  @override
  State<UpgradeRecommendationsPage> createState() =>
      _UpgradeRecommendationsPageState();
}

class _UpgradeRecommendationsPageState
    extends State<UpgradeRecommendationsPage>
    with SingleTickerProviderStateMixin {
  // ── animation ─────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── data ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _data;
  bool _loading = true;

  // ── AI section ────────────────────────────────────────────────────────────
  Map<String, dynamic>? _aiData;
  bool _aiLoading = false;
  bool _aiExpanded = false;

  // ── budget ────────────────────────────────────────────────────────────────
  double _budgetKzt = 150000;
  double _usdToKzt  = 480.0;

  static const double _budgetMin = 30000;
  static const double _budgetMax = 500000;

  static const _presets = [
    _Preset('50к',  50000),
    _Preset('100к', 100000),
    _Preset('200к', 200000),
    _Preset('400к', 400000),
  ];

  // ── colours ───────────────────────────────────────────────────────────────
  static const _purple = Color(0xFF6C63FF);
  static const _green  = Color(0xFF4CAF50);
  static const _orange = Color(0xFFFFA726);
  static const _red    = Color(0xFFF44336);
  static const _violet = Color(0xFF7B2FBE);

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _fetchRate();
    _load();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  String get _tier {
    if (_budgetKzt < 100000) return 'low';
    if (_budgetKzt < 250000) return 'medium';
    return 'high';
  }

  int get _budgetUsd => (_budgetKzt / _usdToKzt).round();

  String _fmtKzt(double kzt) => kzt
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ');

  String _usdStr(num usd) => _fmtKzt(usd * _usdToKzt);

  int _prioOrder(String? p) {
    if (p == 'high') return 0;
    if (p == 'medium') return 1;
    return 2;
  }

  Color _prioColor(String? p) {
    if (p == 'high') return _red;
    if (p == 'medium') return _orange;
    return _purple;
  }

  String _prioLabel(String? p) {
    if (p == 'high') return 'Критично';
    if (p == 'medium') return 'Важно';
    return 'Опционально';
  }

  IconData _compIcon(String? c) {
    if (c == null) return Icons.hardware;
    final lc = c.toLowerCase();
    if (lc.contains('проц') || lc.contains('cpu')) return Icons.memory_rounded;
    if (lc.contains('видео') || lc.contains('gpu'))
      return Icons.videogame_asset_rounded;
    if (lc.contains('пам') || lc.contains('ram') || lc.contains('озу'))
      return Icons.storage_rounded;
    if (lc.contains('накоп') || lc.contains('ssd') || lc.contains('hdd'))
      return Icons.save_rounded;
    return Icons.hardware_rounded;
  }

  List<Map<String, dynamic>> get _sorted {
    final recs =
        (_data?['recommendations'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return List.of(recs)
      ..sort((a, b) => _prioOrder(a['priority']) - _prioOrder(b['priority']));
  }

  int get _totalAllKzt {
    final recs = _data?['recommendations'] as List<dynamic>? ?? [];
    return recs.fold(0,
        (sum, r) => sum + ((r['price'] as num) * _usdToKzt).toInt());
  }

  // Sum of highest-priority items that fit within budget (greedy)
  int get _totalFitKzt {
    int remaining = _budgetKzt.toInt();
    int total = 0;
    for (final r in _sorted) {
      final cost = ((r['price'] as num) * _usdToKzt).toInt();
      if (cost <= remaining) {
        total += cost;
        remaining -= cost;
      }
    }
    return total;
  }

  // ── network ───────────────────────────────────────────────────────────────
  Future<void> _fetchRate() async {
    try {
      final res = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['result'] == 'success') {
          final r = (d['rates']['KZT'] as num?)?.toDouble();
          if (r != null && mounted) setState(() => _usdToKzt = r);
        }
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _data = null; });
    try {
      final token = await SessionManager.getAuthToken() ?? '';
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/upgrade-recommendations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': widget.userEmail,
          'gameTitle': widget.gameTitle,
          'budget': _tier,
        }),
      );
      if (!mounted) return;
      if (res.statusCode == 401) {
        await SessionManager.handleUnauthorized(context);
        return;
      }
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['success'] == true) {
          setState(() {
            _data = d;
            _loading = false;
            _aiData = null;
            _aiExpanded = false;
          });
          _animController.forward(from: 0);
        } else {
          setState(() => _loading = false);
          _snack(d['message'] ?? 'Ошибка', _red);
        }
      } else {
        setState(() => _loading = false);
        _snack('Ошибка сервера (${res.statusCode})', _red);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _snack('Нет соединения', _red);
    }
  }

  Future<void> _loadAi() async {
    setState(() { _aiLoading = true; _aiExpanded = true; });
    try {
      final token = await SessionManager.getAuthToken() ?? '';
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/ai-smart-upgrade-recommendations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': widget.userEmail,
          'gameTitle': widget.gameTitle,
          'budget': _budgetUsd,
          'targetFPS': 60,
        }),
      );
      if (!mounted) return;
      if (res.statusCode == 401) {
        await SessionManager.handleUnauthorized(context);
        return;
      }
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['success'] == true) {
          setState(() { _aiData = d; _aiLoading = false; });
        } else {
          setState(() => _aiLoading = false);
          _snack(d['message'] ?? 'Ошибка AI', _red);
        }
      } else {
        setState(() => _aiLoading = false);
        _snack('Ошибка AI анализа', _red);
      }
    } catch (_) {
      if (mounted) setState(() => _aiLoading = false);
      _snack('Нет соединения', _red);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _launch(String url) async {
    try {
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        _snack('Не удалось открыть ссылку', _red);
      }
    } catch (_) {
      _snack('Некорректная ссылка', _red);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final ac  = AppColors.of(context);
    final recs = _sorted;

    return Scaffold(
      backgroundColor: ac.bg,
      body: SafeArea(
        child: Column(
          children: [
            _appBar(ac),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _purple))
                  : _data == null
                      ? _errorWidget(ac)
                      : FadeTransition(
                          opacity: _fadeAnim,
                          child: SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                _budgetCard(ac),
                                const SizedBox(height: 14),
                                if (recs.isNotEmpty) ...[
                                  _budgetTracker(ac),
                                  const SizedBox(height: 18),
                                ],
                                _aiButton(ac),
                                if (_aiExpanded) ...[
                                  const SizedBox(height: 14),
                                  _aiSection(ac),
                                ],
                                const SizedBox(height: 20),
                                if (recs.isEmpty)
                                  _perfectPc(ac)
                                else ...[
                                  _sectionHeader(recs.length, ac),
                                  const SizedBox(height: 12),
                                  ...recs.asMap().entries.map((e) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 14),
                                        child: _recCard(
                                            e.value, e.key + 1, ac),
                                      )),
                                ],
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

  // ── app bar ───────────────────────────────────────────────────────────────
  Widget _appBar(AppColors ac) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_rounded, color: ac.text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Апгрейд ПК',
                    style: TextStyle(
                        color: ac.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                Text(
                  widget.gameTitle,
                  style: const TextStyle(
                      color: _purple, fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!_loading)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: ac.textMuted, size: 22),
              onPressed: _load,
              tooltip: 'Обновить',
            ),
        ],
      ),
    );
  }

  // ── budget card ───────────────────────────────────────────────────────────
  Widget _budgetCard(AppColors ac) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: _purple, size: 18),
              ),
              const SizedBox(width: 10),
              Text('Бюджет',
                  style: TextStyle(
                      color: ac.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_fmtKzt(_budgetKzt)} ₸',
                  style: const TextStyle(
                      color: _purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _purple,
              inactiveTrackColor: _purple.withValues(alpha: 0.12),
              thumbColor: _purple,
              overlayColor: _purple.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              min: _budgetMin,
              max: _budgetMax,
              divisions:
                  ((_budgetMax - _budgetMin) / 10000).round(),
              value: _budgetKzt,
              onChanged: (v) => setState(() => _budgetKzt = v),
              onChangeEnd: (_) => _load(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('30к ₸',
                    style:
                        TextStyle(color: ac.textMuted, fontSize: 10)),
                Text('500к ₸',
                    style:
                        TextStyle(color: ac.textMuted, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick presets
          Row(
            children: _presets.asMap().entries.map((e) {
              final p = e.value;
              final i = e.key;
              final selected = (_budgetKzt - p.kzt).abs() < 5000;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _budgetKzt = p.kzt);
                    _load();
                  },
                  child: Container(
                    margin:
                        EdgeInsets.only(right: i < _presets.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? _purple.withValues(alpha: 0.18)
                          : ac.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _purple : ac.inputBorder,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      p.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? _purple : ac.textMuted,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Tier hint
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _purple.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _purple, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _data?['budgetMessage'] ??
                        (_tier == 'low'
                            ? 'Эконом-апгрейд: лучшее соотношение цена/прирост FPS'
                            : _tier == 'medium'
                                ? 'Средний бюджет: сбалансированный апгрейд'
                                : 'Премиум: максимальная производительность'),
                    style: TextStyle(
                        color: ac.textSecondary,
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── budget tracker ────────────────────────────────────────────────────────
  Widget _budgetTracker(AppColors ac) {
    final allKzt    = _totalAllKzt;
    final fitKzt    = _totalFitKzt;
    final budgetInt = _budgetKzt.toInt();
    final fitsAll   = allKzt <= budgetInt;
    final ratio     = (fitKzt / budgetInt).clamp(0.0, 1.0);
    final accentColor = fitsAll ? _green : _orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                fitsAll
                    ? Icons.check_circle_outline_rounded
                    : Icons.account_balance_wallet_outlined,
                color: accentColor,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  fitsAll
                      ? 'Все апгрейды вписываются в бюджет'
                      : 'Приоритетные апгрейды в бюджете',
                  style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_fmtKzt(fitKzt.toDouble())} / ${_fmtKzt(_budgetKzt)} ₸',
                style: TextStyle(
                    color: ac.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: ac.text.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 6,
            ),
          ),
          if (!fitsAll) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Полная стоимость:',
                    style:
                        TextStyle(color: ac.textMuted, fontSize: 11)),
                Text(
                  '${_fmtKzt(allKzt.toDouble())} ₸  (+${_fmtKzt((allKzt - budgetInt).toDouble())} ₸)',
                  style: TextStyle(
                      color: _orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── AI button ─────────────────────────────────────────────────────────────
  Widget _aiButton(AppColors ac) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _aiLoading ? null : _loadAi,
        icon: _aiLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(
          _aiLoading
              ? 'AI анализирует...'
              : _aiExpanded && _aiData != null
                  ? 'Обновить AI анализ'
                  : 'AI анализ узкого места',
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _violet,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _violet.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  // ── AI section ────────────────────────────────────────────────────────────
  Widget _aiSection(AppColors ac) {
    if (_aiLoading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: ac.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _violet.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(color: _violet),
            const SizedBox(height: 14),
            Text('Анализ производительности системы...',
                style: TextStyle(color: ac.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    if (_aiData == null) return const SizedBox.shrink();

    final analysis = _aiData!['analysis'] as Map<String, dynamic>?;
    final aiRecs =
        (_aiData!['recommendations'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();

    return Container(
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _violet.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [_violet, _purple]),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('AI Deep Analysis',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                Text(
                  '${_fmtKzt(_budgetKzt)} ₸',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bottleneck
                if (analysis != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _red.withValues(alpha: 0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: _red, size: 15),
                            const SizedBox(width: 6),
                            const Text('Узкое место',
                                style: TextStyle(
                                    color: _red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(analysis['bottleneck'] ?? '',
                            style: TextStyle(
                                color: ac.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(analysis['bottleneckReason'] ?? '',
                            style: TextStyle(
                                color: ac.textSecondary,
                                fontSize: 12,
                                height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _impactRow(Icons.memory_rounded, 'CPU',
                      analysis['cpuImpact'] ?? '', ac),
                  const SizedBox(height: 6),
                  _impactRow(Icons.videogame_asset_rounded, 'GPU',
                      analysis['gpuImpact'] ?? '', ac),
                  const SizedBox(height: 6),
                  _impactRow(Icons.storage_rounded, 'RAM',
                      analysis['ramImpact'] ?? '', ac),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ac.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(analysis['overallAssessment'] ?? '',
                        style: TextStyle(
                            color: ac.textSecondary,
                            fontSize: 12,
                            height: 1.4)),
                  ),
                  const SizedBox(height: 14),
                ],

                // AI component recs
                if (aiRecs.isNotEmpty) ...[
                  Text('Рекомендации AI',
                      style: TextStyle(
                          color: ac.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...aiRecs.map((r) => _aiRecItem(r, ac)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _impactRow(
      IconData icon, String label, String text, AppColors ac) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _purple, size: 14),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(
                color: _purple, fontSize: 12, fontWeight: FontWeight.w700)),
        Expanded(
          child: Text(text,
              style: TextStyle(color: ac.textSecondary, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _aiRecItem(Map<String, dynamic> rec, AppColors ac) {
    final pColor = _prioColor(rec['priority'] as String?);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ac.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: pColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(rec['component'] ?? '',
                    style: TextStyle(
                        color: pColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(rec['name'] ?? '',
                    style: TextStyle(
                        color: ac.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('\$${rec['price']}',
                  style: TextStyle(
                      color: pColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          if ((rec['reason'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(rec['reason'] ?? '',
                style: TextStyle(
                    color: ac.textSecondary, fontSize: 11, height: 1.4)),
          ],
          if ((rec['fpsGain'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.speed_rounded,
                    color: _green, size: 13),
                const SizedBox(width: 4),
                Text(rec['fpsGain'] ?? '',
                    style: const TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(int count, AppColors ac) {
    return Row(
      children: [
        Text('Рекомендации',
            style: TextStyle(
                color: ac.text,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _purple.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
              style: const TextStyle(
                  color: _purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
        const Spacer(),
        Text(
          _tier == 'low'
              ? 'Эконом'
              : _tier == 'medium'
                  ? 'Средний'
                  : 'Премиум',
          style: TextStyle(color: ac.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  // ── recommendation card ───────────────────────────────────────────────────
  Widget _recCard(Map<String, dynamic> rec, int index, AppColors ac) {
    final priority   = rec['priority'] as String?;
    final pColor     = _prioColor(priority);
    final priceUsd   = (rec['price'] as num).toDouble();
    final priceKzt   = priceUsd * _usdToKzt;
    final fits       = priceKzt <= _budgetKzt;
    final fpsGain    = rec['fpsGain'] as String? ?? '';
    final hasLink    = (rec['link'] as String? ?? '').isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          // ── header strip ─────────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: pColor.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // Number badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('$index',
                        style: TextStyle(
                            color: pColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(_compIcon(rec['component'] as String?),
                    color: pColor, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(rec['component'] ?? '',
                      style: TextStyle(
                          color: pColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_prioLabel(priority),
                      style: TextStyle(
                          color: pColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          // ── body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Current
                _compareRow(
                  icon: Icons.close_rounded,
                  iconColor: _red,
                  label: 'Сейчас',
                  value: rec['current'] ?? '—',
                  bg: _red.withValues(alpha: 0.06),
                  ac: ac,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_downward_rounded,
                        color: ac.textMuted, size: 15),
                  ],
                ),
                const SizedBox(height: 8),
                // Recommended
                _compareRow(
                  icon: Icons.check_rounded,
                  iconColor: _green,
                  label: 'Заменить на',
                  value: rec['recommended'] ?? '—',
                  bg: _green.withValues(alpha: 0.06),
                  ac: ac,
                ),

                const SizedBox(height: 14),

                // FPS gain badge (if present)
                if (fpsGain.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _green.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.speed_rounded,
                            color: _green, size: 16),
                        const SizedBox(width: 6),
                        Text(fpsGain,
                            style: const TextStyle(
                                color: _green,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Price row + buy button
                Row(
                  children: [
                    // Price + budget indicator
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Цена',
                              style: TextStyle(
                                  color: ac.textMuted, fontSize: 11)),
                          const SizedBox(height: 3),
                          Text(
                            '${_usdStr(rec['price'])} ₸',
                            style: const TextStyle(
                                color: _purple,
                                fontSize: 19,
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                fits
                                    ? Icons.check_circle_rounded
                                    : Icons.remove_circle_rounded,
                                color: fits ? _green : _orange,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fits
                                    ? 'В бюджете'
                                    : 'Превышает бюджет',
                                style: TextStyle(
                                  color: fits ? _green : _orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Buy button
                    if (hasLink)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _launch(rec['link'] as String),
                        icon: const Icon(
                            Icons.shopping_cart_rounded,
                            size: 16),
                        label: const Text('Купить',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 13),
                          elevation: 0,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── AI chat button ────────────────────────────────────────
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiChatPage(
                        userEmail: widget.userEmail,
                        gameTitle: widget.gameTitle,
                        recommendation: rec,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _purple.withValues(alpha: 0.10),
                          _violet.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _purple.withValues(alpha: 0.28)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _purple.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.smart_toy_rounded,
                            color: _purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Спросить ИИ о компоненте',
                                style: TextStyle(
                                  color: _purple,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Задайте вопрос ИИ-ассистенту об этом апгрейде',
                                style: TextStyle(
                                  color: Color(0xFF9B95E8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: _purple.withValues(alpha: 0.55),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color bg,
    required AppColors ac,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(color: ac.textMuted, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: ac.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── perfect PC ────────────────────────────────────────────────────────────
  Widget _perfectPc(AppColors ac) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: _green, size: 48),
          ),
          const SizedBox(height: 16),
          Text('Ваш ПК готов!',
              style: TextStyle(
                  color: ac.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Апгрейд для ${widget.gameTitle} не требуется',
            textAlign: TextAlign.center,
            style: TextStyle(color: ac.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── error widget ──────────────────────────────────────────────────────────
  Widget _errorWidget(AppColors ac) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              color: ac.textMuted, size: 60),
          const SizedBox(height: 14),
          Text('Не удалось загрузить рекомендации',
              style: TextStyle(color: ac.textMuted, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Повторить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── data class ────────────────────────────────────────────────────────────────
class _Preset {
  final String label;
  final double kzt;
  const _Preset(this.label, this.kzt);
}
