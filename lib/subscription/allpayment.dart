import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_locales/flutter_locales.dart';
import 'package:paytmpayments_allinonesdk/paytmpayments_allinonesdk.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../provider/bottombarprovider.dart';
import '../provider/paymentprovider.dart';
import '../provider/profileprovider.dart';
import '../routes/routes_constant.dart';
import '../subscription/instamojopg.dart';
import '../subscription/payuhashservice.dart';
import '../subscription/payuparams.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../utils/dimens.dart';
import '../utils/loadingoverlay.dart';
import '../utils/sharedpre.dart';
import '../utils/utils.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';
import '../widget/nodata.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import '../subscription/stripe/stripe_checkout.dart';
import 'package:flutterwave_standard_smart/flutterwave.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:pay_with_paystack/pay_with_paystack.dart';
import 'package:payu_checkoutpro_flutter/PayUConstantKeys.dart';
import 'package:payu_checkoutpro_flutter/payu_checkoutpro_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:provider/provider.dart';

final bool _kAutoConsume = Platform.isIOS || true;

class AllPayment extends StatefulWidget {
  final dynamic reqText;
  final String? payType,
      newPage,
      oldPage,
      producerId,
      itemId,
      price,
      itemTitle,
      typeId,
      videoType,
      subVideoType,
      productPackage,
      currency;
  const AllPayment({
    super.key,
    required this.newPage,
    required this.oldPage,
    required this.reqText,
    required this.payType,
    required this.producerId,
    required this.itemId,
    required this.price,
    required this.itemTitle,
    required this.typeId,
    required this.videoType,
    required this.subVideoType,
    required this.productPackage,
    required this.currency,
  });

  @override
  State<AllPayment> createState() => AllPaymentState();
}

