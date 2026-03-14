import 'package:mobile_scanner/mobile_scanner.dart';

enum ScannerStatus { initializing, ready, noPermission, paused, error }

class ScannerState {
  final ScannerStatus status;
  final bool torchOn;
  final CameraFacing facing;
  final bool isBusy;
  final String? lastRawValue;
  final String? errorMessage;

  const ScannerState({
    required this.status,
    required this.torchOn,
    required this.facing,
    required this.isBusy,
    this.lastRawValue,
    this.errorMessage,
  });

  factory ScannerState.initial() => const ScannerState(
    status: ScannerStatus.initializing,
    torchOn: false,
    facing: CameraFacing.back,
    isBusy: false,
    lastRawValue: null,
    errorMessage: null,
  );

  ScannerState copyWith({
    ScannerStatus? status,
    bool? torchOn,
    CameraFacing? facing,
    bool? isBusy,
    Object? lastRawValue = _sentinel,
    Object? errorMessage = _sentinel,
  }) {
    return ScannerState(
      status: status ?? this.status,
      torchOn: torchOn ?? this.torchOn,
      facing: facing ?? this.facing,
      isBusy: isBusy ?? this.isBusy,
      lastRawValue: identical(lastRawValue, _sentinel)
          ? this.lastRawValue
          : lastRawValue as String?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _sentinel = Object();
