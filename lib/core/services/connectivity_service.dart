import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);
  StreamSubscription? _subscription;

  void initialize() {
    _subscription?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _checkConnection(results);
    });
    // Check initial connectivity
    _connectivity.checkConnectivity().then(_checkConnection);
  }

  Future<void> _checkConnection(List<ConnectivityResult> results) async {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      isOffline.value = true;
      return;
    }

    if (kIsWeb) {
      // En la web, las solicitudes HTTP directas suelen fallar por restricciones CORS.
      // Si el navegador reporta una conexión activa, asumimos que está online.
      isOffline.value = false;
      return;
    }

    // Even if connected to Wi-Fi/Mobile data, check if there is real internet access
    final hasInternet = await verifyRealInternet();
    isOffline.value = !hasInternet;
  }

  Future<bool> verifyRealInternet() async {
    try {
      // Perform a quick HEAD request to the project's Supabase API endpoint
      await http.head(
        Uri.parse('https://nnwtkhncjlalwzywgida.supabase.co'),
      ).timeout(const Duration(seconds: 4));
      
      // If we get any status code/response, we successfully reached the Supabase server,
      // which means we have active internet access.
      return true;
    } catch (_) {
      try {
        // Fallback check to a public resolver
        final responseFallback = await http.head(
          Uri.parse('https://www.google.com'),
        ).timeout(const Duration(seconds: 4));
        return responseFallback.statusCode >= 200 && responseFallback.statusCode < 400;
      } catch (_) {
        return false;
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
