import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../core/app_config.dart';
import '../../core/app_theme.dart';
import '../../models/language.dart';
import '../../state/recording_session.dart';
import '../../state/transcript_controller.dart';
import '../../state/ws_recording_session.dart';
import 'widgets/status_chip.dart';
import 'widgets/subtitle_list.dart';

/// Live subtitle screen: status header, translation controls, scrolling
/// transcript, and the stop action.
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  late final TranscriptController _transcript;
  late final RecordingSession _session;
  StreamSubscription<SessionEvent>? _subscription;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _stopping = false;
  Player? _debugPlayer;
  bool _debugNotified = false;

  @override
  void initState() {
    super.initState();
    _transcript = TranscriptController();
    _session = WsRecordingSession(endpoint: asrEndpoint);
    _subscription = _session.events.listen(_transcript.apply);
    _session.updateTranslation(
      enabled: _transcript.translateEnabled,
      target: _transcript.target,
    );
    unawaited(_session.start(source: _transcript.source));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (!_debugNotified && _session.debugAudioPath != null) {
        _debugNotified = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('调试音频已保存：${_session.debugAudioPath}')),
        );
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_session.dispose());
    unawaited(_debugPlayer?.dispose());
    _transcript.dispose();
    super.dispose();
  }

  void _onTranslateChanged(bool enabled) {
    _transcript.setTranslateEnabled(enabled);
    _session.updateTranslation(enabled: enabled, target: _transcript.target);
  }

  void _onTargetChanged(TargetLanguage target) {
    _transcript.setTarget(target);
    _session.updateTranslation(enabled: _transcript.translateEnabled, target: target);
  }

  void _onSourceChanged(SourceLanguage source) {
    _transcript.setSource(source);
    unawaited(_session.updateSource(source));
  }

  Future<void> _stop() async {
    if (_stopping) return;
    _stopping = true;
    final String? savedPath = await _session.stop();
    if (!mounted) return;
    Navigator.of(context).pop(savedPath);
  }

  Future<void> _playDebugAudio() async {
    final String? path = _session.debugAudioPath;
    if (path == null) return;
    try {
      _debugPlayer ??= Player();
      await _debugPlayer!.open(Media(Uri.file(path).toString()), play: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在播放调试音频：$path')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _transcript,
          builder: (BuildContext context, Widget? _) {
            return Column(
              children: <Widget>[
                _buildHeader(context),
                if (_transcript.error != null) _buildErrorBanner(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: SubtitleList(
                          lines: _transcript.lines,
                          partial: _transcript.partial,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_session.debugAudioPath != null) _buildDebugBar(),
                _buildFooter(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              StatusChip(status: _transcript.status),
              _buildSourceLanguageDropdown(),
              _buildTranslateToggle(),
            ],
          ),
          const SizedBox(height: 10),
          if (_transcript.translateEnabled)
            _buildTargetSelector()
          else
            Text(
              '翻译已关闭 · 只显示原文，不调用翻译接口',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceLanguageDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<SourceLanguage>(
          value: _transcript.source,
          isDense: true,
          dropdownColor: const Color(0xFF14232A),
          borderRadius: BorderRadius.circular(10),
          icon: Icon(Icons.expand_more, size: 18, color: Colors.white.withValues(alpha: 0.6)),
          style: const TextStyle(fontSize: 12.5, color: Colors.white),
          items: SourceLanguage.values
              .map(
                (SourceLanguage language) => DropdownMenuItem<SourceLanguage>(
                  value: language,
                  child: Text('识别：${language.label}'),
                ),
              )
              .toList(),
          onChanged: (SourceLanguage? value) {
            if (value != null) _onSourceChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildTranslateToggle() {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.translate_rounded, size: 15, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          const Text('翻译', style: TextStyle(fontSize: 12.5, color: Colors.white70)),
          Transform.scale(
            scale: 0.78,
            child: Switch(
              value: _transcript.translateEnabled,
              onChanged: _onTranslateChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TargetLanguage.values.map((TargetLanguage language) {
        final bool selected = _transcript.target == language;
        return ChoiceChip(
          label: Text(language.label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => _onTargetChanged(language),
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFF052622) : Colors.white.withValues(alpha: 0.75),
          ),
          selectedColor: AppTheme.accent,
          backgroundColor: Colors.white.withValues(alpha: 0.07),
          side: BorderSide(
            color: selected ? AppTheme.accent : Colors.white.withValues(alpha: 0.14),
          ),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }

  Widget _buildDebugBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.bug_report_outlined, size: 16, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '调试录音（发送给ASR的前5秒）',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ),
          TextButton.icon(
            onPressed: _playDebugAudio,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('播放', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A1518).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFF08A8E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _transcript.error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFF6C7C9)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 8, 22, bottomInset > 0 ? bottomInset + 8 : 18),
      child: Column(
        children: <Widget>[
          Text(
            _formatDuration(_elapsed),
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 2,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _stopping ? null : _stop,
                  icon: const Icon(Icons.stop_circle_outlined, size: 20),
                  label: const Text(
                    '停止录音',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final String minutes = duration.inMinutes.toString().padLeft(2, '0');
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
