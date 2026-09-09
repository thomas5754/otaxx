import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'manage_server.dart';
import 'wifi_internal.dart';
import 'wifi_external.dart';
import 'ddos_panel.dart';
import 'nik_check.dart';
import 'tiktok_page.dart';
import 'instagram_page.dart';
import 'qr_gen.dart';
import 'domain_page.dart';
import 'spam_ngl.dart';
import 'music_page.dart';
import 'package:otax/anime_page.dart';
import 'package:provider/provider.dart';
import 'package:otax/ui/models/providers/appProvider.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'bug_group_page.dart';
import 'enak_page.dart';
import 'ai_page.dart';
import 'fakestory.dart';
import 'faketweet.dart';
import 'iqc.dart';
import 'cpanel.dart';
import 'colong.dart';
import 'ff.dart';
import 'packman.dart';
import 'ular.dart';
import 'gameotax.dart';
import 'tourl.dart';
import 'controller.dart';
import 'dart:math' as math;
import 'auto_detect_page.dart';
import 'create_vps_page.dart';
import 'install_panel_page.dart';
import 'webapk.dart';
class ToolsPage extends StatefulWidget {
  final String sessionKey;
  final String userRole;
  final String username;
  final List<Map<String, dynamic>> listDoos;

  const ToolsPage({
    super.key,
    required this.sessionKey,
    required this.userRole,
    required this.username,
    required this.listDoos,
  });

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  static const Color midnight = Color(0xFF0B0C10);
  static const Color charcoal = Color(0xFF1A1C22);
  static const Color steel = Color(0xFF2D3038);
  static const Color crimson = Color(0xFFDC143C);
  static const Color ruby = Color(0xFFE0115F);
  static const Color platinum = Color(0xFFE5E5E5);

