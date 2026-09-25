import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final double? trimStart;  // in seconds
  final double? trimEnd;    // in seconds
  final double height;
  final Color? accentColor;

  const AudioPlayerWidget({
    Key? key,
    required this.audioUrl,
    this.trimStart,
    this.trimEnd,
    this.height = 60,
    this.accentColor,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _positionSubscription;
    Timer? _fadeTimer;


  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _setupListeners();
    _loadAudio();
  }

  void _setupListeners() {
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() => _position = Duration.zero);
      }
    });
  }

  Future<void> _loadAudio() async {
    setState(() => _isLoading = true);
    await _player.setSource(UrlSource(widget.audioUrl));
    setState(() => _isLoading = false);
  }

    Future<void> _fadeIn() async {
    const steps = 10;
    const stepDuration = Duration(milliseconds: 30); // total 300ms
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      if (_player.state == PlayerState.playing && mounted) {
        _player.setVolume(i / steps);
      } else {
        break;
      }
    }
  }

   Future<void> _fadeOut({bool pauseAfter = true}) async {
    const steps = 10;
    const stepDuration = Duration(milliseconds: 30);
    for (int i = steps; i >= 0; i--) {
      await Future.delayed(stepDuration);
      if (_player.state == PlayerState.playing && mounted) {
        _player.setVolume(i / steps);
      } else {
        break;
      }
    }
    if (pauseAfter) {
      await _player.pause();
    }
  }

  void _startPlayback() async {
     _fadeTimer?.cancel();
      await _player.setVolume(0);
    //await _player.resume();
    // Seek to trimStart if provided
    if (widget.trimStart != null && widget.trimStart! > 0) {
      await _player.seek(Duration(milliseconds: (widget.trimStart! * 1000).round()));
    }
       await _player.resume();
       _fadeIn();
    // Set up position listener to stop at trimEnd
    if (widget.trimEnd != null && widget.trimEnd! > (widget.trimStart ?? 0)) {
      _positionSubscription = _player.onPositionChanged.listen((pos) {
        if (pos.inMilliseconds >= (widget.trimEnd! * 1000).round()) {
          _fadeOut(pauseAfter: true);
          //_player.stop();
          _positionSubscription?.cancel();
        }
      });
    }
  }

  Future<void> _pausePlayback() async {
    _fadeTimer?.cancel();
    await _fadeOut(pauseAfter: true); // fade out then pause
  }

  @override
  void dispose() {
    
    _fadeTimer?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  // String _formatDuration(Duration d) {
  //   String twoDigits(int n) => n.toString().padLeft(2, '0');
  //   final minutes = twoDigits(d.inMinutes.remainder(60));
  //   final seconds = twoDigits(d.inSeconds.remainder(60));
  //   return "$minutes:$seconds";
  // }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? Theme.of(context).primaryColor;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  )
                : Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    color: accent,
                    size: 32,
                  ),
            onPressed: _isLoading
                ? null
                : () async {
                    if (_isPlaying) {
                      await _pausePlayback();
                      //_positionSubscription?.cancel();
                    } else {
                      _startPlayback();
                    }
                  },
          ),
         // Text(_formatDuration(_position), style: TextStyle(color: accent)),
          Expanded(
            child: Slider(
              value: _position.inSeconds.toDouble(),
              min: 0,
              max: _duration.inSeconds.toDouble(),
              activeColor: accent,
              onChanged: (value) {
                _player.seek(Duration(seconds: value.toInt()));
              },
            ),
          ),
         // Text(_formatDuration(_duration), style: TextStyle(color: accent)),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}