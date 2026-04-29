import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../utils/utils.dart';
import 'package:flutter/services.dart';

class ConnectivityProvider extends ChangeNotifier {
  final Connectivity connectivity = Connectivity();

  List<ConnectivityResult> connectivityResults = [ConnectivityResult.none];
  bool isOnline = false;

  Timer? _offlineTimer;

  /// Initialize connectivity & start listening
  Future<void> initConnectivity() async {
    try {
      final results = await connectivity.checkConnectivity();
      await _handleStatus(results);
    } on PlatformException catch (e) {
      printLog("Couldn't check connectivity status: $e");
    }

    connectivity.onConnectivityChanged.listen(_handleStatus);
  }

  /// Handle changes from connectivity_plus
  Future<void> _handleStatus(List<ConnectivityResult> results) async {
    connectivityResults = results;

    final hasConnection = results.any((r) =>
        (r == ConnectivityResult.mobile) ||
        (r == ConnectivityResult.wifi) ||
        (r == ConnectivityResult.ethernet));

    // --- ONLINE ---
    if (hasConnection) {
      _offlineTimer?.cancel();
      printLog('_handleStatus isOnline ==> $isOnline');
      if (!isOnline) {
        isOnline = true;
        printLog(
            '_handleStatus Back online: ${results.map((e) => e.name).join(", ")}');
        notifyListeners();
      }
      return;
    }

    // --- OFFLINE (schedule delay) ---
    _offlineTimer?.cancel();
    _offlineTimer = Timer(const Duration(seconds: 3), () {
      if (isOnline) {
        isOnline = false;
        printLog('Went offline');
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();
    super.dispose();
  }
}
