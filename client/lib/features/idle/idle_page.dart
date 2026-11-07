import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../config/idle_video_config.dart';
import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../recording/recording_page.dart';

/// Full-screen idle screen: looping muted video (or a gradient fallback) with a
/// single call to action.
class IdlePage extends StatefulWidget {
  const IdlePage({super.key});

  @override
  State<IdlePage> createState() => _IdlePageState();
}

class _IdlePageState extends State<IdlePage> {
  Player? _player;
  VideoController? _controller;
  StreamSubscription<String>? _errorSubscription;
  IdleVideoConfig? _config;
  String? _error;
  bool _ready = false;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    unawaited(_errorSubscription?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
        _ready = false;
      });
    }

    final IdleVideoConfig config = await IdleVideoConfig.load();
    if (!mounted) return;
    _config = config;

    // Fail fast with a readable message when the bundled asset is missing.
    if (config.isAsset) {
      try {
        await rootBundle.load(config.value);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _error = '待机视频缺失：${config.value}\n已使用渐变背景，请替换 assets/idle/idle_loop.mp4 '
              '或修改 config/idle_video.json';
        });
        return;
      }
    }

    await _errorSubscription?.cancel();
    await _player?.dispose();

    try {
      final Player player = Player();
      final VideoController controller = VideoController(player);
      _errorSubscription = player.stream.error.listen((String message) {
        if (!mounted) return;
        setState(() {
          _ready = false;
          _error = '待机视频播放失败：$message';
        });
      });

      await player.setVolume(0);
      await player.setPlaylistMode(PlaylistMode.loop);
      await player.open(Media(config.uri), play: true);

      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _player = player;
        _controller = controller;
        _ready = true;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = '待机视频初始化失败：$error';
      });
    }
  }

  Future<void> _startRecording() async {
    await _player?.pause();
    if (!mounted) return;
    final String? savedPath = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const RecordingPage()),
    );
    if (!mounted) return;
    if (savedPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录音已保存至：$savedPath')),
      );
    }
    await _player?.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _buildBackground(),
          const _IdleScrim(),
          SafeArea(
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeader(),
                  const Spacer(),
                  if (_error != null) _buildErrorCard(),
                  const SizedBox(height: 16),
                  _buildStartButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (_ready && _controller != null && _error == null) {
      final Video video = Video(
        controller: _controller!,
        fit: BoxFit.cover,
        fill: Colors.black,
        controls: NoVideoControls,
        wakelock: false,
      );
      final int turns = _config?.quarterTurns ?? 0;
      return turns == 0 ? video : RotatedBox(quarterTurns: turns, child: video);
    }
    return const _GradientFallback();
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: AppTheme.accent),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              kAppName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '实时字幕 · 边听边记',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.62),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2A12).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0A33E).withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE0A33E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFFF3DCB8)),
            ),
          ),
          TextButton(
            onPressed: _initializing ? null : _initialize,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: _startRecording,
                icon: const Icon(Icons.mic_rounded, size: 24),
                label: const Text(
                  '开始录音',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: const Color(0xFF052622),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _initializing
                  ? '正在准备待机视频…'
                  : '视频静音循环播放，开始录音后暂停',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdleScrim extends StatelessWidget {
  const _IdleScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.78),
          ],
          stops: const <double>[0, 0.45, 1],
        ),
      ),
    );
  }
}

class _GradientFallback extends StatelessWidget {
  const _GradientFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.15,
          colors: <Color>[Color(0xFF12333A), Color(0xFF081418), Color(0xFF030608)],
        ),
      ),
    );
  }
}
