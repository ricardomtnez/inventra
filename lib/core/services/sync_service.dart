import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import 'connectivity_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  SyncService._internal();

  static const String _queueKey = 'offline_movements_queue';
  final ValueNotifier<int> pendingCount = ValueNotifier<int>(0);
  bool _isSyncing = false;

  Future<void> initialize() async {
    await _updatePendingCount();
    
    // Listen to connection changes to auto-sync
    ConnectivityService().isOffline.addListener(() {
      if (!ConnectivityService().isOffline.value) {
        sincronizarPendientes();
      }
    });
  }

  Future<void> _updatePendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    pendingCount.value = queue.length;
  }

  Future<void> encolarMovimiento(Map<String, dynamic> movimiento) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    
    queue.add(jsonEncode(movimiento));
    await prefs.setStringList(_queueKey, queue);
    await _updatePendingCount();
  }

  Future<void> encolarOperacion(String table, Map<String, dynamic> data, {String op = 'insert', String? id}) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    
    final item = {
      'op': op,
      'table': table,
      'data': data,
      if (id != null) 'id': id,
    };
    
    queue.add(jsonEncode(item));
    await prefs.setStringList(_queueKey, queue);
    await _updatePendingCount();
  }

  Future<void> sincronizarPendientes() async {
    if (_isSyncing) return;
    
    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_queueKey) ?? [];
    if (queue.isEmpty) return;

    _isSyncing = true;
    final List<String> remainingItems = List.from(queue);

    try {
      final client = SupabaseClientHelper.client;
      for (final itemStr in queue) {
        final Map<String, dynamic> item = jsonDecode(itemStr);
        if (item.containsKey('op')) {
          final String op = item['op'];
          final String table = item['table'];
          final Map<String, dynamic> data = item['data'];
          if (op == 'insert') {
            final Map<String, dynamic> insertData = Map.from(data);
            final String? offlineIneBase64 = insertData.remove('offline_ine_base64') as String?;
            final String? loanId = insertData['id'];

            await client.from(table).insert(insertData);

            // Si hay una foto de INE en base64 en la operación offline, subirla al storage ahora
            if (offlineIneBase64 != null && loanId != null) {
              try {
                final bytes = base64Decode(offlineIneBase64);
                await client.storage.from('fotos_herramientas').uploadBinary(
                  'identificaciones/ine_$loanId.jpg',
                  bytes,
                  fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
                );
              } catch (e) {
                debugPrint('Error uploading offline INE: $e');
              }
            }
          } else if (op == 'update') {
            final String id = item['id'];
            if (data.containsKey('cantidad_devuelta_increment')) {
              final int increment = data['cantidad_devuelta_increment'];
              // Consultar préstamo actual
              final loan = await client.from(table).select('cantidad, cantidad_devuelta, grupo_id').eq('id', id).single();
              final int cantTotal = loan['cantidad'] as int;
              final int cantDevueltaAnterior = loan['cantidad_devuelta'] as int;
              final String? loanGrupoId = loan['grupo_id'] as String?;
              final int nuevaCantDevuelta = cantDevueltaAnterior + increment;
              final int capDevuelta = nuevaCantDevuelta > cantTotal ? cantTotal : nuevaCantDevuelta;
              
              String nuevoEstado = 'PARCIAL';
              if (capDevuelta >= cantTotal) {
                nuevoEstado = 'DEVUELTO';
              }
              
              await client.from(table).update({
                'cantidad_devuelta': capDevuelta,
                'estado': nuevoEstado,
                'fecha_devolucion': nuevoEstado == 'DEVUELTO' ? DateTime.now().toIso8601String() : null,
              }).eq('id', id);

              // Eliminar la INE del storage SOLO SI todas las herramientas del grupo se han devuelto
              if (nuevoEstado == 'DEVUELTO') {
                bool canDeleteIne = true;
                if (loanGrupoId != null && loanGrupoId.isNotEmpty) {
                  final remainingGroupLoans = await client
                      .from('prestamos')
                      .select('id')
                      .eq('grupo_id', loanGrupoId)
                      .neq('estado', 'DEVUELTO');
                  if (remainingGroupLoans.isNotEmpty) {
                    canDeleteIne = false;
                  }
                }
                if (canDeleteIne) {
                  try {
                    await client.storage
                        .from('fotos_herramientas')
                        .remove(['identificaciones/ine_$id.jpg']);
                  } catch (e) {
                    debugPrint('Error deleting offline INE: $e');
                  }
                }
              }
            } else {
              await client.from(table).update(data).eq('id', id);
            }
          } else if (op == 'delete_storage') {
            final String bucket = data['bucket'] ?? 'fotos_herramientas';
            final List<dynamic> paths = data['paths'] ?? [];
            try {
              await client.storage.from(bucket).remove(List<String>.from(paths));
            } catch (e) {
              debugPrint('Error executing offline storage deletion: $e');
            }
          }
        } else {
          // Formato heredado
          await client.from('movimientos').insert(item);
        }
        remainingItems.remove(itemStr);
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      await prefs.setStringList(_queueKey, remainingItems);
      await _updatePendingCount();
      _isSyncing = false;
      notifyListeners();
    }
  }
}
