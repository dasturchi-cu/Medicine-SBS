class Category {
  final String id;
  final String titleUz;
  final String iconKey;

  const Category({
    required this.id,
    required this.titleUz,
    required this.iconKey,
  });
}

class Course {
  final String id;
  final String categoryId;
  final String titleUz;
  final String authorUz;
  final String imageUrl;
  final String priceUz;
  final double progress; // 0..1
  final double rating; // 0..5
  final bool isPaid;
  final String descriptionUz;
  final List<Section> sections;

  const Course({
    required this.id,
    required this.categoryId,
    required this.titleUz,
    required this.authorUz,
    required this.imageUrl,
    required this.priceUz,
    required this.progress,
    required this.rating,
    required this.isPaid,
    required this.descriptionUz,
    required this.sections,
  });
}

class Section {
  final String id;
  final String titleUz;
  final String durationUz;
  final List<Lesson> lessons;

  const Section({
    required this.id,
    required this.titleUz,
    required this.durationUz,
    required this.lessons,
  });
}

class Lesson {
  final String id;
  final String titleUz;
  final String durationUz;
  final bool isLocked;
  final bool isCompleted;
  final String transcriptUz;
  final List<String> slides;
  final String videoUrl;

  const Lesson({
    required this.id,
    required this.titleUz,
    required this.durationUz,
    required this.isLocked,
    required this.isCompleted,
    required this.transcriptUz,
    required this.slides,
    required this.videoUrl,
  });
}

