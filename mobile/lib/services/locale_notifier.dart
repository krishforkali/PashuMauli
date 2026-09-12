import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _langKey = 'pm_selected_language';

/// Manages selected locale with persistence via shared_preferences.
class LocaleNotifier extends StateNotifier<Locale> {
  final SharedPreferences _prefs;

  LocaleNotifier(this._prefs) : super(_loadInitial(_prefs));

  static Locale _loadInitial(SharedPreferences prefs) {
    final lang = prefs.getString(_langKey);
    return _localeFromCode(lang);
  }

  static Locale _localeFromCode(String? code) {
    switch (code) {
      case 'hi':
        return const Locale('hi');
      case 'mr':
        return const Locale('mr');
      default:
        return const Locale('en');
    }
  }

  Future<void> setLocale(Locale locale) async {
    await _prefs.setString(_langKey, locale.languageCode);
    state = locale;
  }

  String get currentLanguageCode => state.languageCode;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

final localeNotifierProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});
