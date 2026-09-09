import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'main.dart';
class ThanksToPage extends StatefulWidget {
  const ThanksToPage({super.key});

  @override
  State<ThanksToPage> createState() => _ThanksToPageState();
}

class _ThanksToPageState extends State<ThanksToPage> {
  List<Map<String, dynamic>> contributors = [];
  bool _isLoading = true;
  
  int _currentPage = 0;
  final PageController _pageController = PageController(
    viewportFraction: 0.88,
  );
  late Timer _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _fetchContributors();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _autoSlideTimer.cancel();
    super.dispose();
  }

  Future<void> _fetchContributors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/contributors'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> items = [];
        
        if (data is List) {
          items = data;
        } else if (data['contributors'] is List) {
          items = data['contributors'];
        } else if (data['data'] is List) {
          items = data['data'];
        }
        
        setState(() {
          contributors = List<Map<String, dynamic>>.from(items.map((item) {
            return {
              'nama': item['nama']?.toString() ?? 'Member',
              'telegram': item['telegram']?.toString() ?? '',
              'role': item['role']?.toString() ?? 'Contributor',
              'avatar': item['avatar']?.toString() ?? '',
              'telegram_url': 'https://t.me/${item['telegram']?.toString().replaceAll('@', '')}',
            };
          }));
          _isLoading = false;
        });
      } else {
        _loadFallbackData();
      }
    } catch (e) {
      _loadFallbackData();
    }
  }

  void _loadFallbackData() {
    setState(() {
      contributors = [
        {
          'nama': 'ᯓ 𝙊𝙏𝘼𝕏',
          'telegram': '@otaxpengenkawin', 
          'role': 'KINGZ',
          'avatar': 'https://files.catbox.moe/vor12a.jpg',
          'telegram_url': 'https://t.me/otaxpengenkawin',
        },
        {
          'nama': 'ᯓ AYUN',
          'telegram': '@Okebisaa', 
          'role': 'Queenz',
          'avatar': 'https://files.catbox.moe/g7thjw.jpg',
          'telegram_url': 'https://t.me/Okebisaa',
        },
      ];
      _isLoading = false;
    });
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_pageController.hasClients && contributors.length > 1) {
        int nextPage = _currentPage + 1;
        if (nextPage >= contributors.length) nextPage = 0;
        
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  

Future<void> _openTelegram(String username) async {
  final cleanUsername = username.replaceAll('@', '');
  final Uri url = Uri.parse('https://t.me/$cleanUsername');

  if (!await launchUrl(
    url,
    mode: LaunchMode.externalApplication,
  )) {
    throw 'Tidak bisa membuka Telegram';
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedContainer(
            duration: const Duration(seconds: 10),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  Color.lerp(Colors.black, const Color(0xFF8B0000), 0.05)!,
                  Colors.black,
                  Colors.black,
                ],
              ),
            ),
          ),
          
          // Floating particles effect
          _buildParticles(),
          
          SafeArea(
            child: Column(
              children: [
                // Minimal Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      // Back button with glow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B0000).withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          color: Colors.white,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Team OTAX',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 3,
                                fontFamily: 'Debrosee',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 1,
                              width: 60,
                              color: const Color(0xFF8B0000),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 60,
                                height: 60,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF8B0000),
                                ),
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Loading Team...',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                  fontFamily: 'Debrosee',
                                ),
                              ),
                            ],
                          ),
                        )
                      : contributors.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.group_off_outlined,
                                    color: Colors.white30,
                                    size: 60,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No contributors yet',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 16,
                                      fontFamily: 'Debrosee',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : PageView.builder(
                              controller: _pageController,
                              itemCount: contributors.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                final person = contributors[index];
                                return AnimatedBuilder(
                                  animation: _pageController,
                                  builder: (context, child) {
                                    double value = 1.0;
                                    if (_pageController.position.haveDimensions) {
                                      value = _pageController.page! - index;
                                      value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                                    }
                                    
                                    return Transform.scale(
                                      scale: value,
                                      child: Opacity(
                                        opacity: value.clamp(0.5, 1.0),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
                                          child: _buildContributorCard(person),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                ),

                // Bottom Navigation
                if (!_isLoading && contributors.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.only(bottom: 30, top: 10),
                    child: Column(
                      children: [
                        // Page Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            contributors.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: _currentPage == index ? 20 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: _currentPage == index 
                                    ? BoxShape.rectangle 
                                    : BoxShape.circle,
                                borderRadius: _currentPage == index 
                                    ? BorderRadius.circular(4) 
                                    : null,
                                color: _currentPage == index
                                    ? const Color(0xFF8B0000)
                                    : Colors.white.withOpacity(0.2),
                                boxShadow: _currentPage == index
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF8B0000).withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Navigation Arrows
                        if (contributors.length > 1)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildNavButton(
                                icon: Icons.chevron_left_rounded,
                                enabled: _currentPage > 0,
                                onTap: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeInOutCubic,
                                  );
                                },
                              ),
                              
                              const SizedBox(width: 60),
                              
                              _buildNavButton(
                                icon: Icons.chevron_right_rounded,
                                enabled: _currentPage < contributors.length - 1,
                                onTap: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeInOutCubic,
                                  );
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticles() {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.1,
        child: Container(
          child: Stack(
            children: List.generate(
              20,
              (index) => Positioned(
                left: (index * 37) % MediaQuery.of(context).size.width,
                top: (index * 53) % MediaQuery.of(context).size.height,
                child: Container(
                  width: 2,
                  height: 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? const Color(0xFF8B0000).withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: enabled
                ? const Color(0xFF8B0000).withOpacity(0.5)
                : Colors.transparent,
            width: 1,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF8B0000).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: enabled ? const Color(0xFF8B0000) : Colors.white24,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildContributorCard(Map<String, dynamic> person) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF0D0D0D),
            Colors.black,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar with shimmer effect
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B0000).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              // Avatar image with border
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8B0000).withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B0000).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: person['avatar'].toString().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: person['avatar'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF8B0000).withOpacity(0.8),
                                  const Color(0xFFB22222),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF8B0000).withOpacity(0.8),
                                  const Color(0xFFB22222),
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF8B0000).withOpacity(0.8),
                                const Color(0xFFB22222),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white70,
                            size: 40,
                          ),
                        ),
                ),
              ),
              
              // Role badge on bottom right of avatar
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 5,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    person['role'][0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Debrosee',
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // Name with elegant typography
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              person['nama'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
                height: 1.3,
                fontFamily: 'Debrosee',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Role tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B0000).withOpacity(0.1),
                  const Color(0xFF8B0000).withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF8B0000).withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Text(
              person['role'].toUpperCase(),
              style: TextStyle(
                color: const Color(0xFFD32F2F),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                fontFamily: 'Debrosee',
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Telegram Button (Elevated with icon)
          if (person['telegram'].toString().isNotEmpty)
            Container(
              width: 260,
              child: ElevatedButton(
                onPressed: () => _openTelegram(person['telegram']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0088CC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFF0088CC).withOpacity(0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.telegram,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telegram',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Debrosee',
                            ),
                          ),
                          Text(
                            person['telegram'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Debrosee',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}