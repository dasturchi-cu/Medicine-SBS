import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/models/content_asset_models.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/books_state.dart';

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
                  subtitle: Text(
                    progress == null ? item.author : 'Progress: ${progress.progressPercent.toStringAsFixed(1)}%',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('${AppRoutes.bookReader}?id=${item.id}'),
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
          return Image.memory(base64Decode(payload), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE9F0FF)));
        } catch (_) {
          return const ColoredBox(color: Color(0xFFE9F0FF));
        }
      }
    }
    return Image.network(value, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE9F0FF)));
  }
}
