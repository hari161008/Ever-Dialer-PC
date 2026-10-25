import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages appearance, theme, scale, and font settings for Ever Dialer PC.
class AppearancePreferences extends ChangeNotifier {
  final SharedPreferences? _prefs;

  late String _colorMode;
  late double _displayScale;
  late double _fontScale;
  late bool _dynamicColors;
  Color? _customPrimaryColor;
  String? _customFontFamily;
  late bool _saturatedColors;
  late String _saturatedTarget;
  late double _backgroundBlur;
  late double _windowTransparency;
  late double _backgroundDimness;

  static const List<Map<String, String>> availableFonts = [
    {'id': 'system', 'name': 'System Default', 'family': ''},
    {'id': 'playwrite', 'name': 'Playwrite USA Modern', 'family': 'Playwrite'},
    {'id': 'comfortaa', 'name': 'Comfortaa', 'family': 'Comfortaa'},
    {'id': 'patrick_hand', 'name': 'Patrick Hand', 'family': 'Patrick Hand'},
    {'id': 'gochi_hand', 'name': 'Gochi Hand', 'family': 'Gochi Hand'},
    {'id': 'advent_pro', 'name': 'Advent Pro', 'family': 'Advent Pro'},
  ];

  AppearancePreferences(this._prefs) {
    _displayScale = (_prefs?.getDouble('display_scale') ?? 1.0).clamp(0.70, 1.50);
    _fontScale = (_prefs?.getDouble('font_scale') ?? 1.0).clamp(0.70, 1.50);
    _backgroundBlur = (_prefs?.getDouble('background_blur') ?? 0.0).clamp(0.0, 30.0);
    final savedTransparency = _prefs?.getDouble('window_transparency');
    if (savedTransparency != null) {
      _windowTransparency = savedTransparency.clamp(0.0, 1.0);
    } else {
      final legacyDim = _prefs?.getDouble('background_dimness');
      _windowTransparency = legacyDim != null ? (1.0 - legacyDim).clamp(0.0, 1.0) : 0.0;
    }
    _backgroundDimness = (1.0 - _windowTransparency).clamp(0.0, 1.0);

    // Support legacy theme_mode ('dark', 'light', 'system') migration to color_mode
    final legacyTheme = _prefs?.getString('theme_mode');
    final savedColorMode = _prefs?.getString('color_mode');
    if (savedColorMode != null) {
      _colorMode = savedColorMode;
    } else if (legacyTheme == 'dark') {
      _colorMode = 'dark';
    } else if (legacyTheme == 'light') {
      _colorMode = 'light';
    } else {
      _colorMode = 'auto';
    }

    _dynamicColors = _prefs?.getBool('dynamic_colors') ?? true;

    final primaryInt = _prefs?.getInt('custom_primary_color');
    if (primaryInt != null) {
      _customPrimaryColor = Color(primaryInt);
    } else {
      _customPrimaryColor = const Color(0xFF6750A4);
    }

    _customFontFamily = _prefs?.getString('custom_font_family');
    _saturatedColors = _prefs?.getBool('saturated_colors') ?? false;
    _saturatedTarget = _prefs?.getString('saturated_target') ?? 'container';
  }

  String get colorMode => _colorMode;
  double get displayScale => _displayScale;
  double get fontScale => _fontScale;
  double get backgroundBlur => _backgroundBlur;
  double get windowTransparency => _windowTransparency;
  double get backgroundDimness => _backgroundDimness;
  bool get dynamicColors => _dynamicColors;
  Color get customPrimaryColor => _customPrimaryColor ?? const Color(0xFF6750A4);
  String? get customFontFamily => _customFontFamily;
  bool get saturatedColors => _saturatedColors;
  String get saturatedTarget => _saturatedTarget;

  String get currentFontDisplayName {
    if (_customFontFamily == null || _customFontFamily!.isEmpty) {
      return 'System Default';
    }
    for (final font in availableFonts) {
      if (font['family'] == _customFontFamily) {
        return font['name']!;
      }
    }
    return _customFontFamily!;
  }

  ThemeMode get themeMode {
    switch (_colorMode) {
      case 'dark':
      case 'black':
        return ThemeMode.dark;
      case 'light':
      case 'white':
        return ThemeMode.light;
      case 'auto':
      default:
        return ThemeMode.system;
    }
  }

  void setColorMode(String mode) {
    if (_colorMode == mode) return;
    _colorMode = mode;
    _prefs?.setString('color_mode', mode);
    // Also update legacy theme_mode for compatibility
    if (mode == 'dark' || mode == 'black') {
      _prefs?.setString('theme_mode', 'dark');
    } else if (mode == 'light' || mode == 'white') {
      _prefs?.setString('theme_mode', 'light');
    } else {
      _prefs?.setString('theme_mode', 'system');
    }
    notifyListeners();
  }

  void setDisplayScale(double val) {
    final clamped = double.parse(val.clamp(0.70, 1.50).toStringAsFixed(2));
    if (_displayScale == clamped) return;
    _displayScale = clamped;
    _prefs?.setDouble('display_scale', clamped);
    notifyListeners();
  }

  void setFontScale(double val) {
    final clamped = double.parse(val.clamp(0.70, 1.50).toStringAsFixed(2));
    if (_fontScale == clamped) return;
    _fontScale = clamped;
    _prefs?.setDouble('font_scale', clamped);
    notifyListeners();
  }

  void resetDisplayScale() => setDisplayScale(1.0);
  void resetFontScale() => setFontScale(1.0);

  void setBackgroundBlur(double val) {
    final clamped = double.parse(val.clamp(0.0, 30.0).toStringAsFixed(1));
    if (_backgroundBlur == clamped) return;
    _backgroundBlur = clamped;
    _prefs?.setDouble('background_blur', clamped);
    notifyListeners();
  }

  void setBackgroundDimness(double val) {
    setWindowTransparency(1.0 - val);
  }

  void setWindowTransparency(double val) {
    final clamped = double.parse(val.clamp(0.0, 1.0).toStringAsFixed(2));
    if (_windowTransparency == clamped) return;
    _windowTransparency = clamped;
    _backgroundDimness = (1.0 - clamped).clamp(0.0, 1.0);
    _prefs?.setDouble('window_transparency', clamped);
    notifyListeners();
  }

  void resetBackgroundSettings() {
    setBackgroundBlur(0.0);
    setWindowTransparency(0.0);
  }

  void setDynamicColors(bool val) {
    if (_dynamicColors == val) return;
    _dynamicColors = val;
    _prefs?.setBool('dynamic_colors', val);
    notifyListeners();
  }

  void setCustomPrimaryColor(Color color) {
    _customPrimaryColor = color;
    _prefs?.setInt('custom_primary_color', color.toARGB32());
    notifyListeners();
  }

  void setCustomFontFamily(String? family) {
    if (family == null || family.isEmpty) {
      _customFontFamily = null;
      _prefs?.remove('custom_font_family');
    } else {
      _customFontFamily = family;
      _prefs?.setString('custom_font_family', family);
    }
    notifyListeners();
  }

  void setSaturatedColors(bool val) {
    if (_saturatedColors == val) return;
    _saturatedColors = val;
    _prefs?.setBool('saturated_colors', val);
    notifyListeners();
  }

  void setSaturatedTarget(String target) {
    if (_saturatedTarget == target) return;
    _saturatedTarget = target;
    _prefs?.setString('saturated_target', target);
    notifyListeners();
  }
}
