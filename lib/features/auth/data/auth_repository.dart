import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseClientHelper.client;

  Future<AuthResponse> login(String username, String password) async {
    // Si no es un correo electrónico, agregamos el dominio automático
    final email = username.contains('@') ? username : '$username@inventra-uni.com';
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
}
