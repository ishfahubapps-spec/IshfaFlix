import 'dart:io';

import 'package:flutter_locales/flutter_locales.dart';

import '../main.dart';
import '../model/playermodel.dart';
import '../model/sharemodel.dart';
import '../players/model/vdociphermodel.dart';
import '../provider/homeprovider.dart';
import '../provider/videobyidprovider.dart';
import '../routes/routes_constant.dart';
import '../shimmer/shimmerutils.dart';
import '../webpages/webcomman.dart';
import '../webwidget/interactive_icon.dart';
import '../widget/castcrew.dart';
import '../widget/myusernetworkimg.dart';
import '../widget/relatedvideoshow.dart';
import 'package:flutter/foundation.dart';

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
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class WebContentVideoDetails extends StatefulWidget {
  final String? newPage, oldPage;
  final dynamic reqText;
  final int videoId, subVideoType, videoType, typeId;
  const WebContentVideoDetails(
    this.videoId,
    this.subVideoType,
    this.videoType,
    this.typeId, {
    super.key,
    required this.newPage,
    required this.oldPage,
    required this.reqText,
  });

  @override
  State<WebContentVideoDetails> createState() => WebContentVideoDetailsState();
}

class WebContentVideoDetailsState extends State<WebContentVideoDetails>
    with RouteAware {
  /* Trailer init */
  VideoPlayerController? _trailerNormalController;
  YoutubePlayerController? _trailerYoutubeController;

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
    printLog("initState videoId ====> ${widget.videoId}");
    printLog("initState videoType ==> ${widget.videoType}");
    printLog("initState typeId =====> ${widget.typeId}");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData(forceRefresh: false);
    });
  }

  Future<void> _getData({bool forceRefresh = false}) async {
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
            enableKeyboard: false,
            enableCaption: false,
            enableJavaScript: true,
            mute: false,
            origin: '',
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
            if (!context.mounted) return;
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
        newPage: widget.newPage ?? "",
        oldPage: widget.oldPage ?? "",
        reqText: widget.reqText ?? "",
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
      playType: playType == "Trailer" ? "Trailer" : "Video",
      isLive: ((videoDetailsProvider
                          .contentDetailModel.result?[0].videoUploadType ??
                      "") ==
                  "live_stream_url" &&
              playType != "Trailer")
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
      videoUrl:
          videoDetailsProvider.contentDetailModel.result?[0].video320 ?? "",
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
    dynamic isContinue;
    isContinue =
        await Utils.openPlayer(context: context, playerModel: playerModel);
    printLog("isContinue ===> $isContinue");
    if (isContinue != null && isContinue == true) {
      _getData(forceRefresh: true);
    }
  }
  /* ========= Open Player ========= */

  @override
  void dispose() {
    super.dispose();
    routeObserver.unsubscribe(this);
    if (_trailerYoutubeController != null) {
      _trailerYoutubeController?.close();
      _trailerYoutubeController = null;
    }
    if (_trailerNormalController != null) {
      _trailerNormalController?.dispose();
      _trailerNormalController = null;
    }
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
    return WebComman(
      newChild: _buildPageUI(),
      newPage: widget.newPage,
      oldPage: widget.oldPage,
      reqText: widget.reqText,
    );
  }

  Widget _buildPageUI() {
    if (videoDetailsProvider.isLoading) {
      return SingleChildScrollView(
        child: Dimens.isBigScreen(context)
            ? ShimmerUtils.buildDetailWebShimmer(context, "video")
            : ShimmerUtils.buildDetailMobileShimmer(context, "video"),
      );
    } else {
      if (videoDetailsProvider.contentDetailModel.status == 200 &&
          videoDetailsProvider.contentDetailModel.result != null) {
        if (Dimens.isBigScreen(context)) {
          return _buildTVWebData();
        } else {
          return _buildMobileData();
        }
      } else {
        return const NoData(title: '', subTitle: '');
      }
    }
  }

  Widget _buildTVWebData() {
    return Column(
      children: [
        SizedBox(
          height: Dimens.getResponsiveHeight(context, 0),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              /* Poster */
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: Dimens.getResponsiveHeight(context, 0),
                child: ((videoDetailsProvider
                                .contentDetailModel.result?[0].trailerUrl ??
                            "")
                        .isNotEmpty)
                    ? setUpTrailerView()
                    : MyNetworkImage(
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
              /* Main title, ReleaseYear, Duration, Age Restriction, Video Quality */
              Positioned(
                left: 35,
                bottom: 35,
                child: Container(
                  padding: EdgeInsets.fromLTRB(0, Dimens.homeTabHeight, 35, 0),
                  width: (MediaQuery.of(context).size.width < 1000)
                      ? (MediaQuery.of(context).size.width * 0.5)
                      : (MediaQuery.of(context).size.width),
                  constraints: const BoxConstraints(minHeight: 0),
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MyText(
                        color: titleTextColor,
                        text: videoDetailsProvider
                                .contentDetailModel.result?[0].name ??
                            "",
                        textalign: TextAlign.start,
                        fontsizeNormal: 33,
                        fontsizeWeb: 33,
                        fontweight: FontWeight.w800,
                        maxline: 2,
                        multilanguage: false,
                        overflow: TextOverflow.ellipsis,
                        fontstyle: FontStyle.normal,
                        // withShaderMask: true,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          /* Release Year */
                          (videoDetailsProvider.contentDetailModel.result?[0]
                                          .releaseDate !=
                                      null &&
                                  videoDetailsProvider.contentDetailModel
                                          .result?[0].releaseDate !=
                                      "")
                              ? Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  child: MyText(
                                    color: descTextColor,
                                    text: DateFormat("yyyy").format(
                                        DateTime.parse(videoDetailsProvider
                                                .contentDetailModel
                                                .result?[0]
                                                .releaseDate ??
                                            "")),
                                    textalign: TextAlign.start,
                                    fontsizeNormal: 13,
                                    fontsizeWeb: 15,
                                    fontweight: FontWeight.w600,
                                    multilanguage: false,
                                    maxline: 1,
                                    overflow: TextOverflow.ellipsis,
                                    fontstyle: FontStyle.normal,
                                  ),
                                )
                              : const SizedBox.shrink(),

                          /* Duration */
                          (videoDetailsProvider.contentDetailModel.result?[0]
                                      .videoDuration !=
                                  null)
                              ? Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  child: MyText(
                                    color: descTextColor,
                                    multilanguage: false,
                                    text: ((videoDetailsProvider
                                                    .contentDetailModel
                                                    .result?[0]
                                                    .videoDuration ??
                                                0) >
                                            0)
                                        ? "${Constant.dotText}  ${Utils.convertTimeToText(videoDetailsProvider.contentDetailModel.result?[0].videoDuration ?? 0)}"
                                        : "",
                                    textalign: TextAlign.start,
                                    fontsizeNormal: 13,
                                    fontsizeWeb: 15,
                                    fontweight: FontWeight.w500,
                                    maxline: 1,
                                    overflow: TextOverflow.ellipsis,
                                    fontstyle: FontStyle.normal,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ],
                      ),

                      /* Release Date */
                      _buildReleaseDate(),

                      /* Prime TAG */
                      (videoDetailsProvider.contentDetailModel.result?[0]
                                      .isPremium ??
                                  0) ==
                              1
                          ? Container(
                              margin: const EdgeInsets.only(top: 10),
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
                                    fontsizeNormal: 13,
                                    fontsizeWeb: 15,
                                    fontweight: FontWeight.w600,
                                    multilanguage: true,
                                    maxline: 1,
                                    overflow: TextOverflow.ellipsis,
                                    fontstyle: FontStyle.normal,
                                  ),
                                  const SizedBox(height: 2),
                                  MyText(
                                    color: titleTextColor,
                                    text: "primetagdesc",
                                    multilanguage: true,
                                    textalign: TextAlign.center,
                                    fontsizeNormal: 13,
                                    fontsizeWeb: 15,
                                    fontweight: FontWeight.w500,
                                    maxline: 1,
                                    overflow: TextOverflow.ellipsis,
                                    fontstyle: FontStyle.normal,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),

                      /* Rent TAG */
                      if (widget.videoType != Constant.upcomingContentType)
                        _buildRentExpiryTAG(),

                      /* Category */
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 5),
                        child: MyText(
                          color: descTextColor,
                          text: Utils.convertHalfStopToVLine(
                              videoDetailsProvider.contentDetailModel.result?[0]
                                      .categoryName ??
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
                      /* Language */
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(top: 5, bottom: 15),
                        child: MyText(
                          color: descTextColor,
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

                      /* Description */
                      Container(
                        width: MediaQuery.of(context).size.width,
                        constraints: const BoxConstraints(minHeight: 0),
                        margin: const EdgeInsets.only(bottom: 8, right: 35),
                        alignment: Alignment.centerLeft,
                        child: ExpandableText(
                          videoDetailsProvider
                                  .contentDetailModel.result?[0].description ??
                              "",
                          expandText: "",
                          collapseText: "",
                          maxLines: (MediaQuery.of(context).size.width < 1000)
                              ? 2
                              : 3,
                          linkColor: descTextColor,
                          expandOnTextTap: true,
                          collapseOnTextTap: true,
                          style: kIsWeb
                              ? TextStyle(
                                  fontSize:
                                      Dimens.isBigScreen(context) ? 15 : 14,
                                  fontStyle: FontStyle.normal,
                                  color: descTextColor,
                                  fontWeight: FontWeight.normal,
                                )
                              : GoogleFonts.inter(
                                  textStyle: TextStyle(
                                    fontSize:
                                        Dimens.isBigScreen(context) ? 15 : 14,
                                    fontStyle: FontStyle.normal,
                                    color: descTextColor,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        /* WatchNow & Feature buttons */
        _buildFeatureBtns(),

        /* Other Details */
        /* Related ~ More Details */
        Container(
          margin: Dimens.isBigScreen(context)
              ? const EdgeInsets.fromLTRB(0, 10, 0, 0)
              : const EdgeInsets.all(0),
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
                    newPage: widget.newPage,
                    oldPage: widget.oldPage,
                    reqText: widget.reqText,
                    videoId: widget.videoId,
                    subVideoType: widget.subVideoType,
                    videoType: widget.videoType,
                    typeId: widget.typeId,
                  ),
                  /* Cast & Crew */
                  CastCrew(
                    castList:
                        videoDetailsProvider.contentDetailModel.result?[0].cast,
                    newPage: widget.newPage,
                  ),
                  /* Director */
                  _buildDirector(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileData() {
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.fromLTRB(0, Dimens.homeTabHeight + 5, 0, 10),
      child: Column(
        children: [
          /* Poster */
          ((videoDetailsProvider.contentDetailModel.result?[0].trailerUrl ?? "")
                  .isNotEmpty)
              ? setUpTrailerView()
              : _buildMobilePoster(),

          /* Other Details */
          const SizedBox(height: 15),
          MyText(
            color: white,
            text: videoDetailsProvider.contentDetailModel.result?[0].name ?? "",
            textalign: TextAlign.center,
            fontsizeNormal: 25,
            fontsizeWeb: 25,
            fontweight: FontWeight.w700,
            multilanguage: false,
            maxline: 5,
            overflow: TextOverflow.ellipsis,
            fontstyle: FontStyle.normal,
            // withShaderMask: true,
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
                        color: titleTextColor,
                        text: DateFormat('yyyy').format(DateTime.parse(
                            videoDetailsProvider.contentDetailModel.result?[0]
                                    .releaseDate ??
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
          if ((videoDetailsProvider.contentDetailModel.result?[0].isPremium ??
                  0) ==
              1)
            Container(
              margin: EdgeInsets.only(
                bottom: ((videoDetailsProvider
                                .contentDetailModel.result?[0].isRent ??
                            0) ==
                        1)
                    ? 0
                    : 20,
              ),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                    color: white,
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
            _buildRentExpiryTAG(),
          /* ************** Rent & Premium TAGs ************** */

          /* Category */
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
            child: MyText(
              color: white,
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
          /* Language */
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
            child: MyText(
              color: white,
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
          /* Description */
          const SizedBox(height: 7),
          Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            constraints: const BoxConstraints(minHeight: 0),
            child: ExpandableText(
              videoDetailsProvider.contentDetailModel.result?[0].description ??
                  "",
              expandText: Locales.string(context, "more"),
              collapseText: Locales.string(context, "less"),
              maxLines: Dimens.isBigScreen(context) ? 50 : 3,
              linkColor: descTextColor,
              expandOnTextTap: true,
              collapseOnTextTap: true,
              style: kIsWeb
                  ? const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.normal,
                      color: descTextColor,
                      fontWeight: FontWeight.w500,
                    )
                  : GoogleFonts.inter(
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
                      newPage: widget.newPage,
                      oldPage: widget.oldPage,
                      reqText: widget.reqText,
                      videoId: widget.videoId,
                      subVideoType: widget.subVideoType,
                      videoType: widget.videoType,
                      typeId: widget.typeId,
                    ),
                    /* Cast & Crew */
                    CastCrew(
                      castList: videoDetailsProvider
                          .contentDetailModel.result?[0].cast,
                      newPage: widget.newPage,
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
    );
  }

  Widget _buildMobilePoster() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
      child: Stack(
        alignment: Alignment.topCenter,
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
                            .contentDetailModel.result?[0].landscape
                            .toString() !=
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
          Positioned(
            top: 8,
            right: 8,
            child: Utils.buildCloseBtn(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBtns() {
    if (Dimens.isBigScreen(context)) {
      return Container(
        alignment: Alignment.centerLeft,
        constraints: const BoxConstraints(minHeight: 0, minWidth: 0),
        margin: const EdgeInsets.fromLTRB(35, 0, 0, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              /* WatchNow & ContinueWatching */
              (widget.videoType == Constant.upcomingContentType)
                  ? _buildWatchTrailer()
                  : _buildWatchNow(),
              if (widget.videoType != Constant.upcomingContentType)
                const SizedBox(width: 10),

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
                      if (Constant.userID != null) {
                        await videoDetailsProvider.setBookMark(
                          context,
                          widget.videoType,
                          widget.subVideoType,
                          widget.videoId,
                        );
                      } else {
                        await Utils.openLogin(
                            context: context, newPage: widget.newPage ?? "");
                      }
                    },
                  );
                },
              ),

              /* Share */
              _buildFeatureBtnItem(
                icon: 'ic_share.png',
                title: 'share',
                multilanguage: true,
                isRent: false,
                onClick: () async {
                  ShareModel shareModel = ShareModel(
                    newPage: RoutesConstant.contentDetailsPage,
                    videoTitle: videoDetailsProvider
                            .contentDetailModel.result?[0].name ??
                        "",
                    videoId:
                        videoDetailsProvider.contentDetailModel.result?[0].id ??
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
              ),
            ],
          ),
        ),
      );
    }
    if (widget.videoType != Constant.upcomingContentType) {
      return Container(
        margin: const EdgeInsets.only(top: 25, bottom: 0),
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
                      if (Constant.userID != null) {
                        await videoDetailsProvider.setBookMark(
                          context,
                          widget.videoType,
                          widget.subVideoType,
                          widget.videoId,
                        );
                      } else {
                        await Utils.openLogin(
                            context: context, newPage: widget.newPage ?? "");
                      }
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
                      if (Utils.checkLoginUser(context)) {
                        await videoDetailsProvider.setLikeDislike(
                          context,
                          subVideoType: widget.subVideoType,
                          videoType: widget.videoType,
                          videoId: widget.videoId,
                        );
                      }
                    },
                  );
                },
              ),

              /* Share */
              _buildFeatureBtnItem(
                icon: 'ic_share.png',
                title: 'share',
                multilanguage: true,
                isRent: false,
                onClick: () async {
                  ShareModel shareModel = ShareModel(
                    newPage: RoutesConstant.contentDetailsPage,
                    videoTitle: videoDetailsProvider
                            .contentDetailModel.result?[0].name ??
                        "",
                    videoId:
                        videoDetailsProvider.contentDetailModel.result?[0].id ??
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
    return InteractiveIcon(builder: (isHovered) {
      return Container(
        alignment: Alignment.center,
        child: InkWell(
          onTap: onClick,
          borderRadius: BorderRadius.circular(5),
          focusColor: gray.withValues(alpha: 0.5),
          child: Container(
            padding: const EdgeInsets.all(5.0),
            constraints: BoxConstraints(
                minWidth: (Dimens.featureSize + 25 /* Margin */)),
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
                  fontweight: FontWeight.w500,
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
    });
  }

  Widget _buildReleaseDate() {
    if (widget.videoType == Constant.upcomingContentType) {
      if (videoDetailsProvider.contentDetailModel.result?[0].releaseDate !=
              null &&
          (videoDetailsProvider.contentDetailModel.result?[0].releaseDate ??
                  "") !=
              "") {
        return Container(
          margin: EdgeInsets.fromLTRB(
              Dimens.isBigScreen(context) ? 0 : 20, 20, 20, 0),
          width: MediaQuery.of(context).size.width,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              MyText(
                color: white,
                text: "release_date",
                multilanguage: true,
                textalign: TextAlign.start,
                fontsizeNormal: 14,
                fontsizeWeb: 15,
                fontweight: FontWeight.w500,
                maxline: 1,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
              ),
              const SizedBox(width: 5),
              MyText(
                color: white,
                text: ":",
                multilanguage: false,
                textalign: TextAlign.start,
                fontsizeNormal: 14,
                fontsizeWeb: 15,
                fontweight: FontWeight.w500,
                maxline: 1,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: MyText(
                  color: complimentryColor,
                  text: DateFormat("dd MMM, yyyy").format(DateTime.parse(
                      videoDetailsProvider
                              .contentDetailModel.result?[0].releaseDate ??
                          "")),
                  multilanguage: false,
                  textalign: TextAlign.start,
                  fontsizeNormal: 14,
                  fontsizeWeb: 15,
                  fontweight: FontWeight.w700,
                  maxline: 2,
                  overflow: TextOverflow.ellipsis,
                  fontstyle: FontStyle.normal,
                ),
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
          padding: Dimens.isBigScreen(context)
              ? const EdgeInsets.fromLTRB(0, 0, 0, 0)
              : const EdgeInsets.fromLTRB(12, 5, 12, 0),
          child: ClipRRect(
            borderRadius: Dimens.isBigScreen(context)
                ? BorderRadius.circular(0)
                : BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(0),
                  width: MediaQuery.of(context).size.width,
                  height: Dimens.getResponsiveHeight(context, 0),
                  child: YoutubePlayer(
                    controller: _trailerYoutubeController!,
                    enableFullScreenOnVerticalDrag: false,
                  ),
                ),
                Positioned.fill(
                  child: PointerInterceptor(
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.all(0),
                      width: MediaQuery.of(context).size.width,
                      height: Dimens.getResponsiveHeight(context, 0),
                    ),
                  ),
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
          padding: Dimens.isBigScreen(context)
              ? const EdgeInsets.fromLTRB(0, 0, 0, 0)
              : const EdgeInsets.fromLTRB(12, 5, 12, 0),
          child: ClipRRect(
            borderRadius: Dimens.isBigScreen(context)
                ? BorderRadius.circular(0)
                : BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(0),
              width: MediaQuery.of(context).size.width,
              height: Dimens.getResponsiveHeight(context, 0),
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
          ),
        ),
      );
    }
  }
  /* ***************** Trailer View END */
  /* ********************************** */

  Widget _buildWatchTrailer() {
    return InteractiveIcon(builder: (isHovered) {
      return Container(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () {
            openPlayer("Trailer");
          },
          focusColor: descTextColor,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 50,
            constraints: BoxConstraints(
              maxWidth: Dimens.isBigScreen(context)
                  ? (MediaQuery.of(context).size.width * 0.25)
                  : MediaQuery.of(context).size.width,
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
                    color: colorPrimaryDark,
                  ),
                  const SizedBox(width: 15),
                  Flexible(
                    child: MyText(
                      color: colorPrimaryDark,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildWatchNow() {
    return InteractiveIcon(builder: (isHovered) {
      return Container(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () {
            openPlayer("Video");
          },
          focusColor: descTextColor,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 50,
            constraints: BoxConstraints(
              maxWidth: Dimens.isBigScreen(context)
                  ? (MediaQuery.of(context).size.width * 0.25)
                  : MediaQuery.of(context).size.width,
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
                            color: colorPrimaryDark,
                          ),
                          const SizedBox(width: 15),
                          Flexible(
                            child: MyText(
                              color: colorPrimaryDark,
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
                        progressColor: colorAccent,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
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
                    : 20,
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
                  : 20,
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
              "Rent at just\n${Constant.currencySymbol}${videoDetailsProvider.contentDetailModel.result?[0].price ?? 0}",
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
                rentProductId: videoDetailsProvider
                        .contentDetailModel.result?[0].webPriceId
                        .toString() ??
                    '',
                newPage: widget.newPage ?? "",
                oldPage: widget.oldPage ?? "",
                reqText: widget.reqText ?? "",
              );
              if (isRented != null && isRented == true) {
                _getData(forceRefresh: true);
              }
            } else {
              await Utils.openLogin(
                  context: context, newPage: widget.newPage ?? "");
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
              width: (kIsWeb && MediaQuery.of(context).size.width > 1000)
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
                      context.go(
                        "/${RoutesConstant.videoByCastPage}/${(directorList?[0].id ?? 0)}",
                        extra: {
                          'newpage': widget.newPage.toString(),
                          'itemid': (directorList?[0].id ?? 0).toString(),
                          'title': directorList?[0].name ?? '',
                          'layouttype': 'ByCast',
                        },
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
                          color: white,
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
}
