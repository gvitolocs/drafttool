import 'dart:async';

class WalletSignInCoordinator {
  static bool _signing = false;

  static Future<T> run<T>(Future<T> Function() action) async {
    if (_signing) {
      throw StateError('A wallet sign-in is already in progress.');
    }
    _signing = true;
    try {
      return await action();
    } finally {
      _signing = false;
    }
  }
}

class WalletBridge {
  bool get hasProvider => false;

  bool openMetaMaskDapp() => false;

  Future<String?> requestAccount() async => null;

  Future<String> signMessage({
    required String address,
    required String message,
  }) {
    throw UnsupportedError('Browser wallet is not available on this platform.');
  }
}

WalletBridge createWalletBridge() => WalletBridge();
