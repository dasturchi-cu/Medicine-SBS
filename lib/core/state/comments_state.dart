import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/comment_models.dart';
import '../di/providers.dart';

final courseCommentsFeedProvider = StreamProvider.autoDispose.family<List<AppCommentItem>, ({String courseKey, String userId})>((
  ref,
  args,
) {
  return ref.read(commentsRepositoryProvider).watchComments(
    courseKey: args.courseKey,
    userId: args.userId,
    pollInterval: const Duration(seconds: 15),
  );
});
