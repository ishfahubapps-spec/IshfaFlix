import 'package:dropdown_button2/dropdown_button2.dart';
import '../provider/findprovider.dart';
import '../provider/generalprovider.dart';
import '../provider/homeprovider.dart';
import '../provider/profileprovider.dart';
import '../model/sectiontypemodel.dart' as type;
import '../provider/purchaselistprovider.dart';
import '../provider/rentstoreprovider.dart';
import '../provider/sectiondataprovider.dart';
import '../provider/sectionviewallprovider.dart';
import '../provider/subhistoryprovider.dart';
import '../provider/videobyidprovider.dart';
import '../provider/viewallprovider.dart';
import '../provider/watchlistprovider.dart';
import '../pushservice/pushnotificationservice.dart';
import '../routes/routes_constant.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../utils/dimens.dart';
import '../utils/sharedpre.dart';
import '../utils/utils.dart';
import '../web_js/js_helper.dart';
import '../webwidget/interactive_icon.dart';
import '../webwidget/webarrowkeyscroll.dart';
import '../webwidget/webfooter.dart';
import '../widget/myimage.dart';
import '../widget/mynetworkimg.dart';
import '../widget/mytext.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class WebComman extends StatefulWidget {
  final String? newPage, oldPage;
  final dynamic reqText;
  final Widget newChild;
  const WebComman({
    required this.newChild,
    required this.newPage,
    required this.oldPage,
    required this.reqText,
    super.key,
  });

  @override
  State<WebComman> createState() => _WebCommanState();
}

class _WebCommanState extends State<WebComman> with RouteAware {
  SharedPre sharePref = SharedPre();
  final JSHelper jsHelper = JSHelper();

  final ScrollController _mainScrollController = ScrollController();

  late SectionDataProvider sectionDataProvider;
  late RentStoreProvider rentStoreProvider;
  late VideoByIDProvider videoByIDProvider;
  late ProfileProvider profileProvider;
  late HomeProvider homeProvider;
  late FindProvider findProvider;
  late SectionViewAllProvider sectionViewAllProvider;
  late ViewAllProvider viewAllProvider;
  late WatchlistProvider watchlistProvider;
  late PurchaselistProvider purchaselistProvider;
  late GeneralProvider generalProvider;
  late SubHistoryProvider subHistoryProvider;

  String? currentPage, rentMenuStatus;
  dynamic reqText;

