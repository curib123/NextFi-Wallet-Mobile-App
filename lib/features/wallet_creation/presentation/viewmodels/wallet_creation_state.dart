import 'package:next_fi/core/services/app_cover/app_cover_service.dart';

class WalletCreationState {
  const WalletCreationState({
    this.appName = '',
    this.version = '',
    this.appCover,
  });

  static const Object _unset = Object();

  final String appName;
  final String version;
  final AppCoverConfig? appCover;

  WalletCreationState copyWith({
    String? appName,
    String? version,
    Object? appCover = _unset,
  }) {
    return WalletCreationState(
      appName: appName ?? this.appName,
      version: version ?? this.version,
      appCover: identical(appCover, _unset)
          ? this.appCover
          : appCover as AppCoverConfig?,
    );
  }
}
