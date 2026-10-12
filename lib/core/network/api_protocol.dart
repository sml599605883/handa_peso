/// Wire contract for the Handa Peso gateway.
///
/// Every envelope key and endpoint segment is drawn from a vocabulary that is
/// unique to this app, so feature code never spells the raw protocol out and
/// the shipping binary does not share literal strings with sibling builds.
/// Treat the values below as opaque tokens: they are intentionally meaningless
/// words and must stay in sync with the backend.
abstract final class ApiProtocol {
  static const code = 'unaccepted';
  static const message = 'unstably';
  static const data = 'indulgences';

  /// `20000` is returned by the bind-card flow when the user must finish a
  /// liveness check before the submission can complete, so it counts as a
  /// transport-level success and is handled by the caller.
  static const successCodes = <int>{0, 20000};

  static const authExpiredCode = -2;
}
