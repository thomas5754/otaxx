import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'main.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminPage extends StatefulWidget {
  final String sessionKey;

  const AdminPage({super.key, required this.sessionKey});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  late String sessionKey;
  List<dynamic> fullUserList = [];
  List<dynamic> filteredList = [];
  final List<String> roleOptions = ['KINGZ', 'OWNER', 'TK', 'PT', 'RESELLER', 'FULLUP', 'member'];
  String selectedRole = 'member';
  int currentPage = 1;
  int itemsPerPage = 25;

  final deleteController = TextEditingController();
  final createUsernameController = TextEditingController();
  final createPasswordController = TextEditingController();
  final createDayController = TextEditingController();
  String newUserRole = 'member';
  bool isLoading = false;
  int _currentCarouselIndex = 0;
  late TabController _tabController;

  // --- Warna Tema Merah-Hitam Premium ---
  final Color primaryRed = const Color(0xFFE53935);
  final Color darkRed = const Color(0xFFB71C1C);
  final Color lightRed = const Color(0xFFFF5252);
  final Color deepBlack = const Color(0xFF121212);
  final Color cardBlack = const Color(0xFF1E1E1E);
  final Color surfaceBlack = const Color(0xFF252525);
  final Color accentGold = const Color(0xFFFFD700);
  final Color accentBlue = const Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    sessionKey = widget.sessionKey;
    _tabController = TabController(length: 3, vsync: this);
    _fetchUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://127.0.0.1:4113/listUsers?key=$sessionKey'),
      );
      final data = jsonDecode(res.body);
      if (data['valid'] == true && data['authorized'] == true) {
        fullUserList = data['users'] ?? [];
        _filterAndPaginate();
      } else {
        _showDialog("⚠️ Error", data['message'] ?? 'Tidak diizinkan melihat daftar user.');
      }
    } catch (_) {
      _showDialog("🌐 Error", "Gagal memuat user list.");
    }
    setState(() => isLoading = false);
  }

  void _filterAndPaginate() {
    setState(() {
      currentPage = 1;
      filteredList = fullUserList.where((u) => u['role'] == selectedRole).toList();
    });
  }

  List<dynamic> _getCurrentPageData() {
    final start = (currentPage - 1) * itemsPerPage;
    final end = (start + itemsPerPage);
    return filteredList.sublist(start, end > filteredList.length ? filteredList.length : end);
  }

  int get totalPages => (filteredList.length / itemsPerPage).ceil();

  Future<void> _deleteUser() async {
    final username = deleteController.text.trim();
    if (username.isEmpty) {
      _showDialog("⚠️ Error", "Masukkan username yang ingin dihapus.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('http://127.0.0.1:4113/deleteUser?key=$sessionKey&username=$username'),
      );
      final data = jsonDecode(res.body);
      if (data['deleted'] == true) {
        _showDialog("✅ Berhasil", "User '${data['user']['username']}' telah dihapus.");
        deleteController.clear();
        _fetchUsers();
      } else {
        _showDialog("❌ Gagal", data['message'] ?? 'Gagal menghapus user.');
      }
    } catch (_) {
      _showDialog("🌐 Error", "Tidak dapat menghubungi server.");
    }
    setState(() => isLoading = false);
  }

  Future<void> _createAccount() async {
  final username = createUsernameController.text.trim();
  final password = createPasswordController.text.trim();
  final day = createDayController.text.trim();

  if (username.isEmpty || password.isEmpty || day.isEmpty) {
    _showDialog("⚠️ Error", "Semua field wajib diisi.");
    return;
  }

  setState(() => isLoading = true);

  try {
    final res = await http.post(
      Uri.parse('http://127.0.0.1:4113/createAccount'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'key': sessionKey,
        'newUser': username,
        'pass': password,
        'day': day,
      }),
    );

    final data = jsonDecode(res.body);

    if (data['created'] == true) {
      _showDialog("✅ Sukses", "Akun '${data['user']['username']}' berhasil dibuat.");
      createUsernameController.clear();
      createPasswordController.clear();
      createDayController.clear();
      _fetchUsers();
    } else {
      _showDialog("❌ Gagal", data['message'] ?? 'Gagal membuat akun.');
    }
  } catch (e) {
    _showDialog("🌐 Error", "Gagal menghubungi server.");
  }

  setState(() => isLoading = false);
}

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: cardBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: primaryRed, width: 2),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryRed,
              fontSize: 22,
              shadows: [
                Shadow(
                  color: primaryRed.withOpacity(0.3),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          content: Text(message, style: const TextStyle(color: Colors.white, fontSize: 16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: primaryRed.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text("OK", style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 25,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: primaryRed.withOpacity(0.05),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildUserItem(Map user, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryRed.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryRed.withOpacity(0.3), Colors.transparent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryRed.withOpacity(0.3)),
          ),
          child: Icon(Icons.person, color: Colors.white, size: 24),
        ),
        title: Text(
          user['username'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(user['role']),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "Role: ${user['role']}",
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Exp: ${user['expiredDate']}",
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              "Parent: ${user['parent'] ?? 'SYSTEM'}",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700, Colors.red.shade900],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 22),
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: cardBlack,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.red, width: 2),
                ),
                title: const Text(
                  "Konfirmasi Hapus",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 22,
                  ),
                ),
                content: Text(
                  "Yakin ingin menghapus user '${user['username']}'?",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Batal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Hapus", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              deleteController.text = user['username'];
              _deleteUser();
            }
          },
        ),
      ),
    ).animate().fadeIn(delay: (index * 100).ms);
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'OWNER':
        return accentGold.withOpacity(0.3);
      case 'TK':
        return Colors.green.withOpacity(0.3);
      case 'PT':
        return Colors.blue.withOpacity(0.3);
      case 'RESELLER':
        return Colors.purple.withOpacity(0.3);
      case 'FULLUP':
        return Colors.orange.withOpacity(0.3);
      default:
        return Colors.grey.withOpacity(0.3);
    }
  }

  Widget _buildPagination() {
  if (totalPages <= 1) return const SizedBox();

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), // Kurangi horizontal padding
    decoration: BoxDecoration(
      color: surfaceBlack,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
    ),
    child: Column(
      children: [
        // Info Total Users dan Halaman
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardBlack,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryRed.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            children: [
              Text(
                'PAGE $currentPage OF $totalPages',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$currentPage',
                      style: TextStyle(
                        color: primaryRed,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' / $totalPages',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${filteredList.length} users • ${_getCurrentPageData().length} on this page',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Tombol Pagination
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tombol Previous
            Flexible(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: currentPage > 1
                      ? () => setState(() => currentPage--)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed.withOpacity(0.1),
                    foregroundColor: primaryRed,
                    disabledForegroundColor: primaryRed.withOpacity(0.3),
                    disabledBackgroundColor: primaryRed.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: currentPage > 1
                            ? primaryRed.withOpacity(0.3)
                            : primaryRed.withOpacity(0.1),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_left, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Prev',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Indicator Halaman (untuk mobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: cardBlack,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryRed.withOpacity(0.2), width: 1),
              ),
              child: Text(
                '$currentPage',
                style: TextStyle(
                  color: primaryRed,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Tombol Next
            Flexible(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: currentPage < totalPages
                      ? () => setState(() => currentPage++)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed.withOpacity(0.1),
                    foregroundColor: primaryRed,
                    disabledForegroundColor: primaryRed.withOpacity(0.3),
                    disabledBackgroundColor: primaryRed.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: currentPage < totalPages
                            ? primaryRed.withOpacity(0.3)
                            : primaryRed.withOpacity(0.1),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildCarouselSection() {
    final List<Widget> carouselItems = [
      // Delete User Card
      _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.red.shade900],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    "DELETE USER",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _buildInputField(
              controller: deleteController,
              label: "Username untuk dihapus",
              icon: Icons.person,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _deleteUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.red.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      "DELETE USER",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Create Account Card
      _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade700, Colors.green.shade900],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    "CREATE ACCOUNT",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            _buildInputField(
              controller: createUsernameController,
              label: "Username",
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 15),
            _buildInputField(
              controller: createPasswordController,
              label: "Password",
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInputField(
                    controller: createDayController,
                    label: "Durasi (hari)",
                    icon: Icons.calendar_today,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  flex: 3,
                  child: _buildDropdown(
                    value: newUserRole,
                    onChanged: (val) => setState(() => newUserRole = val ?? 'member'),
                    label: "Role",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isLoading ? null : _createAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: Colors.green.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      "CREATE ACCOUNT",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 480,
          child: PageView.builder(
            itemCount: carouselItems.length,
            controller: PageController(viewportFraction: 0.9),
            onPageChanged: (index) {
              setState(() => _currentCarouselIndex = index);
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: carouselItems[index],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            carouselItems.length,
            (index) => AnimatedContainer(
              duration: 300.ms,
              width: _currentCarouselIndex == index ? 32 : 12,
              height: 12,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: _currentCarouselIndex == index ? primaryRed : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
            ).animate().scale(delay: (index * 100).ms),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepBlack,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: cardBlack,
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryRed, darkRed],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryRed.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ADMIN PAGE",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: primaryRed.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "User OTAX Management",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 800.ms),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Carousel Section
                    _buildCarouselSection().animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 40),

                    // User Management Section
                    _buildGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: accentBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accentBlue.withOpacity(0.3)),
                                ),
                                child: Icon(Icons.people, color: accentBlue, size: 28),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  "USER OTAX",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: surfaceBlack,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Text(
                                  "Total: ${filteredList.length} users",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),

                          _buildDropdown(
                            value: selectedRole,
                            onChanged: (val) {
                              if (val != null) {
                                selectedRole = val;
                                _filterAndPaginate();
                              }
                            },
                            label: "Filter by Role",
                          ),

                          const SizedBox(height: 25),

                          isLoading
                              ? Center(
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        width: 50,
                                        height: 50,
                                        child: CircularProgressIndicator(
                                          color: primaryRed,
                                          strokeWidth: 4,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        "Loading users...",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Column(
                                  children: [
                                    if (filteredList.isEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(vertical: 60),
                                        child: Column(
                                          children: [
                                            Icon(Icons.people_outline, color: Colors.white.withOpacity(0.3), size: 80),
                                            const SizedBox(height: 20),
                                            Text(
                                              "No users found for role: $selectedRole",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.5),
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Column(
                                        children: [
                                          ..._getCurrentPageData()
                                              .asMap()
                                              .entries
                                              .map((entry) => _buildUserItem(entry.value, entry.key))
                                              .toList(),
                                          const SizedBox(height: 30),
                                          _buildPagination(),
                                        ],
                                      ),
                                  ],
                                ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 600.ms),

                    const SizedBox(height: 20),

                    // Footer Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceBlack,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info, color: Colors.white.withOpacity(0.6), size: 18),
                          const SizedBox(width: 10),
                          Text(
                            "OTAX | ${fullUserList.length} Total Users",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
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
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: primaryRed,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          prefixIcon: Icon(icon, color: primaryRed.withOpacity(0.8), size: 24),
          filled: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryRed, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required Function(String?) onChanged,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: cardBlack,
        icon: Icon(Icons.arrow_drop_down, color: primaryRed, size: 32),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
          prefixIcon: Icon(Icons.category, color: primaryRed.withOpacity(0.8), size: 24),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: primaryRed, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        items: roleOptions.map((role) {
          return DropdownMenuItem(
            value: role,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  role.toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}