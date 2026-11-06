import 'package:flutter/material.dart';

import '../../../models/session_status.dart';

/// Colored pill that communicates the ASR connection state at a glance.
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key});

  final SessionStatus status;

  Color get _color => switch (status) {
        SessionStatus.listening => const Color(0xFF4ADE80),
        SessionStatus.connecting => const Color(0xFF60A5FA),
        SessionStatus.paused => const Color(0xFFFBBF24),
        SessionStatus.reconnecting => const Color(0xFFFB923C),
        SessionStatus.error => const Color(0xFFF87171),
        SessionStatus.idle => const Color(0xFF94A3B8),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
