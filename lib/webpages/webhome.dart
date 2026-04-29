import 'dart:async';
import 'dart:io';
import '../model/playermodel.dart';
import '../players/model/vdociphermodel.dart';
import '../provider/clipsprovider.dart';
import '../routes/routes_constant.dart';
import '../webwidget/interactive_icon.dart';
import '../webwidget/leftright_scroll_on_hover.dart';
import '../widget/nodata.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'package:carousel_slider/carousel_slider.dart';
import '../model/sectionlistmodel.dart';
import '../provider/generalprovider.dart';
import '../provider/sectionviewallprovider.dart';
import '../webpages/webcomman.dart';
import '../shimmer/shimmerutils.dart';
import '../utils/sharedpre.dart';

import '../model/sectiontypemodel.dart' as type;
import '../model/sectionlistmodel.dart' as list;
import '../model/sectionbannermodel.dart' as banner;
import '../utils/constant.dart';
import '../utils/dimens.dart';
import '../provider/homeprovider.dart';
import '../provider/sectiondataprovider.dart';
import '../utils/color.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';
import '../utils/utils.dart';
import '../widget/mynetworkimg.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WebHome extends StatefulWidget {
  final String? newPage, oldPage;
  final dynamic reqText;
  const WebHome({
    super.key,
    required this.newPage,
    required this.oldPage,
    required this.reqText,
  });

  @override
  State<WebHome> createState() => WebHomeState();
}

class WebHomeState extends State<WebHome> {
  SharedPre sharedPref = SharedPre();
  late SectionDataProvider sectionDataProvider;
  late HomeProvider homeProvider;

  final TextEditingController searchController = TextEditingController();
  CarouselSliderController carouselController = CarouselSliderController();

  bool isSearchEnable = false;
  String? currentPage, langCatName, mSearchText, subscriptionStatus;

