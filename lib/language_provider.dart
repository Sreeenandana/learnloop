import 'package:flutter/foundation.dart';

class LanguageProvider extends ChangeNotifier {
  String _language = "Java"; // default value

  String get language => _language;

  void setLanguage(String newLanguage) {
    if (_language != newLanguage) {
      _language = newLanguage;
      notifyListeners();
    }
  }
}
