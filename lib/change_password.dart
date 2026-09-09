import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';
import 'main.dart';


class ChangePasswordPage extends StatefulWidget {
  final String username;
  final String sessionKey;

  const ChangePasswordPage({
    super.key,
    required this.username,
    required this.sessionKey,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> with SingleTickerProviderStateMixin {
  final oldPassCtrl = TextEditingController();
  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();

  bool isLoading = false;
  bool _isObscureOld = true;
  bool _isObscureNew = true;
  bool _isObscureConfirm = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // --- Warna Tema Elegant Merah-Hitam ---
  final Color bloodRed = const Color(0xFFE53935);
  final Color darkRed = const Color(0xFFB71C1C);
  final Color lightRed = const Color(0xFFFF5252);
  final Color deepBlack = const Color(0xFF0A0A0A);
  final Color glassBlack = Colors.black.withOpacity(0.7);
  final Color cardGlow = Color(0x30E53935);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final oldPass = oldPassCtrl.text.trim();
    final newPass = newPassCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    if (oldPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      _showMessage("All fields are required");
      return;
    }

    if (newPass != confirmPass) {
      _showMessage("New password doesn't match confirmation");
      return;
    }

    setState(() => isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("http://127.0.0.1:4113/changepass"),
        body: {
          "username": widget.username,
          "oldPass": oldPass,
          "newPass": newPass,
          "sessionKey": widget.sessionKey,
        },
      );

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        _showMessage("Password changed successfully", isSuccess: true);
        oldPassCtrl.clear();
        newPassCtrl.clear();
        confirmPassCtrl.clear();
      } else {
        _showMessage(data['message'] ?? "Failed to change password");
      }
    } catch (e) {
      _showMessage("Server error: $e");
    }

    setState(() => isLoading = false);
  }

  void _showMessage(String msg, {bool isSuccess = false}) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: glassBlack,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: isSuccess ? Colors.green.withOpacity(0.5) : bloodRed.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.info,
                color: isSuccess ? Colors.green : bloodRed,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                isSuccess ? "Success" : "Notice",
                style: TextStyle(
                  color: isSuccess ? Colors.green : bloodRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          content: Text(
            msg,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          actions: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    bloodRed.withOpacity(0.8),
                    darkRed.withOpacity(0.8),
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "CLOSE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: padding ?? EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            glassBlack,
            Colors.black.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bloodRed.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cardGlow,
            blurRadius: 30,
            spreadRadius: 3,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    required IconData prefixIcon,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              border: Border.all(color: bloodRed.withOpacity(0.3), width: 1.5),
            ),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: bloodRed,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                prefixIcon: Icon(prefixIcon, color: bloodRed, size: 22),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: bloodRed.withOpacity(0.7),
                    size: 20,
                  ),
                  onPressed: onToggle,
                ),
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepBlack,
      body: Stack(
        children: [
          // Animated Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 2.0,
                  colors: [
                    bloodRed.withOpacity(0.08),
                    darkRed.withOpacity(0.04),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
            ),
          ),

          // Floating Particles
          ...List.generate(
            3,
            (index) => Positioned(
              top: MediaQuery.of(context).size.height * 0.3 + index * 100,
              left: MediaQuery.of(context).size.width * 0.1 + index * 80,
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: bloodRed.withOpacity(0.4),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: bloodRed.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(reverse: true),
            ).fade(duration: 2.seconds).moveX(
                  begin: 0,
                  end: 20,
                  duration: (index + 3).seconds,
                  curve: Curves.easeInOutSine,
                ),
          ),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 30),

                          // Header Section
                          _buildGlassCard(
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        bloodRed.withOpacity(0.3),
                                        darkRed.withOpacity(0.1),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: bloodRed.withOpacity(0.4),
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.security,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ).animate().scale(duration: 800.ms),
                                
                                SizedBox(height: 20),
                                
                                Text(
                                  "SECURITY UPDATE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                
                                SizedBox(height: 8),
                                
                                Text(
                                  "Change your account password",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                                
                                SizedBox(height: 16),
                                
                                Container(
                                  height: 2,
                                  width: 80,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        bloodRed.withOpacity(0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 30),

                          // Form Section
                          _buildGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person, color: bloodRed, size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Account: ${widget.username}",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 25),
                                
                                _buildPasswordField(
                                  label: "Current Password",
                                  controller: oldPassCtrl,
                                  obscureText: _isObscureOld,
                                  onToggle: () => setState(() => _isObscureOld = !_isObscureOld),
                                  prefixIcon: Icons.lock_clock,
                                ),
                                
                                _buildPasswordField(
                                  label: "New Password",
                                  controller: newPassCtrl,
                                  obscureText: _isObscureNew,
                                  onToggle: () => setState(() => _isObscureNew = !_isObscureNew),
                                  prefixIcon: Icons.lock_open,
                                ),
                                
                                _buildPasswordField(
                                  label: "Confirm New Password",
                                  controller: confirmPassCtrl,
                                  obscureText: _isObscureConfirm,
                                  onToggle: () => setState(() => _isObscureConfirm = !_isObscureConfirm),
                                  prefixIcon: Icons.lock_reset,
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 200.ms),

                          SizedBox(height: 30),

                          // Button Section
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  bloodRed.withOpacity(0.9),
                                  darkRed.withOpacity(0.9),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: bloodRed.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: isLoading ? null : _changePassword,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: isLoading
                                        ? [
                                            SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 3,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ]
                                        : [
                                            Icon(Icons.security, color: Colors.white, size: 22),
                                            SizedBox(width: 12),
                                            Text(
                                              "UPDATE PASSWORD",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ],
                                  ),
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 400.ms).scaleXY(
                                begin: 0.95,
                                end: 1,
                                duration: 600.ms,
                              ),

                          SizedBox(height: 20),

                          // Security Tips
                          _buildGlassCard(
                            padding: EdgeInsets.all(20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info, color: bloodRed, size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Security Tips:",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "• Use at least 8 characters\n• Include numbers and special characters\n• Avoid using personal information\n• Don't reuse old passwords",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 600.ms),

                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: bloodRed.withOpacity(0.3)),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms),
        ],
      ),
    );
  }
}