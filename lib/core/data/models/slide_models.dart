class HomeSlideItem {
  static String normalizeButtonLabel(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 'Boshlash';
    final lower = t.toLowerCase();
    if (lower == 'boshlashs' || lower == 'boshlash.') return 'Boshlash';
    return t;
  }

  const HomeSlideItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.buttonText,
    required this.courseId,
    required this.orderNo,
  });

  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String buttonText;
  final String? courseId;
  final int orderNo;

  factory HomeSlideItem.fromJson(Map<String, dynamic> json) {
    final rawCourse = json['course_id'];
    final courseStr = rawCourse == null ? '' : rawCourse.toString().trim();

    return HomeSlideItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      buttonText: normalizeButtonLabel((json['button_text'] ?? 'Boshlash').toString()),
      courseId: courseStr.isEmpty ? null : courseStr,
      orderNo: int.tryParse((json['order_no'] ?? '1').toString()) ?? 1,
    );
  }
}
