import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_fi/features/claimable/view/claimable_list_screen.dart';
import 'package:next_fi/features/swap/view/swap_screen.dart';
import 'package:next_fi/features/transactions/view/transaction_screen.dart';
import 'package:next_fi/features/wallet_home/view/wallet_home_screen.dart';

class TabVM extends ChangeNotifier {
  int _currentIndex = 0;
  bool _isFirstTime = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  int get currentIndex => _currentIndex;
  bool get isFirstTime => _isFirstTime;

  final List<Widget> screens = const [
    WalletHomeScreen(),
    SwapScreen(),
    ClaimableListScreen(),
    TransactionScreen(),
  ];

  TabVM() {
    _loadFirstTimeStatus();
  }

  void setTab(int index) {
    if (index < 0 || index >= screens.length) return;
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> _loadFirstTimeStatus() async {
    String? value = await _secureStorage.read(key: 'first_time');
    _isFirstTime = value == null ? true : value.toLowerCase() == 'true';
    notifyListeners();
  }

  Future<void> setFirstTimeFlag(bool value) async {
    await _secureStorage.write(key: 'first_time', value: value.toString());
    _isFirstTime = value;
    notifyListeners();
  }
}