import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BugSenderPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const BugSenderPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
  });

  @override
  State<BugSenderPage> createState() => _BugSenderPageState();
}

class _BugSenderPageState extends State<BugSenderPage>
    with TickerProviderStateMixin {
  List<dynamic> senderList = [];
  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;

  // === BLACK & GOLD THEME ===
  static const Color _bgDeep = Color(0xFF000000);
  static const Color _bgCard = Color(0xFF0A0800);
  static const Color _bgSection = Color(0xFF050300);
  static const Color _gold = Color(0xFFB8860B);
  static const Color _goldDark = Color(0xFF8B6508);
  static const Color _border = Color(0xFF1A1200);
  static const Color _textMuted = Color(0xFF6B6B6B);
  static const Color _textSubtle = Color(0xFF3D3D3D);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fetchSenders();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchSenders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
            "https://affecting-gateway-marijuana-borders.trycloudflare.com/mySender?key=${widget.sessionKey}"),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["valid"] == true) {
          if (mounted) {
            setState(() {
              senderList = data["connections"] ?? [];
            });
          }
        } else {
          if (mounted) {
            setState(() => errorMessage = data["message"] ?? "Failed to fetch");
          }
        }
      } else {
        if (mounted) {
          setState(() => errorMessage = "Server error: ${response.statusCode}");
        }
      }
    } catch (e) {
      if (mounted) setState(() => errorMessage = "Connection failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshSenders() async {
    setState(() => isRefreshing = true);
    await _fetchSenders();
  }

  void _showAddSenderDialog() {
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _gold.withValues(alpha: 0.2)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _gold.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.add_link_rounded, color: _gold, size: 22),
            ),
            const SizedBox(width: 14),
            const Text(
              "NEW SENDER",
              style: TextStyle(
                color: _gold,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Masukkan nomor WhatsApp target yang ingin dihubungkan sebagai Sender Node.",
              style: TextStyle(color: _textMuted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono'),
              decoration: InputDecoration(
                labelText: "Phone Number",
                labelStyle: TextStyle(
                    color: _textMuted, fontFamily: 'ShareTechMono'),
                hintText: "628xxx...",
                hintStyle: TextStyle(color: _textSubtle),
                prefixIcon: Icon(Icons.phone_android, color: _gold.withValues(alpha: 0.6)),
                filled: true,
                fillColor: _bgSection,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _gold.withValues(alpha: 0.5), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "CANCEL",
              style: TextStyle(
                  color: _textMuted,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: TextButton(
              onPressed: () async {
                final number = phoneController.text.trim();
                if (number.isEmpty) {
                  Navigator.pop(context);
                  _showSnackBar("Number cannot be empty", isError: true);
                  return;
                }
                Navigator.pop(context);
                await _addSender(number);
              },
              child: const Text(
                "GENERATE PAIRING",
                style: TextStyle(
                  color: _gold,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addSender(String number) async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(
          "https://affecting-gateway-marijuana-borders.trycloudflare.com/getPairing?key=${widget.sessionKey}&number=$number"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["valid"] == true) {
          _showPairingCodeDialog(number, data['pairingCode']);
          _showSnackBar("Pairing sequence generated!", isError: false);
        } else {
          _showSnackBar(data['message'] ?? "Pairing failed", isError: true);
        }
      } else {
        _showSnackBar("Server Error: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      _showSnackBar("Connection Fault: $e", isError: true);
    } finally {
      setState(() => isLoading = false);
      _fetchSenders();
    }
  }

  void _showPairingCodeDialog(String number, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _gold.withValues(alpha: 0.4), width: 1.5),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                      color: _gold.withValues(alpha: 0.15),
                      blurRadius: 25,
                      spreadRadius: 0),
                ],
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: _gold, size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              "PAIRING REQUIRED",
              style: TextStyle(
                color: _gold,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "TARGET: $number",
              style: TextStyle(
                  color: _textMuted, fontFamily: 'ShareTechMono', fontSize: 12),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: _bgSection,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: _gold.withValues(alpha: 0.15),
                      blurRadius: 25,
                      spreadRadius: -5),
                ],
              ),
              child: Center(
                child: Text(
                  code,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    fontFamily: 'ShareTechMono',
                    shadows: [Shadow(color: _gold, blurRadius: 12)],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_all, color: _gold, size: 18),
                label: const Text(
                  "COPY TO CLIPBOARD",
                  style: TextStyle(
                    color: _gold,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side:
                      BorderSide(color: _gold.withValues(alpha: 0.4), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  _showSnackBar("Sequence copied to clipboard!", isError: false);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _fetchSenders();
            },
            child: Text(
              "CLOSE & REFRESH",
              style: TextStyle(
                  color: _textMuted,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSender(String senderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => AlertDialog(
        backgroundColor: _bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _gold.withValues(alpha: 0.4), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _gold, size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              "PURGE NODE",
              style: TextStyle(
                  color: _gold,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "Apakah Anda yakin ingin menghapus Sender Node ini selamanya? Proses ini tidak dapat dibatalkan.",
          style: TextStyle(color: _textMuted, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              "CANCEL",
              style: TextStyle(
                  color: _textMuted,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "PURGE",
                style: TextStyle(
                  color: _gold,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => isLoading = true);
      try {
        final response = await http.delete(Uri.parse(
            "https://affecting-gateway-marijuana-borders.trycloudflare.com/deleteSender?key=${widget.sessionKey}&id=$senderId"));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["valid"] == true) {
            _showSnackBar("Node purged successfully.", isError: false);
            _fetchSenders();
          } else {
            _showSnackBar(data["message"] ?? "Failed to purge node",
                isError: true);
          }
        } else {
          _showSnackBar("Server error: ${response.statusCode}", isError: true);
        }
      } catch (e) {
        _showSnackBar("Connection failed: $e", isError: true);
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: _bgDeep,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _bgDeep,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'ShareTechMono',
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.orangeAccent : _gold,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSenderCard(Map<String, dynamic> sender, int index) {
    final name = sender['sessionName'] ?? 'WhatsApp Sender';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _gold.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(Icons.hub_outlined, color: _gold, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "NODE ID: ${sender['id']?.toString().substring(0, 8) ?? 'UNKNOWN'}",
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 11,
                          fontFamily: 'ShareTechMono',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _gold.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _gold,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _gold.withValues(
                                      alpha: _pulseAnimation.value),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "ONLINE",
                        style: TextStyle(
                          color: _gold,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'ShareTechMono',
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            color: _border,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _refreshSenders(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sync, size: 16, color: _textMuted),
                            const SizedBox(width: 8),
                            Text(
                              "SYNC",
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: _border),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _deleteSender(sender['id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: _gold),
                            const SizedBox(width: 8),
                            Text(
                              "PURGE",
                              style: TextStyle(
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: _gold,
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
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.04),
                shape: BoxShape.circle,
                border: Border.all(color: _gold.withValues(alpha: 0.12), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: _gold.withValues(alpha: 0.06),
                      blurRadius: 40,
                      spreadRadius: 0),
                ],
              ),
              child: Icon(Icons.router_outlined,
                  color: _gold.withValues(alpha: 0.3), size: 60),
            ),
            const SizedBox(height: 30),
            const Text(
              "NO ACTIVE NODES",
              style: TextStyle(
                color: _gold,
                fontSize: 17,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Sistem tidak mendeteksi koneksi pengirim.\nTambahkan WhatsApp node pertama Anda.",
              style: TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontFamily: 'ShareTechMono',
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1.5),
                gradient: LinearGradient(
                  colors: [
                    _gold.withValues(alpha: 0.12),
                    _goldDark.withValues(alpha: 0.06),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                      color: _gold.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 0),
                ],
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_link_rounded, color: _gold, size: 20),
                label: const Text(
                  "INITIALIZE SENDER",
                  style: TextStyle(
                    color: _gold,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _showAddSenderDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
