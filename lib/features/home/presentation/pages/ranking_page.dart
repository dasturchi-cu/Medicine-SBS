import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../widgets/ranking_item.dart';

/// Reyting tab'i: kalit, sarlavha (tr yoki literal), davr, manba (video/pomodoro).
class _RankTab {
  final String key;
  final String? titleKey; // tr kaliti (null bo'lsa literal `title` ishlatiladi)
  final String title; // literal (masalan "Pomodoro")
  final String period;
  final String? source;
  const _RankTab(this.key, {this.titleKey, this.title = '', required this.period, this.source});
}

// Video (o'qish) reytingi — 5 davr; + alohida "Pomodoro" (faqat kunlik).
// Pomodoro 2-o'rinda (Kunlik'dan keyin) — chekkada qolib ko'zga tashlanmasligi
// uchun; emoji bilan ajratilgan.
const List<_RankTab> _kTabs = <_RankTab>[
  _RankTab('daily', titleKey: 'tab_daily', period: 'daily', source: 'video'),
  _RankTab('pomodoro', title: '⏱ Pomodoro', period: 'daily', source: 'pomodoro'),
  _RankTab('weekly', titleKey: 'tab_weekly', period: 'weekly', source: 'video'),
  _RankTab('monthly', titleKey: 'tab_monthly', period: 'monthly', source: 'video'),
  _RankTab('yearly', titleKey: 'tab_yearly', period: 'yearly', source: 'video'),
  _RankTab('overall', titleKey: 'tab_overall', period: 'overall', source: 'video'),
];

class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Map<String, bool> _loading = {};
  final Map<String, List<_RankingUser>> _users = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _kTabs.length, vsync: this);
    _tabs.addListener(_onTabChanged);
    Future.microtask(() => _load(_kTabs.first));
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final tab = _kTabs[_tabs.index];
    if (!_users.containsKey(tab.key) && !(_loading[tab.key] ?? false)) {
      _load(tab);
    }
  }

  Future<void> _load(_RankTab tab) async {
    if (!mounted) return;
    setState(() => _loading[tab.key] = true);
    try {
      final currentUserId = ref.read(authControllerProvider).userId ?? "";
      final items = await ref
          .read(rankingRepositoryProvider)
          .fetchRanking(limit: 50, period: tab.period, source: tab.source);
      if (!mounted) return;
      setState(() {
        _users[tab.key] = items
            .map(
              (item) => _RankingUser(
                rank: item.rank,
                name: item.fullName,
                studyMinutes: item.quizMinutes.round(),
                me: item.userId == currentUserId,
              ),
            )
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _users[tab.key] = const []);
    } finally {
      if (mounted) setState(() => _loading[tab.key] = false);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('ranking')),
        actions: [
          IconButton(
            tooltip: context.tr('ranking_info_title'),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: Text(ctx.tr('ranking_info_title')),
                    content: Text(
                      ctx.tr('ranking_info_body').replaceAll('\\n', '\n'),
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(ctx.tr('btn_understood')),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: _kTabs
              .map((t) => Tab(text: t.titleKey != null ? context.tr(t.titleKey!) : t.title))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _kTabs.map((tab) {
          return _RankingList(
            users: _users[tab.key] ?? const [],
            loading: _loading[tab.key] ?? !_users.containsKey(tab.key),
            onRefresh: () => _load(tab),
          );
        }).toList(),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  const _RankingList({
    required this.users,
    required this.loading,
    required this.onRefresh,
  });

  final List<_RankingUser> users;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(child: Text('Reyting maʼlumoti yo‘q')),
          ],
        ),
      );
    }
    final top10 = users.take(10).toList();
    final meIndex = users.indexWhere((u) => u.me);
    final hasMe = meIndex >= 0;
    // "Sizning o'rningiz" bloki faqat foydalanuvchi ro'yxatda bor va Top 10 dan
    // tashqarida bo'lsa ko'rsatiladi. Aks holda 1-o'rindagi odam xato ko'rsatilardi.
    final showYourPlace = hasMe && meIndex >= 10;
    final me = hasMe ? users[meIndex] : null;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.s16),
        itemCount: top10.length + (showYourPlace ? 3 : 0),
        itemBuilder: (context, index) {
          final topEnd = top10.length;
          if (index < topEnd) {
            final u = top10[index];
            final h = u.studyMinutes ~/ 60;
            final m = u.studyMinutes % 60;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: RankingItem(
                rank: u.rank,
                name: u.name,
                timeLabel: context.tr(
                  'time_hm',
                  params: {'h': '$h', 'm': '$m'},
                ),
                isCurrentUser: u.me,
              ),
            );
          }

          if (showYourPlace && me != null) {
            final local = index - topEnd;
            if (local == 0) {
              return Text(
                context.tr('your_place'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              );
            }
            if (local == 1) return const SizedBox(height: AppSpacing.s8);
            return RankingItem(
              rank: me.rank,
              name: me.name,
              timeLabel: context.tr(
                'time_hm',
                params: {
                  'h': '${me.studyMinutes ~/ 60}',
                  'm': '${me.studyMinutes % 60}',
                },
              ),
              isCurrentUser: true,
              prefixLabel: context.tr('nav_profile'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _RankingUser {
  final int rank;
  final String name;
  final int studyMinutes;
  final bool me;

  const _RankingUser({
    required this.rank,
    required this.name,
    required this.studyMinutes,
    required this.me,
  });
}
