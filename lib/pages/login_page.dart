import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'register_page.dart';
import 'main_page.dart';
import 'admin_panel_page.dart';
import '../utils/session_manager.dart';
import '../utils/api_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  Future<void> login() async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (email.isEmpty) {
      _showSnackBar("Введите email", Colors.orange);
      return;
    }
    
    if (!_isValidEmail(email)) {
      _showSnackBar("Введите корректный email", Colors.orange);
      return;
    }

    if (password.isEmpty) {
      _showSnackBar("Введите пароль", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final token = data['token'] as String? ?? '';
          final isAdmin = data['isAdmin'] == true;

          _showSnackBar("Успешный вход!", const Color(0xFF4CAF50));
          await Future.delayed(const Duration(milliseconds: 500));

          if (isAdmin) {
            await SessionManager.saveAdminToken(token);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminPanelPage(adminEmail: email, adminToken: token),
                ),
              );
            }
          } else {
            await SessionManager.saveUserSession(email, token);
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => MainPage(userEmail: email),
                ),
              );
            }
          }
        } else {
          _showSnackBar(
            data['message'] ?? "Неверные данные",
            Colors.red,
          );
        }
      } else {
        _showSnackBar("Ошибка сервера: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Ошибка подключения: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    // Controllers
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        bool codeSent = false;
        bool isBusy = false;
        int cooldown = 0;
        Timer? timer;

        void startCooldown(StateSetter ss) {
          cooldown = 60;
          timer?.cancel();
          timer = Timer.periodic(const Duration(seconds: 1), (t) {
            ss(() {
              if (cooldown > 0) { cooldown--; } else { t.cancel(); }
            });
          });
        }

        return StatefulBuilder(
          builder: (context, ss) {
            Future<void> sendCode() async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !_isValidEmail(email)) {
                _showSnackBar("Введите корректный email", Colors.orange);
                return;
              }
              ss(() => isBusy = true);
              try {
                final response = await http.post(
                  Uri.parse('${ApiConfig.baseUrl}/send-otp'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'email': email, 'purpose': 'reset'}),
                );
                final data = jsonDecode(response.body);
                if (data['success'] == true) {
                  ss(() => codeSent = true);
                  startCooldown(ss);
                  _showSnackBar("Код отправлен на $email", const Color(0xFF4CAF50));
                } else {
                  _showSnackBar(data['message'] ?? "Ошибка", Colors.red);
                }
              } catch (_) {
                _showSnackBar("Ошибка подключения", Colors.red);
              } finally {
                ss(() => isBusy = false);
              }
            }

            Future<void> resetPassword() async {
              final email = emailCtrl.text.trim();
              final code = codeCtrl.text.trim();
              final newPass = newPassCtrl.text;
              final confirmPass = confirmPassCtrl.text;

              if (code.isEmpty || code.length != 6) {
                _showSnackBar("Введите 6-значный код из письма", Colors.orange);
                return;
              }
              if (newPass.length < 8) {
                _showSnackBar("Пароль должен быть не менее 8 символов", Colors.orange);
                return;
              }
              if (newPass != confirmPass) {
                _showSnackBar("Пароли не совпадают", Colors.red);
                return;
              }
              ss(() => isBusy = true);
              try {
                final response = await http.post(
                  Uri.parse('${ApiConfig.baseUrl}/forgot-password'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'email': email, 'code': code, 'newPassword': newPass}),
                );
                final data = jsonDecode(response.body);
                if (data['success'] == true) {
                  timer?.cancel();
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _showSnackBar("Пароль изменён! Войдите с новым паролем.",
                        const Color(0xFF4CAF50));
                  }
                } else {
                  _showSnackBar(data['message'] ?? "Ошибка", Colors.red);
                }
              } catch (_) {
                _showSnackBar("Ошибка подключения", Colors.red);
              } finally {
                ss(() => isBusy = false);
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.lock_reset, color: Color(0xFF6C63FF), size: 26),
                  const SizedBox(width: 10),
                  Text(
                    codeSent ? "Введите код и пароль" : "Сброс пароля",
                    style: const TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!codeSent) ...[
                      Text(
                        "Введите email — мы пришлём код для сброса пароля",
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      _buildDialogField(emailCtrl, "Email", Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mark_email_read_rounded,
                                color: Color(0xFF4CAF50), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Код отправлен на ${emailCtrl.text.trim()}",
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildDialogField(codeCtrl, "6-значный код из письма",
                          Icons.pin_outlined,
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 10),
                      _buildDialogField(newPassCtrl, "Новый пароль",
                          Icons.lock_outline,
                          obscure: true),
                      const SizedBox(height: 10),
                      _buildDialogField(confirmPassCtrl, "Подтвердите пароль",
                          Icons.lock_outline,
                          obscure: true),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: cooldown > 0 || isBusy ? null : sendCode,
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero),
                          child: Text(
                            cooldown > 0
                                ? "Повторить через ${cooldown}с"
                                : "Отправить код снова",
                            style: TextStyle(
                              fontSize: 12,
                              color: cooldown > 0
                                  ? Colors.white38
                                  : const Color(0xFF6C63FF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isBusy ? null : () {
                    timer?.cancel();
                    Navigator.pop(dialogContext);
                  },
                  child: Text("Отмена",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                ),
                ElevatedButton(
                  onPressed: isBusy ? null : (codeSent ? resetPassword : sendCode),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          codeSent ? "Сменить пароль" : "Отправить код",
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
          filled: true,
          fillColor: Colors.transparent,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.games_rounded,
                      color: Color(0xFF6C63FF),
                      size: 40,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  const Text(
                    "GamePulse",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    "Добро пожаловать!",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 48),

                  _buildTextField(
                    controller: emailCtrl,
                    hintText: "Email",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: passCtrl,
                    hintText: "Пароль",
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: const Color(0xFF6C63FF),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text(
                        "Забыли пароль?",
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
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
                              "Войти",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterPage(),
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: "Нет аккаунта? ",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                        children: const [
                          TextSpan(
                            text: "Зарегистрироваться",
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF6C63FF),
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