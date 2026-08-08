import 'package:flutter/material.dart';

IconData iconForCategoryKey(String key) {
  switch (key) {
    case 'online':
      return Icons.play_circle_outline;
    case 'books':
      return Icons.menu_book_outlined;
    default:
      return Icons.grid_view_rounded;
  }
}

