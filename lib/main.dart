import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'login_page.dart';
import 'dashboard_page.dart';
import 'home_page.dart';
import 'seller_page.dart';
import 'admin_page.dart';
import 'landing.dart';

String baseUrl = "http://127.0.0.1:4113";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadConfig();

  runApp(const MyApp());
}
Future<void> loadConfig() async {
  while (true) {
    try {
      final githubRes = await http
          .get(Uri.parse(
              "https://raw.githubusercontent.com/otaxXOne/OTAX-APP/refs/heads/main/config.json"))
          .timeout(const Duration(seconds: 8));

      if (githubRes.statusCode == 200) {
        final data = jsonDecode(githubRes.body);
        if (data["base_url"] != null &&
            data["base_url"].toString().isNotEmpty) {
          baseUrl = data["base_url"];
          return;
        }
      }
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 3));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OTAX',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'ShareTechMono',
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark().copyWith(
          secondary: Colors.purple,
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {

          case '/':
            return MaterialPageRoute(builder: (_) => const LandingPage());

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());

          case '/dashboard':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => DashboardPage(
                username: args['username'] ?? '',
                password: args['password'] ?? '',
                role: args['role'] ?? '',
                sessionKey: args['key'] ?? '',
                expiredDate: args['expiredDate'] ?? '',
                listBug: List<Map<String, dynamic>>.from(args['listBug'] ?? []),
                listDoos: List<Map<String, dynamic>>.from(args['listDoos'] ?? []),
                news: List<Map<String, dynamic>>.from(args['news'] ?? []),
              ),
            );

          case '/home':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => HomePage(
                username: args['username'] ?? '',
                password: args['password'] ?? '',
                listBug: List<Map<String, dynamic>>.from(args['listBug'] ?? []),
                role: args['role'] ?? '',
                expiredDate: args['expiredDate'] ?? '',
                sessionKey: args['sessionKey'] ?? '',
              ),
            );

          case '/seller':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => SellerPage(
                keyToken: args['keyToken'] ?? '',
              ),
            );

          case '/admin':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            return MaterialPageRoute(
              builder: (_) => AdminPage(
                sessionKey: args['sessionKey'] ?? '',
              ),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text("404 - Not Found")),
              ),
            );
        }
      },
    );
  }
}