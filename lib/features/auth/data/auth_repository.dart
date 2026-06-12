import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class AuthRepository {
  // Patrón Singleton para compartir roles y estado de sesión globalmente
  static final AuthRepository _instance = AuthRepository._internal();
  factory AuthRepository() => _instance;
  AuthRepository._internal();

  final SupabaseClient _client = SupabaseClientHelper.client;
  List<String> _assignedRoles = [];

  List<String> get assignedRoles => _assignedRoles;

  Future<AuthResponse> login(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Cargar roles asignados después del login exitoso
    await loadRoles();

    return response;
  }

  Future<void> logout() async {
    await _client.auth.signOut();
    _assignedRoles.clear();
  }

  Future<void> loadRoles() async {
    final user = currentUser;
    if (user == null) {
      _assignedRoles = [];
      return;
    }

    try {
      final List<dynamic> res = await _client.rpc(
        'get_user_roles',
        params: {'p_usuario_id': user.id},
      );
      _assignedRoles = res.map((e) => e.toString()).toList();
    } catch (e) {
      _assignedRoles = [];
    }
  }

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  bool get isAdmin => _assignedRoles.contains('ADMIN');
  bool get isOperador => _assignedRoles.contains('OPERADOR');
  bool get isVisitante => _assignedRoles.contains('VISITANTE');
  bool hasRole(String role) => _assignedRoles.contains(role);
}
