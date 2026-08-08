class BookItemModel {
  const BookItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.fileUrl,
    required this.fileMime,
    required this.author,
    required this.categoryName,
    required this.pageCount,
  });

  final String id;
  final String title;
  final String description;
  final String coverImageUrl;
  final String fileUrl;
  final String fileMime;
  final String author;
  final String categoryName;
  final int pageCount;

  factory BookItemModel.fromJson(Map<String, dynamic> json) {
    return BookItemModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      coverImageUrl: (json['cover_image_url'] ?? '').toString(),
      fileUrl: (json['file_url'] ?? '').toString(),
      fileMime: (json['file_mime'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
      categoryName: (json['category_name'] ?? '').toString(),
      pageCount: int.tryParse((json['page_count'] ?? '0').toString()) ?? 0,
    );
  }
}

class BookProgressModel {
  const BookProgressModel({
    required this.bookId,
    required this.pageNo,
    required this.progressPercent,
  });

  final String bookId;
  final int pageNo;
  final double progressPercent;

  factory BookProgressModel.fromJson(Map<String, dynamic> json) {
    return BookProgressModel(
      bookId: (json['book_id'] ?? '').toString(),
      pageNo: int.tryParse((json['page_no'] ?? '1').toString()) ?? 1,
      progressPercent: double.tryParse((json['progress_percent'] ?? '0').toString()) ?? 0,
    );
  }
}

class LessonAssetModel {
  const LessonAssetModel({
    required this.id,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.fileType,
    required this.previewImageUrl,
    required this.lessonId,
    required this.orderNo,
  });

  final String id;
  final String title;
  final String description;
  final String fileUrl;
  final String fileType;
  final String previewImageUrl;
  final String lessonId;
  final int orderNo;

  factory LessonAssetModel.fromJson(Map<String, dynamic> json) {
    return LessonAssetModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      fileUrl: (json['file_url'] ?? '').toString(),
      fileType: (json['file_type'] ?? 'pdf').toString(),
      previewImageUrl: (json['preview_image_url'] ?? '').toString(),
      lessonId: (json['lesson_id'] ?? '').toString(),
      orderNo: int.tryParse((json['order_no'] ?? '1').toString()) ?? 1,
    );
  }
}
