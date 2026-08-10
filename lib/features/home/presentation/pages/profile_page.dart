import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/state/purchase_controller.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/theme/theme_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _showNameEditDialog(BuildContext context, WidgetRef ref) async {
    final auth = ref.read(authControllerProvider);
    var editedName = auth.name == 'Ism yozmagansiz' ? '' : auth.name;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ismni tahrirlash'),
          content: TextFormField(
            initialValue: editedName,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Ismingizni kiriting'),
            onChanged: (value) => editedName = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(editedName.trim()),
              child: const Text('Saqlash'),
            ),
          ],
        );
      },
    );
    if (!context.mounted || newName == null) return;
    try {
      await ref.read(authControllerProvider.notifier).updateName(newName);
    } on AuthServiceError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(courseRepositoryProvider);
    final progress = ref.watch(progressControllerProvider);
    final purchase = ref.watch(purchaseControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final myCount = repo.getCourses().where((c) {
      final p = progress.byCourseId[c.id];
      return (p?.enrolled ?? false) || c.progress > 0;
    }).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        children: [
          Text(
            context.tr('profile'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.s12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.isLoggedIn
                              ? 'ID: ${auth.userId ?? '-'}'
                              : '$myCount ta kurs',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (auth.isLoggedIn)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _showNameEditDialog(context, ref),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Tahrirlash'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (auth.isLoggedIn && auth.userId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: auth.userId!));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ID nusxalandi')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined),
                  label: const Text('ID ni nusxalash'),
                ),
              ),
            ),
          if (!auth.isLoggedIn && purchase.purchasedCourseIds.isEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Akkauntga kiring'),
                subtitle: const Text('Kurs sotib olish uchun login qiling'),
                onTap: () => context.push(AppRoutes.login),
              ),
            ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(context.tr('nav_my_courses')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(AppRoutes.myCourses),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: Text(context.tr('language')),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppLang>(
                      value:
                          (ref
                                      .watch(localizationProvider)
                                      .valueOrNull
                                      ?.langCode ??
                                  'uz') ==
                              'ru'
                          ? AppLang.ru
                          : (ref
                                        .watch(localizationProvider)
                                        .valueOrNull
                                        ?.langCode ??
                                    'uz') ==
                                'en'
                          ? AppLang.en
                          : AppLang.uz,
                      items: [
                        DropdownMenuItem(
                          value: AppLang.uz,
                          child: Text(context.tr('lang_uz')),
                        ),
                        DropdownMenuItem(
                          value: AppLang.ru,
                          child: Text(context.tr('lang_ru')),
                        ),
                        DropdownMenuItem(
                          value: AppLang.en,
                          child: Text(context.tr('lang_en')),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        ref
                            .read(localizationProvider.notifier)
                            .setLang(
                              v == AppLang.ru
                                  ? 'ru'
                                  : v == AppLang.en
                                  ? 'en'
                                  : 'uz',
                            );
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    ref.watch(themeControllerProvider) ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  ),
                  title: const Text('Tun rejimi'),
                  subtitle: Text(ref.watch(themeControllerProvider) ? 'Yoqilgan' : "O'chirilgan"),
                  value: ref.watch(themeControllerProvider),
                  onChanged: (v) => ref.read(themeControllerProvider.notifier).toggle(v),
                ),
              ],
            ),
          ),
          if (auth.isLoggedIn) ...[
            const SizedBox(height: AppSpacing.s12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, ref),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Akkauntdan chiqish'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Akkauntdan chiqish'),
          content: const Text('Rostdan ham akkauntdan chiqmoqchimisiz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Chiqish'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).logout();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Akkauntdan chiqdingiz')),
    );
  }
}
