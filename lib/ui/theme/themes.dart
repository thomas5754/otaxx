import 'package:otax/ui/theme/amethyst.dart';
import 'package:otax/ui/theme/coldPurple.dart';
import 'package:otax/ui/theme/hotPink.dart';
import 'package:otax/ui/theme/lime.dart';
import 'package:otax/ui/theme/neonRed.dart';
import 'package:otax/ui/theme/star.dart';
import 'package:otax/ui/theme/mocha.dart';
import 'package:otax/ui/theme/monochrome.dart';
import 'package:otax/ui/theme/neonGreen.dart';
import 'package:otax/ui/theme/sakura.dart';
import 'package:otax/ui/theme/types.dart';
import 'package:flutter/material.dart';

/** List of available themes.
 *
The theme list in UI screen is generated from this list */
List<ThemeItem> availableThemes = [
  LimeZest(), // ids are in order 0 -> n
  Monochrome(),
  ColdPurple(),
  HotPink(),
  Amethyst(),
  Mocha(),
  Sakura(),
  NeonGreen(),
  Star(),
  NeonRed(),
];
// Represents a generic light theme (used only for its values)
AnimeStreamTheme lightModeValues = AnimeStreamTheme(
  textMainColor: Colors.black,
  textSubColor: Color.fromARGB(255, 61, 61, 61),
  backgroundColor: Colors.white,
  backgroundSubColor: Color.fromARGB(255, 179, 179, 179),
  modalSheetBackgroundColor: Colors.white,
  accentColor: Colors.black, // ignore this field
  onAccent: Colors.white
);

// Represents a generic dark theme (used only for its values)
AnimeStreamTheme darkModeValues = AnimeStreamTheme(
  backgroundColor: Color.fromARGB(255, 24, 24, 24),
  backgroundSubColor: const Color.fromARGB(255, 36, 36, 36),
  textMainColor: Colors.white,
  textSubColor: Color.fromARGB(255, 180, 180, 180),
  modalSheetBackgroundColor: Color(0xff121212),
  accentColor: Colors.black, // ignore this field
  onAccent: Colors.white
);
