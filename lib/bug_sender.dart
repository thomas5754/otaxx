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
