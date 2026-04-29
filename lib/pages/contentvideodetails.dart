import 'dart:io';
import 'package:flutter_locales/flutter_locales.dart';

import '../main.dart';
import '../model/download_item.dart';
import '../model/playermodel.dart';
import '../model/sharemodel.dart';
import '../pages/contentbyid.dart';
import '../pages/mydownloads.dart';
import '../players/model/vdociphermodel.dart';
import '../provider/connectivityprovider.dart';
import '../provider/videobyidprovider.dart';
import '../provider/videodownloadprovider.dart';
import '../provider/homeprovider.dart';
import '../routes/routes_constant.dart';
import '../shimmer/shimmerutils.dart';
import '../utils/adhelper.dart';
import '../webservice/apiservices.dart';
import '../widget/castcrew.dart';
import '../widget/myusernetworkimg.dart';
import '../widget/relatedvideoshow.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../model/contentdetailmodel.dart';
import '../utils/dimens.dart';
import '../widget/nodata.dart';
import '../provider/videodetailsprovider.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';
import '../utils/utils.dart';
import '../widget/mynetworkimg.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class ContentVideoDetails extends StatefulWidget {
  final int videoId, subVideoType, videoType, typeId;
  const ContentVideoDetails(
      this.videoId, this.subVideoType, this.videoType, this.typeId,
      {super.key});

  @override
  State<ContentVideoDetails> createState() => ContentVideoDetailsState();
}

