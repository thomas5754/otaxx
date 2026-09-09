import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:math';
import 'custom_payload.dart';
import 'main.dart';
import 'bug_sender.dart';

class HomePage extends StatefulWidget {
  final String username;
  final String password;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final String role;
  final String expiredDate;

  const HomePage({
    super.key,
    required this.username,
    required this.password,
    required this.sessionKey,
    required this.listBug,
    required this.role,
    required this.expiredDate,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final TextEditingController targetController = TextEditingController();
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _shimmerAnimation;

  String selectedBugId = "";
  bool _isSending = false;
  String? _responseMessage;
  String? currentFlag;

  // ── Sender System ──────────────────────────────────────────────
  String _senderType = 'pribadi';
  bool _canUseGlobal = false;
  bool _hasOwnSender = false;
  int _globalOnlineCount = 0;
  int _globalAttemptsLeft = 999;
  int _globalMaxAttempts = 0;

  static const _globalRoles = ['FULLUP', 'RESELLER', 'PT', 'TK', 'OWNER', 'KINGZ'];
  static const _maxGlobalMap = {
    'FULLUP': 3, 'RESELLER': 5, 'PT': 6,
    'TK': 8, 'OWNER': 10, 'KINGZ': 0,
  };

  // Bug yang diizinkan pakai sender global (sama dengan GLOBAL_ALLOWED_BUGS di backend)
  static const _globalAllowedBugs = ['cspam', 'ios_invis'];

  /// Daftar bug yang ditampilkan sesuai sender yang dipilih
  List<Map<String, dynamic>> get _visibleBugs => _senderType == 'global'
      ? widget.listBug
          .where((b) => _globalAllowedBugs.contains(b['bug_id']))
          .toList()
      : widget.listBug;

  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  final Color _primaryColor = const Color(0xFF050810);
  final Color _secondaryColor = const Color(0xFF0D1421);
  final Color _accentColor = const Color(0xFF00D4FF);
  final Color _accentSoft = const Color(0xFF0099CC);
  final Color _successColor = const Color(0xFF00E5A0);
  final Color _warningColor = const Color(0xFFFFB547);
  final Color _dangerColor = const Color(0xFFFF4D6A);
  final Color _textPrimary = const Color(0xFFEEF2FF);
  final Color _textSecondary = const Color(0xFF8B9BBE);
  final Color _cardColor = const Color(0xFF0E1628);
  final Color _cardBorder = const Color(0xFF1E2D4A);

  final Map<String, String> countryFlags = {
    '1': '🇺🇸',
    '7': '🇷🇺',
    '20': '🇪🇬',
    '27': '🇿🇦',
    '30': '🇬🇷',
    '31': '🇳🇱',
    '32': '🇧🇪',
    '33': '🇫🇷',
    '34': '🇪🇸',
    '36': '🇭🇺',
    '39': '🇮🇹',
    '40': '🇷🇴',
    '41': '🇨🇭',
    '43': '🇦🇹',
    '44': '🇬🇧',
    '45': '🇩🇰',
    '46': '🇸🇪',
    '47': '🇳🇴',
    '48': '🇵🇱',
    '49': '🇩🇪',
    '51': '🇵🇪',
    '52': '🇲🇽',
    '53': '🇨🇺',
    '54': '🇦🇷',
    '55': '🇧🇷',
    '56': '🇨🇱',
    '57': '🇨🇴',
    '58': '🇻🇪',
    '60': '🇲🇾',
    '61': '🇦🇺',
    '62': '🇮🇩',
    '63': '🇵🇭',
    '64': '🇳🇿',
    '65': '🇸🇬',
    '66': '🇹🇭',
    '81': '🇯🇵',
    '82': '🇰🇷',
    '84': '🇻🇳',
    '86': '🇨🇳',
    '90': '🇹🇷',
    '91': '🇮🇳',
    '92': '🇵🇰',
    '93': '🇦🇫',
    '94': '🇱🇰',
    '95': '🇲🇲',
    '98': '🇮🇷',
    '212': '🇲🇦',
    '213': '🇩🇿',
    '216': '🇹🇳',
    '218': '🇱🇾',
    '220': '🇬🇲',
    '221': '🇸🇳',
    '222': '🇲🇷',
    '223': '🇲🇱',
    '224': '🇬🇳',
    '225': '🇨🇮',
    '226': '🇧🇫',
    '227': '🇳🇪',
    '228': '🇹🇬',
    '229': '🇧🇯',
    '230': '🇲🇺',
    '231': '🇱🇷',
    '232': '🇸🇱',
    '233': '🇬🇭',
    '234': '🇳🇬',
    '235': '🇹🇩',
    '236': '🇨🇫',
    '237': '🇨🇲',
    '238': '🇨🇻',
    '239': '🇸🇹',
    '240': '🇬🇶',
    '241': '🇬🇦',
    '242': '🇨🇬',
    '243': '🇨🇩',
    '244': '🇦🇴',
    '245': '🇬🇼',
    '246': '🇮🇴',
    '248': '🇸🇨',
    '249': '🇸🇩',
    '250': '🇷🇼',
    '251': '🇪🇹',
    '252': '🇸🇴',
    '253': '🇩🇯',
    '254': '🇰🇪',
    '255': '🇹🇿',
    '256': '🇺🇬',
    '257': '🇧🇮',
    '258': '🇲🇿',
    '260': '🇿🇲',
    '261': '🇲🇬',
    '262': '🇷🇪',
    '263': '🇿🇼',
    '264': '🇳🇦',
    '265': '🇲🇼',
    '266': '🇱🇸',
    '267': '🇧🇼',
    '268': '🇸🇿',
    '269': '🇰🇲',
    '290': '🇸🇭',
    '291': '🇪🇷',
    '297': '🇦🇼',
    '298': '🇫🇴',
    '299': '🇬🇱',
    '350': '🇬🇮',
    '351': '🇵🇹',
    '352': '🇱🇺',
    '353': '🇮🇪',
    '354': '🇮🇸',
    '355': '🇦🇱',
    '356': '🇲🇹',
    '357': '🇨🇾',
    '358': '🇫🇮',
    '359': '🇧🇬',
    '370': '🇱🇹',
    '371': '🇱🇻',
    '372': '🇪🇪',
    '373': '🇲🇩',
    '374': '🇦🇲',
    '375': '🇧🇾',
    '376': '🇦🇩',
    '377': '🇲🇨',
    '378': '🇸🇲',
    '380': '🇺🇦',
    '381': '🇷🇸',
    '382': '🇲🇪',
    '385': '🇭🇷',
    '386': '🇸🇮',
    '387': '🇧🇦',
    '389': '🇲🇰',
    '420': '🇨🇿',
    '421': '🇸🇰',
    '423': '🇱🇮',
    '500': '🇫🇰',
    '501': '🇧🇿',
    '502': '🇬🇹',
    '503': '🇸🇻',
    '504': '🇭🇳',
    '505': '🇳🇮',
    '506': '🇨🇷',
    '507': '🇵🇦',
    '508': '🇵🇲',
    '509': '🇭🇹',
    '591': '🇧🇴',
    '592': '🇬🇾',
    '593': '🇪🇨',
    '594': '🇬🇫',
    '595': '🇵🇾',
    '596': '🇲🇶',
    '597': '🇸🇷',
    '598': '🇺🇾',
    '852': '🇭🇰',
    '853': '🇲🇴',
    '855': '🇰🇭',
    '856': '🇱🇦',
    '880': '🇧🇩',
    '886': '🇹🇼',
    '960': '🇲🇻',
    '961': '🇱🇧',
    '962': '🇯🇴',
    '963': '🇸🇾',
    '964': '🇮🇶',
    '965': '🇰🇼',
    '966': '🇸🇦',
    '967': '🇾🇪',
    '968': '🇴🇲',
    '970': '🇵🇸',
    '971': '🇦🇪',
    '972': '🇮🇱',
    '973': '🇧🇭',
    '974': '🇶🇦',
    '975': '🇧🇹',
    '976': '🇲🇳',
    '977': '🇳🇵',
    '992': '🇹🇯',
    '993': '🇹🇲',
    '994': '🇦🇿',
    '995': '🇬🇪',
    '996': '🇰🇬',
    '998': '🇺🇿',
  };

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (widget.listBug.isNotEmpty) {
      selectedBugId = widget.listBug[0]['bug_id'];
    }
    _initializeVideoPlayer();

    // Set dari role langsung — tidak tunggu async
    _canUseGlobal    = _globalRoles.contains(widget.role);
    _globalMaxAttempts = _maxGlobalMap[widget.role] ?? 0;
    _globalAttemptsLeft = _globalMaxAttempts == 0 ? 999 : _globalMaxAttempts;
    _senderType = 'pribadi';

    // Load online count dari server
    _loadSenderInfo();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _floatAnimation = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.asset(
        'assets/videos/otaxai.mp4');

    _videoController.initialize().then((_) {
      setState(() {
        _videoController.setVolume(0);
        _videoController.setLooping(true);
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: true,
          showControls: false,
          autoInitialize: true,
          errorBuilder: (context, errorMessage) {
            return _buildVideoFallback();
          },
        );
        _isVideoInitialized = true;
        _videoController.play();
      });
    }).catchError((error) {
      setState(() {
        _isVideoInitialized = false;
      });
    });
  }

