import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/services/app_cover/app_cover_service.dart';
import 'package:next_fi/features/wallet_creation/presentation/viewmodels/wallet_creation_state.dart';

final walletCreationPackageInfoProvider = Provider<Future<PackageInfo>>((
  Ref ref,
) {
  return PackageInfo.fromPlatform();
});

final walletCreationControllerProvider =
    NotifierProvider.autoDispose<WalletCreationController, WalletCreationState>(
      WalletCreationController.new,
    );

class WalletCreationController extends Notifier<WalletCreationState> {
  @override
  WalletCreationState build() {
    Future<void>.microtask(_load);
    return const WalletCreationState();
  }

  Future<void> _load() async {
    await Future.wait([loadAppInfo(), loadAppCover()]);
  }

  Future<void> loadAppInfo() async {
    final info = await ref.read(walletCreationPackageInfoProvider);
    if (!ref.mounted) return;
    state = state.copyWith(
      appName: info.appName,
      version: 'v${info.version} (${info.buildNumber})',
    );
  }

  Future<void> loadAppCover() async {
    try {
      final cover = await ref.read(appCoverServiceProvider).getCurrent();
      if (!ref.mounted) return;
      state = state.copyWith(appCover: cover);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(appCover: null);
    }
  }
}
