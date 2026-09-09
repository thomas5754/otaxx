// lib/widgets/game_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_monitor_service.dart';
import '../services/vpn_packet_capture.dart';

class GameOverlay extends StatefulWidget {
  final AppMonitorService monitorService;
  final VPNPacketCapture vpnService;
  final VoidCallback onAttackPressed;
  final VoidCallback onClosePressed;
  
  const GameOverlay({
    Key? key,
    required this.monitorService,
    required this.vpnService,
    required this.onAttackPressed,
    required this.onClosePressed,
  }) : super(key: key);

  @override
  State<GameOverlay> createState() => _GameOverlayState();
}

class _GameOverlayState extends State<GameOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  Offset _position = const Offset(50, 100);
  bool _isDragging = false;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.monitorService.isGameRunning,
      builder: (context, isGameRunning, child) {
        if (!isGameRunning) return const SizedBox.shrink();
        
        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: Draggable(
            onDragStarted: () => setState(() => _isDragging = true),
            onDragEnd: (details) => setState(() => _isDragging = false),
            onDraggableCanceled: (velocity, offset) {
              setState(() {
                _position = offset;
                _isDragging = false;
              });
            },
            feedback: _buildOverlayContent(),
            childWhenDragging: Opacity(
              opacity: 0.7,
              child: _buildOverlayContent(),
            ),
            child: _buildOverlayContent(),
          ),
        );
      },
    );
  }
  
  Widget _buildOverlayContent() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.red.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header dengan drag handle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.drag_handle, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ML Auto-Detect',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onClosePressed,
                  ),
                ],
              ),
            ),
            
            // Body
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // Status Game
                  _buildStatusRow(
                    'Game Status',
                    'Mobile Legends',
                    Icons.sports_esports,
                    Colors.greenAccent,
                  ),
                  const SizedBox(height: 8),
                  
                  // Status Capture
                  ValueListenableBuilder<bool>(
                    valueListenable: widget.vpnService.isCapturing,
                    builder: (context, isCapturing, child) {
                      return _buildStatusRow(
                        'Packet Capture',
                        isCapturing ? 'Active' : 'Standby',
                        Icons.network_check,
                        isCapturing ? Colors.green : Colors.orange,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  
                  // Detected IP
                  ValueListenableBuilder<String?>(
                    valueListenable: widget.vpnService.detectedServerIP,
                    builder: (context, serverIP, child) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: serverIP != null 
                                ? Colors.green 
                                : Colors.grey.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.dns,
                              color: serverIP != null ? Colors.green : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                serverIP ?? 'No IP detected',
                                style: TextStyle(
                                  color: serverIP != null ? Colors.white : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Attack Button
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: ElevatedButton(
                      onPressed: widget.vpnService.detectedServerIP.value != null 
                          ? widget.onAttackPressed 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'LAUNCH ATTACK',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
  
  Widget _buildStatusRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}