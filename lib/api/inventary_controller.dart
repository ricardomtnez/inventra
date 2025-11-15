import 'dart:convert';
import 'package:http/http.dart' as http;

class InventaryController {
  final String baseUrl =
      "https://www.keysolutionstechnology.com.mx/inventra_api/routes/api.php?r="; // tu ruta PHP

  Future<List<String>> obtenerCategorias() async {
    try {
      final url = Uri.parse('${baseUrl}categories/allCategories');
      //print("📡 Solicitando: $url");

      final response = await http.get(url);

      //print("📨 Status: ${response.statusCode}");
      //print("📦 Body: ${response.body}");

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['success'] == true) {
          List<String> categorias = ["Todas las categorías"];

          for (var cat in jsonData['data']) {
            categorias.add(cat['nombre_categoria']);
          }

          return categorias;
        } else {
          //print("⚠ API Error: ${jsonData['message']}");
        }
      } else {
        //print(" Error HTTP: ${response.statusCode}");
      }
    } catch (e) {
      //print(" Exception: $e");
    }

    // fallback si ocurre cualquier error
    return ["Todas las categorías"];
  }

  //Metodo consultar todo el inventario de herramienta (todas las categorias y ubicaciones)
  Future<List<Map<String, dynamic>>> obtenerInventarioHerramienta() async {
    final url = Uri.parse('${baseUrl}herramientas/allTools');
    final response = await http.get(url);

    print("Respuesta API: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map && decoded.containsKey('data')) {
        final List<dynamic> data = decoded['data'];

        return data
            .map(
              (e) => {
                'id': e['codigo_herramienta'],
                'name': e['nombre_herramienta'],
                'description': e['descripcion'],
                'category': e['nombre_categoria'],
                'location': e['nombre_ubicacion'],
                'price': _toDouble(e['costo_promedio']),
                'available': e['stock_total'],
                'status': (int.tryParse(e['stock_total'].toString()) ?? 0) > 0
                    ? 'available'
                    : 'damaged',
              },
            )
            .toList();
      } else {
        throw Exception("Formato inesperado en JSON: falta 'data'");
      }
    } else {
      throw Exception("Error al cargar inventario (${response.statusCode})");
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.00;

    // Convertimos a String para limpiar
    String clean = value
        .toString()
        .replaceAll(",", "") // quitar comas de miles
        .trim();

    // Convertimos a double
    return double.tryParse(clean) ?? 0.00;
  }
}
