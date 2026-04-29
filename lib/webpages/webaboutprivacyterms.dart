import '../utils/dimens.dart';
import '../utils/sharedpre.dart';
import '../utils/utils.dart';
import '../webpages/webcomman.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class WebAboutPrivacyTerms extends StatefulWidget {
  final String? newPage, oldPage;
  final dynamic reqText;
  final String appBarTitle, loadURL;

  const WebAboutPrivacyTerms({
    super.key,
    required this.appBarTitle,
    required this.loadURL,
    required this.newPage,
    required this.oldPage,
    required this.reqText,
  });

  @override
  State<WebAboutPrivacyTerms> createState() => _WebAboutPrivacyTermsState();
}

class _WebAboutPrivacyTermsState extends State<WebAboutPrivacyTerms> {
  InAppWebViewController? webViewController;
  SharedPre sharedPref = SharedPre();

  @override
  void initState() {
    super.initState();
    printLog("loadURL ========> ${widget.loadURL}");
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebComman(
      newChild: _buildPageUI(),
      newPage: widget.newPage,
      oldPage: widget.oldPage,
      reqText: '',
    );
  }

  Widget _buildPageUI() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height,
      padding: EdgeInsets.fromLTRB(35, Dimens.homeTabHeight, 35, 0),
      child: setWebView(),
    );
  }

  Widget setWebView() {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.loadURL)),
          initialSettings: InAppWebViewSettings(
            supportZoom: true,
            javaScriptEnabled: true,
            clearCache: true,
            disableHorizontalScroll: true,
            useShouldOverrideUrlLoading: true,
            disableVerticalScroll: false,
          ),
          onLoadStart: (controller, url) async {
            printLog("onLoadStart url =========> $url");
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            return NavigationActionPolicy.ALLOW;
          },
          onLoadStop: (controller, url) async {
            printLog("onLoadStop url =========> $url");
          },
          onProgressChanged: (controller, progress) {
            printLog("onProgressChanged progress =====> $progress");
          },
          onUpdateVisitedHistory: (controller, url, isReload) {
            printLog("onUpdateVisitedHistory url =========> $url");
          },
          onConsoleMessage: (controller, consoleMessage) {
            printLog("consoleMessage =========> $consoleMessage");
          },
        ),
        Positioned.fill(
          child: PointerInterceptor(
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(0),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),
        ),
      ],
    );
  }
}
