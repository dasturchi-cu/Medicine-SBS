import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Admin analytics uchun `completed` serverga ishonchli tushishi — oxirgi 1 sekunddan tashqari yumshoq chegaralar.
bool _isVideoCompleted(int watchedSec, int durationSec) {
  if (durationSec <= 0) return false;
  if (durationSec <= 15) return watchedSec >= durationSec - 1;
  final nearEnd = watchedSec >= durationSec - 5;
  final pctOk = watchedSec >= (durationSec * 0.90).floor();
  return nearEnd || pctOk;
}

// ─────────────────────────────────────────────
//  PUBLIC WIDGET
// ─────────────────────────────────────────────

class VideoPlayerBox extends StatefulWidget {
  const VideoPlayerBox({
    super.key,
    required this.url,
    required this.height,
    this.initialWatchedSec = 0,
    this.onWatchProgress,
  });

  final String url;
  final double height;
  final int initialWatchedSec;
  final void Function(int watchedSec, bool completed)? onWatchProgress;

  @override
  State<VideoPlayerBox> createState() => _VideoPlayerBoxState();
}

class _VideoPlayerBoxState extends State<VideoPlayerBox> {
  VideoPlayerController? _controller;
  YoutubePlayerController? _ytController;
  String? _youtubeId;

  double _speed = 1.0;
  double _volume = 1.0;
  int _lastReportedSec = 0;
  bool _completedReported = false;
  int? _pendingInitialSeekSec;

  bool get _isYoutube => _youtubeId != null && _ytController != null;

  // ── init ────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pendingInitialSeekSec = widget.initialWatchedSec > 0
        ? widget.initialWatchedSec
        : null;
    _youtubeId = _extractYouTubeId(widget.url);

