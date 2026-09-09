import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main.dart';
import 'bug_sender.dart';

class CustomPayloadPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;
  final List<Map<String, dynamic>> listBug;

  const CustomPayloadPage({
    super.key,
    required this.sessionKey,
    required this.username,
    required this.role,
    required this.listBug,
  });

  @override
  State<CustomPayloadPage> createState() => _CustomPayloadPageState();
}

class _CustomPayloadPageState extends State<CustomPayloadPage>
    with TickerProviderStateMixin {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _delayController =
      TextEditingController(text: "1000");
  final TextEditingController _countController =
      TextEditingController(text: "1");

  final List<Map<String, dynamic>> _selectedBugs = [];
  bool _isSending = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Video
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  // Colors — sama dengan homepage
  static const Color _primaryColor    = Color(0xFF050810);
  static const Color _accentColor     = Color(0xFF00D4FF);
  static const Color _accentSoft      = Color(0xFF0099CC);
  static const Color _successColor    = Color(0xFF00E5A0);
  static const Color _warningColor    = Color(0xFFFFB547);
  static const Color _dangerColor     = Color(0xFFFF4D6A);
  static const Color _textPrimary     = Color(0xFFEEF2FF);
  static const Color _textSecondary   = Color(0xFF8B9BBE);
  static const Color _cardBorder      = Color(0xFF1E2D4A);
  static const Color _cardColor       = Color(0xFF0E1628);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initVideoPlayer();
  }

  void _initVideoPlayer() {
    _videoController =
        VideoPlayerController.asset('assets/videos/otaxai.mp4');
    _videoController.initialize().then((_) {
      setState(() {
        _videoController
          ..setVolume(0.0)
          ..setLooping(true);
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: true,
          showControls: false,
          autoInitialize: true,
        );
        _isVideoInitialized = true;
        _videoController.play();
      });
    }).catchError((_) => setState(() => _isVideoInitialized = false));
  }

  @override
  void dispose() {
    _targetController.dispose();
    _delayController.dispose();
    _countController.dispose();
    _pulseController.dispose();
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  // ─── helpers ───────────────────────────────────────────────────────────────

  String? formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return null;
    return cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
  }

  List<Color> _bugGradient(int index) {
    const palettes = [
      [Color(0xFF00D4FF), Color(0xFF00E5A0)],
      [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      [Color(0xFF8E54E9), Color(0xFF4776E6)],
      [Color(0xFFFFD166), Color(0xFFFFB347)],
      [Color(0xFF06D6A0), Color(0xFF4CC9F0)],
    ];
    return palettes[index % palettes.length];
  }

  // ─── sender check (persis homepage) ───────────────────────────────────────

  Future<bool> _hasSender() async {
    try {
      final res = await http.get(
        Uri.parse("http://127.0.0.1:4113/mySender?key=${widget.sessionKey}"),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode != 200) return false;
      final data = jsonDecode(res.body);
      return data["valid"] == true &&
          data["connections"] != null &&
          (data["connections"] as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showProfessionalDialog(
    String title,
    String message,
    IconData icon,
    Color color, {
    VoidCallback? onPressed,
    String buttonLabel = 'MENGERTI',
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(40),
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _cardColor.withOpacity(0.97),
                _cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withOpacity(0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 50,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.08),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 36),
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Debrosee',
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    height: 1.65,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (onPressed != null) onPressed();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ).copyWith(
                      overlayColor: MaterialStateProperty.all(
                        Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontFamily: 'Debrosee',
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── send ──────────────────────────────────────────────────────────────────

  Future<void> _sendSequentialPayload() async {
    // ── cek sender persis seperti homepage ──
    final hasSender = await _hasSender();
    if (!hasSender) {
      _showProfessionalDialog(
        "Sender Required",
        "Kamu belum punya sender aktif. Tambahkan sender terlebih dahulu sebelum mengirim payload.",
        Icons.wifi_find_rounded,
        _warningColor,
        buttonLabel: 'TAMBAH SENDER',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BugSenderPage(
                sessionKey: widget.sessionKey,
                username: widget.username,
                role: widget.role,
              ),
            ),
          );
        },
      );
      return;
    }

    final target = formatPhoneNumber(_targetController.text.trim());
    if (target == null || target.length < 10) {
      _toast('Format nomor tidak valid', _warningColor); return;
    }
    if (_selectedBugs.isEmpty) {
      _toast('Pilih minimal satu bug', _warningColor); return;
    }
    final delay = int.tryParse(_delayController.text) ?? 1000;
    final count = int.tryParse(_countController.text) ?? 1;
    if (delay < 0 || delay > 60000) {
      _toast('Delay harus 0-60000 ms', _warningColor); return;
    }
    if (count < 1 || count > 100) {
      _toast('Count harus 1-100', _warningColor); return;
    }

    setState(() => _isSending = true);
    try {
      final payload = {
        'key': widget.sessionKey,
        'target': target,
        'delay': delay,
        'count': count,
        'bugs': _selectedBugs.map((b) => b['bug_id']).toList(),
        'mode': 'sequential',
        'sequence_order': _selectedBugs.map((b) => b['bug_id']).toList(),
      };
      final response = await http
          .post(
            Uri.parse("http://127.0.0.1:4113/api/custom-payload"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final bugCount = _selectedBugs.length;
          _targetController.clear();
          setState(() => _selectedBugs.clear());
          _showSuccessSheet(target, count, delay, bugCount);
        } else {
          _toast(data['message'] ?? 'Gagal mengirim', _dangerColor);
        }
      } else {
        _toast('Server error ${response.statusCode}', _dangerColor);
      }
    } catch (e) {
      _toast('Koneksi error: $e', _dangerColor);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _showSuccessSheet(String target, int count, int delay, int bugCount) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SuccessSheet(
        target: target,
        count: count,
        delay: delay,
        bugCount: bugCount,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  void _openBugPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _BugPickerSheet(
          allBugs: widget.listBug,
          selectedBugs: _selectedBugs,
          bugGradient: _bugGradient,
          onAdd: (bug, index) {
            if (!_selectedBugs.any((s) => s['bug_id'] == bug['bug_id'])) {
              setState(() {
                _selectedBugs.add({
                  'bug_id': bug['bug_id'],
                  'bug_name': bug['bug_name'],
                  'colorIndex': index,
                });
              });
              setSheetState(() {});
            }
          },
          onRemove: (bugId) {
            setState(() {
              _selectedBugs.removeWhere((s) => s['bug_id'] == bugId);
            });
            setSheetState(() {});
          },
        ),
      ),
    );
  }

  // ─── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Video BG
          Positioned.fill(
            child: _isVideoInitialized && _chewieController != null
                ? Chewie(controller: _chewieController!)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D1B2A), _primaryColor],
                      ),
                    ),
                  ),
          ),
          // Dark overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.60),
                    Colors.black.withOpacity(0.82),
                  ],
                ),
              ),
            ),
          ),
          // Accent glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.7, -0.9),
                  radius: 1.2,
                  colors: [
                    _accentColor.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                    child: Column(
                      children: [
                        _buildTargetCard(),
                        const SizedBox(height: 12),
                        _buildBugQueueCard(),
                        const SizedBox(height: 12),
                        _buildConfigRow(),
                        const SizedBox(height: 16),
                        _buildSendButton(),
                        const SizedBox(height: 10),
                        _buildStatusBar(),
                      ],
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

  // ─── header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(bottom: BorderSide(color: _cardBorder.withOpacity(0.5))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: _accentColor.withOpacity(0.08),
                    border: Border.all(color: _accentColor.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _accentColor, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (b) => const LinearGradient(
                      colors: [_textPrimary, _accentColor],
                      stops: [0.5, 1.0],
                    ).createShader(b),
                    child: const Text(
                      'CUSTOM PAYLOAD',
                      style: TextStyle(
                        fontFamily: 'Debrosee',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Mode Sekuensial • Bebas Atur',
                      style: TextStyle(
                          color: _textSecondary, fontSize: 10.5, letterSpacing: 0.4)),
                ],
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (_, __) => Transform.scale(
                  scale: _selectedBugs.isEmpty ? 1.0 : _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _accentColor.withOpacity(0.15),
                        _accentColor.withOpacity(0.04),
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _accentColor
                            .withOpacity(_selectedBugs.isEmpty ? 0.2 : 0.5),
                      ),
                      boxShadow: _selectedBugs.isNotEmpty
                          ? [
                              BoxShadow(
                                  color: _accentColor.withOpacity(0.2),
                                  blurRadius: 12)
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${_selectedBugs.length}',
                            style: TextStyle(
                              fontFamily: 'Debrosee',
                              color: _selectedBugs.isEmpty
                                  ? _textSecondary
                                  : _accentColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            )),
                        Text('BUG',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── target input ──────────────────────────────────────────────────────────

  Widget _buildTargetCard() {
    return _glassCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_accentColor, _accentSoft]),
              boxShadow: [
                BoxShadow(color: _accentColor.withOpacity(0.3), blurRadius: 12)
              ],
            ),
            child: const Icon(Icons.phone_android_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NOMOR TARGET',
                    style: TextStyle(
                      fontFamily: 'Debrosee',
                      color: _textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.4,
                    )),
                TextField(
                  controller: _targetController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: _accentColor,
                  decoration: InputDecoration(
                    hintText: '62xxxxxxxxxx',
                    hintStyle: TextStyle(
                        color: _textSecondary.withOpacity(0.4), fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(top: 6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── bug queue card ────────────────────────────────────────────────────────

  Widget _buildBugQueueCard() {
    return _glassCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _dangerColor.withOpacity(0.12),
                  border: Border.all(color: _dangerColor.withOpacity(0.25)),
                ),
                child: Icon(Icons.bug_report_rounded, color: _dangerColor, size: 15),
              ),
              const SizedBox(width: 10),
              Text('ANTRIAN PAYLOAD',
                  style: TextStyle(
                    fontFamily: 'Debrosee',
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  )),
              const Spacer(),
              if (_selectedBugs.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _selectedBugs.clear()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _dangerColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _dangerColor.withOpacity(0.2)),
                    ),
                    child: Text('Reset',
                        style: TextStyle(
                            color: _dangerColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),

          if (_selectedBugs.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                itemCount: _selectedBugs.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _selectedBugs.removeAt(oldIndex);
                    _selectedBugs.insert(newIndex, item);
                  });
                },
                proxyDecorator: (child, index, animation) => child,
                itemBuilder: (ctx, i) {
                  final bug = _selectedBugs[i];
                  final colors = _bugGradient(bug['colorIndex'] ?? i);
                  return ReorderableDragStartListener(
                    key: ValueKey(bug['bug_id']),
                    index: i,
                    child: Container(
                      margin: EdgeInsets.only(
                          right: i < _selectedBugs.length - 1 ? 8 : 0),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          colors[0].withOpacity(0.22),
                          colors[1].withOpacity(0.10),
                        ]),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                            color: colors[0].withOpacity(0.45), width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: colors),
                            ),
                            child: Center(
                              child: Text('${i + 1}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(bug['bug_name'] ?? 'Bug',
                              style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: () => setState(() => _selectedBugs.removeAt(i)),
                            child: Icon(Icons.close,
                                color: _textSecondary, size: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Text('Tahan & geser untuk ubah urutan',
                style: TextStyle(
                    color: _textSecondary.withOpacity(0.4),
                    fontSize: 9.5,
                    letterSpacing: 0.3)),
          ],

          const SizedBox(height: 12),
          GestureDetector(
            onTap: _openBugPicker,
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _accentColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: _accentColor, size: 17),
                  const SizedBox(width: 7),
                  Text('Tambah Payload',
                      style: TextStyle(
                        fontFamily: 'Debrosee',
                        color: _accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── config row ────────────────────────────────────────────────────────────

  Widget _buildConfigRow() {
    return Row(
      children: [
        Expanded(
          child: _buildConfigTile(
            label: 'DELAY',
            sub: 'Interval (ms)',
            controller: _delayController,
            colors: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
            icon: Icons.timer_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildConfigTile(
            label: 'COUNT',
            sub: 'Pengulangan',
            controller: _countController,
            colors: const [Color(0xFF06D6A0), Color(0xFF4CC9F0)],
            icon: Icons.repeat_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildConfigTile({
    required String label,
    required String sub,
    required TextEditingController controller,
    required List<Color> colors,
    required IconData icon,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors[0].withOpacity(0.14),
                colors[1].withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors[0].withOpacity(0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: colors[0], size: 15),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontFamily: 'Debrosee',
                      color: colors[0],
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    )),
              ]),
              Text(sub,
                  style: TextStyle(color: _textSecondary, fontSize: 10)),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(
                  color: colors[0],
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
                cursorColor: colors[0],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── send button ───────────────────────────────────────────────────────────

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: _isSending ? null : _sendSequentialPayload,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) => Transform.scale(
          scale: _isSending ? 1.0 : _pulseAnimation.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: _isSending
                    ? [
                        _accentColor.withOpacity(0.35),
                        _accentSoft.withOpacity(0.35),
                      ]
                    : [_accentColor, _accentSoft],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isSending
                  ? []
                  : [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.4),
                        blurRadius: 22,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _isSending
                    ? const Row(
                        key: ValueKey('loading'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('MENGIRIM...',
                              style: TextStyle(
                                fontFamily: 'Debrosee',
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                              )),
                        ],
                      )
                    : const Row(
                        key: ValueKey('idle'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rocket_launch_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Text('KIRIM PAYLOAD',
                              style: TextStyle(
                                fontFamily: 'Debrosee',
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              )),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── status bar ────────────────────────────────────────────────────────────

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _cardBorder.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isSending
                    ? [_warningColor, const Color(0xFFFFB347)]
                    : _selectedBugs.isEmpty
                        ? [_textSecondary, _textSecondary]
                        : [_successColor, _accentColor],
              ),
              boxShadow: !_isSending && _selectedBugs.isNotEmpty
                  ? [
                      BoxShadow(
                          color: _successColor.withOpacity(0.5), blurRadius: 6)
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isSending
                  ? 'Mengirim payload...'
                  : _selectedBugs.isEmpty
                      ? 'Belum ada bug dipilih'
                      : '${_selectedBugs.length} bug  •  ${_delayController.text}ms  •  ${_countController.text}x',
              style: TextStyle(
                  color: _textSecondary, fontSize: 11.5, letterSpacing: 0.3),
            ),
          ),
          if (_selectedBugs.isNotEmpty && !_isSending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _accentColor.withOpacity(0.2)),
              ),
              child: Text('READY',
                  style: TextStyle(
                    fontFamily: 'Debrosee',
                    color: _accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  )),
            ),
        ],
      ),
    );
  }

  // ─── glass helpers ─────────────────────────────────────────────────────────

  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Bug Picker Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _BugPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> allBugs;
  final List<Map<String, dynamic>> selectedBugs;
  final List<Color> Function(int) bugGradient;
  final void Function(Map<String, dynamic>, int) onAdd;
  final void Function(String) onRemove;

  const _BugPickerSheet({
    required this.allBugs,
    required this.selectedBugs,
    required this.bugGradient,
    required this.onAdd,
    required this.onRemove,
  });

  static const Color _cardColor      = Color(0xFF0E1628);
  static const Color _cardBorder     = Color(0xFF1E2D4A);
  static const Color _accentColor    = Color(0xFF00D4FF);
  static const Color _textPrimary    = Color(0xFFEEF2FF);
  static const Color _textSecondary  = Color(0xFF8B9BBE);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: _accentColor.withOpacity(0.12), blurRadius: 40, spreadRadius: 2),
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 60,
              offset: const Offset(0, 20)),
        ],
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentColor.withOpacity(0.1),
                    border: Border.all(color: _accentColor.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.bug_report_rounded, color: _accentColor, size: 13),
                ),
                const SizedBox(width: 10),
                const Text('PILIH PAYLOAD',
                    style: TextStyle(
                      fontFamily: 'Debrosee',
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    )),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, color: _textSecondary, size: 20),
                ),
              ],
            ),
          ),
          const Divider(color: _cardBorder, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: allBugs.length,
              itemBuilder: (ctx, i) {
                final bug = allBugs[i];
                final isSelected =
                    selectedBugs.any((s) => s['bug_id'] == bug['bug_id']);
                final colors = bugGradient(i);
                return GestureDetector(
                  onTap: () {
                    if (isSelected) {
                      onRemove(bug['bug_id']);
                    } else {
                      onAdd(bug, i);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [
                                colors[0].withOpacity(0.18),
                                colors[1].withOpacity(0.06),
                              ]
                            : [
                                Colors.white.withOpacity(0.04),
                                Colors.white.withOpacity(0.02),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? colors[0].withOpacity(0.45)
                            : _cardBorder,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: colors,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.security_rounded,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bug['bug_name'] ?? 'Unknown',
                                  style: TextStyle(
                                    color: isSelected ? _textPrimary : _textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  )),
                              Text(bug['bug_id'] ?? '',
                                  style: TextStyle(
                                    color: _textSecondary.withOpacity(0.6),
                                    fontSize: 10,
                                    fontFamily: 'RobotoMono',
                                  )),
                            ],
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isSelected
                              ? Container(
                                  key: const ValueKey('check'),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: colors),
                                    boxShadow: [
                                      BoxShadow(
                                          color: colors[0].withOpacity(0.35),
                                          blurRadius: 8)
                                    ],
                                  ),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 13),
                                )
                              : Container(
                                  key: const ValueKey('add'),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.04),
                                    border: Border.all(
                                        color: _cardBorder.withOpacity(0.6)),
                                  ),
                                  child: Icon(Icons.add,
                                      color: _textSecondary, size: 13),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Success Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _SuccessSheet extends StatelessWidget {
  final String target;
  final int count;
  final int delay;
  final int bugCount;
  final VoidCallback onClose;

  const _SuccessSheet({
    required this.target,
    required this.count,
    required this.delay,
    required this.bugCount,
    required this.onClose,
  });

  static const Color _accentColor   = Color(0xFF00D4FF);
  static const Color _successColor  = Color(0xFF00E5A0);
  static const Color _cardColor     = Color(0xFF0E1628);
  static const Color _cardBorder    = Color(0xFF1E2D4A);
  static const Color _textPrimary   = Color(0xFFEEF2FF);
  static const Color _textSecondary = Color(0xFF8B9BBE);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _successColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _successColor.withOpacity(0.18),
              blurRadius: 40,
              spreadRadius: 3),
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 60,
              offset: const Offset(0, 20)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_successColor, _accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                    color: _successColor.withOpacity(0.4),
                    blurRadius: 28,
                    spreadRadius: 4)
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
          ),
          const SizedBox(height: 20),
          const Text('PAYLOAD TERKIRIM',
              style: TextStyle(
                fontFamily: 'Debrosee',
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              )),
          const SizedBox(height: 5),
          Text('Sekuens berhasil dikirim',
              style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _cardBorder),
            ),
            child: Column(children: [
              _infoRow(Icons.phone_iphone_rounded, 'Target', target),
              _infoRow(Icons.bug_report_rounded, 'Payload', '$bugCount bug'),
              _infoRow(Icons.repeat_rounded, 'Ulangan', '${count}x'),
              _infoRow(Icons.timer_outlined, 'Interval', '${delay}ms'),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: _successColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('SELESAI',
                  style: TextStyle(
                    fontFamily: 'Debrosee',
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  )),
            ),
          ),
          const SizedBox(height: 8),
          Text('© Apk OTAX Bug',
              style: TextStyle(
                  color: _textSecondary.withOpacity(0.3),
                  fontSize: 10,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _successColor.withOpacity(0.07),
            ),
            child: Icon(icon, color: _successColor, size: 12),
          ),
          const SizedBox(width: 11),
          Expanded(
              child: Text(label,
                  style: TextStyle(color: _textSecondary, fontSize: 12.5))),
          Text(value,
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
