import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _hasCompletedOnboarding = false;
  bool _companionEnabled = true;
  bool _notificationsEnabled = true;
  bool _walkRemindersEnabled = true;
  bool _visionAutoStart = false;
  int _visionAnalysisInterval = 5;
  String? _selectedModelPath;
  bool _selectedModelIsNetwork = false;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get companionEnabled => _companionEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get walkRemindersEnabled => _walkRemindersEnabled;
  bool get visionAutoStart => _visionAutoStart;
  int get visionAnalysisInterval => _visionAnalysisInterval;
  String? get selectedModelPath => _selectedModelPath;
  bool get selectedModelIsNetwork => _selectedModelIsNetwork;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _hasCompletedOnboarding = prefs.getBool('hasCompletedOnboarding') ?? false;
    _companionEnabled = prefs.getBool('companionEnabled') ?? true;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    _walkRemindersEnabled = prefs.getBool('walkRemindersEnabled') ?? true;
    _visionAutoStart = prefs.getBool('visionAutoStart') ?? false;
    _visionAnalysisInterval = prefs.getInt('visionAnalysisInterval') ?? 5;
    _selectedModelPath = prefs.getString('selectedModelPath');
    _selectedModelIsNetwork = prefs.getBool('selectedModelIsNetwork') ?? false;
    notifyListeners();
  }

  Future<void> setOnboardingCompleted(bool value) async {
    _hasCompletedOnboarding = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', value);
    notifyListeners();
  }

  Future<void> setCompanionEnabled(bool value) async {
    _companionEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('companionEnabled', value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    notifyListeners();
  }

  Future<void> setWalkRemindersEnabled(bool value) async {
    _walkRemindersEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('walkRemindersEnabled', value);
    notifyListeners();
  }



  Future<void> setVisionAnalysisInterval(int value) async {
    _visionAnalysisInterval = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('visionAnalysisInterval', value);
    notifyListeners();
  }

  Future<void> setVisionAutoStart(bool value) async {
    _visionAutoStart = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('visionAutoStart', value);
    notifyListeners();
  }

  Future<void> setSelectedModel(String? path, bool isNetwork) async {
    _selectedModelPath = path;
    _selectedModelIsNetwork = isNetwork;
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove('selectedModelPath');
    } else {
      await prefs.setString('selectedModelPath', path);
    }
    await prefs.setBool('selectedModelIsNetwork', isNetwork);
    notifyListeners();
  }
}