    if (_youtubeId != null) {
      _ytController = YoutubePlayerController(
        initialVideoId: _youtubeId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          forceHD: false,
          enableCaption: true,
        ),
      )..addListener(_handleYoutubeProgress);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ytController?.unMute();
        _ytController?.setVolume(100);
      });
      return;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) async {
        await _controller?.setVolume(_volume);
        final c = _controller;
        final seekSec = _pendingInitialSeekSec;
        if (c != null && seekSec != null && c.value.duration.inSeconds > 0) {
          final maxSeek = (c.value.duration.inSeconds - 1).clamp(0, 1 << 30);
          final safeSeek = seekSec.clamp(0, maxSeek).toInt();
          if (safeSeek > 0) {
            await c.seekTo(Duration(seconds: safeSeek));
            _lastReportedSec = safeSeek;
          }
          _pendingInitialSeekSec = null;
        }
        if (mounted) setState(() {});
      })
      ..addListener(_handleVideoProgress);
  }

  @override
  void didUpdateWidget(covariant VideoPlayerBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _pendingInitialSeekSec = widget.initialWatchedSec > 0
          ? widget.initialWatchedSec
          : null;
      _lastReportedSec = 0;
      _completedReported = false;
    }
  }

  // ── dispose ─────────────────────────────────

  @override
  void dispose() {
    _emitLatestProgress();
    _controller?.removeListener(_handleVideoProgress);
    _ytController?.removeListener(_handleYoutubeProgress);
    _controller?.dispose();
    _ytController?.dispose();
    super.dispose();
  }

  // ── progress helpers ────────────────────────

  void _emitProgress(int watchedSec, bool completed) {
    final shouldReport =
        completed ? !_completedReported : watchedSec - _lastReportedSec >= 10;
    if (!shouldReport || watchedSec <= 0) return;
    _lastReportedSec = watchedSec;
    if (completed) _completedReported = true;
    widget.onWatchProgress?.call(watchedSec, completed);
  }

  void _handleVideoProgress() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final watchedSec = c.value.position.inSeconds;
    final durationSec = c.value.duration.inSeconds;
    final completed = _isVideoCompleted(watchedSec, durationSec);
    _emitProgress(watchedSec, completed);
  }

  void _handleYoutubeProgress() {
    final c = _ytController;
    if (c == null) return;
    final watchedSec = c.value.position.inSeconds;
    final durationSec = c.metadata.duration.inSeconds;
    final seekSec = _pendingInitialSeekSec;
    if (seekSec != null && durationSec > 0 && watchedSec < seekSec) {
      final safeSeek = seekSec.clamp(0, durationSec - 1).toInt();
      if (safeSeek > 0) {
        c.seekTo(Duration(seconds: safeSeek));
        _lastReportedSec = safeSeek;
      }
      _pendingInitialSeekSec = null;
      return;
    }
    final completed = _isVideoCompleted(watchedSec, durationSec);
    _emitProgress(watchedSec, completed);
  }

  void _emitLatestProgress() {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      final w = c.value.position.inSeconds;
      final d = c.value.duration.inSeconds;
      if (w > 0) widget.onWatchProgress?.call(w, _isVideoCompleted(w, d));
      return;
    }
    final yc = _ytController;
    if (yc != null) {
      final w = yc.value.position.inSeconds;
      final d = yc.metadata.duration.inSeconds;
      if (w > 0) widget.onWatchProgress?.call(w, _isVideoCompleted(w, d));
    }
  }

  // ── controls ────────────────────────────────

  Future<void> _setSpeed(double speed) async {
    if (_isYoutube) {
      _ytController!.setPlaybackRate(speed);
    } else {
      await _controller?.setPlaybackSpeed(speed);
    }
    if (mounted) setState(() => _speed = speed);
  }

  Future<void> _setVolume(double volume) async {
    final v = volume.clamp(0.0, 1.0);
    if (_isYoutube) {
      final pct = (v * 100).round();
      _ytController!.setVolume(pct);
      pct == 0 ? _ytController!.mute() : _ytController!.unMute();
    } else {
      await _controller?.setVolume(v);
    }
    if (mounted) setState(() => _volume = v);
  }

  // ── fullscreen ──────────────────────────────

  Future<void> _openFullscreen() async {
    if (_isYoutube) {
      final yc = _ytController!;
      final wasPlaying = yc.value.isPlaying;
      final result =
          await Navigator.of(context, rootNavigator: true)
              .push<_FullscreenYoutubeResult>(
        MaterialPageRoute(
          builder: (_) => _FullscreenYoutubePage(
            videoId: _youtubeId!,
            startAt: yc.value.position,
            speed: _speed,
            volume: (_volume * 100).round(),
            autoPlay: wasPlaying,
          ),
        ),
      );
      if (result == null || !mounted) return;
      if (result.position > Duration.zero) yc.seekTo(result.position);
      yc.setPlaybackRate(result.speed);
      yc.setVolume(result.volume);
      result.volume == 0 ? yc.mute() : yc.unMute();
      wasPlaying && result.isPlaying ? yc.play() : yc.pause();
      setState(() {
        _speed = result.speed;
        _volume = (result.volume / 100).clamp(0.0, 1.0);
      });
      return;
    }

    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final wasPlaying = c.value.isPlaying;
    final result =
        await Navigator.of(context, rootNavigator: true)
            .push<_FullscreenVideoResult>(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(
          url: widget.url,
          startAt: c.value.position,
          speed: _speed,
          volume: _volume,
          autoPlay: wasPlaying,
        ),
      ),
    );
    if (result == null || !mounted) return;
    await c.seekTo(result.position);
    await c.setPlaybackSpeed(result.speed);
    await c.setVolume(result.volume);
    wasPlaying && result.isPlaying ? await c.play() : await c.pause();
    setState(() {
      _speed = result.speed;
      _volume = result.volume;
    });
  }

  // ── build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isYoutube) return _buildYoutube();
    return _buildNative();
  }

  Widget _buildYoutube() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: _VideoShell(
          isYoutube: true,
          ytController: _ytController!,
          speed: _speed,
          volume: _volume,
          onSpeed: _setSpeed,
          onVolume: _setVolume,
          onFullscreen: _openFullscreen,
        ),
      ),
    );
  }

  Widget _buildNative() {
    final c = _controller;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: c == null || !c.value.isInitialized
            ? const _LoadingIndicator()
            : _VideoShell(
                isYoutube: false,
                nativeController: c,
                speed: _speed,
                volume: _volume,
                onSpeed: _setSpeed,
                onVolume: _setVolume,
                onFullscreen: _openFullscreen,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  VIDEO SHELL  (inline player with auto-hide)
// ─────────────────────────────────────────────

class _VideoShell extends StatefulWidget {
  const _VideoShell({
    required this.isYoutube,
    this.nativeController,
    this.ytController,
    required this.speed,
    required this.volume,
    required this.onSpeed,
    required this.onVolume,
    required this.onFullscreen,
  });

  final bool isYoutube;
  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final double speed;
  final double volume;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onVolume;
  final VoidCallback onFullscreen;

  @override
  State<_VideoShell> createState() => _VideoShellState();
}

class _VideoShellState extends State<_VideoShell>
    with SingleTickerProviderStateMixin {
  bool _showControls = true;
  Timer? _hideTimer;
  late AnimationController _fadeAnim;
  late Animation<double> _fadeIn;

  // seek-feedback overlay
  bool _showSeekFeedback = false;
  bool _seekForward = true;
  Timer? _seekFeedbackTimer;

  @override
  void initState() {
    super.initState();
    _fadeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );
    _fadeIn = CurvedAnimation(parent: _fadeAnim, curve: Curves.easeOut);
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _fadeAnim.dispose();
    super.dispose();
  }

  // ── tap / double-tap ─────────────────────────

  void _onTap() {
    if (!_showControls) {
      _revealControls();
    } else {
      _hideControls();
    }
  }

  void _onDoubleTapLeft() => _seekBy(-10);
  void _onDoubleTapRight() => _seekBy(10);

  void _seekBy(int seconds) {
    final c = widget.nativeController;
    if (c != null && c.value.isInitialized) {
      final target = c.value.position + Duration(seconds: seconds);
      c.seekTo(target.isNegative ? Duration.zero : target);
    }
    final yc = widget.ytController;
    if (yc != null) {
      final target = yc.value.position + Duration(seconds: seconds);
      yc.seekTo(target.isNegative ? Duration.zero : target);
    }
    setState(() {
      _seekForward = seconds > 0;
      _showSeekFeedback = true;
    });
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer =
        Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showSeekFeedback = false);
    });
    _revealControls();
  }

  void _revealControls() {
    setState(() => _showControls = true);
    _fadeAnim.forward();
    _startHideTimer();
  }

  void _hideControls() {
    _hideTimer?.cancel();
    setState(() => _showControls = false);
    _fadeAnim.reverse();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
        _fadeAnim.reverse();
      }
    });
  }

  void _keepAlive() => _startHideTimer();

  // ── play/pause ───────────────────────────────

  void _togglePlay() {
    final c = widget.nativeController;
    if (c != null) {
      c.value.isPlaying ? c.pause() : c.play();
    }
    final yc = widget.ytController;
    if (yc != null) {
      yc.value.isPlaying ? yc.pause() : yc.play();
    }
    _revealControls();
  }

  bool get _isPlaying {
    if (widget.nativeController != null) return widget.nativeController!.value.isPlaying;
    if (widget.ytController != null) return widget.ytController!.value.isPlaying;
    return false;
  }

  // ── build ────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── video content ──
          if (widget.isYoutube)
            _YoutubeCore(controller: widget.ytController!)
          else
            _NativeCore(controller: widget.nativeController!),

          // ── double-tap zones ──
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onTap,
                  onDoubleTap: _onDoubleTapLeft,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onTap,
                  onDoubleTap: _onDoubleTapRight,
                ),
              ),
            ],
          ),

          // ── seek feedback ──
          if (_showSeekFeedback)
            Align(
              alignment:
                  _seekForward ? Alignment.centerRight : Alignment.centerLeft,
              child: _SeekFeedback(forward: _seekForward),
            ),

          // ── controls overlay ──
          FadeTransition(
            opacity: _fadeIn,
            child: IgnorePointer(
              ignoring: !_showControls,
              child: _ControlsOverlay(
                isYoutube: widget.isYoutube,
                nativeController: widget.nativeController,
                ytController: widget.ytController,
                isPlaying: _isPlaying,
                speed: widget.speed,
                volume: widget.volume,
                onTogglePlay: _togglePlay,
                onSpeed: (s) {
                  widget.onSpeed(s);
                  _keepAlive();
                },
                onVolume: (v) {
                  widget.onVolume(v);
                  _keepAlive();
                },
                onFullscreen: widget.onFullscreen,
                onSeek: (pos) {
                  widget.nativeController?.seekTo(pos);
                  widget.ytController?.seekTo(pos);
                  _keepAlive();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  VIDEO CORES
// ─────────────────────────────────────────────

class _NativeCore extends StatelessWidget {
  const _NativeCore({required this.controller});
  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }
}

class _YoutubeCore extends StatelessWidget {
  const _YoutubeCore({required this.controller});
  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF1E6BB8),
        topActions: const [],
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF1E6BB8),
          handleColor: Color(0xFF1E6BB8),
        ),
        bottomActions: const [
          CurrentPosition(),
          SizedBox(width: 8),
          ProgressBar(isExpanded: true),
          SizedBox(width: 8),
          RemainingDuration(),
        ],
      ),
      builder: (_, player) => Center(child: player),
    );
  }
}

