import 'dart:async';
import '../utils/loadingoverlay.dart';
import '../widget/mynetworkimg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:simple_shadow/simple_shadow.dart';
import 'package:video_player/video_player.dart';

import '../model/sharemodel.dart';
import '../model/clipepisodesmodel.dart' as shortsepisode;
import '../model/contentdetailmodel.dart' as details;
import '../provider/clipsprovider.dart';
import '../routes/routes_constant.dart';
import '../shimmer/shimmerutils.dart';
import '../utils/color.dart';
import '../utils/dimens.dart';
import '../utils/utils.dart';
import '../widget/centerplaybutton.dart';
import '../widget/muteunmutebutton.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';

String duration2String(Duration? dur) {
  final duration = dur ?? Duration.zero;

  if (duration.inSeconds <= 0) return "00:00";

  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;

  return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
}

class ClipsEpisodes extends StatefulWidget {
  final int videoId, subVideoType, videoType, typeId;
  const ClipsEpisodes({
    required this.videoId,
    required this.subVideoType,
    required this.videoType,
    required this.typeId,
    super.key,
  });

  @override
  State<ClipsEpisodes> createState() => _ClipsEpisodesState();
}

class _ClipsEpisodesState extends State<ClipsEpisodes> {
  late ClipsProvider clipsProvider;

