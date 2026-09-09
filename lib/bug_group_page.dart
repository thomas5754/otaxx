import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';
class BugSystem {
  final String id;
  final String name;
  final String description;
  final String icon;
  final int count;
  final int delay;

  BugSystem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.count = 0,
    this.delay = 0,
  });
}

class GroupItem {
  final String id;
  final String name;
  final bool joined;
  final String avatarUrl;
  final int memberCount;
  bool isExpanded;

  GroupItem({
    required this.id,
    required this.name,
    this.joined = false,
    this.avatarUrl = '',
    this.memberCount = 0,
    this.isExpanded = false,
  });

  GroupItem copyWith({bool? isExpanded}) {
    return GroupItem(
      id: id,
      name: name,
      joined: joined,
      avatarUrl: avatarUrl,
      memberCount: memberCount,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }
}

class BugGroupPage extends StatefulWidget {
  final String sessionKey;
  final String role;

  const BugGroupPage({
    super.key,
    required this.sessionKey,
    required this.role,
  });

  @override
  State<BugGroupPage> createState() => _BugGroupPageState();
}

class _BugGroupPageState extends State<BugGroupPage> with SingleTickerProviderStateMixin {
  bool _isSending = false;
  bool _isLoading = false;
  bool _isLoadingBugs = false;
  bool _hasSender = false;
  bool _allExpanded = false;
  GroupItem? _selectedGroup;
  BugSystem? _selectedBug;
  TextEditingController _groupInputController = TextEditingController();
  TextEditingController _searchController = TextEditingController();
  List<GroupItem> _joinedGroups = [];
  List<GroupItem> _filteredGroups = [];
  List<BugSystem> _bugSystems = [];
  int _cooldownTime = 0;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Color Palette - Elegant Dark Theme
  final Color _deepCharcoal = const Color(0xFF0A0A0F);
  final Color _darkSlate = const Color(0xFF121218);
  final Color _carbonBlack = const Color(0xFF1A1A22);
  final Color _obsidian = const Color(0xFF0D0D12);
  final Color _gunmetal = const Color(0xFF1C1C24);
  
  // Accent Colors - Deep, Rich, Sophisticated Reds
  final Color _bloodWine = const Color(0xFF660708);
  final Color _darkCrimson = const Color(0xFF8A0E1B);
  final Color _velvetMaroon = const Color(0xFF9D1D2A);
  final Color _rustRed = const Color(0xFFA41623);
  final Color _emberRed = const Color(0xFFBA181B);
  
  // Gradient Colors
  final Color _gradientStart = const Color(0xFF660708);
  final Color _gradientEnd = const Color(0xFF8A0E1B);
  
  // Neutral Colors
  final Color _platinum = const Color(0xFFF0F0F0);
  final Color _silverGray = const Color(0xFFCCCCCC);
  final Color _steelGray = const Color(0xFF888888);
  final Color _shadowGray = const Color(0xFF444444);
  final Color _glassWhite = const Color(0x20FFFFFF);
  final Color _glassBlack = const Color(0x20000000);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(begin: 0.1, end: 0.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _checkSenderAndGroups();
    _fetchBugSystems();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBugSystems() async {
    setState(() => _isLoadingBugs = true);
    
    try {
      final res = await http.get(
        Uri.parse("http://127.0.0.1:4113/bugGroupSystems"),
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["valid"] == true) {
          final bugSystems = data["bugSystems"] as List?;
          final newBugs = bugSystems?.map((b) => BugSystem(
            id: b["id"] ?? "",
            name: b["name"] ?? "",
            description: b["description"] ?? "",
            icon: b["icon"] ?? "🐛",
            count: b["count"] ?? 0,
            delay: b["delay"] ?? 0,
          )).toList() ?? [];
          
          setState(() {
            _bugSystems = newBugs;
            if (newBugs.isNotEmpty && _selectedBug == null) {
              _selectedBug = newBugs.first;
            }
          });
        }
      }
    } catch (e) {
      print("Error fetching bug systems: $e");
    } finally {
      setState(() => _isLoadingBugs = false);
    }
  }

