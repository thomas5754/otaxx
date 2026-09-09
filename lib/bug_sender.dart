import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shimmer/shimmer.dart';

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

class _BugSenderPageState extends State<BugSenderPage> with SingleTickerProviderStateMixin {
  List<dynamic> senderList = [];
  bool isLoading = false;
  bool isRefreshing = false;
  String? errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late PageController _pageController;
  int _currentPage = 0;

  // Elegant Minimalist Color Palette
  static const Color primaryDark = Color(0xFF0F0F13);
  static const Color deepBlack = Color(0xFF18181D);
  static const Color darkCharcoal = Color(0xFF202027);
  static const Color elegantBlue = Color(0xFF2A5C8B);
  static const Color softBlue = Color(0xFF3A7BBF);
  static const Color slateGray = Color(0xFF2D3748);
  static const Color mutedBlue = Color(0xFF4A6572);
  static const Color steelBlue = Color(0xFF3B5268);
  static const Color goldAccent = Color(0xFFB9A16B);
  static const Color platinum = Color(0xFFE2E2E2);
  static const Color carbonFiber = Color(0xFF24242B);
  static const Color successGreen = Color(0xFF2ECC71);
  static const Color errorRed = Color(0xFFE74C3C);
  static const Color subtleGlow = Color(0xFF2A5C8B);

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: 0,
    );
    
    _fetchSenders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchSenders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse("http://127.0.0.1:4113/mySender?key=${widget.sessionKey}"),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["valid"] == true) {
          setState(() {
            senderList = data["connections"] ?? [];
          });
        } else {
          setState(() {
            errorMessage = data["message"] ?? "Failed to fetch senders";
          });
        }
      } else {
        setState(() {
          errorMessage = "Server error: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Connection failed: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  Future<void> _refreshSenders() async {
    setState(() => isRefreshing = true);
    await _fetchSenders();
  }

  Widget _buildMinimalistBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryDark.withOpacity(0.95),
            deepBlack,
            Colors.black,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _GeometricPatternPainter(
          color: slateGray.withOpacity(0.03),
        ),
      ),
    );
  }

  Widget _buildElegantHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryDark.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Logo dengan desain minimalis
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      elegantBlue.withOpacity(0.9),
                      softBlue.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: platinum.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.send_rounded,
                    color: platinum,
                    size: 22,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Title Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "SENDER MANAGEMENT",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        color: platinum,
                        letterSpacing: 2,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "WhatsApp Sender Dashboard",
                      style: TextStyle(
                        color: platinum.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: slateGray.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: elegantBlue.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: successGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${senderList.length} ACTIVE",
                      style: TextStyle(
                        color: platinum.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Subtle Divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  elegantBlue.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselSenderCards() {
    if (senderList.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _pageController,
            itemCount: senderList.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final sender = Map<String, dynamic>.from(senderList[index]);
              return _buildElegantSenderCard(sender, index);
            },
          ),
        ),

        const SizedBox(height: 24),

        // Minimalist Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(senderList.length, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 6,
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? elegantBlue : platinum.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildElegantSenderCard(Map<String, dynamic> sender, int index) {
    final name = sender['sessionName'] ?? 'Unnamed Sender';
    final phone = sender['id']?.split(':')[0]?.split('@')[0] ?? 'Unknown';
    final isActive = index == _currentPage;
    
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double scale = 1.0;
        double opacity = 1.0;
        if (_pageController.position.haveDimensions) {
          final value = (_pageController.page ?? 0) - index;
          scale = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
          opacity = (1 - (value.abs() * 0.3)).clamp(0.7, 1.0);
        }

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Stack(
                children: [
                  // Main Card
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: darkCharcoal,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                        if (isActive)
                          BoxShadow(
                            color: elegantBlue.withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                      ],
                      border: Border.all(
                        color: platinum.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withOpacity(0.02),
                              Colors.white.withOpacity(0.01),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header dengan desain bersih
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          elegantBlue.withOpacity(0.9),
                                          softBlue.withOpacity(0.7),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.phone_android_rounded,
                                        color: platinum,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toUpperCase(),
                                          style: TextStyle(
                                            color: platinum,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Inter',
                                            letterSpacing: 0.8,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          phone,
                                          style: TextStyle(
                                            color: platinum.withOpacity(0.6),
                                            fontSize: 13,
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: successGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: successGreen.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: successGreen,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          "ONLINE",
                                          style: TextStyle(
                                            color: successGreen,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Subtle Divider
                              Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      slateGray.withOpacity(0.2),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Action Buttons - Clean Design
                              Row(
                                children: [
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () => _refreshSender(sender),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: slateGray.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: platinum.withOpacity(0.08),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.refresh_rounded,
                                                color: platinum.withOpacity(0.9),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "REFRESH",
                                                style: TextStyle(
                                                  color: platinum.withOpacity(0.9),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Inter',
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () => _deleteSender(sender['id']),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: errorRed.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: errorRed.withOpacity(0.1),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.delete_outline_rounded,
                                                color: errorRed,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "DELETE",
                                                style: TextStyle(
                                                  color: errorRed,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  fontFamily: 'Inter',
                                                  letterSpacing: 0.8,
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

                              const SizedBox(height: 20),

                              // Status Info - Minimalist
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: slateGray.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: platinum.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: goldAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Connected to WhatsApp Web",
                                        style: TextStyle(
                                          color: platinum.withOpacity(0.7),
                                          fontSize: 11,
                                          fontFamily: 'Inter',
                                        ),
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: slateGray.withOpacity(0.1),
                border: Border.all(
                  color: platinum.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.phone_iphone_rounded,
                color: platinum.withOpacity(0.3),
                size: 40,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "NO SENDERS",
              style: TextStyle(
                color: platinum,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                fontFamily: 'Inter',
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 150,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    elegantBlue.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              width: 280,
              decoration: BoxDecoration(
                color: darkCharcoal,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: platinum.withOpacity(0.08),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: goldAccent,
                    size: 28,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Add your first WhatsApp sender\nto start using premium features",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: platinum.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.5,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [elegantBlue, softBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: _showAddSenderDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: platinum, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      "ADD FIRST SENDER",
                      style: TextStyle(
                        color: platinum,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                        letterSpacing: 1,
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: errorRed.withOpacity(0.05),
                border: Border.all(
                  color: errorRed.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: errorRed,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "CONNECTION ERROR",
              style: TextStyle(
                color: platinum,
                fontSize: 18,
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              width: 280,
              decoration: BoxDecoration(
                color: darkCharcoal,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: errorRed.withOpacity(0.1)),
              ),
              child: Text(
                errorMessage ?? "Unknown error occurred",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: platinum.withOpacity(0.7),
                  fontSize: 12,
                  height: 1.5,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: elegantBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: elegantBlue.withOpacity(0.2)),
              ),
              child: ElevatedButton(
                onPressed: _fetchSenders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: platinum, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "RETRY CONNECTION",
                      style: TextStyle(
                        color: platinum,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                        letterSpacing: 0.8,
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

  Future<void> _refreshSender(Map<String, dynamic> sender) async {
    _showSnackBar("Refreshing sender connection...", isError: false);
    await _fetchSenders();
  }

  void _showAddSenderDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => _buildMinimalistDialog(),
    );
  }

  Widget _buildMinimalistDialog() {
    final phoneController = TextEditingController();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: darkCharcoal,
          border: Border.all(
            color: platinum.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: slateGray.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: platinum.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: elegantBlue.withOpacity(0.2),
                    ),
                    child: Icon(Icons.add_rounded, color: platinum, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "ADD NEW SENDER",
                      style: TextStyle(
                        color: platinum,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMinimalistTextField(
                    controller: phoneController,
                    label: "Phone Number",
                    icon: Icons.phone_rounded,
                    hint: "628123456789",
                    isPhone: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: slateGray.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: platinum.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "CANCEL",
                                  style: TextStyle(
                                    color: platinum.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Inter',
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [elegantBlue, softBlue],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              final number = phoneController.text.trim();
                              if (number.isEmpty) {
                                _showSnackBar(
                                  "Please enter phone number",
                                  isError: true,
                                );
                                return;
                              }
                              Navigator.pop(context);
                              await _addSender(number, "");
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "CONTINUE",
                              style: TextStyle(
                                color: platinum,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                                letterSpacing: 0.8,
                              ),
                            ),
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
    );
  }

  Widget _buildMinimalistTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: platinum.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: slateGray.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: platinum.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            style: TextStyle(
              color: platinum,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: platinum.withOpacity(0.4),
              ),
              prefixIcon: Icon(icon, color: goldAccent, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Keep existing methods for addSender, deleteSender, showSnackBar, etc.
  // (Updating them to match the new minimalist theme)

  Future<void> _addSender(String number, String name) async {
    BuildContext? loadingContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        loadingContext = context;
        return _buildMinimalistLoadingDialog();
      },
    );

    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
            "http://127.0.0.1:4113/getPairing?key=${widget.sessionKey}&number=$number"),
      );

      if (loadingContext != null && mounted) {
        Navigator.of(loadingContext!).pop();
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["valid"] == true) {
          _showPairingCodeDialog(number, data['pairingCode'], name);
          _showSnackBar("Pairing code generated successfully!", isError: false);
        } else {
          _showSnackBar(
              data['message'] ?? "Failed to generate pairing code",
              isError: true);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", isError: true);
      }
    } catch (e) {
      if (loadingContext != null && mounted) {
        Navigator.of(loadingContext!).pop();
      }
      _showSnackBar("Connection failed: $e", isError: true);
    } finally {
      setState(() => isLoading = false);
      _fetchSenders();
    }
  }

  void _showPairingCodeDialog(String number, String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: darkCharcoal,
            border: Border.all(
              color: platinum.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: elegantBlue.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: platinum.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: elegantBlue.withOpacity(0.2),
                      ),
                      child: Icon(Icons.qr_code_scanner_rounded, color: platinum),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "PAIRING REQUIRED",
                        style: TextStyle(
                          color: platinum,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Phone Number Info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: slateGray.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: platinum.withOpacity(0.08)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone_rounded, color: goldAccent, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "PHONE NUMBER",
                                  style: TextStyle(
                                    color: platinum.withOpacity(0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Inter',
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  number,
                                  style: TextStyle(
                                    color: platinum,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Pairing Code
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: slateGray.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: elegantBlue.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Text(
                              "PAIRING CODE",
                              style: TextStyle(
                                color: platinum.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter',
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              code,
                              style: TextStyle(
                                color: goldAccent,
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'RobotoMono',
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Valid for 20 minutes",
                              style: TextStyle(
                                color: platinum.withOpacity(0.5),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: slateGray.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: platinum.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: goldAccent, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "INSTRUCTIONS",
                                style: TextStyle(
                                  color: platinum,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildInstructionStep(
                            number: "1",
                            title: "Open WhatsApp",
                            description: "Go to Settings menu",
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionStep(
                            number: "2",
                            title: "Linked Devices",
                            description: "Tap on 'Linked Devices' option",
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionStep(
                            number: "3",
                            title: "Link a Device",
                            description: "Select 'Link a Device'",
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionStep(
                            number: "4",
                            title: "Enter Code",
                            description: "Type the 6-digit code above",
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Footer Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: slateGray.withOpacity(0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: platinum.withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: slateGray.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: platinum.withOpacity(0.08)),
                            ),
                            child: Center(
                              child: Text(
                                "CLOSE",
                                style: TextStyle(
                                  color: platinum,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [elegantBlue, softBlue],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _fetchSenders();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            "REFRESH",
                            style: TextStyle(
                              color: platinum,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Inter',
                              letterSpacing: 0.8,
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
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String number,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: elegantBlue.withOpacity(0.2),
            border: Border.all(
              color: elegantBlue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: platinum,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: platinum,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: platinum.withOpacity(0.7),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalistLoadingDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: darkCharcoal,
          border: Border.all(color: platinum.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: elegantBlue.withOpacity(0.1),
                border: Border.all(
                  color: elegantBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                color: platinum,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "GENERATING CODE",
              style: TextStyle(
                color: platinum,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please wait while we create your pairing code",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: platinum.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(elegantBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSender(String senderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _buildMinimalistConfirmationDialog(),
    );

    if (confirmed == true) {
      setState(() => isLoading = true);

      try {
        final response = await http.delete(
          Uri.parse(
              "http://127.0.0.1:4113/deleteSender?key=${widget.sessionKey}&id=$senderId"),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["valid"] == true) {
            _showSnackBar("Sender deleted successfully!", isError: false);
            _fetchSenders();
          } else {
            _showSnackBar(data["message"] ?? "Failed to delete sender",
                isError: true);
          }
        } else {
          _showSnackBar("Server error: ${response.statusCode}", isError: true);
        }
      } catch (e) {
        _showSnackBar("Connection failed: $e", isError: true);
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildMinimalistConfirmationDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: darkCharcoal,
          border: Border.all(color: errorRed.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: errorRed.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: platinum.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: errorRed.withOpacity(0.2),
                    ),
                    child: Icon(Icons.warning_amber_rounded, 
                        color: errorRed, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "CONFIRM DELETE",
                      style: TextStyle(
                        color: platinum,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    "Are you sure you want to delete this sender?\nThis action cannot be undone.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: platinum.withOpacity(0.8),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: () => Navigator.pop(context, false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: slateGray.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: platinum.withOpacity(0.08)),
                              ),
                              child: Center(
                                child: Text(
                                  "CANCEL",
                                  style: TextStyle(
                                    color: platinum,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: errorRed.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: errorRed.withOpacity(0.3)),
                          ),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              "DELETE",
                              style: TextStyle(
                                color: platinum,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          decoration: BoxDecoration(
            color: isError ? errorRed.withOpacity(0.9) : successGreen.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                color: platinum,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: platinum,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: Stack(
        children: [
          _buildMinimalistBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildElegantHeader(),
                Expanded(
                  child: isLoading && senderList.isEmpty
                      ? Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: elegantBlue.withOpacity(0.1),
                              border: Border.all(
                                color: elegantBlue.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(platinum),
                              ),
                            ),
                          ),
                        )
                      : errorMessage != null && senderList.isEmpty
                          ? _buildErrorState()
                          : _buildCarouselSenderCards(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [elegantBlue, softBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: elegantBlue.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          foregroundColor: platinum,
          onPressed: _showAddSenderDialog,
          elevation: 0,
          child: Icon(Icons.add_rounded, size: 24),
        ),
      ),
    );
  }
}

class _GeometricPatternPainter extends CustomPainter {
  final Color color;

  _GeometricPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.2
      ..style = PaintingStyle.stroke;

    final gridSize = 60.0;

    // Draw subtle diagonal lines
    for (double i = -size.height; i < size.width * 2; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GeometricPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}