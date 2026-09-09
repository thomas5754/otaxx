import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'live_target_overlay.dart';
import 'ddos_panel.dart';
import 'main.dart'; // Tambahkan ini

class VpsPage extends StatefulWidget {
  final String username;
  final String role;
  final String sessionKey;

  const VpsPage({
    super.key,
    required this.username,
    required this.role,
    required this.sessionKey,
  });

  @override
  State<VpsPage> createState() => _VpsPageState();
}

class _VpsPageState extends State<VpsPage> with SingleTickerProviderStateMixin {
  final Color primaryDark = const Color(0xFF0A0A0A);
  final Color deepRed = const Color(0xFFB00020);
  final Color accentRed = const Color(0xFFE53935);
  final Color cyberBlue = const Color(0xFF2962FF);
  final Color cyberPurple = const Color(0xFFAA00FF);
  final Color cyberGreen = const Color(0xFF00C853);
  final Color cardDark = const Color(0xFF121212);
  final Color primaryWhite = Colors.white;
  final Color glassColor = Colors.white.withOpacity(0.05);

  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<Map<String, dynamic>> _vpsList = [];
  Map<String, dynamic>? _selectedVps;
  bool _isLoading = true;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    _loadVpsData();
  }

  Future<void> _loadVpsData() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse("$baseUrl/myServer?key=${widget.sessionKey}");
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _vpsList = List<Map<String, dynamic>>.from(data);
          if (_vpsList.isNotEmpty) _selectedVps = _vpsList.first;
        });
      } else if (res.statusCode == 401) {
        // Session tidak valid, kembali ke login
        _showSnackBar('Sesi tidak valid, silakan login ulang', isError: true);
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushReplacementNamed(context, '/login');
        });
      } else {
        _showSnackBar('Gagal memuat VPS: ${res.body}', isError: true);
        setState(() {
          _vpsList = [];
          _selectedVps = null;
        });
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
      setState(() {
        _vpsList = [];
        _selectedVps = null;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addVps() async {
    if (_aliasController.text.isEmpty ||
        _ipController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnackBar('Semua field wajib diisi!', isError: true);
      return;
    }

    try {
      final uri = Uri.parse("$baseUrl/addServer");
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': widget.sessionKey,
          'host': _ipController.text.trim(),
          'port': int.tryParse(_portController.text) ?? 22,
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
          'alias': _aliasController.text.trim(),
        }),
      );

      if (res.statusCode == 200) {
        _showSnackBar('✅ VPS berhasil ditambahkan!');
        _aliasController.clear();
        _ipController.clear();
        _portController.clear();
        _usernameController.clear();
        _passwordController.clear();
        _loadVpsData();
      } else {
        _showSnackBar('Gagal: ${res.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _deleteVps(String host) async {
    final confirm = await _showConfirmDialog('Hapus VPS?', 'Yakin ingin menghapus VPS ini?');
    if (!confirm) return;

    try {
      final uri = Uri.parse("$baseUrl/delServer");
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'key': widget.sessionKey, 'host': host}),
      );

      if (res.statusCode == 200) {
        _showSnackBar('🗑️ VPS berhasil dihapus!');
        _loadVpsData();
      } else {
        _showSnackBar('Gagal: ${res.body}', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: isError ? [deepRed, accentRed] : [cyberGreen, Colors.green],
            ),
          ),
          child: Row(
            children: [
              Icon(isError ? Icons.error_outline : Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cardDark, const Color(0xFF1A1A1A)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentRed.withOpacity(0.5)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: cyberGreen, size: 48),
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(message, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white30),
                            ),
                          ),
                          child: const Text('BATAL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: deepRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('LANJUT'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ) ??
        false;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cyberPurple.withOpacity(0.2), cyberBlue.withOpacity(0.1), Colors.transparent],
        ),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [cyberBlue, cyberPurple]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: cyberBlue.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.terminal, color: Colors.white, size: 28),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cardDark.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cyberBlue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_outline, color: cyberBlue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.username.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (widget.role.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cyberPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: cyberPurple.withOpacity(0.5)),
                        ),
                        child: Text(
                          widget.role.toUpperCase(),
                          style: TextStyle(color: cyberPurple, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [cyberBlue, cyberPurple, accentRed],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(bounds),
            child: const Text(
              "OTAX VPS Manager",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1.5, height: 1.2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Kelola server VPS dengan mudah dan cepat",
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'DAFTAR VPS', Icons.list_alt_rounded),
          _buildTabButton(1, 'SERANGAN', Icons.bolt_rounded),
          _buildTabButton(2, 'LIVE TARGET', Icons.my_location_rounded),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isActive = _activeTab == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _activeTab = index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(colors: [cyberBlue, cyberPurple])
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: isActive ? Border.all(color: Colors.white.withOpacity(0.2)) : null,
              boxShadow: isActive ? [BoxShadow(color: cyberBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
            ),
            child: Column(
              children: [
                Icon(icon, color: isActive ? Colors.white : Colors.white70, size: 20),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVpsListTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: cyberBlue),
                    const SizedBox(width: 10),
                    Text('TAMBAH VPS BARU', style: TextStyle(color: cyberBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInputField('Nama/Alias', _aliasController, Icons.badge_outlined, 'Contoh: Server Utama'),
                const SizedBox(height: 12),
                _buildInputField('Alamat IP', _ipController, Icons.dns_outlined, '192.168.1.1'),
                const SizedBox(height: 12),
                _buildInputField('Port SSH', _portController, Icons.numbers_outlined, '22 (default)', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _buildInputField('Username', _usernameController, Icons.person_outline, 'root atau user'),
                const SizedBox(height: 12),
                _buildInputField('Password', _passwordController, Icons.lock_outline, 'Password SSH', isPassword: true),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _addVps,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [cyberBlue, cyberPurple]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: cyberBlue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('TAMBAH VPS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_vpsList.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildGlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage_outlined, color: cyberBlue),
                      const SizedBox(width: 10),
                      const Text('VPS TERSIMPAN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cyberBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: cyberBlue.withOpacity(0.3)),
                        ),
                        child: Text('${_vpsList.length} VPS', style: TextStyle(color: cyberBlue, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._vpsList.map((vps) => _buildVpsCard(vps)).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVpsCard(Map<String, dynamic> vps) {
    final isSelected = _selectedVps?['host'] == vps['host'];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? cyberBlue.withOpacity(0.15) : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? cyberBlue : Colors.white12, width: isSelected ? 2 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedVps = vps),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [cyberBlue.withOpacity(0.4), cyberPurple.withOpacity(0.4)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.computer_outlined, color: cyberBlue, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vps['alias'] ?? vps['host'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${vps['host']}:${vps['port']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('User: ${vps['username']}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _selectedVps = vps),
                      icon: Icon(Icons.check_circle, color: isSelected ? cyberGreen : Colors.white30, size: 24),
                    ),
                    IconButton(
                      onPressed: () => _deleteVps(vps['host']),
                      icon: Icon(Icons.delete_outline, color: deepRed.withOpacity(0.8), size: 22),
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

  Widget _buildAttackTab() {
    return Center(
      child: _selectedVps != null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, color: Color(0xFFE53935), size: 80),
                const SizedBox(height: 20),
                const Text(
                  'Gunakan DDoS Panel untuk meluncurkan serangan',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttackPanel(sessionKey: widget.sessionKey),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('BUKA DDOS PANEL'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            )
          : const Text(
              'Pilih VPS terlebih dahulu',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
    );
  }

  Widget _buildLiveTargetTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildGlassCard(
            child: Column(
              children: [
                const Icon(Icons.my_location, color: Color(0xFFE53935), size: 64),
                const SizedBox(height: 16),
                const Text(
                  'LIVE TARGET CAPTURE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Aktifkan overlay untuk menangkap IP dan port dari game yang sedang berjalan (Mobile Legends, dll).\n'
                  'Setelah muncul, tekan "SERANG" untuk meluncurkan serangan menggunakan VPS Anda.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _requestOverlayPermission,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('BUKA OVERLAY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _requestOverlayPermission() async {
    final status = await Permission.systemAlertWindow.request();
    if (status.isGranted) {
      await _showOverlay();
    } else {
      _showSnackBar('Izin overlay diperlukan', isError: true);
    }
  }

  Future<void> _showOverlay() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_key', widget.sessionKey);
    await FlutterOverlayWindow.showOverlay(
      height: 280,
      width: 320,
      overlayTitle: 'Live Target',
      overlayContent: 'Menangkap koneksi...',
      enableDrag: true,
      positionGravity: PositionGravity.auto,
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    IconData icon,
    String hint, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
          prefixIcon: Icon(icon, color: cyberBlue, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: glassColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF0F0F1A), Color(0xFF0A0A15)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF2962FF)))
                    : IndexedStack(
                        index: _activeTab,
                        children: [
                          _buildVpsListTab(),
                          _buildAttackTab(),
                          _buildLiveTargetTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}