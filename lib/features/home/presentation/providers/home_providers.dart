import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedCategoryIdProvider = StateProvider<String>(
  (ref) => 'cat_nevralogiya',
);

final homeSearchQueryProvider = StateProvider<String>((ref) => '');
