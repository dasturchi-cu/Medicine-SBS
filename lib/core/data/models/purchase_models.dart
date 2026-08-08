class UserEntitlementItem {
  const UserEntitlementItem({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.sectionId,
    required this.isActive,
  });

  final String id;
  final String userId;
  final String? courseId;
  final String? sectionId;
  final bool isActive;

  factory UserEntitlementItem.fromJson(Map<String, dynamic> json) {
    return UserEntitlementItem(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      courseId: json['course_id']?.toString(),
      sectionId: json['section_id']?.toString(),
      isActive: json['is_active'] == true,
    );
  }
}
