// lib/features/scanner/view_model/scanner_vm.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:next_fi/features/scanner/model/scanner_state.dart';

class ScannerVM extends ChangeNotifier with WidgetsBindingObserver {
  ScannerVM({
    MobileScannerController? controller,
    this.onResult,
  }) : _controller = controller ??
      MobileScannerController(
        autoStart: false, // we'll manage lifecycle ourselves
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
        formats: const [
          BarcodeFormat.qrCode,
          BarcodeFormat.aztec,
          BarcodeFormat.pdf417,
          BarcodeFormat.codabar,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
          BarcodeFormat.dataMatrix,
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.itf,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
      ) {
    WidgetsBinding.instance.addObserver(this);
    // Listen to controller.value updates (torch state, facing, permission, errors, etc.)
    _controller.addListener(_onControllerChanged);
  }

  final MobileScannerController _controller;
  MobileScannerController get controller => _controller;

  final void Function(String rawValue)? onResult;

  ScannerState _state = ScannerState.initial();
  ScannerState get state => _state;
  void _set(ScannerState s) {
    _state = s;
    notifyListeners();
  }

  void _onControllerChanged() {
    final v = _controller.value;
    // Mirror interesting controller state into our VM state
    _set(state.copyWith(
      torchOn: v.torchState == TorchState.on,
      facing: v.cameraDirection,
      // keep current status unless we can refine it here
      status: v.isRunning
          ? ScannerStatus.ready
          : (state.status == ScannerStatus.initializing ? ScannerStatus.initializing : state.status),
      // don't overwrite isBusy/lastRawValue here
    ));
    // Surface controller errors (if any)
    if (v.error != null && state.status != ScannerStatus.error) {
      _set(state.copyWith(status: ScannerStatus.error, errorMessage: v.error.toString(), isBusy: false));
    }
  }

  Future<void> init() async {
    try {
      _set(state.copyWith(status: ScannerStatus.initializing, errorMessage: null));
      await _controller.start(); // returns Future<void>
      final v = _controller.value;
      if (v.hasCameraPermission != true) {
        _set(state.copyWith(status: ScannerStatus.noPermission, isBusy: false));
        return;
      }
      _set(state.copyWith(status: ScannerStatus.ready, isBusy: false));
    } catch (e) {
      _set(state.copyWith(status: ScannerStatus.error, errorMessage: '$e', isBusy: false));
    }
  }

  void onDetect(BarcodeCapture cap) {
    if (state.isBusy || state.status != ScannerStatus.ready) return;
    final value = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (value == null || value.trim().isEmpty) return;

    _set(state.copyWith(isBusy: true, lastRawValue: value.trim()));
    pause();
    onResult?.call(state.lastRawValue!);
  }

  Future<void> resume() async {
    try {
      await _controller.start();
      _set(state.copyWith(status: ScannerStatus.ready, isBusy: false));
    } catch (e) {
      _set(state.copyWith(status: ScannerStatus.error, errorMessage: '$e', isBusy: false));
    }
  }

  Future<void> pause() async {
    try {
      await _controller.stop();
      _set(state.copyWith(status: ScannerStatus.paused));
    } catch (_) {
      // ignore
    }
  }

  Future<void> retryPermission() async {
    _set(state.copyWith(status: ScannerStatus.initializing, errorMessage: null));
    await init();
  }

  Future<void> toggleTorch() async {
    await _controller.toggleTorch();
    // state mirrors via _onControllerChanged
  }

  Future<void> switchCamera() async {
    await _controller.switchCamera();
    // state mirrors via _onControllerChanged
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      if (!_controller.value.isRunning) {
        resume();
      }
    } else if (appState == AppLifecycleState.paused) {
      if (_controller.value.isRunning) {
        pause();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }
}
