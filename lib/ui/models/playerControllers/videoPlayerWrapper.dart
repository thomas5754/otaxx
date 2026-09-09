import 'dart:io';

import 'package:otax/core/commons/extractQuality.dart';
import 'package:otax/ui/models/playerControllers/videoController.dart';
import 'package:otax/ui/models/widgets/player/playerUtils.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/material.dart';

/// Event types kept for API compatibility with places that previously
/// listened to BetterPlayer's eventListener (e.g. PiP stop detection).
enum PlayerEventType { exception, pipStop, initialized, play, pause, progress, finished }

class PlayerEvent {
  final PlayerEventType type;
  final Map<String, dynamic>? parameters;
  const PlayerEvent(this.type, [this.parameters]);
}

typedef PlayerEventListener = void Function(PlayerEvent event);

/// Drop-in replacement for the old BetterPlayerWrapper, built on top of
/// video_player + chewie (both actively maintained & AGP-compatible).
class VideoPlayerWrapper implements VideoController {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  final List<VoidCallback> _listeners = [];
  final List<PlayerEventListener> _eventListeners = [];

  String? _activeUrl;
  BoxFit _fit = BoxFit.contain;

  final key = GlobalKey();

  /// Kept so call sites that previously did `(controller as BetterPlayerWrapper).controller...`
  /// can be migrated to `.addEventsListener(...)` on this wrapper instead.
  void addEventsListener(PlayerEventListener listener) {
    _eventListeners.add(listener);
  }

  void _emit(PlayerEvent ev) {
    for (final l in _eventListeners) {
      l(ev);
    }
  }

  @override
  Future<void> initiateVideo(String url, {Map<String, String>? headers, bool offline = false}) async {
    _activeUrl = url;

    final controller = offline
        ? VideoPlayerController.file(File(url))
        : VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: headers ?? const {},
          );

    _videoController = controller;

    try {
      await controller.initialize();
    } catch (e) {
      _emit(PlayerEvent(PlayerEventType.exception, {"error": e.toString()}));
      rethrow;
    }

    _chewieController = ChewieController(
      videoPlayerController: controller,
      autoPlay: true,
      looping: false,
      showControls: false,
      aspectRatio: 16 / 9,
      allowedScreenSleep: false,
      placeholder: const PlayerLoadingWidget(),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            "Whoops! Ran into some errors playing this video!\nDetails:\n$errorMessage",
            style: const TextStyle(fontSize: 20),
          ),
        );
      },
    );

    controller.addListener(() {
      if (controller.value.hasError) {
        _emit(PlayerEvent(PlayerEventType.exception, {"error": controller.value.errorDescription}));
      }
    });

    _emit(const PlayerEvent(PlayerEventType.initialized));
  }

  @override
  bool? get isBuffering => _videoController?.value.isBuffering;

  @override
  bool? get isPlaying => _videoController?.value.isPlaying;

  @override
  int? get position => _videoController?.value.position.inMilliseconds;

  @override
  int? get duration => _videoController?.value.duration.inMilliseconds;

  @override
  int? get buffered => _videoController?.value.buffered.lastOrNull?.end.inSeconds;

  @override
  double? get volume => _videoController?.value.volume;

  @override
  String? get activeMediaUrl => _activeUrl;

  @override
  bool? get isInitialized => _videoController?.value.isInitialized;

  @override
  Future<void> pause() async {
    await _videoController?.pause();
    _emit(const PlayerEvent(PlayerEventType.pause));
  }

  @override
  Future<void> play() async {
    await _videoController?.play();
    _emit(const PlayerEvent(PlayerEventType.play));
  }

  @override
  Future<void> seekTo(Duration duration) async {
    await _videoController?.seekTo(duration);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _videoController?.setPlaybackSpeed(speed);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
  }

  @override
  Widget getWidget() {
    if (_chewieController == null) {
      return const PlayerLoadingWidget();
    }
    return FittedBox(
      fit: _fit,
      child: SizedBox(
        width: _videoController?.value.size.width ?? 16,
        height: _videoController?.value.size.height ?? 9,
        child: Chewie(controller: _chewieController!, key: key),
      ),
    );
  }

  @override
  void addListener(VoidCallback cb) {
    _listeners.add(cb);
    _videoController?.addListener(cb);
  }

  @override
  void removeListener(VoidCallback cb) {
    _videoController?.removeListener(cb);
    _listeners.remove(cb);
  }

  @override
  void setFit(BoxFit fit) {
    _fit = fit;
  }

  @override
  Future<void> setVolume(double volume) async {
    await _videoController?.setVolume(volume);
  }

  @override
  Future<void> setPip(bool value) async {
    // Native PiP isn't supported directly by video_player/chewie.
    // We still emit a pipStop-like event so existing listeners (e.g. watch.dart)
    // don't break; PiP UI itself needs a platform-specific implementation if required.
    if (!value) {
      _emit(const PlayerEvent(PlayerEventType.pipStop));
    }
  }

  @override
  Future<void> setAudioTrack(AudioStream aud) async {
    // video_player/chewie do not support ASMS-style multi-audio-track switching
    // out of the box. Kept as a no-op for interface compatibility.
    debugPrint("[VideoPlayerWrapper] setAudioTrack requested for ${aud.language}, "
        "but multi-audio-track switching isn't supported by video_player/chewie.");
  }

  @override
  void setQuality(QualityStream qs) {
    // Quality switching requires reinitializing the controller with a new URL.
    // Call initiateVideo(qs.url) from the caller if quality switching is needed.
    debugPrint("[VideoPlayerWrapper] setQuality requested for ${qs.resolution}. "
        "Re-initiate video with the new url (${qs.url}) to switch quality.");
  }
}