// ─────────────────────────────────────────────
//  CONTROLS OVERLAY
// ─────────────────────────────────────────────

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.isYoutube,
    this.nativeController,
    this.ytController,
    required this.isPlaying,
    required this.speed,
    required this.volume,
    required this.onTogglePlay,
    required this.onSpeed,
    required this.onVolume,
    required this.onFullscreen,
    required this.onSeek,
  });

  final bool isYoutube;
  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final bool isPlaying;
  final double speed;
  final double volume;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onVolume;
  final VoidCallback onFullscreen;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x88000000),
            Colors.transparent,
            Colors.transparent,
            Color(0xCC000000),
          ],
          stops: [0.0, 0.25, 0.65, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // ── center play/pause ──
          Center(
            child: _PlayPauseButton(isPlaying: isPlaying, onTap: onTogglePlay),
          ),

          // ── bottom bar ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              isYoutube: isYoutube,
              nativeController: nativeController,
              ytController: ytController,
              speed: speed,
              volume: volume,
              onSpeed: onSpeed,
              onVolume: onVolume,
              onFullscreen: onFullscreen,
              onSeek: onSeek,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PLAY / PAUSE BUTTON
// ─────────────────────────────────────────────

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onTap});
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: ValueKey(isPlaying),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 38,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  BOTTOM BAR  (seek + controls)
// ─────────────────────────────────────────────

