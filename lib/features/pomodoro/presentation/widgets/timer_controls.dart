import 'package:flutter/material.dart';

import '../../../../core/theme/design_system.dart';

class TimerControls extends StatelessWidget {
  const TimerControls({
    super.key,
    required this.isRunning,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  });

  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isRunning ? null : onStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Start'),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isRunning ? onPause : null,
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: const Text('Pause'),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}
