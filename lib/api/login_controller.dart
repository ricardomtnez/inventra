import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginController {
  static const String _userKey = "saved_user";
  static const String _passKey = "saved_pass";

  static Future<Map<String, dynamic>> signIn(
    String nombreUsuario,
    String hashContrasena,
  ) async {
    final url = Uri.parse(
      "https://keysolutionstechnology.com.mx/inventra_api/routes/api.php?r=login",
    );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "nombre_usuario": nombreUsuario,
          "hash_contrasena": hashContrasena,
        }),
      );

      print(response.body);

      return jsonDecode(response.body);
    } catch (e) {
      return {"error": "Error de conexión con el servidor"};
    }
  }

  /// Guardar credenciales
  static Future<void> saveCredentials(String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user);
    await prefs.setString(_passKey, pass);
  }

  /// Cargar credenciales guardadas
  static Future<Map<String, String?>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "user": prefs.getString(_userKey),
      "pass": prefs.getString(_passKey),
    };
  }

  /// Eliminar credenciales guardadas
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_passKey);
  }
}
