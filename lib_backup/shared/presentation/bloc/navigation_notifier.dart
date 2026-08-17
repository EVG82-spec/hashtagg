import 'package:flutter/foundation.dart';

class NavigationNotifier extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }

  void selectHome() => setSelectedIndex(0);
  void selectFavorites() => setSelectedIndex(1);
  void selectAdd() => setSelectedIndex(2);
  void selectChats() => setSelectedIndex(3);
  void selectProfile() => setSelectedIndex(4);
}
