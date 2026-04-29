import '../model/continuewatchingmodel.dart';
import '../model/profilemodel.dart';
import '../model/successmodel.dart';
import '../model/watchlistmodel.dart';
import '../utils/constant.dart';
import '../utils/utils.dart';
import '../webservice/apiservices.dart';
import 'package:flutter/material.dart';

class MySpaceProvider extends ChangeNotifier {
  ProfileModel profileModel = ProfileModel();
  SuccessModel successModel = SuccessModel();
  ContinueWatchingModel continueWatchingModel = ContinueWatchingModel();
  WatchlistModel watchlistModel = WatchlistModel();

  bool loading = false,
      loadingContinue = false,
      loadingWatchlist = false,
      loadingUpdate = false,
      loadingPCCheck = false;

  Future<void> getProfile(BuildContext context) async {
    printLog("getProfile userID :==> ${Constant.userID}");

    loading = true;
    profileModel = await ApiService().profile();
    printLog("get_profile status :==> ${profileModel.status}");
    printLog("get_profile message :==> ${profileModel.message}");
    if (profileModel.status == 200 && profileModel.result != null) {
      if ((profileModel.result?.length ?? 0) > 0) {
        Utils.saveUserPaymentCreds(
          userID: profileModel.result?[0].id.toString(),
          userName: profileModel.result?[0].userName.toString(),
          fullName: profileModel.result?[0].fullName.toString(),
          userEmail: profileModel.result?[0].email.toString(),
          userMobile: profileModel.result?[0].mobileNumber.toString(),
        );
        Utils.updatePremium(profileModel.result?[0].isBuy.toString() ?? "0");
        if (context.mounted) {
          printLog("========= get_profile loadAds =========");
          Utils.loadAds(context);
        }
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> getContinueWatching(int pageNo) async {
    printLog("getContinueWatching pageNo :==> $pageNo");
    loadingContinue = true;
    continueWatchingModel = await ApiService().getContinueWatching(pageNo);
    printLog(
        "getContinueWatching status :===> ${continueWatchingModel.status}");
    printLog(
        "getContinueWatching message :==> ${continueWatchingModel.message}");
    loadingContinue = false;
    notifyListeners();
  }

  Future<void> getWatchlist(int pageNo) async {
    printLog("getWatchlist pageNo :==> $pageNo");
    loadingWatchlist = true;
    watchlistModel = await ApiService().watchlist(pageNo);
    printLog("getWatchlist status :===> ${watchlistModel.status}");
    printLog("getWatchlist message :==> ${watchlistModel.message}");
    loadingWatchlist = false;
    notifyListeners();
  }

  Future<void> getUpdatePCStatus(dynamic pcStatus) async {
    printLog("getUpdatePCStatus pcStatus :==> $pcStatus");
    successModel = SuccessModel();
    loadingPCCheck = true;
    try {
      successModel = await ApiService().updatePCStatus(pcStatus);
    } on Exception catch (e) {
      printLog("UpdatePCStatus Exception ====> $e");
    }
    printLog("getUpdatePCStatus status :====> ${successModel.status}");
    printLog("getUpdatePCStatus message :===> ${successModel.message}");
    loadingPCCheck = false;
    notifyListeners();
  }

  Future<void> changeUserMode(dynamic kidsStatus) async {
    printLog("changeUserMode kidsStatus :==> $kidsStatus");
    successModel = SuccessModel();
    loadingPCCheck = true;
    try {
      successModel = await ApiService().addRemoveKidsMode(kidsStatus);
    } on Exception catch (e) {
      printLog("changeUserMode Exception ====> $e");
    }
    printLog("changeUserMode status :====> ${successModel.status}");
    printLog("changeUserMode message :===> ${successModel.message}");
    loadingPCCheck = false;
    notifyListeners();
  }

  Future<void> parentControlCheckPassword(dynamic password) async {
    printLog("parentControlCheckPassword password :==> $password");
    successModel = SuccessModel();
    loadingPCCheck = true;
    successModel = await ApiService().parentControlCheckPassword(password);
    printLog("parentControlCheckPassword status :===> ${successModel.status}");
    printLog("parentControlCheckPassword message :==> ${successModel.message}");
    loadingPCCheck = false;
    notifyListeners();
  }

  void setUpdateLoading(bool isLoading) {
    loadingPCCheck = isLoading;
    notifyListeners();
  }

  void notifyProvider() {
    notifyListeners();
  }

  void clearProvider() {
    continueWatchingModel = ContinueWatchingModel();
    watchlistModel = WatchlistModel();
    successModel = SuccessModel();
    loading = false;
  }
}
