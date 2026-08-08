import 'package:flutter/material.dart';

import '../../../../core/theme/design_system.dart';
import 'settings_row.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.soundOn,
    required this.onFocusMinus,
    required this.onFocusPlus,
    required this.onBreakMinus,
    required this.onBreakPlus,
    required this.onSoundChanged,
  });

  final int focusMinutes;
  final int breakMinutes;
  final bool soundOn;
  final VoidCallback onFocusMinus;
  final VoidCallback onFocusPlus;
  final VoidCallback onBreakMinus;
  final VoidCallback onBreakPlus;
  final ValueChanged<bool> onSoundChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          children: [
            SettingsRow(
              label: 'Fokus vaqti',
              value: focusMinutes,
              onMinus: onFocusMinus,
              onPlus: onFocusPlus,
            ),
            const Divider(height: AppSpacing.s20),
            SettingsRow(
              label: 'Tanaffus vaqti',
              value: breakMinutes,
              onMinus: onBreakMinus,
              onPlus: onBreakPlus,
            ),
            const Divider(height: AppSpacing.s20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ovoz',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.volume_up_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                Switch(value: soundOn, onChanged: onSoundChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
