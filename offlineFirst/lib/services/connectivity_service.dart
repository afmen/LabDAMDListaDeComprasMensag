import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Serviço de monitoramento de conectividade de rede
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._init();
  
  final Connectivity _connectivity = Connectivity();
  final _connectivityController = StreamController<bool>.broadcast();
  
  bool _isOnline = false;
  StreamSubscription? _subscription;

  ConnectivityService._init();

  /// Stream de status de conectividade
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Status atual de conectividade
  bool get isOnline => _isOnline;

  /// Inicializar monitoramento
  Future<void> initialize() async {
    // Modificação 1: checkConnectivity() agora retorna List<ConnectivityResult>
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Modificação 2: onConnectivityChanged.listen espera um parâmetro List<ConnectivityResult>
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
    
    print('✅ Serviço de conectividade inicializado');
  }

  // Modificação 3: Alterar o tipo do parâmetro para List<ConnectivityResult>
  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    
    // Verificar se a lista contém *qualquer* tipo de conexão,
    // ou seja, se a lista não é [ConnectivityResult.none]
    // A lista não conter 'none' é suficiente para ser considerado online.
    _isOnline = results.contains(ConnectivityResult.mobile) || 
                results.contains(ConnectivityResult.wifi) || 
                results.contains(ConnectivityResult.ethernet) ||
                results.contains(ConnectivityResult.vpn);
                
    // Nota: O método .any((result) => result != ConnectivityResult.none)
    // também pode ser usado, mas a listagem explícita é mais clara.
    
    if (wasOnline != _isOnline) {
      print(_isOnline ? '🟢 Conectado à internet' : '🔴 Sem conexão à internet');
      _connectivityController.add(_isOnline);
    }
  }

  /// Verificar conectividade manualmente
  Future<bool> checkConnectivity() async {
    // checkConnectivity() também foi atualizado para retornar List<ConnectivityResult>
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    return _isOnline;
  }

  /// Dispose
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}