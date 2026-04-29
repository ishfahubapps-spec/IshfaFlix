import 'package:flutter/material.dart';

class BottombarProvider extends ChangeNotifier {
  int bottomNavIndex = 0;
  bool isShowAppbar = true;

  Future setAppbarVisibility(bool isShowAppbar) async {
    this.isShowAppbar = isShowAppbar;
    notifyListeners();
  }

  Future setBottomNavIndex(int index) async {
    bottomNavIndex = index;
    notifyListeners();
  }

  void clearProvider() {
    isShowAppbar = true;
    bottomNavIndex = 0;
  }
}
