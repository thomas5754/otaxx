import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  // Ultra Premium Color Palette
  static const Color primaryColor = Color(0xFFB71C1C);
  static const Color accentGold = Color(0xFFD4AF37);
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color surfaceColor = Color(0xFF151515);
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color dividerColor = Color(0xFF2D2D2D);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoScale;
  late Animation<Offset> _titleSlide;
  late Animation<double> _cardOpacity;
  late Animation<double> _buttonSlide;

  @override
  void initState() {
    super.initState();

    // Initialize video
    _videoController = VideoPlayerController.asset("assets/videos/banner.mp4")
      ..initialize().then((_) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.setLooping(true);
        _videoController.setVolume(0);
        _videoController.play();
      });

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Staggered animations for smooth entrance
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.5, curve: Curves.elasticOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _cardOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeInOut),
      ),
    );

    _buttonSlide = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _videoController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $uri");
    }
  }
void _showError(String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Error'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: LandingPage.darkBackground,
      body: Container(
        height: screenHeight,
        child: Stack(
          children: [
            // Animated gradient background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.6),
                    radius: 1.2,
                    colors: [
                      primaryColor.withOpacity(0.05),
                      LandingPage.darkBackground,
                      LandingPage.darkBackground,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Subtle grid pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),

            // Main Content - Centered without scroll
            SafeArea(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 600,
                    maxHeight: screenHeight * 0.9,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Video Banner - Persegi Panjang
                      ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          width: 320,
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accentGold.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _isVideoInitialized
                                ? VideoPlayer(_videoController)
                                : Center(
                                    child: CircularProgressIndicator(
                                      color: accentGold,
                                      strokeWidth: 2,
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Animated Title
                      SlideTransition(
                        position: _titleSlide,
                        child: Column(
                          children: [
                            Text(
                              "OTAX",
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 64,
                                fontWeight: FontWeight.w300,
                                fontFamily: 'Inter',
                                letterSpacing: 8,
                                height: 0.9,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 140,
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withOpacity(0.8),
                                    accentGold.withOpacity(0.6),
                                    primaryColor.withOpacity(0.8),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "ALWAYS OTAX",
                              style: TextStyle(
                                color: accentGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Welcome Card with Glass Effect
                      FadeTransition(
                        opacity: _cardOpacity,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: dividerColor.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: accentGold,
                                size: 36,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "OTAX BUG",
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w300,
                                  fontFamily: 'Inter',
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Aplikasi dengan design elegant dan fitur terbaru. Pengembangan langsung oleh TEAM OTAX.",
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 14,
                                  height: 1.6,
                                  fontWeight: FontWeight.w300,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Action Buttons
                      AnimatedBuilder(
                        animation: _buttonSlide,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _buttonSlide.value),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            _ElevatedButton(
                              onPressed: () async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(),
    ),
  );

  if (baseUrl.isEmpty) {
    await loadConfig();
  }

  Navigator.pop(context);

  if (baseUrl.isEmpty) {
    _showError("Server belum siap. Coba lagi.");
    return;
  }

  Navigator.pushNamed(context, "/login");
},
                              label: "LOGIN TO OTAX",
                              icon: Icons.rocket_launch_rounded,
                              isPrimary: true,
                            ),
                            const SizedBox(height: 16),
                            _OutlinedButton(
                              onPressed: () =>
                                  _openUrl("https://t.me/Otapengenkawin"),
                              label: "CONTACT SUPPORT",
                              icon: Icons.support_agent_rounded,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Social Media Footer
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: surfaceColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: dividerColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Hubungi Kami",
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _SocialButton(
                                  icon: Icons.telegram,
                                  color: const Color(0xFF0088CC),
                                  url: "https://t.me/Otapengenkawin",
                                  label: "Telegram",
                                ),
                                const SizedBox(width: 20),
                                _SocialButton(
                                  icon: Icons.music_note_rounded,
                                  color: Colors.white,
                                  url: "https://tiktok.com/@otaxpengenkawin",
                                  label: "TikTok",
                                ),
                                const SizedBox(width: 20),
                                _SocialButton(
                                  icon: Icons.email_rounded,
                                  color: primaryColor,
                                  url: "mailto:otastoree17@gmail.com",
                                  label: "Email",
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Divider(
                              color: dividerColor.withOpacity(0.3),
                              height: 1,
                              thickness: 1,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "© 2026 OTAX BUG. All Rights Reserved",
                              style: TextStyle(
                                color: textSecondary.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Getter untuk mengakses color constants dengan mudah
  Color get primaryColor => LandingPage.primaryColor;
  Color get accentGold => LandingPage.accentGold;
  Color get darkBackground => LandingPage.darkBackground;
  Color get surfaceColor => LandingPage.surfaceColor;
  Color get cardColor => LandingPage.cardColor;
  Color get textPrimary => LandingPage.textPrimary;
  Color get textSecondary => LandingPage.textSecondary;
  Color get dividerColor => LandingPage.dividerColor;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.01)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += 50) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += 50) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ElevatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;
  final bool isPrimary;

  const _ElevatedButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.isPrimary,
  });

  @override
  State<_ElevatedButton> createState() => _ElevatedButtonState();
}

class _ElevatedButtonState extends State<_ElevatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTapDown: (_) => _controller.reverse(),
        onTapUp: (_) {
          _controller.forward();
          widget.onPressed();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      LandingPage.primaryColor,
                      LandingPage.primaryColor.withOpacity(0.9),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: LandingPage.primaryColor
                          .withOpacity(0.3 + _glow.value * 0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OutlinedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData icon;

  const _OutlinedButton({
    required this.onPressed,
    required this.label,
    required this.icon,
  });

  @override
  State<_OutlinedButton> createState() => _OutlinedButtonState();
}

class _OutlinedButtonState extends State<_OutlinedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTapDown: (_) => _controller.reverse(),
        onTapUp: (_) {
          _controller.forward();
          widget.onPressed();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: Container(
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: LandingPage.surfaceColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: LandingPage.accentGold.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      color: LandingPage.accentGold,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: LandingPage.accentGold,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String url;
  final String label;

  const _SocialButton({
    required this.icon,
    required this.color,
    required this.url,
    required this.label,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotation = Tween<double>(begin: 0, end: 0.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchURL() async {
    final Uri uri = Uri.parse(widget.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch ${widget.url}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: GestureDetector(
        onTap: _launchURL,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scale.value,
              child: Transform.rotate(
                angle: _rotation.value,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            widget.color.withOpacity(0.2),
                            widget.color.withOpacity(0.1),
                          ],
                        ),
                        border: Border.all(
                          color: widget.color.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.color.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: LandingPage.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}