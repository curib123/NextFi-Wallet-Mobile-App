import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:next_fi/app/config/app_providers.dart';
import 'package:next_fi/core/services/app_cover/app_cover_service.dart';
import 'package:next_fi/features/onboarding/presentation/viewmodels/onboarding_state.dart';

final onboardingControllerProvider =
    NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    _loadAppCover();
    return const OnboardingState();
  }

  Future<void> _loadAppCover() async {
    try {
      final AppCoverConfig? cover = await ref
          .read(appCoverServiceProvider)
          .getCurrent();
      if (!ref.mounted) return;
      state = state.copyWith(appCover: cover);
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(appCover: null);
    }
  }

  void setCurrentIndex(int index) {
    if (index == state.currentIndex) return;
    state = state.copyWith(currentIndex: index);
  }

  Future<void> runFinish(Future<void> Function() onFinish) async {
    if (state.finishing) return;
    state = state.copyWith(finishing: true);
    try {
      await onFinish();
    } finally {
      if (ref.mounted) {
        state = state.copyWith(finishing: false);
      }
    }
  }
}
