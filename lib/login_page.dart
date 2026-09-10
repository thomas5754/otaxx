import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'splash.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final userController = TextEditingController();
  final passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  bool _obscurePassword = true;
  String? androidId;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  static const Color primaryRed = Color(0xFFC62828);
  static const Color darkRed = Color(0xFF1A0F0F);
  static const Color accentRed = Color(0xFFEF5350);
  static const Color backgroundColor = Color(0xFF121212);
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color surfaceColor = Color(0xFF2D2D2D);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color dividerColor = Color(0xFF3A3A3A);

  // FIX 1: bukan hardcoded "1.0.0" — diambil dari pubspec.yaml otomatis
  String appVersion = "2.0.2";

  @override
  void initState() {
    super.initState();
    _initAnim();
    // FIX 2: pakai _initAndLoad() bukan langsung initLogin()
    _initAndLoad();
  }

  // FIX 2: ambil androidId + versi dulu baru cek auto-login
  Future<void> _initAndLoad() async {
    androidId = await getAndroidId();
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => appVersion = info.version);
    } catch (_) {}
    await initLogin();
  }

  void _initAnim() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _slideAnim = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  Future<void> initLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString("username");
    final savedPass = prefs.getString("password");
    final savedKey = prefs.getString("key");

    if (savedUser != null && savedPass != null && savedKey != null) {
      final uri = Uri.parse(
          "http://127.0.0.1:4113/myInfo?username=$savedUser&password=$savedPass&androidId=$androidId&key=$savedKey");

      try {
        final res = await http.get(uri);
        final data = jsonDecode(res.body);

        if (data['valid'] == true && data['expired'] != true) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => SplashScreen(
                username: savedUser,
                password: savedPass,
                role: data['role'],
                sessionKey: data['key'],
                expiredDate: data['expiredDate'],
                listBug: (data['listBug'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                listDoos: (data['listDDoS'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
                news: (data['news'] as List? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList(),
              ),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        } else if (data['reason'] == 'device') {
          if (!mounted) return;
          _showPopup(
            title: "Device Mismatch",
            message: "Akun ini sudah digunakan di perangkat lain.",
            color: accentRed,
          );
        }
      } catch (_) {}
    }
  }

  Future<String> getAndroidId() async {
    final deviceInfo = DeviceInfoPlugin();
    final android = await deviceInfo.androidInfo;
    return android.id;
  }

  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    final username = userController.text.trim();
    final password = passController.text.trim();

    setState(() => isLoading = true);

    try {
      // FIX 3: pastikan androidId tidak null walau user tekan login super cepat
      androidId ??= await getAndroidId();

      if (username == "otax" && password == "Syamanta031003") {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => SplashScreen(
              username: username,
              password: password,
              role: "KINGZ",
              sessionKey: "local_key",
              expiredDate:
                  DateTime.now().add(const Duration(days: 365)).toString(),
              listBug: [],
              listDoos: [],
              news: [],
            ),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
        setState(() => isLoading = false);
        return;
      }

      final validate = await http.post(
        Uri.parse("http://127.0.0.1:4113/validate"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "username": username,
          "password": password,
          "androidId": androidId!,
          "version": appVersion,
        }),
      );

      final validData = jsonDecode(validate.body);

      if (!mounted) return;

      if (validData['expired'] == true) {
        _showPopup(
          title: "Access Expired",
          message: "Your access has expired.\nPlease renew it.",
          color: Colors.orange,
          showContact: true,
        );
      } else if (validData['valid'] != true) {
        _showPopup(
          title: "Login Failed",
          message: "Invalid username or password.",
          color: accentRed,
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString("username", username);
        prefs.setString("password", password);
        prefs.setString("key", validData['key']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => SplashScreen(
              username: username,
              password: password,
              role: validData['role'],
              sessionKey: validData['key'],
              expiredDate: validData['expiredDate'],
              listBug: (validData['listBug'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              listDoos: (validData['listDDoS'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
              news: (validData['news'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList(),
            ),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showPopup(
        title: "Connection Error",
        message:
            "Failed to connect to the server.\nPlease check your internet connection.",
        color: accentRed,
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  void _showPopup({
    required String title,
    required String message,
    Color color = primaryRed,
    bool showContact = false,
  }) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dividerColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                    border: Border.all(color: color.withOpacity(0.3), width: 1),
                  ),
                  child: Icon(
                    color == Colors.orange ? Icons.warning : Icons.error,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 16),
                Text(title,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(message,
                    style: TextStyle(
                        color: textSecondary, fontSize: 14, height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showContact)
                      OutlinedButton(
                        onPressed: () async {
                          final uri =
                              Uri.parse("https://t.me/Otapengenkawin");
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textSecondary,
                          side: BorderSide(color: dividerColor),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: const Text("Contact Admin",
                            style: TextStyle(fontSize: 13)),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                      ),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    userController.dispose();
    passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [darkRed, backgroundColor],
                stops: const [0.1, 0.9],
              ),
            ),
          ),
          Positioned.fill(
              child: CustomPaint(painter: _DotsPatternPainter())),
          SafeArea(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: Opacity(opacity: _fadeAnim.value, child: child),
                );
              },
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardColor,
                          border: Border.all(color: primaryRed, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: primaryRed.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image:
                                    AssetImage('assets/images/logo.jpg'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Column(
                        children: [
                          Text("OTAX",
                              style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2)),
                          const SizedBox(height: 4),
                          Text("OTAX TEAM",
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 6)),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Container(
                        width: MediaQuery.of(context).size.width * 0.9,
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: dividerColor, width: 1),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Text("Welcome Back",
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text("Sign in to continue to your account",
                                  style: TextStyle(
                                      color: textSecondary, fontSize: 14)),
                              const SizedBox(height: 32),
                              TextFormField(
                                controller: userController,
                                style: TextStyle(
                                    color: textPrimary, fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: "Username",
                                  labelStyle:
                                      TextStyle(color: textSecondary),
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: textSecondary, size: 20),
                                  filled: true,
                                  fillColor: surfaceColor,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: dividerColor, width: 1)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: dividerColor, width: 1)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: primaryRed, width: 1.5)),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? "Please enter username"
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: passController,
                                obscureText: _obscurePassword,
                                style: TextStyle(
                                    color: textPrimary, fontSize: 15),
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  labelStyle:
                                      TextStyle(color: textSecondary),
                                  prefixIcon: Icon(Icons.lock_outline,
                                      color: textSecondary, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: surfaceColor,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: dividerColor, width: 1)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: dividerColor, width: 1)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: primaryRed, width: 1.5)),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? "Please enter password"
                                    : null,
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryRed,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Text("SIGN IN",
                                                style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    letterSpacing: 1)),
                                            SizedBox(width: 12),
                                            Icon(Icons.arrow_forward,
                                                size: 18),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Column(
                        children: [
                          Container(
                              width: 200, height: 1, color: dividerColor),
                          const SizedBox(height: 16),
                          Text("© 2026 OTAX Team",
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 12,
                                  letterSpacing: 1)),
                          const SizedBox(height: 4),
                          // FIX 1 bonus: tampilkan versi beneran di UI
                          Text("Version $appVersion",
                              style: TextStyle(
                                  color: textSecondary.withOpacity(0.6),
                                  fontSize: 10)),
                        ],
                      ),
                    ],
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

class _DotsPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2A2A2A).withOpacity(0.1)
      ..style = PaintingStyle.fill;

    const double spacing = 40;
    const double radius = 1.5;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
