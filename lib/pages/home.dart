import 'dart:async';
import 'dart:io';
import 'package:carousel_slider/carousel_slider.dart';
import '../model/playermodel.dart';
import '../pages/sectionviewall.dart';
import '../pages/contentbyid.dart';
import '../pages/settings.dart';
import '../players/model/vdociphermodel.dart';
import '../provider/bottombarprovider.dart';
import '../provider/connectivityprovider.dart';
import '../provider/profileprovider.dart';
import '../provider/sectionviewallprovider.dart';
import '../provider/videobyidprovider.dart';
import '../routes/routes_constant.dart';
import '../shimmer/shimmerutils.dart';
import '../utils/adhelper.dart';
import '../model/sectionlistmodel.dart';
import '../model/sectiontypemodel.dart' as type;
import '../model/sectionlistmodel.dart' as list;
import '../model/sectionbannermodel.dart' as banner;
import '../utils/constant.dart';
import '../utils/dimens.dart';
import '../widget/morehomedialog.dart';
import '../widget/myusernetworkimg.dart';
import '../widget/nodata.dart';
import '../provider/homeprovider.dart';
import '../provider/sectiondataprovider.dart';
import '../utils/color.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';
import '../utils/utils.dart';
import '../widget/mynetworkimg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:scrollview_observer/scrollview_observer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class Home extends StatefulWidget {
  final String? pageName;
  const Home({super.key, required this.pageName});

  @override
  State<Home> createState() => HomeState();
}

class HomeState extends State<Home> {
  late HomeProvider homeProvider;
  late BottombarProvider bottombarProvider;
  late SectionDataProvider sectionDataProvider;
  late VideoByIDProvider videoByIDProvider;
  late ConnectivityProvider connectivityProvider;
  CarouselSliderController carouselController = CarouselSliderController();
  final nestedScrollController = ScrollController();
  final tabScrollController = ScrollController();
  late ListObserverController observerController;
  String? currentPage, subscriptionStatus;

  Future<void> _nestedScrollListener() async {
    if (!nestedScrollController.hasClients) return;
    if (nestedScrollController.offset >=
            nestedScrollController.position.maxScrollExtent &&
        !nestedScrollController.position.outOfRange &&
        (sectionDataProvider.isMorePage ?? false)) {
      sectionDataProvider.setLoadMore(true);
      _fetchSectionData(sectionDataProvider.currentPage ?? 0);
    }
  }

