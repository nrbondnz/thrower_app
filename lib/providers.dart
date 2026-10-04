import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_service.dart';
import 'scoring/target_model.dart';

/// Wiring for the app's layers. Tests override any of these with fakes.

final targetModelProvider = Provider<TargetModel>((ref) => TargetModel.ikthof());

/// No auth provider is chosen yet, so this must be overridden before use.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('Auth provider not chosen yet (backend deferred)'),
);
