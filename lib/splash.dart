import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dashboard_page.dart';

class SplashScreen extends StatefulWidget {
  final String username;
  final String password;
  final String role;
  final String expiredDate;
  final String sessionKey;
  final List<Map<String, dynamic>> listBug;
  final List<Map<String, dynamic>> listDoos;
  final List<dynamic> news;

  const SplashScreen({
    super.key,
    required this.username,
    required this.password,
    required this.role,
    required this.expiredDate,
    required this.sessionKey,
    required this.listBug,
    required this.listDoos,
    required this.news,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController? _videoController;
  late AnimationController _fadeController;
  late Animation<double> _textOpacityAnimation;
  bool _videoReady = false;
  bool _videoError = false;
  bool _skipPressed = false;

  Timer? _timeoutTimer;
  Timer? _checkTimer;

  // Warna disesuaikan dengan video Gemini (dark cinematic + cyan/teal accent)
  final Color _primaryColor = const Color(0xFF050810);
  final Color _textColor = const Color(0xFFEEF2FF);
  final Color _dimAccent = const Color(0xFF6B7280);
  final Color _accentColor = const Color(0xFF00D4FF);
  final Color _accentGlow = const Color(0xFF0099CC);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _textOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeController.forward();
    });

    _timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_videoReady && !_skipPressed) {
        _handleVideoTimeout();
      }
    });

    _initializeVideo();
  }

  void _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset(
          "assets/videos/otaxai.mp4");

      final initTimeout = Timer(const Duration(seconds: 2), () {
        if (mounted &&
            _videoController != null &&
            !_videoController!.value.isInitialized) {
          _handleVideoError();
        }
      });

      await _videoController!.initialize();
      initTimeout.cancel();

      if (!mounted) return;

      setState(() {
        _videoReady = true;
      });

      _videoController!.setLooping(false);
      _videoController!.setVolume(0.7);

      _startVideoCheckTimer();

      await _videoController!.play().catchError((e) {
        _handleVideoError();
      });

      _videoController!.addListener(() {
        if (!mounted) return;

        if (_videoController!.value.position >=
            _videoController!.value.duration) {
          if (_videoController!.value.duration > Duration.zero) {
            _navigateToDashboard();
          }
        }
      });
    } catch (e) {
      _handleVideoError();
    }
  }

  void _startVideoCheckTimer() {
    _checkTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_videoController == null ||
          !_videoController!.value.isInitialized) {
        return;
      }

      final currentPosition = _videoController!.value.position;
      final isPlaying = _videoController!.value.isPlaying;

      if (isPlaying && currentPosition.inMilliseconds > 0) {
        if (_lastPosition == currentPosition) {
          _stuckFrames++;
          if (_stuckFrames > 2) {
            timer.cancel();
            _handleVideoError();
          }
        } else {
          _lastPosition = currentPosition;
          _stuckFrames = 0;
        }
      }
    });
  }

  Duration _lastPosition = Duration.zero;
  int _stuckFrames = 0;

  void _handleVideoError() {
    if (!mounted || _skipPressed) return;

    setState(() {
      _videoError = true;
    });

    _timeoutTimer?.cancel();
    _checkTimer?.cancel();

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && !_skipPressed) {
        _navigateToDashboard();
      }
    });
  }

  void _handleVideoTimeout() {
    if (!mounted || _skipPressed) return;

    _timeoutTimer?.cancel();
    _checkTimer?.cancel();

    _navigateToDashboard();
  }

  void _navigateToDashboard() {
    if (_skipPressed) return;

    _skipPressed = true;

    _timeoutTimer?.cancel();
    _checkTimer?.cancel();

    if (_videoController != null && _videoController!.value.isInitialized) {
      _videoController!.pause();
      _videoController!.dispose();
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          username: widget.username,
          password: widget.password,
          role: widget.role,
          expiredDate: widget.expiredDate,
          sessionKey: widget.sessionKey,
          listBug: widget.listBug,
          listDoos: widget.listDoos,
          news: widget.news,
        ),
      ),
    );
  }

  void _skipVideo() {
    if (_skipPressed) return;

    _fadeController.reverse().then((_) {
      _navigateToDashboard();
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _checkTimer?.cancel();
    _fadeController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryColor,
      body: GestureDetector(
        onTap: _skipVideo,
        child: Stack(
          children: [
            // ── VIDEO / FALLBACK BACKGROUND ──────────────────────────────
            if (_videoReady && !_videoError && _videoController != null)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        const Color(0xFF0D1B2A),
                        _primaryColor,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accentColor.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity(0.08),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── DARK OVERLAY (lebih halus agar video tetap terlihat) ──────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                    ],
                    stops: const [0.0, 0.25, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // ── CENTER LOGO ───────────────────────────────────────────────
            Center(
              child: FadeTransition(
                opacity: _textOpacityAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Garis atas
                    Container(
                      width: 1,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _accentColor.withOpacity(0.7),
                          ],
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 28),
                    ),

                    // Nama aplikasi
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          _textColor,
                          _accentColor,
                          _textColor,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ).createShader(bounds),
                      child: Text(
                        "OTAX",
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          letterSpacing: 14,
                          height: 1.1,
                          fontFamily: 'Orbitron',
                          shadows: [
                            Shadow(
                              color: _accentColor.withOpacity(0.6),
                              blurRadius: 24,
                              offset: const Offset(0, 0),
                            ),
                            Shadow(
                              color: Colors.black.withOpacity(0.8),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Tagline
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 6),
                      child: Text(
                        "Hanya Untuk Bersenang - Senang",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w300,
                          color: _textColor.withOpacity(0.75),
                          letterSpacing: 2.5,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Orbitron',
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.9),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Garis bawah
                    Container(
                      width: 80,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            _accentColor.withOpacity(0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      margin: const EdgeInsets.only(top: 28),
                    ),
                  ],
                ),
              ),
            ),

            // ── SKIP BUTTON (kanan atas) ──────────────────────────────────
            Positioned(
              top: 44,
              right: 20,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _skipVideo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _accentColor.withOpacity(0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accentColor.withOpacity(0.15),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fast_forward_rounded,
                          color: _accentColor,
                          size: 15,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'LEWATI',
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.8,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── ERROR BANNER ──────────────────────────────────────────────
            if (_videoError)
              Positioned(
                top: 100,
                left: 24,
                right: 24,
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.orange, size: 15),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Video tidak tersedia, melanjutkan...",
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── BOTTOM INFO (loading + watermark) ────────────────────────
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _textOpacityAnimation,
                child: Column(
                  children: [
                    // Indikator loading (hanya saat video belum siap)
                    if (!_videoReady || _videoError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _videoError
                                    ? Colors.orange
                                    : _accentColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: (_videoError
                                            ? Colors.orange
                                            : _accentColor)
                                        .withOpacity(0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _videoError
                                  ? "Mode fallback aktif"
                                  : "Memuat...",
                              style: TextStyle(
                                fontSize: 10,
                                color: _textColor.withOpacity(0.55),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Hint klik
                    Text(
                      'Klik di mana saja untuk melanjutkan',
                      style: TextStyle(
                        color: _textColor.withOpacity(0.35),
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Watermark OTAX kecil
                    Text(
                      "OTAX",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w300,
                        color: _accentColor.withOpacity(0.3),
                        letterSpacing: 8,
                        fontFamily: 'Orbitron',
                        shadows: [
                          Shadow(
                            color: _accentColor.withOpacity(0.3),
                            blurRadius: 6,
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
      ),
    );
  }
}
