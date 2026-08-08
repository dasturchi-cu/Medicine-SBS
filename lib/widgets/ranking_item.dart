import 'package:flutter/material.dart';

import '../core/theme/design_system.dart';

class RankingItem extends StatelessWidget {
  const RankingItem({
    super.key,
    required this.rank,
    required this.name,
    required this.timeLabel,
    required this.isCurrentUser,
    this.prefixLabel,
  });

  final int rank;
  final String name;
  final String timeLabel;
  final bool isCurrentUser;
  final String? prefixLabel;

  Color _rankColor() => AppColors.primary;

  bool get _isTop3 => rank <= 3;

  Color _topBgColor() {
    if (rank == 1) return AppColors.primary.withValues(alpha: 0.12);
    if (rank == 2) return AppColors.primary.withValues(alpha: 0.09);
    return AppColors.primary.withValues(alpha: 0.06);
  }

  @override
  Widget build(BuildContext context) {
    final bg = isCurrentUser ? AppColors.surfaceAlt : AppColors.surface;
    final cardColor = _isTop3 ? _topBgColor() : bg;

    return Card(
      margin: EdgeInsets.zero,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isTop3
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: _rankColor(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            CircleAvatar(
              radius: _isTop3 ? 20 : 18,
              backgroundColor: _rankColor().withValues(alpha: 0.15),
              child: Icon(Icons.person, color: _rankColor()),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (prefixLabel != null)
                    Text(
                      prefixLabel!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: _isTop3 ? FontWeight.w900 : FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: Text(
                timeLabel,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: _isTop3 ? FontWeight.w900 : FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
