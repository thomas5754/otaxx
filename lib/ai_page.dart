import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AIPage extends StatefulWidget {
  final String sessionKey;
  final String username;
  final String role;

  const AIPage({
    Key? key,
    required this.sessionKey,
    required this.username,
    required this.role,
  }) : super(key: key);

  @override
  _AIPageState createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String prompt) async {
    if (prompt.trim().isEmpty) return;

    // Tambahkan pesan user ke list
    setState(() {
      _messages.add({'role': 'user', 'content': prompt});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final uri = Uri.parse(
          'https://api.siputzx.my.id/api/ai/gemini-lite?prompt=${Uri.encodeComponent(prompt)}&model=gemini-2.0-flash-lite');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final aiResponse = json['data']['parts'][0]['text'] ?? 'Maaf, tidak ada respons.';
        setState(() {
          _messages.add({'role': 'assistant', 'content': aiResponse});
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'content': 'Error: Gagal terhubung ke server (${response.statusCode})'
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'assistant', 'content': 'Exception: $e'});
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Minimal AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OTAX AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Gemini 2.0 Flash Lite',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white, size: 22),
                    onPressed: () {
                      setState(() => _messages.clear());
                    },
                  ),
                ],
              ),
            ),

            // Area Chat
            Expanded(
              child: Container(
                color: Colors.black,
                child: _messages.isEmpty && !_isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[800],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Mulai percakapan dengan AI',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isLoading) {
                            return _buildLoadingIndicator();
                          }
                          final msg = _messages[index];
                          final isUser = msg['role'] == 'user';
                          return _buildMessageBubble(msg['content'], isUser);
                        },
                      ),
              ),
            ),

            // Input Area
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(
                  top: BorderSide(color: Colors.grey[800]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tanyakan sesuatu...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[900],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4CAF50),
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),

            // Minimal Online Indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'OTAX AI Assistant • Online',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Info Button
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: Colors.black.withOpacity(0.7),
        onPressed: () => _showInfoDialog(),
        child: const Icon(Icons.info_outline, color: Colors.white, size: 18),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF4CAF50) : Colors.grey[900],
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.black : Colors.white,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'AI sedang mengetik...',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'OTAX AI Assistant',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Powered by Gemini 2.0 Flash Lite',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('User:', widget.username),
                    _buildInfoRow('Role:', widget.role),
                    _buildInfoRow('Session:', '${widget.sessionKey.substring(0, 8)}...'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('CLOSE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}