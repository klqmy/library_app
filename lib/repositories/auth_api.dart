import '../core/api_client.dart';
import '../models/app_user.dart';

class AuthApi {
  final ApiClient client;
  AuthApi(this.client);
  Future<AuthResult> login(String username, String password) async =>
      AuthResult.fromJson(
        Map<String, dynamic>.from(
          await client.post(
            '/auth/login',
            data: {'username': username.trim(), 'password': password},
            authenticated: false,
          ),
        ),
      );
  Future<void> register(Map<String, dynamic> data) async {
    await client.post('/auth/register', data: data, authenticated: false);
  }

  Future<AuthResult> refresh(String refreshToken) async => AuthResult.fromJson(
    Map<String, dynamic>.from(
      await client.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        authenticated: false,
      ),
    ),
  );
  Future<AppUser> me() async =>
      AppUser.fromJson(Map<String, dynamic>.from(await client.get('/auth/me')));
  Future<void> logout(String refreshToken) async {
    await client.post(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
      authenticated: false,
    );
  }
}