  Future<void> _checkSenderAndGroups() async {
    setState(() => _isLoading = true);
    
    try {
      final senderRes = await http.get(
        Uri.parse("http://127.0.0.1:4113/mySender?key=${widget.sessionKey}"),
        headers: {'Content-Type': 'application/json'},
      );

      if (senderRes.statusCode == 200) {
        final senderData = jsonDecode(senderRes.body);
        if (senderData["valid"] == true) {
          final connections = senderData["connections"] as List?;
          setState(() {
            _hasSender = connections != null && connections.isNotEmpty;
          });
        }
      }

      if (_hasSender) {
        final groupRes = await http.get(
          Uri.parse("http://127.0.0.1:4113/myGroup?key=${widget.sessionKey}"),
          headers: {'Content-Type': 'application/json'},
        );

        if (groupRes.statusCode == 200) {
          final groupData = jsonDecode(groupRes.body);
          if (groupData["valid"] == true) {
            final groups = groupData["groups"] as List?;
            final newGroups = groups?.map((g) => GroupItem(
              id: g["id"] ?? "",
              name: g["name"] ?? "-",
              joined: true,
              avatarUrl: g["avatar"] ?? "",
              memberCount: g["memberCount"] ?? 0,
              isExpanded: false,
            )).toList() ?? [];
            
            setState(() {
              _joinedGroups = newGroups;
              _filteredGroups = List.from(newGroups);
              if (newGroups.isNotEmpty && _selectedGroup == null) {
                _selectedGroup = newGroups.first;
              }
            });
          }
        }
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterGroups(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredGroups = List.from(_joinedGroups);
      });
      return;
    }

    final filtered = _joinedGroups.where((group) {
      final name = group.name.toLowerCase();
      final id = group.id.toLowerCase();
      final searchLower = query.toLowerCase();
      return name.contains(searchLower) || id.contains(searchLower);
    }).toList();

    setState(() {
      _filteredGroups = filtered;
    });
  }

  void _toggleGroupExpansion(int index) {
    setState(() {
      _filteredGroups[index] = _filteredGroups[index].copyWith(
        isExpanded: !_filteredGroups[index].isExpanded,
      );
    });
  }

  void _toggleAllGroups() {
    setState(() {
      _allExpanded = !_allExpanded;
      for (int i = 0; i < _filteredGroups.length; i++) {
        _filteredGroups[i] = _filteredGroups[i].copyWith(
          isExpanded: _allExpanded,
        );
      }
    });
  }

