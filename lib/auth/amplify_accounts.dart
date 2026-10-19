import 'dart:async';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'auth_service.dart';

/// Where a build finds the deployed backend's settings (Amplify's
/// `amplify_outputs.json`, generated per branch and never committed: see
/// Common Tasks → Connect the App to the Amplify Backend).
const amplifyOutputsAsset = 'assets/config/amplify_outputs.json';

/// The deployed backend's settings from [bundle]; null if this build has
/// none (no backend connected yet), or the file is empty.
Future<String?> loadAmplifyOutputs(AssetBundle bundle) async {
  try {
    final outputs = await bundle.loadString(amplifyOutputsAsset);
    return outputs.trim().isEmpty ? null : outputs;
  } catch (_) {
    return null;
  }
}

/// Connects the app to its AWS Amplify backend (stage 2 of the Accounts
/// Roadmap; Nigel: always Amplify, as WhereWillWeVisit) with [outputs], and
/// returns the app's [AuthService]. Null without outputs, or if Amplify
/// can't be configured: the app then runs signed out, as it always has
/// (signing in is never needed to score).
Future<AuthService?> connectAccounts(String? outputs) async {
  if (outputs == null) return null;
  try {
    await Amplify.addPlugin(AmplifyAuthCognito());
    await Amplify.configure(outputs);
    return AmplifyAuthService()..start();
  } on Exception catch (e) {
    debugPrint('Accounts unavailable: $e');
    return null;
  }
}

/// [AuthService] on Amplify's Cognito sign-in (as WhereWillWeVisit's
/// `AuthService`): follows the Hub's sign-in events. The [AppUser.id] is the
/// Cognito `sub` (Amplify's `userId`), never derived from the email.
class AmplifyAuthService implements AuthService {
  final _changes = StreamController<AppUser?>.broadcast();
  StreamSubscription<AuthHubEvent>? _hub;
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() => _changes.stream;

  /// Looks up whoever is signed in already (a session kept from last time),
  /// then follows sign-ins and sign-outs.
  void start() {
    _hub = Amplify.Hub.listen(HubChannel.Auth, (AuthHubEvent event) {
      switch (event.type) {
        case AuthHubEventType.signedIn:
          unawaited(_refresh());
        case AuthHubEventType.signedOut || AuthHubEventType.sessionExpired || AuthHubEventType.userDeleted:
          _set(null);
      }
    });
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final email = (await Amplify.Auth.fetchUserAttributes())
          .where((a) => a.userAttributeKey == AuthUserAttributeKey.email)
          .firstOrNull
          ?.value;
      _set(AppUser(id: user.userId, displayName: email ?? user.username));
    } on AuthException {
      _set(null);
    }
  }

  void _set(AppUser? user) {
    _user = user;
    if (!_changes.isClosed) _changes.add(user);
  }

  @override
  Future<void> signOut() => Amplify.Auth.signOut();

  void dispose() {
    _hub?.cancel();
    _changes.close();
  }
}
