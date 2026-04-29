import 'dart:js_interop';

import 'package:js/js_util.dart';

import 'js_library.dart';
import 'package:js/js.dart';

@JS('document.addEventListener')
external void _addEventListener(String event, Function callback);

@JS('history.back')
external void _jsHistoryBack();

@JS('document.documentElement.requestFullscreen')
external JSPromise _jsRequestFullscreen();

@JS('document.exitFullscreen')
external JSPromise _jsExitFullscreen();

@JS('document.fullscreenElement')
external JSAny? _jsFullscreenElement;

class JSHelper {
  Future<String> callOpenTab(String url, String target) async {
    return await promiseToFuture(jsOpenTab(url, target));
  }

  void setupRightClickBlock() {
    _addEventListener('contextmenu', allowInterop((event) {
      event.preventDefault();
    }));
  }

  void goBack() {
    _jsHistoryBack();
  }

  Future<void> callBrowserFullscreen(bool isFullscreen) async {
    if (isFullscreen) {
      await _jsRequestFullscreen().toDart;
    } else {
      if (_jsFullscreenElement != null) {
        await _jsExitFullscreen().toDart;
      }
    }
  }
}
