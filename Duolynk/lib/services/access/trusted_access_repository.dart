import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final trustedAccessRepositoryProvider = Provider<TrustedAccessRepository>(
  (ref) => TrustedAccessRepository(),
);

class TrustedAccessRepository {
  TrustedAccessRepository({FirebaseFunctions? functions})
    : _injectedFunctions = functions;

  // Resolved lazily so demo mode (no Firebase app) can build this repository.
  final FirebaseFunctions? _injectedFunctions;
  late final FirebaseFunctions _functions =
      _injectedFunctions ?? FirebaseFunctions.instance;

  Future<TrustedAccessResult> unlockCandidateProfile({
    required String candidateUid,
  }) async {
    final callable = _functions.httpsCallable('unlockCandidateProfile');
    final result = await callable.call<Map<String, dynamic>>({
      'candidateUid': candidateUid,
    });
    return TrustedAccessResult.fromMap(result.data);
  }

  Future<TrustedAccessResult> activateConversation({
    required String matchId,
  }) async {
    final callable = _functions.httpsCallable('activateConversation');
    final result = await callable.call<Map<String, dynamic>>({
      'matchId': matchId,
    });
    return TrustedAccessResult.fromMap(result.data);
  }

  Future<Map<String, dynamic>> fetchAuthorizedFullProfile({
    required String candidateUid,
  }) async {
    final callable = _functions.httpsCallable('getAuthorizedFullProfile');
    final result = await callable.call<Map<String, dynamic>>({
      'candidateUid': candidateUid,
    });
    return result.data;
  }

  Future<TrustedAccessResult> createCuratedIntroduction({
    required Map<String, dynamic> payload,
  }) async {
    final callable = _functions.httpsCallable('createCuratedIntroduction');
    final result = await callable.call<Map<String, dynamic>>(payload);
    return TrustedAccessResult.fromMap(result.data);
  }

  Future<Map<String, dynamic>> generateWeeklyCuratedCandidates() async {
    final callable = _functions.httpsCallable(
      'generateWeeklyCuratedCandidates',
    );
    final result = await callable.call<Map<String, dynamic>>({});
    return result.data;
  }

  Future<TrustedAccessResult> respondToCuratedMatch({
    required String matchId,
    required String action,
  }) async {
    final callable = _functions.httpsCallable('respondToCuratedMatch');
    final result = await callable.call<Map<String, dynamic>>({
      'matchId': matchId,
      'action': action,
    });
    return TrustedAccessResult.fromMap(result.data);
  }

  Future<TrustedAccessResult> expireCuratedMatch({
    required String matchId,
  }) async {
    final callable = _functions.httpsCallable('expireCuratedMatch');
    final result = await callable.call<Map<String, dynamic>>({
      'matchId': matchId,
    });
    return TrustedAccessResult.fromMap(result.data);
  }

  Future<TrustedAccessResult> unmatchPair({required String matchId}) async {
    final callable = _functions.httpsCallable('unmatchPair');
    final result = await callable.call<Map<String, dynamic>>({
      'matchId': matchId,
    });
    return TrustedAccessResult.fromMap(result.data);
  }

  Future<String> ensureConversationForMatch({required String matchId}) async {
    final callable = _functions.httpsCallable('ensureConversationForMatch');
    final result = await callable.call<Map<String, dynamic>>({
      'matchId': matchId,
    });
    return result.data['conversationId'] as String? ?? '';
  }
}

class TrustedAccessResult {
  const TrustedAccessResult({required this.status, this.pairKey, this.limit});

  final String status;
  final String? pairKey;
  final int? limit;

  bool get succeeded => const {
    'unlocked',
    'alreadyUnlocked',
    'premiumAccess',
    'mutualAccess',
    'activated',
    'alreadyActivated',
    'created',
    'ready',
    'interested',
    'mutual',
    'passed',
    'expired',
    'unmatched',
    'unchanged',
  }.contains(status);

  factory TrustedAccessResult.fromMap(Map<String, dynamic> map) {
    return TrustedAccessResult(
      status: map['status'] as String? ?? 'unknown',
      pairKey: map['pairKey'] as String?,
      limit: map['limit'] is num ? (map['limit'] as num).round() : null,
    );
  }
}