  Future<void> _joinGroupFromInput() async {
    final input = _groupInputController.text.trim();
    if (input.isEmpty) {
      _showToast("Please enter group JID or link", isError: true);
      return;
    }

    _showElegantLoadingDialog();

    setState(() => _isLoading = true);

    try {
      final res = await http.post(
        Uri.parse("http://127.0.0.1:4113/joinGroup"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'key': widget.sessionKey,
          'groupInput': input,
        }),
      );

      Navigator.pop(context);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["valid"] == true && data["success"] == true) {
          _showElegantSuccessDialog(
            title: "Group Joined",
            message: data["message"] ?? "Successfully joined group"
          );
          _groupInputController.clear();
          _checkSenderAndGroups();
        } else {
          _showElegantErrorDialog(
            title: "Join Failed",
            message: data["message"] ?? "Failed to join group"
          );
        }
      } else {
        _showElegantErrorDialog(
          title: "Server Error",
          message: "Status: ${res.statusCode}"
        );
      }
    } catch (e) {
      _showElegantErrorDialog(
        title: "Connection Error",
        message: "Failed: $e"
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendBugToGroup() async {
    if (!_hasSender) {
      _showToast("No active sender available", isError: true);
      return;
    }

    if (_selectedGroup == null) {
      _showToast("Please select a group first", isError: true);
      return;
    }

    if (_selectedBug == null) {
      _showToast("Please select a bug system", isError: true);
      return;
    }

    _showElegantSendingDialog();

    setState(() {
      _isSending = true;
      _cooldownTime = 0;
    });

    try {
      final res = await http.get(Uri.parse(
          "http://127.0.0.1:4113/sendBugGroup?key=${widget.sessionKey}&group=${_selectedGroup!.id.split("@")[0]}&bugType=${_selectedBug!.id}"));

      Navigator.pop(context);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data["cooldown"] == true) {
          final waitTime = data["wait"] ?? 0;
          setState(() {
            _cooldownTime = waitTime;
          });
          _showToast("Cooldown active: ${waitTime}s", isError: true);
        } else if (data["valid"] == false) {
          _showToast("Invalid session key", isError: true);
        } else if (data["sended"] == true) {
          _showElegantSuccessDialog(
            title: "${_selectedBug!.name} Sent",
            message: "Successfully sent ${_selectedBug!.name} to ${_selectedGroup!.name}"
          );
        } else {
          _showToast("Failed to send bug", isError: true);
        }
      } else {
        _showToast("Server error: ${res.statusCode}", isError: true);
      }
    } catch (e) {
      _showToast("Connection failed: $e", isError: true);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showElegantLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_darkSlate.withOpacity(0.95), _carbonBlack.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _glassWhite, width: 1),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_gradientStart, _gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.group_add_rounded,
                      color: _platinum,
                      size: 32,
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  Text(
                    "Joining Group",
                    style: TextStyle(
                      color: _platinum,
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1,
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

  void _showElegantSendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_darkSlate.withOpacity(0.95), _carbonBlack.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _glassWhite, width: 1),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_gradientStart, _gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: _platinum,
                      size: 36,
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  Text(
                    "Sending ${_selectedBug?.name ?? "Bug"}",
                    style: TextStyle(
                      color: _platinum,
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
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

  void _showElegantSuccessDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_darkSlate.withOpacity(0.95), _carbonBlack.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 60),
                  
                  SizedBox(height: 32),
                  
                  Text(
                    title,
                    style: TextStyle(
                      color: _platinum,
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: 16),
                  
                  Text(
                    message,
                    style: TextStyle(
                      color: _silverGray.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showElegantErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_darkSlate.withOpacity(0.95), _carbonBlack.withOpacity(0.95)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _darkCrimson.withOpacity(0.3), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: _gradientEnd, size: 60),
                  
                  SizedBox(height: 32),
                  
                  Text(
                    title,
                    style: TextStyle(
                      color: _platinum,
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  SizedBox(height: 16),
                  
                  Text(
                    message,
                    style: TextStyle(
                      color: _silverGray.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? _gradientStart.withOpacity(0.9) : _shadowGray.withOpacity(0.9),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: _platinum,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: _platinum),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: 3),
        elevation: 20,
        margin: EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildBugSystemCard(BugSystem bug) {
    bool isSelected = _selectedBug?.id == bug.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBug = bug;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 400),
        width: 220,
        margin: EdgeInsets.only(right: 16, bottom: 8),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [_gradientStart, _gradientEnd]
                : [_carbonBlack, _gunmetal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _platinum.withOpacity(0.3) : _shadowGray,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _obsidian.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _glassWhite, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      bug.icon,
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_platinum, _silverGray],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _platinum.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: _gradientStart,
                      size: 16,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              bug.name,
              style: TextStyle(
                color: _platinum,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 6),
            Text(
              bug.description,
              style: TextStyle(
                color: _silverGray.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w300,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(int index) {
    GroupItem group = _filteredGroups[index];
    bool isSelected = _selectedGroup?.id == group.id;
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isSelected
                  ? [_carbonBlack, _gunmetal]
                  : [_darkSlate, _carbonBlack],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Group Header (Always Visible)
              GestureDetector(
                onTap: () => _toggleGroupExpansion(index),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: group.isExpanded ? _gradientStart.withOpacity(0.2) : Colors.transparent,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Group Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_gradientStart, _gradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _gradientStart.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.group_rounded,
                            color: _platinum,
                            size: 22,
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 16),
                      
                      // Group Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: TextStyle(
                                      color: _platinum,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    "JOINED",
                                    style: TextStyle(
                                      color: Colors.green.shade300,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 6),
                            
                            Row(
                              children: [
                                Icon(
                                  Icons.people_alt_outlined,
                                  color: _steelGray,
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "${group.memberCount} members",
                                  style: TextStyle(
                                    color: _steelGray,
                                    fontSize: 13,
                                  ),
                                ),
                                Spacer(),
                                AnimatedRotation(
                                  turns: group.isExpanded ? 0.5 : 0,
                                  duration: Duration(milliseconds: 300),
                                  child: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: _steelGray,
                                    size: 20,
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
              ),
              
              // Expandable Content
              AnimatedCrossFade(
                duration: Duration(milliseconds: 300),
                crossFadeState: group.isExpanded 
                    ? CrossFadeState.showFirst 
                    : CrossFadeState.showSecond,
                firstChild: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _glassBlack,
                  ),
                  child: Column(
                    children: [
                      // Group ID
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _obsidian,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _glassWhite.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.fingerprint_outlined,
                              color: _steelGray,
                              size: 16,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Group ID",
                                    style: TextStyle(
                                      color: _steelGray,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    group.id,
                                    style: TextStyle(
                                      color: _silverGray,
                                      fontSize: 12,
                                      fontFamily: 'Monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Select Button
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: isSelected
                                    ? LinearGradient(
                                        colors: [_gradientStart, _gradientEnd],
                                      )
                                    : LinearGradient(
                                        colors: [_shadowGray, _steelGray],
                                      ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _gradientStart.withOpacity(0.3),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                          offset: Offset(0, 3),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedGroup = group;
                                  });
                                },
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                      color: _platinum,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      isSelected ? "SELECTED" : "SELECT GROUP",
                                      style: TextStyle(
                                        color: _platinum,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                secondChild: SizedBox(height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _carbonBlack,
                  _gunmetal,
                ],
                stops: [0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              Icons.group_off_rounded,
              color: _steelGray,
              size: 50,
            ),
          ),
          
          SizedBox(height: 24),
          
          Text(
            "No Groups Available",
            style: TextStyle(
              color: _platinum,
              fontSize: 20,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
          
          SizedBox(height: 12),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Connect a WhatsApp sender and join groups to start sending bugs",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _silverGray.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w300,
                height: 1.6,
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
      backgroundColor: _obsidian,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_deepCharcoal, _obsidian, _deepCharcoal],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Elegant App Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_darkSlate.withOpacity(0.9), _carbonBlack.withOpacity(0.9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: _glassWhite.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [_gradientStart, _gradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _gradientStart.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.groups_rounded,
                        color: _platinum,
                        size: 22,
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Bug Groups",
                            style: TextStyle(
                              color: _platinum,
                              fontSize: 18,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.5,
                            ),
                          ),
                          
                          SizedBox(height: 4),
                          
                          Text(
                            _hasSender 
                                ? "${_joinedGroups.length} groups • ${widget.role}"
                                : "No sender connected",
                            style: TextStyle(
                              color: _hasSender ? Colors.green.shade300 : _steelGray,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    IconButton(
                      onPressed: _checkSenderAndGroups,
                      icon: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_gunmetal, _shadowGray],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isLoading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                          color: _platinum,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content Area
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Join Group Section
                      Container(
                        padding: EdgeInsets.all(20),
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_carbonBlack.withOpacity(0.8), _gunmetal.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _glassWhite.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.add_circle_outlined,
                                  color: _gradientEnd,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "Join New Group",
                                  style: TextStyle(
                                    color: _platinum,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(height: 16),
                            
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _groupInputController,
                                style: TextStyle(
                                  color: _platinum,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Enter group JID or link...",
                                  hintStyle: TextStyle(
                                    color: _steelGray.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w300,
                                  ),
                                  prefixIcon: Container(
                                    padding: EdgeInsets.only(left: 16, right: 12),
                                    child: Icon(
                                      Icons.link_rounded,
                                      color: _steelGray,
                                      size: 20,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: _darkSlate,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 16),
                            
                            Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [_gradientStart, _gradientEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _gradientStart.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: _isLoading ? null : _joinGroupFromInput,
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _platinum,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_rounded,
                                            color: _platinum,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            "JOIN GROUP",
                                            style: TextStyle(
                                              color: _platinum,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
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

                      // Search Section
                      if (_joinedGroups.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(16),
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_carbonBlack.withOpacity(0.8), _gunmetal.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _glassWhite.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: _gradientEnd,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _filterGroups,
                                  style: TextStyle(
                                    color: _platinum,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w300,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Search groups...",
                                    hintStyle: TextStyle(
                                      color: _steelGray.withOpacity(0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w300,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterGroups('');
                                  },
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: _steelGray,
                                    size: 18,
                                  ),
                                ),
                              IconButton(
                                onPressed: _toggleAllGroups,
                                icon: Icon(
                                  _allExpanded ? Icons.unfold_less : Icons.unfold_more,
                                  color: _gradientEnd,
                                  size: 20,
                                ),
                                tooltip: _allExpanded ? "Collapse All" : "Expand All",
                              ),
                            ],
                          ),
                        ),

                        // Groups List Header
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.list_alt_rounded,
                                    color: _gradientEnd,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Your Groups",
                                    style: TextStyle(
                                      color: _platinum,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _glassBlack,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _glassWhite.withOpacity(0.1)),
                                ),
                                child: Text(
                                  "${_filteredGroups.length} groups",
                                  style: TextStyle(
                                    color: _silverGray,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Groups List (Accordion Style)
                        _filteredGroups.isEmpty
                            ? Container(
                                height: 150,
                                margin: EdgeInsets.only(top: 20),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        color: _steelGray,
                                        size: 50,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        "No groups found",
                                        style: TextStyle(
                                          color: _platinum,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _filteredGroups.length,
                                itemBuilder: (context, index) {
                                  return _buildGroupCard(index);
                                },
                              ),

                        SizedBox(height: 24),

                        // Bug Systems Section (Only when group is selected)
                        if (_selectedGroup != null && _filteredGroups.isNotEmpty) ...[
                          Container(
                            padding: EdgeInsets.all(20),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_carbonBlack.withOpacity(0.8), _gunmetal.withOpacity(0.8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _glassWhite.withOpacity(0.1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Icon(
                                      Icons.bug_report_rounded,
                                      color: _gradientEnd,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Bug Systems",
                                            style: TextStyle(
                                              color: _platinum,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "Selected: ${_selectedGroup!.name}",
                                            style: TextStyle(
                                              color: _steelGray,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 16),

                                // Bug Systems Carousel
                                _isLoadingBugs
                                    ? Container(
                                        height: 120,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: _gradientEnd,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 140,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: _bugSystems.length,
                                          itemBuilder: (context, index) {
                                            return _buildBugSystemCard(_bugSystems[index]);
                                          },
                                        ),
                                      ),

                                SizedBox(height: 20),

                                // Send Bug Button
                                Container(
                                  width: double.infinity,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: _cooldownTime > 0 || _selectedBug == null
                                        ? LinearGradient(colors: [_shadowGray, _steelGray])
                                        : LinearGradient(
                                            colors: [_gradientStart, _gradientEnd],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    boxShadow: _cooldownTime > 0 || _selectedBug == null
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: _gradientStart.withOpacity(0.4),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                              offset: Offset(0, 4),
                                            ),
                                          ],
                                  ),
                                  child: TextButton(
                                    onPressed: _isSending || _cooldownTime > 0 || _selectedBug == null
                                        ? null
                                        : _sendBugToGroup,
                                    style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isSending
                                        ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: _platinum,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _cooldownTime > 0
                                                    ? Icons.timer_outlined
                                                    : Icons.send_rounded,
                                                color: _platinum,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                _cooldownTime > 0
                                                    ? "WAIT ${_cooldownTime}s"
                                                    : "SEND ${_selectedBug?.name?.toUpperCase() ?? "BUG"}",
                                                style: TextStyle(
                                                  color: _platinum,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
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
                        ],
                      ] else ...[
                        // Empty State
                        _buildEmptyState(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}