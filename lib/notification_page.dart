import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<dynamic> _notifications = [];

  final Color bloodRed = const Color(0xFFD32F2F);
  final Color deepBlack = const Color(0xFF0D0D0D);
  final Color cardDark = const Color(0xFF1C1C1C);

  late AnimationController _anim;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.get(
        Uri.parse("http://127.0.0.1:4113/notify/list"),
      );

      if (res.statusCode != 200) {
        throw "Failed to load";
      }

      final data = jsonDecode(res.body);
      _notifications = data["notifications"] ?? [];

      _anim.forward(from: 0);
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Widget _buildCard(Map n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark.withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bloodRed.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: bloodRed.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n["title"] ?? "Notification",
            style: TextStyle(
              color: bloodRed,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            n["message"] ?? "",
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Text(
            n["createdAt"] ?? "",
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
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
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: bloodRed,
        onRefresh: _fetchNotifications,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 200),
                      Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  )
                : _notifications.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 200),
                          Center(
                            child: Text(
                              "No notifications",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        ],
                      )
                    : FadeTransition(
                        opacity: _fade,
                        child: ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (_, i) =>
                              _buildCard(_notifications[i]),
                        ),
                      ),
      ),
    );
  }
}