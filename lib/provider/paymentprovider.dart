import '../utils/utils.dart';
import '../model/couponmodel.dart';
import '../model/paymentoptionmodel.dart';
import '../model/paytmmodel.dart';
import '../model/successmodel.dart';
import '../utils/constant.dart';
import '../webservice/apiservices.dart';
import 'package:flutter/material.dart';

class PaymentProvider extends ChangeNotifier {
  PaymentOptionModel paymentOptionModel = PaymentOptionModel();
  PayTmModel payTmModel = PayTmModel();
  SuccessModel successModel = SuccessModel();
  CouponModel couponModel = CouponModel();

  bool loading = false, payLoading = false, couponLoading = false;
  String? currentPayment = "", finalAmount = "";

  /* Current Payment Params */
  String? payType,
      itemId,
      producerId,
      itemTitle,
      typeId,
      videoType,
      subVideoType,
      productPackage,
      currency,
      paymentId;
  /* Current Payment Parameters */

  Future<void> setLoading(bool loading) async {
    this.loading = loading;
    notifyListeners();
  }

  Future<void> setCurrentPayParams({
    required String payType,
    required String itemId,
    required String price,
    required String itemTitle,
    required String typeId,
    required String videoType,
    required String productPackage,
    required String currency,
    required String paymentId,
  }) async {
    this.payType = payType;
    this.itemId = itemId;
    finalAmount = price;
    this.itemTitle = itemTitle;
    this.typeId = typeId;
    this.videoType = videoType;
    this.productPackage = productPackage;
    this.currency = currency;
    this.paymentId = paymentId;

    Utils.savePayParams(
      payType: payType,
      itemId: itemId,
      price: price,
      itemTitle: itemTitle,
      typeId: typeId,
      videoType: videoType,
      productPackage: productPackage,
      currency: currency,
      paymentId: paymentId,
    );
    notifyListeners();
  }

  Future<void> getPaymentOption() async {
    loading = true;
    paymentOptionModel = await ApiService().getPaymentOption();
    printLog("getPaymentOption status :==> ${paymentOptionModel.status}");
    printLog("getPaymentOption message :==> ${paymentOptionModel.message}");
    loading = false;
    notifyListeners();
  }

  Future<void> applyPackageCouponCode(dynamic couponCode, packageId) async {
    printLog("applyPackageCouponCode couponCode :==> $couponCode");
    printLog("applyPackageCouponCode packageId :==> $packageId");
    couponLoading = true;
    couponModel = await ApiService().applyPackageCoupon(couponCode, packageId);
    printLog("applyPackageCouponCode status :==> ${couponModel.status}");
    printLog("applyPackageCouponCode message :==> ${couponModel.message}");
    couponLoading = false;
    notifyListeners();
  }

  Future<void> applyRentCouponCode(
      dynamic couponCode, videoId, typeId, videoType, price) async {
    printLog("applyRentCouponCode couponCode :==> $couponCode");
    printLog("applyRentCouponCode videoId :==> $videoId");
    printLog("applyRentCouponCode typeId :==> $typeId");
    printLog("applyRentCouponCode videoType :==> $videoType");
    printLog("applyRentCouponCode price :==> $price");
    couponLoading = true;
    couponModel = await ApiService()
        .applyRentCoupon(couponCode, videoId, typeId, videoType, price);
    printLog("applyRentCouponCode status :==> ${couponModel.status}");
    printLog("applyRentCouponCode message :==> ${couponModel.message}");
    couponLoading = false;
    notifyListeners();
  }

  void setFinalAmount(String? amount) {
    finalAmount = amount;
    printLog("setFinalAmount finalAmount :==> $finalAmount");
    notifyListeners();
  }

  Future<void> getPaytmToken(dynamic merchantID, orderId, custmoreID, channelID,
      txnAmount, website, callbackURL, industryTypeID) async {
    printLog("getPaytmToken merchantID :=======> $merchantID");
    printLog("getPaytmToken orderId :==========> $orderId");
    printLog("getPaytmToken custmoreID :=======> $custmoreID");
    printLog("getPaytmToken channelID :========> $channelID");
    printLog("getPaytmToken txnAmount :========> $txnAmount");
    printLog("getPaytmToken website :==========> $merchantID");
    printLog("getPaytmToken callbackURL :======> $merchantID");
    printLog("getPaytmToken industryTypeID :===> $industryTypeID");
    loading = true;
    payTmModel = await ApiService().getPaytmToken(merchantID, orderId,
        custmoreID, channelID, txnAmount, website, callbackURL, industryTypeID);
    printLog("getPaytmToken status :===> ${payTmModel.status}");
    printLog("getPaytmToken message :==> ${payTmModel.message}");
    loading = false;
    notifyListeners();
  }

  Future<void> addTransaction(
      dynamic packageId, description, amount, paymentId, couponCode) async {
    printLog("addTransaction userID :======> ${Constant.userID}");
    printLog("addTransaction packageId :===> $packageId");
    printLog("addTransaction couponCode :==> $couponCode");
    payLoading = true;
    successModel = await ApiService()
        .addTransaction(packageId, description, amount, paymentId, couponCode);
    printLog("addTransaction status :===> ${successModel.status}");
    printLog("addTransaction message :==> ${successModel.message}");
    payLoading = false;
    notifyListeners();
  }

  Future<void> addRentTransaction(dynamic producerId, videoId, price, typeId,
      videoType, subVideoType, transactionId, description, couponCode) async {
    printLog("addRentTransaction userID :======> ${Constant.userID}");
    printLog("addRentTransaction producerId :==> $producerId");
    printLog("addRentTransaction videoId :=====> $videoId");
    printLog("addRentTransaction couponCode :==> $couponCode");
    payLoading = true;
    successModel = await ApiService().addRentTransaction(
        producerId,
        videoId,
        price,
        typeId,
        videoType,
        subVideoType,
        transactionId,
        description,
        couponCode);
    printLog("addRentTransaction status :===> ${successModel.status}");
    printLog("addRentTransaction message :==> ${successModel.message}");
    payLoading = false;
    notifyListeners();
  }

  void setCurrentPayment(String? payment) {
    currentPayment = payment;
    notifyListeners();
  }

  void clearProvider() {
    printLog("<================ clearProvider ================>");
    currentPayment = "";
    finalAmount = "";
    payType = null;
    itemId = null;
    itemTitle = null;
    typeId = null;
    videoType = null;
    productPackage = null;
    currency = null;
    paymentId = null;
    paymentOptionModel = PaymentOptionModel();
    successModel = SuccessModel();
  }
}
