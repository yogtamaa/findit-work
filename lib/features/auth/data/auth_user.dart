/// Data user dari `POST /api/login` (envelope: data.token + data.user).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.role,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
      };
}

/// Hasil login: JWT token + profil user.
class LoginResult {
  const LoginResult({required this.token, required this.user});

  final String token;
  final AuthUser user;

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String? ?? '';
    final userJson = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LoginResult(token: token, user: AuthUser.fromJson(userJson));
  }
}