  static const List<_ToolCategory> _categories = [
    _ToolCategory(
      icon: Icons.cloud_outlined,
      title: "Panel",
      subtitle: "Manajemen server",
    ),
    _ToolCategory(
      icon: Icons.sports_esports_outlined,
      title: "Game & AI",
      subtitle: "Catur, pacman, asisten",
    ),
    _ToolCategory(
      icon: Icons.flash_on_outlined,
      title: "DDoS",
      subtitle: "Stress test",
    ),
    _ToolCategory(
      icon: Icons.wifi_outlined,
      title: "Network",
      subtitle: "WiFi, spam",
    ),
    _ToolCategory(
      icon: Icons.search_outlined,
      title: "OSINT",
      subtitle: "NIK, domain, telepon",
    ),
    _ToolCategory(
      icon: Icons.download_outlined,
      title: "Downloader",
      subtitle: "TikTok, Instagram",
    ),
    _ToolCategory(
      icon: Icons.build_outlined,
      title: "OTAXRAT",
      subtitle: "Rat Malware",
    ),
    _ToolCategory(
      icon: Icons.rocket_launch_outlined,
      title: "Generator",
      subtitle: "Quote, fake story",
    ),
    _ToolCategory(
      icon: Icons.auto_awesome_outlined,
      title: "Anime",
      subtitle: "Streaming, 18+",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: midnight,
      body: Stack(
        children: [
          const _NoiseBackground(),
          RepaintBoundary(
            child: _GlowEffect(glowAnimation: _glowAnimation),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSectionHeader(),
                const SizedBox(height: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      itemCount: _categories.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.92,
                      ),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return _ToolCard(
                          category: category,
                          onTap: () => _onCategoryTap(context, category),
                        );
                      },
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Hero(
            tag: 'logo',
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [crimson, ruby],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: crimson.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/otaxlogo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, Colors.white],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.shield_moon_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "OTAX",
                  style: TextStyle(
                    color: platinum,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Gateway Tools",
                  style: TextStyle(
                    color: platinum.withOpacity(0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: charcoal,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: crimson.withOpacity(0.3),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: crimson,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: crimson.withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.userRole.toUpperCase(),
                  style: const TextStyle(
                    color: crimson,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [crimson, ruby],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "Tools OTAX",
            style: TextStyle(
              color: platinum.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            "${_categories.length} item",
            style: TextStyle(
              color: platinum.withOpacity(0.4),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _onCategoryTap(BuildContext context, _ToolCategory category) {
    switch (category.title) {
      case "Panel":
        _showVpsTools(context);
        break;
      case "Game & AI":
        _showGamesTools(context);
        break;
      case "DDoS":
        _showDDoSTools(context);
        break;
      case "Network":
        _showNetworkTools(context);
        break;
      case "OSINT":
        _showOSINTTools(context);
        break;
      case "Downloader":
        _showDownloaderTools(context);
        break;
      case "OTAXRAT":
        _showUtilityTools(context);
        break;
      case "Generator":
        _showQuickAccess(context);
        break;
      case "Anime":
        _showAnimeTools(context);
        break;
    }
  }

  void _showAnimeTools(BuildContext context) {
    _showModalSheet(
      context,
      "Anime",
      Icons.auto_awesome_outlined,
      [
        _buildModalItem(
          icon: Icons.movie_outlined,
          label: "Anime Page",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FutureBuilder(
                  future: ensureAnimeStreamInitialized(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return ChangeNotifierProvider(
                      create: (ctx) => AppProvider(),
                      child: const AnimeStream(),
                    );
                  },
                ),
              ),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.lock_outlined,
          label: "18+",
          onTap: () {
            Navigator.pop(context);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: const Text('Informasi'),
                      content: const Text(
                        'Mohon Maaf Fitur Ini Ditutup Selama Bulan Ramadhan',
                        textAlign: TextAlign.center,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              }
            });
          },
        ),
      ],
    );
  }

  void _showVpsTools(BuildContext context) {
    _showModalSheet(
      context,
      "Panel",
      Icons.cloud_outlined,
      [
        _buildModalItem(
          icon: Icons.sports_esports_outlined,
          label: "Cpanel",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CpanelPage(
                  username: widget.username,
                  role: widget.userRole,
                ),
              ),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.security_outlined,
          label: "Colong Sender",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CredsStealerAdvancedPage(
                  username: widget.username,
                  role: widget.userRole,
                ),
              ),
            );
          },
        ),
_buildModalItem(
  icon: Icons.computer_outlined,
  label: "Buat VPS DigitalOcean",
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateVpsPage(
          sessionKey: widget.sessionKey,
          username: widget.username,
          role: widget.userRole,
        ),
      ),
    );
  },
),

_buildModalItem(
  icon: Icons.settings_ethernet_outlined,
  label: "Install Panel Pterodactyl",
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InstallPanelPage(),
      ),
    );
  },
),
_buildModalItem(
  icon: Icons.build_circle_outlined,
  label: "Install Flutter",
  onTap: () {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InstallWeb2apkPage(),
      ),
    );
  },
),
      ],
    );
  }

  void _showGamesTools(BuildContext context) {
    _showModalSheet(
      context,
      "Game & AI",
      Icons.sports_esports_outlined,
      [
        _buildModalItem(
          icon: Icons.sports_esports_outlined,
          label: "Packman",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PacmanGamePage()),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.catching_pokemon_outlined,
          label: "Ular Klasik",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SnakeGame()),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.videogame_asset_outlined,
          label: "Free Fire Tools",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FreeFireToolsPage(
                  sessionKey: widget.sessionKey,
                  username: widget.username,
                  role: widget.userRole,
                ),
              ),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.catching_pokemon_outlined,
          label: "OTAX GAMES",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RetroGameHub()),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.smart_toy_outlined,
          label: "AI Assistant",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AIPage(
                  sessionKey: widget.sessionKey,
                  username: widget.username,
                  role: widget.userRole,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDDoSTools(BuildContext context) {
  _showModalSheet(
    context,
    "DDoS",
    Icons.flash_on_outlined,
    [
      _buildModalItem(
        icon: Icons.flash_on_outlined,
        label: "Attack Panel",
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AttackPanel(
                sessionKey: widget.sessionKey,
                listDoos: widget.listDoos,
              ),
            ),
          );
        },
      ),
      _buildModalItem(
        icon: Icons.dns_outlined,
        label: "Manage Server",
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManageServerPage(keyToken: widget.sessionKey),
            ),
          );
        },
      ),
      // Tambahkan item Auto Detect ML
      _buildModalItem(
        icon: Icons.sports_esports_outlined,
        label: "Auto Detect Games",
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AutoDetectPage(
                sessionKey: widget.sessionKey,
                savedVPS: widget.listDoos, // Langsung kirim listDoos
              ),
            ),
          );
        },
      ),
    ],
  );
}

  void _showNetworkTools(BuildContext context) {
    _showModalSheet(
      context,
      "Network",
      Icons.wifi_outlined,
      [
        _buildModalItem(
          icon: Icons.newspaper_outlined,
          label: "Spam NGL",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NglPage()),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.wifi_off_outlined,
          label: "WiFi Internal",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => WifiKillerPage()),
            );
          },
        ),
        if (widget.userRole == "KINGZ" || widget.userRole == "OWNER")
          _buildModalItem(
            icon: Icons.router_outlined,
            label: "WiFi External",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WifiInternalPage(sessionKey: widget.sessionKey),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showOSINTTools(BuildContext context) {
    _showModalSheet(
      context,
      "OSINT",
      Icons.search_outlined,
      [
        _buildModalItem(
          icon: Icons.badge_outlined,
          label: "NIK Detail",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NikCheckerPage()),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.domain_outlined,
          label: "Domain OSINT",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DomainOsintPage()),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.person_search_outlined,
          label: "Phone Lookup",
          onTap: () => _showComingSoon(context),
        ),
        _buildModalItem(
          icon: Icons.email_outlined,
          label: "Email OSINT",
          onTap: () => _showComingSoon(context),
        ),
      ],
    );
  }

  void _showDownloaderTools(BuildContext context) {
    _showModalSheet(
      context,
      "Downloader",
      Icons.download_outlined,
      [
        _buildModalItem(
          icon: Icons.video_library_outlined,
          label: "TikTok",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TiktokDownloaderPage()),
            );
          },
        ),
        _buildModalItem(
          icon: Icons.camera_alt_outlined,
          label: "Instagram",
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InstagramDownloaderPage()),
            );
          },
        ),
      ],
    );
  }

  void _showUtilityTools(BuildContext context) {
    _showModalSheet(
      context,
      "OTAXRAT",
      Icons.build_outlined,
      [
        _buildModalItem(
          icon: Icons.badge_outlined,
          label: "RAT Controll",
          onTap: () {
            Navigator.pop(context);
            AppConfig.sessionKey = widget.sessionKey;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TargetListPage()),
            );
          },
        ),
      ],
    );
  }

 void _showQuickAccess(BuildContext context) {
  _showModalSheet(
    context,
    "Generator",
    Icons.auto_awesome,
    [
      _buildModalItem(
        icon: Icons.phone_iphone,
        label: "iPhone Quote",
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IqcPage()),
          );
        },
      ),
      _buildModalItem(
        icon: Icons.auto_stories_outlined,
        label: "Fake Story",
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FakeStoryPage()),
          );
        },
      ),
      _buildModalItem(
        icon: Icons.flutter_dash,
        label: "Fake Tweet",
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FakeTweetPage()),
          );
        },
      ),
      _buildModalItem(
        icon: Icons.cloud_upload_outlined,
        label: "To Url",
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UploadToUrlPage()),
          );
        },
      ),
    ],
  );
}

  void _showModalSheet(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> items,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: charcoal,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [crimson.withOpacity(0.15), ruby.withOpacity(0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: crimson, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF909090)),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(
              color: Colors.white.withOpacity(0.06),
              height: 1,
              thickness: 0.8,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => items[index],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: crimson.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: midnight.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.02),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      crimson.withOpacity(0.12),
                      ruby.withOpacity(0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: crimson, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: platinum.withOpacity(0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.hourglass_top_outlined, color: platinum, size: 18),
            const SizedBox(width: 12),
            const Text(
              'Segera hadir',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: crimson,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ToolCategory {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ToolCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _ToolCard extends StatelessWidget {
  final _ToolCategory category;
  final VoidCallback onTap;

  const _ToolCard({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: _ToolsPageState.crimson.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: _ToolsPageState.charcoal,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.03),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _ToolsPageState.crimson.withOpacity(0.15),
                      _ToolsPageState.ruby.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  category.icon,
                  color: _ToolsPageState.crimson,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                category.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                category.subtitle,
                style: TextStyle(
                  color: _ToolsPageState.platinum.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowEffect extends StatelessWidget {
  final Animation<double> glowAnimation;

  const _GlowEffect({required this.glowAnimation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: -80,
              right: -40,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _ToolsPageState.crimson.withOpacity(0.12 * glowAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _ToolsPageState.ruby.withOpacity(0.1 * glowAnimation.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NoiseBackground extends StatelessWidget {
  const _NoiseBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _NoisePainter(),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.008)
      ..style = PaintingStyle.fill;
    final random = math.Random(42);
    for (int i = 0; i < 150; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.2;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}