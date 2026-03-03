import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'utils/session_manager.dart';
import 'utils/theme_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeManager.loadSavedTheme();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static ThemeData get _darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D1E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          surface: Color(0xFF1A1A2E),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          hintStyle: TextStyle(color: Colors.white70),
        ),
      );

  static ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F2F8),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF6C63FF),
          surface: Color(0xFFFFFFFF),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          hintStyle: TextStyle(color: Colors.black45),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeManager.notifier,
      builder: (_, mode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'GamePulse',
          themeMode: mode,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          home: const SplashScreen(),
          onGenerateRoute: (settings) {
            if (settings.name == '/main') {
              final email = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => MainPage(userEmail: email),
              );
            }
            return MaterialPageRoute(builder: (_) => const LoginPage());
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final isLoggedIn = await SessionManager.isLoggedIn();

    if (isLoggedIn) {
      final email = await SessionManager.getUserEmail();
      if (email != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MainPage(userEmail: email),
          ),
        );
        return;
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.games,
                color: Color(0xFF6C63FF),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "GamePulse",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              color: Color(0xFF6C63FF),
            ),
          ],
        ),
      ),
    );
  }
}
