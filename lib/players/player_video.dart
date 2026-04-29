import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_locales/flutter_locales.dart';

import '../main.dart';
import '../model/playermodel.dart';
import '../web_js/js_helper.dart';
import '../widget/centerplaybutton.dart';
import 'model/optionitem.dart';
import '../players/orientationmanager.dart';
import 'model/subtitlemodel.dart';
import '../provider/connectivityprovider.dart';
import '../provider/playerprovider.dart';
import '../routes/routes_constant.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../utils/utils.dart';
import '../widget/myimage.dart';
import '../widget/mynetworkimg.dart';
import '../widget/mytext.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_cast_video/flutter_cast_video.dart';
import 'model/subtitlemodel.dart' as mysubtitle;
import 'package:flutter_subtitle/flutter_subtitle.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

import 'model/vdociphermodel.dart';

String duration2String(Duration? dur, {showLive = '🔴 Live'}) {
  Duration duration = dur ?? const Duration();
  if (duration.inSeconds <= 0) {
    return showLive;
  } else {
    return duration.toString().split('.').first.padLeft(8, "0");
  }
}

class PlayerVideo extends StatefulWidget {
  final PlayerModel playerModel;

  const PlayerVideo({
    super.key,
    required this.playerModel,
  });

  @override
  State<PlayerVideo> createState() => _PlayerVideoState();
}

