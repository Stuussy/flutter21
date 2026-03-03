import 'dart:convert';
import '../utils/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminAddGamePage extends StatefulWidget {
  final String adminToken;
  const AdminAddGamePage({super.key, this.adminToken = ''});

  @override
  State<AdminAddGamePage> createState() => _AdminAddGamePageState();
}

class _AdminAddGamePageState extends State<AdminAddGamePage> {
  static String get _baseUrl => ApiConfig.baseUrl;

  final _titleController    = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _subtitleController = TextEditingController();
  bool _isLoading   = false;
  bool _aiLoading   = false;

  // Tier data
  final _minCpuController  = TextEditingController();
  final _minGpuController  = TextEditingController();
  String _minRam = '8 GB';

  final _recCpuController  = TextEditingController();
  final _recGpuController  = TextEditingController();
  String _recRam = '16 GB';

  final _highCpuController = TextEditingController();
  final _highGpuController = TextEditingController();
  String _highRam = '16 GB';

  final List<String> _minCpus  = [];
  final List<String> _minGpus  = [];
  final List<String> _recCpus  = [];
  final List<String> _recGpus  = [];
  final List<String> _highCpus = [];
  final List<String> _highGpus = [];

  final _ramOptions = ['8 GB', '16 GB', '32 GB', '64 GB'];

  @override
  void dispose() {
    _titleController.dispose();
    _imageUrlController.dispose();
    _subtitleController.dispose();
    _minCpuController.dispose();
    _minGpuController.dispose();
    _recCpuController.dispose();
    _recGpuController.dispose();
    _highCpuController.dispose();
    _highGpuController.dispose();
    super.dispose();
  }

  void _addChip(TextEditingController controller, List<String> list) {
    final text = controller.text.trim();
    if (text.isNotEmpty && !list.contains(text)) {
      setState(() {
        list.add(text);
        controller.clear();
      });
    }
  }

  void _removeChip(List<String> list, int index) {
    setState(() => list.removeAt(index));
  }

