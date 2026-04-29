import '../provider/subhistoryprovider.dart';
import '../shimmer/shimmerutils.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../utils/dimens.dart';
import '../utils/utils.dart';
import '../webpages/webcomman.dart';
import '../widget/mytext.dart';
import '../widget/nodata.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

class SubscriptionHistory extends StatefulWidget {
  final String? newPage, oldPage;
  final dynamic reqText;
  const SubscriptionHistory({
    required this.newPage,
    required this.oldPage,
    required this.reqText,
    super.key,
  });

  @override
  State<SubscriptionHistory> createState() => _SubscriptionHistoryState();
}

class _SubscriptionHistoryState extends State<SubscriptionHistory> {
  late SubHistoryProvider subHistoryProvider;
  final nestedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    nestedScrollController.addListener(_nestedScrollListener);
    subHistoryProvider =
        Provider.of<SubHistoryProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNewData(0);
    });
  }

  Future<void> _nestedScrollListener() async {
    if (!nestedScrollController.hasClients) return;
    if (nestedScrollController.offset >=
            nestedScrollController.position.maxScrollExtent &&
        !nestedScrollController.position.outOfRange &&
        (subHistoryProvider.isMorePage ?? false)) {
      subHistoryProvider.setLoadMore(true);
      _fetchNewData(subHistoryProvider.currentPage ?? 0);
    }
  }

  Future<void> _fetchNewData(int? nextPage) async {
    printLog("_fetchNewData nextPage =========> $nextPage");
    printLog(
        "_fetchNewData isMorePage =======> ${subHistoryProvider.isMorePage}");
    printLog(
        "_fetchNewData currentPage ======> ${subHistoryProvider.currentPage}");
    printLog(
        "_fetchNewData totalPage ========> ${subHistoryProvider.totalPage}");

    await subHistoryProvider.getSubscriptionList((nextPage ?? 0) + 1);
    printLog(
        "historyDataList length ==> ${subHistoryProvider.historyDataList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    subHistoryProvider.clearProvider();
    super.dispose();
  }

  bool _checkExpiry(int position) {
    printLog(
        "expDate ===> ${subHistoryProvider.historyDataList?[position].expiryDate}");
    if ((subHistoryProvider.historyDataList?[position].expiryDate ?? "") !=
        "") {
      return DateTime.now().isBefore(DateTime.parse(
          subHistoryProvider.historyDataList?[position].expiryDate ?? ""));
    } else {
      return false;
    }
  }

  TransactionStyle getTransactionStyle(String status) {
    switch (status) {
      case 'current':
        return TransactionStyle(
          backgroundColor: colorPrimary,
          borderColor: white,
          titleTextColor: black,
          descTextColor: black,
          buttonColor: complimentryColor,
          buttonTextColor: white,
        );
      case 'upcoming':
        return TransactionStyle(
          backgroundColor: transparent,
          borderColor: gray.withValues(alpha: 0.5),
          titleTextColor: colorPrimary.withValues(alpha: 0.7),
          descTextColor: gray.withValues(alpha: 0.5),
          buttonColor: colorAccent,
          buttonTextColor: white.withValues(alpha: 0.7),
        );
      case 'expired':
        return TransactionStyle(
          backgroundColor: transparent,
          borderColor: gray,
          titleTextColor: colorPrimary,
          descTextColor: white,
          buttonColor: gray,
          buttonTextColor: white,
        );
      default:
        return TransactionStyle(
          backgroundColor: transparent,
          borderColor: gray,
          titleTextColor: colorPrimary,
          descTextColor: white,
          buttonColor: gray,
          buttonTextColor: white,
        );
    }
  }

  String _transStatus(int position) {
    printLog(
        "expDate ===> ${subHistoryProvider.historyDataList?[position].expiryDate}");
    if ((subHistoryProvider.historyDataList?[position].isUpcoming ?? 0) == 1) {
      return 'upcoming';
    } else if ((subHistoryProvider.historyDataList?[position].expiryDate ??
                "") !=
            "" &&
        DateTime.now().isBefore(DateTime.parse(
            subHistoryProvider.historyDataList?[position].expiryDate ?? ""))) {
      return 'current';
    } else if ((subHistoryProvider.historyDataList?[position].expiryDate ??
                "") !=
            "" &&
        DateTime.now().isAfter(DateTime.parse(
            subHistoryProvider.historyDataList?[position].expiryDate ?? ""))) {
      return 'expired';
    } else {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return WebComman(
        newPage: widget.newPage,
        oldPage: widget.oldPage,
        reqText: '',
        newChild: _buildForWeb(),
      );
    } else {
      return Scaffold(
        backgroundColor: appBgColor,
        appBar: Utils.myAppBarWithBack(context, "transactions", true),
        body: SafeArea(
          child: _buildForOther(),
        ),
      );
    }
  }

  Widget _buildForWeb() {
    return Column(
      children: [
        SizedBox(height: Dimens.homeTabHeight + 30),
        Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.only(left: 20, right: 20),
          alignment: Alignment.center,
          child: MyText(
            color: colorPrimary,
            text: "transactions",
            multilanguage: true,
            textalign: TextAlign.center,
            maxline: 2,
            fontsizeNormal: 20,
            fontsizeWeb: 25,
            fontweight: FontWeight.w600,
            overflow: TextOverflow.ellipsis,
            fontstyle: FontStyle.normal,
          ),
        ),
        SingleChildScrollView(
          padding: EdgeInsets.only(
              top: Dimens.isBigScreen(context) ? 40 : 12,
              bottom: Dimens.isBigScreen(context) ? 40 : 12),
          child: Consumer<SubHistoryProvider>(
            builder: (context, subHistoryProvider, child) {
              if (subHistoryProvider.loading) {
                return ShimmerUtils.buildHistoryShimmer(context, 10);
              } else {
                if (subHistoryProvider.historyDataList != null &&
                    (subHistoryProvider.historyDataList?.length ?? 0) > 0) {
                  if (Dimens.isBigScreen(context)) {
                    return _buildWebItem();
                  } else {
                    return _buildOtherItem();
                  }
                } else {
                  return const NoData(
                    title: 'no_transaction_title',
                    subTitle: 'no_transaction_desc',
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildForOther() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: nestedScrollController,
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            child: Consumer<SubHistoryProvider>(
              builder: (context, subHistoryProvider, child) {
                if (subHistoryProvider.loading) {
                  return ShimmerUtils.buildHistoryShimmer(context, 10);
                } else {
                  if (subHistoryProvider.historyDataList != null &&
                      (subHistoryProvider.historyDataList?.length ?? 0) > 0) {
                    return _buildOtherItem();
                  } else {
                    return const NoData(
                      title: 'no_transaction_title',
                      subTitle: 'no_transaction_desc',
                    );
                  }
                }
              },
            ),
          ),
        ),
        /* AdMob Banner */
        Container(
          child: Utils.showBannerAd(context),
        ),
      ],
    );
  }

  Widget _buildWebItem() {
    return Container(
      padding: const EdgeInsets.only(left: 30, right: 30, bottom: 15),
      child: ResponsiveGridList(
        minItemWidth: (Dimens.isBigScreen(context))
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
          (subHistoryProvider.historyDataList?.length ?? 0),
          (position) {
            final String status = _transStatus(position);
            final TransactionStyle style = getTransactionStyle(status);
            return Container(
              width: MediaQuery.of(context).size.width,
              constraints: BoxConstraints(minHeight: Dimens.heightHistory),
              decoration: Utils.setBGWithBorder(
                  style.backgroundColor, style.borderColor, 5, 0.5),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          /* Title */
                          MyText(
                            color: style.titleTextColor,
                            text: subHistoryProvider
                                    .historyDataList?[position].packageName ??
                                "",
                            textalign: TextAlign.start,
                            maxline: 2,
                            overflow: TextOverflow.ellipsis,
                            fontsizeNormal: 18,
                            fontsizeWeb: 20,
                            fontweight: FontWeight.w700,
                            fontstyle: FontStyle.normal,
                          ),

                          /* Price */
                          Container(
                            constraints: const BoxConstraints(minHeight: 0),
                            margin: const EdgeInsets.only(top: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  color: style.descTextColor,
                                  text: "price",
                                  textalign: TextAlign.center,
                                  fontsizeNormal: 13,
                                  fontweight: FontWeight.w500,
                                  fontsizeWeb: 15,
                                  maxline: 1,
                                  multilanguage: true,
                                  overflow: TextOverflow.ellipsis,
                                  fontstyle: FontStyle.normal,
                                ),
                                const SizedBox(width: 5),
                                MyText(
                                  color: style.descTextColor,
                                  text: ":",
                                  textalign: TextAlign.center,
                                  fontsizeNormal: 13,
                                  fontweight: FontWeight.w500,
                                  fontsizeWeb: 15,
                                  maxline: 1,
                                  multilanguage: false,
                                  overflow: TextOverflow.ellipsis,
                                  fontstyle: FontStyle.normal,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: MyText(
                                    color: style.descTextColor,
                                    text:
                                        "${Constant.currencySymbol}${subHistoryProvider.historyDataList?[position].price.toString()}",
                                    textalign: TextAlign.start,
                                    fontsizeNormal: 15,
                                    fontweight: FontWeight.w700,
                                    fontsizeWeb: 14,
                                    multilanguage: false,
                                    maxline: 1,
                                    overflow: TextOverflow.ellipsis,
                                    fontstyle: FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          /* Expire On */
                          Container(
                            constraints: const BoxConstraints(minHeight: 0),
                            margin: const EdgeInsets.only(top: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  color: style.descTextColor,
                                  text: _checkExpiry(position)
                                      ? "expire_on"
                                      : "expired_on",
                                  textalign: TextAlign.center,
                                  fontsizeNormal: 13,
                                  fontweight: FontWeight.w500,
                                  fontsizeWeb: 15,
                                  maxline: 1,
                                  multilanguage: true,
                                  overflow: TextOverflow.ellipsis,
                                  fontstyle: FontStyle.normal,
                                ),
                                const SizedBox(width: 5),
                                MyText(
                                  color: style.descTextColor,
                                  text: ":",
                                  textalign: TextAlign.center,
                                  fontsizeNormal: 13,
                                  fontweight: FontWeight.w500,
                                  fontsizeWeb: 15,
                                  maxline: 1,
                                  multilanguage: false,
                                  overflow: TextOverflow.ellipsis,
                                  fontstyle: FontStyle.normal,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: MyText(
                                    color: style.descTextColor,
                                    text: (subHistoryProvider
                                                    .historyDataList?[position]
                                                    .expiryDate !=
                                                null ||
                                            (subHistoryProvider
                                                        .historyDataList?[
                                                            position]
                                                        .expiryDate ??
                                                    "") !=
                                                "")
                                        ? (subHistoryProvider
                                                .historyDataList?[position]
                                                .expiryDate
                                                .toString() ??
                                            "")
                                        : "-",
                                    textalign: TextAlign.start,
                                    fontsizeNormal: 13,
                                    fontweight: FontWeight.w700,
                                    fontsizeWeb: 14,
                                    multilanguage: false,
                                    maxline: 5,
                                    overflow: TextOverflow.ellipsis,
                                    fontstyle: FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (subHistoryProvider
                              .historyDataList?[position].expiryDate !=
                          null ||
                      (subHistoryProvider
                                  .historyDataList?[position].expiryDate ??
                              "") !=
                          "")
                    Container(
                      height: 32,
                      constraints: const BoxConstraints(minWidth: 0),
                      decoration: Utils.setBGWithBorder(
                          style.buttonColor, style.buttonTextColor, 15, 0.5),
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      alignment: Alignment.center,
                      child: MyText(
                        color: style.buttonTextColor,
                        text: _transStatus(position),
                        multilanguage: true,
                        textalign: TextAlign.center,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        fontsizeNormal: 13,
                        fontsizeWeb: 15,
                        fontweight: FontWeight.w700,
                        fontstyle: FontStyle.normal,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtherItem() {
    return AlignedGridView.count(
      shrinkWrap: true,
      crossAxisCount: 1,
      crossAxisSpacing: 0,
      mainAxisSpacing: 12,
      padding: const EdgeInsets.only(left: 15, right: 15),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subHistoryProvider.historyDataList?.length ?? 0,
      itemBuilder: (BuildContext context, int position) {
        final String status = _transStatus(position);
        final TransactionStyle style = getTransactionStyle(status);
        return Container(
          width: MediaQuery.of(context).size.width,
          constraints: BoxConstraints(minHeight: Dimens.heightHistory),
          decoration: Utils.setBGWithBorder(
              style.backgroundColor, style.borderColor, 5, 0.5),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 0, 15, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      /* Title */
                      MyText(
                        color: style.titleTextColor,
                        text: subHistoryProvider
                                .historyDataList?[position].packageName ??
                            "",
                        textalign: TextAlign.start,
                        maxline: 2,
                        overflow: TextOverflow.ellipsis,
                        fontsizeNormal: 18,
                        fontweight: FontWeight.w700,
                        fontstyle: FontStyle.normal,
                      ),

                      /* Price */
                      Container(
                        constraints: const BoxConstraints(minHeight: 0),
                        margin: const EdgeInsets.only(top: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(
                              color: style.descTextColor,
                              text: "price",
                              textalign: TextAlign.center,
                              fontsizeNormal: 13,
                              fontweight: FontWeight.w500,
                              fontsizeWeb: 15,
                              maxline: 1,
                              multilanguage: true,
                              overflow: TextOverflow.ellipsis,
                              fontstyle: FontStyle.normal,
                            ),
                            const SizedBox(width: 5),
                            MyText(
                              color: style.descTextColor,
                              text: ":",
                              textalign: TextAlign.center,
                              fontsizeNormal: 13,
                              fontweight: FontWeight.w500,
                              fontsizeWeb: 15,
                              maxline: 1,
                              multilanguage: false,
                              overflow: TextOverflow.ellipsis,
                              fontstyle: FontStyle.normal,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: MyText(
                                color: style.descTextColor,
                                text:
                                    "${Constant.currencySymbol}${subHistoryProvider.historyDataList?[position].price.toString()}",
                                textalign: TextAlign.start,
                                fontsizeNormal: 15,
                                fontweight: FontWeight.w700,
                                fontsizeWeb: 14,
                                multilanguage: false,
                                maxline: 1,
                                overflow: TextOverflow.ellipsis,
                                fontstyle: FontStyle.normal,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /* Expire On */
                      Container(
                        constraints: const BoxConstraints(minHeight: 0),
                        margin: const EdgeInsets.only(top: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MyText(
                              color: style.descTextColor,
                              text: _checkExpiry(position)
                                  ? "expire_on"
                                  : "expired_on",
                              textalign: TextAlign.center,
                              fontsizeNormal: 13,
                              fontweight: FontWeight.w500,
                              fontsizeWeb: 15,
                              maxline: 1,
                              multilanguage: true,
                              overflow: TextOverflow.ellipsis,
                              fontstyle: FontStyle.normal,
                            ),
                            const SizedBox(width: 5),
                            MyText(
                              color: style.descTextColor,
                              text: ":",
                              textalign: TextAlign.center,
                              fontsizeNormal: 13,
                              fontweight: FontWeight.w500,
                              fontsizeWeb: 15,
                              maxline: 1,
                              multilanguage: false,
                              overflow: TextOverflow.ellipsis,
                              fontstyle: FontStyle.normal,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: MyText(
                                color: style.descTextColor,
                                text: (subHistoryProvider
                                                .historyDataList?[position]
                                                .expiryDate !=
                                            null ||
                                        (subHistoryProvider
                                                    .historyDataList?[position]
                                                    .expiryDate ??
                                                "") !=
                                            "")
                                    ? (subHistoryProvider
                                            .historyDataList?[position]
                                            .expiryDate
                                            .toString() ??
                                        "")
                                    : "-",
                                textalign: TextAlign.start,
                                fontsizeNormal: 13,
                                fontweight: FontWeight.w700,
                                fontsizeWeb: 14,
                                multilanguage: false,
                                maxline: 5,
                                overflow: TextOverflow.ellipsis,
                                fontstyle: FontStyle.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (subHistoryProvider.historyDataList?[position].expiryDate !=
                      null ||
                  (subHistoryProvider.historyDataList?[position].expiryDate ??
                          "") !=
                      "")
                Container(
                  height: 32,
                  constraints: const BoxConstraints(minWidth: 0),
                  decoration: Utils.setBGWithBorder(
                      style.buttonColor, style.buttonTextColor, 15, 0.5),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                  alignment: Alignment.center,
                  child: MyText(
                    color: style.buttonTextColor,
                    text: _transStatus(position),
                    multilanguage: true,
                    textalign: TextAlign.center,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    fontsizeNormal: 13,
                    fontsizeWeb: 15,
                    fontweight: FontWeight.w700,
                    fontstyle: FontStyle.normal,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TransactionStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color titleTextColor;
  final Color descTextColor;
  final Color buttonColor;
  final Color buttonTextColor;

  const TransactionStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.titleTextColor,
    required this.descTextColor,
    required this.buttonColor,
    required this.buttonTextColor,
  });
}
