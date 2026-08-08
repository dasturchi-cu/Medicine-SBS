import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stores current selected course id for cross-screen flows.
final selectedCourseIdProvider = StateProvider<String?>((ref) => null);

