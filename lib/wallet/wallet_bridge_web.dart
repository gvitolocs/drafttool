import 'dart:js_interop';

@JS('window.pokoinWallet.hasProvider')
external bool _hasProvider();

@JS('window.pokoinWallet.openMetaMaskDapp')
external bool _openMetaMaskDapp();

@JS('window.pokoinWallet.requestAccounts')
external JSPromise<JSArray<JSString>> _requestAccounts();

@JS('window.pokoinWallet.signMessage')
external JSPromise<JSString> _signMessage(JSString address, JSString message);

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
  bool get hasProvider {
    try {
      return _hasProvider();
    } catch (_) {
      return false;
    }
  }

  bool openMetaMaskDapp() {
    try {
      return _openMetaMaskDapp();
    } catch (_) {
      return false;
    }
  }

  Future<String?> requestAccount() async {
    final accounts = await _requestAccounts().toDart;
    if (accounts.length == 0) {
      return null;
    }
    return accounts[0].toDart;
  }

  Future<String> signMessage({
    required String address,
    required String message,
  }) async {
    final signature = await _signMessage(address.toJS, message.toJS).toDart;
    return signature.toDart;
  }
}

WalletBridge createWalletBridge() => WalletBridge();