  @override
  void initState() {
    super.initState();
    currentPage = widget.newPage ?? "";
    sectionDataProvider =
        Provider.of<SectionDataProvider>(context, listen: false);
    homeProvider = Provider.of<HomeProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();
    });
  }

  Future<void> _getData() async {
    Utils.getCurrencySymbol();
    final generalProvider =
        Provider.of<GeneralProvider>(context, listen: false);

    subscriptionStatus =
        await Utils.configByStatus(status: Constant.subscriptionStatus);
    printLog('_getData subscriptionStatus ===> $subscriptionStatus');

    Constant.userID = await sharedPref.read("userid");
    Constant.userIsKid = await sharedPref.readBool(Constant.profileUserKey);
    printLog('Constant userID =====> ${Constant.userID}');
    printLog('Constant userIsKid ==> ${Constant.userIsKid}');

    await homeProvider.setLoading(true);
    await homeProvider.getSectionType();

    printLog("<===============================>");
    printLog('_getData oldPage ==> ${widget.oldPage}');
    printLog('_getData newPage ==> ${widget.newPage}');
    printLog("<===============================>");
    if (!homeProvider.loading && widget.newPage == RoutesConstant.homePage) {
      if (homeProvider.sectionTypeModel.status == 200 &&
          homeProvider.sectionTypeModel.result != null) {
        if ((homeProvider.sectionTypeModel.result?.length ?? 0) > 0) {
          if ((sectionDataProvider.sectionBannerModel.result?.length ?? 0) ==
                  0 ||
              (sectionDataProvider.sectionList?.length ?? 0) == 0) {
            getTabData(-1, homeProvider.sectionTypeModel.result);
          }
        }
      }
    }

    Future.delayed(Duration.zero).then((value) {
      if (!context.mounted) return;
      setState(() {});
    });
    if (!mounted) return;
    generalProvider.getGeneralsetting(context);
  }

  Future<void> setSelectedTab(int tabPos) async {
    if (!mounted) return;
    homeProvider.setSelectedTab(tabPos);
    printLog("setSelectedTab position ====> $tabPos");
    printLog(
        "setSelectedTab lastTabPos ==> ${sectionDataProvider.lastTabPosition}");
    if (sectionDataProvider.lastTabPosition == tabPos) {
      return;
    } else {
      sectionDataProvider.setTabPosition(tabPos);
    }
  }

  Future<void> getTabData(
      int position, List<type.Result>? sectionTypeList) async {
    await sectionDataProvider.clearOldData();
    sectionDataProvider.setLoading(true);
    final isDefaultTab = position == -1;
    final tabId =
        isDefaultTab ? "0" : (sectionTypeList?[position].id ?? 0).toString();
    final type = isDefaultTab ? "1" : "2";

    await setSelectedTab(isDefaultTab ? 0 : position + 1);

    await Future.wait([
      sectionDataProvider.getSectionBanner(tabId, type),
      sectionDataProvider.getSectionList(tabId, type, 1),
    ]);
  }

  Future<void> openDetailPage(
      int videoId, int subVideoType, int videoType, int typeId) async {
    printLog("videoId =========> $videoId");
    printLog("videoType =======> $videoType");
    printLog("subVideoType ====> $subVideoType");
    printLog("typeId ==========> $typeId");
    if (!mounted) return;
    Utils.openDetails(
      context: context,
      videoId: videoId,
      subVideoType: subVideoType,
      videoType: videoType,
      typeId: typeId,
      newPage: (videoType == Constant.clipsContentType)
          ? RoutesConstant.clipsEpisodesPage
          : RoutesConstant.contentDetailsPage,
      oldPage: widget.newPage ?? "",
      reqText: '',
    );
  }

  /* ========= Open Player ========= */
  Future<void> openPlayer(
      String playType, int index, List<list.Datum>? sectionList) async {
    printLog("index ==========> $index");

    /* CHECK SUBSCRIPTION */
    if (playType != "Trailer") {
      bool? isPrimiumUser = await Utils.checkSubsRentLogin(
        context: context,
        isPremium: sectionList?[index].isPremium ?? 0,
        isBuy: sectionList?[index].isBuy ?? 0,
        isRent: sectionList?[index].isRent ?? 0,
        rentBuy: sectionList?[index].rentBuy ?? 0,
        producerId: (sectionList?[index].producerId ?? 0).toString(),
        videoId: (sectionList?[index].id ?? 0).toString(),
        rentPrice: (sectionList?[index].price ?? 0).toString(),
        vTitle: (sectionList?[index].name ?? 0).toString(),
        typeId: (sectionList?[index].typeId ?? 0).toString(),
        vType: (sectionList?[index].videoType ?? 0).toString(),
        subVideoType: (sectionList?[index].subVideoType ?? 0).toString(),
        rentProductId: (kIsWeb)
            ? (sectionList?[index].webPriceId.toString() ?? '')
            : (Platform.isIOS
                ? (sectionList?[index].iosProductPackage.toString() ?? '')
                : (sectionList?[index].androidProductPackage.toString() ?? '')),
        newPage: widget.newPage ?? "",
        oldPage: widget.oldPage ?? "",
        reqText: widget.reqText ?? "",
      );
      printLog("isPrimiumUser =============> $isPrimiumUser");
      if (!isPrimiumUser) return;
    }
    /* CHECK SUBSCRIPTION */

    if (!mounted) return;
    /* Set-up Quality URLs */
    Utils.setQualityURLs(
      video320: (sectionList?[index].video320 ?? ""),
      video480: (sectionList?[index].video480 ?? ""),
      video720: (sectionList?[index].video720 ?? ""),
      video1080: (sectionList?[index].video1080 ?? ""),
    );

    /* VdoCipher OTP */
    VdoCipherModel? vdocipherDetails;
    if ((sectionList?[index].videoUploadType ?? "") ==
            Constant.vdocipherPlayType &&
        playType != "Trailer") {
      if (!mounted) return;
      vdocipherDetails = await Utils.getVdoCipherOTP(
          context: context,
          videoId: (sectionList?[index].episode != null)
              ? (sectionList?[index].episode?.video320 ?? "")
              : (sectionList?[index].video320 ?? ""));
      printLog(
          "openPlayer vdocipherDetails ======> ${vdocipherDetails?.result?.otp}");
    }
    /* VdoCipher OTP */

    PlayerModel playerModel = PlayerModel(
      playType:
          ((sectionList?[index].videoType ?? 0) == Constant.showContentType ||
                  (sectionList?[index].subVideoType ?? 0) ==
                      Constant.showContentType)
              ? "Show"
              : "Video",
      isLive:
          ((sectionList?[index].videoUploadType ?? "") == "live_stream_url" &&
                  playType != "Trailer")
              ? true
              : false,
      videoId: (sectionList?[index].id ?? 0),
      videoTitle: sectionList?[index].name ?? "",
      videoType: sectionList?[index].videoType ?? 0,
      subVideoType: sectionList?[index].subVideoType ?? 0,
      typeId: sectionList?[index].typeId ?? 0,
      episodeId: (sectionList?[index].episode != null)
          ? (sectionList?[index].episode?.id ?? 0)
          : 0,
      videoUrl: (sectionList?[index].episode != null)
          ? (sectionList?[index].episode?.video320 ?? "")
          : (sectionList?[index].video320 ?? ""),
      cipherMediaDetails:
          (vdocipherDetails != null && vdocipherDetails.result != null)
              ? (vdocipherDetails.result)
              : null,
      trailerUrl: sectionList?[index].trailerUrl ?? "",
      uploadType: sectionList?[index].videoUploadType ?? "",
      videoThumb: sectionList?[index].landscape ?? "",
      stopTime: sectionList?[index].stopTime ?? 0,
      isPremium: sectionList?[index].isPremium ?? 0,
      isBuy: sectionList?[index].isBuy ?? 0,
      isRent: sectionList?[index].isRent ?? 0,
      rentBuy: sectionList?[index].rentBuy ?? 0,
      securityKey: "",
      securityIVKey: null,
      currentEpiPos: 0,
      episodeList: null,
    );

    if (!mounted) return;
    var isContinues =
        await Utils.openPlayer(context: context, playerModel: playerModel);
    if (isContinues != null && isContinues == true) {
      getTabData(0, homeProvider.sectionTypeModel.result);
      Future.delayed(Duration.zero).then((value) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }
  /* ========= Open Player ========= */

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
    if (homeProvider.loading) {
      return ShimmerUtils.buildHomeMobileShimmer(context);
    } else {
      if (homeProvider.sectionTypeModel.status == 200) {
        if (homeProvider.sectionTypeModel.result != null ||
            (homeProvider.sectionTypeModel.result?.length ?? 0) > 0) {
          return _buildTypeTabData(homeProvider.sectionTypeModel.result);
        } else {
          return const SizedBox.shrink();
        }
      } else {
        return const SizedBox.shrink();
      }
    }
  }

  Widget _buildTypeTabData(List<type.Result>? sectionTypeList) {
    return Consumer<SectionDataProvider>(
      builder: (context, sectionDataProvider, child) {
        if ((sectionDataProvider.sectionBannerModel.result == null ||
                (sectionDataProvider.sectionBannerModel.result?.length ?? 0) ==
                    0) &&
            (sectionDataProvider.sectionList?.length ?? 0) == 0 &&
            !sectionDataProvider.loadingBanner &&
            !sectionDataProvider.loadingSection) {
          return const Center(
            child: NoData(title: 'no_data', subTitle: 'no_video_show'),
          );
        } else {
          return _buildBannerSections();
        }
      },
    );
  }

  Widget _buildBannerSections() {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      child: Column(
        children: [
          /* Banner */
          if (sectionDataProvider.loadingBanner)
            if (Dimens.isBigScreen(context))
              ShimmerUtils.bannerWeb(context)
            else
              ShimmerUtils.bannerMobile(context)
          else if (sectionDataProvider.sectionBannerModel.status == 200 &&
              sectionDataProvider.sectionBannerModel.result != null)
            if (Dimens.isBigScreen(context))
              _tvHomeBanner(sectionDataProvider.sectionBannerModel.result)
            else
              _mobileHomeBanner(sectionDataProvider.sectionBannerModel.result)
          else
            SizedBox(height: Dimens.homeTabHeight),

          /* Continue Watching & Remaining Sections */
          if (sectionDataProvider.loadingSection &&
              !sectionDataProvider.loadMore)
            sectionShimmer()
          else if (sectionDataProvider.sectionList != null &&
              (sectionDataProvider.sectionList?.length ?? 0) > 0)
            setSectionByType(sectionDataProvider.sectionList)
          else
            const SizedBox.shrink(),

          /* Pagination loader */
          if (sectionDataProvider.loadMore)
            ShimmerUtils.sectionPortraitListView(context)
          else
            const SizedBox.shrink(),
          SizedBox(height: Dimens.homeTabHeight),
        ],
      ),
    );
  }

  /* Banner START ************** */
  Widget _tvHomeBanner(List<banner.Result>? sectionBannerList) {
    if ((sectionBannerList?.length ?? 0) > 0) {
      return SizedBox(
        width: MediaQuery.of(context).size.width,
        height: Dimens.getResponsiveHeight(context, 0),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CarouselSlider.builder(
              itemCount: (sectionBannerList?.length ?? 0),
              carouselController: carouselController,
              options: CarouselOptions(
                initialPage: 0,
                height: Dimens.getResponsiveHeight(context, 0),
                enlargeCenterPage: false,
                autoPlay: true,
                autoPlayCurve: Curves.easeInOutQuart,
                enableInfiniteScroll: true,
                autoPlayInterval:
                    Duration(milliseconds: Constant.bannerDuration),
                autoPlayAnimationDuration:
                    Duration(milliseconds: Constant.animationDuration),
                viewportFraction: 1.0,
                onPageChanged: (val, _) async {
                  sectionDataProvider.setCurrentBanner(val);
                },
              ),
              itemBuilder:
                  (BuildContext context, int index, int pageViewIndex) {
                return InkWell(
                  focusColor: white,
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionBannerList?[index].id ?? 0,
                      sectionBannerList?[index].subVideoType ?? 0,
                      sectionBannerList?[index].videoType ?? 0,
                      sectionBannerList?[index].typeId ?? 0,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: Dimens.getResponsiveHeight(context, 0),
                          child: MyNetworkImage(
                            imageUrl: (sectionBannerList?[index].landscape ==
                                        null ||
                                    (sectionBannerList?[index].landscape ?? "")
                                        .isEmpty ||
                                    (sectionBannerList?[index].landscape ?? "")
                                        .contains("no_img"))
                                ? (sectionBannerList?[index].thumbnail ?? "")
                                : (sectionBannerList?[index].landscape ?? ""),
                            fit: BoxFit.fill,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(0),
                          width: MediaQuery.of(context).size.width * 0.5,
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                appBgColor,
                                appBgColor.withValues(alpha: 0.9),
                                appBgColor.withValues(alpha: 0.7),
                                appBgColor.withValues(alpha: 0.5),
                                appBgColor.withValues(alpha: 0.3),
                                appBgColor.withValues(alpha: 0.1),
                                transparent,
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(0),
                          width: MediaQuery.of(context).size.width,
                          transform: Matrix4.translationValues(0, 1, 0),
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.center,
                              colors: [
                                appBgColor,
                                appBgColor.withValues(alpha: 0.9),
                                appBgColor.withValues(alpha: 0.7),
                                appBgColor.withValues(alpha: 0.5),
                                appBgColor.withValues(alpha: 0.3),
                                appBgColor.withValues(alpha: 0.1),
                                transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 35,
                          bottom: 35,
                          child: Container(
                            width: Dimens.isBigScreen(context)
                                ? (MediaQuery.of(context).size.width * 0.35)
                                : (MediaQuery.of(context).size.width * 0.5),
                            constraints: const BoxConstraints(minHeight: 0),
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  color: white,
                                  text: (sectionBannerList?[index].name !=
                                              null &&
                                          sectionBannerList?[index].name != "")
                                      ? (sectionBannerList?[index].name ?? "")
                                      : "-",
                                  textalign: TextAlign.start,
                                  fontsizeNormal: 33,
                                  fontsizeWeb: 33,
                                  fontweight: FontWeight.w700,
                                  multilanguage: false,
                                  maxline: 2,
                                  overflow: TextOverflow.ellipsis,
                                  fontstyle: FontStyle.normal,
                                  isShadowText: true,
                                ),
                                const SizedBox(height: 12),
                                /* Category */
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                      const EdgeInsets.only(top: 5, bottom: 5),
                                  child: MyText(
                                    color: descTextColor,
                                    text: Utils.convertHalfStopToVLine(
                                        sectionBannerList?[index]
                                                .categoryName ??
                                            ""),
                                    textalign: TextAlign.start,
                                    fontsizeNormal: 13,
                                    fontweight: FontWeight.w500,
                                    fontsizeWeb: 15,
                                    multilanguage: false,
                                    maxline: 1,
                                    overflow: TextOverflow.ellipsis,
                                    fontstyle: FontStyle.normal,
                                    isShadowText: true,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: MediaQuery.of(context).size.width,
                                  constraints:
                                      const BoxConstraints(minHeight: 0),
                                  margin: const EdgeInsets.only(top: 8),
                                  alignment: Alignment.centerLeft,
                                  child: ExpandableText(
                                    sectionBannerList?[index].description ?? "",
                                    expandText: "",
                                    collapseText: "",
                                    maxLines:
                                        Dimens.isBigScreen(context) ? 2 : 3,
                                    linkColor: descTextColor,
                                    expandOnTextTap: true,
                                    collapseOnTextTap: true,
                                    style: kIsWeb
                                        ? TextStyle(
                                            fontSize:
                                                Dimens.isBigScreen(context)
                                                    ? 15
                                                    : 14,
                                            fontStyle: FontStyle.normal,
                                            color: descTextColor,
                                            fontWeight: FontWeight.normal,
                                          )
                                        : GoogleFonts.inter(
                                            textStyle: TextStyle(
                                              fontSize:
                                                  Dimens.isBigScreen(context)
                                                      ? 15
                                                      : 14,
                                              fontStyle: FontStyle.normal,
                                              color: descTextColor,
                                              fontWeight: FontWeight.normal,
                                            ),
                                          ),
                                  ),
                                ),
                                /* Watch Now */
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildBannerWatchNow(
                                      index, sectionBannerList),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            /* Dots */
            Positioned(
              bottom: Dimens.getResponsiveHeight(context, 0) / 5,
              right: 80,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                decoration:
                    Utils.setBackground(appBgColor.withValues(alpha: 0.6), 20),
                child: AnimatedSmoothIndicator(
                  count: (sectionBannerList?.length ?? 0),
                  activeIndex: sectionDataProvider.cBannerIndex ?? 0,
                  effect: const ScrollingDotsEffect(
                    spacing: 12,
                    radius: 10,
                    activeDotScale: 1.2,
                    activeDotColor: colorAccent,
                    dotColor: defaultIconColor,
                    dotHeight: 10,
                    dotWidth: 10,
                  ),
                  onDotClicked: (index) async {
                    await carouselController.animateToPage(index);
                    sectionDataProvider.setCurrentBanner(index);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _mobileHomeBanner(List<banner.Result>? sectionBannerList) {
    if ((sectionBannerList?.length ?? 0) > 0) {
      return Stack(
        alignment: AlignmentDirectional.bottomCenter,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        children: [
          /* Poster */
          SizedBox(
            height: Dimens.getBannerHeight(context),
            child: InkWell(
              focusColor: white,
              borderRadius: BorderRadius.circular(0),
              onTap: () {
                printLog(
                    "Clicked on index ==> ${sectionDataProvider.cBannerIndex}");
                openDetailPage(
                  sectionBannerList?[(sectionDataProvider.cBannerIndex ?? 0)]
                          .id ??
                      0,
                  sectionBannerList?[(sectionDataProvider.cBannerIndex ?? 0)]
                          .subVideoType ??
                      0,
                  sectionBannerList?[(sectionDataProvider.cBannerIndex ?? 0)]
                          .videoType ??
                      0,
                  sectionBannerList?[(sectionDataProvider.cBannerIndex ?? 0)]
                          .typeId ??
                      0,
                );
              },
              child: Stack(
                alignment: AlignmentDirectional.bottomCenter,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: Dimens.getBannerHeight(context),
                    margin: const EdgeInsets.only(bottom: 15),
                    child: MyNetworkImage(
                      imageUrl: sectionBannerList?[
                                  (sectionDataProvider.cBannerIndex ?? 0)]
                              .thumbnail ??
                          "",
                      fit: BoxFit.fill,
                    ),
                  ),
                  /* Top Gradient */
                  Container(
                    padding: const EdgeInsets.all(0),
                    width: MediaQuery.of(context).size.width,
                    height: Dimens.getBannerHeight(context),
                    alignment: Alignment.topCenter,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          appBgColor.withValues(alpha: 0.9),
                          appBgColor.withValues(alpha: 0.5),
                          appBgColor.withValues(alpha: 0.1),
                          transparent,
                          transparent,
                          transparent,
                        ],
                      ),
                    ),
                  ),
                  /* Bottom Gradient */
                  Container(
                    padding: const EdgeInsets.all(0),
                    width: MediaQuery.of(context).size.width,
                    height: Dimens.getBannerHeight(context),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [
                          transparent,
                          transparent,
                          transparent,
                          transparent,
                          appBgColor.withValues(alpha: 0.1),
                          appBgColor.withValues(alpha: 0.3),
                          appBgColor.withValues(alpha: 0.5),
                          appBgColor.withValues(alpha: 0.7),
                          appBgColor.withValues(alpha: 0.9),
                          appBgColor,
                          appBgColor,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          /* Text */
          SizedBox(
            width: MediaQuery.of(context).size.width,
            height: Dimens.getBannerHeight(context),
            child: CarouselSlider.builder(
              itemCount: (sectionBannerList?.length ?? 0),
              carouselController: carouselController,
              options: CarouselOptions(
                initialPage: 0,
                height: Dimens.getBannerHeight(context),
                enlargeCenterPage: false,
                enableInfiniteScroll:
                    (sectionBannerList?.length ?? 0) > 1 ? true : false,
                autoPlay: true,
                autoPlayCurve: Curves.linear,
                autoPlayInterval:
                    Duration(milliseconds: Constant.bannerDuration),
                autoPlayAnimationDuration:
                    Duration(milliseconds: Constant.animationDuration),
                viewportFraction: 1.0,
                onPageChanged: (val, _) async {
                  sectionDataProvider.setCurrentBanner(val);
                },
              ),
              itemBuilder:
                  (BuildContext context, int index, int pageViewIndex) {
                return InkWell(
                  focusColor: white,
                  borderRadius: BorderRadius.circular(0),
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionBannerList?[index].id ?? 0,
                      sectionBannerList?[index].subVideoType ?? 0,
                      sectionBannerList?[index].videoType ?? 0,
                      sectionBannerList?[index].typeId ?? 0,
                    );
                  },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 50),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        /* Name */
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          child: MyText(
                            color: white,
                            text: (sectionBannerList?[index].name != null &&
                                    sectionBannerList?[index].name != "")
                                ? (sectionBannerList?[index].name ?? "")
                                : "-",
                            textalign: TextAlign.center,
                            fontsizeNormal: 23,
                            fontsizeWeb: 23,
                            fontweight: FontWeight.w700,
                            multilanguage: false,
                            maxline: 2,
                            overflow: TextOverflow.ellipsis,
                            fontstyle: FontStyle.normal,
                            isShadowText: true,
                          ),
                        ),

                        /* Languages */
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 5, 20, 0),
                          alignment: Alignment.center,
                          child: MyText(
                            color: white,
                            text: (sectionBannerList?[index].totalLanguage !=
                                        null &&
                                    (sectionBannerList?[index].totalLanguage ??
                                            0) >
                                        0)
                                ? ("${(sectionBannerList?[index].totalLanguage ?? 0)} ${((sectionBannerList?[index].totalLanguage ?? 0) == 1) ? "Language" : "Languages"}")
                                : "-",
                            textalign: TextAlign.center,
                            fontsizeNormal: 12,
                            fontsizeWeb: 14,
                            fontweight: FontWeight.w600,
                            multilanguage: false,
                            maxline: 1,
                            overflow: TextOverflow.ellipsis,
                            fontstyle: FontStyle.normal,
                            isShadowText: true,
                          ),
                        ),
                        /* Category */
                        Container(
                          margin: const EdgeInsets.fromLTRB(20, 3, 20, 30),
                          alignment: Alignment.center,
                          child: MyText(
                            color: white,
                            text: (sectionBannerList?[index].categoryName !=
                                        null &&
                                    sectionBannerList?[index].categoryName !=
                                        "")
                                ? ((sectionBannerList?[index].categoryName ??
                                        "")
                                    .replaceAll(
                                        RegExp('[,]'), ' ${Constant.dotText}'))
                                : "-",
                            textalign: TextAlign.center,
                            fontsizeNormal: 12,
                            fontsizeWeb: 14,
                            fontweight: FontWeight.w700,
                            multilanguage: false,
                            maxline: 2,
                            overflow: TextOverflow.ellipsis,
                            fontstyle: FontStyle.normal,
                            isShadowText: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          /* Buttons & Dots */
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /* Watch Now */
                  _buildBannerWatchNow(
                      sectionDataProvider.cBannerIndex ?? 0, sectionBannerList),
                  /* Dots */
                  AnimatedSmoothIndicator(
                    count: (sectionBannerList?.length ?? 0),
                    activeIndex: sectionDataProvider.cBannerIndex ?? 0,
                    effect: const ScrollingDotsEffect(
                      spacing: 8,
                      radius: 4,
                      activeDotScale: 1.2,
                      activeDotColor: colorPrimary,
                      dotColor: defaultIconColor,
                      dotHeight: 6,
                      dotWidth: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildBannerWatchNow(
      int index, List<banner.Result>? sectionBannerList) {
    return Container(
      height: Dimens.isBigScreen(context) ? 50 : 45,
      alignment: Alignment.center,
      margin: Dimens.isBigScreen(context)
          ? const EdgeInsets.fromLTRB(0, 30, 0, 20)
          : const EdgeInsets.fromLTRB(15, 15, 15, 15),
      child: Row(
        mainAxisAlignment: Dimens.isBigScreen(context)
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          /* Watch Now / Subscription */
          InteractiveIcon(builder: (isHovered) {
            return Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () {
                  openDetailPage(
                    sectionBannerList?[index].id ?? 0,
                    sectionBannerList?[index].subVideoType ?? 0,
                    sectionBannerList?[index].videoType ?? 0,
                    sectionBannerList?[index].typeId ?? 0,
                  );
                },
                focusColor: white,
                borderRadius: BorderRadius.circular(10),
                child: FittedBox(
                  child: Container(
                    height: Dimens.isBigScreen(context) ? 50 : 45,
                    padding: const EdgeInsets.fromLTRB(40, 2, 40, 2),
                    decoration: Dimens.isBigScreen(context)
                        ? Utils.setBackground(white.withValues(alpha: 0.1), 8)
                        : Utils.setBackground(secondaryBgColor, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        MyImage(
                          width: 15,
                          height: 15,
                          imagePath: "ic_play.png",
                        ),
                        const SizedBox(width: 15),
                        MyText(
                          color: white,
                          text: "watch_now",
                          multilanguage: true,
                          fontsizeNormal: 14,
                          fontweight: FontWeight.w400,
                          fontsizeWeb: 15,
                          maxline: 1,
                          overflow: TextOverflow.ellipsis,
                          fontstyle: FontStyle.normal,
                          textalign: TextAlign.start,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 20),
          /* Add to Watchlist */
          InteractiveIcon(builder: (isHovered) {
            return Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () async {
                  if (Constant.userID != null) {
                    await sectionDataProvider.setBookMark(
                        context, (sectionDataProvider.cBannerIndex ?? 0));
                  } else {
                    Utils.openLogin(
                        context: context, newPage: widget.newPage ?? "");
                  }
                },
                focusColor: white,
                borderRadius: BorderRadius.circular(10),
                child: FittedBox(
                  child: Container(
                    height: Dimens.isBigScreen(context) ? 50 : 45,
                    width: Dimens.isBigScreen(context) ? 50 : 45,
                    decoration: Dimens.isBigScreen(context)
                        ? Utils.setBackground(white.withValues(alpha: 0.1), 8)
                        : Utils.setBackground(secondaryBgColor, 10),
                    padding: const EdgeInsets.all(16),
                    child: MyImage(
                      imagePath: (sectionBannerList?[
                                          (sectionDataProvider.cBannerIndex ??
                                              0)]
                                      .isBookmark ??
                                  0) ==
                              1
                          ? "ic_tick.png"
                          : "ic_plus.png",
                      color: white,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
  /* **************** Banner END */

  /* Sections START ************** */
  Widget setSectionByType(List<list.Result>? sectionList) {
    return ListView.builder(
      itemCount: sectionList?.length ?? 0,
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, 15, 0, 0),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        if (sectionList?[index].data != null &&
            (sectionList?[index].data?.length ?? 0) > 0) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleViewAll(
                sectionList: sectionList,
                index: index,
                onViewAllClick: () async {
                  printLog("viewAll ====> ${sectionList?[index].viewAll}");
                  final sectionViewAllProvider =
                      Provider.of<SectionViewAllProvider>(context,
                          listen: false);
                  if ((sectionList?[index].viewAll ?? 0) == 1) {
                    sectionViewAllProvider.setLoading(true);
                    if (!context.mounted) return;
                    context.go(
                      "/${RoutesConstant.sectionDetailsPage}/${(sectionList?[index].id ?? 0)}/${(sectionList?[index].videoType ?? 0)}",
                      extra: {
                        'newpage': widget.newPage.toString(),
                        'itemid': (sectionList?[index].id ?? 0).toString(),
                        'title': sectionList?[index].title ?? '',
                        'screenlayout': sectionList?[index].screenLayout ?? '',
                        'videotype':
                            (sectionList?[index].videoType ?? 0).toString(),
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: getRemainingDataHeight(
                  sectionList?[index].videoType.toString() ?? "",
                  sectionList?[index].screenLayout ?? "",
                  sectionList,
                  index,
                ),
                child: setSectionData(sectionList: sectionList, index: index),
              ),
              SizedBox(height: Dimens.isBigScreen(context) ? 40 : 25),
            ],
          );
        } else {
          if ((sectionDataProvider.sectionBannerModel.result == null ||
                  (sectionDataProvider.sectionBannerModel.result?.length ??
                          0) ==
                      0) &&
              (sectionDataProvider.sectionList != null &&
                  (sectionDataProvider.sectionList?.length ?? 0) == 1) &&
              !sectionDataProvider.loadingBanner &&
              !sectionDataProvider.loadingSection) {
            return const Center(
              child: NoData(title: 'no_data', subTitle: 'no_video_show'),
            );
          } else {
            return const SizedBox.shrink();
          }
        }
      },
    );
  }

  Widget _buildTitleViewAll({
    required List<list.Result>? sectionList,
    required int index,
    required Function()? onViewAllClick,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(Dimens.isBigScreen(context) ? 35 : 20, 0,
          Dimens.isBigScreen(context) ? 35 : 20, 0),
      child: InkWell(
        onTap:
            ((sectionList?[index].viewAll ?? 0) == 1) ? onViewAllClick : null,
        borderRadius: BorderRadius.circular(3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if ((sectionList?[index].videoType ?? 0) ==
                          Constant.channelType)
                        Container(
                          alignment: Alignment.centerRight,
                          height: 17,
                          width: 17,
                          margin: const EdgeInsets.only(right: 2),
                          child: MyImage(
                            imagePath: "ic_fire.png",
                            fit: BoxFit.contain,
                          ),
                        ),
                      if ((sectionList?[index].videoType ?? 0) ==
                          Constant.clipsContentType)
                        Container(
                          alignment: Alignment.centerRight,
                          height: 17,
                          width: 17,
                          margin: const EdgeInsets.only(right: 2),
                          child: MyImage(
                            imagePath: "ic_clips.png",
                            fit: BoxFit.contain,
                            color: colorAccent,
                          ),
                        ),
                      Container(
                        alignment: Alignment.centerLeft,
                        child: MyText(
                          color: titleTextColor,
                          text: sectionList?[index].title.toString() ?? "",
                          textalign: TextAlign.start,
                          fontsizeNormal: 16,
                          fontsizeWeb: 18,
                          fontweight: FontWeight.w600,
                          multilanguage: false,
                          maxline: 1,
                          overflow: TextOverflow.ellipsis,
                          fontstyle: FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                  if ((sectionList?[index].shortTitle.toString() ?? "")
                      .isNotEmpty)
                    Container(
                      alignment: Alignment.centerLeft,
                      child: MyText(
                        color: descTextColor,
                        text: sectionList?[index].shortTitle.toString() ?? "",
                        textalign: TextAlign.start,
                        fontsizeNormal: 12,
                        fontweight: FontWeight.w400,
                        fontsizeWeb: 16,
                        multilanguage: false,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        fontstyle: FontStyle.normal,
                      ),
                    ),
                ],
              ),
            ),
            if ((sectionList?[index].viewAll ?? 0) == 1)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    alignment: Alignment.centerRight,
                    child: MyText(
                      color: titleTextColor,
                      text: "viewall",
                      textalign: TextAlign.center,
                      fontsizeNormal: 14,
                      fontweight: FontWeight.w500,
                      fontsizeWeb: 16,
                      multilanguage: true,
                      maxline: 1,
                      overflow: TextOverflow.ellipsis,
                      fontstyle: FontStyle.normal,
                    ),
                  ),
                  Container(
                    height: 25,
                    width: 25,
                    padding: const EdgeInsets.all(5),
                    alignment: Alignment.centerRight,
                    child: MyImage(
                      imagePath: "ic_viewall.png",
                      fit: BoxFit.contain,
                      color: descTextColor,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget setSectionData(
      {required List<list.Result>? sectionList, required int index}) {
    /* screen_layout =>  landscape, big_landscape, index_landscape, portrait, big_portrait, index_portrait, 
                         square, category, language, channel */
    if ((sectionList?[index].screenLayout ?? "") == "landscape") {
      return _buildLandscapeUI(sectionList?[index].videoType,
          sectionList?[index].data, sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "big_landscape") {
      return _buildLandscapeBigUI(sectionList?[index].videoType,
          sectionList?[index].data, sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "index_landscape") {
      return _buildLandscapeIndexUI(sectionList?[index].videoType,
          sectionList?[index].data, sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "portrait") {
      return _buildPortraitUI(sectionList?[index].videoType,
          sectionList?[index].data, sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "big_portrait") {
      return _buildPortraitBigUI(sectionList?[index].videoType,
          sectionList?[index].data, sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "index_portrait") {
      return _buildPortraitIndexUI(sectionList?[index].videoType,
          sectionList?[index].data, sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "square") {
      return _buildSquareUI(sectionList?[index].videoType,
          sectionList?[index].data, sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "shorts") {
      return _buildShortsUI(
        sectionList?[index].id,
        sectionList?[index].data,
        sectionList?[index].scrollController,
      );
    } else if ((sectionList?[index].screenLayout ?? "") == "category") {
      return _buildGenresUI(
          sectionList?[index].videoType,
          sectionList?[index].typeId ?? 0,
          sectionList?[index].data,
          sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "language") {
      return _buildLanguageUI(
          sectionList?[index].videoType,
          sectionList?[index].typeId ?? 0,
          sectionList?[index].data,
          sectionList?[index].scrollController);
    } else if ((sectionList?[index].screenLayout ?? "") == "channel") {
      return _buildChannelUI(
          sectionList?[index].videoType,
          sectionList?[index].typeId ?? 0,
          sectionList?[index].data,
          sectionList?[index].scrollController);
    } else {
      return _buildLandscapeUI(sectionList?[index].videoType,
          sectionList?[index].data, sectionList?[index].scrollController);
    }
  }

  double getRemainingDataHeight(
    String? videoType,
    String? layoutType,
    List<list.Result>? sectionList,
    int index,
  ) {
    if (layoutType == "landscape" || layoutType == "index_landscape") {
      return Dimens.isBigScreen(context)
          ? Dimens.heightLandWeb
          : Dimens.heightLand;
    } else if (layoutType == "big_landscape") {
      return Dimens.isBigScreen(context)
          ? Dimens.heightLandBigWeb
          : Dimens.heightLandBig;
    } else if (layoutType == "portrait" || layoutType == "index_portrait") {
      return Dimens.isBigScreen(context)
          ? Dimens.heightPortWeb
          : Dimens.heightPort;
    } else if (layoutType == "big_portrait") {
      return Dimens.isBigScreen(context)
          ? Dimens.heightPortBigWeb
          : Dimens.heightPortBig;
    } else if (layoutType == "square") {
      return Dimens.isBigScreen(context)
          ? Dimens.heightSquareWeb
          : Dimens.heightSquare;
    } else if (layoutType == "shorts") {
      return ((sectionList?[index].data?.length ?? 0) < 4)
          ? (Dimens.heightShortsTotalWeb)
          : (Dimens.heightShortsTotalWeb * 2);
    } else if (layoutType == "category") {
      return Dimens.isBigScreen(context)
          ? Dimens.heightGenWeb
          : Dimens.heightGen;
    } else if (layoutType == "language") {
      return Dimens.isBigScreen(context)
          ? Dimens.heightLangWeb
          : Dimens.heightLang;
    } else if (layoutType == "channel") {
      return ((sectionList?[index].data?.length ?? 0) < 13)
          ? (Dimens.isBigScreen(context)
              ? Dimens.heightChannelTotalWeb
              : Dimens.heightChannelTotal)
          : ((Dimens.isBigScreen(context)
                  ? Dimens.heightChannelTotalWeb
                  : Dimens.heightChannelTotal) *
              2);
    } else {
      return Dimens.isBigScreen(context)
          ? Dimens.heightLandWeb
          : Dimens.heightLand;
    }
  }

  /* Continue Watching START ************** */
  Widget _buildContinueWatchingUI(
      int? videoType, int index, List<Datum>? sectionDataList) {
    if (videoType != 8) {
      if (sectionDataList?[index].isTitle == 0) {
        return const SizedBox.shrink();
      }
      return Container(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
        alignment: Alignment.bottomLeft,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        decoration: Utils.setGradTTBBGWithCenter(
            transparent, appBgColor.withValues(alpha: 0.1), appBgColor, 0),
        child: MyText(
          color: white,
          multilanguage: false,
          text: sectionDataList?[index].name.toString() ?? "",
          fontsizeNormal: 13,
          fontweight: FontWeight.w600,
          fontsizeWeb: 15,
          maxline: 1,
          overflow: TextOverflow.ellipsis,
          textalign: TextAlign.start,
          fontstyle: FontStyle.normal,
        ),
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        /* Bottom Gradient */
        Container(
          padding: const EdgeInsets.all(0),
          width: MediaQuery.of(context).size.width,
          height: Dimens.getBannerHeight(context),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [
                transparent,
                transparent,
                transparent,
                appBgColor.withValues(alpha: 0.1),
                appBgColor.withValues(alpha: 0.5),
                appBgColor.withValues(alpha: 0.9),
                appBgColor,
              ],
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8, right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  openPlayer("ContinueWatch", index, sectionDataList);
                },
                child: Row(
                  children: [
                    MyImage(
                      width: 20,
                      height: 20,
                      imagePath: "play.png",
                    ),
                    if (sectionDataList?[index].isTitle != 0)
                      const SizedBox(width: 10),
                    if (sectionDataList?[index].isTitle == 0)
                      const SizedBox.shrink()
                    else
                      Expanded(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          child: MyText(
                            color: white,
                            multilanguage: false,
                            text: sectionDataList?[index].name.toString() ?? "",
                            fontsizeNormal: 13,
                            fontweight: FontWeight.w600,
                            fontsizeWeb: 15,
                            maxline: 1,
                            overflow: TextOverflow.ellipsis,
                            textalign: TextAlign.start,
                            fontstyle: FontStyle.normal,
                            isShadowText: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              constraints:
                  BoxConstraints(minWidth: MediaQuery.of(context).size.width),
              padding: const EdgeInsets.all(0),
              child: LinearPercentIndicator(
                padding: const EdgeInsets.all(0),
                barRadius: const Radius.circular(2),
                lineHeight: 4,
                percent: Utils.getPercentage(
                    (sectionDataList?[index].episode != null)
                        ? (sectionDataList?[index].episode?.videoDuration ?? 0)
                        : (sectionDataList?[index].videoDuration ?? 0),
                    sectionDataList?[index].stopTime ?? 0),
                backgroundColor: secProgressColor,
                progressColor: colorPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
  /* **************** Continue Watching END */

  Widget _buildLandscapeUI(
    int? videoType,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.isBigScreen(context)
          ? Dimens.heightLandWeb
          : Dimens.heightLand,
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthLandWeb
            : Dimens.widthLand,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightLandWeb
            : Dimens.heightLand,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: ListView.separated(
          controller: scrollController,
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 35 : 20,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          scrollDirection: Axis.horizontal,
          separatorBuilder: (context, index) =>
              SizedBox(width: Dimens.spaceBetweenCardsWeb),
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
                width: Dimens.isBigScreen(context)
                    ? Dimens.widthLandWeb
                    : Dimens.widthLand,
                height: Dimens.isBigScreen(context)
                    ? Dimens.heightLandWeb
                    : Dimens.heightLand,
                child: InkWell(
                  focusColor: white,
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionDataList?[index].id ?? 0,
                      sectionDataList?[index].subVideoType ?? 0,
                      sectionDataList?[index].videoType ?? 0,
                      sectionDataList?[index].typeId ?? 0,
                    );
                  },
                  child: Stack(
                    alignment: AlignmentDirectional.bottomStart,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(Dimens.cardRadiusMedium),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: MyNetworkImage(
                          imageUrl:
                              sectionDataList?[index].landscape.toString() ??
                                  "",
                          fit: BoxFit.fill,
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 0,
                        child: Utils.buildRentPremiumTAG(
                          context: context,
                          isPremium: sectionDataList?[index].isPremium ?? 0,
                          isRent: sectionDataList?[index].isRent ?? 0,
                          rentPrice: sectionDataList?[index].price ?? 0,
                        ),
                      ),
                      _buildContinueWatchingUI(
                          videoType, index, sectionDataList),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeIndexUI(
    int? videoType,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.isBigScreen(context)
          ? Dimens.heightLandWeb
          : Dimens.heightLand,
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthLandWeb
            : Dimens.widthLand,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightLandWeb
            : Dimens.heightLand,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: AlignedGridView.count(
          controller: scrollController,
          shrinkWrap: true,
          crossAxisCount: 1,
          mainAxisSpacing: 40,
          itemCount: (sectionDataList?.length ?? 0),
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 55 : 40,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          physics: const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemBuilder: (BuildContext context, index) {
            return Stack(
              alignment: Alignment.centerLeft,
              children: [
                /* Image */
                InkWell(
                  borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionDataList?[index].id ?? 0,
                      sectionDataList?[index].subVideoType ?? 0,
                      sectionDataList?[index].videoType ?? 0,
                      sectionDataList?[index].typeId ?? 0,
                    );
                  },
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(Dimens.cardRadiusMedium),
                    child: MyNetworkImage(
                      width: Dimens.isBigScreen(context)
                          ? Dimens.widthLandWeb
                          : Dimens.widthLand,
                      height: Dimens.isBigScreen(context)
                          ? Dimens.heightLandWeb
                          : Dimens.heightLand,
                      fit: BoxFit.fill,
                      imageUrl:
                          sectionDataList?[index].landscape.toString() ?? "",
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 0,
                  child: Utils.buildRentPremiumTAG(
                    context: context,
                    isPremium: sectionDataList?[index].isPremium ?? 0,
                    isRent: sectionDataList?[index].isRent ?? 0,
                    rentPrice: sectionDataList?[index].price ?? 0,
                  ),
                ),
                /* Count */
                Container(
                  transform: Dimens.isBigScreen(context)
                      ? Matrix4.translationValues(-13, 0, 0)
                      : Matrix4.translationValues(-15, 0, 0),
                  child: Text(
                    "${index + 1}",
                    style: kIsWeb
                        ? TextStyle(
                            fontSize: Dimens.isBigScreen(context) ? 85 : 60,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth =
                                  Dimens.isBigScreen(context) ? 8 : 6
                              ..color = colorPrimary.withValues(alpha: 0.4),
                          )
                        : GoogleFonts.inter(
                            textStyle: TextStyle(
                              fontSize: Dimens.isBigScreen(context) ? 85 : 60,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth =
                                    Dimens.isBigScreen(context) ? 8 : 6
                                ..color = colorPrimary.withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                ),
                Container(
                  transform: Dimens.isBigScreen(context)
                      ? Matrix4.translationValues(-20, 0, 0)
                      : Matrix4.translationValues(-19, 0, 0),
                  child: Text(
                    "${index + 1}",
                    style: kIsWeb
                        ? TextStyle(
                            fontSize: Dimens.isBigScreen(context) ? 85 : 60,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth =
                                  Dimens.isBigScreen(context) ? 8 : 6
                              ..color = colorPrimary,
                          )
                        : GoogleFonts.inter(
                            textStyle: TextStyle(
                              fontSize: Dimens.isBigScreen(context) ? 85 : 60,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth =
                                    Dimens.isBigScreen(context) ? 8 : 6
                                ..color = colorPrimary,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLandscapeBigUI(
    int? videoType,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.isBigScreen(context)
          ? Dimens.heightLandBigWeb
          : Dimens.heightLandBig,
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthLandBigWeb
            : Dimens.widthLandBig,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightLandBigWeb
            : Dimens.heightLandBig,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: ListView.separated(
          controller: scrollController,
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 35 : 20,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          scrollDirection: Axis.horizontal,
          separatorBuilder: (context, index) =>
              SizedBox(width: Dimens.spaceBetweenCardsWeb),
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
                width: Dimens.isBigScreen(context)
                    ? Dimens.widthLandBigWeb
                    : Dimens.widthLandBig,
                height: Dimens.isBigScreen(context)
                    ? Dimens.heightLandBigWeb
                    : Dimens.heightLandBig,
                child: InkWell(
                  focusColor: white,
                  borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionDataList?[index].id ?? 0,
                      sectionDataList?[index].subVideoType ?? 0,
                      sectionDataList?[index].videoType ?? 0,
                      sectionDataList?[index].typeId ?? 0,
                    );
                  },
                  child: Stack(
                    alignment: AlignmentDirectional.bottomStart,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(Dimens.cardRadiusMedium),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: MyNetworkImage(
                          imageUrl:
                              sectionDataList?[index].landscape.toString() ??
                                  "",
                          fit: BoxFit.fill,
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 0,
                        child: Utils.buildRentPremiumTAG(
                          context: context,
                          isPremium: sectionDataList?[index].isPremium ?? 0,
                          isRent: sectionDataList?[index].isRent ?? 0,
                          rentPrice: sectionDataList?[index].price ?? 0,
                        ),
                      ),
                      _buildContinueWatchingUI(
                          videoType, index, sectionDataList),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitUI(
    int? videoType,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.isBigScreen(context)
          ? Dimens.heightPortWeb
          : Dimens.heightPort,
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthPortWeb
            : Dimens.widthPort,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightPortWeb
            : Dimens.heightPort,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: ListView.separated(
          controller: scrollController,
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 35 : 20,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          separatorBuilder: (context, index) =>
              SizedBox(width: Dimens.spaceBetweenCardsWeb),
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
                width: Dimens.isBigScreen(context)
                    ? Dimens.widthPortWeb
                    : Dimens.widthPort,
                height: Dimens.isBigScreen(context)
                    ? Dimens.heightPortWeb
                    : Dimens.heightPort,
                child: InkWell(
                  focusColor: white,
                  borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionDataList?[index].id ?? 0,
                      sectionDataList?[index].subVideoType ?? 0,
                      sectionDataList?[index].videoType ?? 0,
                      sectionDataList?[index].typeId ?? 0,
                    );
                  },
                  child: Stack(
                    alignment: AlignmentDirectional.bottomStart,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(Dimens.cardRadiusMedium),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: MyNetworkImage(
                          imageUrl:
                              sectionDataList?[index].thumbnail.toString() ??
                                  "",
                          fit: BoxFit.fill,
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 0,
                        child: Utils.buildRentPremiumTAG(
                          context: context,
                          isPremium: sectionDataList?[index].isPremium ?? 0,
                          isRent: sectionDataList?[index].isRent ?? 0,
                          rentPrice: sectionDataList?[index].price ?? 0,
                        ),
                      ),
                      _buildContinueWatchingUI(
                          videoType, index, sectionDataList),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitBigUI(
    int? videoType,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.isBigScreen(context)
          ? Dimens.heightPortBigWeb
          : Dimens.heightPortBig,
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthPortBigWeb
            : Dimens.widthPortBig,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightPortBigWeb
            : Dimens.heightPortBig,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: ListView.separated(
          controller: scrollController,
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 35 : 20,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          separatorBuilder: (context, index) =>
              SizedBox(width: Dimens.spaceBetweenCardsWeb),
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
                width: Dimens.isBigScreen(context)
                    ? Dimens.widthPortBigWeb
                    : Dimens.widthPortBig,
                height: Dimens.isBigScreen(context)
                    ? Dimens.heightPortBigWeb
                    : Dimens.heightPortBig,
                child: InkWell(
                  focusColor: white,
                  borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionDataList?[index].id ?? 0,
                      sectionDataList?[index].subVideoType ?? 0,
                      sectionDataList?[index].videoType ?? 0,
                      sectionDataList?[index].typeId ?? 0,
                    );
                  },
                  child: Stack(
                    alignment: AlignmentDirectional.bottomStart,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(Dimens.cardRadiusMedium),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: MyNetworkImage(
                          imageUrl:
                              sectionDataList?[index].thumbnail.toString() ??
                                  "",
                          fit: BoxFit.fill,
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 0,
                        child: Utils.buildRentPremiumTAG(
                          context: context,
                          isPremium: sectionDataList?[index].isPremium ?? 0,
                          isRent: sectionDataList?[index].isRent ?? 0,
                          rentPrice: sectionDataList?[index].price ?? 0,
                        ),
                      ),
                      _buildContinueWatchingUI(
                          videoType, index, sectionDataList),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitIndexUI(
    int? videoType,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.isBigScreen(context)
          ? Dimens.heightPortWeb
          : Dimens.heightPort,
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthPortWeb
            : Dimens.widthPort,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightPortWeb
            : Dimens.heightPort,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: AlignedGridView.count(
          controller: scrollController,
          shrinkWrap: true,
          crossAxisCount: 1,
          mainAxisSpacing: 35,
          itemCount: (sectionDataList?.length ?? 0),
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 56 : 35,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          physics: const AlwaysScrollableScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemBuilder: (BuildContext context, index) {
            return Stack(
              alignment: Alignment.bottomLeft,
              children: [
                /* Image */
                InkWell(
                  borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionDataList?[index].id ?? 0,
                      sectionDataList?[index].subVideoType ?? 0,
                      sectionDataList?[index].videoType ?? 0,
                      sectionDataList?[index].typeId ?? 0,
                    );
                  },
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(Dimens.cardRadiusMedium),
                    child: MyNetworkImage(
                      width: Dimens.isBigScreen(context)
                          ? Dimens.widthPortWeb
                          : Dimens.widthPort,
                      height: Dimens.isBigScreen(context)
                          ? Dimens.heightPortWeb
                          : Dimens.heightPort,
                      fit: BoxFit.fill,
                      imageUrl:
                          sectionDataList?[index].thumbnail.toString() ?? "",
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 0,
                  child: Utils.buildRentPremiumTAG(
                    context: context,
                    isPremium: sectionDataList?[index].isPremium ?? 0,
                    isRent: sectionDataList?[index].isRent ?? 0,
                    rentPrice: sectionDataList?[index].price ?? 0,
                  ),
                ),
                /* Count */
                Container(
                  transform: Dimens.isBigScreen(context)
                      ? Matrix4.translationValues(-13, 20, 0)
                      : Matrix4.translationValues(-11, 15, 0),
                  child: Text(
                    "${index + 1}",
                    style: kIsWeb
                        ? TextStyle(
                            fontSize: Dimens.isBigScreen(context) ? 80 : 55,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth =
                                  Dimens.isBigScreen(context) ? 8 : 5
                              ..color = colorPrimary.withValues(alpha: 0.4),
                          )
                        : GoogleFonts.inter(
                            textStyle: TextStyle(
                              fontSize: Dimens.isBigScreen(context) ? 80 : 55,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth =
                                    Dimens.isBigScreen(context) ? 8 : 5
                                ..color = colorPrimary.withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                ),
                Container(
                  transform: Dimens.isBigScreen(context)
                      ? Matrix4.translationValues(-20, 20, 0)
                      : Matrix4.translationValues(-15, 15, 0),
                  child: Text(
                    "${index + 1}",
                    style: kIsWeb
                        ? TextStyle(
                            fontSize: Dimens.isBigScreen(context) ? 80 : 55,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth =
                                  Dimens.isBigScreen(context) ? 8 : 5
                              ..color = colorPrimary,
                          )
                        : GoogleFonts.inter(
                            textStyle: TextStyle(
                              fontSize: Dimens.isBigScreen(context) ? 80 : 55,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth =
                                    Dimens.isBigScreen(context) ? 8 : 5
                                ..color = colorPrimary,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSquareUI(
    int? videoType,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.isBigScreen(context)
          ? Dimens.heightSquareWeb
          : Dimens.heightSquare,
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthSquareWeb
            : Dimens.widthSquare,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightSquareWeb
            : Dimens.heightSquare,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: ListView.separated(
          controller: scrollController,
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 35 : 20,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          separatorBuilder: (context, index) =>
              SizedBox(width: Dimens.spaceBetweenCardsWeb),
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
                width: Dimens.isBigScreen(context)
                    ? Dimens.widthSquareWeb
                    : Dimens.widthSquare,
                height: Dimens.isBigScreen(context)
                    ? Dimens.heightSquareWeb
                    : Dimens.heightSquare,
                child: InkWell(
                  focusColor: white,
                  borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
                  onTap: () {
                    printLog("Clicked on index ==> $index");
                    openDetailPage(
                      sectionDataList?[index].id ?? 0,
                      sectionDataList?[index].subVideoType ?? 0,
                      sectionDataList?[index].videoType ?? 0,
                      sectionDataList?[index].typeId ?? 0,
                    );
                  },
                  child: Stack(
                    alignment: AlignmentDirectional.bottomStart,
                    children: [
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(Dimens.cardRadiusMedium),
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        child: MyNetworkImage(
                          imageUrl:
                              sectionDataList?[index].thumbnail.toString() ??
                                  "",
                          fit: BoxFit.cover,
                          height: MediaQuery.of(context).size.height,
                          width: MediaQuery.of(context).size.width,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 0,
                        child: Utils.buildRentPremiumTAG(
                          context: context,
                          isPremium: sectionDataList?[index].isPremium ?? 0,
                          isRent: sectionDataList?[index].isRent ?? 0,
                          rentPrice: sectionDataList?[index].price ?? 0,
                        ),
                      ),
                      _buildContinueWatchingUI(
                          videoType, index, sectionDataList),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShortsUI(
    int? sectionId,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: ((sectionDataList?.length ?? 0) < 4)
          ? (Dimens.heightShortsTotalWeb)
          : (Dimens.heightShortsTotalWeb * 2),
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: 10,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthShortsWeb
            : Dimens.widthShorts,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightShortsWeb
            : Dimens.heightShorts,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: AlignedGridView.count(
            itemCount: sectionDataList?.length ?? 0,
            shrinkWrap: true,
            crossAxisCount: ((sectionDataList?.length ?? 0) < 4) ? 1 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            padding: EdgeInsets.only(
                left: Dimens.isBigScreen(context) ? 35 : 20,
                right: Dimens.isBigScreen(context) ? 35 : 20),
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext context, int index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
                  width: Dimens.isBigScreen(context)
                      ? Dimens.widthShortsWeb
                      : Dimens.widthShorts,
                  height: Dimens.isBigScreen(context)
                      ? Dimens.heightShortsWeb
                      : Dimens.heightShorts,
                  child: InkWell(
                    focusColor: white,
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final clipsProvider =
                          Provider.of<ClipsProvider>(context, listen: false);

                      int typeId = sectionDataList?[index].typeId ?? 0;
                      int videoType = sectionDataList?[index].videoType ?? 0;
                      int videoId = sectionDataList?[index].id ?? 0;
                      int subVideoType = 0;
                      printLog("Clicked on index ======> $index");
                      printLog("Clicked on sectionId ==> $sectionId");
                      printLog("Clicked on typeId =====> $typeId");
                      printLog("Clicked on videoType ==> $videoType");
                      printLog("Clicked on videoId ====> $videoId");
                      try {
                        clipsProvider.setEpiLoading(true);
                        clipsProvider.getShortsDetails(
                            typeId, videoType, videoId, subVideoType,
                            forceRefresh: true);
                      } on Exception catch (e) {
                        printLog("_buildFeatureIcon Episode Exception => $e");
                      }

                      openDetailPage(videoId, subVideoType, videoType, typeId);
                    },
                    child: Stack(
                      alignment: AlignmentDirectional.bottomStart,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          child: MyNetworkImage(
                            imageUrl:
                                sectionDataList?[index].thumbnail.toString() ??
                                    "",
                            fit: BoxFit.fill,
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                          ),
                        ),
                        Container(
                          alignment: Alignment.bottomLeft,
                          padding: EdgeInsets.all(8),
                          clipBehavior: Clip.antiAliasWithSaveLayer,
                          decoration: Utils.setGradTTBBGWithCenter(
                              transparent,
                              transparent,
                              appBgColor.withValues(alpha: 0.8),
                              0),
                          child: MyText(
                            color: white,
                            multilanguage: false,
                            text: sectionDataList?[index].name.toString() ?? "",
                            fontsizeNormal: 13,
                            fontsizeWeb: 15,
                            fontweight: FontWeight.w600,
                            maxline: 2,
                            overflow: TextOverflow.ellipsis,
                            textalign: TextAlign.start,
                            fontstyle: FontStyle.normal,
                            isShadowText: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChannelUI(
    int? videoType,
    int? typeId,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: ((sectionDataList?.length ?? 0) < 13)
          ? (Dimens.isBigScreen(context)
              ? Dimens.heightChannelTotalWeb
              : Dimens.heightChannelTotal)
          : ((Dimens.isBigScreen(context)
                  ? Dimens.heightChannelTotalWeb
                  : Dimens.heightChannelTotal) *
              2),
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthChannelWeb
            : Dimens.widthChannel,
        height: ((sectionDataList?.length ?? 0) < 13)
            ? (Dimens.isBigScreen(context)
                ? Dimens.heightChannelTotalWeb
                : Dimens.heightChannelTotal)
            : ((Dimens.isBigScreen(context)
                    ? Dimens.heightChannelTotalWeb
                    : Dimens.heightChannelTotal) *
                2),
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: AlignedGridView.count(
          controller: scrollController,
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          crossAxisCount: ((sectionDataList?.length ?? 0) < 13) ? 1 : 2,
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 35 : 20,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          scrollDirection: Axis.horizontal,
          crossAxisSpacing: Dimens.spaceBetweenCardsWeb,
          mainAxisSpacing: Dimens.spaceBetweenCardsWeb,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: InkWell(
                borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
                focusColor: white,
                onTap: () async {
                  printLog("Clicked on index ==> $index");
                  if (!mounted) return;
                  context.go(
                    "/${RoutesConstant.videoByChannelPage}/${(sectionDataList?[index].id ?? 0)}",
                    extra: {
                      'newpage': widget.newPage.toString(),
                      'itemid': (sectionDataList?[index].id ?? 0).toString(),
                      'title': sectionDataList?[index].name ?? '',
                      'layouttype': 'ByChannel',
                    },
                  );
                },
                child: Container(
                  alignment: Alignment.center,
                  height: Dimens.isBigScreen(context)
                      ? Dimens.heightChannelWeb
                      : Dimens.heightChannel,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(Dimens.cardRadiusMedium),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: MyNetworkImage(
                      imageUrl:
                          sectionDataList?[index].landscapeImg.toString() ?? "",
                      fit: BoxFit.fill,
                      width: Dimens.isBigScreen(context)
                          ? Dimens.widthChannelWeb
                          : Dimens.widthChannel,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguageUI(
    int? videoType,
    int? typeId,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.isBigScreen(context)
          ? Dimens.heightLangWeb
          : Dimens.heightLang,
      child: LeftRightScrollOnHover(
        scrollController: scrollController,
        itemCount: (sectionDataList?.length ?? 0),
        itemSpacing: Dimens.spaceBetweenCardsWeb,
        itemWidth: Dimens.isBigScreen(context)
            ? Dimens.widthLangWeb
            : Dimens.widthLang,
        height: Dimens.isBigScreen(context)
            ? Dimens.heightLangWeb
            : Dimens.heightLang,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: ListView.separated(
          controller: scrollController,
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 35 : 20,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          scrollDirection: Axis.horizontal,
          separatorBuilder: (context, index) =>
              SizedBox(width: Dimens.spaceBetweenLangCatWeb),
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular((Dimens.isBigScreen(context)
                      ? Dimens.heightLangWeb
                      : Dimens.heightLang) /
                  2),
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: InkWell(
                borderRadius: BorderRadius.circular((Dimens.isBigScreen(context)
                        ? Dimens.heightLangWeb
                        : Dimens.heightLang) /
                    2),
                focusColor: white,
                onTap: () async {
                  printLog("Clicked on index ==> $index");
                  if (!mounted) return;
                  context.go(
                    "/${RoutesConstant.videoByLanguagePage}/${(sectionDataList?[index].id ?? 0)}",
                    extra: {
                      'newpage': widget.newPage.toString(),
                      'itemid': (sectionDataList?[index].id ?? 0).toString(),
                      'title': sectionDataList?[index].name ?? '',
                      'layouttype': 'ByLanguage',
                    },
                  );
                },
                child: Container(
                  height: Dimens.isBigScreen(context)
                      ? Dimens.heightLangWeb
                      : Dimens.heightLang,
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        (Dimens.isBigScreen(context)
                                ? Dimens.heightLangWeb
                                : Dimens.heightLang) /
                            2),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: MyNetworkImage(
                      imageUrl: sectionDataList?[index].image.toString() ?? "",
                      fit: BoxFit.contain,
                      width: Dimens.isBigScreen(context)
                          ? Dimens.widthLangWeb
                          : Dimens.widthLang,
                      height: Dimens.isBigScreen(context)
                          ? Dimens.heightLangWeb
                          : Dimens.heightLang,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGenresUI(
    int? videoType,
    int? typeId,
    List<Datum>? sectionDataList,
    ScrollController? scrollController,
  ) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height:
          Dimens.isBigScreen(context) ? Dimens.heightGenWeb : Dimens.heightGen,
      child: LeftRightScrollOnHover(
        height: Dimens.isBigScreen(context)
            ? Dimens.heightGenWeb
            : Dimens.heightGen,
        scrollController: scrollController,
        itemSpacing: Dimens.spaceBetweenLangCatWeb,
        itemCount: (sectionDataList?.length ?? 0),
        itemWidth:
            Dimens.isBigScreen(context) ? Dimens.widthGenWeb : Dimens.widthGen,
        onLeftTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: false,
              scrollController: scrollController,
            );
          }
        },
        onRightTap: () {
          if (scrollController != null) {
            Utils.scrollContentView(
              context: context,
              forward: true,
              scrollController: scrollController,
            );
          }
        },
        child: ListView.separated(
          controller: scrollController,
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
              left: Dimens.isBigScreen(context) ? 35 : 20,
              right: Dimens.isBigScreen(context) ? 35 : 20),
          scrollDirection: Axis.horizontal,
          separatorBuilder: (context, index) =>
              SizedBox(width: Dimens.spaceBetweenLangCatWeb),
          itemBuilder: (BuildContext context, int index) {
            return Container(
              width: Dimens.isBigScreen(context)
                  ? Dimens.widthGenWeb
                  : Dimens.widthGen,
              height: Dimens.isBigScreen(context)
                  ? Dimens.heightGenWeb
                  : Dimens.heightGen,
              alignment: Alignment.center,
              child: InkWell(
                focusColor: white,
                borderRadius: BorderRadius.circular((Dimens.isBigScreen(context)
                        ? Dimens.widthGenWeb
                        : Dimens.widthGen) /
                    2),
                onTap: () async {
                  printLog("Clicked on index ==> $index");
                  if (!mounted) return;
                  context.go(
                    "/${RoutesConstant.videoByCatPage}/${(sectionDataList?[index].id ?? 0)}",
                    extra: {
                      'newpage': widget.newPage.toString(),
                      'itemid': (sectionDataList?[index].id ?? 0).toString(),
                      'title': sectionDataList?[index].name ?? '',
                      'layouttype': 'ByCategory',
                    },
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                      (Dimens.isBigScreen(context)
                              ? Dimens.widthGenWeb
                              : Dimens.widthGen) /
                          2),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: MyNetworkImage(
                    imageUrl: sectionDataList?[index].image.toString() ?? "",
                    fit: BoxFit.cover,
                    width: Dimens.isBigScreen(context)
                        ? Dimens.widthGenWeb
                        : Dimens.widthGen,
                    height: Dimens.isBigScreen(context)
                        ? Dimens.heightGenWeb
                        : Dimens.heightGen,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  /* ***************** Sections END */

  /* Section Shimmer */
  Widget sectionShimmer() {
    return ListView.builder(
      itemCount: 10, // itemCount must be greater than 5
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        if (index == 1) {
          return ShimmerUtils.setHomeSections(context, "portrait");
        } else if (index == 2) {
          return ShimmerUtils.setHomeSections(context, "square");
        } else if (index == 3) {
          return ShimmerUtils.setHomeSections(context, "langGen");
        } else {
          return ShimmerUtils.setHomeSections(context, "landscape");
        }
      },
    );
  }
}
