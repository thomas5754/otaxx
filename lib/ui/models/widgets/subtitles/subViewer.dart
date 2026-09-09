import 'dart:io';

import 'package:otax/core/app/logging.dart';
import 'package:otax/core/app/runtimeDatas.dart';
import 'package:otax/core/commons/enums.dart';
import 'package:otax/core/commons/subtitleParsers/subtitleParsers.dart';
import 'package:otax/core/commons/subtitleTranslator.dart';
import 'package:otax/ui/models/snackBar.dart';
import 'package:otax/ui/models/playerControllers/videoController.dart';
import 'package:otax/ui/models/widgets/subtitles/subtitle.dart';
import 'package:otax/ui/models/widgets/subtitles/subtitleSettings.dart';
import 'package:otax/ui/models/widgets/subtitles/subtitleText.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SubViewer extends StatefulWidget {
  final VideoController controller;
  final String subtitleSource;
  final Map<String, String>? headers;
  final SubtitleFormat format;
  final SubtitleSettings settings;

  const SubViewer({
    super.key,
    required this.controller,
    required this.format,
    required this.subtitleSource,
    required this.settings,
    this.headers = const {},
  });

  @override
  State<SubViewer> createState() => _SubViewerState();
}

class _SubViewerState extends State<SubViewer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateSubtitle);
    loadSubs();
    print("subs initialized");
  }

  List<Subtitle> subs = [];
  List<Subtitle> activeSubtitles = [];

  bool areSubsLoading = true;

  /// True ketika proses terjemahan sedang berjalan di background
  bool isTranslating = false;

  /// Progress terjemahan 0.0 – 1.0
  double translateProgress = 0.0;

  String? _loadedSubsUrl;

  /// Apakah preferensi bahasa pengguna adalah Indonesia?
  bool get _preferIndonesian {
    final lang = (currentUserSettings?.preferredSubtitleLanguage ?? 'English').toLowerCase();
    return lang == 'indonesian' || lang == 'indonesia';
  }

  void loadSubs() async {
    try {
      if (mounted) {
        setState(() {
          areSubsLoading = true;
          isTranslating = false;
          translateProgress = 0.0;
        });
      }

      subs.clear();
      print("loading ${widget.format.name} subs");

      switch (widget.format) {
        case SubtitleFormat.ASS:
          subs = await Subtitleparsers().parseAss(widget.subtitleSource, headers: widget.headers ?? {});
          break;
        case SubtitleFormat.VTT:
          subs = await Subtitleparsers().parseVtt(widget.subtitleSource, headers: widget.headers ?? {});
          break;
        case SubtitleFormat.SRT:
          subs = await Subtitleparsers().parseSrt(widget.subtitleSource, headers: widget.headers ?? {});
          break;
      }

      print(widget.subtitleSource);
      _loadedSubsUrl = widget.subtitleSource;

      if (mounted) {
        setState(() {
          areSubsLoading = false;
        });
      }

      // ─── AUTO-TRANSLATE ke Indonesia ─────────────────────────────────────
      // Subtitle asli (Inggris) langsung tampil dulu, terjemahan jalan di background.
      if (_preferIndonesian && subs.isNotEmpty) {
        await _autoTranslateToIndonesian();
      }
      // ─────────────────────────────────────────────────────────────────────

    } catch (err) {
      Logs.player.log(err.toString());
      SchedulerBinding.instance.addPostFrameCallback((dur) {
        floatingSnackBar("Couldnt load the subtitles!");
      });
      if (mounted) {
        setState(() {
          areSubsLoading = false;
          isTranslating = false;
        });
      }
    }
  }

  /// Terjemahkan seluruh subtitle ke Bahasa Indonesia secara bertahap.
  Future<void> _autoTranslateToIndonesian() async {
    if (!mounted) return;
    setState(() {
      isTranslating = true;
      translateProgress = 0.0;
    });

    try {
      final translated = await SubtitleTranslator.translate(
        subs,
        targetLang: 'id',
        sourceLang: 'auto',
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              translateProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          subs = translated;
          isTranslating = false;
          translateProgress = 1.0;
        });
      }

      print('[SubViewer] Auto-translate selesai: ${subs.length} baris');
    } catch (e) {
      print('[SubViewer] Auto-translate gagal: $e');
      if (mounted) {
        setState(() {
          isTranslating = false;
        });
        SchedulerBinding.instance.addPostFrameCallback((_) {
          floatingSnackBar("Terjemahan otomatis gagal, menampilkan subtitle asli");
        });
      }
    }
  }

  int lastLineIndex = 0;

  void _updateSubtitle() {
    final currentPosition = widget.controller.position;

    if (currentPosition == null || subs.isEmpty) return;

    if (_loadedSubsUrl != widget.subtitleSource && !areSubsLoading) {
      print("Subtitle Source Changed, Loading new subs..");
      return loadSubs();
    }

    if (lastLineIndex >= subs.length ||
        (lastLineIndex > 0 && subs[lastLineIndex].start.inMilliseconds > currentPosition)) {
      lastLineIndex = 0;
    }

    while (lastLineIndex < subs.length && subs[lastLineIndex].end.inMilliseconds < currentPosition) {
      lastLineIndex++;
    }

    List<Subtitle> newMatches = [];

    for (int i = lastLineIndex; i < subs.length; i++) {
      final sub = subs[i];
      if (sub.start.inMilliseconds > currentPosition) break;
      if (sub.end.inMilliseconds >= currentPosition) {
        newMatches.add(sub);
      }
    }

    if (!_areSubtitleListsEqual(activeSubtitles, newMatches)) {
      if (mounted) {
        setState(() {
          activeSubtitles = newMatches;
        });
      }
    }
  }

  bool _areSubtitleListsEqual(List<Subtitle> a, List<Subtitle> b) {
    if (a.length != b.length) return false;
    if (a.isEmpty && b.isEmpty) return true;
    return a.first.start.inMilliseconds == b.first.start.inMilliseconds &&
        a.first.end.inMilliseconds == b.first.end.inMilliseconds &&
        a.last.start.inMilliseconds == b.last.start.inMilliseconds &&
        a.last.end.inMilliseconds == b.last.end.inMilliseconds;
  }

  TextStyle subTextStyle() {
    return TextStyle(
      fontSize: Platform.isWindows ? widget.settings.fontSize * 1.5 : widget.settings.fontSize,
      fontFamily: widget.settings.fontFamily ?? "Rubik",
      color: widget.settings.textColor,
      fontWeight: widget.settings.bold ? FontWeight.w700 : FontWeight.w500,
      fontFamilyFallback: ["Poppins"],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<SubtitleAlignment, List<Subtitle>> subsGrouped = {};
    for (final sub in activeSubtitles) {
      subsGrouped.putIfAbsent(sub.alignment, () => []).add(sub);
    }

    for (var list in subsGrouped.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    return Stack(
      children: [
        // ── Subtitle text ──────────────────────────────────────────────────
        ...subsGrouped.entries.map((group) {
          final alignment = group.key;
          final groupSubs = group.value;

          return Align(
            alignment: getLineAlignment(alignment),
            child: Container(
              width: MediaQuery.of(context).size.width / 1.4,
              margin: EdgeInsets.only(
                  bottom: widget.settings.bottomMargin, top: widget.settings.bottomMargin),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: groupSubs
                    .map(
                      (sub) => SubtitleText(
                        text: areSubsLoading ? "Memuat subtitle..." : sub.dialogue,
                        style: subTextStyle(),
                        strokeColor: widget.settings.strokeColor,
                        strokeWidth: widget.settings.strokeWidth,
                        backgroundColor: widget.settings.backgroundColor,
                        backgroundTransparency: widget.settings.backgroundTransparency,
                        enableShadows: widget.settings.enableShadows,
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        }).toList(),

        // ── Indikator terjemahan berjalan ──────────────────────────────────
        if (isTranslating)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        value: translateProgress > 0 ? translateProgress : null,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      translateProgress > 0
                          ? '🇮🇩 Menerjemahkan... ${(translateProgress * 100).toInt()}%'
                          : '🇮🇩 Menerjemahkan...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'Rubik',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Alignment getLineAlignment(SubtitleAlignment alignment) {
    switch (alignment) {
      case SubtitleAlignment.topLeft:
        return Alignment.topLeft;
      case SubtitleAlignment.topCenter:
        return Alignment.topCenter;
      case SubtitleAlignment.topRight:
        return Alignment.topRight;
      case SubtitleAlignment.centerLeft:
        return Alignment.centerLeft;
      case SubtitleAlignment.center:
        return Alignment.center;
      case SubtitleAlignment.centerRight:
        return Alignment.centerRight;
      case SubtitleAlignment.bottomLeft:
        return Alignment.bottomLeft;
      case SubtitleAlignment.bottomCenter:
        return Alignment.bottomCenter;
      case SubtitleAlignment.bottomRight:
        return Alignment.bottomRight;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateSubtitle);
    super.dispose();
  }
}
