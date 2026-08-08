import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'localization_service.dart';

enum AppLang { uz, ru, en }

@immutable
class LocalizationState {
  const LocalizationState({
    required this.langCode,
    required this.all,
  });

  final String langCode; // 'uz' | 'ru' | 'en'
  final Map<String, Map<String, String>> all;

  Map<String, String> get current => all[langCode] ?? const {};
  Map<String, String> get fallbackEn => all['en'] ?? const {};

  LocalizationState copyWith({String? langCode, Map<String, Map<String, String>>? all}) {
    return LocalizationState(
      langCode: langCode ?? this.langCode,
      all: all ?? this.all,
    );
  }
}

final localizationServiceProvider = Provider<LocalizationService>((ref) {
  return LocalizationService();
});

final localizationProvider =
    AsyncNotifierProvider<LocalizationController, LocalizationState>(LocalizationController.new);

class LocalizationController extends AsyncNotifier<LocalizationState> {
  @override
  Future<LocalizationState> build() async {
    final service = ref.read(localizationServiceProvider);
    final all = await service.preloadAll();
    return LocalizationState(langCode: 'uz', all: all);
  }

  void setLang(String code) {
    final s = state.valueOrNull;
    if (s == null) return;
    if (code != 'uz' && code != 'ru' && code != 'en') return;
    state = AsyncData(s.copyWith(langCode: code));
  }
}

String translate(LocalizationState st, String key, [Map<String, String>? params]) {
  final raw = st.current[key] ?? st.fallbackEn[key] ?? key;
  if (params == null || params.isEmpty) return raw;
  var out = raw;
  params.forEach((k, v) => out = out.replaceAll('{$k}', v));
  return out;
}

class TrScope extends InheritedWidget {
  const TrScope({
    super.key,
    required this.state,
    required super.child,
  });

  final LocalizationState state;

  static LocalizationState of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<TrScope>();
    return w!.state;
  }

  @override
  bool updateShouldNotify(TrScope oldWidget) => oldWidget.state.langCode != state.langCode;
}

extension TrExtension on BuildContext {
  String tr(String key, {Map<String, String>? params}) {
    final st = TrScope.of(this);
    return translate(st, key, params);
  }
}

