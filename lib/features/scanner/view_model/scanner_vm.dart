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
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      ) {
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
  }

  final MobileScannerController _controller;
  MobileScannerController get controller => _controller;

  final void Function(String rawValue)? onResult;

  ScannerState _state = ScannerState.initial();
  ScannerState get state => _state;

  void _setState(ScannerState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _onControllerChanged() {
    final value = _controller.value;

    _setState(state.copyWith(
      torchOn: value.torchState == TorchState.on,
      facing: value.cameraDirection,
      status: value.isRunning
          ? ScannerStatus.ready
          : (state.status == ScannerStatus.initializing
          ? ScannerStatus.initializing
          : state.status),
    ));

    if (value.error != null && state.status != ScannerStatus.error) {
      _setState(state.copyWith(
        status: ScannerStatus.error,
        errorMessage: value.error.toString(),
        isBusy: false,
      ));
    }
  }

  Future<void> init() async {
    try {
      _setState(state.copyWith(
        status: ScannerStatus.initializing,
        errorMessage: null,
      ));

      await _controller.start();

      final value = _controller.value;
      if (value.hasCameraPermission != true) {
        _setState(state.copyWith(
          status: ScannerStatus.noPermission,
          isBusy: false,
        ));
        return;
      }

      _setState(state.copyWith(
        status: ScannerStatus.ready,
        isBusy: false,
      ));
    } catch (e) {
      _setState(state.copyWith(
        status: ScannerStatus.error,
        errorMessage: e.toString(),
        isBusy: false,
      ));
    }
  }

  void onDetect(BarcodeCapture capture) {
    if (state.isBusy || state.status != ScannerStatus.ready) return;

    final value = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;

    if (value == null || value.trim().isEmpty) return;

    _setState(state.copyWith(
      isBusy: true,
      lastRawValue: value.trim(),
    ));

    pause();
    onResult?.call(state.lastRawValue!);
  }

  Future<void> resume() async {
    try {
      await _controller.start();
      _setState(state.copyWith(
        status: ScannerStatus.ready,
        isBusy: false,
      ));
    } catch (e) {
      _setState(state.copyWith(
        status: ScannerStatus.error,
        errorMessage: e.toString(),
        isBusy: false,
      ));
    }
  }

  Future<void> pause() async {
    try {
      await _controller.stop();
      _setState(state.copyWith(status: ScannerStatus.paused));
    } catch (_) {
      // Ignore pause errors
    }
  }

  Future<void> retryPermission() async {
    _setState(state.copyWith(
      status: ScannerStatus.initializing,
      errorMessage: null,
    ));
    await init();
  }

  Future<void> toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } catch (e) {
      debugPrint('Torch toggle failed: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (e) {
      debugPrint('Camera switch failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (!_controller.value.isInitialized) return;

    switch (appState) {
      case AppLifecycleState.resumed:
        if (!_controller.value.isRunning &&
            state.status != ScannerStatus.paused) {
          resume();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        if (_controller.value.isRunning) {
          pause();
        }
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
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