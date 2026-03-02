import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'upgrade_recommendations_page.dart';
import '../utils/session_manager.dart';
import '../utils/api_config.dart';
import '../utils/cache_manager.dart';
import '../utils/app_colors.dart';

class GameInfoPage extends StatefulWidget {
  final String title;
  final String image;
  final String userEmail;

  const GameInfoPage({
    super.key,
    required this.title,
    required this.image,
    required this.userEmail,
  });

  @override
  State<GameInfoPage> createState() => _GameInfoPageState();
}

class _GameInfoPageState extends State<GameInfoPage>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  
  Map<String, dynamic>? compatibilityData;
  bool isLoading = true;
  bool _fromCache = false;
  bool _hasNetworkError = false;
  String _networkErrorMsg = '';
  bool _noPcSpecs = false;

  late AnimationController _fpsController;
  late Animation<int> _fpsAnimation;

  final Map<String, Map<String, dynamic>> gameThemes = {
    "Counter-Strike 2": {
      "colors": [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      "icon": Icons.whatshot,
    },
    "PUBG: Battlegrounds": {
      "colors": [Color(0xFF4A90E2), Color(0xFF5B9BD5)],
      "icon": Icons.military_tech,
    },
    "Minecraft": {
      "colors": [Color(0xFF4CAF50), Color(0xFF66BB6A)],
      "icon": Icons.view_in_ar,
    },
    "Valorant": {
      "colors": [Color(0xFFE91E63), Color(0xFFF48FB1)],
      "icon": Icons.flash_on,
    },
    "Cyberpunk 2077": {
      "colors": [Color(0xFFFFEB3B), Color(0xFFFFC107)],
      "icon": Icons.theater_comedy,
    },
    "Fortnite": {
      "colors": [Color(0xFF9C27B0), Color(0xFFBA68C8)],
      "icon": Icons.groups,
    },
    "GTA V": {
      "colors": [Color(0xFFFF5722), Color(0xFFFF7043)],
      "icon": Icons.directions_car,
    },
    "The Witcher 3": {
      "colors": [Color(0xFF607D8B), Color(0xFF78909C)],
      "icon": Icons.castle,
    },
    "Apex Legends": {
      "colors": [Color(0xFFF44336), Color(0xFFEF5350)],
      "icon": Icons.sports_esports,
    },
    "Dota 2": {
      "colors": [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
      "icon": Icons.shield,
    },
    "League of Legends": {
      "colors": [Color(0xFF00BCD4), Color(0xFF26C6DA)],
      "icon": Icons.sports_kabaddi,
    },
    "Overwatch 2": {
      "colors": [Color(0xFFFF9800), Color(0xFFFFB74D)],
      "icon": Icons.people,
    },
    "Red Dead Redemption 2": {
      "colors": [Color(0xFF795548), Color(0xFF8D6E63)],
      "icon": Icons.terrain,
    },
    "Elden Ring": {
      "colors": [Color(0xFF9E9E9E), Color(0xFFBDBDBD)],
      "icon": Icons.auto_awesome,
    },
    "Starfield": {
      "colors": [Color(0xFF1A237E), Color(0xFF283593)],
      "icon": Icons.rocket_launch,
    },
  };

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();

    _fpsController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _fpsAnimation = IntTween(begin: 0, end: 0).animate(_fpsController);

    checkCompatibility();
  }

  @override
  void dispose() {
    _animController.dispose();
    _fpsController.dispose();
    super.dispose();
  }

  Future<void> checkCompatibility({bool forceRefresh = false}) async {
    setState(() {
      isLoading = true;
      _hasNetworkError = false;
      _noPcSpecs = false;
    });

    // Try cache first (skip if user explicitly refreshes)
    if (!forceRefresh) {
      final cached = await CacheManager.getCompatibility(
          widget.userEmail, widget.title);
      if (cached != null) {
        if (mounted) {
          setState(() {
            compatibilityData = cached;
            isLoading = false;
            _fromCache = true;
          });
          _startFpsAnimation(cached['compatibility']['estimatedFPS']);
        }
        return;
      }
    }

    try {
      final token = await SessionManager.getAuthToken() ?? '';
      final url = Uri.parse('${ApiConfig.baseUrl}/check-game-compatibility');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': widget.userEmail,
          'gameTitle': widget.title,
        }),
      );

      if (response.statusCode == 401) {
        if (mounted) await SessionManager.handleUnauthorized(context);
        return;
      } else if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // Save to cache
          await CacheManager.saveCompatibility(
              widget.userEmail, widget.title, data);
          if (mounted) {
            setState(() {
              compatibilityData = data;
              isLoading = false;
              _fromCache = false;
            });
            _startFpsAnimation(data['compatibility']['estimatedFPS']);
          }
        } else {
          if (mounted) setState(() => isLoading = false);
          _showSnackBar(data['message'] ?? "Ошибка проверки", Colors.red);
        }
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        final msg = (data['message'] ?? '').toString().toLowerCase();
        if (mounted) {
          setState(() {
            isLoading = false;
            _noPcSpecs = msg.contains('характеристик') ||
                msg.contains('добавьте') ||
                msg.contains('pc') ||
                msg.contains('пк');
          });
          if (!_noPcSpecs) {
            _showSnackBar(data['message'] ?? "Ошибка проверки", Colors.red);
          }
        }
      } else {
        if (mounted) setState(() => isLoading = false);
        _showSnackBar("Ошибка проверки совместимости", Colors.red);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().toLowerCase();
        final isNetwork = msg.contains('socket') ||
            msg.contains('connection') ||
            msg.contains('timeout') ||
            msg.contains('network') ||
            msg.contains('failed host');
        setState(() {
          isLoading = false;
          _hasNetworkError = true;
          _networkErrorMsg = isNetwork
              ? 'Нет подключения к интернету'
              : 'Не удалось получить данные';
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Поделиться результатом ──────────────────────────────────────────────
  void _shareResult() {
    if (compatibilityData == null) return;
    final compat = compatibilityData!['compatibility'];
    final statusText = getStatusText(compat['status'] as String);
    final fps = compat['estimatedFPS'];
    final message = compat['message'] ?? '';

    final text = '🎮 GamePulse — Проверка совместимости\n'
        '━━━━━━━━━━━━━━━━━━\n'
        '🕹 Игра: ${widget.title}\n'
        '⚡ Результат: $statusText — $fps FPS\n'
        '📝 $message\n'
        '━━━━━━━━━━━━━━━━━━\n'
        'Проверено через GamePulse';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Результат скопирован — вставьте в любой мессенджер',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Анимированный счётчик FPS ────────────────────────────────────────────
  void _startFpsAnimation(int targetFps) {
    _fpsAnimation = IntTween(begin: 0, end: targetFps).animate(
      CurvedAnimation(parent: _fpsController, curve: Curves.easeOut),
    );
    _fpsController.forward(from: 0.0);
  }

  // ─── Баннер "Недостаточно" ────────────────────────────────────────────────
  Widget _buildInsufficientBanner() {
    final gameReqs = compatibilityData!['gameRequirements'];
    final userPC = compatibilityData!['userPC'];

    if (gameReqs == null || userPC == null) return const SizedBox.shrink();

    final minReqs = gameReqs['minimum'];
    if (minReqs == null) return const SizedBox.shrink();

    // Определяем узкие места
    final tips = <_UpgradeTip>[];

    final userGpu = (userPC['gpu'] ?? '').toString().toLowerCase();
    final minGpuRaw = minReqs['gpu'];
    final minGpu = (minGpuRaw is List
            ? (minGpuRaw as List).first
            : minGpuRaw?.toString() ?? '')
        .toString();

    if (minGpu.isNotEmpty) {
      tips.add(_UpgradeTip(
        icon: Icons.videogame_asset_rounded,
        label: 'Видеокарта',
        current: userPC['gpu'] ?? 'неизвестно',
        required: minGpu,
        color: Colors.red,
      ));
    }

    final userCpu = (userPC['cpu'] ?? '').toString().toLowerCase();
    final minCpuRaw = minReqs['cpu'];
    final minCpu = (minCpuRaw is List
            ? (minCpuRaw as List).first
            : minCpuRaw?.toString() ?? '')
        .toString();

    if (minCpu.isNotEmpty && !userCpu.contains('i9') && !userCpu.contains('ryzen 9')) {
      tips.add(_UpgradeTip(
        icon: Icons.memory_rounded,
        label: 'Процессор',
        current: userPC['cpu'] ?? 'неизвестно',
        required: minCpu,
        color: const Color(0xFFFFA726),
      ));
    }

    final userRamStr = (userPC['ram'] ?? '').toString();
    final minRamStr = (minReqs['ram'] ?? '').toString();
    final userRam = int.tryParse(
            RegExp(r'\d+').firstMatch(userRamStr)?.group(0) ?? '') ??
        0;
    final minRam = int.tryParse(
            RegExp(r'\d+').firstMatch(minRamStr)?.group(0) ?? '') ??
        0;
    if (minRam > 0 && userRam < minRam) {
      tips.add(_UpgradeTip(
        icon: Icons.storage_rounded,
        label: 'Оперативная память',
        current: userRamStr,
        required: minRamStr,
        color: const Color(0xFFE91E63),
      ));
    }

    if (tips.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_circle_rounded,
                  color: Colors.red, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Что нужно обновить',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((t) => _buildTipRow(t)),
        ],
      ),
    );
  }

  Widget _buildTipRow(_UpgradeTip tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tip.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(tip.icon, color: tip.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.label,
                    style: TextStyle(
                        color: tip.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                    children: [
                      TextSpan(
                          text: 'У вас: ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45))),
                      TextSpan(text: tip.current),
                      TextSpan(
                          text: '  →  Минимум: ',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45))),
                      TextSpan(
                          text: tip.required,
                          style: TextStyle(
                              color: tip.color,
                              fontWeight: FontWeight.w600)),
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

  // ─── Placeholder для загрузки изображения ────────────────────────────────
  Widget _buildImagePlaceholder() {
    final ac = AppColors.of(context);
    return Container(
      color: ac.card,
      child: Center(
        child: Icon(
          Icons.videogame_asset_outlined,
          color: ac.text.withValues(alpha: 0.12),
          size: 40,
        ),
      ),
    );
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'excellent':
        return const Color(0xFF4CAF50);
      case 'good':
        return const Color(0xFF6C63FF);
      case 'playable':
        return const Color(0xFFFFA726);
      case 'insufficient':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'excellent':
        return 'Отлично';
      case 'good':
        return 'Хорошо';
      case 'playable':
        return 'Играбельно';
      case 'insufficient':
        return 'Недостаточно';
      default:
        return 'Неизвестно';
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'excellent':
        return Icons.check_circle;
      case 'good':
        return Icons.thumb_up;
      case 'playable':
        return Icons.warning;
      case 'insufficient':
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameTheme = gameThemes[widget.title] ?? {
      "colors": [Color(0xFF6C63FF), Color(0xFF4CAF50)],
      "icon": Icons.games,
    };

    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gameTheme["colors"],
                ),
              ),
              child: Stack(
                children: [
                  Opacity(
                    opacity: 0.1,
                    child: Center(
                      child: Icon(
                        gameTheme["icon"],
                        size: 150,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            ac.bg,
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),

                  // Кнопка «Поделиться» — появляется только когда есть результат
                  if (compatibilityData != null)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.ios_share_rounded,
                              color: Colors.white),
                          tooltip: 'Поделиться результатом',
                          onPressed: _shareResult,
                        ),
                      ),
                    ),
                  
                  Positioned(
                    bottom: 20,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Проверка совместимости",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF6C63FF),
                      ),
                    )
                  : _hasNetworkError
                      ? Center(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.wifi_off_rounded,
                                      color: Colors.red, size: 48),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Нет подключения',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _networkErrorMsg,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 28),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      checkCompatibility(forceRefresh: true),
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 18),
                                  label: const Text('Повторить'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6C63FF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28, vertical: 12),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                  : (_noPcSpecs || compatibilityData == null)
                      ? _noPcSpecs
                          ? _buildNoPcSpecsScreen()
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      size: 64),
                                  const SizedBox(height: 16),
                                  Text("Не удалось загрузить данные",
                                      style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 16)),
                                ],
                              ),
                            )
                      : RefreshIndicator(
                          color: const Color(0xFF6C63FF),
                          backgroundColor: const Color(0xFF1A1A2E),
                          onRefresh: () => checkCompatibility(forceRefresh: true),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCompactResultCard(),

                                  // ИИ-анализ производительности
                                  if (compatibilityData!['aiAnalysis'] != null) ...[
                                    const SizedBox(height: 16),
                                    _buildAiAnalysisCard(),
                                  ],

                                  // Баннер с конкретными рекомендациями
                                  // прямо на странице при статусе insufficient
                                  if (compatibilityData!['compatibility']['status'] == 'insufficient')
                                    ...[
                                      const SizedBox(height: 16),
                                      _buildInsufficientBanner(),
                                    ],

                                  const SizedBox(height: 16),

                                  _buildPCSpecsCard(),

                                  const SizedBox(height: 16),

                                  _buildGameRequirementsCard(),

                                  const SizedBox(height: 16),

                                  if (compatibilityData!['compatibility']['status'] != 'excellent')
                                    _buildUpgradeButton(),

                                  const SizedBox(height: 16),
                                ],
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

  Widget _buildNoPcSpecsScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.computer_outlined,
                color: Color(0xFF6C63FF),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Сначала настройте ПК',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Чтобы проверить совместимость с игрой, укажите компоненты своего компьютера — процессор, видеокарту и оперативную память.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.settings_outlined, size: 20),
                label: const Text(
                  'Перейти к настройке ПК',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisCard() {
    final ai = compatibilityData!['aiAnalysis'] as Map<String, dynamic>;
    final bottleneck = ai['bottleneck']?.toString() ?? '';
    final quality = ai['quality']?.toString() ?? '';
    final fpsRange = ai['fpsRange']?.toString() ?? '';
    final analysis = ai['analysis']?.toString() ?? '';
    final ac = AppColors.of(context);

    IconData bottleneckIcon;
    Color bottleneckColor;
    switch (bottleneck) {
      case 'GPU':
        bottleneckIcon = Icons.videogame_asset_rounded;
        bottleneckColor = const Color(0xFFE91E63);
        break;
      case 'CPU':
        bottleneckIcon = Icons.memory_rounded;
        bottleneckColor = const Color(0xFFFFA726);
        break;
      case 'RAM':
        bottleneckIcon = Icons.storage_rounded;
        bottleneckColor = const Color(0xFF00BCD4);
        break;
      default:
        bottleneckIcon = Icons.check_circle_outline;
        bottleneckColor = const Color(0xFF4CAF50);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.08),
            ac.card,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Color(0xFF6C63FF), size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'ИИ-анализ',
                style: TextStyle(
                  color: ac.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildAiStatChip(
                  Icons.speed_rounded,
                  'FPS диапазон',
                  fpsRange,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAiStatChip(
                  Icons.tune_rounded,
                  'Качество',
                  quality,
                  const Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAiStatChip(
                  bottleneckIcon,
                  'Узкое место',
                  bottleneck,
                  bottleneckColor,
                ),
              ),
            ],
          ),
          if (analysis.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ac.text.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ac.inputBorder),
              ),
              child: Text(
                analysis,
                style: TextStyle(
                  color: ac.textSecondary,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiStatChip(IconData icon, String label, String value, Color color) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: ac.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : '—',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactResultCard() {
    final compatibility = compatibilityData!['compatibility'];
    final status = compatibility['status'];
    final statusColor = getStatusColor(status);
    final fps = compatibility['estimatedFPS'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_fromCache)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.cached,
                    color: Colors.white.withValues(alpha: 0.45), size: 14),
                const SizedBox(width: 6),
                Text(
                  'Кэшировано · потяните вниз для обновления',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                ),
              ],
            ),
          ),
        Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.15),
            statusColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              getStatusIcon(status),
              color: statusColor,
              size: 40,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getStatusText(status),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  compatibility['message'],
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.speed,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      AnimatedBuilder(
                        animation: _fpsController,
                        builder: (_, __) => Text(
                          '${_fpsAnimation.value} FPS',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ],
    );
  }

  Widget _buildCompatibilityCard() {
    final compatibility = compatibilityData!['compatibility'];
    final status = compatibility['status'];
    final statusColor = getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            getStatusIcon(status),
            color: statusColor,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            getStatusText(status),
            style: TextStyle(
              color: statusColor,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            compatibility['message'],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFPSCard() {
    final estimatedFPS = compatibilityData!['compatibility']['estimatedFPS'];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6C63FF),
            Color(0xFF4CAF50),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ожидаемый FPS",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "$estimatedFPS",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.speed,
              color: Colors.white,
              size: 48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameRequirementsCard() {
    final ac = AppColors.of(context);
    final gameReqs = compatibilityData!['gameRequirements'];

    if (gameReqs == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 10),
              Text(
                "Требования игры",
                style: TextStyle(
                  color: ac.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildCompactRequirementRow(
            "Минимум",
            gameReqs['minimum'],
            const Color(0xFFFFA726),
          ),

          const Divider(height: 16, color: Colors.white10),

          _buildCompactRequirementRow(
            "Рекомендуется",
            gameReqs['recommended'],
            const Color(0xFF4CAF50),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRequirementRow(String label, Map<String, dynamic> reqs, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildSmallChip("CPU", reqs['cpu'] is List ? (reqs['cpu'] as List).first : reqs['cpu'], Icons.memory),
            _buildSmallChip("GPU", reqs['gpu'] is List ? (reqs['gpu'] as List).first : reqs['gpu'], Icons.videogame_asset),
            _buildSmallChip("RAM", reqs['ram'], Icons.storage),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallChip(String label, String value, IconData icon) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ac.text.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ac.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 6),
          Text(
            "$label: ",
            style: TextStyle(
              color: ac.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: ac.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRequirementsSection(String title, Map<String, dynamic> reqs, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSpecRow(Icons.memory, "CPU", _formatList(reqs['cpu'])),
        const SizedBox(height: 8),
        _buildSpecRow(Icons.videogame_asset, "GPU", _formatList(reqs['gpu'])),
        const SizedBox(height: 8),
        _buildSpecRow(Icons.storage, "RAM", reqs['ram'] ?? 'N/A'),
      ],
    );
  }
  
  String _formatList(dynamic value) {
    if (value is List) {
      return value.join(', ');
    }
    return value?.toString() ?? 'N/A';
  }

  Widget _buildPCSpecsCard() {
    final ac = AppColors.of(context);
    final userPC = compatibilityData!['userPC'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ac.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.computer, color: Color(0xFF6C63FF), size: 20),
              const SizedBox(width: 10),
              Text(
                "Ваш ПК",
                style: TextStyle(
                  color: ac.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSpecRow(Icons.memory, "CPU", userPC['cpu'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildSpecRow(Icons.videogame_asset, "GPU", userPC['gpu'] ?? 'N/A'),
          const SizedBox(height: 12),
          _buildSpecRow(Icons.storage, "RAM", userPC['ram'] ?? 'N/A'),
          if ((userPC['storage'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSpecRow(Icons.sd_storage, "Хранилище", userPC['storage']),
          ],
          if ((userPC['os'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSpecRow(Icons.computer, "ОС", userPC['os']),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecRow(IconData icon, String label, String value) {
    final ac = AppColors.of(context);
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6C63FF), size: 18),
        const SizedBox(width: 12),
        Text(
          "$label:",
          style: TextStyle(
            color: ac.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: ac.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UpgradeRecommendationsPage(
                userEmail: widget.userEmail,
                gameTitle: widget.title,
              ),
            ),
          );
        },
        icon: const Icon(Icons.upgrade, size: 20),
        label: const Text(
          "Рекомендации по улучшению",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// Вспомогательная структура для баннера апгрейда
class _UpgradeTip {
  final IconData icon;
  final String label;
  final String current;
  final String required;
  final Color color;

  const _UpgradeTip({
    required this.icon,
    required this.label,
    required this.current,
    required this.required,
    required this.color,
  });
}