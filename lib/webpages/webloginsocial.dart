import 'dart:io';

import 'package:flutter_locales/flutter_locales.dart';

import '../utils/loadingoverlay.dart';
import '../provider/generalprovider.dart';
import '../provider/homeprovider.dart';
import '../provider/profileprovider.dart';
import '../provider/sectiondataprovider.dart';
import '../routes/routes_constant.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../utils/dimens.dart';
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
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

class WebLoginSocial extends StatefulWidget {
  final String? newPage, oldPage;
  final dynamic reqText;
  const WebLoginSocial({
    super.key,
    required this.newPage,
    required this.oldPage,
    required this.reqText,
  });

  @override
  State<WebLoginSocial> createState() => _WebLoginSocialState();
}

class _WebLoginSocialState extends State<WebLoginSocial> {
  SharedPre sharedPre = SharedPre();
  final numberController = TextEditingController();
  String? mobileNumber, email, userName, strType, strDeviceType, strDeviceToken;
  File? mProfileImg;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn.instance;
  bool initialized = false;
  String? webServerClientId;

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
    _getDeviceToken();
  }

  Future<void> _getDeviceToken() async {
    webServerClientId = await sharedPre.read(Constant.googleClientIdKey);
    printLog("_getDeviceToken webServerClientId ===> $webServerClientId");
    String? token = await Utils.getFirebaseWebToken();
    strDeviceToken = token;
    strDeviceType = "3";
    printLog("_getDeviceToken strDeviceToken ===> $strDeviceToken");
    printLog("_getDeviceToken strDeviceType ====> $strDeviceType");
  }

  @override
  void dispose() {
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (context.canPop()) {
                        context.pop();
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
              color: white,
              text: "welcomeback",
              fontsizeNormal: 16,
              fontsizeWeb: 25,
              multilanguage: true,
              fontweight: FontWeight.w600,
              maxline: 1,
              overflow: TextOverflow.ellipsis,
              textalign: TextAlign.start,
              fontstyle: FontStyle.normal,
            ),
            const SizedBox(height: 7),
            MyText(
              color: descTextColor,
              text: "login_with_mobile_note",
              fontsizeNormal: 13,
              fontsizeWeb: 15,
              multilanguage: true,
              fontweight: FontWeight.w500,
              maxline: 2,
              overflow: TextOverflow.ellipsis,
              textalign: TextAlign.start,
              fontstyle: FontStyle.normal,
            ),
            const SizedBox(height: 20),

            /* Enter Mobile Number */
            Container(
              width: MediaQuery.of(context).size.width,
              height: Dimens.textFieldHeightWeb,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: colorPrimary,
                  width: 0.7,
                ),
                color: edtViewShadowColor,
                borderRadius: BorderRadius.circular(5),
              ),
              child: IntlPhoneField(
                disableLengthCheck: true,
                controller: numberController,
                textAlignVertical: TextAlignVertical.center,
                autovalidateMode: AutovalidateMode.disabled,
                style: kIsWeb
                    ? const TextStyle(
                        color: white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3.0,
                      )
                    : GoogleFonts.inter(
                        color: white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3.0,
                      ),
                showCountryFlag: false,
                showDropdownIcon: false,
                initialCountryCode: Constant.defaultCountryCode,
                dropdownTextStyle: kIsWeb
                    ? const TextStyle(
                        color: white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      )
                    : GoogleFonts.inter(
                        color: white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintStyle: kIsWeb
                      ? const TextStyle(
                          color: descTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        )
                      : GoogleFonts.inter(
                          color: descTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                  hintText: Locales.string(context, "enter_mobile"),
                ),
                onChanged: (phone) {
                  printLog('===> ${phone.completeNumber}');
                  mobileNumber = phone.completeNumber;
                  printLog('===>mobileNumber $mobileNumber');
                },
                onCountryChanged: (country) {
                  printLog('===> ${country.name}');
                  printLog('===> ${country.code}');
                },
              ),
            ),
            const SizedBox(height: 30),

            /* Login Button */
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () async {
                  printLog("Click mobileNumber ==> $mobileNumber");
                  if (numberController.text.toString().isEmpty) {
                    Utils.showToast("Enter your mobile number to login");
                  } else {
                    printLog("mobileNumber ==> $mobileNumber");
                    if (!mounted) return;
                    Utils.openWebDialog(
                      context: context,
                      newPage: RoutesConstant.loginOTPPage,
                      oldPage: widget.oldPage ?? "",
                      reqText: mobileNumber ?? "",
                    );
                  }
                },
                focusColor: white,
                borderRadius: BorderRadius.circular(5),
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
                      text: "login",
                      multilanguage: true,
                      fontsizeNormal: 15,
                      fontsizeWeb: 16,
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
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: Dimens.isBigScreen(context) ? 80 : 50,
                  height: 1,
                  color: colorAccent,
                ),
                const SizedBox(width: 15),
                MyText(
                  color: descTextColor,
                  text: "or",
                  multilanguage: true,
                  fontsizeNormal: 14,
                  fontsizeWeb: 14,
                  fontweight: FontWeight.w500,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  textalign: TextAlign.center,
                  fontstyle: FontStyle.normal,
                ),
                const SizedBox(width: 15),
                Container(
                  width: Dimens.isBigScreen(context) ? 80 : 50,
                  height: 1,
                  color: colorAccent,
                ),
              ],
            ),
            const SizedBox(height: 25),

            /* Google Login Button */
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  printLog("Clicked on : ====> loginWith Google");
                  _gmailLogin();
                },
                focusColor: colorPrimary,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: Dimens.buttonHeight,
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                    decoration: BoxDecoration(
                      color: white,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MyImage(
                          width: 20,
                          height: 20,
                          imagePath: "ic_google.png",
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 25),
                        Flexible(
                          child: MyText(
                            color: black,
                            text: "loginwithgoogle",
                            fontsizeNormal: 14,
                            fontsizeWeb: 16,
                            multilanguage: true,
                            fontweight: FontWeight.w600,
                            maxline: 1,
                            overflow: TextOverflow.ellipsis,
                            textalign: TextAlign.center,
                            fontstyle: FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* Google(Gmail) Login */
  Future<void> _gmailLogin() async {
    UserCredential userCredential;
    try {
      LoadingOverlay().show(context);
      GoogleAuthProvider authProvider = GoogleAuthProvider();
      authProvider
          .setCustomParameters({'prompt': 'select_account'}); // force chooser
      authProvider.addScope('email');
      authProvider.addScope('profile');
      userCredential = await _auth.signInWithPopup(authProvider);

      if (userCredential.user == null) {
        LoadingOverlay().hide();
        Utils.showToast("User not found!!!");
        return;
      }
      printLog(
          "_gmailLogin UserName ======> ${userCredential.user?.displayName}");
      printLog("_gmailLogin UserEmail =====> ${userCredential.user?.email}");
      String firebasedid = userCredential.user?.uid ?? "";
      printLog('_gmailLogin firebasedid ===> $firebasedid');

      checkAndNavigate(userCredential.user?.email ?? "",
          userCredential.user?.displayName ?? "", "2");
    } on FirebaseAuthException catch (e) {
      printLog('_gmailLogin Firebase Error Code ==> ${e.code.toString()}');
      printLog('_gmailLogin Firebase Error =======> ${e.message.toString()}');
      if (!mounted) return;
      LoadingOverlay().hide();
    }
  }

  Future<void> checkAndNavigate(
      String mail, String displayName, String type) async {
    email = mail;
    userName = displayName;
    strType = type;
    printLog('checkAndNavigate email ==========>> $email');
    printLog('checkAndNavigate userName =======>> $userName');
    printLog('checkAndNavigate strType ========>> $strType');
    printLog('checkAndNavigate strDeviceType ==>> $strDeviceType');
    printLog('checkAndNavigate strDeviceToken =>> $strDeviceToken');
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    final sectionDataProvider =
        Provider.of<SectionDataProvider>(context, listen: false);
    final generalProvider =
        Provider.of<GeneralProvider>(context, listen: false);

    await generalProvider.loginWithSocial(email, userName, strType,
        Constant.deviceName, strDeviceType, strDeviceToken, null);
    printLog('checkAndNavigate loading ==>> ${generalProvider.loading}');

    if (!generalProvider.loading) {
      if (generalProvider.loginSocialModel.status == 200) {
        printLog('Login Successfull!');
        Utils.saveUserCreds(
          userID: generalProvider.loginSocialModel.result?[0].id.toString(),
          fullName:
              generalProvider.loginSocialModel.result?[0].fullName.toString() ??
                  "",
          userName:
              generalProvider.loginSocialModel.result?[0].userName.toString() ??
                  "",
          userEmail:
              generalProvider.loginSocialModel.result?[0].email.toString() ??
                  "",
          userMobile: generalProvider.loginSocialModel.result?[0].mobileNumber
                  .toString() ??
              "",
          userImage:
              generalProvider.loginSocialModel.result?[0].image.toString() ??
                  "",
          userPremium:
              generalProvider.loginSocialModel.result?[0].isBuy.toString() ??
                  "",
          userType:
              generalProvider.loginSocialModel.result?[0].type.toString() ?? "",
          deviceType:
              generalProvider.loginSocialModel.result?[0].deviceType.toString(),
          deviceToken: generalProvider.loginSocialModel.result?[0].deviceToken
              .toString(),
        );

        // Set UserID for Next
        Constant.userID =
            generalProvider.loginSocialModel.result?[0].id.toString();
        printLog('Constant userID ==>> ${Constant.userID}');

        await Utils.setUserMode(false);
        homeProvider.homeNotifyProvider();
        if (!mounted) return;
        await profileProvider.getProfile(context);
        await sectionDataProvider.getSectionBanner("0", "1");
        await sectionDataProvider.getSectionList("0", "1", 1);
        // Hide Progress Dialog
        LoadingOverlay().hide();
        if (!mounted) return;
        if (context.canPop()) {
          printLog("=====================REMOVE=====================");
          context.pop();
        }
        context.pushReplacementNamed(RoutesConstant.homePage);
      } else {
        // Hide Progress Dialog
        if (!mounted) return;
        LoadingOverlay().hide();
        Utils.showToast(generalProvider.loginSocialModel.message ?? "");
      }
    }
  }
}