class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.isYoutube,
    this.nativeController,
    this.ytController,
    required this.speed,
    required this.volume,
    required this.onSpeed,
    required this.onVolume,
    required this.onFullscreen,
    required this.onSeek,
  });

  final bool isYoutube;
  final VideoPlayerController? nativeController;
  final YoutubePlayerController? ytController;
  final double speed;
  final double volume;
  final ValueChanged<double> onSpeed;
  final ValueChanged<double> onVolume;
  final VoidCallback onFullscreen;
  final ValueChanged<Duration> onSeek;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  double? _dragValue; // null = not dragging

  Duration get _position {
    if (widget.nativeController != null) {
      return widget.nativeController!.value.position;
    }
    return widget.ytController?.value.position ?? Duration.zero;
  }

  Duration get _duration {
    if (widget.nativeController != null) {
      return widget.nativeController!.value.duration;
    }
    return widget.ytController?.metadata.duration ?? Duration.zero;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // rebuild every frame for native video
    if (widget.nativeController != null) {
      return AnimatedBuilder(
        animation: widget.nativeController!,
        builder: (context, child) => _buildBar(),
      );
    }
    // for youtube, rebuild on controller changes
    if (widget.ytController != null) {
      return ListenableBuilder(
        listenable: widget.ytController!,
        builder: (context, child) => _buildBar(),
      );
    }
    return _buildBar();
  }

  Widget _buildBar() {
    final pos = _position;
    final dur = _duration;
    final total = dur.inMilliseconds.toDouble();
    final current = _dragValue ?? pos.inMilliseconds.toDouble();
    final fraction = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── seek bar (native only; YT has its own) ──
          if (!widget.isYoutube)
            _SeekBar(
              fraction: fraction,
              onChangeStart: (v) {
                setState(() => _dragValue = v * total);
              },
              onChanged: (v) {
                setState(() => _dragValue = v * total);
              },
              onChangeEnd: (v) {
                final target =
                    Duration(milliseconds: (v * total).round().clamp(0, total.round()));
                widget.onSeek(target);
                setState(() => _dragValue = null);
              },
            ),

          // ── time + buttons ──
          Row(
            children: [
              if (!widget.isYoutube) ...[
                Text(
                  _fmt(Duration(milliseconds: current.round())),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const Text(
                  ' / ',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Text(
                  _fmt(dur),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const Spacer(),
              _VolumeButton(volume: widget.volume, onVolume: widget.onVolume),
              const SizedBox(width: 4),
              _SpeedButton(speed: widget.speed, onSpeed: widget.onSpeed),
              const SizedBox(width: 4),
              _IconBtn(
                icon: Icons.fullscreen_rounded,
                tooltip: "Katta ko'rish",
                onTap: widget.onFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SEEK BAR
// ─────────────────────────────────────────────

class _SeekBar extends StatelessWidget {
  const _SeekBar({
    required this.fraction,
    required this.onChangeStart,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final double fraction;
  final ValueChanged<double> onChangeStart;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: const Color(0xFF1E6BB8),
        inactiveTrackColor: Colors.white30,
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
      ),
      child: Slider(
        value: fraction,
        onChangeStart: onChangeStart,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  SMALL CONTROL BUTTONS
// ─────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _VolumeButton extends StatelessWidget {
  const _VolumeButton({required this.volume, required this.onVolume});
  final double volume;
  final ValueChanged<double> onVolume;

  IconData get _icon {
    if (volume == 0) return Icons.volume_off_rounded;
    if (volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      initialValue: volume,
      onSelected: onVolume,
      offset: const Offset(0, -120),
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _volItem(0.0, '🔇  0%'),
        _volItem(0.25, '🔉  25%'),
        _volItem(0.5, '🔉  50%'),
        _volItem(0.75, '🔊  75%'),
        _volItem(1.0, '🔊  100%'),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(_icon, color: Colors.white, size: 22),
      ),
    );
  }

  PopupMenuItem<double> _volItem(double v, String label) => PopupMenuItem(
        value: v,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      );
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onSpeed});
  final double speed;
  final ValueChanged<double> onSpeed;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      initialValue: speed,
      onSelected: onSpeed,
      offset: const Offset(0, -180),
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        _speedItem(0.5),
        _speedItem(0.75),
        _speedItem(1.0),
        _speedItem(1.25),
        _speedItem(1.5),
        _speedItem(2.0),
      ],
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 3),
            Text(
              '${speed}x',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<double> _speedItem(double v) => PopupMenuItem(
        value: v,
        child: Row(
          children: [
            Icon(
              Icons.check,
              size: 16,
              color: v == speed ? const Color(0xFF1E6BB8) : Colors.transparent,
            ),
            const SizedBox(width: 8),
            Text(
              '${v}x',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: v == speed ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────
//  SEEK FEEDBACK  (+10s / −10s bubble)
// ─────────────────────────────────────────────

class _SeekFeedback extends StatelessWidget {
  const _SeekFeedback({required this.forward});
  final bool forward;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              forward ? Icons.forward_10_rounded : Icons.replay_10_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 6),
            Text(
              forward ? '+10s' : '−10s',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  LOADING INDICATOR
// ─────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Color(0xFF1E6BB8)),
          strokeWidth: 3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FULLSCREEN  –  NATIVE
// ─────────────────────────────────────────────

class _FullscreenVideoPage extends StatefulWidget {
  const _FullscreenVideoPage({
    required this.url,
    required this.startAt,
    required this.speed,
    required this.volume,
    required this.autoPlay,
  });

  final String url;
  final Duration startAt;
  final double speed;
  final double volume;
  final bool autoPlay;

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  VideoPlayerController? _controller;
  late double _speed;
  late double _volume;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _speed = widget.speed;
    _volume = widget.volume;
    _enterLandscape();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) async {
        final c = _controller;
        if (c == null || !mounted) return;
        await c.seekTo(widget.startAt);
        await c.setPlaybackSpeed(_speed);
        await c.setVolume(_volume);
        if (widget.autoPlay) await c.play();
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _exitLandscape();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _enterLandscape() async {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitLandscape() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    final c = _controller;
    final result = _FullscreenVideoResult(
      position: c?.value.position ?? widget.startAt,
      isPlaying: c?.value.isPlaying ?? false,
      speed: _speed,
      volume: _volume,
    );
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop(result);
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(result);
      return;
    }
    _isClosing = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _close(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: c == null || !c.value.isInitialized
            ? const _LoadingIndicator()
            : _VideoShell(
                isYoutube: false,
                nativeController: c,
                speed: _speed,
                volume: _volume,
                onSpeed: (s) async {
                  await c.setPlaybackSpeed(s);
                  if (mounted) setState(() => _speed = s);
                },
                onVolume: (v) async {
                  final n = v.clamp(0.0, 1.0);
                  await c.setVolume(n);
                  if (mounted) setState(() => _volume = n);
                },
                onFullscreen: _close,
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FULLSCREEN  –  YOUTUBE
// ─────────────────────────────────────────────

class _FullscreenYoutubePage extends StatefulWidget {
  const _FullscreenYoutubePage({
    required this.videoId,
    required this.startAt,
    required this.speed,
    required this.volume,
    required this.autoPlay,
  });

  final String videoId;
  final Duration startAt;
  final double speed;
  final int volume;
  final bool autoPlay;

  @override
  State<_FullscreenYoutubePage> createState() => _FullscreenYoutubePageState();
}

class _FullscreenYoutubePageState extends State<_FullscreenYoutubePage> {
  late final YoutubePlayerController _controller;
  late int _volume;
  late double _speed;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _volume = widget.volume;
    _speed = widget.speed;
    _enterLandscape();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.autoPlay,
        mute: false,
        forceHD: false,
      ),
    );
    _controller.setPlaybackRate(_speed);
    _controller.setVolume(_volume);
    _volume == 0 ? _controller.mute() : _controller.unMute();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _controller.seekTo(widget.startAt));
  }

  @override
  void dispose() {
    _exitLandscape();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enterLandscape() async {
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitLandscape() async {
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    final result = _FullscreenYoutubeResult(
      position: _controller.value.position,
      isPlaying: _controller.value.isPlaying,
      speed: _speed,
      volume: _volume,
    );
    final rootNav = Navigator.of(context, rootNavigator: true);
    if (rootNav.canPop()) {
      rootNav.pop(result);
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(result);
      return;
    }
    _isClosing = false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _close(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _VideoShell(
          isYoutube: true,
          ytController: _controller,
          speed: _speed,
          volume: _volume / 100,
          onSpeed: (s) {
            _controller.setPlaybackRate(s);
            if (mounted) setState(() => _speed = s);
          },
          onVolume: (v) {
            final pct = (v * 100).round();
            _controller.setVolume(pct);
            pct == 0 ? _controller.mute() : _controller.unMute();
            if (mounted) setState(() => _volume = pct);
          },
          onFullscreen: _close,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  RESULT MODELS
// ─────────────────────────────────────────────

class _FullscreenVideoResult {
  const _FullscreenVideoResult({
    required this.position,
    required this.isPlaying,
    required this.speed,
    required this.volume,
  });
  final Duration position;
  final bool isPlaying;
  final double speed;
  final double volume;
}

class _FullscreenYoutubeResult {
  const _FullscreenYoutubeResult({
    required this.position,
    required this.isPlaying,
    required this.speed,
    required this.volume,
  });
  final Duration position;
  final bool isPlaying;
  final double speed;
  final int volume;
}

// ─────────────────────────────────────────────
//  YOUTUBE ID EXTRACTOR
// ─────────────────────────────────────────────

String? _extractYouTubeId(String input) {
  final value = input.trim();
  if (value.isEmpty) return null;
  final idPattern = RegExp(r'^[a-zA-Z0-9_-]{11}$');
  if (idPattern.hasMatch(value)) return value;
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    final seg = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    return idPattern.hasMatch(seg) ? seg : null;
  }
  if (uri.host.contains('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && idPattern.hasMatch(v)) return v;
    for (final prefix in ['embed', 'live', 'shorts']) {
      if (uri.pathSegments.length >= 2 && uri.pathSegments.first == prefix) {
        final id = uri.pathSegments[1];
        if (idPattern.hasMatch(id)) return id;
      }
    }
  }
  return null;
}