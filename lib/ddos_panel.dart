import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'main.dart';

enum AttackMode { ipPort, domain }

class AttackPanel extends StatefulWidget {
  final String sessionKey;
  final List<Map<String, dynamic>> listDoos; // untuk kompatibilitas

  const AttackPanel({
    super.key,
    required this.sessionKey,
    this.listDoos = const [],
  });

  @override
  State<AttackPanel> createState() => _AttackPanelState();
}

class _AttackPanelState extends State<AttackPanel> with TickerProviderStateMixin {
  final targetController = TextEditingController();
  final portController = TextEditingController();

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  double attackDuration = 60;
  AttackMode _attackMode = AttackMode.ipPort;

  final Color bloodRed = const Color(0xFFE53935);
  final Color darkRed = const Color(0xFFB71C1C);
  final Color lightRed = const Color(0xFFFF5252);
  final Color deepBlack = const Color(0xFF0A0A0A);
  final Color cardDark = const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  void _onModeChanged(AttackMode mode) {
    setState(() {
      _attackMode = mode;
      if (mode == AttackMode.domain) {
        portController.text = "80";
      }
    });
  }

  Future<void> _sendAttack() async {
    final target = targetController.text.trim();
    if (target.isEmpty) {
      _showAlert("Input Tidak Valid", "Target tidak boleh kosong.");
      return;
    }

    int port;
    if (_attackMode == AttackMode.ipPort) {
      final portStr = portController.text.trim();
      if (portStr.isEmpty || int.tryParse(portStr) == null) {
        _showAlert("Port Tidak Valid", "Harap masukkan port yang benar (angka).");
        return;
      }
      port = int.parse(portStr);
    } else {
      port = 80; // default untuk domain
    }

    final key = widget.sessionKey;
    final int duration = attackDuration.toInt();

    try {
      final uri = Uri.parse("http://127.0.0.1:4113/sendCommand");
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': key,
          'target': target,
          'port': port,
          'duration': duration,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 401) {
        _showAlert("❌ Kunci Tidak Valid", data['error'] ?? "Sesi tidak valid.");
      } else if (response.statusCode == 400) {
        _showAlert("⚠️ Permintaan Salah", data['error'] ?? "Data yang dikirim tidak lengkap.");
      } else if (response.statusCode == 200 && data['success'] == true) {
        _showAlert("✅ Berhasil", data['message'] ?? "Serangan diluncurkan.");
      } else {
        _showAlert("❌ Gagal", data['error'] ?? "Terjadi kesalahan tak terduga.");
      }
    } catch (e) {
      _showAlert("❌ Error", "Koneksi gagal. Periksa jaringan Anda.");
    }
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: bloodRed.withOpacity(0.3), width: 1.5),
          ),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: bloodRed)),
          content: Text(msg, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: bloodRed)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardDark, cardDark.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bloodRed.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: bloodRed.withOpacity(0.15), blurRadius: 25, spreadRadius: 2),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGlassInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? hintText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [cardDark, cardDark.withOpacity(0.8)],
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(color: enabled ? Colors.white : Colors.white54),
        cursorColor: bloodRed,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: enabled ? Colors.white70 : Colors.white38),
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: enabled ? bloodRed : Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: bloodRed.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: bloodRed, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: bloodRed.withOpacity(0.3)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: bloodRed.withOpacity(0.1)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: bloodRed, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
        ),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 15, spreadRadius: 2),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepBlack,
      body: Stack(
        children: [
          // Background efek
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [bloodRed.withOpacity(0.1), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [darkRed.withOpacity(0.08), Colors.transparent],
                ),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildGlassCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.rocket_launch, color: bloodRed, size: 32),
                            const SizedBox(width: 12),
                            const Text(
                              "ATTACK PANEL",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: Tween(begin: 0.6, end: 1.0).animate(_controller),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [bloodRed.withOpacity(0.4), darkRed.withOpacity(0.4)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: bloodRed.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Target Input", Icons.computer),
                            _buildGlassInputField(
                              controller: targetController,
                              label: _attackMode == AttackMode.ipPort ? "Target IP" : "Domain",
                              icon: Icons.computer,
                              hintText: _attackMode == AttackMode.ipPort
                                  ? "Contoh: 1.1.1.1"
                                  : "Contoh: example.com",
                            ),
                            const SizedBox(height: 16),
                            // Mode selector
                            Center(
                              child: SegmentedButton<AttackMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: AttackMode.ipPort,
                                    label: Text('IP + Port'),
                                    icon: Icon(Icons.computer),
                                  ),
                                  ButtonSegment(
                                    value: AttackMode.domain,
                                    label: Text('Domain'),
                                    icon: Icon(Icons.public),
                                  ),
                                ],
                                selected: {_attackMode},
                                onSelectionChanged: (Set<AttackMode> newSelection) {
                                  _onModeChanged(newSelection.first);
                                },
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                                    (Set<MaterialState> states) {
                                      if (states.contains(MaterialState.selected)) {
                                        return bloodRed.withOpacity(0.3);
                                      }
                                      return cardDark;
                                    },
                                  ),
                                  foregroundColor: MaterialStateProperty.all(Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Port", Icons.wifi_tethering),
                            if (_attackMode == AttackMode.ipPort)
                              _buildGlassInputField(
                                controller: portController,
                                label: "Port",
                                icon: Icons.wifi_tethering,
                                keyboardType: TextInputType.number,
                                hintText: "Contoh: 80, 443, 22",
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: bloodRed.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.wifi_tethering, color: Colors.white54),
                                    const SizedBox(width: 12),
                                    const Text(
                                      "Port default: 80",
                                      style: TextStyle(color: Colors.white70, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("Durasi Serangan", Icons.timer),
                            const SizedBox(height: 16),
                            Text(
                              "⏱ ${attackDuration.toInt()} detik",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Slider(
                              value: attackDuration,
                              min: 10,
                              max: 300,
                              divisions: 29,
                              label: "${attackDuration.toInt()}s",
                              activeColor: bloodRed,
                              inactiveColor: Colors.white.withOpacity(0.2),
                              thumbColor: lightRed,
                              onChanged: (value) => setState(() => attackDuration = value),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildActionButton(
                        text: "LAUNCH ATTACK",
                        icon: Icons.bolt,
                        onPressed: _sendAttack,
                        color: bloodRed,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    targetController.dispose();
    portController.dispose();
    super.dispose();
  }
}