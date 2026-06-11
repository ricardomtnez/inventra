import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class HerramientasRepository {
  final SupabaseClient _client = SupabaseClientHelper.client;

  Future<List<Map<String, dynamic>>> obtenerHerramientas() async {
    final data = await _client.from('herramientas').select('*, ubicaciones(nombre)').order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> obtenerUbicaciones() async {
    final data = await _client.from('ubicaciones').select('*').order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String?> subirFoto(File file, String fileName) async {
    try {
      final path = 'fotos/$fileName';
      await _client.storage.from('fotos_herramientas').upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      return _client.storage.from('fotos_herramientas').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  Future<void> registrarHerramienta({
    required String nombre,
    required String descripcion,
    required String? fotoUrl,
    required String ubicacionId,
    required int stockInicial,
    required double costoUnitario,
    required Map<String, dynamic> especificaciones,
  }) async {
    // 1. Insertar herramienta
    final insertRes = await _client.from('herramientas').insert({
      'nombre': nombre,
      'descripcion': descripcion,
      'foto_url': fotoUrl,
      'ubicacion_id': ubicacionId,
      'especificaciones': especificaciones,
      'stock': 0, // El trigger calculará esto a partir del movimiento inicial
      'costo_promedio': 0.00,
    }).select().single();

    final uuidHerramienta = insertRes['id'];

    // 2. Si hay stock inicial, insertar el movimiento correspondiente
    if (stockInicial > 0) {
      await _client.from('movimientos').insert({
        'herramienta_id': uuidHerramienta,
        'tipo': 'ENTRADA',
        'motivo': 'COMPRA_NUEVA',
        'cantidad': stockInicial,
        'precio_unitario': costoUnitario,
        'responsable_nombre': 'Carga Inicial de Sistema',
      });
    }
  }
}
