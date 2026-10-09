import 'package:flutter/foundation.dart';

class NavigationNotifier extends ChangeNotifier {
  int _selectedIndex = 0;
  int _homeTapCounter = 0;

  int get selectedIndex => _selectedIndex;
  int get homeTapCounter => _homeTapCounter;

  void setSelectedIndex(int index) {
    _selectedIndex = index;
    notifyListeners();
  }

  /// Вызывается при клике на "Домой"
  /// Увеличивает счётчик — HomeScreen слушает и сбрасывает на вкладку "Рекомендации" + скролл вверх
  void tapHome() {
    _selectedIndex = 0;
    _homeTapCounter++;
    notifyListeners();
  }

  void selectHome() => setSelectedIndex(0);
  void selectFavorites() => setSelectedIndex(1);
  void selectAdd() => setSelectedIndex(2);
  void selectChats() => setSelectedIndex(3);
  void selectProfile() => setSelectedIndex(4);
}
