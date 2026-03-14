import 'package:next_fi/core/services/oath2.0/models/user_model.dart';

class TopBarProfileState {
  const TopBarProfileState({
    required this.isLoading,
    required this.isLoggedIn,
    this.user,
  });

  const TopBarProfileState.initial()
    : isLoading = true,
      isLoggedIn = false,
      user = null;

  final bool isLoading;
  final bool isLoggedIn;
  final User? user;

  TopBarProfileState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    Object? user = _sentinel,
  }) {
    return TopBarProfileState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: identical(user, _sentinel) ? this.user : user as User?,
    );
  }
}

const Object _sentinel = Object();
