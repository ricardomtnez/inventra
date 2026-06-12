import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        final Map<String, dynamic> mov = jsonDecode(itemStr);
        await client.from('movimientos').insert(mov);
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
