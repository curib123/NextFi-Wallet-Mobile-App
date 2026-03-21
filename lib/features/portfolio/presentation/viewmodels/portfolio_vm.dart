import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:next_fi/core/services/network_monitor.dart';
import 'package:next_fi/core/services/portfolio/models/portfolio_models.dart';
import 'package:next_fi/core/services/portfolio/portfolio_core_service.dart';
import 'package:next_fi/core/services/wallet/wallet_manager.dart';
import 'package:next_fi/features/portfolio/presentation/viewmodels/portfolio_state.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/wallet_home_vm.dart';

class PortfolioVM extends ChangeNotifier {
  PortfolioVM({
    required WalletHomeVM walletHomeVM,
    required NetworkMonitor networkMonitor,
    WalletManager? walletManager,
    PortfolioCoreService? portfolioCoreService,
    Future<WalletPortfolioData> Function(String walletId, PortfolioRange range)?
        loadPortfolio,
  }) : _walletHomeVM = walletHomeVM,
       _networkMonitor = networkMonitor,
       _walletManager = walletManager ?? WalletManager.I,
       _portfolioCore = portfolioCoreService ?? PortfolioCoreService.I,
       _loadPortfolio = loadPortfolio {
    _walletHomeVM.addListener(_onWalletChanged);
    _networkMonitor.addListener(_onNetworkChanged);
    unawaited(bindActiveWallet());
  }

  final WalletHomeVM _walletHomeVM;
  final NetworkMonitor _networkMonitor;
  final WalletManager _walletManager;
  final PortfolioCoreService _portfolioCore;
  final Future<WalletPortfolioData> Function(String walletId, PortfolioRange range)?
      _loadPortfolio;

  PortfolioState _state = const PortfolioState();
  PortfolioState get state => _state;

  int _loadToken = 0;
  bool _disposed = false;

  Future<void> bindActiveWallet() async {
    final backendId = await _walletManager.getActiveWalletBackendId();
    final walletState = _walletHomeVM.state;
    final address = walletState.address?.trim();
    final label = walletState.walletName?.trim();

    final changed =
        _state.activeWalletId != backendId ||
        _state.activeWalletAddress != address ||
        _state.walletLabel != label;

    if (!changed) return;

    _set(
      PortfolioState(
        activeWalletId: backendId,
        activeWalletAddress: address,
        walletLabel: label,
        selectedRange: _state.selectedRange,
        loading: backendId != null && backendId.trim().isNotEmpty,
        isOffline: !_networkMonitor.isOnline,
      ),
    );

    if (backendId == null || backendId.trim().isEmpty) return;
    await load(range: _state.selectedRange);
  }

  Future<void> load({PortfolioRange? range}) async {
    final walletId = _state.activeWalletId?.trim();
    if (walletId == null || walletId.isEmpty) return;

    final selectedRange = range ?? _state.selectedRange;
    final token = ++_loadToken;
    _set(
      _state.copyWith(
        selectedRange: selectedRange,
        loading: true,
        error: null,
        data: null,
      ),
    );

    try {
      final data =
          await (_loadPortfolio ??
              ((walletId, range) => _portfolioCore.api.getWalletPortfolio(
                    walletId: walletId,
                    range: range,
                  )))(walletId, selectedRange);
      if (_disposed || token != _loadToken || _state.activeWalletId != walletId) {
        return;
      }

      _set(
        _state.copyWith(
          loading: false,
          error: null,
          data: data,
          walletLabel: data.walletLabel ?? _state.walletLabel,
        ),
      );
    } catch (error) {
      if (_disposed || token != _loadToken || _state.activeWalletId != walletId) {
        return;
      }
      _set(
        _state.copyWith(
          loading: false,
          data: null,
          error: 'Unable to load this wallet portfolio right now.',
        ),
      );
    }
  }

  Future<void> refresh() => load();

  Future<void> setRange(PortfolioRange range) => load(range: range);

  void _onWalletChanged() {
    unawaited(bindActiveWallet());
  }

  void _onNetworkChanged() {
    if (_disposed) return;
    _set(_state.copyWith(isOffline: !_networkMonitor.isOnline));
  }

  void _set(PortfolioState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _walletHomeVM.removeListener(_onWalletChanged);
    _networkMonitor.removeListener(_onNetworkChanged);
    super.dispose();
  }
}
