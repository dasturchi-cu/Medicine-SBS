class LessonSlideItem {
  const LessonSlideItem({
    required this.id,
    required this.lessonId,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.orderNo,
  });

  final String id;
  final String lessonId;
  final String title;
  final String body;
  final String imageUrl;
  final int orderNo;

  factory LessonSlideItem.fromJson(Map<String, dynamic> json) {
    return LessonSlideItem(
      id: (json['id'] ?? '').toString(),
      lessonId: (json['lesson_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      orderNo: int.tryParse((json['order_no'] ?? '1').toString()) ?? 1,
    );
  }
}