  // ── AI auto-fill ────────────────────────────────────────────────────────────
  Future<void> _aiFillRequirements() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar("Сначала введите название игры", Colors.orange);
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/admin/ai-fill-game'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.adminToken}'},
        body: jsonEncode({'title': title}),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        final d = data['data'];
        setState(() {
          // subtitle
          if ((d['subtitle'] as String? ?? '').isNotEmpty) {
            _subtitleController.text = d['subtitle'];
          }
          // minimum
          _minCpus
            ..clear()
            ..addAll((d['minimum']?['cpu'] as List? ?? []).map((e) => e.toString()));
          _minGpus
            ..clear()
            ..addAll((d['minimum']?['gpu'] as List? ?? []).map((e) => e.toString()));
          final minRam = d['minimum']?['ram'] as String? ?? '8 GB';
          _minRam = _ramOptions.contains(minRam) ? minRam : '8 GB';
          // recommended
          _recCpus
            ..clear()
            ..addAll((d['recommended']?['cpu'] as List? ?? []).map((e) => e.toString()));
          _recGpus
            ..clear()
            ..addAll((d['recommended']?['gpu'] as List? ?? []).map((e) => e.toString()));
          final recRam = d['recommended']?['ram'] as String? ?? '16 GB';
          _recRam = _ramOptions.contains(recRam) ? recRam : '16 GB';
          // high
          _highCpus
            ..clear()
            ..addAll((d['high']?['cpu'] as List? ?? []).map((e) => e.toString()));
          _highGpus
            ..clear()
            ..addAll((d['high']?['gpu'] as List? ?? []).map((e) => e.toString()));
          final highRam = d['high']?['ram'] as String? ?? '32 GB';
          _highRam = _ramOptions.contains(highRam) ? highRam : '32 GB';
        });
        _showSnackBar("ИИ заполнил требования для «$title»!", const Color(0xFF4CAF50));
      } else {
        _showSnackBar(data['message'] ?? "Ошибка ИИ", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Ошибка подключения", Colors.red);
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _saveGame() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar("Введите название игры", Colors.orange);
      return;
    }
    if (_minCpus.isEmpty || _minGpus.isEmpty) {
      _showSnackBar("Добавьте минимум 1 CPU и 1 GPU для минимальных требований", Colors.orange);
      return;
    }
    if (_recCpus.isEmpty || _recGpus.isEmpty) {
      _showSnackBar("Добавьте минимум 1 CPU и 1 GPU для рекомендуемых требований", Colors.orange);
      return;
    }
    if (_highCpus.isEmpty || _highGpus.isEmpty) {
      _showSnackBar("Добавьте минимум 1 CPU и 1 GPU для высоких требований", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('$_baseUrl/admin/add-game');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.adminToken}'},
        body: jsonEncode({
          'title':    title,
          'image':    _imageUrlController.text.trim(),
          'subtitle': _subtitleController.text.trim(),
          'minimum':     {'cpu': _minCpus,  'gpu': _minGpus,  'ram': _minRam},
          'recommended': {'cpu': _recCpus,  'gpu': _recGpus,  'ram': _recRam},
          'high':        {'cpu': _highCpus, 'gpu': _highGpus, 'ram': _highRam},
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        _showSnackBar("Игра '$title' добавлена!", const Color(0xFF4CAF50));
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, true);
      } else {
        _showSnackBar(data['message'] ?? "Ошибка", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Ошибка подключения", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title ──────────────────────────────────────────
                    _buildTextField(
                      controller: _titleController,
                      hintText: "Название игры",
                      icon: Icons.games,
                    ),
                    const SizedBox(height: 12),

                    // ── AI fill button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _aiLoading ? null : _aiFillRequirements,
                        icon: _aiLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 20),
                        label: Text(
                          _aiLoading ? "ИИ заполняет..." : "Заполнить требования автоматически (ИИ)",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Image URL ──────────────────────────────────────
                    _buildTextField(
                      controller: _imageUrlController,
                      hintText: "URL картинки (необязательно)",
                      icon: Icons.image,
                    ),
                    const SizedBox(height: 8),

                    // ── Image preview ──────────────────────────────────
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _imageUrlController,
                      builder: (_, val, __) {
                        final url = val.text.trim();
                        if (url.isEmpty) return const SizedBox.shrink();
                        return Container(
                          height: 120,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                                  ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF1A1A2E),
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.white38, size: 40),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // ── Subtitle ───────────────────────────────────────
                    _buildTextField(
                      controller: _subtitleController,
                      hintText: "Жанр / описание (необязательно)",
                      icon: Icons.label_outline,
                    ),
                    const SizedBox(height: 24),

                    // ── Tiers ──────────────────────────────────────────
                    _buildTierSection(
                      "Минимальные требования",
                      Icons.speed,
                      const Color(0xFF4CAF50),
                      _minCpuController,
                      _minGpuController,
                      _minCpus,
                      _minGpus,
                      _minRam,
                      (val) => setState(() => _minRam = val),
                    ),
                    const SizedBox(height: 24),
                    _buildTierSection(
                      "Рекомендуемые требования",
                      Icons.star,
                      const Color(0xFF6C63FF),
                      _recCpuController,
                      _recGpuController,
                      _recCpus,
                      _recGpus,
                      _recRam,
                      (val) => setState(() => _recRam = val),
                    ),
                    const SizedBox(height: 24),
                    _buildTierSection(
                      "Высокие требования",
                      Icons.diamond,
                      const Color(0xFFFFA726),
                      _highCpuController,
                      _highGpuController,
                      _highCpus,
                      _highGpus,
                      _highRam,
                      (val) => setState(() => _highRam = val),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveGame,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save, size: 20),
                        label: Text(
                          _isLoading ? "Сохранение..." : "Сохранить игру",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.add_circle, color: Color(0xFFFFA726), size: 24),
          const SizedBox(width: 12),
          const Text(
            "Добавить игру",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFFFFA726), size: 20),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildTierSection(
    String title,
    IconData icon,
    Color color,
    TextEditingController cpuController,
    TextEditingController gpuController,
    List<String> cpuList,
    List<String> gpuList,
    String ramValue,
    ValueChanged<String> onRamChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          _buildChipInput("CPU", cpuController, cpuList, Icons.memory, color),
          const SizedBox(height: 12),
          _buildChipInput("GPU", gpuController, gpuList, Icons.videogame_asset, color),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.storage, color: color.withValues(alpha: 0.7), size: 18),
              const SizedBox(width: 8),
              Text("RAM:", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: DropdownButton<String>(
                    value: ramValue,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A2E),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: _ramOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) { if (val != null) onRamChanged(val); },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipInput(
    String label,
    TextEditingController controller,
    List<String> chips,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color.withValues(alpha: 0.7), size: 18),
            const SizedBox(width: 8),
            Text("$label:", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Например: Intel i5-12400",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  onSubmitted: (_) => _addChip(controller, chips),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: ElevatedButton(
                onPressed: () => _addChip(controller, chips),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.2),
                  foregroundColor: color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.zero,
                  elevation: 0,
                ),
                child: const Icon(Icons.add, size: 20),
              ),
            ),
          ],
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(
              chips.length,
              (index) => Chip(
                label: Text(chips[index],
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                backgroundColor: color.withValues(alpha: 0.15),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
                deleteIconColor: color,
                onDeleted: () => _removeChip(chips, index),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
