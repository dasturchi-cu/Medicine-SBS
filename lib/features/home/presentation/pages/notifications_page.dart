import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/state/notifications_state.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final feedAsync = ref.watch(notificationsFeedProvider);
    final repo = ref.watch(notificationsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notificationlar')),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Notificationlarni yuklashda xatolik.')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Hozircha notification yo‘q.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final userId = auth.userId ?? '';
                  await repo.markViewed(userId: userId, notificationId: item.id);
                  await repo.markClicked(userId: userId, notificationId: item.id);
                  ref.invalidate(notificationsFeedProvider);
                },
                child: Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NotificationImage(imageUrl: item.imageUrl),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                if (!item.viewed)
                                  const Icon(Icons.brightness_1, size: 10, color: Color(0xFF2563EB)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(item.message),
                            const SizedBox(height: 8),
                            Text(
                              _formatDate(item.sentAt),
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _formatDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)} ${two(value.hour)}:${two(value.minute)}';
}

class _NotificationImage extends StatelessWidget {
  const _NotificationImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) return _placeholder();

    if (trimmed.startsWith('data:image')) {
      final commaIndex = trimmed.indexOf(',');
      if (commaIndex > 0) {
        final payload = trimmed.substring(commaIndex + 1);
        try {
          final bytes = base64Decode(payload);
          return Image.memory(
            bytes,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _placeholder(),
          );
        } catch (_) {
          return _placeholder();
        }
      }
    }

    return Image.network(
      trimmed,
      width: double.infinity,
      height: 180,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: double.infinity,
      height: 180,
      color: const Color(0xFFE9F0FF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 32,
        color: Color(0xFF1E6BB8),
      ),
    );
  }
}