class ContentVideoDetailsState extends State<ContentVideoDetails>
    with RouteAware {
  /* Create Instance And Initilize Hive */
  late Box<DownloadItem> downloadBox;

  /* Trailer init */
  VideoPlayerController? _trailerNormalController;
  YoutubePlayerController? _trailerYoutubeController;

  late VideoDownloadProvider downloadProvider;
  late ConnectivityProvider connectivityProvider;
  late VideoDetailsProvider videoDetailsProvider;
  late HomeProvider homeProvider;

  List<Cast>? directorList;
  Map<String, String> qualityUrlList = <String, String>{};
  String? rentStatus;

  @override
  void initState() {
    super.initState();
    homeProvider = Provider.of<HomeProvider>(context, listen: false);
    videoDetailsProvider =
        Provider.of<VideoDetailsProvider>(context, listen: false);
    connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    downloadProvider =
        Provider.of<VideoDownloadProvider>(context, listen: false);

    /* Initilize Hive */
    if (!kIsWeb) {
      if (Constant.userID != null) {
        if (Constant.userIsKid == true) {
          downloadBox = Hive.box<DownloadItem>(
              '${Constant.hiveDownloadBox}_${Constant.userID}_KID');
        } else {
          downloadBox = Hive.box<DownloadItem>(
              '${Constant.hiveDownloadBox}_${Constant.userID}');
        }
      } else {
        downloadBox = Hive.box<DownloadItem>(Constant.hiveDownloadBox);
      }
    }

    printLog("initState videoId ====> ${widget.videoId}");
    printLog("initState videoType ==> ${widget.videoType}");
    printLog("initState typeId =====> ${widget.typeId}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData(forceRefresh: false);
    });
  }

  Future<void> _getData({bool forceRefresh = false}) async {
    videoDetailsProvider.setLoading(true);
    Utils.getCurrencySymbol();
    rentStatus = await Utils.configByStatus(status: Constant.rentStatus);
    printLog('_getData rentStatus =====> $rentStatus');
    await Future.wait([
      videoDetailsProvider.getContentDetails(
          widget.typeId, widget.videoType, widget.videoId, widget.subVideoType,
          forceRefresh: forceRefresh),
      videoDetailsProvider.getRelatedContent(widget.typeId, widget.videoType,
          widget.videoId, widget.subVideoType, 1),
    ]);

    if (videoDetailsProvider.contentDetailModel.status == 200) {
      if (videoDetailsProvider.contentDetailModel.result != null &&
          (videoDetailsProvider.contentDetailModel.result?.length ?? 0) > 0) {
        /* Trailer set-up */
        _setUpTrailer();

        /* Set-up Subtitle URLs */
        Utils.setSubtitleURLs(
          subtitleUrl1:
              (videoDetailsProvider.contentDetailModel.result?[0].subtitle1 ??
                  ""),
          subtitleUrl2:
              (videoDetailsProvider.contentDetailModel.result?[0].subtitle2 ??
                  ""),
          subtitleUrl3:
              (videoDetailsProvider.contentDetailModel.result?[0].subtitle3 ??
                  ""),
          subtitleLang1: (videoDetailsProvider
                  .contentDetailModel.result?[0].subtitleLang1 ??
              ""),
          subtitleLang2: (videoDetailsProvider
                  .contentDetailModel.result?[0].subtitleLang2 ??
              ""),
          subtitleLang3: (videoDetailsProvider
                  .contentDetailModel.result?[0].subtitleLang3 ??
              ""),
        );

        /* Cast */
        if (videoDetailsProvider.contentDetailModel.result?[0].cast != null &&
            (videoDetailsProvider.contentDetailModel.result?[0].cast?.length ??
                    0) >
                0) {
          directorList = <Cast>[];
          for (int i = 0;
              i <
                  (videoDetailsProvider
                          .contentDetailModel.result?[0].cast?.length ??
                      0);
              i++) {
            if (videoDetailsProvider
                    .contentDetailModel.result?[0].cast?[i].type ==
                "Director") {
              Cast cast =
                  videoDetailsProvider.contentDetailModel.result?[0].cast?[i] ??
                      Cast();
              directorList?.add(cast);
              printLog("directorList size ===> ${directorList?.length ?? 0}");
            }
          }
        }
      }
    }

    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  /* ********* Widget LIFE CYCLES ********* */
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPop() {
    printLog("didPop");
    super.didPop();
  }

  @override
  void didPopNext() {
    printLog("didPopNext");
    if (videoDetailsProvider.contentDetailModel.result?[0].trailerType ==
        "youtube") {
      if (_trailerYoutubeController == null) {
        loadTrailer(
            videoDetailsProvider.contentDetailModel.result?[0].trailerUrl ?? "",
            videoDetailsProvider.contentDetailModel.result?[0].trailerType ??
                "");
      } else {
        if (_trailerYoutubeController != null &&
            _trailerYoutubeController?.value.playerState != PlayerState.ended) {
          _trailerYoutubeController?.seekTo(seconds: 0.0);
          _trailerYoutubeController?.playVideo();
        }
      }
    } else {
      if (_trailerNormalController == null) {
        loadTrailer(
            videoDetailsProvider.contentDetailModel.result?[0].trailerUrl ?? "",
            videoDetailsProvider.contentDetailModel.result?[0].trailerType ??
                "");
      } else {
        if (_trailerNormalController != null &&
            !(_trailerNormalController?.value.isCompleted ?? false)) {
          _trailerNormalController?.play();
        }
      }
    }
    super.didPopNext();
  }

  @override
  void didPush() {
    printLog("didPush");
    super.didPush();
  }

  @override
  void didPushNext() {
    printLog("didPushNext");
    if (_trailerYoutubeController != null) {
      _trailerYoutubeController?.close();
      _trailerYoutubeController = null;
    }
    if (_trailerNormalController != null) {
      _trailerNormalController?.dispose();
      _trailerNormalController = null;
    }
    super.didPushNext();
  }
  /* ********* Widget LIFE CYCLES ********* */

  /* ********* Trailer Set-Up & Loading START ********* */
  void _setUpTrailer() {
    printLog(
        "trailerUrl ===========> ${videoDetailsProvider.contentDetailModel.result?[0].trailerUrl}");
    printLog(
        "trailerType ==========> ${videoDetailsProvider.contentDetailModel.result?[0].trailerType}");
    if (videoDetailsProvider.contentDetailModel.result?[0].trailerUrl != null ||
        videoDetailsProvider.contentDetailModel.result?[0].trailerUrl != "") {
      if (videoDetailsProvider.contentDetailModel.result?[0].trailerType ==
          "youtube") {
        if (_trailerYoutubeController == null) {
          loadTrailer(
              videoDetailsProvider.contentDetailModel.result?[0].trailerUrl ??
                  "",
              videoDetailsProvider.contentDetailModel.result?[0].trailerType ??
                  "");
        } else {
          _trailerYoutubeController?.seekTo(seconds: 0.0);
        }
      } else {
        if (_trailerNormalController == null) {
          loadTrailer(
              videoDetailsProvider.contentDetailModel.result?[0].trailerUrl ??
                  "",
              videoDetailsProvider.contentDetailModel.result?[0].trailerType ??
                  "");
        } else {
          _trailerNormalController?.seekTo(Duration.zero);
        }
      }
    }
  }

  Future<void> loadTrailer(dynamic trailerUrl, trailerType) async {
    printLog("loadTrailer URL ==========> $trailerUrl");
    printLog("loadTrailer Type =========> $trailerType");
    bool? isAutoPlay = await Utils.getTrailerAutoPlay();
    printLog("loadTrailer isAutoPlay ===> $isAutoPlay");
    if (isAutoPlay && trailerUrl != null && trailerUrl.toString().isNotEmpty) {
      if (trailerType == "youtube") {
        var videoId = YoutubePlayerController.convertUrlToId(trailerUrl ?? "");
        printLog("Youtube Trailer videoId :====> $videoId");
        _trailerYoutubeController = YoutubePlayerController.fromVideoId(
          videoId: videoId ?? '',
          autoPlay: true,
          params: const YoutubePlayerParams(
            showControls: false,
            showVideoAnnotations: false,
            strictRelatedVideos: false,
            playsInline: false,
            mute: false,
            showFullscreenButton: false,
            loop: false,
          ),
        );
        _trailerYoutubeController?.playVideo();
        _trailerYoutubeController?.listen(
          (event) {
            printLog("event =====> $event");
            if (event.playerState == PlayerState.ended) {
              setState(() {});
            }
          },
        );
        Future.delayed(Duration.zero).then((value) {
          if (!mounted) return;
          setState(() {});
        });
      } else {
        _trailerNormalController = VideoPlayerController.networkUrl(
          Uri.parse(trailerUrl ?? ""),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        )..initialize().then((value) {
            if (!mounted) return;
            setState(() {
              printLog(
                  "isPlaying =========> ${_trailerNormalController?.value.isPlaying}");
              _trailerNormalController?.play();
            });
          });
        _trailerNormalController?.setLooping(false);
        _trailerNormalController?.addListener(() async {
          if (_trailerNormalController?.value.hasError ?? false) {
            printLog(
                "VideoScreen errorDescription ====> ${_trailerNormalController?.value.errorDescription}");
          }
          if (_trailerNormalController?.value.isCompleted ?? false) {
            setState(() {});
          }
        });
      }
    }
  }
  /* ********* Trailer Set-Up & Loading END *********** */

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    routeObserver.unsubscribe(this);
    if (downloadProvider.dProgress >= 100) {
      downloadProvider.clearProvider();
      videoDetailsProvider.clearProvider();
    }
    if (_trailerYoutubeController != null) {
      _trailerYoutubeController?.close();
      _trailerYoutubeController = null;
    }
    if (_trailerNormalController != null) {
      _trailerNormalController?.dispose();
      _trailerNormalController = null;
    }
    super.dispose();
  }

  bool _checkExpiry() {
    printLog(
        "rentExpiryDate =======> ${videoDetailsProvider.contentDetailModel.result?[0].rentExpiryDate}");
    if ((videoDetailsProvider.contentDetailModel.result?[0].rentExpiryDate ??
            "") !=
        "") {
      return DateTime.now().isBefore(DateTime.parse(
          videoDetailsProvider.contentDetailModel.result?[0].rentExpiryDate ??
              ""));
    } else {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: widget.key,
      backgroundColor: appBgColor,
      body: SafeArea(
        child: _buildUIWithAppBar(),
      ),
    );
  }

  Widget _buildUIWithAppBar() {
    if (videoDetailsProvider.isLoading) {
      return SingleChildScrollView(
        child: ShimmerUtils.buildDetailMobileShimmer(context, "video"),
      );
    } else {
      if (videoDetailsProvider.contentDetailModel.status == 200 &&
          videoDetailsProvider.contentDetailModel.result != null) {
        return _buildPage();
      } else {
        return const NoData(title: '', subTitle: '');
      }
    }
  }

  Widget _buildPage() {
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: const BoxConstraints.expand(),
      child: RefreshIndicator(
        backgroundColor: white,
        color: complimentryColor,
        displacement: 80,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 1500))
              .then((value) {
            videoDetailsProvider.setLoading(true);
            Future.delayed(Duration.zero).then((value) {
              if (!mounted) return;
              setState(() {});
            });
            _getData(forceRefresh: true);
          });
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              /* Poster */
              ((videoDetailsProvider.contentDetailModel.result?[0].trailerUrl ??
                          "")
                      .isNotEmpty)
                  ? setUpTrailerView()
                  : _buildMobilePoster(),

              /* Other Details */
              const SizedBox(height: 15),
              MyText(
                color: titleTextColor,
                text: videoDetailsProvider.contentDetailModel.result?[0].name ??
                    "",
                textalign: TextAlign.center,
                fontsizeNormal: 25,
                fontsizeWeb: 25,
                fontweight: FontWeight.w700,
                multilanguage: false,
                maxline: 5,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
                withShaderMask: true,
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      /* Release Year */
                      if (videoDetailsProvider
                                  .contentDetailModel.result?[0].releaseDate !=
                              null &&
                          videoDetailsProvider
                                  .contentDetailModel.result?[0].releaseDate !=
                              "")
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: MyText(
                            color: descTextColor,
                            text: DateFormat('yyyy').format(DateTime.parse(
                                videoDetailsProvider.contentDetailModel
                                        .result?[0].releaseDate ??
                                    "")),
                            textalign: TextAlign.center,
                            fontsizeNormal: 13,
                            fontsizeWeb: 15,
                            fontweight: FontWeight.w500,
                            multilanguage: false,
                            maxline: 1,
                            overflow: TextOverflow.ellipsis,
                            fontstyle: FontStyle.normal,
                          ),
                        ),
                      if (videoDetailsProvider
                                  .contentDetailModel.result?[0].releaseDate !=
                              null &&
                          videoDetailsProvider
                                  .contentDetailModel.result?[0].releaseDate !=
                              "")
                        Container(
                          height: 3,
                          width: 3,
                          decoration: Utils.setBackground(white, 3),
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      /* Duration */
                      if (videoDetailsProvider
                              .contentDetailModel.result?[0].videoDuration !=
                          null)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: MyText(
                            color: descTextColor,
                            multilanguage: false,
                            text: ((videoDetailsProvider.contentDetailModel
                                            .result?[0].videoDuration ??
                                        0) >
                                    0)
                                ? Utils.convertTimeToText(videoDetailsProvider
                                        .contentDetailModel
                                        .result?[0]
                                        .videoDuration ??
                                    0)
                                : "",
                            textalign: TextAlign.center,
                            fontsizeNormal: 13,
                            fontsizeWeb: 15,
                            fontweight: FontWeight.w500,
                            maxline: 1,
                            overflow: TextOverflow.ellipsis,
                            fontstyle: FontStyle.normal,
                          ),
                        ),
                      if (videoDetailsProvider
                              .contentDetailModel.result?[0].videoDuration !=
                          null)
                        Container(
                          height: 3,
                          width: 3,
                          decoration: Utils.setBackground(white, 3),
                          margin: const EdgeInsets.only(right: 8),
                        ),
                    ],
                  ),
                ),
              ),

              /* Release Date */
              _buildReleaseDate(),

              /* Continue Watching Button / Watch Now button */
              Container(
                margin: const EdgeInsets.only(top: 18, bottom: 0),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: (widget.videoType == Constant.upcomingContentType)
                    ? _buildWatchTrailer()
                    : _buildWatchNow(),
              ),
              const SizedBox(height: 20),

              /* ************** Basic Details & Feature Buttons ************** */
              /* ************** Rent & Premium TAGs ************** */
              /* Prime TAG */
              if ((videoDetailsProvider
                          .contentDetailModel.result?[0].isPremium ??
                      0) ==
                  1)
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  margin: EdgeInsets.only(
                    bottom: ((videoDetailsProvider
                                    .contentDetailModel.result?[0].isRent ??
                                0) ==
                            1)
                        ? 0
                        : 20,
                  ),
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      MyText(
                        color: colorPrimary,
                        text: "primetag",
                        textalign: TextAlign.start,
                        fontsizeNormal: 12,
                        fontsizeWeb: 14,
                        fontweight: FontWeight.w700,
                        multilanguage: true,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        fontstyle: FontStyle.normal,
                      ),
                      const SizedBox(height: 2),
                      MyText(
                        color: descTextColor,
                        text: "primetagdesc",
                        multilanguage: true,
                        textalign: TextAlign.center,
                        fontsizeNormal: 12,
                        fontsizeWeb: 14,
                        fontweight: FontWeight.w500,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        fontstyle: FontStyle.normal,
                      ),
                    ],
                  ),
                ),

              /* Rent TAG */
              if (widget.videoType != Constant.upcomingContentType)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  alignment: Alignment.centerLeft,
                  child: _buildRentExpiryTAG(),
                ),
              /* ************** Rent & Premium TAGs ************** */

              /* Category */
              Container(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                  child: MyText(
                    color: titleTextColor,
                    text: Utils.convertHalfStopToVLine(videoDetailsProvider
                            .contentDetailModel.result?[0].categoryName ??
                        ""),
                    textalign: TextAlign.start,
                    fontsizeNormal: 13,
                    fontweight: FontWeight.w600,
                    fontsizeWeb: 15,
                    multilanguage: false,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    fontstyle: FontStyle.normal,
                  ),
                ),
              ),
              /* Language */
              Container(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
                  child: MyText(
                    color: titleTextColor,
                    text: videoDetailsProvider
                            .contentDetailModel.result?[0].languageName ??
                        "",
                    textalign: TextAlign.start,
                    fontsizeNormal: 13,
                    fontweight: FontWeight.w600,
                    fontsizeWeb: 15,
                    multilanguage: false,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    fontstyle: FontStyle.normal,
                  ),
                ),
              ),
              /* Description */
              const SizedBox(height: 7),
              Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                width: MediaQuery.of(context).size.width,
                constraints: const BoxConstraints(minHeight: 0),
                child: ExpandableText(
                  videoDetailsProvider
                          .contentDetailModel.result?[0].description ??
                      "",
                  expandText: Locales.string(context, "more"),
                  collapseText: Locales.string(context, "less"),
                  maxLines: Dimens.isBigScreen(context) ? 50 : 3,
                  linkColor: descTextColor,
                  expandOnTextTap: true,
                  collapseOnTextTap: true,
                  style: GoogleFonts.inter(
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.normal,
                      color: descTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              /* Included Features buttons */
              _buildFeatureBtns(),
              /* ************** Basic Details & Feature Buttons ************** */

              /* AdMob Banner */
              Utils.showBannerAd(context),

              /* Related ~ More Details */
              Container(
                margin: const EdgeInsets.all(0),
                child: Consumer<VideoDetailsProvider>(
                  builder: (context, videoDetailsProvider, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /* Customers also watched */
                        RelatedVideoShow(
                          relatedDataList:
                              videoDetailsProvider.relatedContentModel.result,
                          newPage: '',
                          oldPage: '',
                          reqText: '',
                          videoId: widget.videoId,
                          subVideoType: widget.subVideoType,
                          videoType: widget.videoType,
                          typeId: widget.typeId,
                        ),
                        /* Cast & Crew */
                        CastCrew(
                          castList: videoDetailsProvider
                              .contentDetailModel.result?[0].cast,
                          newPage: '',
                        ),
                        /* Director */
                        _buildDirector(),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBtns() {
    if (widget.videoType != Constant.upcomingContentType) {
      return Container(
        margin: const EdgeInsets.only(top: 25, bottom: 0),
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /* Rent Button */
              _buildRentBtn(),

              /* Start Over & Trailer */
              Consumer<VideoDetailsProvider>(
                builder: (context, videoDetailsProvider, child) {
                  if ((videoDetailsProvider
                                  .contentDetailModel.result?[0].stopTime ??
                              0) >
                          0 &&
                      videoDetailsProvider
                              .contentDetailModel.result?[0].videoDuration !=
                          null) {
                    /* Start Over */
                    return _buildFeatureBtnItem(
                      icon: 'ic_restart.png',
                      title: 'startover',
                      multilanguage: true,
                      isRent: false,
                      onClick: () async {
                        openPlayer("startOver");
                      },
                    );
                  } else {
                    /* Trailer */
                    return _buildFeatureBtnItem(
                      icon: 'ic_borderplay.png',
                      title: 'trailer',
                      multilanguage: true,
                      isRent: false,
                      onClick: () {
                        openPlayer("Trailer");
                      },
                    );
                  }
                },
              ),

              /* Download */
              if (!(kIsWeb) || !(Constant.isTV))
                (videoDetailsProvider
                                .contentDetailModel.result?[0].isDownload ??
                            0) ==
                        1
                    ? _buildDownloadWithSubCheck()
                    : const SizedBox.shrink(),

              /* Watchlist */
              Consumer<VideoDetailsProvider>(
                builder: (context, videoDetailsProvider, child) {
                  return _buildFeatureBtnItem(
                    icon: ((videoDetailsProvider
                                    .contentDetailModel.result?[0].isBookmark ??
                                0) ==
                            1)
                        ? 'watchlist_remove.png'
                        : 'ic_plus.png',
                    title: 'watchlist',
                    multilanguage: true,
                    isRent: false,
                    onClick: () async {
                      printLog(
                          "isBookmark ====> ${videoDetailsProvider.contentDetailModel.result?[0].isBookmark ?? 0}");
                      AdHelper.showFullscreenAd(context, Constant.rewardAdType,
                          () async {
                        if (Constant.userID != null) {
                          await videoDetailsProvider.setBookMark(
                            context,
                            widget.videoType,
                            widget.subVideoType,
                            widget.videoId,
                          );
                        } else {
                          await Utils.openLogin(context: context, newPage: "");
                        }
                      });
                    },
                  );
                },
              ),

              /* Rate (Like/Dislike) */
              Consumer<VideoDetailsProvider>(
                builder: (context, videoDetailsProvider, child) {
                  if ((videoDetailsProvider
                              .contentDetailModel.result?[0].isLike ??
                          0) !=
                      1) {
                    return SizedBox.shrink();
                  }
                  return _buildFeatureBtnItem(
                    icon: ((videoDetailsProvider
                                    .contentDetailModel.result?[0].isUserLike ??
                                0) ==
                            1)
                        ? 'ic_heartfill.png'
                        : 'ic_heart.png',
                    title: ((videoDetailsProvider
                                    .contentDetailModel.result?[0].isUserLike ??
                                0) ==
                            1)
                        ? 'rated'
                        : 'rate',
                    multilanguage: true,
                    isRent: false,
                    onClick: () async {
                      printLog(
                          "isUserLike ====> ${videoDetailsProvider.contentDetailModel.result?[0].isUserLike ?? 0}");
                      AdHelper.showFullscreenAd(context, Constant.rewardAdType,
                          () async {
                        if (Utils.checkLoginUser(context)) {
                          await videoDetailsProvider.setLikeDislike(
                            context,
                            subVideoType: widget.subVideoType,
                            videoType: widget.videoType,
                            videoId: widget.videoId,
                          );
                        }
                      });
                    },
                  );
                },
              ),

              /* More */
              if (!(kIsWeb) || !(Constant.isTV))
                _buildFeatureBtnItem(
                  icon: 'ic_more.png',
                  title: 'more',
                  multilanguage: true,
                  isRent: false,
                  onClick: () {
                    buildMoreDialog(videoDetailsProvider
                            .contentDetailModel.result?[0].stopTime ??
                        0);
                  },
                ),
            ],
          ),
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _buildFeatureBtnItem({
    required String title,
    required String icon,
    required bool multilanguage,
    required bool isRent,
    required Function()? onClick,
  }) {
    return Container(
      alignment: Alignment.center,
      child: InkWell(
        onTap: onClick,
        borderRadius: BorderRadius.circular(5),
        focusColor: gray.withValues(alpha: 0.5),
        child: Container(
          padding: const EdgeInsets.all(5.0),
          constraints:
              BoxConstraints(minWidth: (Dimens.featureSize + 20 /* Margin */)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                alignment: Alignment.center,
                child: MyImage(
                  width: Dimens.featureIconSize,
                  height: Dimens.featureIconSize,
                  color: isRent ? colorAccent : white,
                  imagePath: icon,
                ),
              ),
              const SizedBox(height: 10),
              MyText(
                color: isRent ? colorAccent : descTextColor,
                text: title,
                multilanguage: multilanguage,
                fontsizeNormal: 11,
                fontsizeWeb: 14,
                fontweight: FontWeight.w600,
                maxline: 2,
                overflow: TextOverflow.ellipsis,
                textalign: TextAlign.center,
                fontstyle: FontStyle.normal,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReleaseDate() {
    if (widget.videoType == Constant.upcomingContentType) {
      if (videoDetailsProvider.contentDetailModel.result?[0].releaseDate !=
              null &&
          (videoDetailsProvider.contentDetailModel.result?[0].releaseDate ??
                  "") !=
              "") {
        return Container(
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MyText(
                color: titleTextColor,
                text: "release_date",
                multilanguage: true,
                textalign: TextAlign.center,
                fontsizeNormal: 12,
                fontsizeWeb: 14,
                fontweight: FontWeight.w600,
                maxline: 1,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
              ),
              const SizedBox(width: 5),
              MyText(
                color: colorPrimary,
                text: ":",
                multilanguage: false,
                textalign: TextAlign.center,
                fontsizeNormal: 12,
                fontsizeWeb: 14,
                fontweight: FontWeight.w600,
                maxline: 1,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
              ),
              const SizedBox(width: 5),
              MyText(
                color: colorAccent,
                text: DateFormat("dd MMM, yyyy").format(DateTime.parse(
                    videoDetailsProvider
                            .contentDetailModel.result?[0].releaseDate ??
                        "")),
                multilanguage: false,
                textalign: TextAlign.center,
                fontsizeNormal: 14,
                fontsizeWeb: 15,
                fontweight: FontWeight.w700,
                maxline: 2,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
              ),
            ],
          ),
        );
      } else {
        return const SizedBox.shrink();
      }
    } else {
      return const SizedBox.shrink();
    }
  }

  /* ********************************** */
  /* Trailer View START *************** */
  Widget setUpTrailerView() {
    if ((videoDetailsProvider.contentDetailModel.result?[0].trailerType ??
            "") ==
        "youtube") {
      if (_trailerYoutubeController != null) {
        if (_trailerYoutubeController?.value.playerState != PlayerState.ended) {
          return _buildTrailerView(
              videoDetailsProvider.contentDetailModel.result?[0].trailerType ??
                  "");
        } else {
          return _buildMobilePoster();
        }
      } else {
        return _buildMobilePoster();
      }
    } else {
      if (_trailerNormalController != null &&
          (_trailerNormalController?.value.isInitialized ?? false)) {
        if (!(_trailerNormalController?.value.isCompleted ?? false) &&
            (_trailerNormalController?.value.isPlaying ?? false)) {
          return _buildTrailerView(
              videoDetailsProvider.contentDetailModel.result?[0].trailerType ??
                  "");
        } else {
          return _buildMobilePoster();
        }
      } else {
        return _buildMobilePoster();
      }
    }
  }

  Widget _buildTrailerView(String trailerType) {
    if (trailerType == "youtube") {
      return VisibilityDetector(
        key: Key('video_${widget.videoId}'),
        onVisibilityChanged: (visibilityInfo) async {
          if (!mounted) return;
          var visiblePercentage = visibilityInfo.visibleFraction * 100;
          printLog(
              '=========== Widget ${visibilityInfo.key} is $visiblePercentage% visible===========');
          if (_trailerYoutubeController != null) {
            if (_trailerYoutubeController?.value.playerState !=
                PlayerState.ended) {
              if (visiblePercentage > 50.0) {
                await _trailerYoutubeController?.playVideo();
              } else {
                await _trailerYoutubeController?.pauseVideo();
              }
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(0),
                  width: MediaQuery.of(context).size.width,
                  height: Dimens.getResponsiveHeight(context, 24),
                  child: AbsorbPointer(
                    absorbing: true,
                    child: YoutubePlayer(
                      controller: _trailerYoutubeController!,
                      enableFullScreenOnVerticalDrag: false,
                    ),
                  ),
                ),
                if (!kIsWeb)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Utils.buildCloseBtn(context),
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      return VisibilityDetector(
        key: Key('video_${widget.videoId}'),
        onVisibilityChanged: (visibilityInfo) async {
          if (!mounted) return;
          var visiblePercentage = visibilityInfo.visibleFraction * 100;
          printLog(
              '=========== Widget ${visibilityInfo.key} is $visiblePercentage% visible===========');
          if (_trailerNormalController != null &&
              (_trailerNormalController?.value.isInitialized ?? false)) {
            if (!(_trailerNormalController?.value.isCompleted ?? false)) {
              if (visiblePercentage > 50.0) {
                await _trailerNormalController?.play();
              } else {
                await _trailerNormalController?.pause();
              }
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(0),
                  width: MediaQuery.of(context).size.width,
                  height: Dimens.getResponsiveHeight(context, 24),
                  child: SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _trailerNormalController?.value.size.width,
                        height: _trailerNormalController?.value.size.height,
                        child: AspectRatio(
                          aspectRatio:
                              _trailerNormalController?.value.aspectRatio ??
                                  (16 / 9),
                          child: AbsorbPointer(
                            absorbing: true,
                            child: VideoPlayer(_trailerNormalController!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Utils.buildCloseBtn(context),
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }
  /* ***************** Trailer View END */
  /* ********************************** */

  Widget _buildMobilePoster() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          /* Poster & Trailer player */
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(0),
              width: MediaQuery.of(context).size.width,
              height: Dimens.getResponsiveHeight(context, 24),
              child: MyNetworkImage(
                fit: BoxFit.fill,
                imageUrl: videoDetailsProvider
                            .contentDetailModel.result?[0].landscape !=
                        ""
                    ? (videoDetailsProvider
                            .contentDetailModel.result?[0].landscape ??
                        "")
                    : (videoDetailsProvider
                            .contentDetailModel.result?[0].thumbnail ??
                        ""),
              ),
            ),
          ),
          if (!kIsWeb)
            Positioned(
              top: 8,
              right: 8,
              child: Utils.buildCloseBtn(context),
            ),
        ],
      ),
    );
  }

  Widget _buildWatchTrailer() {
    return Container(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () {
          openPlayer("Trailer");
        },
        focusColor: descTextColor,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 45,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width,
          ),
          decoration: Utils.setBackground(white, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MyImage(
                  width: 15,
                  height: 15,
                  imagePath: "ic_play.png",
                  color: black,
                ),
                const SizedBox(width: 15),
                MyText(
                  color: black,
                  text: "watch_trailer",
                  multilanguage: true,
                  textalign: TextAlign.start,
                  fontsizeNormal: 14,
                  fontweight: FontWeight.w600,
                  fontsizeWeb: 16,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  fontstyle: FontStyle.normal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatchNow() {
    return Container(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () {
          openPlayer("Video");
        },
        focusColor: descTextColor,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 45,
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width,
          ),
          decoration: Utils.setBackground(white, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        MyImage(
                          width: 15,
                          height: 15,
                          imagePath: "ic_play.png",
                          color: black,
                        ),
                        const SizedBox(width: 15),
                        MyText(
                          color: black,
                          text: "watch_now",
                          multilanguage: true,
                          textalign: TextAlign.start,
                          fontsizeNormal: 14,
                          fontweight: FontWeight.w600,
                          fontsizeWeb: 16,
                          maxline: 1,
                          overflow: TextOverflow.ellipsis,
                          fontstyle: FontStyle.normal,
                        ),
                      ],
                    ),
                  ),
                ),
                if ((videoDetailsProvider
                                .contentDetailModel.result?[0].stopTime ??
                            0) >
                        0 &&
                    videoDetailsProvider
                            .contentDetailModel.result?[0].videoDuration !=
                        null)
                  Container(
                    height: 3,
                    constraints: const BoxConstraints(minWidth: 0),
                    child: LinearPercentIndicator(
                      padding: const EdgeInsets.all(0),
                      barRadius: const Radius.circular(2),
                      lineHeight: 4,
                      percent: Utils.getPercentage(
                          videoDetailsProvider.contentDetailModel.result?[0]
                                  .videoDuration ??
                              0,
                          videoDetailsProvider
                                  .contentDetailModel.result?[0].stopTime ??
                              0),
                      backgroundColor: secProgressColor,
                      progressColor: complimentryColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRentExpiryTAG() {
    if ((videoDetailsProvider.contentDetailModel.result?[0].isRent ?? 0) == 1) {
      if ((videoDetailsProvider.contentDetailModel.result?[0].rentBuy ?? 0) ==
              1 &&
          (videoDetailsProvider.contentDetailModel.result?[0].rentExpiryDate ??
                  "")
              .isNotEmpty) {
        return FittedBox(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
            margin: EdgeInsets.only(
                top: ((videoDetailsProvider
                                .contentDetailModel.result?[0].isPremium ??
                            0) ==
                        1)
                    ? 10
                    : 0,
                bottom: 20),
            decoration:
                Utils.setBGWithBorder(transparent, defaultIconColor, 3, 0.4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MyText(
                  multilanguage: true,
                  color: titleTextColor,
                  text: _checkExpiry() ? "rent_expire_on" : "rent_expired",
                  fontsizeNormal: 14,
                  fontweight: FontWeight.w500,
                  fontsizeWeb: 16,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  textalign: TextAlign.start,
                  fontstyle: FontStyle.normal,
                  isShadowText: true,
                ),
                if (_checkExpiry())
                  MyText(
                    color: titleTextColor,
                    multilanguage: false,
                    text: " : ",
                    fontsizeNormal: 14,
                    fontweight: FontWeight.w600,
                    fontsizeWeb: 16,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    textalign: TextAlign.start,
                    fontstyle: FontStyle.normal,
                    isShadowText: true,
                  ),
                if (_checkExpiry())
                  MyText(
                    color: _checkExpiry() ? colorPrimary : redColor,
                    multilanguage: false,
                    text: DateFormat("dd MMM, yyyy").format(DateTime.parse(
                        videoDetailsProvider
                                .contentDetailModel.result?[0].rentExpiryDate ??
                            "")),
                    fontsizeNormal: 14,
                    fontweight: FontWeight.w600,
                    fontsizeWeb: 14,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    textalign: TextAlign.start,
                    fontstyle: FontStyle.normal,
                    isShadowText: true,
                  ),
              ],
            ),
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          margin: EdgeInsets.only(
              top: ((videoDetailsProvider
                              .contentDetailModel.result?[0].isPremium ??
                          0) ==
                      1)
                  ? 10
                  : 0,
              bottom: 20),
          width: MediaQuery.of(context).size.width,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: Utils.setBackground(complimentryColor, 18),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(1),
                child: MyText(
                  color: white,
                  text: Constant.currencySymbol,
                  textalign: TextAlign.center,
                  fontsizeNormal: 10,
                  fontsizeWeb: 12,
                  fontweight: FontWeight.w700,
                  multilanguage: false,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  fontstyle: FontStyle.normal,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 5),
                child: MyText(
                  color: titleTextColor,
                  text: "renttag",
                  textalign: TextAlign.center,
                  fontsizeNormal: 12,
                  fontsizeWeb: 14,
                  fontweight: FontWeight.w600,
                  multilanguage: true,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  fontstyle: FontStyle.normal,
                ),
              ),
            ],
          ),
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildRentBtn() {
    if (rentStatus != null && rentStatus != "1" && Constant.userIsKid == true) {
      return const SizedBox.shrink();
    }
    if ((videoDetailsProvider.contentDetailModel.result?[0].isRent ?? 0) == 1) {
      if ((videoDetailsProvider.contentDetailModel.result?[0].rentBuy ?? 0) ==
          1) {
        return _buildFeatureBtnItem(
          icon: 'ic_purchased.png',
          title: "purchased",
          multilanguage: true,
          isRent: true,
          onClick: () async {},
        );
      } else {
        return _buildFeatureBtnItem(
          icon: 'ic_store.png',
          title:
              "${Constant.currencySymbol}${videoDetailsProvider.contentDetailModel.result?[0].price ?? 0} for Rent",
          multilanguage: false,
          isRent: true,
          onClick: () async {
            if (Constant.userID != null) {
              dynamic isRented = await Utils.paymentForRent(
                context: context,
                videoId: videoDetailsProvider.contentDetailModel.result?[0].id
                        .toString() ??
                    '',
                rentPrice: videoDetailsProvider
                        .contentDetailModel.result?[0].price
                        .toString() ??
                    '',
                vTitle: videoDetailsProvider.contentDetailModel.result?[0].name
                        .toString() ??
                    '',
                typeId: videoDetailsProvider
                        .contentDetailModel.result?[0].typeId
                        .toString() ??
                    '',
                vType: videoDetailsProvider
                        .contentDetailModel.result?[0].videoType
                        .toString() ??
                    '',
                subVideoType: videoDetailsProvider
                        .contentDetailModel.result?[0].subVideoType
                        .toString() ??
                    '',
                producerId: videoDetailsProvider
                        .contentDetailModel.result?[0].producerId
                        .toString() ??
                    '',
                rentProductId: (kIsWeb)
                    ? (videoDetailsProvider
                            .contentDetailModel.result?[0].webPriceId
                            .toString() ??
                        '')
                    : (Platform.isIOS
                        ? (videoDetailsProvider
                                .contentDetailModel.result?[0].iosProductPackage
                                .toString() ??
                            '')
                        : (videoDetailsProvider.contentDetailModel.result?[0]
                                .androidProductPackage
                                .toString() ??
                            '')),
                newPage: '',
                oldPage: '',
                reqText: '',
              );
              if (isRented != null && isRented == true) {
                _getData(forceRefresh: true);
              }
            } else {
              await Utils.openLogin(context: context, newPage: "");
              _getData(forceRefresh: true);
            }
          },
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }

  /* Director */
  Widget _buildDirector() {
    if (directorList != null && (directorList?.length ?? 0) > 0) {
      return Container(
        padding: EdgeInsets.only(
          left: Dimens.isBigScreen(context) ? 35 : 12,
          right: Dimens.isBigScreen(context) ? 35 : 12,
        ),
        constraints: BoxConstraints(
            minHeight: Dimens.isBigScreen(context)
                ? Dimens.heightCastWeb
                : Dimens.heightCast),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: MediaQuery.of(context).size.width,
              height: 0.5,
              color: grayDark,
              margin: const EdgeInsets.fromLTRB(0, 8, 0, 15),
            ),
            SizedBox(
              width: Dimens.isBigScreen(context)
                  ? (MediaQuery.of(context).size.width * 0.7)
                  : MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(Dimens.cardRadius),
                    focusColor: white,
                    onTap: () async {
                      final videoByIDProvider = Provider.of<VideoByIDProvider>(
                          context,
                          listen: false);
                      videoByIDProvider.setLoading(true);
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) {
                          return ContentByID(
                            directorList?[0].id ?? 0,
                            directorList?[0].name ?? "",
                            'ByCast',
                          );
                        }),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2.0),
                      height: Dimens.isBigScreen(context)
                          ? Dimens.heightCastWeb
                          : Dimens.heightCast,
                      width: Dimens.isBigScreen(context)
                          ? Dimens.widthCastWeb
                          : Dimens.widthCast,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            Dimens.isBigScreen(context)
                                ? Dimens.cardRadiusMedium
                                : Dimens.cardRadius),
                        child: MyUserNetworkImage(
                          imageUrl: directorList?[0].image ?? "",
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        MyText(
                          color: titleTextColor,
                          multilanguage: false,
                          text: directorList?[0].name ?? "",
                          fontstyle: FontStyle.normal,
                          maxline: 1,
                          fontsizeNormal: 12,
                          fontsizeWeb: 15,
                          fontweight: FontWeight.w500,
                          overflow: TextOverflow.ellipsis,
                          textalign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        MyText(
                          color: descTextColor,
                          text: directorList?[0].personalInfo ?? "",
                          textalign: TextAlign.start,
                          multilanguage: false,
                          fontsizeNormal: 12,
                          fontweight: FontWeight.w500,
                          fontsizeWeb: 14,
                          maxline: 7,
                          overflow: TextOverflow.ellipsis,
                          fontstyle: FontStyle.normal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  /* ========= Download ========= */
  Widget _buildDownloadWithSubCheck() {
    if ((videoDetailsProvider.contentDetailModel.result?[0].isDownload ?? 0) ==
        0) {
      return const SizedBox.shrink();
    }
    if ((videoDetailsProvider.contentDetailModel.result?[0].isPremium ?? 0) ==
            1 &&
        (videoDetailsProvider.contentDetailModel.result?[0].isRent ?? 0) == 1) {
      if ((videoDetailsProvider.contentDetailModel.result?[0].isBuy ?? 0) ==
              1 ||
          (videoDetailsProvider.contentDetailModel.result?[0].rentBuy ?? 0) ==
              1) {
        return _buildDownloadBtn();
      } else {
        return const SizedBox.shrink();
      }
    } else if ((videoDetailsProvider.contentDetailModel.result?[0].isPremium ??
            0) ==
        1) {
      if ((videoDetailsProvider.contentDetailModel.result?[0].isBuy ?? 0) ==
          1) {
        return _buildDownloadBtn();
      } else {
        return const SizedBox.shrink();
      }
    } else if ((videoDetailsProvider.contentDetailModel.result?[0].isRent ??
            0) ==
        1) {
      if ((videoDetailsProvider.contentDetailModel.result?[0].rentBuy ?? 0) ==
          1) {
        return _buildDownloadBtn();
      } else {
        return const SizedBox.shrink();
      }
    } else {
      return _buildDownloadBtn();
    }
  }

  Widget _buildDownloadBtn() {
    if ((videoDetailsProvider.contentDetailModel.result?[0].videoUploadType ==
                "server_video" ||
            videoDetailsProvider
                    .contentDetailModel.result?[0].videoUploadType ==
                "external") &&
        (videoDetailsProvider.contentDetailModel.result?[0].videoExtension ??
                "")
            .contains("mp4")) {
      return Consumer2<VideoDetailsProvider, VideoDownloadProvider>(
        builder: (context, videoDetailsProvider, downloadProvider, child) {
          bool isInDownload = false;
          if (!kIsWeb) {
            if (downloadBox.isOpen &&
                downloadBox.values.toList().isNotEmpty &&
                (downloadBox.values.toList().indexWhere((downloadItem) {
                      return (downloadItem.id ==
                              videoDetailsProvider
                                  .contentDetailModel.result?[0].id &&
                          downloadItem.videoType ==
                              videoDetailsProvider
                                  .contentDetailModel.result?[0].videoType &&
                          downloadItem.subVideoType ==
                              videoDetailsProvider
                                  .contentDetailModel.result?[0].subVideoType);
                    })) !=
                    -1) {
              List<DownloadItem> myDownloadList =
                  downloadBox.values.where((downloadItem) {
                return (downloadItem.id ==
                        videoDetailsProvider.contentDetailModel.result?[0].id &&
                    downloadItem.videoType ==
                        videoDetailsProvider
                            .contentDetailModel.result?[0].videoType &&
                    downloadItem.subVideoType ==
                        videoDetailsProvider
                            .contentDetailModel.result?[0].subVideoType);
              }).toList();
              printLog(
                  "_buildDownloadBtn myDownloadList ====> ${myDownloadList.length}");
              if (myDownloadList.isNotEmpty) {
                isInDownload = (myDownloadList[0].isDownload == 1);
                printLog(
                    "_buildDownloadBtn isInDownload ======> $isInDownload");
              }
            }
          }
          return Container(
            alignment: Alignment.center,
            constraints: BoxConstraints(
                minWidth: (Dimens.featureSize + 25 /* Margin */)),
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              focusColor: gray.withValues(alpha: 0.5),
              onTap: () async {
                if (Constant.userID != null) {
                  if (!isInDownload) {
                    if ((downloadProvider.dProgress == 0 ||
                            downloadProvider.dProgress == -1 ||
                            downloadProvider.encryptProgress == 0.0) &&
                        !downloadProvider.loading &&
                        (downloadProvider.itemId == null ||
                            downloadProvider.itemId == 0)) {
                      _checkAndDownload();
                    } else {
                      Utils.showSnackbar(context, "info", "please_wait", true);
                    }
                  } else {
                    buildDownloadCompleteDialog();
                  }
                } else {
                  await Utils.openLogin(context: context, newPage: "");
                  _getData(forceRefresh: true);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (downloadProvider.dProgress != 0 &&
                        downloadProvider.dProgress > 0 &&
                        downloadProvider.dProgress < 100 &&
                        !isInDownload &&
                        downloadProvider.itemId ==
                            videoDetailsProvider
                                .contentDetailModel.result?[0].id)
                      Container(
                        alignment: Alignment.center,
                        child: CircularPercentIndicator(
                          radius: (Dimens.featureIconSize / 2),
                          lineWidth: 2.0,
                          percent:
                              (downloadProvider.dProgress / 100).toDouble(),
                          progressColor: complimentryColor,
                        ),
                      )
                    else if (downloadProvider.encryptProgress > 0 &&
                        downloadProvider.encryptProgress < 1.0 &&
                        downloadProvider.itemId ==
                            videoDetailsProvider
                                .contentDetailModel.result?[0].id)
                      Container(
                        width: Dimens.featureIconSize,
                        height: Dimens.featureIconSize,
                        alignment: Alignment.center,
                        child: CircularPercentIndicator(
                          radius: (Dimens.featureIconSize / 2),
                          lineWidth: 2.0,
                          percent: downloadProvider.encryptProgress,
                          progressColor: complimentryColor,
                        ),
                      )
                    else
                      Container(
                        alignment: Alignment.center,
                        child: MyImage(
                          width: Dimens.featureIconSize,
                          height: Dimens.featureIconSize,
                          color: white,
                          imagePath: isInDownload
                              ? "ic_download_done.png"
                              : "ic_download.png",
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (downloadProvider.dProgress != 0 &&
                        downloadProvider.dProgress > 0 &&
                        downloadProvider.dProgress < 100 &&
                        !isInDownload)
                      MyText(
                        color: descTextColor,
                        text: "${downloadProvider.dProgress}%",
                        multilanguage: false,
                        fontsizeNormal: 10,
                        fontweight: FontWeight.w600,
                        fontsizeWeb: 14,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        textalign: TextAlign.center,
                        fontstyle: FontStyle.normal,
                      )
                    else if (downloadProvider.encryptProgress > 0 &&
                        downloadProvider.encryptProgress < 1.0 &&
                        downloadProvider.itemId ==
                            videoDetailsProvider
                                .contentDetailModel.result?[0].id)
                      MyText(
                        color: descTextColor,
                        text:
                            "${Locales.string(context, "saved")} ${(downloadProvider.encryptProgress * 100).toStringAsFixed(2)}%",
                        multilanguage: false,
                        fontsizeNormal: 10,
                        fontweight: FontWeight.w600,
                        fontsizeWeb: 14,
                        maxline: 1,
                        overflow: TextOverflow.ellipsis,
                        textalign: TextAlign.center,
                        fontstyle: FontStyle.normal,
                      )
                    else
                      MyText(
                        color: descTextColor,
                        text: isInDownload ? "complete" : "download",
                        multilanguage: true,
                        fontsizeNormal: 10,
                        fontweight: FontWeight.w600,
                        fontsizeWeb: 14,
                        maxline: 2,
                        overflow: TextOverflow.ellipsis,
                        textalign: TextAlign.center,
                        fontstyle: FontStyle.normal,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Future<void> _checkAndDownload() async {
    if (!connectivityProvider.isOnline) {
      Utils.showSnackbar(context, "fail", "no_internet", true);
      return;
    }
    if ((videoDetailsProvider.contentDetailModel.result?[0].video320 ?? "")
        .isNotEmpty) {
      try {
        prepareVideoDownload(
            context, videoDetailsProvider.contentDetailModel.result?[0]);
      } catch (e) {
        printLog("Downloading... Exception ======> $e");
      }
    } else {
      if (!mounted) return;
      Utils.showSnackbar(context, "fail", "invalid_url", true);
    }
  }

  void buildDownloadCompleteDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: lightBlack,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(23),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  MyText(
                    text: "download_options",
                    multilanguage: true,
                    fontsizeNormal: 16,
                    color: titleTextColor,
                    fontstyle: FontStyle.normal,
                    fontweight: FontWeight.w700,
                    maxline: 2,
                    overflow: TextOverflow.ellipsis,
                    textalign: TextAlign.start,
                  ),
                  const SizedBox(height: 5),
                  MyText(
                    text: "download_options_note",
                    multilanguage: true,
                    fontsizeNormal: 10,
                    color: descTextColor,
                    fontstyle: FontStyle.normal,
                    fontweight: FontWeight.w500,
                    maxline: 5,
                    overflow: TextOverflow.ellipsis,
                    textalign: TextAlign.start,
                  ),
                  const SizedBox(height: 12),

                  /* To Download */
                  InkWell(
                    borderRadius: BorderRadius.circular(5),
                    focusColor: white,
                    onTap: () async {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      if (Constant.userID != null) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const MyDownloads(viewFrom: ''),
                          ),
                        );
                        setState(() {});
                      } else {
                        await Utils.openLogin(context: context, newPage: "");
                        _getData(forceRefresh: true);
                      }
                    },
                    child: Container(
                      height: Dimens.minHtDialogContent,
                      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          MyImage(
                            width: Dimens.dialogIconSize,
                            height: Dimens.dialogIconSize,
                            imagePath: "ic_setting.png",
                            fit: BoxFit.fill,
                            color: defaultIconColor,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: MyText(
                              text: "take_me_to_the_downloads_page",
                              multilanguage: true,
                              fontsizeNormal: 14,
                              color: titleTextColor,
                              fontstyle: FontStyle.normal,
                              fontweight: FontWeight.w600,
                              maxline: 1,
                              overflow: TextOverflow.ellipsis,
                              textalign: TextAlign.start,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /* Delete */
                  InkWell(
                    borderRadius: BorderRadius.circular(5),
                    focusColor: white,
                    onTap: () async {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      await videoDetailsProvider.addRemoveDownload(
                          context,
                          videoDetailsProvider.contentDetailModel.result?[0].id,
                          videoDetailsProvider
                              .contentDetailModel.result?[0].videoType,
                          videoDetailsProvider
                              .contentDetailModel.result?[0].subVideoType);
                    },
                    child: Container(
                      height: Dimens.minHtDialogContent,
                      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          MyImage(
                            width: Dimens.dialogIconSize,
                            height: Dimens.dialogIconSize,
                            imagePath: "ic_delete.png",
                            fit: BoxFit.fill,
                            color: defaultIconColor,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: MyText(
                              text: "delete_download",
                              multilanguage: true,
                              fontsizeNormal: 14,
                              color: titleTextColor,
                              fontstyle: FontStyle.normal,
                              fontweight: FontWeight.w600,
                              maxline: 1,
                              overflow: TextOverflow.ellipsis,
                              textalign: TextAlign.start,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  /* ========= Download ========= */

  /* ========= Dialogs ========= */
  void buildMoreDialog(dynamic stopTime) {
    showModalBottomSheet(
      context: context,
      backgroundColor: lightBlack,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  /* Share */
                  InkWell(
                    borderRadius: BorderRadius.circular(5),
                    focusColor: white,
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      ShareModel shareModel = ShareModel(
                        newPage: RoutesConstant.contentDetailsPage,
                        videoTitle: videoDetailsProvider
                                .contentDetailModel.result?[0].name ??
                            "",
                        videoId: videoDetailsProvider
                                .contentDetailModel.result?[0].id ??
                            0,
                        videoType: videoDetailsProvider
                                .contentDetailModel.result?[0].videoType ??
                            0,
                        subVideoType: videoDetailsProvider
                                .contentDetailModel.result?[0].subVideoType ??
                            0,
                        typeId: videoDetailsProvider
                                .contentDetailModel.result?[0].typeId ??
                            0,
                      );
                      Utils.openShareDialog(
                        context: context,
                        shareModel: shareModel,
                      );
                    },
                    child: _buildDialogItems(
                      icon: "ic_share.png",
                      title: "share",
                      isMultilang: true,
                    ),
                  ),

                  /* Trailer */
                  stopTime > 0
                      ? InkWell(
                          borderRadius: BorderRadius.circular(5),
                          focusColor: white,
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                            openPlayer("Trailer");
                          },
                          child: _buildDialogItems(
                            icon: "ic_borderplay.png",
                            title: "trailer",
                            isMultilang: true,
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogItems({
    required String icon,
    required String title,
    required bool isMultilang,
  }) {
    return Container(
      height: Dimens.minHtDialogContent,
      padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          MyImage(
            width: Dimens.dialogIconSize,
            height: Dimens.dialogIconSize,
            imagePath: icon,
            fit: BoxFit.contain,
            color: defaultIconColor,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: MyText(
              text: title,
              multilanguage: isMultilang,
              fontsizeNormal: 14,
              fontsizeWeb: 16,
              color: titleTextColor,
              fontstyle: FontStyle.normal,
              fontweight: FontWeight.w600,
              maxline: 1,
              overflow: TextOverflow.ellipsis,
              textalign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }
  /* ========= Dialogs ========= */

  /* ========= Open Player ========= */
  Future<void> openPlayer(String playType) async {
    /* CHECK SUBSCRIPTION */
    if (playType != "Trailer") {
      bool? isPrimiumUser = await Utils.checkSubsRentLogin(
        context: context,
        isPremium:
            videoDetailsProvider.contentDetailModel.result?[0].isPremium ?? 0,
        isBuy: videoDetailsProvider.contentDetailModel.result?[0].isBuy ?? 0,
        isRent: videoDetailsProvider.contentDetailModel.result?[0].isRent ?? 0,
        rentBuy:
            videoDetailsProvider.contentDetailModel.result?[0].rentBuy ?? 0,
        producerId:
            (videoDetailsProvider.contentDetailModel.result?[0].producerId ?? 0)
                .toString(),
        videoId: (videoDetailsProvider.contentDetailModel.result?[0].id ?? 0)
            .toString(),
        rentPrice:
            (videoDetailsProvider.contentDetailModel.result?[0].price ?? 0)
                .toString(),
        vTitle: (videoDetailsProvider.contentDetailModel.result?[0].name ?? 0)
            .toString(),
        typeId: (videoDetailsProvider.contentDetailModel.result?[0].typeId ?? 0)
            .toString(),
        vType:
            (videoDetailsProvider.contentDetailModel.result?[0].videoType ?? 0)
                .toString(),
        subVideoType:
            (videoDetailsProvider.contentDetailModel.result?[0].subVideoType ??
                    0)
                .toString(),
        rentProductId: (kIsWeb)
            ? (videoDetailsProvider.contentDetailModel.result?[0].webPriceId
                    .toString() ??
                '')
            : (Platform.isIOS
                ? (videoDetailsProvider
                        .contentDetailModel.result?[0].iosProductPackage
                        .toString() ??
                    '')
                : (videoDetailsProvider
                        .contentDetailModel.result?[0].androidProductPackage
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
    printLog(
        "ID :===> ${(videoDetailsProvider.contentDetailModel.result?[0].id ?? 0)}");

    int? stopTime;
    if (playType == "startOver" || playType == "Trailer") {
      stopTime = 0;
    } else {
      stopTime =
          (videoDetailsProvider.contentDetailModel.result?[0].stopTime ?? 0);
    }

    String? vUrl, vUploadType;
    if (playType == "Trailer") {
      Utils.clearQualitySubtitle();
      vUploadType =
          (videoDetailsProvider.contentDetailModel.result?[0].trailerType ??
              "");
      vUrl =
          (videoDetailsProvider.contentDetailModel.result?[0].trailerUrl ?? "");
    } else {
      /* Set-up Quality URLs */
      Utils.setQualityURLs(
        video320:
            (videoDetailsProvider.contentDetailModel.result?[0].video320 ?? ""),
        video480:
            (videoDetailsProvider.contentDetailModel.result?[0].video480 ?? ""),
        video720:
            (videoDetailsProvider.contentDetailModel.result?[0].video720 ?? ""),
        video1080:
            (videoDetailsProvider.contentDetailModel.result?[0].video1080 ??
                ""),
      );

      vUrl =
          (videoDetailsProvider.contentDetailModel.result?[0].video320 ?? "");
      vUploadType =
          (videoDetailsProvider.contentDetailModel.result?[0].videoUploadType ??
              "");
    }

    printLog("vUploadType ===> $vUploadType");
    printLog("stopTime ===> $stopTime");

    if (!mounted) return;
    if (vUrl.isEmpty || vUrl == "") {
      if (playType == "Trailer") {
        Utils.showSnackbar(context, "info", "trailer_not_found", true);
      } else {
        Utils.showSnackbar(context, "info", "video_not_found", true);
      }
      return;
    }

    /* VdoCipher OTP */
    VdoCipherModel? vdocipherDetails;
    if (vUploadType == Constant.vdocipherPlayType && playType != "Trailer") {
      if (!mounted) return;
      vdocipherDetails = await Utils.getVdoCipherOTP(
          context: context,
          videoId:
              (videoDetailsProvider.contentDetailModel.result?[0].video320 ??
                  ""));
      printLog(
          "openPlayer vdocipherDetails ======> ${vdocipherDetails?.result?.otp}");
    }
    /* VdoCipher OTP */

    PlayerModel playerModel = PlayerModel(
      playType: (playType == "Trailer") ? "Trailer" : "Video",
      isLive: (vUploadType == "live_stream_url" && playType != "Trailer")
          ? true
          : false,
      videoId: videoDetailsProvider.contentDetailModel.result?[0].id ?? 0,
      videoTitle: videoDetailsProvider.contentDetailModel.result?[0].name ?? "",
      videoType:
          videoDetailsProvider.contentDetailModel.result?[0].videoType ?? 0,
      subVideoType:
          videoDetailsProvider.contentDetailModel.result?[0].subVideoType ?? 0,
      typeId: videoDetailsProvider.contentDetailModel.result?[0].typeId ?? 0,
      episodeId: 0,
      videoUrl: vUrl,
      cipherMediaDetails:
          (vdocipherDetails != null && vdocipherDetails.result != null)
              ? (vdocipherDetails.result)
              : null,
      trailerUrl:
          videoDetailsProvider.contentDetailModel.result?[0].trailerUrl ?? "",
      uploadType: vUploadType,
      videoThumb:
          videoDetailsProvider.contentDetailModel.result?[0].landscape ?? "",
      stopTime: stopTime,
      isPremium:
          videoDetailsProvider.contentDetailModel.result?[0].isPremium ?? 0,
      isBuy: videoDetailsProvider.contentDetailModel.result?[0].isBuy ?? 0,
      isRent: videoDetailsProvider.contentDetailModel.result?[0].isRent ?? 0,
      rentBuy: videoDetailsProvider.contentDetailModel.result?[0].rentBuy ?? 0,
      securityKey: "",
      securityIVKey: null,
      currentEpiPos: 0,
      episodeList: null,
    );

    if (!mounted) return;
    AdHelper.showFullscreenAd(context, Constant.rewardAdType, () async {
      dynamic isContinue;
      isContinue =
          await Utils.openPlayer(context: context, playerModel: playerModel);
      printLog("isContinue ===> $isContinue");
      if (isContinue != null && isContinue == true) {
        _getData(forceRefresh: true);
      }
    });
  }
  /* ========= Open Player ========= */
}