  void _scrollUp() {
    if (!_mainScrollController.hasClients) return;
    _mainScrollController.animateTo(
      _mainScrollController.position.minScrollExtent,
      duration: const Duration(seconds: 1),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _scrollDown() {
    if (!_mainScrollController.hasClients) return;
    _mainScrollController.animateTo(
      _mainScrollController.position.maxScrollExtent,
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
    /* Home Sections */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (sectionDataProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.homePage) {
      sectionDataProvider.setLoadMore(true);
      _fetchSectionData(sectionDataProvider.currentPage ?? 0);
    }

    /* Rent Store */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (rentStoreProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.storePage) {
      rentStoreProvider.setLoadMore(true);
      _fetchRentNewData(rentStoreProvider.currentPage ?? 0);
    }

    /* Content By Id */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (videoByIDProvider.isMorePage ?? false) &&
        (widget.newPage == RoutesConstant.videoByCatPage ||
            widget.newPage == RoutesConstant.videoByChannelPage ||
            widget.newPage == RoutesConstant.videoByLanguagePage)) {
      videoByIDProvider.setLoadMore(true);
      _fetchNewContentById(videoByIDProvider.currentPage ?? 0);
    }

    /* Content By Section */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (sectionViewAllProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.sectionDetailsPage) {
      sectionViewAllProvider.setLoadMore(true);
      _fetchSectionDetails(sectionViewAllProvider.currentPage ?? 0);
    }

    /* Content By Search */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (findProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.searchPage) {
      findProvider.setLoadMore(true);
      _fetchNewSearchData(findProvider.currentPage ?? 0);
    }

    /* Related Content */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (viewAllProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.relatedContentPage) {
      viewAllProvider.setLoadMore(true);
      _fetchRelatedContent(viewAllProvider.currentPage ?? 0);
    }

    /* Continue Watching */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (viewAllProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.continueWatchPage) {
      viewAllProvider.setLoadMore(true);
      _fetchContinueWatch(viewAllProvider.currentPage ?? 0);
    }

    /* Watchlist */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (watchlistProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.myWatchlistPage) {
      watchlistProvider.setLoadMore(true);
      _fetchWatchlist(watchlistProvider.currentPage ?? 0);
    }

    /* User Rent ContentList */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (purchaselistProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.rentPurchasePage) {
      purchaselistProvider.setLoadMore(true);
      _fetchUserRentContentList(purchaselistProvider.currentPage ?? 0);
    }

    /* Subscription History */
    if (_mainScrollController.offset >=
            _mainScrollController.position.maxScrollExtent &&
        !_mainScrollController.position.outOfRange &&
        (subHistoryProvider.isMorePage ?? false) &&
        widget.newPage == RoutesConstant.subsHistoryPage) {
      subHistoryProvider.setLoadMore(true);
      _fetchSubsHistoryData(subHistoryProvider.currentPage ?? 0);
    }
  }

  Future<void> _fetchSectionData(int? nextPage) async {
    printLog(
        "_fetchSectionData selectedIndex ====> ${homeProvider.selectedIndex}");
    printLog("_fetchSectionData nextPage  ========> $nextPage");
    printLog(
        "_fetchSectionData isMorePage  ======> ${sectionDataProvider.isMorePage}");
    printLog(
        "_fetchSectionData currentPage ======> ${sectionDataProvider.currentPage}");
    printLog(
        "_fetchSectionData totalPage   ======> ${sectionDataProvider.totalPage}");

    await sectionDataProvider.getSectionList(
        (homeProvider.selectedIndex == -1 || homeProvider.selectedIndex == 0)
            ? 0
            : (homeProvider
                    .sectionTypeModel.result?[homeProvider.selectedIndex].id ??
                0),
        (homeProvider.selectedIndex == -1 || homeProvider.selectedIndex == 0)
            ? "1"
            : "2",
        (nextPage ?? 0) + 1);
    printLog(
        "sectionList length ==> ${sectionDataProvider.sectionList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchRentNewData(int? nextPage) async {
    printLog("_fetchRentNewData nextPage  ========> $nextPage");
    printLog(
        "_fetchRentNewData isMorePage  ======> ${rentStoreProvider.isMorePage}");
    printLog(
        "_fetchRentNewData currentPage ======> ${rentStoreProvider.currentPage}");
    printLog(
        "_fetchRentNewData totalPage   ======> ${rentStoreProvider.totalPage}");

    await rentStoreProvider.getRentContentList(
        rentStoreProvider
                .sectionTypeList?[rentStoreProvider.selectedIndex].type ??
            0,
        (nextPage ?? 0) + 1);
    printLog(
        "rentDataList length ==> ${rentStoreProvider.rentDataList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchNewContentById(int? nextPage) async {
    printLog("_fetchNewContentById nextPage  ========> $nextPage");
    printLog(
        "_fetchNewContentById isMorePage  ======> ${videoByIDProvider.isMorePage}");
    printLog(
        "_fetchNewContentById currentPage ======> ${videoByIDProvider.currentPage}");
    printLog(
        "_fetchNewContentById totalPage   ======> ${videoByIDProvider.totalPage}");

    if (widget.newPage == RoutesConstant.videoByCatPage) {
      printLog(
          "_fetchNewContentById currentCatId ======> ${videoByIDProvider.currentCatId}");
      await videoByIDProvider.getVideoByCategory(
          videoByIDProvider.currentCatId, (nextPage ?? 0) + 1);
    } else if (widget.newPage == RoutesConstant.videoByLanguagePage) {
      printLog(
          "_fetchNewContentById currentLangId =====> ${videoByIDProvider.currentLangId}");
      await videoByIDProvider.getVideoByLanguage(
          videoByIDProvider.currentLangId, (nextPage ?? 0) + 1);
    } else {
      printLog(
          "_fetchNewContentById currentChannelId ==> ${videoByIDProvider.currentChannelId}");
      await videoByIDProvider.getVideoByChannel(
          videoByIDProvider.currentChannelId, (nextPage ?? 0) + 1);
    }
    printLog("contentList length ==> ${videoByIDProvider.contentList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchSectionDetails(int? nextPage) async {
    printLog("_fetchSectionDetails nextPage  ========> $nextPage");
    printLog(
        "_fetchSectionDetails isMorePage  ======> ${sectionViewAllProvider.isMorePage}");
    printLog(
        "_fetchSectionDetails currentPage ======> ${sectionViewAllProvider.currentPage}");
    printLog(
        "_fetchSectionDetails totalPage   ======> ${sectionViewAllProvider.totalPage}");

    await sectionViewAllProvider.getSectionDetails(
        widget.reqText, (nextPage ?? 0) + 1);
    printLog(
        "sectionDetailsList length ==> ${sectionViewAllProvider.sectionDetailList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchNewSearchData(int? nextPage) async {
    printLog("_fetchNewSearchData nextPage  ========> $nextPage");
    printLog(
        "_fetchNewSearchData isMorePage  ======> ${findProvider.isMorePage}");
    printLog(
        "_fetchNewSearchData currentPage ======> ${findProvider.currentPage}");
    printLog(
        "_fetchNewSearchData totalPage   ======> ${findProvider.totalPage}");

    await findProvider.getSearchContent(widget.reqText, (nextPage ?? 0) + 1);
    printLog(
        "searchDataList length ==> ${findProvider.searchDataList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchRelatedContent(int? nextPage) async {
    printLog("_fetchRelatedContent nextPage  ========> $nextPage");
    printLog(
        "_fetchRelatedContent isMorePage  ======> ${viewAllProvider.isMorePage}");
    printLog(
        "_fetchRelatedContent currentPage ======> ${viewAllProvider.currentPage}");
    printLog(
        "_fetchRelatedContent totalPage   ======> ${viewAllProvider.totalPage}");
    printLog("_fetchRelatedContent newPage  ========> ${widget.newPage}");
    printLog("_fetchRelatedContent reqText  ========> ${widget.reqText}");

    if (widget.reqText is Map<String, dynamic>) {
      final extraData = widget.reqText as Map<String, dynamic>;
      final itemID = extraData['itemid'] as int;
      final subVideoType = extraData['subvideotype'] as int;
      final videoType = extraData['videotype'] as int;
      final typeId = extraData['typeid'] as int;
      await viewAllProvider.getRelatedContent(
          typeId, videoType, itemID, subVideoType, (nextPage ?? 0) + 1);
    }
    printLog(
        "_fetchRelatedContent length ==> ${viewAllProvider.relatedList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchContinueWatch(int? nextPage) async {
    printLog("_fetchContinueWatch nextPage  ========> $nextPage");
    printLog(
        "_fetchContinueWatch isMorePage  ======> ${viewAllProvider.isMorePage}");
    printLog(
        "_fetchContinueWatch currentPage ======> ${viewAllProvider.currentPage}");
    printLog(
        "_fetchContinueWatch totalPage   ======> ${viewAllProvider.totalPage}");
    printLog("_fetchContinueWatch newPage  ========> ${widget.newPage}");
    printLog("_fetchContinueWatch reqText  ========> ${widget.reqText}");

    await viewAllProvider.getContinueWatching((nextPage ?? 0) + 1);
    printLog(
        "_fetchContinueWatch length ==> ${viewAllProvider.continueWatchList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchWatchlist(int? nextPage) async {
    printLog("_fetchWatchlist nextPage  ========> $nextPage");
    printLog(
        "_fetchWatchlist isMorePage  ======> ${watchlistProvider.isMorePage}");
    printLog(
        "_fetchWatchlist currentPage ======> ${watchlistProvider.currentPage}");
    printLog(
        "_fetchWatchlist totalPage   ======> ${watchlistProvider.totalPage}");

    await watchlistProvider.getWatchlist((nextPage ?? 0) + 1);
    printLog(
        "_fetchWatchlist length ==> ${watchlistProvider.watchlistDataList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchUserRentContentList(int? nextPage) async {
    printLog("_fetchUserRentContentList nextPage  ========> $nextPage");
    printLog(
        "_fetchUserRentContentList isMorePage  ======> ${purchaselistProvider.isMorePage}");
    printLog(
        "_fetchUserRentContentList currentPage ======> ${purchaselistProvider.currentPage}");
    printLog(
        "_fetchUserRentContentList totalPage   ======> ${purchaselistProvider.totalPage}");

    await purchaselistProvider.getUserRentVideoList((nextPage ?? 0) + 1);
    printLog(
        "_fetchUserRentContentList length ==> ${purchaselistProvider.contentList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _fetchSubsHistoryData(int? nextPage) async {
    printLog("_fetchSubsHistoryData nextPage =========> $nextPage");
    printLog(
        "_fetchSubsHistoryData isMorePage =======> ${subHistoryProvider.isMorePage}");
    printLog(
        "_fetchSubsHistoryData currentPage ======> ${subHistoryProvider.currentPage}");
    printLog(
        "_fetchSubsHistoryData totalPage ========> ${subHistoryProvider.totalPage}");

    await subHistoryProvider.getSubscriptionList((nextPage ?? 0) + 1);
    printLog(
        "historyDataList length ==> ${subHistoryProvider.historyDataList?.length}");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    super.didChangeDependencies();
  }

  @override
  void didPopNext() {
    printLog("didPopNext");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();
    });
    super.didPopNext();
  }

  @override
  void initState() {
    super.initState();
    currentPage = widget.newPage;
    reqText = widget.reqText;
    generalProvider = Provider.of<GeneralProvider>(context, listen: false);
    sectionDataProvider =
        Provider.of<SectionDataProvider>(context, listen: false);
    rentStoreProvider = Provider.of<RentStoreProvider>(context, listen: false);
    videoByIDProvider = Provider.of<VideoByIDProvider>(context, listen: false);
    findProvider = Provider.of<FindProvider>(context, listen: false);
    sectionViewAllProvider =
        Provider.of<SectionViewAllProvider>(context, listen: false);
    viewAllProvider = Provider.of<ViewAllProvider>(context, listen: false);
    watchlistProvider = Provider.of<WatchlistProvider>(context, listen: false);
    purchaselistProvider =
        Provider.of<PurchaselistProvider>(context, listen: false);
    homeProvider = Provider.of<HomeProvider>(context, listen: false);
    profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    subHistoryProvider =
        Provider.of<SubHistoryProvider>(context, listen: false);
    _mainScrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();

      if (kIsWeb) {
        PushNotificationService().requestNotificationPermission();
      }
    });
  }

  Future<void> _getData() async {
    Constant.userID = await sharePref.read("userid");
    printLog('userID =========> ${Constant.userID}');
    /* Get Profile */
    if (Constant.userID != null) {
      if (!mounted) return;
      profileProvider.getProfile(context).then((_) async {
        if (mounted) profileProvider.notifyProvider();
      });
    }

    if (mounted) {
      generalProvider.getGeneralsetting(context).then((_) async {
        rentMenuStatus =
            await Utils.configByStatus(status: Constant.rentStatus);
        printLog('_getData rentMenuStatus ==> $rentMenuStatus');
        printLog('_getData userIsKid =======> ${Constant.userIsKid}');
        if (mounted) setState(() {});
      });
    }

    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> setSelectedTab(int tabPos) async {
    if (!mounted) return;
    homeProvider.setSelectedTab(tabPos);

    printLog("getTabData position ====> $tabPos");
    printLog(
        "getTabData lastTabPosition ====> ${sectionDataProvider.lastTabPosition}");
    if (sectionDataProvider.lastTabPosition == tabPos) {
      return;
    } else {
      sectionDataProvider.setTabPosition(tabPos);
    }
  }

  Future<void> getTabData(
      int position, List<type.Result>? sectionTypeList) async {
    sectionDataProvider.setLoading(true);
    if (position == -1) {
      await setSelectedTab(0);
      sectionDataProvider.getSectionBanner("0", "1");
      sectionDataProvider.getSectionList("0", "1", 1);
    } else {
      await setSelectedTab(position + 1);
      sectionDataProvider.getSectionBanner(
          sectionTypeList?[position].id ?? 0, "2");
      sectionDataProvider.getSectionList(
          sectionTypeList?[position].id ?? 0, "2", 1);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBgColor,
      floatingActionButton: (widget.newPage != RoutesConstant.clipsEpisodesPage)
          ? FloatingActionButton.small(
              backgroundColor: colorAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2)),
              onPressed: () {
                printLog("Offset =========> ${_mainScrollController.offset}");
                if (_mainScrollController.offset <=
                        _mainScrollController.position.minScrollExtent &&
                    !_mainScrollController.position.outOfRange) {
                  _scrollDown();
                } else {
                  _scrollUp();
                }
              },
              child: (_mainScrollController.hasClients &&
                      (_mainScrollController.offset >=
                              _mainScrollController.position.maxScrollExtent &&
                          !_mainScrollController.position.outOfRange))
                  ? (const Icon(Icons.arrow_upward_rounded))
                  : (const Icon(Icons.arrow_downward_rounded)),
            )
          : null,
      body: Stack(
        children: [
          _buildPage(),
          /* AppBar */
          _buildAppBar(),
        ],
      ),
    );
  }

  /* AppBar */
  Widget _buildAppBar() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: Dimens.homeTabHeight,
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
      decoration: Utils.setGradTTBWithCenter(
          appBgColor, appBgColor.withValues(alpha: 0.4), transparent, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /* Menu */
          (!Dimens.isBigScreen(context))
              ? Container(
                  constraints: const BoxConstraints(
                    minWidth: 25,
                  ),
                  padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
                  child: Consumer<HomeProvider>(
                    builder: (context, homeProvider, child) {
                      return DropdownButtonHideUnderline(
                        child: DropdownButton2(
                          isDense: true,
                          isExpanded: true,
                          customButton: MyImage(
                            height: 30,
                            imagePath: "ic_menu.png",
                            fit: BoxFit.contain,
                            color: white,
                          ),
                          items: _buildWebDropDownItems(),
                          onChanged: (type.Result? value) async {
                            if (value?.id == -1) {
                              await getTabData(
                                  -1, homeProvider.sectionTypeModel.result);
                              if (widget.newPage != RoutesConstant.homePage) {
                                if (!context.mounted) return;
                                context.go(
                                  '/',
                                  extra: widget.newPage ?? "",
                                );
                              }
                            } else if (value?.id == -2) {
                              printLog("<===============================>");
                              printLog(
                                  "storePage oldPage ======> ${widget.oldPage}");
                              printLog(
                                  "storePage newPage ======> ${widget.newPage}");
                              printLog("<===============================>");
                              if (!context.mounted) return;
                              context.go(
                                '/${RoutesConstant.storePage}',
                                extra: widget.newPage ?? "",
                              );
                            } else {
                              final index = homeProvider.sectionTypeModel.result
                                  ?.indexWhere((item) => item.id == value?.id);
                              printLog("<===============================>");
                              printLog("sectionType index ======> $index");
                              printLog("<===============================>");

                              if (index != null && index != -1 && index != -2) {
                                await getTabData(index,
                                    homeProvider.sectionTypeModel.result);
                              }
                              if (widget.newPage != RoutesConstant.homePage) {
                                if (!context.mounted) return;
                                context.go(
                                  '/',
                                  extra: widget.newPage ?? "",
                                );
                              }
                            }
                          },
                          dropdownStyleData: DropdownStyleData(
                            width: MediaQuery.of(context).size.width * 0.5,
                            useSafeArea: true,
                            padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
                            decoration:
                                Utils.setBackground(secondaryBgColor, 5),
                            elevation: 8,
                          ),
                          menuItemStyleData: MenuItemStyleData(
                            overlayColor: WidgetStateProperty.resolveWith(
                              (states) {
                                if (states.contains(WidgetState.focused)) {
                                  return white.withValues(alpha: 0.5);
                                }
                                return transparent;
                              },
                            ),
                          ),
                          buttonStyleData: ButtonStyleData(
                            decoration: Utils.setBGWithBorder(
                                transparent, white, 20, 1),
                            overlayColor: WidgetStateProperty.resolveWith(
                              (states) {
                                if (states.contains(WidgetState.focused)) {
                                  return white.withValues(alpha: 0.5);
                                }
                                if (states.contains(WidgetState.hovered)) {
                                  return white.withValues(alpha: 0.5);
                                }
                                return transparent;
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),

          /* App Icon & Back Icon */
          if (currentPage == RoutesConstant.homePage)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                focusColor: white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  await getTabData(-1, homeProvider.sectionTypeModel.result);
                },
                child: Container(
                  padding: const EdgeInsets.all(3.0),
                  child: MyImage(
                    width: Dimens.appIconSizeWeb,
                    height: Dimens.appIconSizeWeb,
                    imagePath: "appicon.png",
                  ),
                ),
              ),
            )
          else
            Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () {
                    printLog("reqText ======> ${widget.reqText}");
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      if (kIsWeb) {
                        jsHelper.goBack();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    }
                  },
                  child: Container(
                    width: 45,
                    height: 45,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(8),
                    child: MyImage(
                      fit: BoxFit.contain,
                      imagePath: "back_web.png",
                    ),
                  ),
                ),
              ),
            ),

          /* Types */
          Dimens.isBigScreen(context)
              ? Expanded(child: tabTitle(homeProvider.sectionTypeModel.result))
              : const Expanded(child: SizedBox.shrink()),
          const SizedBox(width: 10),

          /* Feature buttons */
          /* Search */
          if (currentPage != RoutesConstant.searchPage)
            Material(
              type: MaterialType.transparency,
              child: _buildSearch(),
            ),

          /* Login / MyProfile */
          const SizedBox(width: 10),
          _buildUserLogin(),
        ],
      ),
    );
  }

  Widget tabTitle(List<type.Result>? sectionTypeList) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Consumer<HomeProvider>(
            builder: (context, homeProvider, child) {
              return ListView.separated(
                itemCount: (sectionTypeList?.length ?? 0) + 1,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                separatorBuilder: (context, index) => const SizedBox(width: 5),
                itemBuilder: (BuildContext context, int index) {
                  return Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      autofocus: true,
                      focusColor: kIsWeb
                          ? (widget.newPage == RoutesConstant.homePage &&
                                  homeProvider.selectedIndex == index)
                              ? colorPrimary
                              : transparent
                          : (widget.newPage == RoutesConstant.homePage &&
                                  homeProvider.selectedIndex == index
                              ? colorPrimary
                              : white.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        printLog("<===============================>");
                        printLog("HOME index ======> $index");
                        printLog("HOME oldPage ====> ${widget.oldPage}");
                        printLog("HOME newPage ====> ${widget.newPage}");
                        printLog("<===============================>");
                        if (index == 0) {
                          await getTabData(
                              -1, homeProvider.sectionTypeModel.result);
                        } else {
                          await getTabData((index - 1),
                              homeProvider.sectionTypeModel.result);
                        }
                        if (widget.newPage != RoutesConstant.homePage) {
                          if (!context.mounted) return;
                          context.go(
                            '/',
                            extra: widget.newPage ?? "",
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2.0),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 32),
                          decoration: Utils.setBackground(
                            (widget.newPage == RoutesConstant.homePage &&
                                    homeProvider.selectedIndex == index)
                                ? white
                                : transparent,
                            12,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.fromLTRB(13, 0, 13, 0),
                          child: InteractiveIcon(builder: (isHovered) {
                            return MyText(
                              color:
                                  (widget.newPage == RoutesConstant.homePage &&
                                          homeProvider.selectedIndex == index)
                                      ? black
                                      : white,
                              multilanguage: false,
                              text: index == 0
                                  ? "Home"
                                  : index > 0
                                      ? (sectionTypeList?[index - 1]
                                              .name
                                              .toString() ??
                                          "")
                                      : "",
                              fontsizeNormal: 12,
                              fontweight: FontWeight.w700,
                              fontsizeWeb: 14,
                              maxline: 1,
                              overflow: TextOverflow.ellipsis,
                              textalign: TextAlign.center,
                              fontstyle: FontStyle.normal,
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          /* Store */
          if ((rentMenuStatus != null && rentMenuStatus == "1") &&
              Constant.userIsKid == false)
            const SizedBox(width: 5),
          if ((rentMenuStatus != null && rentMenuStatus == "1") &&
              Constant.userIsKid == false)
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                focusColor: white.withValues(alpha: 0.5),
                onTap: () async {
                  printLog("newPage ======> ${widget.newPage}");
                  if (!mounted) return;
                  context.go(
                    '/${RoutesConstant.storePage}',
                    extra: widget.newPage ?? "",
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 32),
                    decoration: Utils.setBackground(
                        widget.newPage == RoutesConstant.storePage
                            ? white
                            : transparent,
                        12),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.fromLTRB(13, 0, 13, 0),
                    child: Consumer<HomeProvider>(
                      builder: (context, homeProvider, child) {
                        return InteractiveIcon(
                          builder: (isHovered) {
                            return MyText(
                              color: widget.newPage == RoutesConstant.storePage
                                  ? black
                                  : white,
                              multilanguage: true,
                              text: "bottommenu4",
                              maxline: 1,
                              overflow: TextOverflow.ellipsis,
                              fontsizeNormal: 14,
                              fontweight: FontWeight.w600,
                              fontsizeWeb: 14,
                              textalign: TextAlign.center,
                              fontstyle: FontStyle.normal,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<type.Result>>? _buildWebDropDownItems() {
    final List<type.Result> typeDropDownList = [];

    // 1. Add static "Home" at first position
    typeDropDownList.add(type.Result()
      ..id = -1 // use unique ID for static item
      ..name = "Home");

    // 2. Add API data in middle
    final apiData = homeProvider.sectionTypeModel.result ?? [];
    typeDropDownList.addAll(apiData);

    // 3. Add static "Store" at last position
    if ((rentMenuStatus != null && rentMenuStatus == "1") &&
        Constant.userIsKid == false) {
      typeDropDownList.add(type.Result()
        ..id = -2 // use unique ID for static item
        ..name = "Store");
    }

    // 4. Build DropdownMenuItem list
    return typeDropDownList.map((type.Result value) {
      final bool isRentSelected =
          (value.id == -2 && widget.newPage == RoutesConstant.storePage);
      final bool isHomeSelected = (value.id == -1 &&
          widget.newPage != RoutesConstant.storePage &&
          homeProvider.selectedIndex == 0);
      final bool isOtherTabSelected =
          widget.newPage != RoutesConstant.storePage &&
              (homeProvider.selectedIndex != -1) &&
              (typeDropDownList[homeProvider.selectedIndex].id ?? 0) ==
                  (value.id ?? 0) &&
              value.id != -1 &&
              value.id != -2;

      final bool isSelected =
          isHomeSelected || isRentSelected || isOtherTabSelected;

      return DropdownMenuItem<type.Result>(
        value: value,
        alignment: Alignment.center,
        child: FittedBox(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 35, minWidth: 100),
            decoration: Utils.setBackground(
              isSelected ? white : transparent,
              20,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: MyText(
              color: isSelected ? black : white,
              multilanguage: false,
              text: value.name ?? "",
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
      );
    }).toList();
  }

  Widget _buildUserLogin() {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        if (Constant.userID != null) {
          return InteractiveIcon(
            builder: (isHovered) {
              return Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Dimens.widthHomeUser),
                  onTap: () {
                    if (!mounted) return;
                    context.go(
                      "/${RoutesConstant.mySpacePage}",
                      extra: widget.newPage ?? "",
                    );
                  },
                  child: Container(
                    decoration: Utils.setBGWithBorder(
                        transparent,
                        isHovered ? colorPrimary : transparent,
                        Dimens.widthHomeUser,
                        2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Dimens.widthHomeUser),
                      child: (Constant.userIsKid == true)
                          ? MyImage(
                              imagePath: "kids.png",
                              fit: BoxFit.cover,
                              height: Dimens.heightHomeUser,
                              width: Dimens.widthHomeUser,
                            )
                          : MyNetworkImage(
                              imageUrl:
                                  (profileProvider.profileModel.status == 200 &&
                                          profileProvider.profileModel.result !=
                                              null)
                                      ? (((profileProvider.profileModel.result
                                                      ?.length ??
                                                  0) >
                                              0)
                                          ? (profileProvider.profileModel
                                                  .result?[0].image ??
                                              "")
                                          : "")
                                      : "",
                              fit: BoxFit.cover,
                              height: Dimens.heightHomeUser,
                              width: Dimens.widthHomeUser,
                            ),
                    ),
                  ),
                ),
              );
            },
          );
        } else {
          return InteractiveIcon(
            builder: (isHovered) {
              return Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(5),
                  focusColor: white.withValues(alpha: 0.5),
                  onTap: () async {
                    if (!mounted) return;
                    await Utils.openLogin(
                        context: context,
                        newPage: RoutesConstant.loginSocialPage);
                    _getData();
                    if (!mounted) return;
                    setState(() {});
                  },
                  child: Container(
                    height: 45,
                    constraints: const BoxConstraints(minWidth: 100),
                    decoration: Utils.setGradLTRBGWithBorder(
                        colorPrimary, colorPrimaryDark, transparent, 5, 0),
                    padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
                    alignment: Alignment.center,
                    child: MyText(
                      multilanguage: true,
                      color: (isHovered ? colorAccent : white),
                      text: "login",
                      maxline: 1,
                      textalign: TextAlign.center,
                      fontstyle: FontStyle.normal,
                      fontsizeNormal: 14,
                      fontsizeWeb: 14,
                      overflow: TextOverflow.ellipsis,
                      fontweight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }

  /* Search bar */
  Widget _buildSearch() {
    return Container(
      height: 50,
      width: 50,
      padding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () async {
          findProvider.setSearchLoading(true);
          if (!mounted) return;
          context.go(
            '/${RoutesConstant.searchPage}',
            extra: widget.newPage ?? "",
          );
        },
        child: Container(
          padding: const EdgeInsets.all(5),
          alignment: Alignment.center,
          child: MyImage(
            imagePath: "ic_find.png",
            color: white,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /* Details */
  Widget _buildPage() {
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: const BoxConstraints.expand(),
      child: WebArrowKeyScroll(
        scrollController: _mainScrollController,
        childToScroll: SingleChildScrollView(
          controller: _mainScrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              /* Post */
              widget.newChild,
              /* Web Footer */
              const SizedBox(height: 20),
              if (widget.newPage != RoutesConstant.clipsEpisodesPage)
                WebFooter(
                  newPage: widget.newPage,
                  oldPage: widget.oldPage,
                  reqText: '',
                  onTypeClick: () {
                    _scrollUp();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
