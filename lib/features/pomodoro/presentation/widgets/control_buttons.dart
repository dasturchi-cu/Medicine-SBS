import 'package:flutter/material.dart';

import '../../../../core/theme/design_system.dart';

class PomodoroControlButtons extends StatelessWidget {
  const PomodoroControlButtons({
    super.key,
    required this.isRunning,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.startLabel,
    required this.pauseLabel,
    required this.resetLabel,
  });

  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final String startLabel;
  final String pauseLabel;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: isRunning ? null : onStart,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              backgroundColor: AppColors.primary,
            ),
            child: Text(startLabel),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: OutlinedButton(
            onPressed: isRunning ? onPause : null,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: Text(pauseLabel),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: Text(resetLabel),
          ),
        ),
      ],
    );
  }
}
