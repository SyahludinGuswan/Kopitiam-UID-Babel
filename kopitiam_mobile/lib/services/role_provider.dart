import 'api_service.dart';

class RoleProfile {
  final String kodeUiw;
  final String kodeUp3;
  final String kodeUlp;
  final String ulp;
  final String username;
  final String role;
  final bool verified;
  final bool offlineCached;

  const RoleProfile({
    required this.kodeUiw,
    required this.kodeUp3,
    required this.kodeUlp,
    required this.ulp,
    required this.username,
    required this.role,
    required this.verified,
    required this.offlineCached,
  });

  factory RoleProfile.fromSession(Map<String, dynamic> session) {
    final offline = session['offlineLogin'] == true;
    final expiry = DateTime.tryParse('${session['offlineExpiresAt'] ?? ''}')
        ?.toUtc();
    final offlineValid =
        offline && expiry != null && DateTime.now().toUtc().isBefore(expiry);
    final online =
        !offline &&
        session['roleVerifiedOnline'] == true &&
        '${session['username'] ?? ''}'.trim().isNotEmpty &&
        '${session['role'] ?? ''}'.trim().isNotEmpty;
    return RoleProfile(
      kodeUiw: '${session['kodeUiw'] ?? ''}'.trim(),
      kodeUp3: '${session['kodeUp3'] ?? ''}'.trim(),
      kodeUlp: '${session['kodeUlp'] ?? ''}'.trim(),
      ulp: '${session['ulp'] ?? ''}'.trim(),
      username: '${session['username'] ?? ''}'.trim(),
      role: '${session['role'] ?? ''}'.trim(),
      verified: online || offlineValid,
      offlineCached: offlineValid,
    );
  }

  bool get canAccessC4a => verified && RoleProvider.canAccessC4aRole(role);

  Map<String, dynamic> toMap() => {
    'kodeUiw': kodeUiw,
    'kodeUp3': kodeUp3,
    'kodeUlp': kodeUlp,
    'ulp': ulp,
    'username': username,
    'role': role,
    'roleVerifiedOnline': verified && !offlineCached,
    'offlineLogin': offlineCached,
  };
}

class RoleProvider {
  final RoleProfile profile;

  const RoleProvider(this.profile);

  factory RoleProvider.fromSession(Map<String, dynamic> session) =>
      RoleProvider(RoleProfile.fromSession(session));

  bool get canAccessC4a => profile.canAccessC4a;

  static const c4aRoles = <String>{
    'super user',
    'superuser',
    'admin',
    'pegawai pln',
  };

  static String normalizeRole(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool canAccessC4aRole(String? role) =>
      c4aRoles.contains(normalizeRole(role));

  static bool hasC4aAccess(Map<String, dynamic> session) =>
      RoleProvider.fromSession(session).canAccessC4a;

  static Map<String, dynamic> markOnline(Map<String, dynamic> session) {
    final result = Map<String, dynamic>.from(session)
      ..['roleVerifiedOnline'] = true
      ..['offlineLogin'] = false;
    result.remove('offlineExpiresAt');
    return result;
  }

  static Map<String, dynamic> markOffline(
    Map<String, dynamic> session,
    DateTime verifiedAt,
  ) {
    final result = Map<String, dynamic>.from(session)
      ..['roleVerifiedOnline'] = false
      ..['offlineLogin'] = true
      ..['offlineExpiresAt'] = verifiedAt
          .toUtc()
          .add(const Duration(days: 1))
          .toIso8601String();
    return result;
  }

  static Future<Map<String, dynamic>> verifyOnline(
    Map<String, dynamic> session,
  ) async {
    final token = '${session['token'] ?? ''}'.trim();
    if (token.isEmpty) throw StateError('Token sesi tidak tersedia.');
    final response = await ApiService.getRoleProfile(token);
    if (response['success'] != true) {
      throw StateError('${response['message'] ?? 'Profil role tidak valid.'}');
    }
    final result = Map<String, dynamic>.from(session);
    final nested = response['profile'];
    final profile = nested is Map
        ? Map<String, dynamic>.from(nested)
        : <String, dynamic>{};
    for (final key in [
      'kodeUiw',
      'kodeUp3',
      'kodeUlp',
      'ulp',
      'username',
      'role',
      'bidang',
      'tim',
      'subTim',
      'aksesMenu',
    ]) {
      if (profile.containsKey(key)) {
        result[key] = profile[key];
      } else if (response.containsKey(key)) {
        result[key] = response[key];
      }
    }
    return markOnline(result);
  }
}
