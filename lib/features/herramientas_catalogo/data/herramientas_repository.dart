import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';

class HerramientasRepository {
  final SupabaseClient _client = SupabaseClientHelper.client;

  Future<List<Map<String, dynamic>>> obtenerHerramientas() async {
    final data = await _client.from('herramientas').select('*, ubicaciones(nombre), unidades_medida(nombre, abreviatura)').order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> obtenerUbicaciones() async {
    final data = await _client.from('ubicaciones').select('*').order('nombre');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> obtenerUnidadesMedida() async {
    final data = await _client.from('unidades_medida').select('*').order('nombre');
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
    required String unidadMedidaId,
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
      'unidad_medida_id': unidadMedidaId,
      'especificaciones': especificaciones,
      'stock': 0, // El trigger calculará esto a partir del movimiento inicial
      'costo_promedio': 0.00,
    }).select().single();

    final uuidHerramienta = insertRes['id'];

    // 2. Si hay stock inicial, insertar el movimiento correspondiente
    if (stockInicial > 0) {
      final user = _client.auth.currentUser;
      String responsableNombre = 'Administrador de Sistema';
      String? responsableId = user?.id;

      if (user != null) {
        try {
          final profile = await _client
              .from('perfiles')
              .select('nombre_completo, matricula')
              .eq('id', user.id)
              .single();
          responsableNombre = profile['nombre_completo'] ?? 'Administrador Autenticado';
          responsableId = profile['matricula'] ?? user.id;
        } catch (_) {}
      }

      await _client.from('movimientos').insert({
        'herramienta_id': uuidHerramienta,
        'tipo': 'ENTRADA',
        'motivo': 'INVENTARIO_INICIAL',
        'cantidad': stockInicial,
        'precio_unitario': costoUnitario,
        'responsable_nombre': responsableNombre,
        'matricula': responsableId,
      });
    }
  }

  Future<Map<String, int>> obtenerEstadisticasMovimientos(String herramientaId) async {
    final data = await _client
        .from('movimientos')
        .select('tipo, motivo, cantidad')
        .eq('herramienta_id', herramientaId);

    int prestadas = 0;
    int perdidas = 0;
    int descompostura = 0;

    for (var m in data) {
      final tipo = m['tipo'] as String;
      final motivo = m['motivo'] as String;
      final cantidad = m['cantidad'] as int;

      if (tipo == 'SALIDA') {
        if (motivo == 'PRESTAMO_ALUMNO_PROFESOR') {
          prestadas += cantidad;
        } else if (motivo == 'BAJA_PERDIDA') {
          perdidas += cantidad;
        } else if (motivo == 'BAJA_DESCOMPOSTURA') {
          descompostura += cantidad;
        }
      } else if (tipo == 'ENTRADA') {
        if (motivo == 'DEVOLUCION_PRESTAMO') {
          prestadas -= cantidad;
        }
      }
    }

    return {
      'prestadas': prestadas < 0 ? 0 : prestadas,
      'perdidas': perdidas,
      'descompostura': descompostura,
    };
  }

  Future<List<Map<String, dynamic>>> obtenerMovimientos() async {
    final data = await _client
        .from('movimientos')
        .select('*, herramientas(nombre)')
        .order('fecha', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> actualizarMovimiento({
    required String id,
    required int cantidad,
    required String motivo,
    required String observacionEdicion,
  }) async {
    await _client.from('movimientos').update({
      'cantidad': cantidad,
      'motivo': motivo,
      'observacion_edicion': observacionEdicion,
      'fecha_edicion': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
