/// Abstract contract for checking network availability across devices.
abstract class NetworkInfo {
  Future<bool> get isConnected;
}

/// Simple implementation for checking connection state
class NetworkInfoImpl implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    // In a real environment, can wrap Connectivity package or HTTP socket ping
    return true;
  }
}
