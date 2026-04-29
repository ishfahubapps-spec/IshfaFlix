import '../provider/generalprovider.dart';
import '../provider/homeprovider.dart';
import '../provider/profileprovider.dart';
import '../provider/sectiondataprovider.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../utils/dimens.dart';
import '../utils/loadingoverlay.dart';
import '../utils/sharedpre.dart';
import '../utils/utils.dart';
import '../webwidget/interactive_icon.dart';
import '../webwidget/webfooter.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import '../routes/routes_constant.dart';

class WebOTPVerify extends StatefulWidget {
  final String? mobileNumber, newPage, oldPage;
  final dynamic reqText;
  const WebOTPVerify(
    this.mobileNumber, {
    super.key,
    required this.newPage,
    required this.oldPage,
    required this.reqText,
  });

  @override
  State<WebOTPVerify> createState() => _WebOTPVerifyState();
}

class _WebOTPVerifyState extends State<WebOTPVerify> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  SharedPre sharePref = SharedPre();
  late GeneralProvider generalProvider;
  final numberController = TextEditingController();
  final pinPutController = TextEditingController();
  late final FocusNode pinPutFocusNode;
  ScrollController scollController = ScrollController();
  String? verificationId, finalOTP, strDeviceType = "3", strDeviceToken;
  int? forceResendingToken;
  bool codeResended = false;
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
    generalProvider = Provider.of<GeneralProvider>(context, listen: false);
    pinPutFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      codeSend(false);
    });
    _getDeviceToken();
  }

  Future<void> _getDeviceToken() async {
    String? token = await Utils.getFirebaseWebToken();
    strDeviceToken = token;
    strDeviceType = "3";
    printLog("_getDeviceToken strDeviceToken ===> $strDeviceToken");
    printLog("_getDeviceToken strDeviceType ====> $strDeviceType");
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    numberController.dispose();
    pinPutFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor,
      body: SingleChildScrollView(
        controller: _mainScrollController,
        scrollDirection: Axis.vertical,
        child: Column(
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
          Dimens.isBigScreen(context) ? 50 : 20,
          Dimens.isBigScreen(context) ? 50 : 20,
          Dimens.isBigScreen(context) ? 50 : 20,
          Dimens.isBigScreen(context) ? 50 : 20,
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
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width,
              alignment: Alignment.centerLeft,
              child: InteractiveIcon(builder: (isHovered) {
                return Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    focusColor: white.withValues(alpha: 0.5),
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(5.0),
                      child: Container(
                        width: 35,
                        height: 35,
                        alignment: Alignment.center,
                        child: MyImage(
                          fit: BoxFit.contain,
                          imagePath: "backwith_bg.png",
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 15),
            Container(
              width: 180,
              height: 60,
              alignment: Alignment.centerLeft,
              child: MyImage(
                fit: BoxFit.contain,
                imagePath: "appicon.png",
              ),
            ),
            const SizedBox(height: 25),
            MyText(
              color: titleTextColor,
              text: "verifyphonenumber",
              fontsizeNormal: 26,
              fontsizeWeb: 21,
              multilanguage: true,
              fontweight: FontWeight.bold,
              maxline: 1,
              overflow: TextOverflow.ellipsis,
              textalign: TextAlign.center,
              fontstyle: FontStyle.normal,
            ),
            const SizedBox(height: 8),
            MyText(
              color: descTextColor,
              text: "code_sent_desc",
              fontsizeNormal: 15,
              fontsizeWeb: 16,
              fontweight: FontWeight.w600,
              maxline: 3,
              overflow: TextOverflow.ellipsis,
              textalign: TextAlign.center,
              multilanguage: true,
              fontstyle: FontStyle.normal,
            ),
            MyText(
              color: descTextColor,
              text: widget.mobileNumber ?? "",
              fontsizeNormal: 15,
              fontsizeWeb: 16,
              fontweight: FontWeight.w600,
              maxline: 3,
              overflow: TextOverflow.ellipsis,
              textalign: TextAlign.center,
              multilanguage: false,
              fontstyle: FontStyle.normal,
            ),
            const SizedBox(height: 40),

            /* Enter Received OTP */
            if (generalProvider.loadingOTP)
              Container(
                height: 50,
                padding: const EdgeInsets.all(3),
                child: Utils.pageLoader(),
              )
            else
              Pinput(
                length: 6,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                controller: pinPutController,
                focusNode: pinPutFocusNode,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                defaultPinTheme: PinTheme(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorPrimary, width: 0.7),
                    shape: BoxShape.rectangle,
                    color: edtViewShadowColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  textStyle: kIsWeb
                      ? const TextStyle(
                          color: white,
                          fontSize: 18,
                          fontStyle: FontStyle.normal,
                          fontWeight: FontWeight.w700,
                        )
                      : GoogleFonts.inter(
                          color: white,
                          fontSize: 16,
                          fontStyle: FontStyle.normal,
                          fontWeight: FontWeight.w700,
                        ),
                ),
              ),
            const SizedBox(height: 30),
            /* Confirm Button */
            if (!generalProvider.loadingOTP)
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  focusColor: white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(5),
                  onTap: () async {
                    printLog(
                        "Clicked sms Code =====> ${pinPutController.text}");
                    if (pinPutController.text.toString().isEmpty) {
                      Utils.showToast("Enter received OTP");
                    } else {
                      _checkOTPAndLogin();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: Dimens.buttonHeight,
                      decoration: Utils.setGradLTRBGWithBorder(
                          colorPrimary, colorPrimaryDark, transparent, 5, 0),
                      alignment: Alignment.center,
                      child: MyText(
                        color: white,
                        text: "confirm",
                        fontsizeNormal: 17,
                        fontsizeWeb: 19,
                        multilanguage: true,
                        fontweight: FontWeight.w600,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        textalign: TextAlign.center,
                        fontstyle: FontStyle.normal,
                      ),
                    ),
                  ),
                ),
              ),
            if (!generalProvider.loadingOTP) const SizedBox(height: 30),

            /* Resend */
            if (!generalProvider.loadingOTP)
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  focusColor: white.withValues(alpha: 0.5),
                  onTap: () {
                    if (!codeResended) {
                      codeSend(true);
                    }
                  },
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 70),
                    padding: const EdgeInsets.all(5),
                    child: MyText(
                      color: titleTextColor,
                      text: "resend",
                      multilanguage: true,
                      fontsizeNormal: 16,
                      fontsizeWeb: 18,
                      fontweight: FontWeight.w600,
                      maxline: 1,
                      overflow: TextOverflow.ellipsis,
                      textalign: TextAlign.center,
                      fontstyle: FontStyle.normal,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> codeSend(bool isResend) async {
    codeResended = isResend;
    await generalProvider.setLoadingOTP(true);
    if (!mounted) return;
    await phoneSignIn(
        phoneNumber: widget.mobileNumber.toString(), isResend: isResend);
  }

  Future<void> phoneSignIn(
      {required String phoneNumber, required bool isResend}) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: _onVerificationCompleted,
      verificationFailed: _onVerificationFailed,
      codeSent: _onCodeSent,
      codeAutoRetrievalTimeout: _onCodeTimeout,
    );
  }

  Future<void> _onVerificationCompleted(
      PhoneAuthCredential authCredential) async {
    printLog("verification completed ${authCredential.smsCode}");
    await generalProvider.setLoadingOTP(false);
    if (!mounted) return;
    setState(() {
      finalOTP = authCredential.smsCode ?? "";
      pinPutController.text = authCredential.smsCode ?? "";
      printLog("finalOTP =====> $finalOTP");
    });
  }

  Future<void> _onVerificationFailed(FirebaseAuthException exception) async {
    if (exception.code == 'invalid-phone-number') {
      printLog("The phone number entered is invalid!");
      await generalProvider.setLoadingOTP(false);
      if (!mounted) return;
      Utils.showToast("The phone number entered is invalid!");
    }
  }

  Future<void> _onCodeSent(
      String verificationId, int? forceResendingToken) async {
    this.verificationId = verificationId;
    this.forceResendingToken = forceResendingToken;
    await generalProvider.setLoadingOTP(false);
    if (!mounted) return;
    printLog("resendingToken =======> ${forceResendingToken.toString()}");
    printLog("code sent");
  }

  Future<Null> _onCodeTimeout(String timeout) async {
    await generalProvider.setLoadingOTP(false);
    if (!mounted) return;
    codeResended = false;
    return null;
  }

  Future<void> _checkOTPAndLogin() async {
    await generalProvider.setLoadingOTP(false);
    if (!mounted) return;
    bool error = false;
    UserCredential? userCredential;

    printLog("_checkOTPAndLogin verificationId =====> $verificationId");
    printLog("_checkOTPAndLogin smsCode =====> ${pinPutController.text}");
    // Create a PhoneAuthCredential with the code
    PhoneAuthCredential? phoneAuthCredential = PhoneAuthProvider.credential(
      verificationId: verificationId ?? "",
      smsCode: pinPutController.text.toString(),
    );

    if (!mounted) return;
    LoadingOverlay().show(context);
    printLog(
        "phoneAuthCredential.smsCode        =====> ${phoneAuthCredential.smsCode}");
    printLog(
        "phoneAuthCredential.verificationId =====> ${phoneAuthCredential.verificationId}");
    try {
      userCredential = await _auth.signInWithCredential(phoneAuthCredential);
      printLog(
          "_checkOTPAndLogin userCredential =====> ${userCredential.user?.phoneNumber ?? ""}");
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      LoadingOverlay().hide();
      printLog("_checkOTPAndLogin error Code =====> ${e.code}");
      if (e.code == 'invalid-verification-code' ||
          e.code == 'invalid-verification-id') {
        if (!mounted) return;
        Utils.showToast("Enter valid OTP");
        pinPutFocusNode.requestFocus();
        return;
      } else if (e.code == 'session-expired') {
        if (!mounted) return;
        Utils.showToast(
            "Your OTP login session is expired, continue with other logins.");
        return;
      } else {
        error = true;
      }
    }
    printLog(
        "Firebase Verification Complated & phoneNumber => ${userCredential?.user?.phoneNumber} and isError => $error");
    if (!error && userCredential != null) {
      _login(widget.mobileNumber.toString());
    } else {
      if (!mounted) return;
      LoadingOverlay().hide();
      Utils.showToast("Login fail!!!");
    }
  }

  Future<void> _login(String mobile) async {
    printLog("_login mobile ==========> $mobile");
    printLog('_login strDeviceType ==>> $strDeviceType');
    printLog('_login strDeviceToken =>> $strDeviceToken');
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final sectionDataProvider =
        Provider.of<SectionDataProvider>(context, listen: false);

    await generalProvider.loginWithOTP(
        mobile, Constant.deviceName, strDeviceType, strDeviceToken);

    if (!generalProvider.loading) {
      if (generalProvider.loginOTPModel.status == 200) {
        printLog(
            'loginOTPModel ==>> ${generalProvider.loginOTPModel.toString()}');
        printLog('Login Successfull!');
        Utils.saveUserCreds(
          userID: generalProvider.loginOTPModel.result?[0].id.toString(),
          fullName:
              generalProvider.loginOTPModel.result?[0].fullName.toString() ??
                  "",
          userName:
              generalProvider.loginOTPModel.result?[0].userName.toString() ??
                  "",
          userEmail:
              generalProvider.loginOTPModel.result?[0].email.toString() ?? "",
          userMobile: generalProvider.loginOTPModel.result?[0].mobileNumber
                  .toString() ??
              "",
          userImage:
              generalProvider.loginOTPModel.result?[0].image.toString() ?? "",
          userPremium:
              generalProvider.loginOTPModel.result?[0].isBuy.toString() ?? "",
          userType:
              generalProvider.loginOTPModel.result?[0].type.toString() ?? "",
          deviceType:
              generalProvider.loginOTPModel.result?[0].deviceType.toString(),
          deviceToken:
              generalProvider.loginOTPModel.result?[0].deviceToken.toString(),
        );

        // Set UserID for Next
        Constant.userID =
            generalProvider.loginOTPModel.result?[0].id.toString();
        printLog('Constant userID ==>> ${Constant.userID}');

        await Utils.setUserMode(false);
        homeProvider.homeNotifyProvider();
        if (!mounted) return;
        await profileProvider.getProfile(context);
        await sectionDataProvider.getSectionBanner("0", "1");
        await sectionDataProvider.getSectionList("0", "1", 1);
        // Hide Progress Dialog
        if (!mounted) return;
        LoadingOverlay().hide();
        if (!mounted) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
          Navigator.pop(context);
        }
        context.pushReplacementNamed(RoutesConstant.homePage);
      } else {
        if (!mounted) return;
        LoadingOverlay().hide();
        Utils.showToast(generalProvider.loginOTPModel.message ?? "");
      }
    }
  }
}
