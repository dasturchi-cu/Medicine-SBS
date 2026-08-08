class CourseBannerItem {
  const CourseBannerItem({
    required this.id,
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.priceLabel,
    required this.courseId,
    required this.telegram,
    required this.isActive,
  });

  final String id;
  final String title;
  final String message;
  final String imageUrl;
  final String priceLabel;
  final String? courseId;
  final String telegram;
  final bool isActive;

  factory CourseBannerItem.fromJson(Map<String, dynamic> json) {
    return CourseBannerItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      priceLabel: (json['price_label'] ?? '').toString(),
      courseId: json['course_id']?.toString(),
      telegram: (json['telegram'] ?? 'Mr_Xusanboy').toString(),
      isActive: json['is_active'] == true,
    );
  }
}
