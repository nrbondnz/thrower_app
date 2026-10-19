/// A signed-in user, independent of whichever auth provider is chosen.
class AppUser {
  const AppUser({required this.id, this.displayName});

  final String id;
  final String? displayName;
}

/// The app's sign-in, independent of the backend (AWS Amplify since stage 2:
/// `AmplifyAuthService`; Design Decisions → User Accounts Required). UI and
/// game code depend on this interface only; tests use a fake. Signing in is
/// never needed to score.
abstract interface class AuthService {
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<void> signOut();

  /// Deletes the signed-in user's account (the stores require it inside the
  /// app: Apple 5.1.1(v)); they're signed out. Their backup is erased first
  /// (see `deleteAccount` in providers).
  Future<void> deleteUser();
}
