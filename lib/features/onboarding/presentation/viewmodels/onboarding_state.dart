import 'package:next_fi/core/services/app_cover/app_cover_service.dart';

class OnboardingState {
  const OnboardingState({
    this.currentIndex = 0,
    this.finishing = false,
    this.appCover,
  });

  final int currentIndex;
  final bool finishing;
  final AppCoverConfig? appCover;

  OnboardingState copyWith({
    int? currentIndex,
    bool? finishing,
    Object? appCover = _sentinel,
  }) {
    return OnboardingState(
      currentIndex: currentIndex ?? this.currentIndex,
      finishing: finishing ?? this.finishing,
      appCover: identical(appCover, _sentinel)
          ? this.appCover
          : appCover as AppCoverConfig?,
    );
  }
}

const Object _sentinel = Object();
