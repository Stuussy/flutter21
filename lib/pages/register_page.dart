import 'package:flutter/material.dart';
import '../utils/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'main_page.dart';
import '../utils/session_manager.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController confirmPassCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // OTP state
  bool _codeSent = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  String passwordStrength = "";
  Color passwordStrengthColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
    passCtrl.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    codeCtrl.dispose();
    _cooldownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 0) {
          _resendCooldown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _checkPasswordStrength() {
    final password = passCtrl.text;
    if (password.isEmpty) {
      setState(() {
        passwordStrength = "";
        passwordStrengthColor = Colors.grey;
      });
      return;
    }
    if (password.length < 8) {
      setState(() {
        passwordStrength = "Слабый (минимум 8 символов)";
        passwordStrengthColor = Colors.red;
      });
      return;
    }
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    setState(() {
      if (strength <= 2) {
        passwordStrength = "Слабый";
        passwordStrengthColor = Colors.red;
      } else if (strength <= 4) {
        passwordStrength = "Средний";
        passwordStrengthColor = Colors.orange;
      } else {
        passwordStrength = "Сильный ✓";
        passwordStrengthColor = const Color(0xFF4CAF50);
      }
    });
  }

  bool _isValidEmail(String email) => RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  ).hasMatch(email);

  Future<void> _sendCode() async {
    final username = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (username.isEmpty || username.length < 3) {
      _showSnackBar("Введите имя (минимум 3 символа)", Colors.orange);
      return;
    }
    if (email.isEmpty || !_isValidEmail(email)) {
      _showSnackBar("Введите корректный email", Colors.orange);
      return;
    }
    if (password.length < 8) {
      _showSnackBar("Пароль должен содержать минимум 8 символов", Colors.red);
      return;
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      _showSnackBar(
        "Пароль должен содержать хотя бы одну заглавную букву",
        Colors.red,
      );
      return;
    }
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      _showSnackBar(
        "Пароль должен содержать хотя бы один спецсимвол",
        Colors.red,
      );
      return;
    }
    if (confirmPassCtrl.text.trim() != password) {
      _showSnackBar("Пароли не совпадают", Colors.red);
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/send-otp");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "purpose": "register"}),
      );
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() => _codeSent = true);
        _startCooldown();
        _showSnackBar("Код отправлен на $email", const Color(0xFF4CAF50));
      } else {
        _showSnackBar(data['message'] ?? "Ошибка отправки", Colors.red);
      }
    } catch (_) {
      _showSnackBar("Ошибка соединения с сервером", Colors.red);
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> register() async {
    final username = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();
    final code = codeCtrl.text.trim();

    if (code.isEmpty || code.length != 6) {
      _showSnackBar("Введите 6-значный код из письма", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/register");
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
          "code": code,
        }),
      );

      if (res.statusCode == 201) {
        _showSnackBar("Регистрация успешна!", const Color(0xFF4CAF50));
        // auto-login: get a token via login endpoint
        await Future.delayed(const Duration(milliseconds: 400));
        final loginRes = await http.post(
          Uri.parse("${ApiConfig.baseUrl}/login"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"email": email, "password": password}),
        );
        if (loginRes.statusCode == 200) {
          final loginData = jsonDecode(loginRes.body);
          if (loginData['success'] == true) {
            await SessionManager.saveUserSession(
              email,
              loginData['token'] as String,
            );
          }
        }
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainPage(userEmail: email)),
            (route) => false,
          );
        }
      } else {
        final data = jsonDecode(res.body);
        _showSnackBar(data['message'] ?? "Ошибка регистрации", Colors.red);
      }
    } catch (_) {
      _showSnackBar("Ошибка соединения с сервером", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == const Color(0xFF4CAF50)
                  ? Icons.check_circle
                  : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF6C63FF,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1,
                            color: Color(0xFF6C63FF),
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          "Создать аккаунт",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Начните играть с GamePulse",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ── Имя ──────────────────────────────────────────
                        _buildTextField(
                          controller: nameCtrl,
                          hintText: "Имя пользователя",
                          icon: Icons.person_outline,
                          enabled: !_codeSent,
                        ),
                        const SizedBox(height: 16),

                        // ── Email ─────────────────────────────────────────
                        _buildTextField(
                          controller: emailCtrl,
                          hintText: "Email",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_codeSent,
                        ),
                        const SizedBox(height: 16),

                        // ── Пароль ────────────────────────────────────────
                        _buildTextField(
                          controller: passCtrl,
                          hintText: "Пароль (мин. 8 символов, A-Z, !@#)",
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          enabled: !_codeSent,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF6C63FF),
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        if (passwordStrength.isNotEmpty && !_codeSent) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: passwordStrengthColor,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                passwordStrength,
                                style: TextStyle(
                                  color: passwordStrengthColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),

                        // ── Подтверждение пароля ──────────────────────────
                        _buildTextField(
                          controller: confirmPassCtrl,
                          hintText: "Подтверждение пароля",
                          icon: Icons.lock_person_outlined,
                          obscureText: _obscureConfirmPassword,
                          enabled: !_codeSent,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF6C63FF),
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Кнопка «Получить код» или поле кода ──────────
                        if (!_codeSent) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton.icon(
                              onPressed: _isSendingCode ? null : _sendCode,
                              icon: _isSendingCode
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.email_outlined, size: 20),
                              label: Text(
                                _isSendingCode
                                    ? "Отправка..."
                                    : "Получить код на почту",
                                style: const TextStyle(
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
                                disabledBackgroundColor: const Color(
                                  0xFF6C63FF,
                                ).withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ] else ...[
                          // ── Код из письма ──────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF4CAF50,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF4CAF50,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.mark_email_read_rounded,
                                  color: Color(0xFF4CAF50),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "Код отправлен на ${emailCtrl.text.trim()}",
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: codeCtrl,
                            hintText: "6-значный код из письма",
                            icon: Icons.pin_outlined,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _resendCooldown > 0 || _isSendingCode
                                    ? null
                                    : () {
                                        setState(() => _codeSent = false);
                                        codeCtrl.clear();
                                      },
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                label: const Text(
                                  "Изменить данные",
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white54,
                                ),
                              ),
                              TextButton(
                                onPressed: _resendCooldown > 0 || _isSendingCode
                                    ? null
                                    : _sendCode,
                                child: Text(
                                  _resendCooldown > 0
                                      ? "Повторить через ${_resendCooldown}с"
                                      : "Отправить снова",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _resendCooldown > 0
                                        ? Colors.white38
                                        : const Color(0xFF6C63FF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C63FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                disabledBackgroundColor: const Color(
                                  0xFF6C63FF,
                                ).withValues(alpha: 0.5),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      "Создать аккаунт",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: RichText(
                            text: TextSpan(
                              text: "Уже есть аккаунт? ",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 14,
                              ),
                              children: const [
                                TextSpan(
                                  text: "Войти",
                                  style: TextStyle(
                                    color: Color(0xFF6C63FF),
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFF1A1A2E) : const Color(0xFF111122),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(
          color: enabled ? Colors.white : Colors.white54,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: enabled
                ? const Color(0xFF6C63FF)
                : const Color(0xFF6C63FF).withValues(alpha: 0.4),
            size: 20,
          ),
          suffixIcon: suffixIcon,
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 15,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