  Widget _buildVideoFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1B2A),
            _primaryColor,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    _accentColor.withOpacity(0.2),
                    _accentColor.withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: _accentColor.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.15),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: _accentColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "OTAX BUG",
              style: TextStyle(
                fontFamily: 'Debrosee',
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    targetController.dispose();
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  String? detectFlag(String input) {
    final clean = input.replaceAll(RegExp(r'\D'), '');
    final codes = countryFlags.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final code in codes) {
      if (clean.startsWith(code)) return countryFlags[code];
    }
    return null;
  }

  String? formatPhoneNumber(String input) {
    final clean = input.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 8) return null;
    return '+$clean';
  }

  // Load info sender dari server (online count dll)
  Future<void> _loadSenderInfo() async {
    try {
      final res = await http.get(
        Uri.parse("http://127.0.0.1:4113/mySender?key=${widget.sessionKey}"),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (data["valid"] != true) return;
      if (!mounted) return;

      final ownConns = data["connections"] as List? ?? [];
      final svrMax   = (data["maxGlobalDaily"] ?? 0) as int;

      setState(() {
        _hasOwnSender      = ownConns.isNotEmpty;
        _canUseGlobal      = _globalRoles.contains(widget.role);
        _globalOnlineCount = (data["globalSenderCount"] ?? 0) as int;
        _globalMaxAttempts = svrMax;
        _globalAttemptsLeft = svrMax == 0 ? 999 : (data["attemptsLeft"] ?? svrMax) as int;
      });
    } catch (_) {}
  }

  Future<void> _sendBug() async {
    // Cek apakah ada sender tersedia
    final bool hasSender = _hasOwnSender || (_canUseGlobal && _globalOnlineCount > 0);

    if (!hasSender) {
      _showProfessionalDialog(
        "Sender Required",
        _canUseGlobal
          ? "Tidak ada sender aktif. Sender global kosong. Tunggu sender global atau tambah sender pribadi."
          : "Kamu belum punya sender. Tap tombol di bawah untuk menambahkan sender.",
        Icons.wifi_find_rounded,
        _warningColor,
        buttonLabel: _canUseGlobal ? 'MENGERTI' : 'TAMBAH SENDER',
        onPressed: _canUseGlobal ? null : () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => BugSenderPage(
              sessionKey: widget.sessionKey,
              username: widget.username,
              role: widget.role,
            ),
          ));
        },
      );
      return;
    }

    // Validasi sender yang dipilih
    if (_senderType == 'pribadi' && !_hasOwnSender) {
      _showProfessionalDialog(
        "Sender Pribadi Kosong",
        "Kamu belum punya sender pribadi. Tambah sender dulu atau pilih Global.",
        Icons.person_off_rounded,
        _warningColor,
        buttonLabel: 'TAMBAH SENDER',
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => BugSenderPage(
              sessionKey: widget.sessionKey,
              username: widget.username,
              role: widget.role,
            ),
          ));
        },
      );
      return;
    }

    if (_senderType == 'global' && _globalMaxAttempts > 0 && _globalAttemptsLeft <= 0) {
      _showResultDialog(
        "Batas Global Habis",
        "Batas kirim sender global hari ini habis ($_globalMaxAttempts x). Reset besok atau pakai pribadi.",
        Icons.block_rounded,
        _dangerColor,
        false,
      );
      return;
    }

    final rawInput = targetController.text.trim();
    final target = formatPhoneNumber(rawInput);

    if (target == null) {
      _showProfessionalDialog(
        "Format Nomor Salah",
        "Gunakan format internasional:\n• 62xxx (Indonesia)\n• 1xxx (USA)\n• 44xxx (UK)\n\nJangan pakai 08xxx atau 0xxx",
        Icons.format_list_numbered_rounded,
        _dangerColor,
      );
      return;
    }

    setState(() => _isSending = true);
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final res = await http.get(Uri.parse(
        "http://127.0.0.1:4113/sendBug?key=${widget.sessionKey}&target=$target&bug=$selectedBugId&sender_type=$_senderType"))
        .timeout(const Duration(seconds: 30));

      final data = jsonDecode(res.body);

      if (data["rateLimit"] == true) {
        _showResultDialog(
          "Rate Limit",
          "Terlalu banyak request. Tunggu 1 detik lalu coba lagi.",
          Icons.timer_rounded, _warningColor, false);
      } else if (data["limitReached"] == true) {
        _showResultDialog(
          "Batas Global Habis",
          data["message"] ?? "Batas sender global hari ini habis.",
          Icons.block_rounded, _dangerColor, false);
      } else if (data["cooldown"] == true) {
        final wait = data["wait"] ?? 0;
        _showResultDialog(
          "Cooldown Aktif",
          "Tunggu ${wait}s sebelum kirim lagi.",
          Icons.timer_rounded, _warningColor, false);
      } else if (data["valid"] == false) {
        _showResultDialog(
          "Session Expired",
          "Sesi habis. Login ulang.",
          Icons.key_off_rounded, _dangerColor, false);
      } else if (data["sended"] == false) {
        _showResultDialog(
          "Gagal",
          data["message"] ?? "Server maintenance.",
          Icons.engineering_rounded, Colors.blueGrey, false);
      } else {
        if (_senderType == 'global' && data["attemptsLeft"] != null) {
          setState(() {
            _globalAttemptsLeft = (data["attemptsLeft"] as num).toInt();
          });
        }
        _showSuccessDialog(target);
        targetController.clear();
        setState(() => currentFlag = null);
      }
    } catch (e) {
      _showResultDialog(
        "Koneksi Error",
        "Gagal hubungi server. Cek koneksi internet.",
        Icons.error_outline_rounded, _dangerColor, false);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showProfessionalDialog(
      String title, String message, IconData icon, Color color, {
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
                      style: TextStyle(
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

  void _showResultDialog(
    String title,
    String message,
    IconData icon,
    Color color,
    bool isSuccess,
  ) {
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _cardColor.withOpacity(0.97),
                _cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 50,
                offset: const Offset(0, 25),
              ),
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 24,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.18),
                        color.withOpacity(0.06),
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
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ).copyWith(
                      overlayColor: MaterialStateProperty.all(
                        Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Text(
                      'LANJUTKAN',
                      style: TextStyle(
                        fontFamily: 'Debrosee',
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        fontSize: 15,
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

  void _showSuccessDialog(String target) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(40),
        child: Container(
          width: 380,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _cardColor.withOpacity(0.97),
                _cardColor,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _successColor.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _successColor.withOpacity(0.2),
                blurRadius: 40,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 60,
                offset: const Offset(0, 25),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _successColor,
                        _successColor.withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _successColor.withOpacity(0.4),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "Bug Terkirim",
                  style: TextStyle(
                    fontFamily: 'Debrosee',
                    color: _textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Bug berhasil dikirim ke target:",
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _successColor.withOpacity(0.08),
                        _successColor.withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _successColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _successColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.phone_iphone_rounded,
                          color: _successColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          target,
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontFamily: 'RobotoMono',
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _successColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ).copyWith(
                      overlayColor: MaterialStateProperty.all(
                        Colors.white.withOpacity(0.15),
                      ),
                      elevation: MaterialStateProperty.all(0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SELESAI',
                          style: TextStyle(
                            fontFamily: 'Debrosee',
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "© Apk OTAX Bug",
                  style: TextStyle(
                    color: _textSecondary.withOpacity(0.4),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderPanel() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 248,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _accentColor.withOpacity(0.25),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accentColor.withOpacity(0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accentColor.withOpacity(0.25),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.username,
                              style: TextStyle(
                                fontFamily: 'Debrosee',
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.6,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [_accentColor, _accentSoft],
                              ).createShader(bounds),
                              child: Text(
                                widget.role.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _accentColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.timer_outlined, color: _accentColor, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              widget.expiredDate,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(Icons.bug_report_rounded, "${widget.listBug.length}", "Total Bugs", _accentColor),
                            Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
                            _buildStatItem(Icons.bolt_rounded, "GACOR", "Success Rate", _successColor),
                            Container(width: 1, height: 36, color: Colors.white.withOpacity(0.1)),
                            _buildStatItem(Icons.verified_rounded, "ACTIVE", "Status", _successColor),
                          ],
                        ),
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

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 8,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Debrosee',
            color: _textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInputPanel() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.07),
                  Colors.white.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputSection(
              title: "NOMOR TARGET",
              icon: Icons.phone_android_rounded,
              iconColor: _accentColor,
              child: Container(
                decoration: BoxDecoration(
                  color: _secondaryColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _cardBorder,
                  ),
                ),
                child: TextField(
                  controller: targetController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  cursorColor: _accentColor,
                  cursorHeight: 20,
                  onChanged: (value) {
                    setState(() {
                      currentFlag = detectFlag(value);
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "62xxxxxxxxxx",
                    hintStyle: TextStyle(
                      color: _textSecondary.withOpacity(0.5),
                      fontSize: 14,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: currentFlag != null
                          ? Text(
                              currentFlag!,
                              style: const TextStyle(fontSize: 22),
                            )
                          : Icon(
                              Icons.public_rounded,
                              color: _textSecondary.withOpacity(0.5),
                              size: 20,
                            ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            _buildInputSection(
              title: "PILIH BUG",
              icon: Icons.bug_report_rounded,
              iconColor: _dangerColor,
              child: Column(
                children: [
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _visibleBugs.length,
                      itemBuilder: (context, index) {
                        final bug = _visibleBugs[index];
                        final isSelected = selectedBugId == bug['bug_id'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedBugId = bug['bug_id'];
                            });
                          },
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_floatController, _shimmerController]),
                            builder: (context, child) {
                              final floatOffset = isSelected ? _floatAnimation.value : 0.0;
                              return Transform.translate(
                                offset: Offset(0, floatOffset),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  width: 180,
                                  margin: EdgeInsets.only(
                                    right: index < _visibleBugs.length - 1 ? 12 : 0,
                                    top: 6,
                                    bottom: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              _accentColor.withOpacity(0.18),
                                              _accentColor.withOpacity(0.06),
                                              _accentSoft.withOpacity(0.12),
                                            ],
                                          )
                                        : LinearGradient(
                                            colors: [
                                              _secondaryColor,
                                              _secondaryColor.withOpacity(0.85),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? _accentColor.withOpacity(
                                              0.4 + 0.3 * ((_shimmerAnimation.value.clamp(-1.0, 1.0) + 1) / 2))
                                          : _cardBorder,
                                      width: isSelected ? 1.8 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: _accentColor.withOpacity(
                                                  0.12 + 0.18 * ((_shimmerAnimation.value.clamp(-1.0, 1.0) + 1) / 2)),
                                              blurRadius: 20 + 8 * ((_shimmerAnimation.value.clamp(-1.0, 1.0) + 1) / 2),
                                              spreadRadius: 1,
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: Stack(
                                      children: [
                                        // Shimmer sweep on selected
                                        if (isSelected)
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: AnimatedBuilder(
                                                animation: _shimmerController,
                                                builder: (_, __) => Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      stops: [
                                                        (_shimmerAnimation.value - 0.5).clamp(0.0, 1.0),
                                                        _shimmerAnimation.value.clamp(0.0, 1.0),
                                                        (_shimmerAnimation.value + 0.5).clamp(0.0, 1.0),
                                                      ],
                                                      colors: [
                                                        Colors.transparent,
                                                        Colors.white.withOpacity(0.06),
                                                        Colors.transparent,
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  AnimatedContainer(
                                                    duration: const Duration(milliseconds: 300),
                                                    width: 34,
                                                    height: 34,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: isSelected
                                                          ? LinearGradient(
                                                              colors: [
                                                                _accentColor.withOpacity(0.3),
                                                                _accentColor.withOpacity(0.1),
                                                              ],
                                                            )
                                                          : null,
                                                      color: isSelected ? null : Colors.white.withOpacity(0.06),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? _accentColor.withOpacity(0.6)
                                                            : Colors.transparent,
                                                        width: 1.2,
                                                      ),
                                                      boxShadow: isSelected
                                                          ? [
                                                              BoxShadow(
                                                                color: _accentColor.withOpacity(0.3),
                                                                blurRadius: 8,
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                    child: Icon(
                                                      Icons.security_rounded,
                                                      color: isSelected ? _accentColor : _textSecondary,
                                                      size: 16,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  AnimatedSwitcher(
                                                    duration: const Duration(milliseconds: 300),
                                                    transitionBuilder: (child, animation) =>
                                                        ScaleTransition(scale: animation, child: child),
                                                    child: isSelected
                                                        ? Container(
                                                            key: const ValueKey('check'),
                                                            width: 22,
                                                            height: 22,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              gradient: LinearGradient(
                                                                colors: [_successColor, _successColor.withOpacity(0.7)],
                                                              ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: _successColor.withOpacity(0.45),
                                                                  blurRadius: 8,
                                                                  spreadRadius: 1,
                                                                ),
                                                              ],
                                                            ),
                                                            child: const Icon(
                                                              Icons.check,
                                                              size: 13,
                                                              color: Colors.white,
                                                            ),
                                                          )
                                                        : const SizedBox.shrink(key: ValueKey('empty')),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    bug['bug_name'] ?? 'Unknown',
                                                    style: TextStyle(
                                                      color: isSelected ? _textPrimary : _textSecondary,
                                                      fontSize: 13.5,
                                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                      letterSpacing: 0.2,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? _accentColor.withOpacity(0.1)
                                                          : Colors.black.withOpacity(0.3),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? _accentColor.withOpacity(0.25)
                                                            : Colors.transparent,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      bug['bug_id'] ?? 'ID',
                                                      style: TextStyle(
                                                        color: isSelected ? _accentColor : _textSecondary,
                                                        fontSize: 10.5,
                                                        fontFamily: 'RobotoMono',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  if (_visibleBugs.length > 1) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _visibleBugs.length,
                        (index) {
                          final bug = _visibleBugs[index];
                          final isSelected = selectedBugId == bug['bug_id'];
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: isSelected ? 20 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [_accentColor, _accentSoft],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
  }) {
    final color = iconColor ?? _accentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.12),
                border: Border.all(
                  color: color.withOpacity(0.25),
                ),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Debrosee',
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  // Widget pilih sender — muncul untuk FULLUP ke atas
  Widget _buildSenderSelector() {
    if (!_canUseGlobal) return const SizedBox.shrink();

    final bool unlimited    = _globalMaxAttempts == 0;
    final bool globalAvail  = _globalOnlineCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2D4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D4FF).withOpacity(0.12),
                border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00D4FF), size: 14),
            ),
            const SizedBox(width: 8),
            const Text('PILIH SENDER', style: TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold,
              letterSpacing: 1.0, fontFamily: 'Debrosee')),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: globalAvail
                  ? const Color(0xFF00E5A0).withOpacity(0.12)
                  : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: globalAvail
                    ? const Color(0xFF00E5A0).withOpacity(0.4)
                    : Colors.red.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 5, height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: globalAvail ? const Color(0xFF00E5A0) : Colors.red)),
                const SizedBox(width: 4),
                Text(
                  globalAvail ? '$_globalOnlineCount sender online' : 'Global offline',
                  style: TextStyle(
                    color: globalAvail ? const Color(0xFF00E5A0) : Colors.red,
                    fontSize: 10)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            // Tombol Pribadi
            Expanded(child: GestureDetector(
              onTap: () => setState(() => _senderType = 'pribadi'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: _senderType == 'pribadi'
                    ? const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF0099BB)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                  color: _senderType == 'pribadi' ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _senderType == 'pribadi'
                      ? Colors.transparent : Colors.white.withOpacity(0.1)),
                  boxShadow: _senderType == 'pribadi' ? [
                    BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4))] : [],
                ),
                child: Column(children: [
                  Icon(Icons.person_rounded, size: 20,
                    color: _senderType == 'pribadi' ? Colors.white : Colors.white38),
                  const SizedBox(height: 4),
                  Text('Pribadi', style: TextStyle(
                    color: _senderType == 'pribadi' ? Colors.white : Colors.white38,
                    fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(_hasOwnSender ? '✓ Aktif' : '✗ Kosong',
                    style: TextStyle(
                      color: _hasOwnSender
                        ? (_senderType == 'pribadi' ? Colors.white70 : Colors.white24)
                        : Colors.redAccent.withOpacity(0.8),
                      fontSize: 9)),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            // Tombol Global
            Expanded(child: GestureDetector(
              onTap: globalAvail ? () {
                setState(() {
                  _senderType = 'global';
                  // Jika bug aktif tidak support global, pindah ke bug pertama yg allowed
                  if (!_globalAllowedBugs.contains(selectedBugId)) {
                    final first = widget.listBug.firstWhere(
                      (b) => _globalAllowedBugs.contains(b['bug_id']),
                      orElse: () => widget.listBug.first,
                    );
                    selectedBugId = first['bug_id'];
                  }
                });
              } : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: _senderType == 'global'
                    ? const LinearGradient(
                        colors: [Color(0xFF00E5A0), Color(0xFF06D6A0)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                  color: _senderType == 'global' ? null : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _senderType == 'global'
                      ? Colors.transparent : Colors.white.withOpacity(0.1)),
                  boxShadow: _senderType == 'global' ? [
                    BoxShadow(color: const Color(0xFF00E5A0).withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4))] : [],
                ),
                child: Stack(children: [
                  Center(child: Column(children: [
                    Icon(Icons.public_rounded, size: 20,
                      color: !globalAvail ? Colors.white12
                        : _senderType == 'global' ? Colors.white : Colors.white38),
                    const SizedBox(height: 4),
                    Text('Global', style: TextStyle(
                      color: !globalAvail ? Colors.white12
                        : _senderType == 'global' ? Colors.white : Colors.white38,
                      fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(!globalAvail ? 'Offline' : '$_globalOnlineCount sender',
                      style: TextStyle(
                        color: !globalAvail ? Colors.white12
                          : _senderType == 'global' ? Colors.white70 : Colors.white24,
                        fontSize: 9)),
                  ])),
                  if (!globalAvail)
                    Positioned.fill(child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(13)))),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 11,
              color: Colors.white.withOpacity(0.35)),
            const SizedBox(width: 5),
            Flexible(child: Text(
              unlimited
                ? 'Sender global: unlimited ♾ (${widget.role})'
                : 'Sisa kirim global hari ini: $_globalAttemptsLeft / $_globalMaxAttempts',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10))),
          ]),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _isSending ? null : _sendBug,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 56,
            decoration: BoxDecoration(
              gradient: _isSending
                  ? LinearGradient(
                      colors: [
                        _accentColor.withOpacity(0.4),
                        _accentSoft.withOpacity(0.4),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accentColor, _accentSoft],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isSending
                  ? []
                  : [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isSending
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "MENGIRIM...",
                            style: TextStyle(
                              fontFamily: 'Debrosee',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "KIRIM BUG",
                            style: TextStyle(
                              fontFamily: 'Debrosee',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponseMessage() {
    if (_responseMessage == null) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _successColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _successColor.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _successColor,
                boxShadow: [
                  BoxShadow(
                    color: _successColor.withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "SUKSES",
                    style: TextStyle(
                      fontFamily: 'Debrosee',
                      color: _textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Bug berhasil dikirim",
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: _textSecondary,
              onPressed: () {
                setState(() {
                  _responseMessage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: Stack(
        children: [
          // ── Full-screen video background ──
          Positioned.fill(
            child: _isVideoInitialized && _chewieController != null
                ? Chewie(controller: _chewieController!)
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [const Color(0xFF0D1B2A), _primaryColor],
                      ),
                    ),
                  ),
          ),
          // Dark overlay so UI stays legible
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.black.withOpacity(0.75),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, -0.8),
                  radius: 1.4,
                  colors: [
                    _accentColor.withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: _accentColor.withOpacity(0.1),
                            border: Border.all(
                              color: _accentColor.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _accentColor.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            color: _accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [_textPrimary, _accentColor],
                            stops: const [0.4, 1.0],
                          ).createShader(bounds),
                          child: Text(
                            "OTAX BUG WHATSAPP",
                            style: TextStyle(
                              fontFamily: 'Debrosee',
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _accentColor.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            "v3.0",
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildHeaderPanel(),
                  const SizedBox(height: 20),
                  _buildInputPanel(),
                  const SizedBox(height: 20),
                  _buildSenderSelector(),
                  _buildSendButton(),
                  const SizedBox(height: 18),
                  _buildResponseMessage(),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              _textSecondary.withOpacity(0.6),
                              _accentColor.withOpacity(0.6),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            "OTAX TEAM",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "© 2026 OTAX Always For You",
                          style: TextStyle(
                            color: _textSecondary.withOpacity(0.3),
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
