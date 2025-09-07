import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/Screen/settings_screen.dart';
import 'package:next_fi/Screen/swap_screen.dart';
import 'package:next_fi/Screen/transaction_screen.dart';
import 'package:next_fi/Screen/wallet_home_screen.dart';

class TabProvider extends ChangeNotifier {
  int _currentIndex = 0;
  bool _isFirstTime = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  int get currentIndex => _currentIndex;
  bool get isFirstTime => _isFirstTime;

  final List<Widget> screens = const [
    WalletHomeScreen(),
    TransactionScreen(),
    SwapScreen(),
    SettingsScreen(),
  ];

  TabProvider() {
    _loadFirstTimeStatus();
  }

  void setTab(int index) {
    if (index < 0 || index >= screens.length) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// ✅ Loads the first-time flag securely (does NOT change it)
  Future<void> _loadFirstTimeStatus() async {
    String? value = await _secureStorage.read(key: 'first_time');
    _isFirstTime = value == null ? true : value.toLowerCase() == 'true';
    notifyListeners();
  }

  /// ✅ Manually update the first-time flag securely
  Future<void> setFirstTimeFlag(bool value) async {
    await _secureStorage.write(key: 'first_time', value: value.toString());
    _isFirstTime = value;
    notifyListeners();
  }
}
