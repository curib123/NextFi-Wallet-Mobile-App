import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_fi/features/wallet_home/data/services/top_bar_profile_service.dart';
import 'package:next_fi/features/wallet_home/presentation/viewmodels/top_bar_profile_state.dart';

final topBarProfileServiceProvider = Provider<TopBarProfileService>(
  (ref) => TopBarProfileService(),
);

final topBarProfileControllerProvider =
    NotifierProvider.autoDispose<
      TopBarProfileController,
      TopBarProfileState
    >(TopBarProfileController.new);

class TopBarProfileController extends Notifier<TopBarProfileState> {
  @override
  TopBarProfileState build() {
    Future.microtask(refresh);
    return const TopBarProfileState.initial();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    final user = await ref.read(topBarProfileServiceProvider).loadCurrentUser();
    state = TopBarProfileState(
      isLoading: false,
      isLoggedIn: user != null,
      user: user,
    );
  }
}
