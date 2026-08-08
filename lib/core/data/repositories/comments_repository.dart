import '../models/comment_models.dart';

abstract class CommentsRepository {
  Future<List<AppCommentItem>> fetchComments({
    required String courseKey,
    required String userId,
  });

  Future<void> addComment({
    required String courseKey,
    required String userId,
    required String authorName,
    required String text,
  });

  Future<void> addReply({
    required String commentId,
    required String userId,
    required String authorName,
    required String text,
  });

  Future<void> toggleLike({
    required String commentId,
    required String userId,
  });

  Stream<List<AppCommentItem>> watchComments({
    required String courseKey,
    required String userId,
    Duration pollInterval = const Duration(seconds: 6),
  });
}