class AllPaymentState extends State<AllPayment>
    implements PayUCheckoutProProtocol {
  final couponController = TextEditingController();
  late PaymentProvider paymentProvider;
  late BottombarProvider bottombarProvider;
  SharedPre sharedPref = SharedPre();
  String? userId, userName, userEmail, userMobileNo;
  String? strCouponCode = "", couponStatus;
  bool isPaymentDone = false;

  /* InApp Purchase */
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  late List<String> _kProductIds;
  final List<PurchaseDetails> _purchases = <PurchaseDetails>[];

  /* Razorpay */
  late Razorpay razorpay;

  /* Paytm */
  String paytmResult = "";

  /* Stripe */
  Map<String, dynamic>? paymentIntent;

  /* PayUMoney */
  late PayUCheckoutProFlutter _payUCheckoutPro;

  @override
  void initState() {
    super.initState();
    paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    bottombarProvider = Provider.of<BottombarProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();
    });
    if (!kIsWeb) {
      /* InApp Purchase */
      _kProductIds = <String>[widget.productPackage ?? ""];
      final Stream<List<PurchaseDetails>> purchaseUpdated =
          _inAppPurchase.purchaseStream;
      _subscription =
          purchaseUpdated.listen((List<PurchaseDetails> purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      }, onDone: () {
        _subscription.cancel();
      }, onError: (Object error) {
        // handle error here.
        printLog("onError ============> ${error.toString()}");
        LoadingOverlay().hide(); // Stop Loading...
      });
      initStoreInfo();
    }

    /* Razorpay */
    razorpay = Razorpay();
  }

  Future<void> _getData() async {
    printLog('_getData paymentId ==> ${paymentProvider.paymentId}');
    /* Save Params */
    if (paymentProvider.paymentId == null) {
      paymentProvider.setFinalAmount(widget.price ?? "");
      printLog('_getData finalAmount ==> ${paymentProvider.finalAmount}');

      await paymentProvider.setCurrentPayParams(
        payType: widget.payType ?? "",
        itemId: widget.itemId ?? "",
        price: paymentProvider.finalAmount ?? "",
        itemTitle: widget.itemTitle ?? "",
        typeId: widget.typeId ?? "",
        videoType: widget.videoType ?? "",
        productPackage: widget.productPackage ?? "",
        currency: Constant.currency,
        paymentId: Utils.generateRandomOrderID(),
      );

      await paymentProvider.getPaymentOption();

      userId = await sharedPref.read("userid");
      userName = await sharedPref.read("userfullname");
      userEmail = await sharedPref.read("useremail");
      userMobileNo = await sharedPref.read("usermobile");
      printLog('_getData userId ==> $userId');
      printLog('_getData userName ==> $userName');
      printLog('_getData userEmail ==> $userEmail');
      printLog('_getData userMobileNo ==> $userMobileNo');

      couponStatus = await Utils.configByStatus(status: Constant.couponStatus);
      printLog('_getData couponStatus ==> $couponStatus');

      Future.delayed(Duration.zero).then((value) {
        if (!mounted) return;
        setState(() {});
      });
    } else {
      if (paymentProvider.payType == "Package") {
        addTransaction(
            "stripe",
            paymentProvider.itemId,
            paymentProvider.itemTitle,
            paymentProvider.finalAmount,
            paymentProvider.paymentId);
      } else if (paymentProvider.payType == "Rent") {
        addRentTransaction(
            "stripe",
            paymentProvider.itemId,
            paymentProvider.finalAmount,
            paymentProvider.typeId,
            paymentProvider.videoType);
      }
    }
  }

  @override
  void dispose() {
    razorpay.clear();
    paymentProvider.clearProvider();
    if (!kIsWeb) {
      if (Platform.isIOS) {
        final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
            _inAppPurchase
                .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        iosPlatformAddition.setDelegate(null);
      }
      _subscription.cancel();
    }
    couponController.dispose();
    super.dispose();
  }

  /* add_transaction API */
  Future addTransaction(
      dynamic pgName, packageId, description, amount, paymentId) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    LoadingOverlay().show(context);
    await paymentProvider.addTransaction(packageId, description, amount,
        paymentProvider.paymentId, (pgName == "inapp") ? "" : strCouponCode);

    if (!paymentProvider.payLoading) {
      if (!mounted) return;
      LoadingOverlay().hide();

      if (paymentProvider.successModel.status == 200) {
        isPaymentDone = true;
        if (!mounted) return;
        await profileProvider.getProfile(context);

        if (!mounted) return;
        if (kIsWeb) {
          if (context.canPop()) {
            context.pop(isPaymentDone);
          }
          context.pushReplacementNamed(RoutesConstant.homePage);
        } else {
          await bottombarProvider.setBottomNavIndex(0);
          if (!mounted) return;
          Utils.redirectToMainPage(context: context);
        }
      } else {
        isPaymentDone = false;
        Utils.showSnackbar(
            context, "info", paymentProvider.successModel.message ?? "", false);
      }
    }
  }

  /* add_rent_transaction API */
  Future addRentTransaction(
      dynamic pgName, videoId, amount, typeId, videoType) async {
    LoadingOverlay().show(context);
    await paymentProvider.addRentTransaction(
        widget.producerId,
        videoId,
        amount,
        typeId,
        videoType,
        widget.subVideoType,
        paymentProvider.paymentId,
        widget.itemTitle,
        (pgName == "inapp") ? "" : strCouponCode);

    if (!paymentProvider.payLoading) {
      if (!mounted) return;
      LoadingOverlay().hide();

      if (paymentProvider.successModel.status == 200) {
        isPaymentDone = true;
        if (!mounted) return;
        if (kIsWeb) {
          if (context.canPop()) {
            context.pop(isPaymentDone);
          }
          context.pushReplacementNamed(RoutesConstant.homePage);
        } else {
          await bottombarProvider.setBottomNavIndex(0);
          if (!mounted) return;
          if (Navigator.canPop(context)) {
            Navigator.pop(context, isPaymentDone);
          }
          if (!mounted) return;
          Utils.redirectToMainPage(context: context);
        }
      } else {
        isPaymentDone = false;
        if (!mounted) return;
        Utils.showToast(paymentProvider.successModel.message ?? "");
      }
    }
  }

  /* apply_coupon API */
  Future applyCoupon() async {
    FocusManager.instance.primaryFocus?.unfocus();
    LoadingOverlay().show(context);
    if (widget.payType == "Package") {
      /* Package Coupon */
      await paymentProvider.applyPackageCouponCode(
          strCouponCode, widget.itemId);

      if (!paymentProvider.couponLoading) {
        LoadingOverlay().hide();
        if (paymentProvider.couponModel.status == 200) {
          couponController.clear();
          paymentProvider.setFinalAmount(
              paymentProvider.couponModel.result?.discountAmount.toString());
          strCouponCode =
              paymentProvider.couponModel.result?.uniqueId.toString();
          printLog("strCouponCode =============> $strCouponCode");
          printLog("finalAmount =============> ${paymentProvider.finalAmount}");
          Utils.showToast(paymentProvider.couponModel.message ?? "");
        } else {
          Utils.showToast(paymentProvider.couponModel.message ?? "");
        }
      }
    } else if (widget.payType == "Rent") {
      /* Rent Coupon */
      await paymentProvider.applyRentCouponCode(strCouponCode, widget.itemId,
          widget.typeId, widget.videoType, widget.price);

      if (!paymentProvider.couponLoading) {
        LoadingOverlay().hide();
        if (paymentProvider.couponModel.status == 200) {
          couponController.clear();
          paymentProvider.setFinalAmount(
              paymentProvider.couponModel.result?.discountAmount.toString());
          strCouponCode =
              paymentProvider.couponModel.result?.uniqueId.toString();
          printLog("strCouponCode =============> $strCouponCode");
          printLog("finalAmount =============> ${paymentProvider.finalAmount}");
          Utils.showToast(paymentProvider.couponModel.message ?? "");
        } else {
          Utils.showToast(paymentProvider.couponModel.message ?? "");
        }
      }
    } else {
      LoadingOverlay().hide();
    }
  }

  Future<void> openPayment({required String pgName}) async {
    printLog("finalAmount =============> ${paymentProvider.finalAmount}");
    if (paymentProvider.finalAmount != "0") {
      if (pgName == "paypal") {
        _paypalInit();
      } else if (pgName == "inapp") {
        _initInAppPurchase();
      } else if (pgName == "razorpay") {
        _initializeRazorpay();
      } else if (pgName == "flutterwave") {
        _flutterwaveInit();
      } else if (pgName == "paytm") {
        _paytmInit();
      } else if (pgName == "stripe") {
        _stripeInit();
      } else if (pgName == "payumoney") {
        _payUMoneyInit();
      } else if (pgName == "paystack") {
        _paystackInit();
      } else if (pgName == "instamojo") {
        _initInstamojo();
      } else if (pgName == "cash") {
        if (!mounted) return;
        Utils.showSnackbar(context, "info", "cash_payment_msg", true);
      }
    } else {
      if (widget.payType == "Package") {
        addTransaction("", paymentProvider.itemId, paymentProvider.itemTitle,
            paymentProvider.finalAmount, paymentProvider.paymentId);
      } else if (widget.payType == "Rent") {
        addRentTransaction(
            "",
            paymentProvider.itemId,
            paymentProvider.finalAmount,
            paymentProvider.typeId,
            paymentProvider.videoType);
      }
    }
  }

  bool checkKeysAndContinue({
    required String isLive,
    required bool isBothKeyReq,
    required String key1,
    required String key2,
  }) {
    if (isBothKeyReq) {
      if (key1 == "" || key2 == "") {
        Utils.showSnackbar(context, "", "payment_not_processed", true);
        return false;
      }
    } else {
      if (key1 == "") {
        Utils.showSnackbar(context, "", "payment_not_processed", true);
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        await onBackPressed(didPop);
      },
      child: _buildPage(),
    );
  }

  Widget _buildPage() {
    return Scaffold(
      backgroundColor: appBgColor,
      appBar: (kIsWeb || Constant.isTV)
          ? null
          : Utils.myAppBarWithBack(context, "payment_details", true),
      body: SafeArea(
        child: Center(
          child: _buildMobilePage(),
        ),
      ),
    );
  }

  Widget _buildMobilePage() {
    return Container(
      width: Dimens.isBigScreen(context)
          ? MediaQuery.of(context).size.width * 0.5
          : MediaQuery.of(context).size.width,
      margin: Dimens.isBigScreen(context)
          ? const EdgeInsets.fromLTRB(50, 0, 50, 50)
          : const EdgeInsets.all(0),
      alignment: Alignment.center,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: Dimens.isBigScreen(context) ? 40 : 0),
          /* Coupon Code Box & Total Amount */
          Container(
            margin: const EdgeInsets.all(8.0),
            child: Card(
              semanticContainer: true,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              elevation: 5,
              color: secondaryBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width,
                constraints: const BoxConstraints(minHeight: 50),
                alignment: Alignment.centerLeft,
                child: Column(
                  children: [
                    if (couponStatus != null && couponStatus == "1")
                      _buildCouponBox(),
                    if (couponStatus != null && couponStatus == "1")
                      const SizedBox(height: 8),
                    if (couponStatus != null && couponStatus == "1")
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                        child: MyText(
                          color: descTextColor,
                          text: 'coupon_not_for',
                          multilanguage: true,
                          fontsizeNormal: 14,
                          fontsizeWeb: 16,
                          maxline: 10,
                          overflow: TextOverflow.ellipsis,
                          fontweight: FontWeight.w600,
                          textalign: TextAlign.start,
                          fontstyle: FontStyle.normal,
                        ),
                      ),
                    if (couponStatus != null && couponStatus == "1")
                      const SizedBox(height: 20),
                    _buildPriceView(),
                  ],
                ),
              ),
            ),
          ),

          /* PGs */
          Expanded(
            child: SingleChildScrollView(
              child: paymentProvider.loading
                  ? Container(
                      height: 230,
                      padding: const EdgeInsets.all(20),
                      child: Utils.pageLoader(),
                    )
                  : paymentProvider.paymentOptionModel.status == 200
                      ? paymentProvider.paymentOptionModel.result != null
                          ? ((kIsWeb)
                              ? _buildWebPayments()
                              : _buildPaymentPage())
                          : const NoData(
                              title: 'no_payment', subTitle: 'no_payment_desc')
                      : const NoData(
                          title: 'no_payment', subTitle: 'no_payment_desc'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponBox() {
    return Consumer<PaymentProvider>(
      builder: (context, paymentProvider, child) {
        if (strCouponCode != null &&
            (strCouponCode ?? "").isNotEmpty &&
            paymentProvider.finalAmount != null &&
            paymentProvider.finalAmount != "" &&
            widget.price != null &&
            widget.price != "" &&
            double.parse(paymentProvider.finalAmount ?? "0") <
                double.parse(widget.price ?? "0")) {
          return Container(
            width: MediaQuery.of(context).size.width,
            height: 50,
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: MyText(
                    color: greenColor,
                    text: 'coupon_applied',
                    multilanguage: true,
                    fontsizeNormal: 15,
                    fontsizeWeb: 17,
                    maxline: 2,
                    overflow: TextOverflow.ellipsis,
                    fontweight: FontWeight.w600,
                    textalign: TextAlign.start,
                    fontstyle: FontStyle.normal,
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(5),
                  onTap: () async {
                    printLog("Click on Apply!");
                    printLog(
                        "finalAmount =====> ${paymentProvider.finalAmount}");
                    printLog("price ===========> ${widget.price}");
                    paymentProvider.setFinalAmount(widget.price ?? "");
                    if (!context.mounted) return;
                    Utils.showToast(Locales.string(context, "coupon_removed"));
                  },
                  child: Container(
                    height: 30,
                    constraints: const BoxConstraints(minWidth: 50),
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                    decoration: Utils.setBackground(white, 5),
                    alignment: Alignment.center,
                    child: MyText(
                      color: black,
                      text: "remove",
                      multilanguage: true,
                      fontsizeNormal: 13,
                      fontsizeWeb: 14,
                      maxline: 1,
                      overflow: TextOverflow.ellipsis,
                      fontweight: FontWeight.w600,
                      textalign: TextAlign.end,
                      fontstyle: FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          width: MediaQuery.of(context).size.width,
          height: 50,
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          padding: const EdgeInsets.only(right: 10),
          decoration:
              Utils.setBGWithBorder(transparent, colorPrimaryDark, 5, 0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  alignment: Alignment.center,
                  child: TextField(
                    onSubmitted: (value) async {
                      if (value.isNotEmpty) {
                        strCouponCode = value.toString();
                        applyCoupon();
                      } else {
                        strCouponCode = "";
                      }
                      printLog("strCouponCode ===========> $strCouponCode");
                    },
                    onChanged: (value) async {
                      if (value.isNotEmpty) {
                        strCouponCode = value.toString();
                      } else {
                        strCouponCode = "";
                      }
                      printLog("strCouponCode ===========> $strCouponCode");
                    },
                    textInputAction: TextInputAction.done,
                    obscureText: false,
                    controller: couponController,
                    keyboardType: TextInputType.text,
                    maxLines: 1,
                    style: const TextStyle(
                      color: white,
                      fontSize: 16,
                      overflow: TextOverflow.ellipsis,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      filled: true,
                      fillColor: transparent,
                      hintStyle: TextStyle(
                        color: descTextColor,
                        fontSize: 14,
                        overflow: TextOverflow.ellipsis,
                        fontWeight: FontWeight.w500,
                      ),
                      hintText: Locales.string(context, "coupon_code_hint"),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () async {
                  printLog("Click on Apply!");
                  printLog("strCouponCode ===========> $strCouponCode");
                  if (strCouponCode != null &&
                      (strCouponCode ?? "").isNotEmpty) {
                    applyCoupon();
                  } else {
                    Utils.showSnackbar(
                        context, "info", "enter_coupon_code", true);
                  }
                },
                child: Container(
                  height: 30,
                  constraints: const BoxConstraints(minWidth: 50),
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                  decoration: Utils.setBackground(white, 5),
                  alignment: Alignment.center,
                  child: MyText(
                    color: black,
                    text: "apply",
                    multilanguage: true,
                    fontsizeNormal: 13,
                    fontsizeWeb: 14,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    fontweight: FontWeight.w600,
                    textalign: TextAlign.end,
                    fontstyle: FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceView() {
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: const BoxConstraints(minHeight: 50),
      decoration: Utils.setBackground(colorPrimary, 0),
      padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
      alignment: Alignment.centerLeft,
      child: Consumer<PaymentProvider>(
        builder: (context, paymentProvider, child) {
          return RichText(
            textAlign: TextAlign.start,
            text: TextSpan(
              text: Locales.string(context, "payable_amount_is"),
              style: GoogleFonts.inter(
                textStyle: const TextStyle(
                  color: lightBlack,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.normal,
                  letterSpacing: 0.5,
                ),
              ),
              children: <TextSpan>[
                TextSpan(
                  text:
                      "${Constant.currencySymbol}${paymentProvider.finalAmount ?? ""}  ",
                  style: kIsWeb
                      ? const TextStyle(
                          color: black,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.normal,
                          letterSpacing: 0.2,
                        )
                      : GoogleFonts.inter(
                          textStyle: const TextStyle(
                            color: black,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
                if (strCouponCode != null &&
                    (strCouponCode ?? "").isNotEmpty &&
                    paymentProvider.finalAmount != null &&
                    paymentProvider.finalAmount != "" &&
                    widget.price != null &&
                    widget.price != "" &&
                    double.parse(paymentProvider.finalAmount ?? "0") <
                        double.parse(widget.price ?? "0"))
                  TextSpan(
                    text: "${Constant.currencySymbol}${widget.price}",
                    style: kIsWeb
                        ? const TextStyle(
                            color: grayDark,
                            decoration: TextDecoration.lineThrough,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.normal,
                            letterSpacing: 0.2,
                          )
                        : GoogleFonts.inter(
                            textStyle: const TextStyle(
                              color: grayDark,
                              decoration: TextDecoration.lineThrough,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.normal,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentPage() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MyText(
            color: titleTextColor,
            text: "payment_methods",
            fontsizeNormal: 15,
            fontsizeWeb: 17,
            maxline: 1,
            multilanguage: true,
            overflow: TextOverflow.ellipsis,
            fontweight: FontWeight.w600,
            textalign: TextAlign.center,
            fontstyle: FontStyle.normal,
          ),
          const SizedBox(height: 5),
          MyText(
            color: descTextColor,
            text: "choose_a_payment_methods_to_pay",
            multilanguage: true,
            fontsizeNormal: 13,
            fontsizeWeb: 15,
            maxline: 2,
            overflow: TextOverflow.ellipsis,
            fontweight: FontWeight.w500,
            textalign: TextAlign.center,
            fontstyle: FontStyle.normal,
          ),
          const SizedBox(height: 15),
          MyText(
            color: colorAccent,
            text: "pay_with",
            multilanguage: true,
            fontsizeNormal: 16,
            fontsizeWeb: 16,
            maxline: 1,
            overflow: TextOverflow.ellipsis,
            fontweight: FontWeight.w700,
            textalign: TextAlign.center,
            fontstyle: FontStyle.normal,
          ),
          const SizedBox(height: 20),

          /* /* Payments */ */
          (!kIsWeb)
              ? (/* Platform.isIOS ? _buildIOSPG() :  */ _buildAndroidPG())
              : const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildWebPayments() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MyText(
            color: titleTextColor,
            text: "payment_methods",
            fontsizeNormal: 15,
            fontsizeWeb: 17,
            maxline: 1,
            multilanguage: true,
            overflow: TextOverflow.ellipsis,
            fontweight: FontWeight.w600,
            textalign: TextAlign.center,
            fontstyle: FontStyle.normal,
          ),
          const SizedBox(height: 5),
          MyText(
            color: descTextColor,
            text: "choose_a_payment_methods_to_pay",
            multilanguage: true,
            fontsizeNormal: 13,
            fontsizeWeb: 15,
            maxline: 2,
            overflow: TextOverflow.ellipsis,
            fontweight: FontWeight.w500,
            textalign: TextAlign.center,
            fontstyle: FontStyle.normal,
          ),
          const SizedBox(height: 15),
          MyText(
            color: colorAccent,
            text: "pay_with",
            multilanguage: true,
            fontsizeNormal: 16,
            fontsizeWeb: 16,
            maxline: 1,
            overflow: TextOverflow.ellipsis,
            fontweight: FontWeight.w700,
            textalign: TextAlign.center,
            fontstyle: FontStyle.normal,
          ),
          const SizedBox(height: 20),

          /* Stripe */
          paymentProvider.paymentOptionModel.result?.stripe != null
              ? paymentProvider.paymentOptionModel.result?.stripe?.visibility ==
                      "1"
                  ? _buildPGButton("pg_stripe.png", "Stripe", 35, 70,
                      onClick: () async {
                      paymentProvider.setCurrentPayment("stripe");
                      openPayment(pgName: "stripe");
                    })
                  : const SizedBox.shrink()
              : const NoData(title: 'no_payment', subTitle: 'no_payment_desc'),
        ],
      ),
    );
  }

  Widget _buildIOSPG() {
    /* In-App purchase */
    return _buildIOSPGButton("In-App Purchase", 35, 110, onClick: () async {
      paymentProvider.setCurrentPayment("inapp");
      _initInAppPurchase();
    });
  }

  Widget _buildIOSPGButton(String pgName, double imgHeight, double imgWidth,
      {required Function() onClick}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: Card(
        semanticContainer: true,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        elevation: 5,
        color: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onClick,
          child: Container(
            constraints: const BoxConstraints(minHeight: 85),
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: MyText(
                    color: black,
                    text: pgName,
                    multilanguage: false,
                    fontsizeNormal: 22,
                    fontsizeWeb: 22,
                    maxline: 2,
                    overflow: TextOverflow.ellipsis,
                    fontweight: FontWeight.w600,
                    textalign: TextAlign.start,
                    fontstyle: FontStyle.normal,
                  ),
                ),
                const SizedBox(width: 20),
                MyImage(
                  imagePath: "ic_arrow_right.png",
                  fit: BoxFit.contain,
                  height: 22,
                  width: 20,
                  color: defaultIconColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAndroidPG() {
    return Column(
      children: [
        /* In-App purchase */
        paymentProvider.paymentOptionModel.result?.inAppPurchage != null
            ? paymentProvider
                        .paymentOptionModel.result?.inAppPurchage?.visibility ==
                    "1"
                ? _buildPGButton("pg_inapp.png", "InApp Purchase", 35, 110,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("inapp");
                    openPayment(pgName: "inapp");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* Paypal */
        paymentProvider.paymentOptionModel.result?.paypal != null
            ? paymentProvider.paymentOptionModel.result?.paypal?.visibility ==
                    "1"
                ? _buildPGButton("pg_paypal.png", "Paypal", 35, 130,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("paypal");
                    openPayment(pgName: "paypal");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* Razorpay */
        paymentProvider.paymentOptionModel.result?.razorpay != null
            ? paymentProvider.paymentOptionModel.result?.razorpay?.visibility ==
                    "1"
                ? _buildPGButton("pg_razorpay.png", "Razorpay", 35, 130,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("razorpay");
                    openPayment(pgName: "razorpay");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* Paytm */
        paymentProvider.paymentOptionModel.result?.payTm != null
            ? paymentProvider.paymentOptionModel.result?.payTm?.visibility ==
                    "1"
                ? _buildPGButton("pg_paytm.png", "Paytm", 30, 90,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("paytm");
                    openPayment(pgName: "paytm");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* Flutterwave */
        paymentProvider.paymentOptionModel.result?.flutterWave != null
            ? paymentProvider
                        .paymentOptionModel.result?.flutterWave?.visibility ==
                    "1"
                ? _buildPGButton("pg_flutterwave.png", "Flutterwave", 35, 130,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("flutterwave");
                    openPayment(pgName: "flutterwave");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* PayUMoney */
        paymentProvider.paymentOptionModel.result?.payUMoney != null
            ? paymentProvider
                        .paymentOptionModel.result?.payUMoney?.visibility ==
                    "1"
                ? _buildPGButton("pg_payumoney.png", "PayU Money", 35, 130,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("payumoney");
                    openPayment(pgName: "payumoney");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* Instamojo */
        paymentProvider.paymentOptionModel.result?.instamojo != null
            ? paymentProvider
                        .paymentOptionModel.result?.instamojo?.visibility ==
                    "1"
                ? _buildPGButton("pg_instamojo.png", "Instamojo", 35, 130,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("instamojo");
                    openPayment(pgName: "instamojo");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* Stripe */
        paymentProvider.paymentOptionModel.result?.stripe != null
            ? paymentProvider.paymentOptionModel.result?.stripe?.visibility ==
                    "1"
                ? _buildPGButton("pg_stripe.png", "Stripe", 35, 70,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("stripe");
                    openPayment(pgName: "stripe");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* Paystack */
        paymentProvider.paymentOptionModel.result?.paystack != null
            ? paymentProvider.paymentOptionModel.result?.paystack?.visibility ==
                    "1"
                ? _buildPGButton("pg_paystack.png", "Paystack", 50, 100,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("paystack");
                    openPayment(pgName: "paystack");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),

        /* Cash */
        paymentProvider.paymentOptionModel.result?.cash != null
            ? paymentProvider.paymentOptionModel.result?.cash?.visibility == "1"
                ? _buildPGButton("pg_cash.png", "Cash", 40, 40,
                    onClick: () async {
                    paymentProvider.setCurrentPayment("cash");
                    openPayment(pgName: "cash");
                  })
                : const SizedBox.shrink()
            : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildPGButton(
      String imageName, String pgName, double imgHeight, double imgWidth,
      {required Function() onClick}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      child: Card(
        semanticContainer: true,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        elevation: 5,
        color: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onClick,
          child: Container(
            constraints: const BoxConstraints(minHeight: 85),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                MyImage(
                  imagePath: imageName,
                  fit: BoxFit.contain,
                  height: imgHeight,
                  width: imgWidth,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: MyText(
                    color: black,
                    text: pgName,
                    multilanguage: false,
                    fontsizeNormal: 14,
                    fontsizeWeb: 15,
                    maxline: 2,
                    overflow: TextOverflow.ellipsis,
                    fontweight: FontWeight.w600,
                    textalign: TextAlign.end,
                    fontstyle: FontStyle.normal,
                  ),
                ),
                const SizedBox(width: 15),
                MyImage(
                  imagePath: "ic_arrow_right.png",
                  fit: BoxFit.fill,
                  height: 22,
                  width: 20,
                  color: defaultIconColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ********* InApp purchase START ********* */
  Future<void> initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {});
      return;
    }

    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    final ProductDetailsResponse productDetailResponse =
        await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    if (productDetailResponse.error != null ||
        productDetailResponse.productDetails.isEmpty) {
      setState(() {});
      return;
    }
  }

  Future<void> _initInAppPurchase() async {
    LoadingOverlay().show(context); // Start Loading...
    printLog(
        "_initInAppPurchase _kProductIds ============> ${_kProductIds[0].toString()}");
    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails(_kProductIds.toSet());
    if (response.notFoundIDs.isNotEmpty) {
      LoadingOverlay().hide(); // Stop Loading...
      Utils.showToast("Please check SKU");
      return;
    }
    printLog("productID ============> ${response.productDetails[0].id}");
    late PurchaseParam purchaseParam;
    if (Platform.isAndroid) {
      purchaseParam =
          GooglePlayPurchaseParam(productDetails: response.productDetails[0]);
    } else {
      purchaseParam = PurchaseParam(productDetails: response.productDetails[0]);
    }
    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } on Exception catch (e) {
      printLog("_initInAppPurchase Exception ============> $e");
      LoadingOverlay().hide(); // Stop Loading...
      Utils.showToast(
          "Transaction was cancelled. No payment has been processed.");
    }
  }

  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    printLog(
        "_listenToPurchaseUpdated purchaseDetailsList ===> ${purchaseDetailsList.length}");
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      printLog(
          "_listenToPurchaseUpdated purchaseDetails status ===> ${purchaseDetails.status}");
      if (purchaseDetails.status == PurchaseStatus.pending) {
        showPendingUI();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          printLog(
              "_listenToPurchaseUpdated purchaseDetails ============> ${purchaseDetails.error.toString()}");
          handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            deliverProduct(purchaseDetails);
          } else {
            _handleInvalidPurchase(purchaseDetails);
            return;
          }
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          LoadingOverlay().hide(); // Stop Loading...
          if (!mounted) return;
          Utils.showSnackbar(context, "info", "payment_cancel", true);
        }
        if (Platform.isAndroid) {
          if (!_kAutoConsume && purchaseDetails.productID == _kProductIds[0]) {
            final InAppPurchaseAndroidPlatformAddition androidAddition =
                _inAppPurchase.getPlatformAddition<
                    InAppPurchaseAndroidPlatformAddition>();
            await androidAddition.consumePurchase(purchaseDetails);
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          printLog(
              "_listenToPurchaseUpdated pendingCompletePurchase ===> ${purchaseDetails.pendingCompletePurchase}");
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> deliverProduct(PurchaseDetails purchaseDetails) async {
    printLog("deliverProduct productID ===> ${purchaseDetails.productID}");
    LoadingOverlay().hide(); // Stop Loading...
    if (purchaseDetails.productID == _kProductIds[0]) {
      if (widget.payType == "Package") {
        addTransaction("inapp", paymentProvider.itemId,
            paymentProvider.itemTitle, widget.price, paymentProvider.paymentId);
      } else if (widget.payType == "Rent") {
        addRentTransaction("inapp", paymentProvider.itemId, widget.price,
            paymentProvider.typeId, paymentProvider.videoType);
      }
      setState(() {});
    } else {
      printLog("deliverProduct consumables else ===> $purchaseDetails");
      setState(() {
        _purchases.add(purchaseDetails);
      });
    }
  }

  void showPendingUI() {
    LoadingOverlay().hide(); // Stop Loading...
    setState(() {});
  }

  void handleError(IAPError error) {
    LoadingOverlay().hide(); // Stop Loading...
    setState(() {});
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) {
    return Future<bool>.value(true);
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {
    LoadingOverlay().hide(); // Stop Loading...
    printLog("invalid Purchase ===> $purchaseDetails");
  }
  /* ********* InApp purchase END ********* */

  /* ********* Razorpay START ********* */
  Future<void> _initializeRazorpay() async {
    if (paymentProvider.paymentOptionModel.result?.razorpay != null) {
      /* Check Keys */
      bool isContinue = checkKeysAndContinue(
        isLive:
            (paymentProvider.paymentOptionModel.result?.razorpay?.isLive ?? ""),
        isBothKeyReq: false,
        key1: (paymentProvider.paymentOptionModel.result?.razorpay?.key1 ?? ""),
        key2: "",
      );
      if (!isContinue) return;

      /* Check Keys */
      Map<String, dynamic>? orderResponse;
      if (!kIsWeb) {
        orderResponse = await createRazorpayOrder(
            amount: paymentProvider.finalAmount ?? "",
            currency: Constant.currency,
            apiKeyId:
                (paymentProvider.paymentOptionModel.result?.razorpay?.key1 ??
                    ""),
            secretKey:
                (paymentProvider.paymentOptionModel.result?.razorpay?.key2 ??
                    ""));
        printLog('Razorpay orderResponse :==> $orderResponse');
        printLog('Razorpay amount_due :=====> ${orderResponse?["amount_due"]}');
        printLog('Razorpay id :=============> ${orderResponse?["id"]}');

        if (orderResponse != null) {
          payByRazorpay(orderResponse: orderResponse);
        } else {
          printLog('Razorpay Keys NOT FOUND!');
          if (!mounted) return;
          Utils.showSnackbar(context, "", "payment_not_processed", true);
        }
      } else {
        payByRazorpay();
      }
    } else {
      Utils.showSnackbar(context, "", "payment_not_processed", true);
    }
  }

  Future payByRazorpay({dynamic orderResponse}) async {
    var options = {
      'key': (paymentProvider.paymentOptionModel.result?.razorpay?.key1 ?? ""),
      'currency': Constant.currency,
      'order_id': orderResponse["id"],
      'amount': orderResponse["amount_due"],
      'name': widget.itemTitle ?? "",
      'description': widget.itemTitle ?? "",
      'send_sms_hash': true,
      'prefill': {'contact': userMobileNo, 'email': userEmail},
      'external': {
        'wallets': ['paytm']
      }
    };
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentErrorResponse);
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccessResponse);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWalletSelected);

    try {
      razorpay.open(options);
    } catch (e) {
      printLog('Razorpay Error :=========> $e');
    }
  }

  Future createRazorpayOrder({
    required String amount,
    required String currency,
    required String apiKeyId,
    required String secretKey,
  }) async {
    try {
      final String basicAuth =
          'Basic ${base64Encode(utf8.encode('$apiKeyId:$secretKey'))}';

      final Map<String, dynamic> body = {
        'amount': (double.parse(amount) * 100).toInt(),
        'currency': currency,
        'receipt': 'receipt#${paymentProvider.itemTitle}',
        'payment_capture': 1,
      };

      final http.Response response = await http.post(
        Uri.parse('https://api.razorpay.com/v1/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        printLog('Failed to create Razorpay order : ${response.body}');
      }
    } on Exception catch (e) {
      printLog('Create Razorpay order Exception : $e');
    }
  }

  void handlePaymentErrorResponse(PaymentFailureResponse response) async {
    /*
    * PaymentFailureResponse contains three values:
    * 1. Error Code
    * 2. Error Description
    * 3. Metadata
    * */
    Utils.showSnackbar(context, "fail", "payment_fail", true);
    paymentProvider.setCurrentPayment("");
  }

  void handlePaymentSuccessResponse(PaymentSuccessResponse response) {
    /*
    * Payment Success Response contains three values:
    * 1. Order ID
    * 2. Payment ID
    * 3. Signature
    * */
    paymentProvider.paymentId = response.paymentId.toString();
    printLog("paymentId ========> ${paymentProvider.paymentId}");
    Utils.showSnackbar(context, "success", "payment_success", true);
    if (widget.payType == "Package") {
      addTransaction(
          "razorpay",
          paymentProvider.itemId,
          paymentProvider.itemTitle,
          paymentProvider.finalAmount,
          paymentProvider.paymentId);
    } else if (widget.payType == "Rent") {
      addRentTransaction(
          "razorpay",
          paymentProvider.itemId,
          paymentProvider.finalAmount,
          paymentProvider.typeId,
          paymentProvider.videoType);
    }
  }

  void handleExternalWalletSelected(ExternalWalletResponse response) {
    printLog("============ External Wallet Selected ============");
  }
  /* ********* Razorpay END ********* */

  /* ********* Paytm START ********* */
  Future<void> _paytmInit() async {
    if (paymentProvider.paymentOptionModel.result?.payTm != null) {
      /* Check Keys */
      bool isContinue = checkKeysAndContinue(
        isLive:
            (paymentProvider.paymentOptionModel.result?.payTm?.isLive ?? ""),
        isBothKeyReq: false,
        key1: (paymentProvider.paymentOptionModel.result?.payTm?.key1 ?? ""),
        key2: "",
      );
      if (!isContinue) return;
      /* Check Keys */

      bool payTmIsStaging;
      String payTmMerchantID,
          payTmOrderId,
          payTmCustmoreID,
          payTmChannelID,
          payTmTxnAmount,
          payTmWebsite,
          payTmCallbackURL,
          payTmIndustryTypeID;

      payTmOrderId = paymentProvider.paymentId ?? "";
      payTmCustmoreID = "${Constant.userID}_${paymentProvider.paymentId}";
      payTmChannelID = "WAP";
      payTmTxnAmount = "${(paymentProvider.finalAmount ?? "")}.00";
      payTmIndustryTypeID = "Retail";

      if (paymentProvider.paymentOptionModel.result?.payTm?.isLive == "1") {
        payTmMerchantID =
            paymentProvider.paymentOptionModel.result?.payTm?.key1 ?? "";
        payTmIsStaging = false;
        payTmWebsite = "DEFAULT";
        payTmCallbackURL =
            "https://secure.paytmpayments.com/theia/paytmCallback?ORDER_ID=$payTmOrderId";
      } else {
        payTmMerchantID =
            paymentProvider.paymentOptionModel.result?.payTm?.key4 ?? "";
        payTmIsStaging = true;
        payTmWebsite = "WEBSTAGING";
        payTmCallbackURL =
            "https://securestage.paytmpayments.com/theia/paytmCallback?ORDER_ID=$payTmOrderId";
      }
      var sendMap = <String, dynamic>{
        "mid": payTmMerchantID,
        "orderId": payTmOrderId,
        "amount": payTmTxnAmount,
        "txnToken": paymentProvider.payTmModel.result?.paytmChecksum ?? "",
        "callbackUrl": payTmCallbackURL,
        "isStaging": payTmIsStaging,
        "restrictAppInvoke": true,
        "enableAssist": true,
      };
      printLog("sendMap ===> $sendMap");

      /* Generate CheckSum from Backend */
      await paymentProvider.getPaytmToken(
        payTmMerchantID,
        payTmOrderId,
        payTmCustmoreID,
        payTmChannelID,
        payTmTxnAmount,
        payTmWebsite,
        payTmCallbackURL,
        payTmIndustryTypeID,
      );

      if (!paymentProvider.loading) {
        if (paymentProvider.payTmModel.result != null) {
          if (paymentProvider.payTmModel.result?.paytmChecksum != null) {
            try {
              var response = PaytmPaymentsAllinonesdk().startTransaction(
                payTmMerchantID,
                payTmOrderId,
                payTmTxnAmount,
                paymentProvider.payTmModel.result?.paytmChecksum ?? "",
                payTmCallbackURL,
                payTmIsStaging,
                true,
                true,
              );
              response.then((value) {
                printLog("value ====> $value");
                setState(() {
                  paytmResult = value.toString();
                });
              }).catchError((onError) {
                if (onError is PlatformException) {
                  setState(() {
                    paytmResult = "${onError.message} \n  ${onError.details}";
                  });
                } else {
                  setState(() {
                    paytmResult = onError.toString();
                  });
                }
              });
            } catch (err) {
              paytmResult = err.toString();
            }
          } else {
            if (!mounted) return;
            Utils.showSnackbar(context, "", "payment_not_processed", true);
          }
        } else {
          if (!mounted) return;
          Utils.showSnackbar(context, "", "payment_not_processed", true);
        }
      }
    } else {
      Utils.showSnackbar(context, "", "payment_not_processed", true);
    }
  }
  /* ********* Paytm END *********** */

  /* ********* Paypal START ********* */
  Future<void> _paypalInit() async {
    if (paymentProvider.paymentOptionModel.result?.paypal != null) {
      /* Check Keys */
      bool isContinue = checkKeysAndContinue(
        isLive:
            (paymentProvider.paymentOptionModel.result?.paypal?.isLive ?? ""),
        isBothKeyReq: true,
        key1: (paymentProvider.paymentOptionModel.result?.paypal?.key1 ?? ""),
        key2: (paymentProvider.paymentOptionModel.result?.paypal?.key2 ?? ""),
      );
      if (!isContinue) return;
      /* Check Keys */

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => UsePaypal(
              sandboxMode:
                  (paymentProvider.paymentOptionModel.result?.paypal?.isLive ??
                              "") ==
                          "1"
                      ? false
                      : true,
              clientId:
                  paymentProvider.paymentOptionModel.result?.paypal?.key1 ?? "",
              secretKey:
                  paymentProvider.paymentOptionModel.result?.paypal?.key2 ?? "",
              returnURL: "return.example.com",
              cancelURL: "cancel.example.com",
              transactions: [
                {
                  "amount": {
                    "total": '${paymentProvider.finalAmount}',
                    "currency": Constant.currency,
                    "details": {
                      "subtotal": '${paymentProvider.finalAmount}',
                      "shipping": '0',
                      "shipping_discount": 0
                    }
                  },
                  "description": widget.payType ?? "",
                  "item_list": {
                    "items": [
                      {
                        "name": "${widget.itemTitle}",
                        "quantity": 1,
                        "price": '${paymentProvider.finalAmount}',
                        "currency": Constant.currency
                      }
                    ],
                  }
                }
              ],
              note: "Contact us for any questions on your order.",
              onSuccess: (params) async {
                printLog("onSuccess: ${params["paymentId"]}");
                if (widget.payType == "Package") {
                  addTransaction(
                      "paypal",
                      paymentProvider.itemId,
                      paymentProvider.itemTitle,
                      paymentProvider.finalAmount,
                      params["paymentId"]);
                } else if (widget.payType == "Rent") {
                  addRentTransaction(
                      "paypal",
                      paymentProvider.itemId,
                      paymentProvider.finalAmount,
                      paymentProvider.typeId,
                      paymentProvider.videoType);
                }
              },
              onError: (params) {
                printLog("onError: ${params["message"]}");
                Utils.showSnackbar(
                    context, "fail", params["message"].toString(), false);
              },
              onCancel: (params) {
                printLog('cancelled: $params');
                Utils.showSnackbar(context, "fail", params.toString(), false);
              }),
        ),
      );
    } else {
      Utils.showSnackbar(context, "", "payment_not_processed", true);
    }
  }
  /* ********* Paypal END *********** */

  /* ********* Stripe START ********* */
  Future createCustomer() async {
    try {
      var body = {
        "email": userEmail,
        "name": userName,
        "phone": userMobileNo,
      };

      //final response  = await http.post(Uri.parse("https://api.stripe.com/v1/customers"),
      final response = await http.post(
        Uri.parse("https://api.stripe.com/v1/customers"),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Authorization":
              "Bearer ${paymentProvider.paymentOptionModel.result?.stripe?.key2}",
        },
        body: body,
      );
      printLog('createCustomer jsonDecode :=> ${jsonDecode(response.body)}');
      return jsonDecode(response.body);
    } catch (err) {
      printLog('createCustomer Error :=> ${err.toString()}');
      return null;
    }
  }

  Future<void> _stripeInit() async {
    if (paymentProvider.paymentOptionModel.result?.stripe != null) {
      /* Check Keys */
      bool isContinue = checkKeysAndContinue(
        isLive:
            (paymentProvider.paymentOptionModel.result?.stripe?.isLive ?? ""),
        isBothKeyReq: true,
        key1: (paymentProvider.paymentOptionModel.result?.stripe?.key1 ?? ""),
        key2: (paymentProvider.paymentOptionModel.result?.stripe?.key2 ?? ""),
      );
      if (!isContinue) return;
      /* Check Keys */

      stripe.Stripe.publishableKey =
          paymentProvider.paymentOptionModel.result?.stripe?.key1 ?? "";

      if (kIsWeb) {
        /* ******* INITIALIZE VALUES ******* */
        Constant.publishableKey =
            (paymentProvider.paymentOptionModel.result?.stripe?.key1 ?? "");
        Constant.secretKey =
            (paymentProvider.paymentOptionModel.result?.stripe?.key2 ?? "");
        Constant.packagePriceId = paymentProvider.productPackage ?? "";
        Constant.successURL = '${Constant.webDomainURL}#/success';
        Constant.cancelURL = '${Constant.webDomainURL}#/cancel';
        printLog("publishableKey ==> ${Constant.publishableKey}");
        printLog("secretKey =======> ${Constant.secretKey}");
        printLog("packagePriceId ==> ${Constant.packagePriceId}");
        printLog("successURL ======> ${Constant.successURL}");
        printLog("cancelURL =======> ${Constant.cancelURL}");
        /* ******* INITIALIZE VALUES ******* */

        redirectToCheckout(context);
      } else {
        try {
          final customerData = await createCustomer();
          printLog("customerData =====> $customerData");

          //STEP 1: Create Payment Intent
          paymentIntent = await createPaymentIntent(
              paymentProvider.finalAmount ?? "", Constant.currency);

          //STEP 2: Initialize Payment Sheet
          await stripe.Stripe.instance
              .initPaymentSheet(
                  paymentSheetParameters: stripe.SetupPaymentSheetParameters(
                billingDetailsCollectionConfiguration:
                    const stripe.BillingDetailsCollectionConfiguration(
                  attachDefaultsToPaymentMethod: true,
                  address: stripe.AddressCollectionMode.automatic,
                  name: stripe.CollectionMode.always,
                  email: stripe.CollectionMode.always,
                  phone: stripe.CollectionMode.always,
                ),
                paymentIntentClientSecret: paymentIntent?['client_secret'],
                style: ThemeMode.light,
                merchantDisplayName: Constant.appName,
                customerId: customerData['id'],
                billingDetails: stripe.BillingDetails(
                  email: userEmail,
                  phone: userMobileNo,
                  name: userName,
                ),
              ))
              .then((value) {});

          //STEP 3: Display Payment sheet
          displayPaymentSheet();
        } catch (err) {
          printLog("_stripeInit Error =====> ${err.toString()}");
          throw Exception(err);
        }
      }
    } else {
      Utils.showSnackbar(context, "", "payment_not_processed", true);
    }
  }

  Future createPaymentIntent(String amount, String currency) async {
    try {
      //Request body
      Map<String, dynamic> body = {
        'amount': calculateAmount(amount),
        'currency': currency,
        'description': paymentProvider.itemTitle,
      };

      //Make post request to Stripe
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization':
              'Bearer ${paymentProvider.paymentOptionModel.result?.stripe?.key2 ?? ""}',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body,
      );
      return json.decode(response.body);
    } catch (err) {
      throw Exception(err.toString());
    }
  }

  String calculateAmount(String amount) {
    final calculatedAmout = (double.parse(amount)) * 100;
    return calculatedAmout.toString();
  }

  Future<void> displayPaymentSheet() async {
    try {
      await stripe.Stripe.instance.presentPaymentSheet().then((value) {
        if (!mounted) return;
        Utils.showSnackbar(context, "success", "payment_success", true);
        if (paymentProvider.payType == "Package") {
          addTransaction(
              "stripe",
              paymentProvider.itemId,
              paymentProvider.itemTitle,
              paymentProvider.finalAmount,
              paymentProvider.paymentId);
        } else if (paymentProvider.payType == "Rent") {
          addRentTransaction(
              "stripe",
              paymentProvider.itemId,
              paymentProvider.finalAmount,
              paymentProvider.typeId,
              paymentProvider.videoType);
        }

        paymentIntent = null;
      }).onError((error, stackTrace) {
        throw Exception(error);
      });
    } on stripe.StripeException catch (e) {
      printLog('Error is:---> $e');
      if (!mounted) return;
      Utils.showSnackbar(context, "fail", "payment_fail", true);
    } catch (e) {
      printLog('$e');
    }
  }
  /* ********* Stripe END ********* */

  /* ********* Flutterwave START ********* */
  Future<void> _flutterwaveInit() async {
    /* Check Keys */
    bool isContinue = checkKeysAndContinue(
      isLive:
          paymentProvider.paymentOptionModel.result?.flutterWave?.isLive ?? "",
      isBothKeyReq: false,
      key1: paymentProvider.paymentOptionModel.result?.flutterWave?.key1 ?? "",
      key2: "",
    );
    if (!isContinue) return;
    /* Check Keys */

    final Customer customer = Customer(
        email: userEmail ?? "",
        name: userName ?? "",
        phoneNumber: userMobileNo ?? '');

    final Flutterwave flutterwave = Flutterwave(
      context: context,
      publicKey:
          paymentProvider.paymentOptionModel.result?.flutterWave?.key1 ?? "",
      currency: Constant.currency,
      redirectUrl: 'https://www.divinetechs.com',
      txRef: const Uuid().v1(),
      amount: paymentProvider.finalAmount.toString().trim(),
      customer: customer,
      paymentOptions: "card, payattitude, barter, bank transfer, ussd",
      customization: Customization(title: widget.itemTitle),
      isTestMode:
          paymentProvider.paymentOptionModel.result?.flutterWave?.isLive != "1",
    );
    ChargeResponse? response = await flutterwave.charge();
    printLog("Flutterwave response =====> ${response.toJson()}");
    if ((response.status == "success" ||
            response.status == "successful" ||
            (response.status ?? "").contains("success")) &&
        response.success == true) {
      paymentProvider.paymentId = response.transactionId.toString();
      printLog("paymentId ========> ${paymentProvider.paymentId}");
      if (!mounted) return;
      Utils.showSnackbar(context, "success", "payment_success", true);

      if (widget.payType == "Package") {
        addTransaction(
            "flutterwave",
            paymentProvider.itemId,
            paymentProvider.itemTitle,
            paymentProvider.finalAmount,
            paymentProvider.paymentId);
      } else if (widget.payType == "Rent") {
        addRentTransaction(
            "flutterwave",
            paymentProvider.itemId,
            paymentProvider.finalAmount,
            paymentProvider.typeId,
            paymentProvider.videoType);
      }
    } else if (response.status == "cancel" && response.status == "cancelled") {
      if (!mounted) return;
      Utils.showSnackbar(context, "info", "payment_cancel", true);
    } else {
      if (!mounted) return;
      Utils.showSnackbar(context, "fail", "payment_fail", true);
    }
  }
  /* ********* Flutterwave END ********* */

  /* ********* PayUMoney START ********* */
  Future<void> _payUMoneyInit() async {
    printLog(
        "_payUMoneyInit isLive ======> ${paymentProvider.paymentOptionModel.result?.payUMoney?.isLive}");
    /* Check Keys */
    bool isContinue = checkKeysAndContinue(
      isLive:
          (paymentProvider.paymentOptionModel.result?.payUMoney?.isLive ?? ""),
      isBothKeyReq: false,
      key1: (paymentProvider.paymentOptionModel.result?.payUMoney?.key3 ?? ""),
      key2: (paymentProvider.paymentOptionModel.result?.payUMoney?.key2 ?? ""),
    );
    if (!isContinue) return;
    /* Check Keys */

    Map<dynamic, dynamic> additionalParam = {
      PayUAdditionalParamKeys.udf1: "udf1",
      PayUAdditionalParamKeys.udf2: "udf2",
      PayUAdditionalParamKeys.udf3: "udf3",
      PayUAdditionalParamKeys.udf4: "udf4",
      PayUAdditionalParamKeys.udf5: "udf5",
    };

    Map<dynamic, dynamic> payUPaymentParams = {
      PayUPaymentParamKey.key:
          (paymentProvider.paymentOptionModel.result?.payUMoney?.key2 ?? ""),
      PayUPaymentParamKey.transactionId: paymentProvider.paymentId ?? "",
      PayUPaymentParamKey.amount: double.parse(widget.price ?? "0").toString(),
      PayUPaymentParamKey.productInfo: widget.itemTitle ?? "",
      PayUPaymentParamKey.firstName: userName ?? "",
      PayUPaymentParamKey.email: userEmail ?? "",
      PayUPaymentParamKey.phone: userMobileNo ?? "",
      PayUPaymentParamKey.ios_surl: "https://payu.herokuapp.com/ios_success",
      PayUPaymentParamKey.ios_furl: "https://payu.herokuapp.com/ios_failure",
      PayUPaymentParamKey.android_surl: "https://payu.herokuapp.com/success",
      PayUPaymentParamKey.android_furl: "https://payu.herokuapp.com/failure",
      PayUPaymentParamKey.environment:
          (paymentProvider.paymentOptionModel.result?.payUMoney?.isLive == "1")
              ? "0"
              : "1", //0 => Production, 1 => Test
      PayUPaymentParamKey.additionalParam: additionalParam,
      PayUPaymentParamKey.userCredential:
          ('${paymentProvider.paymentOptionModel.result?.payUMoney?.key2}:${userEmail ?? ""}')
    };
    printLog("_payUMoneyInit Params ======> ${payUPaymentParams.toString()}");

    try {
      _payUCheckoutPro.openCheckoutScreen(
        payUPaymentParams: payUPaymentParams,
        payUCheckoutProConfig: PayUParams.createPayUConfigParams(),
      );
    } on Exception catch (e) {
      printLog("_payUMoneyInit Exception ======> ${e.toString()}");
    }
  }

  @override
  generateHash(Map response) {
    // Pass response param to your backend server
    // Backend will generate the hash and will callback to
    Map<dynamic, dynamic> hashResponse = PayUHashService((paymentProvider
                    .paymentOptionModel.result?.payUMoney?.isLive ==
                "1")
            ? (paymentProvider.paymentOptionModel.result?.payUMoney?.key3 ?? "")
            : (paymentProvider.paymentOptionModel.result?.payUMoney?.key3 ??
                ""))
        .generateHash(response);
    printLog("hashResponse =====> $hashResponse");
    _payUCheckoutPro.hashGenerated(hash: hashResponse);
  }

  @override
  onError(Map? response) {
    printLog("onError response ======> $response");
    if (!mounted) return;
    Utils.showToast(Locales.string(context, "payment_fail"));
  }

  @override
  onPaymentCancel(Map? response) {
    printLog("onPaymentCancel response ======> $response");
    if (!mounted) return;
    Utils.showToast(Locales.string(context, "payment_cancel"));
  }

  @override
  onPaymentFailure(response) {
    printLog("onPaymentFailure response ======> $response");
    if (!mounted) return;
    Utils.showToast(Locales.string(context, "payment_fail"));
  }

  @override
  onPaymentSuccess(response) {
    printLog("onPaymentSuccess response ======> $response");
    if (!mounted) return;
    Utils.showToast(Locales.string(context, "payment_success"));

    if (widget.payType == "Package") {
      addTransaction("payumoney", widget.itemId, widget.itemTitle,
          paymentProvider.finalAmount, paymentProvider.paymentId);
    } else if (widget.payType == "Rent") {
      addRentTransaction("payumoney", widget.itemId,
          paymentProvider.finalAmount, widget.typeId, widget.videoType);
    }
  }
  /* ********** PayUMoney END ********** */

  /* ********* Paystack START ********* */
  Future<void> _paystackInit() async {
    /* Check Keys */
    bool isContinue = checkKeysAndContinue(
      isLive:
          (paymentProvider.paymentOptionModel.result?.paystack?.isLive ?? ""),
      isBothKeyReq: false,
      key1: (paymentProvider.paymentOptionModel.result?.paystack?.key1 ?? ""),
      key2: (paymentProvider.paymentOptionModel.result?.paystack?.key2 ?? ""),
    );
    if (!isContinue) return;
    /* Check Keys */

    printLog("_paystackInit finalAmount ==> ${paymentProvider.finalAmount}");
    printLog("_paystackInit currency =====> ${Constant.currency}");
    PayWithPayStack().now(
      context: context,
      customerEmail: userEmail ?? "",
      reference: DateTime.now().microsecondsSinceEpoch.toString(),
      currency: Constant.currency,
      amount: double.parse(paymentProvider.finalAmount ?? "0") * 100,
      secretKey: (paymentProvider.paymentOptionModel.result?.paystack?.isLive ==
              "1")
          ? (paymentProvider.paymentOptionModel.result?.paystack?.key1 ?? "")
          : (paymentProvider.paymentOptionModel.result?.paystack?.key4 ?? ""),
      transactionCompleted: (paymentData) async {
        printLog("Transaction Successful => ${paymentData.gatewayResponse}");
        printLog("paymentId ========> ${paymentProvider.paymentId}");

        if (!mounted) return;
        Utils.showSnackbar(context, "success", "payment_success", true);

        if (widget.payType == "Package") {
          await addTransaction(
              "paystack",
              paymentProvider.itemId,
              paymentProvider.itemTitle,
              paymentProvider.finalAmount,
              paymentProvider.paymentId);
        } else if (widget.payType == "Rent") {
          await addRentTransaction(
              "paystack",
              paymentProvider.itemId,
              paymentProvider.finalAmount,
              paymentProvider.typeId,
              paymentProvider.videoType);
        }
      },
      transactionNotCompleted: (transaction) {
        printLog("Transaction Not Successful! $transaction");
        if (!mounted) return;
        Utils.showSnackbar(context, "fail", "payment_fail", true);
      },
      callbackUrl: 'https://dtlive.divinetechs.in/',
    );
  }
  /* ********* Paystack END ********* */

  /* ********* Instamojo START ********* */
  Future<void> _initInstamojo() async {
    /* Check Keys */
    bool isContinue = checkKeysAndContinue(
      isLive:
          (paymentProvider.paymentOptionModel.result?.instamojo?.isLive ?? ""),
      isBothKeyReq: false,
      key1: (paymentProvider.paymentOptionModel.result?.instamojo?.key1 ?? ""),
      key2: (paymentProvider.paymentOptionModel.result?.instamojo?.key2 ?? ""),
    );
    if (!isContinue) return;
    /* Check Keys */

    String apiKey =
        paymentProvider.paymentOptionModel.result?.instamojo?.key1 ?? "";
    String authToken =
        paymentProvider.paymentOptionModel.result?.instamojo?.key2 ?? "";
    String requestURL =
        ((paymentProvider.paymentOptionModel.result?.instamojo?.isLive ?? "") ==
                "1")
            ? 'https://www.instamojo.com/api/1.1/payment-requests/'
            : 'https://test.instamojo.com/api/1.1/payment-requests/';
    printLog("_initInstamojo apiKey =========> $apiKey");
    printLog("_initInstamojo authToken ======> $authToken");
    printLog("_initInstamojo requestURL =====> $requestURL");

    final Map<String, dynamic> orderData = {
      'amount': double.parse(paymentProvider.finalAmount ?? '0')
          .toString(), // Amount in INR
      'purpose': widget.payType ?? '',
      'buyer_name': userName ?? '',
      'email': userEmail ?? '',
      'phone': userMobileNo ?? '',
      'currency': Constant.currency,
      'send_email': 'False',
      'send_sms': 'False',
      'allow_repeated_payments': 'False',
    };

    final response = await http.post(
      Uri.parse(requestURL),
      headers: {
        "Accept": "application/json",
        'Content-Type': 'application/x-www-form-urlencoded',
        "X-Api-Key": apiKey,
        "X-Auth-Token": authToken,
      },
      body: orderData,
    );

    printLog('createInstamojoOrder statusCode : ${response.statusCode}');
    if (response.statusCode == 201) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final String paymentUrl = responseData['payment_request']['longurl'];
      final String paymentReqID = responseData['payment_request']['id'];

      // Now you can open this payment URL in a WebView or a browser
      printLog('Payment URL : $paymentUrl');
      printLog('Payment ID  : $paymentReqID');
      if (!mounted) return;
      dynamic result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => InstamojoPG(
            paymentUrl: paymentUrl,
            paymentId: paymentReqID,
          ),
        ),
      );

      printLog("result =====> $result");
      printLog("paymentReqID =====> $paymentReqID");
      if (result != null && result == true) {
        _checkPaymentStatus(paymentReqID);
      }
    } else {
      // Handle error
      printLog('Failed to create Instamojo order');
      if (!mounted) return;
      Utils.showSnackbar(context, "fail", "payment_not_processed", true);
    }
  }

  Future<void> _checkPaymentStatus(String id) async {
    printLog("_checkPaymentStatus id =========> $id");
    String apiKey =
        paymentProvider.paymentOptionModel.result?.instamojo?.key1 ?? "";
    String authToken =
        paymentProvider.paymentOptionModel.result?.instamojo?.key2 ?? "";
    String requestURL =
        ((paymentProvider.paymentOptionModel.result?.instamojo?.isLive ?? "") ==
                "1")
            ? 'https://www.instamojo.com/api/1.1/payment-requests/'
            : 'https://test.instamojo.com/api/1.1/payment-requests/';
    printLog("_checkPaymentStatus apiKey =========> $apiKey");
    printLog("_checkPaymentStatus authToken ======> $authToken");
    printLog("_checkPaymentStatus requestURL =====> $requestURL");

    final response = await http.get(
      Uri.parse('$requestURL$id/'),
      headers: {
        "Accept": "application/json",
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-Api-Key': apiKey,
        'X-Auth-Token': authToken,
      },
    );

    printLog('createInstamojoOrder statusCode : ${response.statusCode}');
    final Map<String, dynamic> realResponse = json.decode(response.body);
    if (realResponse['success'] == true) {
      if (realResponse["payment_request"]['payments'] != null) {
        List<dynamic> myPayments = [];
        myPayments = realResponse["payment_request"]['payments'];
        if (myPayments.isNotEmpty) {
          if (myPayments[0]['status'] == "Credit") {
            paymentProvider.paymentId = myPayments[0]['payment_id'];
            printLog(
                'createInstamojoOrder paymentId : ${paymentProvider.paymentId}');

            if (!mounted) return;
            Utils.showSnackbar(context, "success", "payment_success", true);

            if (widget.payType == "Package") {
              await addTransaction(
                  "instamojo",
                  paymentProvider.itemId,
                  paymentProvider.itemTitle,
                  paymentProvider.finalAmount,
                  paymentProvider.paymentId);
            } else if (widget.payType == "Rent") {
              await addRentTransaction(
                  "instamojo",
                  paymentProvider.itemId,
                  paymentProvider.finalAmount,
                  paymentProvider.typeId,
                  paymentProvider.videoType);
            }
            printLog("PAYMENT STATUS SUCCESS");
            //payment is successful.
          } else {
            printLog("PAYMENT STATUS PENDING");
            if (!mounted) return;
            Utils.showSnackbar(context, "info", "payment_cancel", true);
            //payment failed or pending.
          }
        } else {
          printLog("PAYMENT STATUS PENDING");
          if (!mounted) return;
          Utils.showSnackbar(context, "info", "payment_cancel", true);
          //payment failed or pending.
        }
      } else {
        printLog("PAYMENT STATUS PENDING");
        if (!mounted) return;
        Utils.showSnackbar(context, "info", "payment_cancel", true);
        //payment failed or pending.
      }
    } else {
      printLog("PAYMENT STATUS FAILED");
      if (!mounted) return;
      Utils.showSnackbar(context, "fail", "payment_fail", true);
      //payment failed.
    }
  }
  /* ********* Instamojo END ********* */

  Future<void> onBackPressed(bool didPop) async {
    if (didPop) return;
    if (kIsWeb) {
      if (context.canPop()) {
        context.pop(isPaymentDone);
      }
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, isPaymentDone);
      }
    }
  }
}

class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}

class SuccessPage extends StatefulWidget {
  const SuccessPage({super.key});

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> {
  SharedPre sharedPref = SharedPre();
  late PaymentProvider paymentProvider;

  @override
  void initState() {
    super.initState();
    paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String? payType = await sharedPref.read("payType");
      String? itemId = await sharedPref.read("itemId");
      String? price = await sharedPref.read("price");
      String? itemTitle = await sharedPref.read("itemTitle");
      String? typeId = await sharedPref.read("typeId");
      String? videoType = await sharedPref.read("videoType");
      String? productPackage = await sharedPref.read("productPackage");
      String? currency = await sharedPref.read("currency");
      String? paymentId = await sharedPref.read("paymentId");

      /* Save Params */
      await paymentProvider.setCurrentPayParams(
        payType: payType ?? "",
        itemId: itemId ?? "",
        price: price ?? "",
        itemTitle: itemTitle ?? "",
        typeId: typeId ?? "",
        videoType: videoType ?? "",
        productPackage: productPackage ?? "",
        currency: currency ?? "",
        paymentId: paymentId ?? "",
      );
      printLog('_getData payType =========> ${paymentProvider.payType}');
      printLog('_getData itemId ==========> ${paymentProvider.itemId}');
      printLog('_getData finalAmount =====> ${paymentProvider.finalAmount}');
      printLog('_getData itemTitle =======> ${paymentProvider.itemTitle}');
      printLog('_getData typeId ==========> ${paymentProvider.typeId}');
      printLog('_getData videoType =======> ${paymentProvider.videoType}');
      printLog('_getData productPackage ==> ${paymentProvider.productPackage}');
      printLog('_getData currency ========> ${paymentProvider.currency}');
      printLog('_getData paymentId =======> ${paymentProvider.paymentId}');
      Future.delayed(const Duration(milliseconds: 500)).then((value) {
        if (!mounted) return;
        _redirectTo();
      });
    });
  }

  Future<void> _redirectTo() async {
    if (!(context.mounted)) return;
    Utils.clearPayParams();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    }
    context.pushReplacementNamed(
      RoutesConstant.paymentPage,
      extra: {
        'newpage': RoutesConstant.subscriptionPage,
        'paytype': paymentProvider.payType,
        'itemid': paymentProvider.itemId,
        'producerid': paymentProvider.producerId,
        'price': paymentProvider.finalAmount,
        'title': paymentProvider.itemTitle,
        'videotype': paymentProvider.videoType,
        'subvideotype': paymentProvider.subVideoType,
        'typeid': paymentProvider.typeId,
        'currency': paymentProvider.currency,
        'productpackage': paymentProvider.productPackage
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MyText(
          color: greenColor,
          text: "Payment Successful.",
          multilanguage: false,
          fontsizeNormal: 30,
          fontsizeWeb: 40,
          maxline: 1,
          overflow: TextOverflow.ellipsis,
          fontweight: FontWeight.w700,
          textalign: TextAlign.center,
          fontstyle: FontStyle.normal,
        ),
      ),
    );
  }
}

class CancelPage extends StatefulWidget {
  const CancelPage({super.key});

  @override
  State<CancelPage> createState() => _CancelPageState();
}

class _CancelPageState extends State<CancelPage> {
  late PaymentProvider paymentProvider;
  @override
  void initState() {
    super.initState();
    paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500)).then((value) {
        if (!mounted) return;
        _redirectTo();
      });
    });
  }

  Future<void> _redirectTo() async {
    Utils.clearPayParams();
    paymentProvider.clearProvider();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    }
    context.go(
      "/${RoutesConstant.subscriptionPage}",
      extra: RoutesConstant.paymentPage,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: MyText(
          color: redColor,
          text: "Payment Cancelled.",
          multilanguage: false,
          fontsizeNormal: 30,
          fontsizeWeb: 40,
          maxline: 1,
          overflow: TextOverflow.ellipsis,
          fontweight: FontWeight.w700,
          textalign: TextAlign.center,
          fontstyle: FontStyle.normal,
        ),
      ),
    );
  }
}
