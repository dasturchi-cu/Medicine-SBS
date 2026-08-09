import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/content_asset_models.dart';
import '../di/providers.dart';
import 'auth_controller.dart';

final booksFeedProvider = StreamProvider<List<BookItemModel>>((ref) {
  // user_id — qulf/ochiqlik shu foydalanuvchiga qarab hisoblanadi (admin grant).
  final userId = ref.watch(authControllerProvider).userId ?? '';
  return ref.read(booksRepositoryProvider).watchBooks(userId: userId);
});

final bookProgressProvider = FutureProvider<List<BookProgressModel>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final userId = auth.userId ?? '';
  if (userId.isEmpty) return const [];
  return ref.read(booksRepositoryProvider).fetchProgress(userId: userId);
});
