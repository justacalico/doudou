import 'package:flutter/material.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  ValueNotifier<int> selectedPageIndex = ValueNotifier<int>(0);

  void navigateToMainPage(int index) {
    selectedPageIndex.value = index;
  }

  void selectPage(int index) {
    selectedPageIndex.value = index;
  }
}