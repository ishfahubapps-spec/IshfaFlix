import 'dart:async';
import 'dart:io';
import '../provider/paymentprovider.dart';
import '../provider/subhistoryprovider.dart';
import '../routes/routes_constant.dart';
import '../subscription/contactus.dart';
import '../subscription/subscriptionhistory.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_html/html.dart' as html;

import 'package:carousel_slider/carousel_slider.dart';
import '../model/subscriptionmodel.dart';
import '../shimmer/shimmerutils.dart';
import '../subscription/allpayment.dart';
import '../utils/constant.dart';
import '../utils/dimens.dart';
import '../utils/sharedpre.dart';
import '../webpages/webcomman.dart';
import '../widget/nodata.dart';
import '../provider/subscriptionprovider.dart';
import '../utils/color.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';
import '../utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

class Subscription extends StatefulWidget {
  final String? newPage, oldPage;
  const Subscription({
    required this.newPage,
    required this.oldPage,
    super.key,
  });

  @override
  State<Subscription> createState() => SubscriptionState();
}

class SubscriptionState extends State<Subscription> {
  late SubscriptionProvider subscriptionProvider;
  CarouselSliderController pageController = CarouselSliderController();
  SharedPre sharedPre = SharedPre();
  String? userName, userEmail, userMobileNo;

  @override
  void initState() {
    super.initState();
    subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    _getData();
  }

  Future<void> _getData() async {
    Utils.getCurrencySymbol();
    await subscriptionProvider.getPackages();
    await _getUserData();
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    subscriptionProvider.clearProvider();
    super.dispose();
  }

