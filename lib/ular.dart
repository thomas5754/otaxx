import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> with TickerProviderStateMixin {
  static const int gridWidth = 20;
  static const int gridHeight = 40;

  late List<List<int>> snake;
  late List<int> food;
  late String direction;
  late String nextDirection;
  bool isPlaying = false;
  bool isPaused = false;
  late Timer gameTimer;
  int score = 0;
  int highScore = 0;
  late AnimationController pulseController;

  final Random rng = Random();

  // Difficulty settings
  String currentDifficulty = 'Medium';
  final List<String> difficulties = ['Easy', 'Medium', 'Hard'];
  final Map<String, int> speedMap = {
    'Easy': 180,
    'Medium': 120,
    'Hard': 70,
  };

  @override
  void initState() {
    super.initState();
    _resetGame();
    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  void _resetGame() {
    snake = [
      [(gridWidth / 2).floor(), (gridHeight / 2).floor()],
      [(gridWidth / 2).floor(), (gridHeight / 2).floor() - 1],
    ];
    direction = 'up';
    nextDirection = 'up';
    score = 0;
    _generateFood();
  }

  void _generateFood() {
    do {
      food = [rng.nextInt(gridWidth), rng.nextInt(gridHeight)];
    } while (snake.any((segment) => segment[0] == food[0] && segment[1] == food[1]));
  }

  void startGame() {
    if (isPlaying) return;
    _resetGame();
    isPlaying = true;
    isPaused = false;
    final speed = speedMap[currentDifficulty] ?? 120;
    gameTimer = Timer.periodic(Duration(milliseconds: speed), (_) => _updateGame());
  }

  void pauseGame() {
    if (!isPlaying) return;
    setState(() => isPaused = !isPaused);
    if (isPaused) {
      gameTimer.cancel();
    } else {
      final speed = speedMap[currentDifficulty] ?? 120;
      gameTimer = Timer.periodic(Duration(milliseconds: speed), (_) => _updateGame());
    }
  }

  void _updateGame() {
    if (!isPlaying || isPaused) return;
    setState(() {
      direction = nextDirection;

      switch (direction) {
        case 'up':
          snake.insert(0, [snake.first[0], snake.first[1] - 1]);
          break;
        case 'down':
          snake.insert(0, [snake.first[0], snake.first[1] + 1]);
          break;
        case 'left':
          snake.insert(0, [snake.first[0] - 1, snake.first[1]]);
          break;
        case 'right':
          snake.insert(0, [snake.first[0] + 1, snake.first[1]]);
          break;
      }

      if (snake.first[0] == food[0] && snake.first[1] == food[1]) {
        score++;
        if (score > highScore) highScore = score;
        _generateFood();
        HapticFeedback.lightImpact();
      } else {
        snake.removeLast();
      }

      if (_isGameOver()) {
        _endGame();
      }
    });
  }

  bool _isGameOver() {
    if (snake.first[0] < 0 ||
        snake.first[0] >= gridWidth ||
        snake.first[1] < 0 ||
        snake.first[1] >= gridHeight) {
      return true;
    }
    for (int i = 1; i < snake.length; i++) {
      if (snake[i][0] == snake.first[0] && snake[i][1] == snake.first[1]) {
        return true;
      }
    }
    return false;
  }

  void _endGame() {
    isPlaying = false;
    isPaused = false;
    gameTimer.cancel();
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(width: 12),
            const Text(
              'Game Over',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreRow('Skor', score),
            const SizedBox(height: 8),
            _buildScoreRow('Tertinggi', highScore),
            const SizedBox(height: 16),
            Text(
              'Kembali ke tools?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
              startGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Main Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, int value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    if (isPlaying) gameTimer.cancel();
    pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0B0C10),
                  const Color(0xFF1A1C22),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _NoisePainter(),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFDC143C), Color(0xFFE0115F)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.catching_pokemon, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'ULAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Skor ',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                            ),
                            Text(
                              '$score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Difficulty selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Level',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: difficulties.map((level) {
                            final isSelected = currentDifficulty == level;
                            return GestureDetector(
                              onTap: isPlaying || isPaused
                                  ? null
                                  : () {
                                      setState(() {
                                        currentDifficulty = level;
                                      });
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.redAccent.withOpacity(0.3)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(30),
                                  border: isSelected
                                      ? Border.all(color: Colors.redAccent, width: 0.8)
                                      : null,
                                ),
                                child: Text(
                                  level,
                                  style: TextStyle(
                                    color: isSelected ? Colors.redAccent : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                // Game area
                Expanded(
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (details.delta.dy > 0 && direction != 'up') {
                        nextDirection = 'down';
                      } else if (details.delta.dy < 0 && direction != 'down') {
                        nextDirection = 'up';
                      }
                    },
                    onHorizontalDragUpdate: (details) {
                      if (details.delta.dx > 0 && direction != 'left') {
                        nextDirection = 'right';
                      } else if (details.delta.dx < 0 && direction != 'right') {
                        nextDirection = 'left';
                      }
                    },
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: gridWidth / gridHeight,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridWidth,
                          ),
                          itemCount: gridWidth * gridHeight,
                          itemBuilder: (context, index) {
                            final x = index % gridWidth;
                            final y = index ~/ gridWidth;

                            Color? cellColor;
                            bool isHead = snake.isNotEmpty && snake.first[0] == x && snake.first[1] == y;
                            bool isBody = snake.any((seg) => seg[0] == x && seg[1] == y) && !isHead;
                            bool isFood = food[0] == x && food[1] == y;

                            if (isHead) {
                              cellColor = Colors.greenAccent;
                            } else if (isBody) {
                              cellColor = Colors.green[400];
                            } else if (isFood) {
                              cellColor = Colors.redAccent;
                            } else {
                              cellColor = Colors.grey[900];
                            }

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 80),
                              margin: const EdgeInsets.all(1.2),
                              decoration: BoxDecoration(
                                color: cellColor,
                                shape: BoxShape.circle,
                                boxShadow: isHead
                                    ? [
                                        BoxShadow(
                                          color: Colors.greenAccent.withOpacity(0.6),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : isFood
                                        ? [
                                            BoxShadow(
                                              color: Colors.redAccent.withOpacity(pulseController.value * 0.5),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                // Control panel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: isPlaying ? Icons.pause : Icons.play_arrow,
                        label: isPlaying ? 'Pause' : 'Start',
                        color: isPlaying ? Colors.orangeAccent : Colors.greenAccent,
                        onPressed: () {
                          if (!isPlaying) {
                            startGame();
                          } else {
                            pauseGame();
                          }
                        },
                      ),
                      _buildControlButton(
                        icon: Icons.refresh,
                        label: 'Reset',
                        color: Colors.blueAccent,
                        onPressed: () {
                          if (isPlaying) {
                            gameTimer.cancel();
                            isPlaying = false;
                            isPaused = false;
                          }
                          _resetGame();
                          setState(() {});
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '$highScore',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        splashColor: color.withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.01)
      ..style = PaintingStyle.fill;
    final random = Random(42);
    for (int i = 0; i < 300; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}