  Future<void> _fetchSectionData(int? nextPage) async {
    printLog("_fetchSectionData nextPage  ========> $nextPage");
    printLog(
        "_fetchSectionData isMorePage  ======> ${sectionDataProvider.isMorePage}");
    printLog(
        "_fetchSectionData currentPage ======> ${sectionDataProvider.currentPage}");
    printLog(
        "_fetchSectionData totalPage   ======> ${sectionDataProvider.totalPage}");

    await sectionDataProvider.getSectionList(
        (homeProvider.selectedIndex == -1)
            ? 0
            : (homeProvider
                    .sectionTypeModel.result?[homeProvider.selectedIndex].id ??
                0),
        (homeProvider.selectedIndex == -1) ? "1" : "2",
        (nextPage ?? 0) + 1);
    printLog(
        "sectionList length ==> ${sectionDataProvider.sectionList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    nestedScrollController.addListener(_nestedScrollListener);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: transparent,
        systemNavigationBarColor: secondaryBgColor,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    videoByIDProvider = Provider.of<VideoByIDProvider>(context, listen: false);
    connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    sectionDataProvider =
        Provider.of<SectionDataProvider>(context, listen: false);
    bottombarProvider = Provider.of<BottombarProvider>(context, listen: false);
    homeProvider = Provider.of<HomeProvider>(context, listen: false);
    observerController =
        ListObserverController(controller: tabScrollController);
    currentPage = widget.pageName ?? "";
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();
    });
  }

  Future _getData() async {
    subscriptionStatus =
        await Utils.configByStatus(status: Constant.subscriptionStatus);
    printLog('_getData subscriptionStatus ===> $subscriptionStatus');
    await homeProvider.setLoading(true);
    if (connectivityProvider.isOnline) {
      await homeProvider.getSectionType();

      if (!homeProvider.loading) {
        printLog(
            '_getData sectionBanner ===> ${sectionDataProvider.sectionBannerModel.result?.length}');
        printLog(
            '_getData sectionList =====> ${sectionDataProvider.sectionList?.length}');
        if (homeProvider.sectionTypeModel.status == 200 &&
            homeProvider.sectionTypeModel.result != null) {
          if ((homeProvider.sectionTypeModel.result?.length ?? 0) > 0) {
            if ((sectionDataProvider.sectionBannerModel.result?.length ?? 0) ==
                    0 ||
                (sectionDataProvider.sectionList?.length ?? 0) == 0) {
              printLog('_getData INITIAL Fetching');
              getTabData(-1, homeProvider.sectionTypeModel.result);
            }
          }
        }
      }
    }
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
    if (connectivityProvider.isOnline) {
      await Future.wait([
        homeProvider.getGenres(),
        homeProvider.getChannel(),
        homeProvider.getLanguage(),
      ]);
    }
    Utils.getCurrencySymbol();
  }

  Future<void> setSelectedTab(int tabPos) async {
    printLog("setSelectedTab tabPos ====> $tabPos");
    if (!mounted) return;
    homeProvider.setSelectedTab(tabPos);
    printLog(
        "setSelectedTab selectedIndex ====> ${homeProvider.selectedIndex}");
    printLog(
        "setSelectedTab lastTabPosition ====> ${sectionDataProvider.lastTabPosition}");
    if (sectionDataProvider.lastTabPosition == tabPos) {
      return;
    } else {
      sectionDataProvider.setTabPosition(tabPos);
    }
  }

  Future<void> getTabData(
      int position, List<type.Result>? sectionTypeList) async {
    printLog("getTabData position ====> $position");
    try {
      await sectionDataProvider.clearOldData();
      sectionDataProvider.setLoading(true);
      await bottombarProvider.setAppbarVisibility(true);

      if (nestedScrollController.hasClients) {
        await nestedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
        );
      }

      final isDefaultTab = position == -1;
      final tabId =
          isDefaultTab ? "0" : (sectionTypeList?[position].id ?? 0).toString();
      final type = isDefaultTab ? "1" : "2";

      // set selected tab index
      await setSelectedTab(isDefaultTab ? -1 : position);

      // parallel API calls
      await Future.wait([
        sectionDataProvider.getSectionBanner(tabId, type),
        sectionDataProvider.getSectionList(tabId, type, 1),
      ]);
    } on Exception catch (e) {
      printLog("getTabData Error :====>  $e");
    }
  }

  Future<void> openDetailPage(
      int videoId, int subVideoType, int videoType, int typeId) async {
    printLog("videoId ========> $videoId");
    printLog("subVideoType ===> $subVideoType");
    printLog("videoType ======> $videoType");
    printLog("typeId =========> $typeId");
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
      oldPage: '',
      reqText: '',
    );
  }

  /* ========= Open Player ========= */
  Future<void> openPlayer(
      String playType, int position, List<Datum>? continueWatchingList) async {
    printLog("position ==========> $position");

    /* CHECK SUBSCRIPTION */
    if (playType != "Trailer") {
      bool? isPrimiumUser = await Utils.checkSubsRentLogin(
        context: context,
        isPremium: continueWatchingList?[position].isPremium ?? 0,
        isBuy: continueWatchingList?[position].isBuy ?? 0,
        isRent: continueWatchingList?[position].isRent ?? 0,
        rentBuy: continueWatchingList?[position].rentBuy ?? 0,
        producerId:
            (continueWatchingList?[position].producerId ?? 0).toString(),
        videoId: (continueWatchingList?[position].id ?? 0).toString(),
        rentPrice: (continueWatchingList?[position].price ?? 0).toString(),
        vTitle: (continueWatchingList?[position].name ?? 0).toString(),
        typeId: (continueWatchingList?[position].typeId ?? 0).toString(),
        vType: (continueWatchingList?[position].videoType ?? 0).toString(),
        subVideoType:
            (continueWatchingList?[position].subVideoType ?? 0).toString(),
        rentProductId: (kIsWeb)
            ? (continueWatchingList?[position].webPriceId.toString() ?? '')
            : (Platform.isIOS
                ? (continueWatchingList?[position]
                        .iosProductPackage
                        .toString() ??
                    '')
                : (continueWatchingList?[position]
                        .androidProductPackage
                        .toString() ??
                    '')),
        newPage: '',
        oldPage: '',
        reqText: '',
      );
      printLog("isPrimiumUser =============> $isPrimiumUser");
      if (!isPrimiumUser) return;
    }
    /* CHECK SUBSCRIPTION */

    /* Set-up Quality URLs */
    Utils.setQualityURLs(
      video320: (continueWatchingList?[position].video320 ?? ""),
      video480: (continueWatchingList?[position].video480 ?? ""),
      video720: (continueWatchingList?[position].video720 ?? ""),
      video1080: (continueWatchingList?[position].video1080 ?? ""),
    );

    /* VdoCipher OTP */
    VdoCipherModel? vdocipherDetails;
    if ((continueWatchingList?[position].videoUploadType ?? "") ==
            Constant.vdocipherPlayType &&
        playType != "Trailer") {
      if (!mounted) return;
      vdocipherDetails = await Utils.getVdoCipherOTP(
          context: context,
          videoId: (continueWatchingList?[position].episode != null)
              ? (continueWatchingList?[position].episode?.video320 ?? "")
              : (continueWatchingList?[position].video320 ?? ""));
      printLog(
          "openPlayer vdocipherDetails ======> ${vdocipherDetails?.result?.otp}");
    }
    /* VdoCipher OTP */

    PlayerModel playerModel = PlayerModel(
      playType: ((continueWatchingList?[position].videoType ?? 0) ==
                  Constant.showContentType ||
              (continueWatchingList?[position].subVideoType ?? 0) ==
                  Constant.showContentType)
          ? "Show"
          : "Video",
      isLive: ((continueWatchingList?[position].videoUploadType ?? "") ==
                  "live_stream_url" &&
              playType != "Trailer")
          ? true
          : false,
      videoId: (continueWatchingList?[position].id ?? 0),
      videoTitle: continueWatchingList?[position].name ?? "",
      videoType: continueWatchingList?[position].videoType ?? 0,
      subVideoType: continueWatchingList?[position].subVideoType ?? 0,
      typeId: continueWatchingList?[position].typeId ?? 0,
      episodeId: (continueWatchingList?[position].episode != null)
          ? (continueWatchingList?[position].episode?.id ?? 0)
          : 0,
      videoUrl: (continueWatchingList?[position].episode != null)
          ? (continueWatchingList?[position].episode?.video320 ?? "")
          : (continueWatchingList?[position].video320 ?? ""),
      cipherMediaDetails:
          (vdocipherDetails != null && vdocipherDetails.result != null)
              ? (vdocipherDetails.result)
              : null,
      trailerUrl: continueWatchingList?[position].trailerUrl ?? "",
      uploadType: continueWatchingList?[position].videoUploadType ?? "",
      videoThumb: continueWatchingList?[position].landscape ?? "",
      stopTime: continueWatchingList?[position].stopTime ?? 0,
      isPremium: continueWatchingList?[position].isPremium ?? 0,
      isBuy: continueWatchingList?[position].isBuy ?? 0,
      isRent: continueWatchingList?[position].isRent ?? 0,
      rentBuy: continueWatchingList?[position].rentBuy ?? 0,
      securityKey: "",
      securityIVKey: null,
      currentEpiPos: 0,
      episodeList: null,
    );
    if (!mounted) return;
    AdHelper.showFullscreenAd(
      context,
      Constant.interstialAdType,
      () async {
        dynamic isContinue = await Utils.openPlayer(
          context: context,
          playerModel: playerModel,
        );
        printLog("isContinue ===> $isContinue");
        if (isContinue != null && isContinue == true) {
          await getTabData(-1, homeProvider.sectionTypeModel.result);
          Future.delayed(Duration.zero).then((value) {
            if (!mounted) return;
            setState(() {});
          });
        }
      },
    );
  }
  /* ========= Open Player ========= */

  void _openMoreDialog() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      backgroundColor: transparent,
      builder: (BuildContext context) {
        return const Wrap(
          alignment: WrapAlignment.center,
          children: [
            MoreHomeDialog(),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollToCurrent() {
    if (homeProvider.selectedIndex == -1) return;
    observerController.animateTo(
      index: homeProvider.selectedIndex,
      curve: Curves.easeInOut,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (!mounted) return false;
          if (nestedScrollController.position.userScrollDirection ==
                  ScrollDirection.reverse &&
              sectionDataProvider.sectionList != null &&
              (sectionDataProvider.sectionList?.length ?? 0) > 2) {
            bottombarProvider.setAppbarVisibility(false);
          } else if (nestedScrollController.position.userScrollDirection ==
              ScrollDirection.forward) {
            bottombarProvider.setAppbarVisibility(true);
          }
          return true;
        },
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: Consumer2<HomeProvider, BottombarProvider>(
                  builder: (context, homeProvider, bottombarProvider, child) {
                    return _buildAppBar(innerBoxIsScrolled);
                  },
                ),
              ),
            ];
          },
          body: _buildPageUI(),
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      centerTitle: false,
      automaticallyImplyLeading: false,
      toolbarHeight: kToolbarHeight,
      titleSpacing: 0,
      backgroundColor: transparent,
      flexibleSpace: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: bottombarProvider.isShowAppbar ? 0.0 : 1.0,
        child: ClipRRect(
          child: Container(
            color: appBgColor.withValues(alpha: 0.8),
          ),
        ),
      ),
      leadingWidth: 100,
      leading: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          splashColor: transparent,
          highlightColor: transparent,
          onTap: () async {
            // await getTabData(-1, homeProvider.sectionTypeModel.result);
          },
          child: MyImage(
            imagePath: "appicon.png",
          ),
        ),
      ),
      title: _buildAppBarSubscribeBtn(),
      actions: [
        Container(
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.only(right: 15),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            splashColor: transparent,
            highlightColor: transparent,
            onTap: () async {
              await Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return const Settings();
                  },
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return child;
                  },
                ),
              );
            },
            child: Consumer<ProfileProvider>(
              builder: (context, profileProvider, child) {
                if (profileProvider.profileModel.result != null &&
                    (profileProvider.profileModel.result?.length ?? 0) > 0) {
                  return Align(
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: (Constant.userIsKid == true)
                          ? MyImage(
                              imagePath: 'kids.png',
                              fit: BoxFit.cover,
                              width: 23,
                              height: 23,
                            )
                          : MyUserNetworkImage(
                              imageUrl: profileProvider
                                      .profileModel.result?[0].image ??
                                  "",
                              fit: BoxFit.cover,
                              width: 23,
                              height: 23,
                            ),
                    ),
                  );
                } else {
                  return MyImage(
                    width: 20,
                    height: 20,
                    imagePath: "ic_stuff.png",
                    color: white,
                  );
                }
              },
            ),
          ),
        ),
      ],
      pinned: true,
      floating: true,
      expandedHeight: 0,
      forceElevated: innerBoxIsScrolled,
    );
  }

  Widget _buildAppBarSubscribeBtn() {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        if (Constant.userIsKid == false &&
            (subscriptionStatus != null && subscriptionStatus == "1")) {
          return Container(
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(40),
              onTap: () async {
                if (Constant.userID != null) {
                  Utils.openSubscription(
                    context: context,
                    oldPage: RoutesConstant.homePage,
                  );
                } else {
                  Utils.openLogin(context: context, newPage: "");
                }
              },
              child: FittedBox(
                child: Container(
                  height: 30,
                  alignment: Alignment.centerLeft,
                  decoration: Utils.subscribeGradBorderBG(
                      (profileProvider.profileModel.result != null &&
                          (profileProvider.profileModel.result?.length ?? 0) >
                              0 &&
                          (profileProvider.profileModel.result?[0].isBuy ??
                                  0) ==
                              1),
                      40,
                      1),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (profileProvider.profileModel.result != null &&
                          (profileProvider.profileModel.result?.length ?? 0) >
                              0 &&
                          (profileProvider.profileModel.result?[0].isBuy ??
                                  0) !=
                              1)
                        MyImage(
                          width: 15,
                          height: 15,
                          imagePath: "ic_subscribe.png",
                          withShaderMask: true,
                        ),
                      if (profileProvider.profileModel.result != null &&
                          (profileProvider.profileModel.result?.length ?? 0) >
                              0 &&
                          (profileProvider.profileModel.result?[0].isBuy ??
                                  0) !=
                              1)
                        const SizedBox(width: 4),
                      MyText(
                        color: (profileProvider.profileModel.result != null &&
                                (profileProvider.profileModel.result?.length ??
                                        0) >
                                    0 &&
                                (profileProvider
                                            .profileModel.result?[0].isBuy ??
                                        0) ==
                                    1)
                            ? white
                            : colorPrimary,
                        text: (profileProvider.profileModel.result != null &&
                                (profileProvider.profileModel.result?.length ??
                                        0) >
                                    0 &&
                                (profileProvider
                                            .profileModel.result?[0].isBuy ??
                                        0) ==
                                    1)
                            ? (profileProvider
                                    .profileModel.result?[0].packageName ??
                                "")
                            : "subscribe",
                        multilanguage: (profileProvider.profileModel.result !=
                                    null &&
                                (profileProvider.profileModel.result?.length ??
                                        0) >
                                    0 &&
                                (profileProvider
                                            .profileModel.result?[0].isBuy ??
                                        0) ==
                                    1)
                            ? false
                            : true,
                        fontsizeNormal: 12,
                        fontsizeWeb: 15,
                        maxline: 1,
                        fontweight: FontWeight.w700,
                        textalign: TextAlign.start,
                        overflow: TextOverflow.ellipsis,
                        fontstyle: FontStyle.normal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildPageUI() {
    if (homeProvider.loading) {
      return ShimmerUtils.buildHomeMobileShimmer(context);
    } else {
      if (homeProvider.sectionTypeModel.status == 200) {
        if (homeProvider.sectionTypeModel.result != null ||
            (homeProvider.sectionTypeModel.result?.length ?? 0) > 0) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              /* Banner & Sections */
              Consumer<SectionDataProvider>(
                builder: (context, sectionDataProvider, child) {
                  if ((sectionDataProvider.sectionBannerModel.result == null ||
                          (sectionDataProvider
                                      .sectionBannerModel.result?.length ??
                                  0) ==
                              0) &&
                      (sectionDataProvider.sectionList?.length ?? 0) == 0 &&
                      !sectionDataProvider.loadingBanner &&
                      !sectionDataProvider.loadingSection) {
                    return const Center(
                      child:
                          NoData(title: 'no_data', subTitle: 'no_video_show'),
                    );
                  } else {
                    return _buildTypeTabData(
                        homeProvider.sectionTypeModel.result);
                  }
                },
              ),

              /* Types */
              FittedBox(
                child: Container(
                  height: Dimens.homeTabHeightSmall,
                  padding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
                  margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  child: _buildTypeTabs(homeProvider.sectionTypeModel.result),
                ),
              ),
            ],
          );
        } else {
          return const Center(
            child: NoData(title: 'no_data', subTitle: 'no_video_show'),
          );
        }
      } else {
        return const Center(
          child: NoData(title: 'no_data', subTitle: 'no_video_show'),
        );
      }
    }
  }

  /* Type START ************** */
  Widget _buildTypeTabs(List<type.Result>? sectionTypeList) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        if (homeProvider.selectedIndex != -1) {
          return _buildSelectedTypeView(sectionTypeList);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (tabScrollController.hasClients) {
              _scrollToCurrent();
            }
          });
          return Visibility(
            visible: (homeProvider.selectedIndex == -1),
            maintainAnimation: true,
            maintainState: true,
            child: AnimatedOpacity(
              opacity: (homeProvider.selectedIndex == -1) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 1000),
              child: ListViewObserver(
                controller: observerController,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 30),
                  decoration: Utils.setBGWithBorder(
                      secondaryBgColor, transparent, Dimens.menuRadius, 0),
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                  child: ListView.separated(
                    itemCount: (sectionTypeList?.length ?? 0) > 3
                        ? 3
                        : (sectionTypeList?.length ?? 0),
                    shrinkWrap: true,
                    controller: tabScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    separatorBuilder: (context, index) => Container(
                      width: 1.5,
                      margin: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                      decoration: Utils.setBackground(grayDark, 5),
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == 2) {
                        return _buildMoreBtn();
                      }
                      return InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: () async {
                          printLog("index ===========> $index");
                          AdHelper.showFullscreenAd(
                              context, Constant.interstialAdType, () async {
                            await bottombarProvider.setAppbarVisibility(true);
                            await getTabData(
                                index, homeProvider.sectionTypeModel.result);
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                          child: MyText(
                            color: white,
                            multilanguage: false,
                            text:
                                (sectionTypeList?[index].name.toString() ?? ""),
                            fontsizeNormal: 14,
                            fontweight: FontWeight.w600,
                            fontsizeWeb: 15,
                            maxline: 1,
                            overflow: TextOverflow.ellipsis,
                            textalign: TextAlign.center,
                            fontstyle: FontStyle.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildSelectedTypeView(List<type.Result>? sectionTypeList) {
    return Visibility(
      visible: (homeProvider.selectedIndex != -1),
      maintainAnimation: true,
      maintainState: true,
      child: AnimatedOpacity(
        opacity: (homeProvider.selectedIndex != -1) ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 1000),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 35),
              decoration: Utils.setBGWithBorder(
                  secondaryBgColor, transparent, Dimens.menuRadius, 0),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: MyText(
                  color: white,
                  multilanguage: false,
                  text: (sectionTypeList?[(homeProvider.selectedIndex)]
                          .name
                          .toString() ??
                      ""),
                  fontsizeNormal: 14,
                  fontweight: FontWeight.w600,
                  fontsizeWeb: 15,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  textalign: TextAlign.center,
                  fontstyle: FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            /* Close */
            InkWell(
              onTap: () async {
                await getTabData(-1, sectionTypeList);
              },
              focusColor: white,
              borderRadius: BorderRadius.circular(Dimens.menuRadius),
              child: FittedBox(
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: secondaryBgColor,
                    borderRadius: BorderRadius.circular(Dimens.menuRadius),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: MyImage(
                    imagePath: "ic_close.png",
                    color: white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreBtn() {
    return InkWell(
      borderRadius: BorderRadius.circular(25),
      onTap: () async {
        _openMoreDialog();
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: MyText(
          color: white,
          multilanguage: true,
          text: "more",
          fontsizeNormal: 14,
          fontweight: FontWeight.w600,
          fontsizeWeb: 15,
          maxline: 1,
          overflow: TextOverflow.ellipsis,
          textalign: TextAlign.center,
          fontstyle: FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildTypeTabData(List<type.Result>? sectionTypeList) {
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: const BoxConstraints.expand(),
      child: RefreshIndicator(
        backgroundColor: white,
        color: complimentryColor,
        displacement: 80,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 1500))
              .then((value) async {
            printLog(
                "getTabData selectedIndex ===========> ${homeProvider.selectedIndex}");
            await _getData();
            getTabData(homeProvider.selectedIndex,
                homeProvider.sectionTypeModel.result);
          });
        },
        child: SingleChildScrollView(
          controller: nestedScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: _buildBannerSections(),
        ),
      ),
    );
  }

  Widget _buildBannerSections() {
    return Column(
      children: [
        /* Banner */
        if (sectionDataProvider.loadingBanner)
          if (Dimens.isBigScreen(context))
            ShimmerUtils.bannerWeb(context)
          else
            ShimmerUtils.bannerMobile(context)
        else if (sectionDataProvider.sectionBannerModel.status == 200 &&
            sectionDataProvider.sectionBannerModel.result != null)
          _mobileHomeBanner(sectionDataProvider.sectionBannerModel.result)
        else
          SafeArea(child: SizedBox(height: Dimens.homeTabHeightSmall)),

        /* AdMob Banner */
        Utils.showBannerAd(context),

        /* Remaining Sections */
        if (sectionDataProvider.loadingSection && !sectionDataProvider.loadMore)
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
    );
  }
  /* **************** Type END */

  /* Banner START ************** */
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
                            withShaderMask: true,
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
      height: 40,
      alignment: Alignment.center,
      margin: const EdgeInsets.fromLTRB(15, 15, 15, 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          /* Watch Now */
          if ((sectionBannerList?[index].isPremium ?? 0) == 1 &&
              (sectionBannerList?[index].isBuy ?? 0) == 0)
            InkWell(
              onTap: () {
                Utils.openSubscription(
                  context: context,
                  oldPage: RoutesConstant.homePage,
                );
              },
              focusColor: white,
              borderRadius: BorderRadius.circular(8),
              child: FittedBox(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.fromLTRB(15, 2, 15, 2),
                  decoration: BoxDecoration(
                    color: secondaryBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      MyImage(
                        width: 15,
                        height: 15,
                        imagePath: "ic_subscribe.png",
                        color: white,
                      ),
                      const SizedBox(width: 8),
                      MyText(
                        color: white,
                        text: "subscribe",
                        multilanguage: true,
                        textalign: TextAlign.start,
                        fontsizeNormal: 13,
                        fontweight: FontWeight.w600,
                        fontsizeWeb: 17,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        fontstyle: FontStyle.normal,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            InkWell(
              onTap: () {
                openDetailPage(
                  sectionBannerList?[index].id ?? 0,
                  sectionBannerList?[index].subVideoType ?? 0,
                  sectionBannerList?[index].videoType ?? 0,
                  sectionBannerList?[index].typeId ?? 0,
                );
              },
              focusColor: white,
              borderRadius: BorderRadius.circular(8),
              child: FittedBox(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.fromLTRB(15, 2, 15, 2),
                  decoration: BoxDecoration(
                    color: secondaryBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                        textalign: TextAlign.start,
                        fontsizeNormal: 13,
                        fontweight: FontWeight.w600,
                        fontsizeWeb: 17,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        fontstyle: FontStyle.normal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(width: 10),
          /* Add to Watchlist */
          InkWell(
            onTap: () async {
              if (Constant.userID != null) {
                await sectionDataProvider.setBookMark(
                    context, (sectionDataProvider.cBannerIndex ?? 0));
              } else {
                await Utils.openLogin(context: context, newPage: "");
              }
            },
            focusColor: white,
            borderRadius: BorderRadius.circular(8),
            child: FittedBox(
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: secondaryBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(11),
                child: MyImage(
                  imagePath: (sectionBannerList?[
                                      (sectionDataProvider.cBannerIndex ?? 0)]
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
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return SectionViewAll(
                            sectionId: sectionList?[index].id ?? 0,
                            appBarTitle: sectionList?[index].title ?? "",
                            screenLayout:
                                sectionList?[index].screenLayout ?? "",
                            videoType: sectionList?[index].videoType ?? 0,
                          );
                        },
                      ),
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
              const SizedBox(height: 25),
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
    return FittedBox(
      child: Container(
        padding: const EdgeInsets.only(left: 13, right: 13),
        child: InkWell(
          onTap:
              ((sectionList?[index].viewAll ?? 0) == 1) ? onViewAllClick : null,
          borderRadius: BorderRadius.circular(3),
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
                      fontsizeNormal: 15,
                      fontweight: FontWeight.w600,
                      fontsizeWeb: 17,
                      multilanguage: false,
                      maxline: 1,
                      overflow: TextOverflow.ellipsis,
                      fontstyle: FontStyle.normal,
                    ),
                  ),
                  if ((sectionList?[index].viewAll ?? 0) == 1)
                    Container(
                      alignment: Alignment.centerRight,
                      height: 20,
                      margin: const EdgeInsets.only(left: 5, top: 2),
                      padding: const EdgeInsets.all(5),
                      child: MyImage(
                        imagePath: "ic_viewall.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                ],
              ),
              if ((sectionList?[index].shortTitle.toString() ?? "").isNotEmpty)
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
      ),
    );
  }

  Widget setSectionData(
      {required List<list.Result>? sectionList, required int index}) {
    /* screen_layout =>  landscape, big_landscape, index_landscape, portrait, big_portrait, index_portrait, 
                         square, category, language, channel */
    if ((sectionList?[index].screenLayout ?? "") == "landscape") {
      return _buildLandscapeUI(
          sectionList?[index].videoType, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "big_landscape") {
      return _buildLandscapeBigUI(
          sectionList?[index].videoType, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "index_landscape") {
      return _buildLandscapeIndexUI(
          sectionList?[index].videoType, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "portrait") {
      return _buildPortraitUI(
          sectionList?[index].videoType, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "big_portrait") {
      return _buildPortraitBigUI(
          sectionList?[index].videoType, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "index_portrait") {
      return _buildPortraitIndexUI(
          sectionList?[index].videoType, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "square") {
      return _buildSquareUI(
          sectionList?[index].videoType, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "shorts") {
      return _buildShortsUI(sectionList?[index].id, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "category") {
      return _buildGenresUI(sectionList?[index].videoType,
          sectionList?[index].typeId ?? 0, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "language") {
      return _buildLanguageUI(sectionList?[index].videoType,
          sectionList?[index].typeId ?? 0, sectionList?[index].data);
    } else if ((sectionList?[index].screenLayout ?? "") == "channel") {
      return _buildChannelUI(sectionList?[index].videoType,
          sectionList?[index].typeId ?? 0, sectionList?[index].data);
    } else {
      return _buildLandscapeUI(
          sectionList?[index].videoType, sectionList?[index].data);
    }
  }

  double getRemainingDataHeight(
    String? videoType,
    String? layoutType,
    List<list.Result>? sectionList,
    int index,
  ) {
    if (layoutType == "landscape" || layoutType == "index_landscape") {
      return Dimens.heightLand;
    } else if (layoutType == "big_landscape") {
      return Dimens.heightLandBig;
    } else if (layoutType == "portrait" || layoutType == "index_portrait") {
      return Dimens.heightPort;
    } else if (layoutType == "big_portrait") {
      return Dimens.heightPortBig;
    } else if (layoutType == "square") {
      return Dimens.heightSquare;
    } else if (layoutType == "shorts") {
      return ((sectionList?[index].data?.length ?? 0) < 4)
          ? (Dimens.heightShortsTotal)
          : (Dimens.heightShortsTotal * 2);
    } else if (layoutType == "category") {
      return Dimens.heightGen;
    } else if (layoutType == "language") {
      return Dimens.heightLang;
    } else if (layoutType == "channel") {
      return ((sectionList?[index].data?.length ?? 0) < 4)
          ? (Dimens.heightChannelTotal)
          : (Dimens.heightChannelTotal * 2);
    } else {
      return Dimens.heightLand;
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
                            fontsizeNormal: 12,
                            fontweight: FontWeight.w600,
                            fontsizeWeb: 14,
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

  Widget _buildLandscapeUI(int? videoType, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightLand,
      child: ListView.separated(
        itemCount: sectionDataList?.length ?? 0,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 14),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) =>
            SizedBox(width: Dimens.spaceBetweenCards),
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.cardRadius),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
              width: Dimens.widthLand,
              height: Dimens.heightLand,
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
                      borderRadius: BorderRadius.circular(Dimens.cardRadius),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: MyNetworkImage(
                        imageUrl:
                            sectionDataList?[index].landscape.toString() ?? "",
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
                    _buildContinueWatchingUI(videoType, index, sectionDataList),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLandscapeIndexUI(int? videoType, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightLand,
      child: AlignedGridView.count(
        shrinkWrap: true,
        crossAxisCount: 1,
        mainAxisSpacing: 30,
        itemCount: (sectionDataList?.length ?? 0),
        padding: const EdgeInsets.only(left: 34, right: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, index) {
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              /* Image */
              InkWell(
                borderRadius: BorderRadius.circular(Dimens.cardRadius),
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
                  borderRadius: BorderRadius.circular(Dimens.cardRadius),
                  child: MyNetworkImage(
                    width: Dimens.widthLand,
                    height: Dimens.heightLand,
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
                transform: Matrix4.translationValues(-17, 0, 0),
                child: Text(
                  "${index + 1}",
                  style: GoogleFonts.inter(
                    textStyle: TextStyle(
                      fontSize: 40,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 5
                        ..color = colorPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              Container(
                transform: Matrix4.translationValues(-19, 0, 0),
                child: Text(
                  "${index + 1}",
                  style: GoogleFonts.inter(
                    textStyle: TextStyle(
                      fontSize: 40,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 5
                        ..color = colorPrimary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLandscapeBigUI(int? videoType, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightLandBig,
      child: ListView.separated(
        itemCount: sectionDataList?.length ?? 0,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 14),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) =>
            SizedBox(width: Dimens.spaceBetweenCards),
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.cardRadius),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
              width: Dimens.widthLandBig,
              height: Dimens.heightLandBig,
              child: InkWell(
                focusColor: white,
                borderRadius: BorderRadius.circular(Dimens.cardRadius),
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
                      borderRadius: BorderRadius.circular(Dimens.cardRadius),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: MyNetworkImage(
                        imageUrl:
                            sectionDataList?[index].landscape.toString() ?? "",
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
                    _buildContinueWatchingUI(videoType, index, sectionDataList),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortraitUI(int? videoType, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightPort,
      child: ListView.separated(
        itemCount: sectionDataList?.length ?? 0,
        shrinkWrap: true,
        padding: const EdgeInsets.only(left: 14, right: 14),
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        separatorBuilder: (context, index) =>
            SizedBox(width: Dimens.spaceBetweenCards),
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.cardRadius),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
              width: Dimens.widthPort,
              height: Dimens.heightPort,
              child: InkWell(
                focusColor: white,
                borderRadius: BorderRadius.circular(Dimens.cardRadius),
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
                      borderRadius: BorderRadius.circular(Dimens.cardRadius),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: MyNetworkImage(
                        imageUrl:
                            sectionDataList?[index].thumbnail.toString() ?? "",
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
                    _buildContinueWatchingUI(videoType, index, sectionDataList),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortraitBigUI(int? videoType, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightPortBig,
      child: ListView.separated(
        itemCount: sectionDataList?.length ?? 0,
        shrinkWrap: true,
        padding: const EdgeInsets.only(left: 14, right: 14),
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        separatorBuilder: (context, index) =>
            SizedBox(width: Dimens.spaceBetweenCards),
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.cardRadius),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
              width: Dimens.widthPortBig,
              height: Dimens.heightPortBig,
              child: InkWell(
                focusColor: white,
                borderRadius: BorderRadius.circular(Dimens.cardRadius),
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
                      borderRadius: BorderRadius.circular(Dimens.cardRadius),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: MyNetworkImage(
                        imageUrl:
                            sectionDataList?[index].thumbnail.toString() ?? "",
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
                    _buildContinueWatchingUI(videoType, index, sectionDataList),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPortraitIndexUI(int? videoType, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightPort,
      child: AlignedGridView.count(
        shrinkWrap: true,
        crossAxisCount: 1,
        mainAxisSpacing: 25,
        itemCount: (sectionDataList?.length ?? 0),
        padding: const EdgeInsets.only(left: 28, right: 14),
        physics: const AlwaysScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, index) {
          return Stack(
            alignment: Alignment.bottomLeft,
            children: [
              /* Image */
              InkWell(
                borderRadius: BorderRadius.circular(Dimens.cardRadius),
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
                  borderRadius: BorderRadius.circular(Dimens.cardRadius),
                  child: MyNetworkImage(
                    width: Dimens.widthPort,
                    height: Dimens.heightPort,
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
                transform: Matrix4.translationValues(-11, 10, 0),
                child: Text(
                  "${index + 1}",
                  style: GoogleFonts.inter(
                    textStyle: TextStyle(
                      fontSize: 60,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 6
                        ..color = colorPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              Container(
                transform: Matrix4.translationValues(-15, 10, 0),
                child: Text(
                  "${index + 1}",
                  style: GoogleFonts.inter(
                    textStyle: TextStyle(
                      fontSize: 60,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 6
                        ..color = colorPrimary,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSquareUI(int? videoType, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightSquare,
      child: ListView.separated(
        itemCount: sectionDataList?.length ?? 0,
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 14),
        separatorBuilder: (context, index) =>
            SizedBox(width: Dimens.spaceBetweenCards),
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.cardRadius),
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
              width: Dimens.widthSquare,
              height: Dimens.heightSquare,
              child: InkWell(
                focusColor: white,
                borderRadius: BorderRadius.circular(Dimens.cardRadius),
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
                      borderRadius: BorderRadius.circular(Dimens.cardRadius),
                      clipBehavior: Clip.antiAliasWithSaveLayer,
                      child: MyNetworkImage(
                        imageUrl:
                            sectionDataList?[index].thumbnail.toString() ?? "",
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
                    _buildContinueWatchingUI(videoType, index, sectionDataList),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShortsUI(int? sectionId, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: ((sectionDataList?.length ?? 0) < 4)
          ? (Dimens.heightShortsTotal)
          : (Dimens.heightShortsTotal * 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        child: AlignedGridView.count(
          itemCount: sectionDataList?.length ?? 0,
          shrinkWrap: true,
          crossAxisCount: ((sectionDataList?.length ?? 0) < 4) ? 1 : 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          padding: const EdgeInsets.only(left: 14, right: 14),
          physics: const NeverScrollableScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemBuilder: (BuildContext context, int index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(Constant.isTV ? 2 : 0),
                width: Dimens.widthShorts,
                height: Dimens.heightShorts,
                child: InkWell(
                  focusColor: white,
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    printLog("Clicked on index ======> $index");
                    printLog("Clicked on sectionId ==> $sectionId");
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
                        decoration: Utils.setGradTTBBGWithCenter(transparent,
                            transparent, appBgColor.withValues(alpha: 0.8), 0),
                        child: MyText(
                          color: white,
                          multilanguage: false,
                          text: sectionDataList?[index].name.toString() ?? "",
                          fontsizeNormal: 13,
                          fontsizeWeb: 15,
                          fontweight: FontWeight.w600,
                          maxline: 1,
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
    );
  }

  Widget _buildChannelUI(
      int? videoType, int? typeId, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: ((sectionDataList?.length ?? 0) < 13)
          ? (Dimens.heightChannelTotal)
          : (Dimens.heightChannelTotal * 2),
      child: AlignedGridView.count(
        itemCount: sectionDataList?.length ?? 0,
        shrinkWrap: true,
        crossAxisCount: ((sectionDataList?.length ?? 0) < 13) ? 1 : 2,
        crossAxisSpacing: Dimens.spaceBetweenChannel,
        mainAxisSpacing: Dimens.spaceBetweenChannel,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 14),
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
              focusColor: white,
              onTap: () async {
                printLog("Clicked on index ==> $index");
                videoByIDProvider.setLoading(true);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return ContentByID(
                        sectionDataList?[index].id ?? 0,
                        sectionDataList?[index].name ?? "",
                        "ByChannel",
                      );
                    },
                  ),
                );
              },
              child: Container(
                height: Dimens.heightChannel,
                alignment: Alignment.center,
                constraints: const BoxConstraints(minWidth: 80),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Dimens.cardRadiusMedium),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: MyNetworkImage(
                    imageUrl:
                        sectionDataList?[index].landscapeImg.toString() ?? "",
                    fit: BoxFit.fill,
                    width: Dimens.widthChannel,
                    height: Dimens.heightChannel,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageUI(
      int? videoType, int? typeId, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightLang,
      child: ListView.separated(
        itemCount: sectionDataList?.length ?? 0,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 14),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) =>
            SizedBox(width: Dimens.spaceBetweenLang),
        itemBuilder: (BuildContext context, int index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(Dimens.heightLang / 2),
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimens.heightLang / 2),
              focusColor: white,
              onTap: () async {
                printLog("Clicked on index ==> $index");
                videoByIDProvider.setLoading(true);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return ContentByID(
                        sectionDataList?[index].id ?? 0,
                        sectionDataList?[index].name ?? "",
                        "ByLanguage",
                      );
                    },
                  ),
                );
              },
              child: Container(
                height: Dimens.heightLang,
                alignment: Alignment.center,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Dimens.heightLang / 2),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: MyNetworkImage(
                    imageUrl: sectionDataList?[index].image.toString() ?? "",
                    fit: BoxFit.fill,
                    height: Dimens.heightLang,
                    width: Dimens.widthLang,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenresUI(
      int? videoType, int? typeId, List<Datum>? sectionDataList) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: Dimens.heightGen,
      child: ListView.separated(
        itemCount: sectionDataList?.length ?? 0,
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 14, right: 14),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (context, index) =>
            SizedBox(width: Dimens.spaceBetweenCategory),
        itemBuilder: (BuildContext context, int index) {
          return Container(
            height: Dimens.heightGen,
            width: Dimens.widthGen,
            alignment: Alignment.center,
            child: InkWell(
              focusColor: white,
              borderRadius: BorderRadius.circular(Dimens.heightGen / 2),
              onTap: () async {
                printLog("Clicked on index ==> $index");
                videoByIDProvider.setLoading(true);
                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return ContentByID(
                        sectionDataList?[index].id ?? 0,
                        sectionDataList?[index].name ?? "",
                        "ByCategory",
                      );
                    },
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Dimens.heightGen / 2),
                clipBehavior: Clip.antiAliasWithSaveLayer,
                child: MyNetworkImage(
                  imageUrl: sectionDataList?[index].image.toString() ?? "",
                  fit: BoxFit.fill,
                  height: Dimens.heightGen,
                  width: Dimens.widthGen,
                ),
              ),
            ),
          );
        },
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
