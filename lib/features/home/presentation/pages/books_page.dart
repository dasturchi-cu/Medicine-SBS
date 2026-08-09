import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/models/content_asset_models.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/telegram_service.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/books_state.dart';
import '../../../../core/theme/design_system.dart';

String _formatPrice(double v) {
  final s = v.toStringAsFixed(0);
  return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
}

/// Qulflangan kitob bosilганда narx + tavsif + Telegram modalini ko'rsatadi.
/// Home sahifasidagi mini-ro'yxat va Kitoblar sahifasi ikkalasida ishlatiladi.
Future<void> showLockedBookSheet(BuildContext context, WidgetRef ref, BookItemModel item) async {
    final auth = ref.read(authControllerProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "${_formatPrice(item.priceUzs)} so'm",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
              ),
              if (item.description.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(item.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Telegram orqali sotib olish'),
                  onPressed: () async {
                    await TelegramService().openTelegram(
                      courseName: item.title,
                      userId: auth.userId ?? 'mehmon',
                      courseId: item.id,
                      userName: auth.name,
                      userPhone: auth.email,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
}

class BooksPage extends ConsumerWidget {
  const BooksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksFeedProvider);
    final progressAsync = ref.watch(bookProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kitoblar')),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text("Server bilan aloqa yo'q")),
        data: (items) {
          final progressByBook = {
            for (final p in (progressAsync.valueOrNull ?? const <BookProgressModel>[])) p.bookId: p,
          };
          if (items.isEmpty) {
            return const Center(child: Text("Hozircha kitoblar yo'q"));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final progress = progressByBook[item.id];
              final locked = item.isLocked;
              final subtitle = locked
                  ? "${_formatPrice(item.priceUzs)} so'm · Qulf 🔒"
                  : (progress == null
                      ? item.author
                      : 'Progress: ${progress.progressPercent.toStringAsFixed(1)}%');
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: _BookCoverImage(url: item.coverImageUrl),
                    ),
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Icon(
                    locked ? Icons.lock_outline : Icons.chevron_right,
                    color: locked ? AppColors.primary : null,
                  ),
                  onTap: () {
                    if (locked) {
                      showLockedBookSheet(context, ref, item);
                    } else {
                      context.push('${AppRoutes.bookReader}?id=${item.id}');
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BookCoverImage extends StatelessWidget {
  const _BookCoverImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final value = url.trim();
    if (value.isEmpty) return const ColoredBox(color: Color(0xFFE9F0FF));
    if (value.startsWith('data:image')) {
      final comma = value.indexOf(',');
      if (comma > 0) {
        try {
          final payload = value.substring(comma + 1).replaceAll(RegExp(r'\s'), '');
          return Image.memory(base64Decode(payload), fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE9F0FF)));
        } catch (_) {
          return const ColoredBox(color: Color(0xFFE9F0FF));
        }
      }
    }
    return Image.network(value, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE9F0FF)));
  }
}
