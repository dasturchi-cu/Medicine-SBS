import 'package:flutter/material.dart';

import '../core/theme/design_system.dart';
import 'course_visual.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.visualKind,
    required this.title,
    required this.author,
    required this.imageUrl,
    required this.progress,
    required this.ratingText,
    required this.commentCountText,
    required this.videoCountText,
    required this.buttonText,
    required this.buttonColor,
    required this.onPressed,
    this.onMessagePressed,
    this.animationDelayMs = 0,
    this.showStats = true,
  });

  final String visualKind;
  final String title;
  final String author;
  final String imageUrl;
  final double progress;
  final String ratingText;
  final String commentCountText;
  final String videoCountText;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onPressed;
  final VoidCallback? onMessagePressed;
  final int animationDelayMs;

  /// Fanlar (subjects) ro'yxatida yulduzcha reyting / video / sharh yozuvlari
  /// ko'rsatilmaydi — faqat kurs nomi va muallif qoladi.
  final bool showStats;

  static const double _statIcon = 14;

  @override
  Widget build(BuildContext context) {
    final statStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          fontSize: 12,
        );
    final ratingStrong = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          fontSize: 12,
        );
    final dotStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.45),
          fontSize: 12,
          height: 1,
        );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + animationDelayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourseVisual(kind: visualKind, imageUrl: imageUrl),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0, 1),
                              minHeight: AppSpacing.s8,
                              backgroundColor: AppColors.surfaceAlt,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          '${(progress * 100).round()}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!showStats)
                          const Spacer()
                        else
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: _statIcon,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      ratingText,
                                      maxLines: 1,
                                      style: ratingStrong,
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('·', style: dotStyle),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.videocam_outlined,
                                      size: _statIcon,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      videoCountText,
                                      maxLines: 1,
                                      style: statStyle,
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text('·', style: dotStyle),
                                ),
                                InkWell(
                                  onTap: onMessagePressed,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                      horizontal: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: _statIcon,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          commentCountText,
                                          maxLines: 1,
                                          style: statStyle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        SizedBox(
                          height: 34,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                              ),
                            ),
                            onPressed: onPressed,
                            child: Text(
                              buttonText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
