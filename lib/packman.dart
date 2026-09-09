import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class PacmanGamePage extends StatefulWidget {
  const PacmanGamePage({super.key});

  @override
  State<PacmanGamePage> createState() => _PacmanGamePageState();
}

class _PacmanGamePageState extends State<PacmanGamePage> {
  static const int gridColumns = 11;
  static const int totalCells = gridColumns * 16;

  int playerPos = gridColumns * 14 + 1;
  int ghostPos = gridColumns * 2 - 2;
  int ghost2Pos = gridColumns * 9 - 1;
  int ghost3Pos = gridColumns * 11 - 2;

  bool preGame = true;
  bool mouthClosed = false;
  bool paused = false;
  int score = 0;

  String direction = "right";
  String ghostLast = "left";
  String ghostLast2 = "left";
  String ghostLast3 = "down";

  Timer? moveTimer;
  Timer? ghostTimer;
  Timer? collisionTimer;

  final AudioPlayer bgPlayer = AudioPlayer();
  final AudioPlayer fxPlayer = AudioPlayer();

  final List<int> barriers = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 22, 33, 44, 55, 66, 77, 99, 110,
    121, 132, 143, 154, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175,
    164, 153, 142, 131, 120, 109, 87, 76, 65, 54, 43, 32, 21, 78, 79, 80, 100,
    101, 102, 84, 85, 86, 106, 107, 108, 24, 35, 46, 57, 30, 41, 52, 63, 81,
    70, 59, 61, 72, 83, 26, 28, 37, 38, 39, 123, 134, 145, 129, 140, 151, 103,
    114, 125, 105, 116, 127, 147, 148, 149,
  ];

  final List<int> food = [];

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  @override
  void dispose() {
    moveTimer?.cancel();
    ghostTimer?.cancel();
    collisionTimer?.cancel();
    bgPlayer.dispose();
    fxPlayer.dispose();
    super.dispose();
  }

  void _initGame() {
    _generateFood();
    _playSound('pacman_beginning.wav', loop: true);
    preGame = false;

    moveTimer = Timer.periodic(const Duration(milliseconds: 170), (_) {
      if (!paused) _movePlayer();
    });

    ghostTimer = Timer.periodic(const Duration(milliseconds: 190), (_) {
      if (!paused) {
        _moveGhost();
        _moveGhost2();
        _moveGhost3();
      }
    });

    collisionTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (paused) return;
      _checkCollision();
      _checkEatFood();
    });
  }

  void _generateFood() {
    food.clear();
    for (int i = 0; i < totalCells; i++) {
      if (!barriers.contains(i)) food.add(i);
    }
  }

  void _movePlayer() {
    setState(() => mouthClosed = !mouthClosed);

    switch (direction) {
      case "left":
        if (!barriers.contains(playerPos - 1)) playerPos--;
        break;
      case "right":
        if (!barriers.contains(playerPos + 1)) playerPos++;
        break;
      case "up":
        if (!barriers.contains(playerPos - gridColumns)) playerPos -= gridColumns;
        break;
      case "down":
        if (!barriers.contains(playerPos + gridColumns)) playerPos += gridColumns;
        break;
    }
  }

  void _moveGhost() {
    switch (ghostLast) {
      case "left":
        if (!barriers.contains(ghostPos - 1)) {
          ghostPos--;
        } else {
          if (!barriers.contains(ghostPos + gridColumns)) {
            ghostPos += gridColumns;
            ghostLast = "down";
          } else if (!barriers.contains(ghostPos + 1)) {
            ghostPos++;
            ghostLast = "right";
          } else if (!barriers.contains(ghostPos - gridColumns)) {
            ghostPos -= gridColumns;
            ghostLast = "up";
          }
        }
        break;
      case "right":
        if (!barriers.contains(ghostPos + 1)) {
          ghostPos++;
        } else {
          if (!barriers.contains(ghostPos - gridColumns)) {
            ghostPos -= gridColumns;
            ghostLast = "up";
          } else if (!barriers.contains(ghostPos + gridColumns)) {
            ghostPos += gridColumns;
            ghostLast = "down";
          } else if (!barriers.contains(ghostPos - 1)) {
            ghostPos--;
            ghostLast = "left";
          }
        }
        break;
      case "up":
        if (!barriers.contains(ghostPos - gridColumns)) {
          ghostPos -= gridColumns;
          ghostLast = "up";
        } else {
          if (!barriers.contains(ghostPos + 1)) {
            ghostPos++;
            ghostLast = "right";
          } else if (!barriers.contains(ghostPos - 1)) {
            ghostPos--;
            ghostLast = "left";
          } else if (!barriers.contains(ghostPos + gridColumns)) {
            ghostPos += gridColumns;
            ghostLast = "down";
          }
        }
        break;
      case "down":
        if (!barriers.contains(ghostPos + gridColumns)) {
          ghostPos += gridColumns;
          ghostLast = "down";
        } else {
          if (!barriers.contains(ghostPos - 1)) {
            ghostPos--;
            ghostLast = "left";
          } else if (!barriers.contains(ghostPos + 1)) {
            ghostPos++;
            ghostLast = "right";
          } else if (!barriers.contains(ghostPos - gridColumns)) {
            ghostPos -= gridColumns;
            ghostLast = "up";
          }
        }
        break;
    }
  }

  void _moveGhost2() {
    switch (ghostLast2) {
      case "left":
        if (!barriers.contains(ghost2Pos - 1)) {
          ghost2Pos--;
        } else {
          if (!barriers.contains(ghost2Pos + gridColumns)) {
            ghost2Pos += gridColumns;
            ghostLast2 = "down";
          } else if (!barriers.contains(ghost2Pos + 1)) {
            ghost2Pos++;
            ghostLast2 = "right";
          } else if (!barriers.contains(ghost2Pos - gridColumns)) {
            ghost2Pos -= gridColumns;
            ghostLast2 = "up";
          }
        }
        break;
      case "right":
        if (!barriers.contains(ghost2Pos + 1)) {
          ghost2Pos++;
        } else {
          if (!barriers.contains(ghost2Pos - gridColumns)) {
            ghost2Pos -= gridColumns;
            ghostLast2 = "up";
          } else if (!barriers.contains(ghost2Pos + gridColumns)) {
            ghost2Pos += gridColumns;
            ghostLast2 = "down";
          } else if (!barriers.contains(ghost2Pos - 1)) {
            ghost2Pos--;
            ghostLast2 = "left";
          }
        }
        break;
      case "up":
        if (!barriers.contains(ghost2Pos - gridColumns)) {
          ghost2Pos -= gridColumns;
          ghostLast2 = "up";
        } else {
          if (!barriers.contains(ghost2Pos + 1)) {
            ghost2Pos++;
            ghostLast2 = "right";
          } else if (!barriers.contains(ghost2Pos - 1)) {
            ghost2Pos--;
            ghostLast2 = "left";
          } else if (!barriers.contains(ghost2Pos + gridColumns)) {
            ghost2Pos += gridColumns;
            ghostLast2 = "down";
          }
        }
        break;
      case "down":
        if (!barriers.contains(ghost2Pos + gridColumns)) {
          ghost2Pos += gridColumns;
          ghostLast2 = "down";
        } else {
          if (!barriers.contains(ghost2Pos - 1)) {
            ghost2Pos--;
            ghostLast2 = "left";
          } else if (!barriers.contains(ghost2Pos + 1)) {
            ghost2Pos++;
            ghostLast2 = "right";
          } else if (!barriers.contains(ghost2Pos - gridColumns)) {
            ghost2Pos -= gridColumns;
            ghostLast2 = "up";
          }
        }
        break;
    }
  }

  void _moveGhost3() {
    switch (ghostLast3) {
      case "left":
        if (!barriers.contains(ghost3Pos - 1)) {
          ghost3Pos--;
        } else {
          if (!barriers.contains(ghost3Pos + gridColumns)) {
            ghost3Pos += gridColumns;
            ghostLast3 = "down";
          } else if (!barriers.contains(ghost3Pos + 1)) {
            ghost3Pos++;
            ghostLast3 = "right";
          } else if (!barriers.contains(ghost3Pos - gridColumns)) {
            ghost3Pos -= gridColumns;
            ghostLast3 = "up";
          }
        }
        break;
      case "right":
        if (!barriers.contains(ghost3Pos + 1)) {
          ghost3Pos++;
        } else {
          if (!barriers.contains(ghost3Pos - gridColumns)) {
            ghost3Pos -= gridColumns;
            ghostLast3 = "up";
          } else if (!barriers.contains(ghost3Pos + gridColumns)) {
            ghost3Pos += gridColumns;
            ghostLast3 = "down";
          } else if (!barriers.contains(ghost3Pos - 1)) {
            ghost3Pos--;
            ghostLast3 = "left";
          }
        }
        break;
      case "up":
        if (!barriers.contains(ghost3Pos - gridColumns)) {
          ghost3Pos -= gridColumns;
          ghostLast3 = "up";
        } else {
          if (!barriers.contains(ghost3Pos + 1)) {
            ghost3Pos++;
            ghostLast3 = "right";
          } else if (!barriers.contains(ghost3Pos - 1)) {
            ghost3Pos--;
            ghostLast3 = "left";
          } else if (!barriers.contains(ghost3Pos + gridColumns)) {
            ghost3Pos += gridColumns;
            ghostLast3 = "down";
          }
        }
        break;
      case "down":
        if (!barriers.contains(ghost3Pos + gridColumns)) {
          ghost3Pos += gridColumns;
          ghostLast3 = "down";
        } else {
          if (!barriers.contains(ghost3Pos - 1)) {
            ghost3Pos--;
            ghostLast3 = "left";
          } else if (!barriers.contains(ghost3Pos + 1)) {
            ghost3Pos++;
            ghostLast3 = "right";
          } else if (!barriers.contains(ghost3Pos - gridColumns)) {
            ghost3Pos -= gridColumns;
            ghostLast3 = "up";
          }
        }
        break;
    }
  }

  void _checkCollision() {
    if (playerPos == ghostPos || playerPos == ghost2Pos || playerPos == ghost3Pos) {
      _gameOver();
    }
  }

  void _checkEatFood() {
    if (food.contains(playerPos)) {
      _playSound('pacman_chomp.wav');
      setState(() {
        food.remove(playerPos);
        score++;
      });
    }
  }

  void _gameOver() {
    bgPlayer.stop();
    _playSound('pacman_death.wav');
    setState(() => playerPos = -1);
    moveTimer?.cancel();
    ghostTimer?.cancel();
    collisionTimer?.cancel();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text('GAME OVER', style: TextStyle(fontWeight: FontWeight.bold))),
        content: Text('Your Score: $score', textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: _restartGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('PLAY AGAIN'),
            ),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    Navigator.pop(context);
    setState(() {
      playerPos = gridColumns * 14 + 1;
      ghostPos = gridColumns * 2 - 2;
      ghost2Pos = gridColumns * 9 - 1;
      ghost3Pos = gridColumns * 11 - 2;
      direction = "right";
      ghostLast = "left";
      ghostLast2 = "left";
      ghostLast3 = "down";
      mouthClosed = false;
      preGame = false;
      paused = false;
      score = 0;
    });

    _generateFood();
    _playSound('pacman_beginning.wav', loop: true);

    moveTimer = Timer.periodic(const Duration(milliseconds: 170), (_) {
      if (!paused) _movePlayer();
    });
    ghostTimer = Timer.periodic(const Duration(milliseconds: 190), (_) {
      if (!paused) {
        _moveGhost();
        _moveGhost2();
        _moveGhost3();
      }
    });
    collisionTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (paused) return;
      _checkCollision();
      _checkEatFood();
    });
  }

  Future<void> _playSound(String fileName, {bool loop = false}) async {
    try {
      final player = fileName.contains('beginning') ? bgPlayer : fxPlayer;
      await player.setSource(AssetSource('assets/$fileName'));
      if (loop) await player.setReleaseMode(ReleaseMode.loop);
      await player.resume();
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void _togglePause() {
    setState(() => paused = !paused);
    if (paused) {
      bgPlayer.pause();
      _playSound('pacman_intermission.wav', loop: true);
    } else {
      bgPlayer.resume();
      fxPlayer.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 8,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (details.delta.dy > 0) {
                    direction = "down";
                  } else if (details.delta.dy < 0) {
                    direction = "up";
                  }
                },
                onHorizontalDragUpdate: (details) {
                  if (details.delta.dx > 0) {
                    direction = "right";
                  } else if (details.delta.dx < 0) {
                    direction = "left";
                  }
                },
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.05),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridColumns,
                    ),
                    itemCount: totalCells,
                    itemBuilder: (context, index) => _buildCell(index),
                  ),
                ),
              ),
            ),
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.amber, width: 1.5),
                    ),
                    child: Text(
                      'SCORE: $score',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _togglePause,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.withOpacity(0.2),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: Icon(
                        paused ? Icons.play_arrow : Icons.pause,
                        color: Colors.amber,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    if (playerPos == -1) {
      return const _EmptyCell();
    }

    if (playerPos == index) {
      if (mouthClosed) {
        return Container(
          margin: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.yellow,
            shape: BoxShape.circle,
          ),
        );
      } else {
        double rotation = 0;
        if (direction == "left") rotation = pi;
        if (direction == "up") rotation = 3 * pi / 2;
        if (direction == "down") rotation = pi / 2;
        return Transform.rotate(
          angle: rotation,
          child: const _PacmanPlayer(),
        );
      }
    }

    if (ghostPos == index) return const _Ghost1();
    if (ghost2Pos == index) return const _Ghost2();
    if (ghost3Pos == index) return const _Ghost3();

    if (barriers.contains(index)) {
      return const _Barrier();
    }

    if (preGame || food.contains(index)) {
      return const _Food();
    }

    return const _EmptyCell();
  }
}

class _PacmanPlayer extends StatelessWidget {
  const _PacmanPlayer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset('lib/images/pacman.png', fit: BoxFit.contain),
    );
  }
}

class _Ghost1 extends StatelessWidget {
  const _Ghost1();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset('lib/images/ghost.png'),
    );
  }
}

class _Ghost2 extends StatelessWidget {
  const _Ghost2();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset('lib/images/ghost2.png'),
    );
  }
}

class _Ghost3 extends StatelessWidget {
  const _Ghost3();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset('lib/images/ghost3.png'),
    );
  }
}

class _Barrier extends StatelessWidget {
  const _Barrier();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue[900],
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.blue[800]!,
              blurRadius: 2,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _Food extends StatelessWidget {
  const _Food();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.yellow,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(1),
      color: Colors.black,
    );
  }
}