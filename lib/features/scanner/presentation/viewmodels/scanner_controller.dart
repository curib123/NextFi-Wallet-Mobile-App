import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:next_fi/features/scanner/data/services/scanner_gallery_service.dart';
import 'package:next_fi/features/scanner/presentation/viewmodels/scanner_state.dart';

final scannerGalleryServiceProvider = Provider<ScannerGalleryService>(
  (ref) => ScannerGalleryService(),
);

final scannerControllerProvider =
    NotifierProvider.autoDispose<ScannerController, ScannerState>(
      ScannerController.new,
    );

class ScannerController extends Notifier<ScannerState>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  MobileScannerController get controller => _controller;

  @override
  ScannerState build() {
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _controller.removeListener(_onControllerChanged);
      _controller.dispose();
    });
    Future.microtask(init);
    return ScannerState.initial();
  }

  Future<void> init() async {
    try {
      state = state.copyWith(
        status: ScannerStatus.initializing,
        errorMessage: null,
      );

      await _controller.start();

      final value = _controller.value;
      if (value.hasCameraPermission != true) {
        state = state.copyWith(
          status: ScannerStatus.noPermission,
          isBusy: false,
        );
        return;
      }

      state = state.copyWith(
        status: ScannerStatus.ready,
        isBusy: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: ScannerStatus.error,
        errorMessage: e.toString(),
        isBusy: false,
      );
    }
  }

  void onDetect(BarcodeCapture capture) {
    if (state.isBusy || state.status != ScannerStatus.ready) return;

    final value = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;

    if (value == null || value.trim().isEmpty) return;
    consumeResult(value.trim());
  }

  void consumeResult(String rawValue) {
    final trimmed = rawValue.trim();
    if (state.isBusy || trimmed.isEmpty) return;
    state = state.copyWith(isBusy: true, lastRawValue: trimmed);
    pause();
  }

  Future<String?> pickQrFromGallery() async {
    final result = await ref
        .read(scannerGalleryServiceProvider)
        .pickQrFromGallery(_controller);
    if (result.rawValue != null && result.rawValue!.isNotEmpty) {
      consumeResult(result.rawValue!);
    }
    return result.errorMessage;
  }

  Future<void> resume() async {
    try {
      await _controller.start();
      state = state.copyWith(
        status: ScannerStatus.ready,
        isBusy: false,
        lastRawValue: null,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: ScannerStatus.error,
        errorMessage: e.toString(),
        isBusy: false,
      );
    }
  }

  Future<void> pause() async {
    try {
      await _controller.stop();
      state = state.copyWith(status: ScannerStatus.paused);
    } catch (_) {}
  }

  Future<void> retryPermission() async {
    state = state.copyWith(
      status: ScannerStatus.initializing,
      errorMessage: null,
    );
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

  void _onControllerChanged() {
    final value = _controller.value;

    state = state.copyWith(
      torchOn: value.torchState == TorchState.on,
      facing: value.cameraDirection,
      status: value.isRunning
          ? ScannerStatus.ready
          : (state.status == ScannerStatus.initializing
                ? ScannerStatus.initializing
                : state.status),
    );

    if (value.error != null && state.status != ScannerStatus.error) {
      state = state.copyWith(
        status: ScannerStatus.error,
        errorMessage: value.error.toString(),
        isBusy: false,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_controller.value.isRunning &&
            this.state.status != ScannerStatus.paused) {
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
}
