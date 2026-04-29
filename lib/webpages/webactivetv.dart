import '../provider/generalprovider.dart';
import '../utils/color.dart';
import '../utils/dimens.dart';
import '../utils/loadingoverlay.dart';
import '../utils/sharedpre.dart';
import '../webwidget/webfooter.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';
import '../utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

class WebActiveTV extends StatefulWidget {
  final String? newPage, oldPage;
  final dynamic reqText;
  const WebActiveTV({
    required this.newPage,
    required this.oldPage,
    required this.reqText,
    super.key,
  });

  @override
  State<WebActiveTV> createState() => WebActiveTVState();
}

class WebActiveTVState extends State<WebActiveTV> {
  SharedPre sharePref = SharedPre();
  final pinPutController = TextEditingController();
  final ScrollController _mainScrollController = ScrollController();

  void _scrollUp() {
    if (!_mainScrollController.hasClients) return;
    _mainScrollController.animateTo(
      _mainScrollController.position.minScrollExtent,
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  Future<void> _scrollListener() async {
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange) {
      setState(() {});
    }
    if (_mainScrollController.offset <=
            _mainScrollController.position.minScrollExtent &&
        !_mainScrollController.position.outOfRange) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _mainScrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    pinPutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor,
      body: SingleChildScrollView(
        controller: _mainScrollController,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              fit: StackFit.passthrough,
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: MyImage(
                    imagePath: (MediaQuery.of(context).size.width >
                            MediaQuery.of(context).size.height)
                        ? "login_bg_land.png"
                        : "login_bg_port.png",
                    fit: BoxFit.fill,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                  ),
                ),
                _buildPageUI(),
                Positioned(
                  top: 30,
                  left: 30,
                  child: Container(
                    width: 180,
                    height: 110,
                    alignment: Alignment.centerLeft,
                    child: MyImage(
                      fit: BoxFit.contain,
                      imagePath: "appicon.png",
                    ),
                  ),
                ),
              ],
            ),

            /* Footer */
            const SizedBox(height: 20),
            kIsWeb
                ? WebFooter(
                    newPage: widget.newPage,
                    oldPage: widget.oldPage,
                    reqText: '',
                    onTypeClick: () {
                      _scrollUp();
                    },
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _buildPageUI() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: MediaQuery.of(context).size.width > 1080
            ? (MediaQuery.of(context).size.width * 0.35)
            : ((MediaQuery.of(context).size.width <= 1080 &&
                    (MediaQuery.of(context).size.width > 720))
                ? (MediaQuery.of(context).size.width * 0.5)
                : MediaQuery.of(context).size.width),
        margin: EdgeInsets.fromLTRB(
          Dimens.isBigScreen(context) ? 50 : 30,
          Dimens.isBigScreen(context) ? 50 : 30,
          Dimens.isBigScreen(context) ? 50 : 30,
          Dimens.isBigScreen(context) ? 50 : 30,
        ),
        padding: EdgeInsets.fromLTRB(
          Dimens.isBigScreen(context) ? 30 : 20,
          Dimens.isBigScreen(context) ? 30 : 20,
          Dimens.isBigScreen(context) ? 30 : 20,
          Dimens.isBigScreen(context) ? 30 : 20,
        ),
        alignment: Alignment.center,
        decoration: Utils.setBackground(appBgColor.withValues(alpha: 0.7), 5),
        child: Column(
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.centerLeft,
                  child: MyImage(
                    fit: BoxFit.fill,
                    imagePath: "backwith_bg.png",
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            MyText(
              color: white,
              text: "verify_tvcode",
              fontsizeNormal: 22,
              multilanguage: true,
              fontweight: FontWeight.bold,
              maxline: 2,
              overflow: TextOverflow.ellipsis,
              textalign: TextAlign.center,
              fontstyle: FontStyle.normal,
            ),
            const SizedBox(height: 8),
            MyText(
              color: descTextColor,
              text: "tvcode_desc",
              fontsizeNormal: 15,
              fontweight: FontWeight.w500,
              maxline: 3,
              overflow: TextOverflow.ellipsis,
              textalign: TextAlign.center,
              multilanguage: true,
              fontstyle: FontStyle.normal,
            ),
            const SizedBox(height: 40),

            /* Enter TV pin */
            Pinput(
              length: 4,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              controller: pinPutController,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              defaultPinTheme: PinTheme(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  border: Border.all(color: colorPrimary, width: 0.7),
                  shape: BoxShape.rectangle,
                  color: edtViewShadowColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                textStyle: kIsWeb
                    ? const TextStyle(
                        color: white,
                        fontSize: 16,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.w800,
                      )
                    : GoogleFonts.inter(
                        color: white,
                        fontSize: 16,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.w800,
                      ),
              ),
            ),
            const SizedBox(height: 30),

            /* Confirm Button */
            InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () {
                printLog("Clicked sms Code =====> ${pinPutController.text}");
                if (pinPutController.text.toString().isEmpty) {
                  Utils.showSnackbar(context, "info", "enter_tv_code", true);
                } else {
                  _checkAndLogin();
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      colorPrimary,
                      colorPrimaryDark,
                    ],
                    begin: FractionalOffset(0.0, 0.0),
                    end: FractionalOffset(1.0, 0.0),
                    stops: [0.0, 1.0],
                    tileMode: TileMode.clamp,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: MyText(
                  color: white,
                  text: "confirm",
                  fontsizeNormal: 17,
                  multilanguage: true,
                  fontweight: FontWeight.w700,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  textalign: TextAlign.center,
                  fontstyle: FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkAndLogin() async {
    printLog("click on Submit mobile => ${pinPutController.text}");
    var generalProvider = Provider.of<GeneralProvider>(context, listen: false);
    LoadingOverlay().show(context);
    await generalProvider.loginWithTV(pinPutController.text.toString());

    if (!generalProvider.loading) {
      if (generalProvider.loginTVModel.status == 200) {
        printLog('Login Successfull!');
        if (!mounted) return;
        LoadingOverlay().hide();
        Utils.showToast("${generalProvider.loginTVModel.message}");
        if (context.canPop()) {
          context.pop();
        }
      } else {
        if (!mounted) return;
        LoadingOverlay().hide();
        Utils.showToast("${generalProvider.loginTVModel.message}");
      }
    }
  }
}
