import 'package:flutter/material.dart';

import '../../../models/transcript_line.dart';

/// Scrollable subtitle feed.
///
/// Committed sentences use a normal weight; the in-flight partial is grey and
/// italic so it reads as provisional. Auto-scroll pauses as soon as the user
/// scrolls up and resumes when they return to the bottom or tap the pill.
class SubtitleList extends StatefulWidget {
  const SubtitleList({
    required this.lines,
    required this.partial,
    super.key,
  });

  final List<TranscriptLine> lines;
  final String partial;

  @override
  State<SubtitleList> createState() => _SubtitleListState();
}

class _SubtitleListState extends State<SubtitleList> {
  final ScrollController _scrollController = ScrollController();
  bool _followTail = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double distance =
        _scrollController.position.maxScrollExtent - _scrollController.position.pixels;
    final bool follow = distance < 80;
    if (follow != _followTail) {
      setState(() => _followTail = follow);
    }
  }

  @override
  void didUpdateWidget(covariant SubtitleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool contentChanged =
        oldWidget.lines.length != widget.lines.length || oldWidget.partial != widget.partial;
    if (_followTail && contentChanged) {
      _scrollToEnd(animate: true);
    }
  }

  void _scrollToEnd({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final double target = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _resumeFollowing() {
    setState(() => _followTail = true);
    _scrollToEnd(animate: true);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPartial = widget.partial.isNotEmpty;
    if (widget.lines.isEmpty && !hasPartial) {
      return const _EmptyState();
    }

    final int itemCount = widget.lines.length + (hasPartial ? 1 : 0);

    return Stack(
      children: <Widget>[
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 28),
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) {
            if (index < widget.lines.length) {
              return _FinalTile(line: widget.lines[index]);
            }
            return _PartialTile(text: widget.partial);
          },
        ),
        if (!_followTail)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(
              child: _JumpToLatestButton(onTap: _resumeFollowing),
            ),
          ),
      ],
    );
  }
}

class _FinalTile extends StatelessWidget {
  const _FinalTile({required this.line});

  final TranscriptLine line;

  @override
  Widget build(BuildContext context) {
    final String? translation = line.translation;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            line.text,
            style: TextStyle(
              fontSize: 20,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.94),
            ),
          ),
          if (translation != null && translation.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (line.translationTarget != null) ...<Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4DD0C4).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      line.translationTarget!.shortLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7FD8CF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(
                    translation,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Color(0xFF9FC4C0),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PartialTile extends StatelessWidget {
  const _PartialTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        text,
        key: const ValueKey<String>('partial-subtitle'),
        style: TextStyle(
          fontSize: 20,
          height: 1.45,
          fontStyle: FontStyle.italic,
          color: Colors.white.withValues(alpha: 0.52),
        ),
      ),
    );
  }
}

class _JumpToLatestButton extends StatelessWidget {
  const _JumpToLatestButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF14232A).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.arrow_downward_rounded, size: 14, color: Colors.white70),
              SizedBox(width: 6),
              Text('回到最新', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.graphic_eq_rounded, size: 40, color: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 12),
          Text(
            '正在聆听…',
            style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 4),
          Text(
            '说话后字幕会显示在这里',
            style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.35)),
          ),
        ],
      ),
    );
  }
}
