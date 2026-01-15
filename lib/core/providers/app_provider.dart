import 'package:flutter/material.dart';

/// Application-wide state provider
class AppProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _currentTab = 'home';
  bool _isDarkMode = true;
  String _language = 'en';

  // Getters
  bool get isLoading => _isLoading;
  String get currentTab => _currentTab;
  bool get isDarkMode => _isDarkMode;
  String get language => _language;

  // Setters
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setCurrentTab(String tab) {
    _currentTab = tab;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }
}
