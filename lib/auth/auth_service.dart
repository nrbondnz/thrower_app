/// A signed-in user, independent of whichever auth provider is chosen.
class AppUser {
  const AppUser({required this.id, this.displayName});

  final String id;
  final String? displayName;
}

/// Accounts are required, but the backend and auth provider are not chosen yet
/// (see Design Decisions → User Accounts Required). UI and game code depend on
/// this interface only, so a provider can be plugged in later.
abstract interface class AuthService {
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<void> signOut();
}
