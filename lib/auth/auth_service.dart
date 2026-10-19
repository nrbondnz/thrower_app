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
}