  final PageController _pageController = PageController();
  Map<int, VideoPlayerController> _controllers = {};
  late ValueNotifier<int> _current;
  final int _preloadCount = 4;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    clipsProvider = Provider.of<ClipsProvider>(context, listen: false);
    _current = ValueNotifier<int>(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData();
    });
  }

  Future _getData() async {
    await clipsProvider.getShortsDetails(
        widget.typeId, widget.videoType, widget.videoId, widget.subVideoType,
        forceRefresh: true);

    if (clipsProvider.contentDetailModel.result != null &&
        (clipsProvider.contentDetailModel.result?.length ?? 0) > 0 &&
        clipsProvider.contentDetailModel.result?[0].season != null &&
        (clipsProvider.contentDetailModel.result?[0].season?.length ?? 0) > 0) {
      await _getAllEpisodes(0);
      _preLoadEpisodes();
    }

    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future _getAllEpisodes(int seasonPos) async {
    printLog("_getAllEpisodes seasonPos ======> $seasonPos");
    await clipsProvider.setSeason(seasonPos);
    await clipsProvider.getEpisodesBySeason(
        widget.videoId,
        clipsProvider.contentDetailModel.result?[0].season?[seasonPos].id ?? 0,
        1,
        forceRefresh: true);
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _preLoadEpisodes() async {
    printLog(
        "_preLoadEpisodes shortFilmEpisodeModel ====> ${clipsProvider.shortFilmEpisodeModel.result?.length}");
    if (clipsProvider.shortFilmEpisodeModel.result != null &&
        (clipsProvider.shortFilmEpisodeModel.result?.length ?? 0) > 0) {
      _prepare(0);
      for (int i = 1; i <= _preloadCount; i++) {
        _prepare(i);
      }
    }
  }

  Future<void> _prepare(int index) async {
    if (index < 0 ||
        index >= (clipsProvider.shortFilmEpisodeModel.result?.length ?? 0)) {
      return;
    }
    if (_controllers.containsKey(index)) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(
          clipsProvider.shortFilmEpisodeModel.result?[index].video320 ?? ""),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );
    _controllers[index] = controller;

    unawaited(() async {
      try {
        await controller.initialize();
        controller.setLooping(true);

        if (_current.value == index) {
          if (_checkPremium(index)) {
            await controller.pause();
          } else {
            await controller.play();
          }
          Future.delayed(Duration.zero).then((value) {
            if (!mounted) return;
            setState(() {});
          });
        } else {
          await controller.seekTo(Duration.zero);
          await controller.play();
          await Future.delayed(const Duration(milliseconds: 150));
          await controller.pause();
        }
      } catch (e, s) {
        printLog("_prepare Video error at index = $index : $e\n$s");
      }
    }());
  }

  void _onPageChanged(int index) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: transparent,
        systemNavigationBarColor: secondaryBgColor,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      _current.value = index;

      for (final entry in _controllers.entries) {
        final i = entry.key;
        final c = entry.value;
        if (!c.value.isInitialized) continue;

        if (i == index) {
          if (_checkPremium(index)) {
            c.pause();
          } else {
            c.play();
          }
        } else {
          // Pause others (rewind asynchronously so it doesn’t block UI)
          c.pause();
          unawaited(c.seekTo(Duration.zero));
        }
      }

      // Preload neighbors
      for (int off = -_preloadCount; off <= _preloadCount; off++) {
        if (off == 0) continue;
        _prepare(index + off);
      }

      // Dispose far controllers
      _controllers.keys
          .where((i) => (i - index).abs() > _preloadCount)
          .toList()
          .forEach((i) {
        _controllers[i]?.dispose();
        _controllers.remove(i);
      });
    });
  }

  bool _checkPremium(int index) {
    return clipsProvider.shortFilmEpisodeModel.result?[index].isPremium == 1 &&
        clipsProvider.shortFilmEpisodeModel.result?[index].isBuy != 1;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _current.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<int>(
        valueListenable: _current,
        builder: (context, current, _) {
          if (clipsProvider.isEpiLoading && !clipsProvider.loadMore) {
            return ShimmerUtils.buildClipsEpisodeShimmer(context);
          }
          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: clipsProvider.shortFilmEpisodeModel.result?.length ?? 0,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final controller = _controllers[index];
              if (controller == null || !controller.value.isInitialized) {
                return ShimmerUtils.buildClipsEpisodeShimmer(context);
              }
              return Consumer<ClipsProvider>(
                builder: (context, clipsProvider, child) {
                  return _EpisodePlayer(
                    controller: controller,
                    isCurrent: (current == index),
                    vIndex: index,
                    pageController: _pageController,
                    seasonList:
                        clipsProvider.contentDetailModel.result?[0].season ??
                            [],
                    episodeList:
                        clipsProvider.shortFilmEpisodeModel.result ?? [],
                    onVideoEnd: () {
                      printLog("ShortsPlayer Auto-scroll triggered for $index");
                      if (index + 1 <
                          (clipsProvider.shortFilmEpisodeModel.result?.length ??
                              0)) {
                        _pageController.animateToPage(
                          index + 1,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                        );
                      }
                    },
                    onSeasonChange: (int mCurrentPage) async {
                      printLog(
                          "onSeasonChange mCurrentPage =====> $mCurrentPage");
                      printLog(
                          "onSeasonChange seasonPos => ${clipsProvider.seasonPos}");
                      _onSeasonChange(
                        mCurrentPage: mCurrentPage,
                        vController: controller,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _onSeasonChange({
    required int mCurrentPage,
    required VideoPlayerController vController,
  }) async {
    if (clipsProvider.seasonPos == mCurrentPage) return;
    printLog(
        "onSeasonChange SeasonID ====> ${(clipsProvider.contentDetailModel.result?[0].season?[mCurrentPage].id ?? 0)}");
    LoadingOverlay().show(context);
    if (vController.value.isPlaying) {
      vController.pause();
    }
    clipsProvider.setEpiLoading(true);
    await clipsProvider.setSeason(mCurrentPage);
    printLog("onSeasonChange seasonPos =2=> ${clipsProvider.seasonPos}");
    await clipsProvider.getEpisodesBySeason(
        clipsProvider.contentDetailModel.result?[0].id ?? 0,
        clipsProvider.contentDetailModel.result?[0].season?[mCurrentPage].id ??
            0,
        1,
        forceRefresh: true);
    _controllers.clear();
    _controllers = {};
    _current = ValueNotifier<int>(0);
    _pageController.jumpToPage(0);
    await _preLoadEpisodes();
    LoadingOverlay().hide();
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    printLog("onSeasonChange CHANGED!!!");
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }
}

/// Single reel widget
class _EpisodePlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final PageController pageController;
  final bool isCurrent;
  final int vIndex;
  final List<details.Season> seasonList;
  final List<shortsepisode.Result> episodeList;
  final VoidCallback? onVideoEnd;
  final void Function(int index) onSeasonChange;
  const _EpisodePlayer({
    required this.controller,
    required this.pageController,
    required this.isCurrent,
    required this.vIndex,
    required this.seasonList,
    required this.episodeList,
    this.onVideoEnd,
    required this.onSeasonChange,
  });

  @override
  State<_EpisodePlayer> createState() => _EpisodePlayerState();
}

class _EpisodePlayerState extends State<_EpisodePlayer>
    with TickerProviderStateMixin {
  late ClipsProvider clipsProvider;

  Timer? _hideTimer;
  bool _showPlayPause = true;
  bool _showControls = true;
  bool _isVideoStarted = false;

  bool _hasSignalledEnd = false;

  int _speedIndex = 1; // start at 1.0x (index 1)
  final List<double> _playbackSpeeds = [0.5, 1.0, 1.5, 2.0];

  // Track mute state per index
  final ValueNotifier<Map<int, bool?>> _muteStatesNotifier = ValueNotifier({});

  Future<void> toggleMute(int index) async {
    final currentStates = Map<int, bool>.from(_muteStatesNotifier.value);
    currentStates[index] = !(currentStates[index] ?? false); // default false
    _muteStatesNotifier.value = currentStates;
    final isMuted = currentStates[index] ?? false;
    widget.controller.setVolume(isMuted ? 0.0 : 1.0);
  }

  void _changeSpeed() {
    setState(() {
      // move to next index, loop back to 0
      _speedIndex = (_speedIndex + 1) % _playbackSpeeds.length;
    });

    final newSpeed = _playbackSpeeds[_speedIndex];
    widget.controller.setPlaybackSpeed(newSpeed);
  }

  Future<void> _togglePlayPause() async {
    printLog("_togglePlayPause _showPlayPause ====> $_showPlayPause");
    printLog("_togglePlayPause _isVideoStarted ===> $_isVideoStarted");
    _showPlayPause = !_showPlayPause;
    _isVideoStarted = (widget.controller.value.isPlaying);
    if (!mounted) return;
    if (_showPlayPause) _startHideTimer();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleControls() async {
    printLog("_toggleControls _showControls =====> $_showPlayPause");
    printLog("_toggleControls _isVideoStarted ===> $_isVideoStarted");
    _showControls = !_showControls;
    if (!mounted) return;
    setState(() {});
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();

    if (!mounted) return;
    _showPlayPause = true;
    _isVideoStarted = (widget.controller.value.isPlaying);

    if (!mounted) return;
    // _startHideTimer();
  }

  Future<void> _startHideTimer() async {
    printLog("_startHideTimer _showPlayPause ====> $_showPlayPause");
    printLog("_startHideTimer _isVideoStarted ===> $_isVideoStarted");
    if (_hideTimer != null) {
      _hideTimer?.cancel();
    }
    _hideTimer = Timer(const Duration(seconds: 5), () async {
      _showPlayPause = false;
      _isVideoStarted = (widget.controller.value.isPlaying);
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    clipsProvider = Provider.of<ClipsProvider>(context, listen: false);

    // Listen for video completion
    widget.controller.addListener(_videoListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Utils.deleteCacheDir();
      _togglePlayPause();
      _addViewAPI();
    });
  }

  Future<void> _addViewAPI() async {
    clipsProvider.addViewCount(
        clipsProvider.contentDetailModel.result?[0].id ?? 0,
        clipsProvider.contentDetailModel.result?[0].videoType ?? 0,
        widget.episodeList[widget.vIndex].id ?? 0);
  }

  @override
  void didUpdateWidget(covariant _EpisodePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If controller instance changed, move listener
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_videoListener);
      widget.controller.addListener(_videoListener);

      // reset signalling state for new controller
      _hasSignalledEnd = false;
    }
  }

  void _videoListener() {
    final c = widget.controller;
    if (!c.value.isInitialized) return;

    final pos = c.value.position;
    final dur = c.value.duration;

    if (dur.inMilliseconds == 0) return;

    // tolerance to allow floating/time drift
    final tolerance = const Duration(milliseconds: 200);

    // If we are the current visible page, and position reaches (duration - tolerance),
    // and we haven't already signalled end, trigger onVideoEnd.
    if (widget.isCurrent && !_hasSignalledEnd && pos >= dur - tolerance) {
      _hasSignalledEnd = true;

      final total = clipsProvider.shortFilmEpisodeModel.result?.length ?? 0;
      final nextIndex = widget.vIndex + 1;
      printLog(
          "ShortsPlayer: end detected (pos=$pos dur=$dur) (totalEpi=$total) (nextIndex=$nextIndex) index=${widget.vIndex} DialogState=${clipsProvider.isDialogOpen}");

      if (nextIndex < total) {
        if (!clipsProvider.isDialogOpen) {
          widget.onVideoEnd?.call();
        }
      } else {
        // Last video: stop
        c.pause();
        _showControls = true;
        _isVideoStarted = (widget.controller.value.isPlaying);
        if (!mounted) return;
        setState(() {});
        printLog("Reached last video, playback stopped.");
      }

      return;
    }

    // If position moves away from near-end (e.g. user rewound or restarted),
    // clear the flag so end can be signalled later again.
    if (pos < dur - tolerance && _hasSignalledEnd) {
      _hasSignalledEnd = false;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  bool _checkPremium() {
    return widget.episodeList[widget.vIndex].isPremium == 1 &&
        widget.episodeList[widget.vIndex].isBuy != 1;
  }

  bool _isFreeORBuy() {
    return widget.episodeList[widget.vIndex].isPremium == 0 ||
        widget.episodeList[widget.vIndex].isBuy == 1;
  }

  @override
  Widget build(BuildContext context) {
    final vCont = widget.controller;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_checkPremium())
          _buildSubscribeView(index: widget.vIndex)
        else
          GestureDetector(
            onTap: () {
              _isVideoStarted ? vCont.pause() : vCont.play();
              if (!mounted) return;
              _togglePlayPause();
            },
            child: ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: vCont,
              builder: (context, cValue, _) {
                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: cValue.size.width,
                      height: cValue.size.height,
                      child: VideoPlayer(vCont),
                    ),
                  ),
                );
              },
            ),
          ),

        if (_isFreeORBuy()) Center(child: _buildHitArea()),

        // Overlays: progress + icons
        Column(
          children: [
            const Spacer(),
            if (_showControls) _buildEpisodeDetails(index: widget.vIndex),
            SizedBox(height: 8),
            if (_showControls && _isFreeORBuy())
              Container(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: vCont,
                  builder: (context, val, _) {
                    final dur = val.duration.inMilliseconds;
                    final pos = val.position.inMilliseconds;
                    final prog = dur > 0 ? pos / dur : 0.0;
                    return SizedBox(
                      height: 5,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4,
                            pressedElevation: 0,
                          ),
                          overlayShape:
                              const RoundSliderOverlayShape(overlayRadius: 0),
                          trackShape: const RoundedRectSliderTrackShape(),
                          minThumbSeparation: 0,
                          showValueIndicator: ShowValueIndicator.never,
                        ),
                        child: Slider(
                          value: prog.clamp(0, 1),
                          onChanged: (v) => vCont.seekTo(val.duration * v),
                          activeColor: colorPrimary,
                          inactiveColor: Colors.white30,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (_showControls && _isFreeORBuy()) _buildBottomBar(),
          ],
        ),

        //AppBar
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          child: SafeArea(child: _buildAppBar()),
        ),
      ],
    );
  }

  Widget _buildSubscribeView({required int index}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: MyNetworkImage(
                  imageUrl: widget.episodeList[widget.vIndex].thumbnail ?? "",
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                decoration:
                    Utils.setBackground(black.withValues(alpha: 0.6), 0),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /* Lock */
                MyImage(
                  imagePath: 'ic_lock.png',
                  height: 30,
                  width: 30,
                ),
                /* Subscription Button */
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () async {
                      await Utils.openSubscription(
                          context: context, oldPage: "");
                    },
                    child: FittedBox(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 0),
                        decoration: Utils.setGradTTBBGWithBorder(
                            colorPrimaryDark, colorPrimary, transparent, 30, 0),
                        alignment: Alignment.center,
                        child: MyText(
                          color: white,
                          text: "subscribe_now",
                          multilanguage: true,
                          textalign: TextAlign.center,
                          fontsizeNormal: 14,
                          fontweight: FontWeight.w600,
                          fontsizeWeb: 15,
                          maxline: 1,
                          overflow: TextOverflow.ellipsis,
                          fontstyle: FontStyle.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      height: kToolbarHeight,
      padding: EdgeInsets.fromLTRB(4, 0, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              if (!_showControls) return;
              if (kIsWeb) {
                if (context.canPop()) {
                  context.pop();
                }
              } else {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            },
            child: Container(
              height: 40,
              width: 40,
              padding: EdgeInsets.all(12),
              child: (!_showControls)
                  ? SizedBox.shrink()
                  : SimpleShadow(
                      color: black.withValues(alpha: 0.5),
                      sigma: 2,
                      child: MyImage(
                        imagePath: "back.png",
                        fit: BoxFit.contain,
                        color: white,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: (!_showControls)
                ? SizedBox.shrink()
                : Container(
                    margin: EdgeInsets.fromLTRB(5, 0, 17, 0),
                    alignment: Alignment.centerLeft,
                    child: MyText(
                      text: widget.episodeList[widget.vIndex].name ?? "",
                      multilanguage: false,
                      fontsizeNormal: 16,
                      fontsizeWeb: 18,
                      maxline: 1,
                      overflow: TextOverflow.ellipsis,
                      fontstyle: FontStyle.normal,
                      fontweight: FontWeight.w600,
                      textalign: TextAlign.start,
                      color: titleTextColor,
                      isShadowText: true,
                    ),
                  ),
          ),
          SizedBox(width: 15),
          /* Mute/Unmute */
          if (_showControls)
            MuteUnmuteButton(
              index: widget.vIndex,
              toggleMute: toggleMute,
              muteStatesNotifier: _muteStatesNotifier,
            ),
          if (_showControls) SizedBox(width: 8),
          InkWell(
            onTap: () {
              _toggleControls();
              if (!_showControls) {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                    overlays: []);
              } else {
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
                    overlays: SystemUiOverlay.values);
                SystemChrome.setSystemUIOverlayStyle(
                  const SystemUiOverlayStyle(
                    statusBarColor: transparent,
                    systemNavigationBarColor: secondaryBgColor,
                    statusBarBrightness: Brightness.light,
                    statusBarIconBrightness: Brightness.light,
                  ),
                );
              }
            },
            child: Container(
              height: 40,
              width: 40,
              padding: EdgeInsets.all(3),
              alignment: Alignment.center,
              decoration: Utils.setBackground(
                  descTextColor.withValues(alpha: 0.75), 25),
              child: SimpleShadow(
                color: black.withValues(alpha: 0.5),
                sigma: 2,
                child: MyImage(
                  height: _showControls ? 25 : 20,
                  width: _showControls ? 25 : 20,
                  imagePath: _showControls
                      ? "ic_screen_default.png"
                      : "ic_screen_full.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHitArea() {
    final c = widget.controller;
    final bool isFinished = (c.value.position >= c.value.duration) &&
        c.value.duration.inSeconds > 0;
    _isVideoStarted = (c.value.isPlaying);
    return Container(
      height: 70,
      width: 70,
      color: Colors.transparent,
      child: Tooltip(
        message: 'Play/Pause',
        child: CenterPlayButton(
          backgroundColor: Colors.black26,
          iconColor: Colors.white,
          isFinished: isFinished,
          isPlaying: _isVideoStarted,
          show: _showPlayPause,
          onPressed: () async {
            if (_checkPremium()) return;
            _isVideoStarted ? c.pause() : c.play();
            if (!mounted) return;
            setState(() {});
            printLog("Play/Pause _isVideoStarted ==> $_isVideoStarted");
            printLog("Play/Pause isPlaying ========> ${c.value.isPlaying}");
            if (c.value.isPlaying == false) {
              _cancelAndRestartTimer();
            } else {
              _startHideTimer();
            }
          },
        ),
      ),
    );
  }

  Widget _buildEpisodeDetails({required int index}) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 0, 0, 0),
      constraints: BoxConstraints(
        minHeight: 0,
        minWidth: 0,
        maxWidth: MediaQuery.of(context).size.width,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: SizedBox()),
          const SizedBox(width: 15),
          /* Feature Buttons */
          _buildFeatureBtns(index),
        ],
      ),
    );
  }

  Widget _buildFeatureBtns(int index) {
    return Builder(builder: (context) {
      return Container(
        padding: EdgeInsets.only(right: 12),
        constraints: const BoxConstraints(minWidth: 45),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /* View */
            _buildFeatureIcon(
              iconName: "ic_eye",
              index: index,
              isTitle: false,
              count: (widget.episodeList[index].totalView ?? 0).toString(),
              onClick: () {},
            ),

            /* Episodes */
            _buildFeatureIcon(
              iconName: "ic_episodes",
              index: index,
              isTitle: true,
              count: "episodes",
              onClick: () async {
                printLog("Tapped on Episodes! => $index");
                clipsProvider.setDialogState(true);
                _showAllEpisodeDialog();
              },
            ),

            /* Share */
            _buildFeatureIcon(
              iconName: 'ic_send',
              index: index,
              count: "share",
              isTitle: true,
              onClick: () async {
                printLog("Tapped on Share! => $index");
                ShareModel shareModel = ShareModel(
                  newPage: RoutesConstant.clipsEpisodesPage,
                  videoTitle:
                      clipsProvider.contentDetailModel.result?[0].name ?? "",
                  videoId: clipsProvider.contentDetailModel.result?[0].id ?? 0,
                  videoType:
                      clipsProvider.contentDetailModel.result?[0].videoType ??
                          0,
                  subVideoType: clipsProvider
                          .contentDetailModel.result?[0].subVideoType ??
                      0,
                  typeId:
                      clipsProvider.contentDetailModel.result?[0].typeId ?? 0,
                );
                Utils.openShareDialog(
                  context: context,
                  shareModel: shareModel,
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFeatureIcon({
    required String iconName,
    required int index,
    required String count,
    required bool isTitle,
    required Function() onClick,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 35,
          height: 35,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: onClick,
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.all(3),
                child: SimpleShadow(
                  color: black.withValues(alpha: 0.5),
                  sigma: 2,
                  child: MyImage(
                    imagePath: "$iconName.png",
                    fit: BoxFit.contain,
                    color: (iconName == "ic_heartfill")
                        ? colorPrimary
                        : titleTextColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (count.isNotEmpty && !isTitle)
          MyText(
            color: titleTextColor,
            text: Utils.withSuffix(int.tryParse(count) ?? 0),
            fontsizeNormal: 12,
            fontsizeWeb: 14,
            fontweight: FontWeight.w500,
            maxline: 1,
            overflow: TextOverflow.ellipsis,
            textalign: TextAlign.center,
            fontstyle: FontStyle.normal,
            isShadowText: true,
          )
        else if (isTitle)
          MyText(
            color: titleTextColor,
            text: count,
            multilanguage: true,
            fontsizeNormal: 12,
            fontsizeWeb: 14,
            fontweight: FontWeight.w500,
            maxline: 1,
            overflow: TextOverflow.ellipsis,
            textalign: TextAlign.center,
            fontstyle: FontStyle.normal,
            isShadowText: true,
          ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildBottomBar() {
    final c = widget.controller;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        return Container(
          padding: EdgeInsets.fromLTRB(20, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MyText(
                color: Colors.white,
                text: duration2String(value.position),
                multilanguage: false,
                textalign: TextAlign.center,
                fontsizeNormal: 14,
                fontsizeWeb: 16,
                fontweight: FontWeight.w500,
                maxline: 1,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
                isShadowText: true,
              ),
              MyText(
                color: Colors.white,
                text: " / ",
                multilanguage: false,
                textalign: TextAlign.center,
                fontsizeNormal: 15,
                fontsizeWeb: 17,
                fontweight: FontWeight.w600,
                maxline: 2,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
                isShadowText: true,
              ),
              MyText(
                color: Colors.white,
                text: duration2String(value.duration),
                multilanguage: false,
                textalign: TextAlign.center,
                fontsizeNormal: 14,
                fontsizeWeb: 16,
                fontweight: FontWeight.w500,
                maxline: 1,
                overflow: TextOverflow.ellipsis,
                fontstyle: FontStyle.normal,
                isShadowText: true,
              ),
              Spacer(),
              Tooltip(
                message: 'Playback Speed',
                child: _buildSpeedButton(),
              ),
            ],
          ),
        );
      },
    );
  }

  GestureDetector _buildSpeedButton() {
    return GestureDetector(
      onTap: _changeSpeed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MyText(
            color: Colors.white,
            text: "${_playbackSpeeds[_speedIndex]}x",
            multilanguage: false,
            textalign: TextAlign.center,
            fontsizeNormal: 14,
            fontsizeWeb: 16,
            fontweight: FontWeight.w500,
            maxline: 1,
            overflow: TextOverflow.ellipsis,
            fontstyle: FontStyle.normal,
          ),
          Container(
            height: 47.0,
            color: Colors.transparent,
            padding: const EdgeInsets.only(left: 6, right: 8),
            margin: const EdgeInsets.only(right: 8),
            child: Icon(
              Icons.speed,
              color: Colors.white,
              size: 25,
            ),
          ),
        ],
      ),
    );
  }

  void _showAllEpisodeDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: secondaryBgColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            _buildEpiDialogItems(),
          ],
        );
      },
    ).whenComplete(() {
      clipsProvider.setDialogState(false);
      if (!mounted) return;
      setState(() {});
    });
  }

  Widget _buildEpiDialogItems() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(15, 15, 15, 0),
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /* Title */
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: MyText(
                    color: titleTextColor,
                    text: "episodes",
                    multilanguage: true,
                    textalign: TextAlign.start,
                    fontsizeNormal: 17,
                    fontweight: FontWeight.w600,
                    fontsizeWeb: 19,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    fontstyle: FontStyle.normal,
                  ),
                ),
              ),
              SizedBox(width: 15),
              Utils.buildCloseBtn(context),
            ],
          ),
        ),
        Container(
          alignment: Alignment.centerLeft,
          child: _buildSeasonBtn(),
        ),
        Container(
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
          height: 0.5,
          decoration:
              Utils.setBackground(descTextColor.withValues(alpha: 0.6), 0),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.55,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            child: AlignedGridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              itemCount: widget.episodeList.length,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 15),
              scrollDirection: Axis.vertical,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int position) {
                return Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                      widget.pageController.jumpToPage(position);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: Dimens.widthEpi,
                            height: Dimens.heightEpi,
                            alignment: Alignment.center,
                            child: MyNetworkImage(
                              imageUrl:
                                  widget.episodeList[position].thumbnail ?? "",
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (position != 0)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: Dimens.widthEpi,
                                height: Dimens.heightEpi,
                                alignment: Alignment.center,
                                decoration: Utils.setBackground(
                                    black.withValues(alpha: 0.4), 8),
                              ),
                            ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              height: 20,
                              width: 20,
                              decoration: BoxDecoration(
                                color: colorPrimary,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                shape: BoxShape.rectangle,
                              ),
                              alignment: Alignment.center,
                              child: MyText(
                                color: black,
                                text: "${position + 1}",
                                multilanguage: false,
                                textalign: TextAlign.center,
                                fontsizeNormal: 12,
                                fontweight: FontWeight.w600,
                                fontsizeWeb: 14,
                                maxline: 1,
                                overflow: TextOverflow.ellipsis,
                                fontstyle: FontStyle.normal,
                              ),
                            ),
                          ),
                          if (widget.episodeList[position].isPremium == 1 &&
                              widget.episodeList[position].isBuy != 1)
                            Container(
                              height: 30,
                              width: 30,
                              alignment: Alignment.center,
                              child: MyImage(
                                imagePath: "ic_lock.png",
                                fit: BoxFit.contain,
                              ),
                            )
                          else if (widget.vIndex == position)
                            Container(
                              height: 30,
                              width: 30,
                              alignment: Alignment.center,
                              child: MyImage(
                                imagePath: "ic_wave.png",
                                fit: BoxFit.contain,
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
      ],
    );
  }

  Widget _buildSeasonBtn() {
    return Consumer<ClipsProvider>(
      builder: (context, clipsProvider, child) {
        if (clipsProvider.contentDetailModel.result?[0].season != null &&
            (clipsProvider.contentDetailModel.result?[0].season?.length ?? 0) >
                0) {
          return Container(
            height: 50,
            margin: EdgeInsets.fromLTRB(
              Dimens.isBigScreen(context) ? 35 : 12,
              Dimens.isBigScreen(context) ? 10 : 8,
              Dimens.isBigScreen(context) ? 35 : 12,
              0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
              child: AlignedGridView.count(
                shrinkWrap: true,
                crossAxisCount: 1,
                crossAxisSpacing: 0,
                mainAxisSpacing: 10,
                itemCount: clipsProvider
                        .contentDetailModel.result?[0].season?.length ??
                    0,
                scrollDirection: Axis.horizontal,
                itemBuilder: (BuildContext context, int index) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          child: InkWell(
                            onTap: () {
                              widget.onSeasonChange(index);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              alignment: Alignment.center,
                              child: MyText(
                                color: (index == clipsProvider.seasonPos)
                                    ? titleTextColor
                                    : descTextColor,
                                text: clipsProvider.contentDetailModel
                                        .result?[0].season?[index].name ??
                                    "-",
                                fontsizeNormal: 13,
                                fontsizeWeb: 15,
                                fontstyle: FontStyle.normal,
                                fontweight: FontWeight.w600,
                                multilanguage: false,
                                maxline: 1,
                                overflow: TextOverflow.ellipsis,
                                textalign: TextAlign.start,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 2,
                        constraints: const BoxConstraints(minWidth: 50),
                        decoration: Utils.setBackground(
                            (index == clipsProvider.seasonPos)
                                ? colorPrimary
                                : transparent,
                            2),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
