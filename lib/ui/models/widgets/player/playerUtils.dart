import 'dart:math';

import 'package:flutter/material.dart';

class PlayerLoadingWidget extends StatelessWidget {
  const PlayerLoadingWidget({
    super.key,
  });

  // Why not have some fun :)
  final messages = const [
    "Loading Your Anime...",
    "Tweaking the pixels...",
    "Setting up the fun...",
    "Tried Oreshura? Loading anyway...",
    "Just a moment, Senpai...",
    ":)",
    "Cooking up the playback...",
    "Hold on! Will Ya?",
    "Aligning the frames...",
    "anime...stream...ing...",
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              height: 200,
              width: 200,
              child: Image.asset(
                "lib/assets/icons/logo_foreground.png",
                opacity: AlwaysStoppedAnimation(0.6),
              )),
          Text(
            messages[Random().nextInt(messages.length)],
            style: TextStyle(color: Colors.grey, fontFamily: "Rubik", fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }
}

/**Format seconds to hour:min:sec format */
String getFormattedTime(int timeInSeconds) {
  String formatTime(int val) {
    return val.toString().padLeft(2, '0');
  }

  int hours = timeInSeconds ~/ 3600;
  int minutes = (timeInSeconds % 3600) ~/ 60;
  int seconds = timeInSeconds % 60;

  String formattedHours = hours == 0 ? '' : formatTime(hours);
  String formattedMins = formatTime(minutes);
  String formattedSeconds = formatTime(seconds);

  return "${formattedHours.length > 0 ? "$formattedHours:" : ''}$formattedMins:$formattedSeconds";
}
