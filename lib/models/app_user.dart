enum Role {
  reader('Читатель'),
  librarian('Библиотекарь'),
  admin('Администратор');

  final String label;
  const Role(this.label);
  static Role parse(Object? value) =>
      Role.values.firstWhere((r) => r.name == value, orElse: () => Role.reader);
}

class AppUser {
  final int id;
  final String username;
  final String fullName;
  final String email;
  final Role role;
  final int? readerId;
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.readerId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num).toInt(),
    username: json['username'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: Role.parse(json['role']),
    readerId: (json['readerId'] as num?)?.toInt(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'role': role.name,
    'readerId': readerId,
  };
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final AppUser user;
  const AuthResult(this.accessToken, this.refreshToken, this.user);
  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
    json['accessToken'] as String,
    json['refreshToken'] as String,
    AppUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
  );
}