class _PlayerVideoState extends State<PlayerVideo>
    with RouteAware, WidgetsBindingObserver {
  final JSHelper _jsHelper = JSHelper();
  late PlayerProvider playerProvider;
  late ConnectivityProvider connectivityProvider;

  final _pipChannel = MethodChannel('${Constant.appPackageName}/pip');

  late VideoPlayerController _videoPlayerController;
  bool _showControls = true;
  bool _isVideoStarted = false;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  int? playerCPosition, videoTotalDuration;
  Timer? _durationTimer;
  Duration? videoCPosition, videoTDuration;
  int _doubleTapCountForward = 0;
  int _doubleTapCountBackward = 0;
  Timer? _doubleTapTimer;

  SubtitleController? subtitleController;

  /* Volume/Brightness START */
  late final VolumeController? _volumeController;
  /* Volume/Brightness END */

  /* Next Episode Pop-up START */
  bool _showNextEpisodePopup = false;
  int _countdownSeconds = 5;
  Timer? _countdownTimer;
  static const int nextEpisodeThresholdMs = 60000; // 60 seconds
  static const int safeStartDelayMs = 3000;

  bool _hasShownNextEpisodePopup = false;
  int _initialPositionMs = 0;
  double _popupOpacity = 1.0;
  double _countdownProgress = 1.0; // 1.0 = full bar, 0.0 = empty
  /* Next Episode Pop-up END */

  /* Chrome Cast START */
  // ChromeCastController? _chromeCastController;
  // AppState _state = AppState.idle;
  // bool _playingOnCasting = false;
  // Map<dynamic, dynamic> _mediaInfo = {};
  /* Chrome Cast END */

  /* IMA Ads START */
  String? imaAdsFeatureStatus;
  late final AdsLoader _adsLoader;
  AdsManager? _adsManager;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  bool _isAdLoaded = false;
  bool _shouldShowContentVideo = false;
  Timer? _videoProgressTimer;
  ContentProgressProvider? _contentProgressProvider;
  AdDisplayContainer? _adDisplayContainer;

  Future<void> _requestAds(AdDisplayContainer container) {
    return _adsLoader.requestAds(AdsRequest(
      adTagUrl: Constant.imaAdTags,
      contentProgressProvider: null,
    ));
  }

  Future<void> _resumeContent() async {
    if (!_isAdLoaded) {
      if (!mounted) return;
      setState(() {
        _shouldShowContentVideo = true;
      });

      if (!kIsWeb && _adsManager != null) {
        printLog("============== Ads ==============");
        _videoProgressTimer = Timer.periodic(
          const Duration(milliseconds: 200),
          (Timer timer) async {
            final Duration? progress = await _videoPlayerController.position;
            if (progress != null) {
              await _contentProgressProvider?.setProgress(
                progress: progress,
                duration: _videoPlayerController.value.duration,
              );
            }
          },
        );
      }

      await _videoPlayerController.play();
    }
  }

  Future<void> _pauseContent() async {
    if (mounted) {
      setState(() {
        _shouldShowContentVideo = false;
      });
    }
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    await _videoPlayerController.pause();
  }
  /* IMA Ads END */

  /// Send video state to Android for PIP player
  void _updateVideoState({required bool isPlaying}) {
    final cPosition = _videoPlayerController.value.position.inSeconds;
    printLog("_updateVideoState cPosition : $cPosition");
    try {
      _pipChannel.invokeMethod('updateVideoState', {
        "isPlaying": isPlaying,
        "videoUrl": widget.playerModel.videoUrl ?? "",
        "position": cPosition,
      });
    } on PlatformException catch (e) {
      printLog("_updateVideoState Failed : ${e.message}");
    }
  }

  void _updateVideoProgress() {
    final cPosition = _videoPlayerController.value.position.inSeconds;
    try {
      _pipChannel.invokeMethod('videoProgress', {
        "position": cPosition,
      });
    } on PlatformException catch (e) {
      printLog("_updateVideoProgress Failed : ${e.message}");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    printLog('didChangeAppLifecycleState state =====> ${state.name}');
    switch (state) {
      case AppLifecycleState.resumed:
        if (connectivityProvider.isOnline &&
            (widget.playerModel.playType == "Video" ||
                widget.playerModel.playType == "Show") &&
            Constant.userID != null &&
            widget.playerModel.isPremium == 1) {
          playerProvider.addRemoveDevice(1);
        }
        if (!kIsWeb && !_shouldShowContentVideo) {
          _adsManager?.resume();
        }
      case AppLifecycleState.inactive:
        // Pausing the Ad video player on Android can only be done in this state
        // because it corresponds to `Activity.onPause`. This state is also
        // triggered before resume, so this will only pause the Ad if the app is
        // in the process of being sent to the background.
        if (!kIsWeb &&
            !_shouldShowContentVideo &&
            _lastLifecycleState == AppLifecycleState.resumed) {
          _adsManager?.pause();
        }
      case AppLifecycleState.hidden:
      // if (connectivityProvider.isOnline &&
      //         (widget.playerModel.playType == "Video" ||
      //             widget.playerModel.playType == "Show") &&
      //         Constant.userID !=
      //             null /* &&
      //     (widget.playerModel.isPremium == 1) */
      //     ) {
      //   // playerProvider.addRemoveDevice(2);
      //   enterPipMode(widget.playerModel.videoUrl ?? "");
      // }
      case AppLifecycleState.paused:
        if (connectivityProvider.isOnline &&
            (widget.playerModel.playType == "Video" ||
                widget.playerModel.playType == "Show") &&
            Constant.userID != null &&
            widget.playerModel.isPremium == 1) {
          playerProvider.addRemoveDevice(2);
        }
      case AppLifecycleState.detached:
    }
    _lastLifecycleState = state;
  }

  @override
  void didChangeDependencies() {
    printLog("========= didChangeDependencies =========");
    routeObserver.subscribe(this, ModalRoute.of(context)!);
    super.didChangeDependencies();
  }

  @override
  void didPop() {
    printLog("========= didPop =========");
    super.didPop();
  }

  @override
  void didPopNext() {
    printLog("========= didPopNext =========");
    super.didPopNext();
  }

  @override
  void didPush() {
    printLog("========= didPush =========");
    super.didPush();
  }

  @override
  void didPushNext() {
    printLog("========= didPushNext =========");
    super.didPushNext();
  }

  bool _checkPremiumLive() {
    if (kIsWeb) return false;
    if (imaAdsFeatureStatus != null && imaAdsFeatureStatus != "1") false;
    if (widget.playerModel.isLive == true) return true;
    if (widget.playerModel.isBuy == 1 || widget.playerModel.rentBuy == 1) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    printLog("initState videoUrl ======> ${widget.playerModel.videoUrl}");
    printLog("initState uploadType ====> ${widget.playerModel.uploadType}");
    printLog("initState stopTime ======> ${widget.playerModel.stopTime}");
    // Store the starting resume position (stopTime)
    _initialPositionMs = widget.playerModel.stopTime ?? 0;

    playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    _volumeController = kIsWeb ? null : VolumeController.instance;

    _setVideoURL();
    OrientationManager.forceLandscape();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      imaAdsFeatureStatus =
          await Utils.configByStatus(status: Constant.activeTvStatus);
      printLog('_getData imaAdsFeatureStatus =======> $imaAdsFeatureStatus');
      _initIMAAds();
    });
    _startHideTimer();
  }

  Future<void> _initIMAAds() async {
    _contentProgressProvider =
        _checkPremiumLive() ? ContentProgressProvider() : null;
    _adDisplayContainer = _checkPremiumLive()
        ? AdDisplayContainer(
            onContainerAdded: (AdDisplayContainer container) {
              _adsLoader = AdsLoader(
                container: container,
                onAdsLoaded: (OnAdsLoadedData data) {
                  final AdsManager manager = data.manager;
                  _adsManager = data.manager;

                  manager.setAdsManagerDelegate(AdsManagerDelegate(
                    onAdEvent: (AdEvent event) async {
                      printLog('OnAdsLoad : ${event.type} => ${event.adData}');
                      switch (event.type) {
                        case AdEventType.loaded:
                          manager.start();
                          if (_isVideoStarted && _adsManager != null) {
                            if (_checkPremiumLive()) {
                              _resumeContent();
                            } else {
                              _pauseContent();
                              await _adsManager?.start();
                            }
                            _pauseContent();
                            await _adsManager?.start();
                            _isAdLoaded = true;
                          }
                        case AdEventType.contentPauseRequested:
                          _pauseContent();
                          _isAdLoaded = true;
                        case AdEventType.contentResumeRequested:
                          _resumeContent();
                        case AdEventType.allAdsCompleted:
                          _isAdLoaded = false;
                          manager.destroy();
                          _adsManager = null;
                          _resumeContent();
                        case AdEventType.clicked:
                        case AdEventType.complete:
                          _updateVideoState(isPlaying: true);
                        case _:
                      }
                    },
                    onAdErrorEvent: (AdErrorEvent event) {
                      printLog('OnAdsLoad ErrorEvent : ${event.error.message}');
                      _resumeContent();
                    },
                  ));

                  manager.init(settings: AdsRenderingSettings());
                },
                onAdsLoadError: (AdsLoadErrorData data) {
                  printLog('OnAdsLoad Error : ${data.error.message}');
                  _isAdLoaded = false;
                  _adsManager = null;
                  _resumeContent();
                },
              );

              // Ads can't be requested until the `AdDisplayContainer` has been added to
              // the native View hierarchy.
              _requestAds(container);
            },
          )
        : null;

    _playerInit();
  }

  Future<void> _playerInit() async {
    WidgetsFlutterBinding.ensureInitialized();
    /* ******* Check Device Sync ******* */
    if (connectivityProvider.isOnline &&
        (widget.playerModel.playType == "Video" ||
            widget.playerModel.playType == "Show") &&
        Constant.userID != null &&
        widget.playerModel.isPremium == 1) {
      await playerProvider.addRemoveDevice(1);
      if (!playerProvider.isDeviceAdded) {
        if (!mounted) return;
        dynamic isNotWatching = await Utils.openWebDialog(
          context: context,
          newPage: RoutesConstant.cannotWatchPage,
          oldPage: "",
          reqText: "",
        );
        printLog("isNotWatching =========> $isNotWatching");
        if (!mounted) return;
        if (isNotWatching != null && isNotWatching == false) {
          if (kIsWeb) {
            if (context.canPop()) {
              context.pop(false);
            }
          } else {
            if (Navigator.canPop(context)) {
              Navigator.pop(context, false);
            }
          }
          return;
        }
      }
    }
    /* ************** */

    /* Subtitles & Quality */
    printLog("sSubTitleUrls Length =======> ${Constant.subtitleUrls.length}");
    if (widget.playerModel.playType == "Video" ||
        widget.playerModel.playType == "Show") {
      if (Constant.resolutionsUrls.isNotEmpty) {
        playerProvider
            .setCurrentQuality(Constant.resolutionsUrls[0].qualityName);
      }
    } else {
      Constant.resolutionsUrls.clear();
      Constant.resolutionsUrls = [];
    }
    /* ************** */

    /* Volume Change */
    if (!kIsWeb) {
      _volumeController?.getVolume().then((v) {
        playerProvider.volumeLevel = v;
        playerProvider.lastVolumeLevel = playerProvider.volumeLevel;
      });
      _volumeController?.isMuted().then((isMuted) {
        playerProvider.isVolMuted = isMuted;
      });

      /* Brightness Change */
      ScreenBrightness().application.then((b) {
        playerProvider.brightnessLevel = b;
      });
    }
    playerProvider.notifyProvider();

    initializePlayer();

    if (connectivityProvider.isOnline &&
        (widget.playerModel.playType == "Video" ||
            widget.playerModel.playType == "Show")) {
      /* Add Video view */
      playerProvider.addVideoView(
          widget.playerModel.videoId.toString(),
          widget.playerModel.videoType.toString(),
          widget.playerModel.subVideoType.toString(),
          widget.playerModel.episodeId.toString());
    }
  }

  Future<void> _setVideoURL() async {
    if (!kIsWeb && widget.playerModel.playType == "Download") {
      dynamic tempFile;

      /* Decrypt & Play START ******************** */
      tempFile = await Utils.decryptUsingFFMPEG([
        File(widget.playerModel.videoUrl ?? ""),
        widget.playerModel.securityKey ?? "",
        widget.playerModel.securityIVKey,
        context,
      ]);
      printLog("_playerInit tempFile ======> $tempFile");
      if (tempFile == null) return;
      _videoPlayerController =
          VideoPlayerController.file(File(tempFile?.path ?? ""));
      /* ********************** Decrypt & Play END */
    } else {
      if (widget.playerModel.playType == "Video" ||
          widget.playerModel.playType == "Show") {
        if (Constant.resolutionsUrls.isNotEmpty) {
          _videoPlayerController = VideoPlayerController.networkUrl(
            Uri.parse(Constant.resolutionsUrls[0].qualityUrl),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
          );
        } else {
          _videoPlayerController = VideoPlayerController.networkUrl(
            Uri.parse(widget.playerModel.videoUrl ?? ""),
            videoPlayerOptions: VideoPlayerOptions(
              mixWithOthers: false,
              allowBackgroundPlayback: false,
            ),
          );
        }
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.playerModel.trailerUrl ?? ""),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: false,
            allowBackgroundPlayback: false,
          ),
        );
      }
    }
  }

  Future<void> initializePlayer() async {
    await Future.wait([_videoPlayerController.initialize()])
        .then((value) async {
      if (mounted) {
        printLog(
            "initializePlayer stopTime :===> ${widget.playerModel.stopTime}");

        /* Subtitle Loads START */
        String? body;
        if (Constant.subtitleUrls.isNotEmpty) {
          try {
            printLog(
                "initializePlayer subtitleUrl ========> ${Constant.subtitleUrls[0].subtitleUrl}");

            // Create custom headers
            playerProvider
                .setCurrentSubtitle(Constant.subtitleUrls[0].subtitleLang);
            final response =
                await http.get(Uri.parse(Constant.subtitleUrls[0].subtitleUrl));
            printLog(
                "initializePlayer Subtitles statusCode =====> ${response.statusCode}");
            if (response.statusCode == 200) {
              body = utf8.decode(response.bodyBytes);
              subtitleController =
                  SubtitleController.string(body, format: SubtitleFormat.srt);
            }
          } on Exception catch (e) {
            printLog("initializePlayer Exception =====> $e");
          }

          if (subtitleController != null) {
            playerProvider.setSubtitles(
              subtitleController!.subtitles.map(
                (e) {
                  printLog(
                      "initializePlayer setSubtitles number ==> ${e.number}");
                  printLog(
                      "initializePlayer setSubtitles start ===> ${e.start}");
                  printLog("initializePlayer setSubtitles end =====> ${e.end}");
                  return mysubtitle.Subtitle(
                    index: e.number,
                    start: Duration(milliseconds: e.start),
                    end: Duration(milliseconds: e.end),
                    text: e.text,
                  );
                },
              ).toList(),
            );
          }
        }
        /* Subtitle Loads END */

        if (widget.playerModel.stopTime != null &&
            (widget.playerModel.stopTime ?? 0) > 0) {
          await _videoPlayerController
              .seekTo(Duration(milliseconds: widget.playerModel.stopTime ?? 0));
        }
        await _videoPlayerController.play();

        if (kIsWeb) {
          _jsHelper.callBrowserFullscreen(true);
        }
        if (_videoPlayerController.value.isPlaying == true) {
          _isVideoStarted = _videoPlayerController.value.isPlaying;
          if (!kIsWeb && _isAdLoaded && _adsManager != null) {
            if (_checkPremiumLive()) {
              _resumeContent();
            } else {
              _pauseContent();
              _isAdLoaded = true;
              await _adsManager?.start();
            }
          } else {
            _resumeContent();
          }
          if (!kIsWeb) _updateVideoState(isPlaying: true);
        }
        if (!mounted) return;
        playerProvider.notifyProvider();
        _startHideTimer();
        startDurationTimer();
      }
    });

    _videoPlayerController.addListener(() async {
      playerCPosition = (_videoPlayerController.value.position).inMilliseconds;
      videoTotalDuration =
          (_videoPlayerController.value.duration).inMilliseconds;

      if (!kIsWeb) {
        _updateVideoProgress();
      }

      if (_videoPlayerController.value.isInitialized) {
        if (widget.playerModel.episodeList != null &&
            (widget.playerModel.episodeList?.length ?? 0) > 0) {
          // Ensure video is playing
          if (!_videoPlayerController.value.isPlaying) return;

          // Prevent repeated popups
          if (_hasShownNextEpisodePopup) return;

          // Safety check
          if (videoTotalDuration == null || playerCPosition == null) return;

          int remainingMs = (videoTotalDuration ?? 0) - (playerCPosition ?? 0);

          // CASE 1: Normal playback — entering last 60s range
          if (remainingMs <= nextEpisodeThresholdMs && remainingMs > 0) {
            // If started inside last 60s, wait a few seconds before showing
            if (_initialPositionMs >=
                ((videoTotalDuration ?? 0) - nextEpisodeThresholdMs)) {
              if ((playerCPosition ?? 0) - _initialPositionMs <
                  safeStartDelayMs) {
                return; // still within safe start delay
              }
            }

            // Auto-adjust countdown based on remaining seconds
            int remainingSec = (remainingMs / 1000).floor();
            _countdownSeconds = remainingSec < 5 ? remainingSec : 5;

            // Trigger popup
            if (!mounted) return;
            setState(() {
              _showNextEpisodePopup = true;
            });
            _hasShownNextEpisodePopup = true;

            _startCountdown();
          }
        }
      }
      // printLog("addListener playerCPosition :===> $playerCPosition");
      // printLog("addListener videoDuration :=====> $videoTotalDuration");
    });

    /* Handle PIP */
    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == "pipClosed") {
        int? position = call.arguments;
        if (position != null) {
          setState(() {
            playerCPosition = position;
          });

          printLog("pipClosed playerCPosition :=====> $playerCPosition");
          // Resume video from last position
          await _videoPlayerController
              .seekTo(Duration(seconds: playerCPosition ?? 0));
          playPausePlayer(true);
        }
      }
    });
  }

  Future<void> playPausePlayer(bool isPlay) async {
    if (!mounted) return;
    if (!isPlay) {
      await _videoPlayerController.pause();
    } else {
      await _videoPlayerController.play();
    }
    playerProvider.notifyProvider();
    _startHideTimer();
  }

  /* Player Duration Monitor START *************** */
  Future<void> _durationMonitor() async {
    // monitor cast events
    var dur = _videoPlayerController.value.duration,
        pos = _videoPlayerController.value.position;
    if (!mounted) return;
    if (videoTDuration == null ||
        (videoTDuration?.inSeconds != dur.inSeconds)) {
      setState(() {
        videoTDuration = dur;
      });
    }
    if (videoCPosition == null ||
        (videoCPosition?.inSeconds != pos.inSeconds)) {
      setState(() {
        videoCPosition = pos;
      });
    }
  }

  void resetDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void startDurationTimer() {
    if (_durationTimer?.isActive ?? false) {
      return;
    }
    resetDurationTimer();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _durationMonitor();
      if (!mounted) return;
      playerProvider.setSubtitlePosition(_videoPlayerController.value.position);
      printLog(
          "startDurationTimer _subtitlesPosition :===> ${playerProvider.subtitlesPosition}");
    });
  }
  /* ***************** Player Duration Monitor END */

  @override
  void dispose() {
    super.dispose();
    routeObserver.unsubscribe(this);
    _countdownTimer?.cancel();
    _updateVideoState(isPlaying: false);
    if (_videoProgressTimer != null) {
      _videoProgressTimer?.cancel();
    }
    if (!kIsWeb) {
      _adsManager?.pause();
      _adsManager?.destroy();
      _adsManager = null;
    }
    if (!kIsWeb) {
      OrientationManager.forcePortrait();
    } else {
      _jsHelper.callBrowserFullscreen(false);
    }
    _hideTimer?.cancel();
    _doubleTapTimer?.cancel();
    _videoPlayerController.dispose();
    // resetTimer();
    // if (!kIsWeb) {
    //   if (Platform.isAndroid && _chromeCastController != null) {
    //     _chromeCastController?.stop();
    //     _chromeCastController?.endSession();
    //   }
    // }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    int totalSeconds = _countdownSeconds;

    _countdownProgress = 1.0; // full bar
    if (!mounted) return;
    setState(() {});

    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds <= 1) {
        _countdownTimer?.cancel();
        _playNextEpisode();
      } else {
        _countdownSeconds--;
        _countdownProgress = _countdownSeconds / totalSeconds;
        setState(() {});
      }
    });
  }

  void _cancelNextEpisode() {
    if (!mounted) return;
    _countdownTimer?.cancel(); // Stop countdown timer
    setState(() {
      _showNextEpisodePopup = false; // Hide popup
    });
    _hasShownNextEpisodePopup = true; // Prevent re-trigger during same playback
  }

  Future<void> _playNextEpisode() async {
    if (!mounted) return;
    setState(() {
      _popupOpacity = 0.0; // start fade-out
    });
    Future.delayed(Duration(milliseconds: 400), () async {
      if (!_showNextEpisodePopup) return;

      if (((widget.playerModel.currentEpiPos ?? 0) + 1) >
          (widget.playerModel.episodeList?.length ?? 0)) {
        onBackPressed(false);
        return;
      }

      /* VdoCipher OTP */
      VdoCipherModel? vdocipherDetails;
      if ((widget
                      .playerModel
                      .episodeList?[(widget.playerModel.currentEpiPos ?? 0) + 1]
                      .videoUploadType ??
                  "") ==
              Constant.vdocipherPlayType &&
          widget.playerModel.playType != "Trailer") {
        if (!mounted) return;
        vdocipherDetails = await Utils.getVdoCipherOTP(
            context: context,
            videoId: (widget
                    .playerModel
                    .episodeList?[(widget.playerModel.currentEpiPos ?? 0) + 1]
                    .video320 ??
                ""));
        printLog(
            "openPlayer vdocipherDetails ======> ${vdocipherDetails?.result?.otp}");
      }
      /* VdoCipher OTP */

      // Load your next episode data here
      // For demo purposes:
      PlayerModel playerModel = PlayerModel(
        playType: widget.playerModel.playType,
        isLive: false,
        videoId: widget.playerModel.videoId ?? 0,
        videoTitle: widget.playerModel.videoTitle ?? "",
        videoType: widget.playerModel.videoType ?? 0,
        subVideoType: 0,
        typeId: widget.playerModel.typeId ?? 0,
        episodeId: widget.playerModel
                .episodeList?[(widget.playerModel.currentEpiPos ?? 0) + 1].id ??
            0,
        videoUrl: widget
                .playerModel
                .episodeList?[(widget.playerModel.currentEpiPos ?? 0) + 1]
                .video320 ??
            "",
        cipherMediaDetails:
            (vdocipherDetails != null && vdocipherDetails.result != null)
                ? (vdocipherDetails.result)
                : null,
        trailerUrl: widget.playerModel.trailerUrl ?? "",
        uploadType: widget.playerModel.uploadType ?? "",
        videoThumb: widget
                .playerModel
                .episodeList?[(widget.playerModel.currentEpiPos ?? 0) + 1]
                .landscape ??
            "",
        stopTime: widget.playerModel.stopTime ?? 0,
        isPremium: widget.playerModel.isPremium ?? 0,
        isBuy: widget.playerModel.isBuy ?? 0,
        isRent: widget.playerModel.isRent ?? 0,
        rentBuy: widget.playerModel.rentBuy ?? 0,
        securityKey: widget.playerModel.securityKey ?? "",
        securityIVKey: widget.playerModel.securityIVKey ?? "",
        currentEpiPos: (widget.playerModel.currentEpiPos ?? 0) + 1,
        episodeList: widget.playerModel.episodeList,
      );
      if (!mounted) return;
      /* Pod Player & Youtube Player */
      if (!context.mounted) return;
      if (kIsWeb) {
        context.pushReplacement(
          "/${RoutesConstant.playerPage}",
          extra: playerModel,
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerVideo(playerModel: playerModel),
          ),
        );
      }
    });
  }

  void _resetDoubleTapCount() {
    _doubleTapCountForward = 0;
    _doubleTapCountBackward = 0;
    _doubleTapTimer?.cancel();
  }

  Future<void> _handleDoubleTap(bool isForward) async {
    if (isForward) {
      _doubleTapCountForward++;
      final seconds = 10 * _doubleTapCountForward;
      _videoPlayerController.seekTo(
        _videoPlayerController.value.position + Duration(seconds: seconds),
      );
      await playerProvider.showSeekPopupTexts("+$seconds", isForward);
    } else {
      _doubleTapCountBackward++;
      final seconds = 10 * _doubleTapCountBackward;
      _videoPlayerController.seekTo(
        _videoPlayerController.value.position - Duration(seconds: seconds),
      );
      await playerProvider.showSeekPopupTexts("-$seconds", isForward);
    }

    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(Duration(seconds: 1), () {
      _resetDoubleTapCount();
    });
  }

  Future<void> _toggleControls() async {
    printLog("_toggleControls _showControls =====> $_showControls");
    printLog("_toggleControls _isVideoStarted ===> $_isVideoStarted");
    if (!_shouldShowContentVideo) return;
    if (!mounted) return;
    _showControls = !_showControls;
    _isVideoStarted = _videoPlayerController.value.isPlaying;
    if (!mounted) return;
    if (_showControls) _startHideTimer();
    playerProvider.notifyProvider();
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();

    if (!mounted) return;
    _showControls = true;
    _isVideoStarted = _videoPlayerController.value.isPlaying;

    if (!mounted) return;
    // _startHideTimer();
  }

  Future<void> _startHideTimer() async {
    printLog("_startHideTimer _showControls =====> $_showControls");
    printLog("_startHideTimer _isVideoStarted ===> $_isVideoStarted");
    if (_hideTimer != null) {
      _hideTimer?.cancel();
    }
    _hideTimer = Timer(Duration(seconds: 3), () async {
      _showControls = false;
      _isVideoStarted = _videoPlayerController.value.isPlaying;
      if (!mounted) return;
      playerProvider.notifyProvider();
    });
  }

  Future<void> _seekRelative(Duration relativeSeek) async {
    final position = _videoPlayerController.value.position + relativeSeek;
    final duration = _videoPlayerController.value.duration;

    if (position < Duration.zero) {
      _videoPlayerController.seekTo(Duration.zero);
    } else if (position > duration) {
      _videoPlayerController.seekTo(duration);
    } else {
      _videoPlayerController.seekTo(position);
    }
  }

  Future<void> _seekBackward() async {
    await _toggleControls();
    await _handleDoubleTap(false);
    await _seekRelative(const Duration(seconds: -10));
  }

  Future<void> _seekForward() async {
    await _toggleControls();
    await _handleDoubleTap(true);
    await _seekRelative(const Duration(seconds: 10));
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, Size size) async {
    if (kIsWeb) return;
    final dx = details.globalPosition.dx;
    final dy = details.delta.dy;

    if (dx < size.width / 2) {
      // Left side: Brightness
      playerProvider.brightnessLevel -= dy * 0.005;
      playerProvider.brightnessLevel =
          playerProvider.brightnessLevel.clamp(0.0, 1.0);
      ScreenBrightness()
          .setApplicationScreenBrightness(playerProvider.brightnessLevel);
      playerProvider.showBrightnessBar = true;
    } else {
      // Right side: Volume
      playerProvider.volumeLevel -= dy * 0.005;
      playerProvider.volumeLevel = playerProvider.volumeLevel.clamp(0.0, 1.0);
      _volumeController?.setVolume(playerProvider.volumeLevel);
      playerProvider.showVolumeBar = true;
      await _volumeController?.setMute(playerProvider.volumeLevel <= 0);
      playerProvider.isVolMuted = (_volumeController != null)
          ? (await _volumeController.isMuted())
          : false;
    }
    playerProvider.notifyProvider();
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _hideVolumeAndBrightnessBars();
  }

  void _onVerticalDragCancel() {
    _hideVolumeAndBrightnessBars();
  }

  void _hideVolumeAndBrightnessBars() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        playerProvider.showVolumeBar = false;
        playerProvider.showBrightnessBar = false;
        playerProvider.notifyProvider();
      }
    });
  }

  Future<void> updateMuteStatus(bool isMute) async {
    if (kIsWeb) return;
    if (isMute) {
      playerProvider.lastVolumeLevel = playerProvider.volumeLevel;
      playerProvider.volumeLevel = 0.0;
    } else {
      playerProvider.volumeLevel = playerProvider.lastVolumeLevel;
    }
    await _volumeController?.setMute(isMute);
    if (Platform.isIOS) {
      // On iOS, the system does not update the mute status immediately
      // You need to wait for the system to update the mute status
      await Future.delayed(Duration(milliseconds: 50));
    }
    playerProvider.isVolMuted = (_volumeController != null)
        ? (await _volumeController.isMuted())
        : false;
    playerProvider.notifyProvider();
  }

  /* Quality START ********************************** */
  void updateQualityUrl({
    required String qualityName,
    required String qualityUrl,
  }) async {
    printLog("updateQualityUrl qualityUrl =====NEW===> $qualityUrl");
    printLog("updateQualityUrl qualityName ====NEW===> $qualityName");
    printLog(
        "updateQualityUrl currentQuality =======> ${playerProvider.currentQuality}");
    if (playerProvider.currentQuality == qualityName) return;

    if (playerProvider.currentQuality == qualityName) return;

    playerCPosition = (_videoPlayerController.value.position).inMilliseconds;
    final wasPlaying = _videoPlayerController.value.isPlaying;

    final newController = VideoPlayerController.networkUrl(
      Uri.parse(qualityUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );
    await newController.initialize();
    await newController.seekTo(Duration(milliseconds: playerCPosition ?? 0));
    playerProvider.notifyProvider();

    if (!mounted) return;
    await _videoPlayerController.pause();
    await _videoPlayerController.dispose();

    _videoPlayerController = newController;

    if (wasPlaying) {
      await _videoPlayerController.play();
      startDurationTimer();
    }

    playerProvider.setCurrentQuality(qualityName);
    playerProvider.notifyProvider();
  }
  /* ************************************ Quality END */

  /* Subtitle START ********************************** */
  Future<void> updateSubtitleUrl({required String subtitleUrl}) async {
    printLog("updateSubtitleUrl subtitleUrl ============> $subtitleUrl");
    printLog(
        "updateSubtitleUrl currentSubtitle ========> ${playerProvider.currentSubtitle}");
    if (subtitleController != null) {
      /* Subtitle Loads START */
      String? body;
      playerProvider.setCurrentSubtitle(playerProvider.currentSubtitle);

      body = utf8.decode((await http.get(Uri.parse(subtitleUrl))).bodyBytes);
      subtitleController = null;
      subtitleController =
          SubtitleController.string(body, format: SubtitleFormat.srt);

      if (body != "") {
        _videoPlayerController
            .setClosedCaptionFile(Future.value(SubRipCaptionFile(body)));
      }

      playerProvider.setSubtitles(
        subtitleController!.subtitles.map(
          (e) {
            printLog("updateSubtitleUrl setSubtitles number ==> ${e.number}");
            printLog("updateSubtitleUrl setSubtitles start ===> ${e.start}");
            printLog("updateSubtitleUrl setSubtitles end =====> ${e.end}");
            return mysubtitle.Subtitle(
              index: e.number,
              start: Duration(milliseconds: e.start),
              end: Duration(milliseconds: e.end),
              text: e.text,
            );
          },
        ).toList(),
      );

      if (!mounted) return;
      playerProvider.setSubtitlePosition(_videoPlayerController.value.position);
      printLog(
          "updateSubtitleUrl _subtitlesPosition :===> ${playerProvider.subtitlesPosition}");
      /* Subtitle Loads END */
      if (!mounted) return;
      await playerProvider.setSubtitleState(true);
    }
  }
  /* ************************************ Subtitle END */

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        onBackPressed(didPop);
      },
      child: MouseRegion(
        // onHover: (_) => _cancelAndRestartTimer(),
        onEnter: (event) {
          _cancelAndRestartTimer();
        },
        onExit: (event) {
          _startHideTimer();
        },
        child: GestureDetector(
          onTap: _toggleControls,
          onVerticalDragEnd: _onVerticalDragEnd,
          onVerticalDragCancel: _onVerticalDragCancel,
          onVerticalDragUpdate: (details) =>
              _onVerticalDragUpdate(details, MediaQuery.of(context).size),
          onDoubleTapDown: (details) async {
            final screenWidth = MediaQuery.of(context).size.width;
            final dx = details.globalPosition.dx;

            final isFinished = (_videoPlayerController.value.position >=
                    _videoPlayerController.value.duration) &&
                _videoPlayerController.value.duration.inSeconds > 0;

            if (widget.playerModel.isLive == true ||
                !_shouldShowContentVideo ||
                isFinished) {
              return;
            }

            if (dx < screenWidth / 2) {
              _handleDoubleTap(false);
            } else {
              _handleDoubleTap(true);
            }
          },
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Consumer<PlayerProvider>(
              builder: (context, playerProvider, child) {
                return Stack(
                  children: [
                    if (_checkPremiumLive() && _adDisplayContainer != null)
                      Center(
                        child: SafeArea(
                          child: Container(
                            padding: EdgeInsets.all(8),
                            alignment: Alignment.center,
                            child: _adDisplayContainer,
                          ),
                        ),
                      ),
                    _setBuildPlayer(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _setBuildPlayer() {
    if (_shouldShowContentVideo) {
      if (_videoPlayerController.value.isInitialized) {
        // if (kIsWeb) {
        return Container(
          key: const ValueKey("video-player"),
          child: _buildPlayer(),
        );
        // } else {
        //   return _handleState();
        // }
      } else {
        return _buildLoadingView();
      }
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildPlayer() {
    if (_videoPlayerController.value.isInitialized) {
      final bool isFinished = (_videoPlayerController.value.position >=
              _videoPlayerController.value.duration) &&
          _videoPlayerController.value.duration.inSeconds > 0;
      printLog("cSubtitleList ======> ${playerProvider.cSubtitleList}");
      return Stack(
        children: [
          Center(
            child: SizedBox.expand(
              child: FittedBox(
                fit: playerProvider.currentFit,
                child: SizedBox(
                  width: _videoPlayerController.value.size.width,
                  height: _videoPlayerController.value.size.height,
                  child: AspectRatio(
                    aspectRatio: _videoPlayerController.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController),
                  ),
                ),
              ),
            ),
          ),

          if (!kIsWeb &&
              !_showControls &&
              playerProvider.showBrightnessBar &&
              !isFinished)
            _buildSideBar("brightness", playerProvider.brightnessLevel,
                Alignment.centerLeft, Icons.brightness_6),

          if (!kIsWeb &&
              !_showControls &&
              playerProvider.showVolumeBar &&
              !isFinished)
            _buildSideBar(
                "volume",
                playerProvider.volumeLevel,
                Alignment.centerRight,
                playerProvider.isVolMuted ? Icons.volume_off : Icons.volume_up),

          // Center Bar
          if (_showControls) SafeArea(child: _buildHitArea()),

          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (_showControls) _buildTopBar(),
              const Spacer(),
              if (playerProvider.subtitleOn &&
                  playerProvider.cSubtitleList != null &&
                  widget.playerModel.isLive == false)
                Center(
                  child: Transform.translate(
                    offset: Offset(
                      0.0,
                      _showControls ? (47.0 * 0.3) : 0.0,
                    ),
                    child: _buildSubtitles(playerProvider.cSubtitleList!),
                  ),
                ),
              if (_showControls) _buildBottomBar(),
            ],
          ),

          // Show Seek buttons after double tap
          _buildSeekPopup(),

          if (!_showControls &&
              _showNextEpisodePopup &&
              widget.playerModel.episodeList != null &&
              (widget.playerModel.episodeList?.length ?? 0) > 0)
            Positioned(
              bottom: 15,
              right: 15,
              child: _buildCountdownWidget(),
            ),
        ],
      );
    } else {
      return Center(child: _buildLoadingView());
    }
  }

  Widget _buildHitArea() {
    final bool isFinished = (_videoPlayerController.value.position >=
            _videoPlayerController.value.duration) &&
        _videoPlayerController.value.duration.inSeconds > 0;
    _isVideoStarted = _videoPlayerController.value.isPlaying;
    return Container(
      alignment: Alignment.center,
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!kIsWeb && !isFinished)
            _buildSideBar("brightness", playerProvider.brightnessLevel,
                Alignment.centerLeft, Icons.brightness_6)
          else
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 150,
            ),
          if (!isFinished && widget.playerModel.isLive == false)
            Tooltip(
              message: 'Backward 10 sec',
              child: CenterSeekButtonNew(
                iconName: "ic_seek_left",
                iconColor: Colors.white,
                show: _showControls,
                fadeDuration: const Duration(seconds: 10),
                iconSize: 26,
                onPressed: _seekBackward,
              ),
            )
          else
            const SizedBox(height: 26, width: 26),
          Tooltip(
            message: 'Play/Pause',
            child: CenterPlayButton(
              backgroundColor: Colors.black54,
              iconColor: Colors.white,
              isFinished: isFinished,
              isPlaying: _isVideoStarted,
              show: _showControls,
              onPressed: () async {
                _isVideoStarted
                    ? _videoPlayerController.pause()
                    : _videoPlayerController.play();
                if (!mounted) return;
                playerProvider.notifyProvider();
                printLog("Play/Pause _isVideoStarted ==> $_isVideoStarted");
                printLog(
                    "Play/Pause isPlaying ========> ${_videoPlayerController.value.isPlaying}");
                if (!_videoPlayerController.value.isPlaying) {
                  _cancelAndRestartTimer();
                } else {
                  _startHideTimer();
                }
              },
            ),
          ),
          if (!isFinished && widget.playerModel.isLive == false)
            Tooltip(
              message: 'Forward 10 sec',
              child: CenterSeekButtonNew(
                iconName: "ic_seek_right",
                iconColor: Colors.white,
                show: _showControls,
                fadeDuration: const Duration(seconds: 10),
                iconSize: 26,
                onPressed: _seekForward,
              ),
            )
          else
            const SizedBox(height: 26, width: 26),
          if (!kIsWeb && !isFinished)
            _buildSideBar(
                "volume",
                playerProvider.volumeLevel,
                Alignment.centerRight,
                playerProvider.isVolMuted ? Icons.volume_off : Icons.volume_up)
          else
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 150,
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tooltip(
            message: 'Exit Player',
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                onBackPressed(false);
              },
            ),
          ),
          Spacer(),
          // if (!kIsWeb &&
          //     widget.playerModel.playType != "Download" &&
          //     Platform.isIOS)
          //   AirPlayButton(
          //     size: 50,
          //     color: Colors.white,
          //     activeColor: Colors.blue,
          //     onRoutesOpening: () => printLog('opening'),
          //     onRoutesClosed: () => printLog('closed'),
          //   ),
          // if (!kIsWeb &&
          //     widget.playerModel.playType != "Download" &&
          //     Platform.isAndroid)
          //   ChromeCastButton(
          //     size: 50,
          //     color: Colors.white,
          //     onButtonCreated: _onButtonCreated,
          //     onSessionStarted: _onSessionStarted,
          //     onSessionEnded: () => setState(() => _state = AppState.idle),
          //     onRequestCompleted: _onRequestCompleted,
          //     onRequestFailed: _onRequestFailed,
          //   ),
          if (widget.playerModel.isLive == false) _buildSubtitleToggle(),
          if (widget.playerModel.isLive == false) _buildOptionsButton(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoProgressIndicator(
              _videoPlayerController,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: colorPrimary,
                backgroundColor: Colors.grey,
                bufferedColor: Colors.white54,
              ),
            ),
            Row(
              children: [
                Tooltip(
                  message: 'Play/Pause',
                  child: IconButton(
                    icon: Icon(
                      _videoPlayerController.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      _videoPlayerController.value.isPlaying
                          ? _videoPlayerController.pause()
                          : _videoPlayerController.play();
                      if (!mounted) return;
                      playerProvider.notifyProvider();
                      _startHideTimer();
                    },
                  ),
                ),
                MyText(
                  color: Colors.white,
                  text: duration2String(
                    (widget.playerModel.isLive == false)
                        ? _videoPlayerController.value.position
                        : Duration.zero,
                  ),
                  multilanguage: false,
                  textalign: TextAlign.center,
                  fontsizeNormal: 15,
                  fontsizeWeb: 17,
                  fontweight: FontWeight.w600,
                  maxline: 2,
                  overflow: TextOverflow.ellipsis,
                  fontstyle: FontStyle.normal,
                ),
                Spacer(),
                if (widget.playerModel.isLive == false)
                  MyText(
                    color: Colors.white,
                    text: duration2String(
                      _videoPlayerController.value.duration,
                    ),
                    multilanguage: false,
                    textalign: TextAlign.center,
                    fontsizeNormal: 15,
                    fontsizeWeb: 17,
                    fontweight: FontWeight.w600,
                    maxline: 2,
                    overflow: TextOverflow.ellipsis,
                    fontstyle: FontStyle.normal,
                  ),
                Tooltip(
                  message: 'Change Fit Mode',
                  child: IconButton(
                    icon: Icon(
                      playerProvider.currentFit == BoxFit.contain
                          ? Icons.aspect_ratio
                          : playerProvider.currentFit == BoxFit.cover
                              ? Icons.fit_screen_sharp
                              : Icons.fullscreen,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      BoxFit finalNewFit;
                      if (playerProvider.currentFit == BoxFit.contain) {
                        if (kIsWeb) {
                          _jsHelper.callBrowserFullscreen(true);
                        }
                        finalNewFit = BoxFit.cover;
                      } else if (playerProvider.currentFit == BoxFit.cover) {
                        finalNewFit = BoxFit.fill;
                      } else {
                        finalNewFit = BoxFit.contain;
                      }
                      await playerProvider.changeBoxFit(finalNewFit);
                      _startHideTimer(); // Optional: Reset the hide timer
                    },
                  ),
                ),
                if (widget.playerModel.isLive == false)
                  Tooltip(
                    message: 'Playback Speed',
                    child: _buildSpeedButton(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekPopup() {
    if (playerProvider.showSeekPopup) {
      return Container(
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!playerProvider.isForwardSeek)
              Expanded(
                child: _buildRowIconTexts(
                  isForward: false,
                  iconName: "ic_seek_left",
                  reqText: playerProvider.seekPopupText ?? "",
                ),
              )
            else
              Expanded(child: SizedBox()),
            if (playerProvider.isForwardSeek)
              Expanded(
                child: _buildRowIconTexts(
                  isForward: true,
                  iconName: "ic_seek_right",
                  reqText: playerProvider.seekPopupText ?? "",
                ),
              )
            else
              Expanded(child: SizedBox()),
          ],
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  GestureDetector _buildSpeedButton() {
    return GestureDetector(
      onTap: () async {
        _hideTimer?.cancel();

        final chosenSpeed = await showCupertinoModalPopup<double>(
          context: context,
          semanticsDismissible: true,
          builder: (context) => _PlaybackSpeedDialog(
            speeds: [0.5, 1.0, 1.5, 2.0],
            selected: _playbackSpeed,
          ),
        );

        if (chosenSpeed != null) {
          _videoPlayerController.setPlaybackSpeed(chosenSpeed);

          _playbackSpeed = chosenSpeed;
        }

        if (_videoPlayerController.value.isPlaying) {
          _startHideTimer();
        }
      },
      child: Container(
        height: 47.0,
        color: Colors.transparent,
        padding: const EdgeInsets.only(
          left: 6.0,
          right: 8.0,
        ),
        margin: const EdgeInsets.only(
          right: 8.0,
        ),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.skewY(0.0)
            ..rotateX(math.pi)
            ..rotateZ(math.pi * 0.8),
          child: Icon(
            Icons.speed,
            color: Colors.white,
            size: 25.0,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleToggle() {
    //if don't have subtitle hiden button
    if (Constant.subtitleUrls.isEmpty) {
      return const SizedBox();
    }
    return Tooltip(
      message: 'Subtitles ON/OFF',
      child: GestureDetector(
        onTap: _subtitleToggle,
        child: Container(
          height: 47.0,
          color: Colors.transparent,
          margin: const EdgeInsets.only(right: 10.0),
          padding: const EdgeInsets.only(
            left: 6.0,
            right: 6.0,
          ),
          child: Icon(
            playerProvider.subtitleOn ? Icons.subtitles : Icons.subtitles_off,
            color: Colors.white,
            size: 25.0,
          ),
        ),
      ),
    );
  }

  Future<void> _subtitleToggle() async {
    if (!mounted) return;
    await playerProvider.setSubtitleState(!playerProvider.subtitleOn);
  }

  Widget _buildSubtitles(Subtitles subtitles) {
    if (!playerProvider.subtitleOn) {
      return const SizedBox();
    }
    if (playerProvider.subtitlesPosition == null) {
      return const SizedBox();
    }
    printLog(
        "_subtitleToggle _subtitlesPosition ====> ${playerProvider.subtitlesPosition?.inMilliseconds}");
    final currentSubtitle =
        subtitles.getByPosition(playerProvider.subtitlesPosition!);
    if (currentSubtitle.isEmpty) {
      return const SizedBox();
    }
    printLog("_subtitleToggle currentSubtitle ====> $currentSubtitle");
    return Container(
      margin: EdgeInsets.fromLTRB(10, 15, 10, 15),
      padding: EdgeInsets.fromLTRB(15, 5, 15, 5),
      decoration: BoxDecoration(
        color: const Color(0x96000000),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: MyText(
        color: Colors.white,
        text: currentSubtitle.first?.text.toString() ?? "",
        multilanguage: false,
        textalign: TextAlign.center,
        fontsizeNormal: 18,
        fontsizeWeb: 20,
        fontweight: FontWeight.w600,
        maxline: 2,
        overflow: TextOverflow.ellipsis,
        fontstyle: FontStyle.normal,
      ),
    );
  }

  Widget _buildLoadingView() {
    return Stack(
      children: [
        // Center Bar
        SafeArea(
            child: Container(
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              Tooltip(
                message: 'Backward 10 sec',
                child: CenterSeekButtonNew(
                  iconName: "ic_seek_left",
                  iconColor: Colors.white,
                  show: true,
                  fadeDuration: const Duration(seconds: 10),
                  iconSize: 26,
                  onPressed: () {},
                ),
              ),
              Tooltip(
                message: 'Play/Pause',
                child: Center(child: _buildLoading()),
              ),
              Tooltip(
                message: 'Forward 10 sec',
                child: CenterSeekButtonNew(
                  iconName: "ic_seek_right",
                  iconColor: Colors.white,
                  show: true,
                  fadeDuration: const Duration(seconds: 10),
                  iconSize: 26,
                  onPressed: () {},
                ),
              ),
              const Spacer(),
            ],
          ),
        )),

        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Align(
              alignment: Alignment.topLeft,
              child: Tooltip(
                message: 'Exit Player',
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    onBackPressed(false);
                  },
                ),
              ),
            ),
            const Spacer(),
            SafeArea(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: 0.0,
                      color: colorPrimary,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                      backgroundColor: Colors.grey,
                    ),
                    Row(
                      children: [
                        Tooltip(
                          message: 'Play/Pause',
                          child: IconButton(
                            icon: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: () async {},
                          ),
                        ),
                        MyText(
                          color: Colors.white,
                          text: "00:00:00",
                          multilanguage: false,
                          textalign: TextAlign.center,
                          fontsizeNormal: 15,
                          fontsizeWeb: 17,
                          fontweight: FontWeight.w600,
                          maxline: 2,
                          overflow: TextOverflow.ellipsis,
                          fontstyle: FontStyle.normal,
                        ),
                        Spacer(),
                        MyText(
                          color: Colors.white,
                          text: "00:00:00",
                          multilanguage: false,
                          textalign: TextAlign.center,
                          fontsizeNormal: 15,
                          fontsizeWeb: 17,
                          fontweight: FontWeight.w600,
                          maxline: 2,
                          overflow: TextOverflow.ellipsis,
                          fontstyle: FontStyle.normal,
                        ),
                        Tooltip(
                          message: 'Change Fit Mode',
                          child: IconButton(
                            icon: Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                            ),
                            onPressed: () async {},
                          ),
                        ),
                        Tooltip(
                          message: 'Playback Speed',
                          child: Container(
                            height: 47.0,
                            color: Colors.transparent,
                            padding: const EdgeInsets.only(
                              left: 6.0,
                              right: 8.0,
                            ),
                            margin: const EdgeInsets.only(
                              right: 8.0,
                            ),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.skewY(0.0)
                                ..rotateX(math.pi)
                                ..rotateZ(math.pi * 0.8),
                              child: Icon(
                                Icons.speed,
                                color: Colors.white,
                                size: 25.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Consumer<PlayerProvider>(
      builder: (context, playerProvider, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.playerModel.playType == "Download")
                SizedBox(
                  height: 70,
                  width: 70,
                  child: Utils.progressWithPercentage(playerProvider.progress),
                ),
              SizedBox(
                height: 70,
                width: 70,
                child: Utils.pageLoader(),
              ),
              if (widget.playerModel.playType == "Download")
                const SizedBox(height: 20),
              if (widget.playerModel.playType == "Download")
                MyText(
                  color: titleTextColor,
                  text:
                      "${Locales.string(context, "loading")} ${(playerProvider.progress * 100).toStringAsFixed(2)}%",
                  textalign: TextAlign.center,
                  fontsizeNormal: 14,
                  fontweight: FontWeight.w600,
                  fontsizeWeb: 16,
                  multilanguage: false,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  fontstyle: FontStyle.normal,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountdownWidget() {
    return AnimatedOpacity(
      opacity: _popupOpacity,
      duration: Duration(milliseconds: 400),
      child: Container(
        width: (MediaQuery.of(context).size.width * 0.5),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            MyNetworkImage(
              imageUrl:
                  "${widget.playerModel.episodeList?[(widget.playerModel.currentEpiPos ?? 0) + 1].landscape}",
              width: 80,
              height: 60,
              fit: BoxFit.cover,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    color: white,
                    multilanguage: false,
                    text:
                        "${widget.playerModel.episodeList?[(widget.playerModel.currentEpiPos ?? 0) + 1].description}",
                    textalign: TextAlign.start,
                    fontsizeNormal: 14,
                    fontweight: FontWeight.w700,
                    fontsizeWeb: 16,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    fontstyle: FontStyle.normal,
                  ),
                  SizedBox(height: 4),
                  MyText(
                    color: white,
                    multilanguage: false,
                    text: "Playing in $_countdownSeconds sec",
                    textalign: TextAlign.start,
                    fontsizeNormal: 12,
                    fontweight: FontWeight.normal,
                    fontsizeWeb: 14,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    fontstyle: FontStyle.normal,
                  ),
                  SizedBox(height: 6),
                  // Netflix gradient progress bar
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 900),
                        curve: Curves.linear,
                        width: (MediaQuery.of(context).size.width * 0.75) *
                            _countdownProgress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.redAccent,
                              Colors.deepOrange,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.play_arrow, color: Colors.white),
              onPressed: _playNextEpisode,
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.white), // Cancel button
              onPressed: _cancelNextEpisode,
            ),
          ],
        ),
      ),
    );
  }

  GestureDetector _buildOptionsButton() {
    final options = <OptionItem>[];
    OptionItem qualityItem = OptionItem(
      onTap: (context) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        qualityDialog();
      },
      iconData: Icons.video_collection_rounded,
      title: 'Quality',
    );
    OptionItem subtitlesItem = OptionItem(
      onTap: (context) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        subtitleDialog();
      },
      iconData: Icons.video_collection_rounded,
      title: 'Subtitles',
    );

    if (Constant.resolutionsUrls.isNotEmpty) options.add(qualityItem);
    if (Constant.subtitleUrls.isNotEmpty) options.add(subtitlesItem);

    return GestureDetector(
      onTap: () async {
        _hideTimer?.cancel();
        await showCupertinoModalPopup<OptionItem>(
          context: context,
          semanticsDismissible: true,
          builder: (context) => CupertinoOptionsDialog(
            options: options,
            cancelButtonText: "Cancel",
          ),
        );
        if (_videoPlayerController.value.isPlaying) {
          _startHideTimer();
        }
      },
      child: Tooltip(
        message: 'Quality/Subtitles change',
        child: Container(
          height: 47.0,
          color: Colors.transparent,
          padding: const EdgeInsets.only(left: 4.0, right: 8.0),
          margin: const EdgeInsets.only(right: 6.0),
          child: Icon(
            Icons.more_vert,
            color: Colors.white,
            size: 23,
          ),
        ),
      ),
    );
  }

  Future<void> subtitleDialog() async {
    await showCupertinoModalPopup<void>(
      context: context,
      semanticsDismissible: true,
      useRootNavigator: true,
      builder: (context) {
        return CupertinoActionSheet(
          actions: Constant.subtitleUrls
              .map(
                (option) => CupertinoActionSheetAction(
                  onPressed: () async {
                    playerProvider.setCurrentSubtitle(option.subtitleLang);
                    updateSubtitleUrl(subtitleUrl: option.subtitleUrl);
                    if (!context.mounted) return;
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    option.subtitleLang,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontStyle: FontStyle.normal,
                      color: (playerProvider.currentSubtitle ==
                              option.subtitleLang)
                          ? black
                          : black.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            isDestructiveAction: true,
            child: Text(
              "Cancel",
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontStyle: FontStyle.normal,
                color: redColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    ).then((value) {
      printLog("============= SUBTITLE =============");
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> qualityDialog() async {
    await showCupertinoModalPopup<void>(
      context: context,
      semanticsDismissible: true,
      useRootNavigator: true,
      builder: (context) {
        return CupertinoActionSheet(
          actions: Constant.resolutionsUrls
              .map(
                (option) => CupertinoActionSheetAction(
                  onPressed: () async {
                    updateQualityUrl(
                      qualityName: option.qualityName,
                      qualityUrl: option.qualityUrl,
                    );
                    if (!context.mounted) return;
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    option.qualityName,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontStyle: FontStyle.normal,
                      color:
                          (playerProvider.currentQuality == option.qualityName)
                              ? black
                              : black.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            isDestructiveAction: true,
            child: Text(
              "Cancel",
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontStyle: FontStyle.normal,
                color: redColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    ).then((value) {
      printLog("============= QUALITY =============");
      if (!mounted) return;
      setState(() {});
    });
  }

  /* Brightness/Volume START ********************************** */
  Widget _buildSideBar(
    String btnType,
    double value,
    Alignment alignment,
    IconData icon,
  ) {
    return SafeArea(
      child: Align(
        alignment: alignment,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          padding: EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () async {
                  await updateMuteStatus(!playerProvider.isVolMuted);
                },
                child: Icon(icon, color: Colors.white),
              ),
              SizedBox(height: 8),
              Expanded(
                child: RotatedBox(
                  quarterTurns: -1,
                  child: LinearProgressIndicator(
                    value: value,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  /* ************************************ Brightness/Volume END */

  /* ChromeCast START ********************************** */
  // Widget _handleState() {
  //   printLog("_handleState _state ==========> $_state");
  //   switch (_state) {
  //     case AppState.connected:
  //       playPausePlayer(false);
  //       return _buildLoading();
  //     case AppState.mediaLoaded:
  //       playPausePlayer(false);
  //       startTimer();
  //       return _mediaControls();
  //     default:
  //       resetTimer();
  //       return _buildPlayer();
  //   }
  // }
  // Duration? position, duration;
  // Widget _mediaControls() {
  //   return SingleChildScrollView(
  //     padding: const EdgeInsets.all(20),
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         MyText(
  //           color: descTextColor,
  //           text: "playing_cast_device",
  //           multilanguage: true,
  //           textalign: TextAlign.center,
  //           fontsizeNormal: 15,
  //           fontsizeWeb: 17,
  //           fontweight: FontWeight.w600,
  //           maxline: 3,
  //           overflow: TextOverflow.ellipsis,
  //           fontstyle: FontStyle.normal,
  //         ),
  //         const SizedBox(height: 20),
  //         ClipRRect(
  //           borderRadius: BorderRadius.circular(8),
  //           child: MyNetworkImage(
  //             width: Dimens.widthLand,
  //             height: Dimens.heightLand,
  //             imageUrl: '${_mediaInfo['image']}',
  //             fit: BoxFit.cover,
  //           ),
  //         ),
  //         const SizedBox(height: 20),
  //         MyText(
  //           color: titleTextColor,
  //           text: '${_mediaInfo['title']}',
  //           multilanguage: false,
  //           textalign: TextAlign.center,
  //           fontsizeNormal: 22,
  //           fontsizeWeb: 24,
  //           fontweight: FontWeight.w700,
  //           maxline: 2,
  //           overflow: TextOverflow.ellipsis,
  //           fontstyle: FontStyle.normal,
  //         ),
  //         const SizedBox(height: 30),
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: <Widget>[
  //             RoundIconButton(
  //               icon: Icons.replay_10,
  //               onPressed: () {
  //                 _chromeCastController?.seek(relative: true, interval: -10.0);
  //               },
  //             ),
  //             RoundIconButton(
  //               icon: _playingOnCasting ? Icons.pause : Icons.play_arrow,
  //               onPressed: _playPause,
  //             ),
  //             RoundIconButton(
  //               icon: Icons.forward_10,
  //               onPressed: () {
  //                 _chromeCastController?.seek(relative: true, interval: 10.0);
  //               },
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 30),
  //         Row(
  //           crossAxisAlignment: CrossAxisAlignment.center,
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             MyText(
  //               color: descTextColor,
  //               text: duration2String(position),
  //               multilanguage: false,
  //               textalign: TextAlign.center,
  //               fontsizeNormal: 15,
  //               fontsizeWeb: 17,
  //               fontweight: FontWeight.w600,
  //               maxline: 2,
  //               overflow: TextOverflow.ellipsis,
  //               fontstyle: FontStyle.normal,
  //             ),
  //             if ((duration?.inMicroseconds ?? 0) > 0) const SizedBox(width: 8),
  //             if ((duration?.inMicroseconds ?? 0) > 0)
  //               MyText(
  //                 color: descTextColor,
  //                 text: "/",
  //                 multilanguage: false,
  //                 textalign: TextAlign.center,
  //                 fontsizeNormal: 15,
  //                 fontsizeWeb: 17,
  //                 fontweight: FontWeight.w600,
  //                 maxline: 2,
  //                 overflow: TextOverflow.ellipsis,
  //                 fontstyle: FontStyle.normal,
  //               ),
  //             const SizedBox(width: 10),
  //             MyText(
  //               color: colorAccent,
  //               text: duration2String(duration),
  //               multilanguage: false,
  //               textalign: TextAlign.center,
  //               fontsizeNormal: 15,
  //               fontsizeWeb: 17,
  //               fontweight: FontWeight.w600,
  //               maxline: 2,
  //               overflow: TextOverflow.ellipsis,
  //               fontstyle: FontStyle.normal,
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }
  // Timer? _timer;
  // Future<void> _monitor() async {
  //   // monitor cast events
  //   var dur = await _chromeCastController?.duration(),
  //       pos = await _chromeCastController?.position();
  //   if (!mounted) return;
  //   if (duration == null ||
  //       (dur != null && duration!.inSeconds != dur.inSeconds)) {
  //     setState(() {
  //       duration = dur;
  //     });
  //   }
  //   if (position == null ||
  //       (pos != null && position!.inSeconds != pos.inSeconds)) {
  //     setState(() {
  //       position = pos;
  //     });
  //   }
  // }
  // void resetTimer() {
  //   _timer?.cancel();
  //   _timer = null;
  // }
  // void startTimer() {
  //   if (_timer?.isActive ?? false) {
  //     return;
  //   }
  //   resetTimer();
  //   _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
  //     _monitor();
  //   });
  // }
  // Future<void> _playPause() async {
  //   final playing = await _chromeCastController?.isPlaying();
  //   if (playing == null) return;
  //   if (playing) {
  //     await _chromeCastController?.pause();
  //   } else {
  //     await _chromeCastController?.play();
  //   }
  //   _playingOnCasting = !playing;
  //   await playerProvider.notifyProvider();
  // }
  // Future<void> _onButtonCreated(ChromeCastController controller) async {
  //   _chromeCastController = controller;
  //   await _chromeCastController?.addSessionListener();
  //   final isCastConnected = await _chromeCastController?.isConnected();
  //   final playing = await _chromeCastController?.isPlaying();
  //   printLog("_onButtonCreated isCastConnected ========> $isCastConnected");
  //   printLog("_onButtonCreated playing ================> $playing");
  //   if (isCastConnected != null &&
  //       isCastConnected &&
  //       playing != null &&
  //       playing) {
  //     setState(() => _state = AppState.idle);
  //     printLog("<======== _startNewCasting LOADING... ========>");
  //     await _chromeCastController?.loadMedia(
  //       widget.playerModel.videoUrl ?? '',
  //       title: widget.playerModel.videoTitle ?? '',
  //       image: widget.playerModel.videoThumb ?? '',
  //       live: false,
  //     );
  //     setState(() => _state = AppState.connected);
  //     printLog("<======== _startNewCasting STARTED NEXT ========>");
  //   }
  // }
  // Future<void> _onSessionStarted() async {
  //   setState(() => _state = AppState.connected);
  //   printLog("_onSessionStarted _state ======> $_state");
  //   await _chromeCastController?.loadMedia(
  //     widget.playerModel.videoUrl ?? '',
  //     title: widget.playerModel.videoTitle ?? '',
  //     image: widget.playerModel.videoThumb ?? '',
  //     live: false,
  //   );
  // }
  // Future<void> _onRequestCompleted() async {
  //   final playing = await _chromeCastController?.isPlaying();
  //   printLog("_onRequestCompleted playing ======> $playing");
  //   if (playing == null) return;
  //   final mediaInfo = await _chromeCastController?.getMediaInfo();
  //   if (!mounted) return;
  //   setState(() {
  //     _state = AppState.mediaLoaded;
  //     _playingOnCasting = playing;
  //     if (mediaInfo != null) {
  //       _mediaInfo = mediaInfo;
  //     }
  //   });
  //   printLog("_onRequestCompleted _state ======> $_state");
  // }
  // Future<void> _onRequestFailed(String? error) async {
  //   setState(() => _state = AppState.error);
  //   printLog("_onRequestFailed =======> $error");
  // }
  /* ************************************ ChromeCast END */

  Widget _buildRowIconTexts({
    required String iconName,
    required String reqText,
    required bool isForward,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!isForward)
          MyImage(
            imagePath: "$iconName.png",
            height: 45,
            width: 45,
            color: white,
          ),
        MyText(
          color: Colors.white,
          text: reqText,
          multilanguage: false,
          textalign: TextAlign.center,
          fontsizeNormal: 15,
          fontsizeWeb: 17,
          fontweight: FontWeight.w600,
          maxline: 1,
          overflow: TextOverflow.ellipsis,
          fontstyle: FontStyle.normal,
        ),
        if (isForward)
          MyImage(
            imagePath: "$iconName.png",
            height: 45,
            width: 45,
            color: white,
          ),
      ],
    );
  }

  Future<void> onBackPressed(bool didPop) async {
    if (didPop) return;
    if (!kIsWeb) {
      OrientationManager.forcePortrait();
    } else {
      _jsHelper.callBrowserFullscreen(false);
    }
    printLog("onBackPressed playerCPosition :===> $playerCPosition");
    printLog("onBackPressed videoDuration :===> $videoTotalDuration");
    printLog("onBackPressed playType :===> ${widget.playerModel.playType}");

    /* Remove Device from Watch START ********* */
    if (connectivityProvider.isOnline &&
        (widget.playerModel.playType == "Video" ||
            widget.playerModel.playType == "Show") &&
        Constant.userID != null &&
        widget.playerModel.isPremium == 1) {
      playerProvider.addRemoveDevice(2);
    }
    /* *********** Remove Device from Watch END */

    if ((widget.playerModel.playType == "Video" ||
            widget.playerModel.playType == "Show") &&
        Constant.userID != null) {
      if ((playerCPosition ?? 0) > 0) {
        /* Add to Continue */
        if (connectivityProvider.isOnline) {
          await playerProvider.addToContinue(
              "${widget.playerModel.videoId}",
              "${widget.playerModel.episodeId}",
              "${widget.playerModel.videoType}",
              "${widget.playerModel.subVideoType}",
              "$playerCPosition");
        }
        if (!mounted) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        }
      } else {
        if (!mounted) return;
        if (Navigator.canPop(context)) {
          Navigator.pop(context, false);
        }
      }
    } else {
      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context, false);
      }
    }
  }
}

class CupertinoOptionsDialog extends StatefulWidget {
  const CupertinoOptionsDialog({
    super.key,
    required this.options,
    this.cancelButtonText,
  });

  final List<OptionItem> options;
  final String? cancelButtonText;

  @override
  State<CupertinoOptionsDialog> createState() => _CupertinoOptionsDialogState();
}

class _CupertinoOptionsDialogState extends State<CupertinoOptionsDialog> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CupertinoActionSheet(
        actions: widget.options
            .map(
              (option) => CupertinoActionSheetAction(
                onPressed: () => option.onTap(context),
                child: Text(option.title),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDestructiveAction: true,
          child: Text(widget.cancelButtonText ?? 'Cancel'),
        ),
      ),
    );
  }
}

class _PlaybackSpeedDialog extends StatelessWidget {
  const _PlaybackSpeedDialog({
    required List<double> speeds,
    required double selected,
  })  : _speeds = speeds,
        _selected = selected;

  final List<double> _speeds;
  final double _selected;

  @override
  Widget build(BuildContext context) {
    final selectedColor = CupertinoTheme.of(context).primaryColor;

    return CupertinoActionSheet(
      actions: _speeds
          .map(
            (e) => CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop(e);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (e == _selected)
                    Icon(Icons.check, size: 20.0, color: selectedColor),
                  Text(e.toString()),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class CenterSeekButtonNew extends StatelessWidget {
  const CenterSeekButtonNew({
    super.key,
    required this.iconName,
    this.iconColor,
    required this.show,
    this.fadeDuration = const Duration(milliseconds: 300),
    this.iconSize = 26,
    this.onPressed,
  });

  final String iconName;
  final bool show;
  final Color? iconColor;
  final VoidCallback? onPressed;
  final Duration fadeDuration;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Center(
        child: UnconstrainedBox(
          child: AnimatedOpacity(
            opacity: show ? 1.0 : 0.0,
            duration: fadeDuration,
            child: InkWell(
              onTap: onPressed,
              child: Container(
                padding: const EdgeInsets.all(3),
                child: MyImage(
                  imagePath: "$iconName.png",
                  height: 45,
                  width: 45,
                  color: white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      padding: const EdgeInsets.all(16.0),
      color: colorPrimary,
      shape: const CircleBorder(),
      onPressed: onPressed,
      child: Icon(icon, color: black),
    );
  }
}

enum AppState { idle, connected, mediaLoaded, error }

class MyWebVTTCaptionFile extends ClosedCaptionFile {
  MyWebVTTCaptionFile(this.captions);

  @override
  List<Caption> captions = [];
}
