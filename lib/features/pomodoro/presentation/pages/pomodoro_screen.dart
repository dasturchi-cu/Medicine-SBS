import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/design_system.dart';
import '../providers/pomodoro_provider.dart';
import '../widgets/control_buttons.dart';
import '../widgets/settings_section.dart';
import '../widgets/stats_card.dart';
import '../widgets/timer_card.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  late final ProviderSubscription<PomodoroState> _soundSubscription;
  late final AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _soundSubscription = ref.listenManual<PomodoroState>(pomodoroProvider, (
      previous,
      next,
    ) {
      final sessionCompleted =
          (previous?.completedSessions ?? 0) < next.completedSessions;
      if (sessionCompleted && next.soundOn) {
        _playCompletionAlert();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _soundSubscription.close();
    super.dispose();
  }

  Future<void> _playCompletionAlert() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/alert.wav'), volume: 1.0);
    } catch (_) {
      await SystemSound.play(SystemSoundType.alert);
    }
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pomodoroProvider);
    final notifier = ref.read(pomodoroProvider.notifier);
    final modeLabel = state.sessionType == PomodoroSessionType.focus
        ? context.tr('pomodoro_session_focus')
        : context.tr('pomodoro_session_break');

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('pomodoro_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s20,
        ),
        children: [
          Text(
            'Fokus vaqtingizni boshqaring',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s12),
          _SessionTypeSwitch(
            selected: state.sessionType,
            onChanged: notifier.setSessionType,
          ),
          const SizedBox(height: AppSpacing.s12),
          TimerCard(
            remainingSeconds: state.remainingSeconds,
            totalSeconds: state.totalSeconds,
            label: modeLabel,
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Pomodoro soni',
                  value: '${state.pomodoroCount}',
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: StatsCard(
                  title: 'Bugungi sessiya',
                  value: '${state.completedSessions}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          PomodoroControlButtons(
            isRunning: state.isRunning,
            onStart: notifier.start,
            onPause: notifier.pause,
            onReset: notifier.reset,
            startLabel: context.tr('pomodoro_start'),
            pauseLabel: context.tr('pomodoro_pause'),
            resetLabel: context.tr('pomodoro_reset'),
          ),
          const SizedBox(height: AppSpacing.s12),
          SettingsSection(
            focusMinutes: state.focusMinutes,
            breakMinutes: state.breakMinutes,
            soundOn: state.soundOn,
            onFocusMinus: () =>
                notifier.updateFocusMinutes(state.focusMinutes - 1),
            onFocusPlus: () =>
                notifier.updateFocusMinutes(state.focusMinutes + 1),
            onBreakMinus: () =>
                notifier.updateBreakMinutes(state.breakMinutes - 1),
            onBreakPlus: () =>
                notifier.updateBreakMinutes(state.breakMinutes + 1),
            onSoundChanged: notifier.toggleSound,
          ),
        ],
      ),
    );
  }
}

class _SessionTypeSwitch extends StatelessWidget {
  const _SessionTypeSwitch({required this.selected, required this.onChanged});

  final PomodoroSessionType selected;
  final ValueChanged<PomodoroSessionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchChip(
              label: context.tr('pomodoro_session_focus'),
              selected: selected == PomodoroSessionType.focus,
              onTap: () => onChanged(PomodoroSessionType.focus),
            ),
          ),
          Expanded(
            child: _SwitchChip(
              label: context.tr('pomodoro_session_break'),
              selected: selected == PomodoroSessionType.breakTime,
              onTap: () => onChanged(PomodoroSessionType.breakTime),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchChip extends StatelessWidget {
  const _SwitchChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.button),
        color: selected ? AppColors.surface : Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
