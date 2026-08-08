import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/slide_models.dart';
import '../di/providers.dart';

final slidesFeedProvider = StreamProvider<List<HomeSlideItem>>((ref) {
  return ref.read(slidesRepositoryProvider).watchSlides();
});