  Future<void> _checkAndPay(List<Result>? packageList, int index) async {
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    if (Utils.checkLoginUser(context)) {
      if (packageList?[index].isBuy == 1) {
        printLog("<============= Purchaged =============>");
        Utils.showSnackbar(context, "info", "already_purchased", true);
        return;
      }
      /* Update Required data for payment */
      if (userName == null ||
          (userName ?? "").isEmpty ||
          (userName ?? "").contains("null") ||
          userEmail == null ||
          (userEmail ?? "").isEmpty ||
          (userEmail ?? "").contains("null") ||
          userMobileNo == null ||
          (userMobileNo ?? "").isEmpty ||
          (userMobileNo ?? "").contains("null")) {
        updateDataDialog(
          isNameReq: (userName == null ||
              (userName ?? "").isEmpty ||
              (userName ?? "").contains("null")),
          isEmailReq: userEmail == null ||
              (userEmail ?? "").isEmpty ||
              (userEmail ?? "").contains("null"),
          isMobileReq: userMobileNo == null ||
              (userMobileNo ?? "").isEmpty ||
              (userMobileNo ?? "").contains("null"),
        );
        return;
      }
      /* Update Required data for payment */
      await paymentProvider.setLoading(true);
      if (!mounted) return;
      if (kIsWeb) {
        final extraParams = {
          'newpage': widget.newPage.toString(),
          'paytype': 'Package',
          'producerid': '',
          'itemid': packageList?[index].id.toString() ?? '',
          'price': packageList?[index].price.toString() ?? '',
          'title': packageList?[index].name.toString() ?? '',
          'videotype': '',
          'subvideotype': '',
          'typeid': '',
          'currency': '',
          'productpackage': (kIsWeb)
              ? (packageList?[index].webPriceId.toString() ?? '')
              : (Platform.isIOS
                  ? (packageList?[index].iosProductPackage.toString() ?? '')
                  : (packageList?[index].androidProductPackage.toString() ??
                      ''))
        };
        context.go(
          "/${RoutesConstant.paymentPage}",
          extra: extraParams,
        );
      } else {
        if (widget.newPage != RoutesConstant.subscriptionPage) {
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                return AllPayment(
                  newPage: RoutesConstant.paymentPage,
                  oldPage: widget.newPage.toString(),
                  reqText: '',
                  payType: 'Package',
                  producerId: '',
                  itemId: packageList?[index].id.toString() ?? '',
                  price: packageList?[index].price.toString() ?? '',
                  itemTitle: packageList?[index].name.toString() ?? '',
                  typeId: '',
                  videoType: '',
                  subVideoType: '',
                  productPackage: (kIsWeb)
                      ? (packageList?[index].webPriceId.toString() ?? '')
                      : (Platform.isIOS
                          ? (packageList?[index].iosProductPackage.toString() ??
                              '')
                          : (packageList?[index]
                                  .androidProductPackage
                                  .toString() ??
                              '')),
                  currency: '',
                );
              },
            ),
          );
        } else {
          await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return AllPayment(
                  newPage: RoutesConstant.paymentPage,
                  oldPage: widget.newPage,
                  reqText: Constant.userID,
                  payType: 'Package',
                  producerId: '',
                  itemId: packageList?[index].id.toString() ?? '',
                  price: packageList?[index].price.toString() ?? '',
                  itemTitle: packageList?[index].name.toString() ?? '',
                  typeId: '',
                  videoType: '',
                  subVideoType: '',
                  productPackage: (kIsWeb)
                      ? (packageList?[index].webPriceId.toString() ?? '')
                      : (Platform.isIOS
                          ? (packageList?[index].iosProductPackage.toString() ??
                              '')
                          : (packageList?[index]
                                  .androidProductPackage
                                  .toString() ??
                              '')),
                  currency: '',
                );
              },
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return child;
              },
            ),
          );
        }
      }
    }
  }

  Future<void> _getUserData() async {
    userName = await sharedPre.read("userfullname");
    userEmail = await sharedPre.read("useremail");
    userMobileNo = await sharedPre.read("usermobile");
    printLog('getUserData userName ======> $userName');
    printLog('getUserData userEmail =====> $userEmail');
    printLog('getUserData userMobileNo ==> $userMobileNo');
  }

  Future<void> updateDataDialog({
    required bool isNameReq,
    required bool isEmailReq,
    required bool isMobileReq,
  }) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final mobileController = TextEditingController();
    if (!context.mounted) return;
    dynamic result;
    if (kIsWeb || Constant.isTV) {
      result = await showDialog<dynamic>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return Dialog(
            alignment: Alignment.center,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            insetPadding: EdgeInsets.fromLTRB(
              (MediaQuery.of(context).size.width > 1000) ? 50 : 30,
              (MediaQuery.of(context).size.width > 1000)
                  ? ((MediaQuery.of(context).size.height > 500) ? 50 : 30)
                  : 30,
              (MediaQuery.of(context).size.width > 1000) ? 50 : 30,
              (MediaQuery.of(context).size.width > 1000)
                  ? ((MediaQuery.of(context).size.height > 500) ? 50 : 30)
                  : 30,
            ),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            backgroundColor: lightBlack,
            child: Utils.dataUpdateDialog(
              context,
              isNameReq: isNameReq,
              isEmailReq: isEmailReq,
              isMobileReq: isMobileReq,
              nameController: nameController,
              emailController: emailController,
              mobileController: mobileController,
            ),
          );
        },
      );
    } else {
      result = await showModalBottomSheet<dynamic>(
        context: context,
        backgroundColor: lightBlack,
        isScrollControlled: true,
        isDismissible: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        builder: (BuildContext context) {
          return Wrap(
            children: [
              Utils.dataUpdateDialog(
                context,
                isNameReq: isNameReq,
                isEmailReq: isEmailReq,
                isMobileReq: isMobileReq,
                nameController: nameController,
                emailController: emailController,
                mobileController: mobileController,
              ),
            ],
          );
        },
      );
    }
    if (result != null) {
      await _getUserData();
      Future.delayed(Duration.zero).then((value) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebComman(
        newPage: widget.newPage,
        oldPage: widget.oldPage,
        reqText: '',
        newChild: _buildSubscription(),
      );
    } else {
      return Scaffold(
        backgroundColor: appBgColor,
        appBar: Utils.myAppBarWithBack(context, "subsciption", true),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: _buildSubscription(),
              ),
            ),
            /* AdMob Banner */
            Container(
              child: Utils.showBannerAd(context),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHistoryBtn() {
    if (Constant.userIsKid == false) {
      return FittedBox(
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimens.cardRadius),
          onTap: () async {
            final subHistoryProvider =
                Provider.of<SubHistoryProvider>(context, listen: false);
            if (!mounted) return;
            if (Constant.userID != null) {
              subHistoryProvider.setLoading(true);
              if (!mounted) return;
              if (kIsWeb) {
                context.go(
                  "/${RoutesConstant.subsHistoryPage}",
                  extra: widget.newPage,
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionHistory(
                      newPage: RoutesConstant.subsHistoryPage,
                      oldPage: '',
                      reqText: '',
                    ),
                  ),
                );
              }
            } else {
              Utils.openLogin(context: context, newPage: "");
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: Utils.setBGWithBorder(
                lightBlack, gray.withValues(alpha: 0.3), 5, 0.5),
            alignment: Alignment.center,
            child: MyText(
              color: white,
              text: "view_transactions",
              multilanguage: true,
              textalign: TextAlign.start,
              fontsizeNormal: 13,
              fontsizeWeb: 18,
              fontweight: FontWeight.w500,
              maxline: 1,
              overflow: TextOverflow.ellipsis,
              fontstyle: FontStyle.normal,
            ),
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildSubscription() {
    if (subscriptionProvider.loading) {
      if (Dimens.isBigScreen(context)) {
        return ShimmerUtils.buildSubscribeWebShimmer(context);
      } else {
        return ShimmerUtils.buildSubscribeShimmer(context);
      }
    } else {
      if (subscriptionProvider.subscriptionModel.status == 200) {
        return Column(
          children: [
            SizedBox(
                height: (Dimens.isBigScreen(context))
                    ? (Dimens.homeTabHeight + 30)
                    : 15),
            Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.only(left: 20, right: 20),
              alignment: Alignment.center,
              child: MyText(
                color: descTextColor,
                text: "subscriptiondesc",
                multilanguage: true,
                textalign: TextAlign.center,
                fontsizeNormal: 16,
                fontsizeWeb: 18,
                maxline: 2,
                fontweight: FontWeight.w600,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
              ),
            ),
            SizedBox(height: Dimens.isBigScreen(context) ? 40 : 30),

            /* Remaining Data */
            _buildItems(subscriptionProvider.subscriptionModel.result),

            /* History Button */
            SizedBox(height: Dimens.isBigScreen(context) ? 40 : 30),
            _buildHistoryBtn(),

            /* Support */
            SizedBox(height: Dimens.isBigScreen(context) ? 25 : 15),
            _buildBottomView(),
          ],
        );
      } else {
        return const NoData(title: '', subTitle: '');
      }
    }
  }

  Widget _buildItems(List<Result>? packageList) {
    if (Dimens.isBigScreen(context)) {
      return buildWebItem(packageList);
    } else {
      return buildMobileItem(packageList);
    }
  }

  Widget buildMobileItem(List<Result>? packageList) {
    if (packageList != null) {
      return CarouselSlider.builder(
        itemCount: packageList.length,
        carouselController: pageController,
        options: CarouselOptions(
          initialPage: 0,
          height: kIsWeb
              ? ((html.window.screen?.height as double) * 0.45)
              : (MediaQuery.of(context).size.height * 0.45),
          enlargeCenterPage: packageList.length > 1 ? true : false,
          enlargeFactor: 0.18,
          autoPlay: false,
          autoPlayCurve: Curves.easeInOutQuart,
          enableInfiniteScroll: packageList.length > 1 ? true : false,
          viewportFraction: packageList.length > 1 ? 0.8 : 0.9,
        ),
        itemBuilder: (BuildContext context, int index, int pageViewIndex) {
          return Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            elevation: 3,
            color: (packageList[index].isBuy == 1 ? colorPrimary : lightBlack),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Container(
              decoration:
                  Utils.setBGWithBorder(transparent, descTextColor, 8, 1),
              child: Column(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.only(left: 18, right: 18),
                    constraints: const BoxConstraints(minHeight: 55),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: MyText(
                            color: (packageList[index].isBuy == 1
                                ? black
                                : colorPrimary),
                            text: packageList[index].name ?? "",
                            textalign: TextAlign.start,
                            fontsizeNormal: 18,
                            fontsizeWeb: 24,
                            maxline: 1,
                            multilanguage: false,
                            overflow: TextOverflow.ellipsis,
                            fontweight: FontWeight.w700,
                            fontstyle: FontStyle.normal,
                          ),
                        ),
                        const SizedBox(width: 5),
                        MyText(
                          color: (packageList[index].isBuy == 1
                              ? black
                              : colorPrimary),
                          text:
                              "${Constant.currencySymbol} ${packageList[index].price.toString()} / ${packageList[index].time.toString()} ${packageList[index].type.toString()}",
                          textalign: TextAlign.center,
                          fontsizeNormal: 16,
                          fontsizeWeb: 22,
                          maxline: 1,
                          multilanguage: false,
                          overflow: TextOverflow.ellipsis,
                          fontweight: FontWeight.w600,
                          fontstyle: FontStyle.normal,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: 0.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    color: descTextColor,
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(1, 9, 1, 9),
                    constraints: const BoxConstraints(minHeight: 0),
                    child: SingleChildScrollView(
                      child: _buildBenefits(packageList, index),
                    ),
                  ),
                  const SizedBox(height: 20),

                  /* Choose Plan */
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(5),
                      onTap: () async {
                        _checkAndPay(packageList, index);
                      },
                      child: Container(
                        height: 45,
                        width: MediaQuery.of(context).size.width * 0.5,
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        decoration: BoxDecoration(
                          color: (packageList[index].isBuy == 1
                              ? white
                              : colorPrimary),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        alignment: Alignment.center,
                        child: Consumer<SubscriptionProvider>(
                          builder: (context, subscriptionProvider, child) {
                            return MyText(
                              color: black,
                              text: (packageList[index].isBuy == 1 &&
                                      packageList[index].isActivePlan == 1)
                                  ? "current"
                                  : ((packageList[index].isBuy == 1)
                                      ? "upcoming"
                                      : "chooseplan"),
                              textalign: TextAlign.center,
                              fontsizeNormal: 16,
                              fontsizeWeb: 20,
                              fontweight: FontWeight.w700,
                              multilanguage: true,
                              maxline: 1,
                              overflow: TextOverflow.ellipsis,
                              fontstyle: FontStyle.normal,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget buildWebItem(List<Result>? packageList) {
    if (packageList != null) {
      return Container(
        padding: const EdgeInsets.only(left: 30, right: 30, bottom: 15),
        child: ResponsiveGridList(
          minItemWidth: (MediaQuery.of(context).size.width > 720)
              ? Dimens.widthPackageWeb
              : Dimens.widthPackage,
          verticalGridSpacing: 8,
          horizontalGridSpacing: 6,
          minItemsPerRow: 1,
          maxItemsPerRow: 3,
          listViewBuilderOptions: ListViewBuilderOptions(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
          children: List.generate(
            (packageList.length),
            (index) {
              return Card(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                elevation: 0,
                color:
                    (packageList[index].isBuy == 1 ? colorPrimary : lightBlack),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  decoration:
                      Utils.setBGWithBorder(transparent, descTextColor, 8, 1),
                  child: Column(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.only(left: 18, right: 18),
                        constraints: const BoxConstraints(minHeight: 55),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: MyText(
                                color: (packageList[index].isBuy == 1
                                    ? black
                                    : colorPrimary),
                                text: packageList[index].name ?? "",
                                textalign: TextAlign.start,
                                fontsizeNormal: 18,
                                fontsizeWeb: 24,
                                maxline: 1,
                                multilanguage: false,
                                overflow: TextOverflow.ellipsis,
                                fontweight: FontWeight.w700,
                                fontstyle: FontStyle.normal,
                              ),
                            ),
                            const SizedBox(width: 5),
                            MyText(
                              color: (packageList[index].isBuy == 1
                                  ? black
                                  : colorPrimary),
                              text:
                                  "${Constant.currencySymbol} ${packageList[index].price.toString()} / ${packageList[index].time.toString()} ${packageList[index].type.toString()}",
                              textalign: TextAlign.center,
                              fontsizeNormal: 16,
                              fontsizeWeb: 22,
                              maxline: 1,
                              multilanguage: false,
                              overflow: TextOverflow.ellipsis,
                              fontweight: FontWeight.w600,
                              fontstyle: FontStyle.normal,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: MediaQuery.of(context).size.width,
                        height: 0.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: descTextColor,
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(1, 9, 1, 9),
                        height: 200,
                        child: SingleChildScrollView(
                          child: _buildBenefits(packageList, index),
                        ),
                      ),
                      const SizedBox(height: 20),

                      /* Choose Plan */
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(5),
                            onTap: () async {
                              _checkAndPay(packageList, index);
                            },
                            child: Container(
                              height: 45,
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                              decoration: BoxDecoration(
                                color: (packageList[index].isBuy == 1
                                    ? white
                                    : colorPrimary),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              alignment: Alignment.center,
                              child: Consumer<SubscriptionProvider>(
                                builder:
                                    (context, subscriptionProvider, child) {
                                  return MyText(
                                    color: black,
                                    text: (packageList[index].isBuy == 1 &&
                                            packageList[index].isActivePlan ==
                                                1)
                                        ? "current"
                                        : ((packageList[index].isBuy == 1)
                                            ? "upcoming"
                                            : "chooseplan"),
                                    textalign: TextAlign.center,
                                    fontsizeNormal: 16,
                                    fontsizeWeb: 20,
                                    fontweight: FontWeight.w700,
                                    multilanguage: true,
                                    maxline: 1,
                                    overflow: TextOverflow.ellipsis,
                                    fontstyle: FontStyle.normal,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildBenefits(List<Result>? packageList, int? index) {
    if (packageList?[index ?? 0].data != null &&
        (packageList?[index ?? 0].data?.length ?? 0) > 0) {
      return AlignedGridView.count(
        shrinkWrap: true,
        crossAxisCount: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 25,
        padding: const EdgeInsets.fromLTRB(15, 2, 15, 5),
        itemCount: (packageList?[index ?? 0].data?.length ?? 0),
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        itemBuilder: (BuildContext context, int position) {
          return Container(
            constraints: const BoxConstraints(minHeight: 15),
            width: MediaQuery.of(context).size.width,
            child: Row(
              children: [
                Expanded(
                  child: MyText(
                    color: (packageList?[index ?? 0].isBuy == 1
                        ? black
                        : descTextColor),
                    text: packageList?[index ?? 0].data?[position].packageKey ??
                        "",
                    textalign: TextAlign.start,
                    multilanguage: false,
                    fontsizeNormal: 15,
                    fontsizeWeb: 18,
                    maxline: 3,
                    overflow: TextOverflow.ellipsis,
                    fontweight: FontWeight.w600,
                    fontstyle: FontStyle.normal,
                  ),
                ),
                const SizedBox(width: 20),
                (((packageList?[index ?? 0].data?[position].packageValue ??
                                    "") ==
                                "1" ||
                            (packageList?[index ?? 0]
                                        .data?[position]
                                        .packageValue ??
                                    "") ==
                                "0") &&
                        !(packageList?[index ?? 0].data?[position].packageKey ??
                                "")
                            .contains(RegExp(r'[0-9]')))
                    ? MyImage(
                        width: 23,
                        height: 23,
                        color: (packageList?[index ?? 0]
                                        .data?[position]
                                        .packageValue ??
                                    "") ==
                                "1"
                            ? (packageList?[index ?? 0].isBuy == 1
                                ? black
                                : colorPrimary)
                            : redColor,
                        imagePath: (packageList?[index ?? 0]
                                        .data?[position]
                                        .packageValue ??
                                    "") ==
                                "1"
                            ? "tick_mark.png"
                            : "cross_mark.png",
                      )
                    : MyText(
                        color: (packageList?[index ?? 0].isBuy == 1
                            ? black
                            : descTextColor),
                        text: packageList?[index ?? 0]
                                .data?[position]
                                .packageValue ??
                            "",
                        textalign: TextAlign.center,
                        fontsizeNormal: 16,
                        fontsizeWeb: 24,
                        multilanguage: false,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        fontweight: FontWeight.bold,
                        fontstyle: FontStyle.normal,
                      ),
              ],
            ),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  /* Bottom Descriptions ********************** */
  Widget _buildBottomView() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MyText(
            color: titleTextColor,
            text: "subscription_issue_help",
            textalign: TextAlign.start,
            fontsizeNormal: 14,
            fontsizeWeb: 16,
            maxline: 1,
            multilanguage: true,
            overflow: TextOverflow.ellipsis,
            fontweight: FontWeight.w500,
            fontstyle: FontStyle.normal,
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () {
              if (kIsWeb) {
                context.go(
                  "/${RoutesConstant.contactUsPage}",
                  extra: RoutesConstant.subscriptionPage,
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return const ContactUs(
                        newPage: RoutesConstant.contactUsPage,
                        oldPage: RoutesConstant.subscriptionPage,
                      );
                    },
                  ),
                );
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MyImage(
                  imagePath: "ic_calling.png",
                  height: 15,
                  width: 15,
                  fit: BoxFit.contain,
                  color: colorPrimary,
                ),
                const SizedBox(width: 5),
                MyText(
                  color: colorPrimary,
                  text: "contact_support_team",
                  textalign: TextAlign.start,
                  fontsizeNormal: 14,
                  fontsizeWeb: 16,
                  maxline: 1,
                  multilanguage: true,
                  overflow: TextOverflow.ellipsis,
                  fontweight: FontWeight.w500,
                  fontstyle: FontStyle.normal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  /* ********************** Bottom Descriptions */
}
