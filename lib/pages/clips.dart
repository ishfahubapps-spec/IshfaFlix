import 'dart:async';
import 'dart:math';
import '../model/clipsmodel.dart' as clips;
import '../pages/clipsepisodes.dart';
import '../shimmer/shimmerutils.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_locales/flutter_locales.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:simple_shadow/simple_shadow.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';
import '../model/commentmodel.dart';
import '../model/sharemodel.dart';
import '../provider/clipsprovider.dart';
import '../routes/routes_constant.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../utils/utils.dart';
import '../widget/centerplaybutton.dart';
import '../widget/muteunmutebutton.dart';
import '../widget/myimage.dart';
import '../widget/mynetworkimg.dart';
import '../widget/mytext.dart';
import '../widget/nodata.dart';

class Clips extends StatefulWidget {
  final int clipId;
  final String openFrom;
  const Clips({
    required this.clipId,
    required this.openFrom,
    super.key,
  });

  @override
  State<Clips> createState() => _ClipsState();
}

class _ClipsState extends State<Clips> {
  late ClipsProvider clipsProvider;

  final PageController _pageController = PageController();
  final Map<int, VideoPlayerController> _controllers = {};
  late final ValueNotifier<int> _current;
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
    printLog("_getData clipId =====> ${widget.clipId}");
    await clipsProvider.getAllShorts(widget.clipId, 1, forceRefresh: true);

    if (clipsProvider.shortFilmsList != null &&
        (clipsProvider.shortFilmsList?.length ?? 0) > 0) {
      printLog(
          "_getData trailerUrl =====> ${clipsProvider.shortFilmsList?[0].trailerUrl}");
    }
    _prepare(0);
    for (int i = 1; i <= _preloadCount; i++) {
      _prepare(i);
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _fetchNewData(int? nextPage) async {
    if (clipsProvider.isMorePage == false) return;
    printLog("_fetchNewData nextPage  ========> $nextPage");
    printLog("_fetchNewData isMorePage  ======> ${clipsProvider.isMorePage}");
    printLog("_fetchNewData currentPage ======> ${clipsProvider.currentPage}");
    printLog("_fetchNewData totalPage   ======> ${clipsProvider.totalPage}");

    await clipsProvider.getAllShorts(widget.clipId, (nextPage ?? 0) + 1,
        forceRefresh: true);
    printLog(
        "_fetchNewData detailsList ======> ${clipsProvider.shortFilmsList?.length}");

    final startIndex =
        (clipsProvider.shortFilmsList?.length ?? 0) - _preloadCount;

    for (int i = startIndex;
        i < (clipsProvider.shortFilmsList?.length ?? 0);
        i++) {
      _prepare(i);
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _prepare(int index) async {
    if (index < 0 || index >= (clipsProvider.shortFilmsList?.length ?? 0)) {
      return;
    }
    if (_controllers.containsKey(index)) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(clipsProvider.shortFilmsList?[index].trailerUrl ?? ""),
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
          await controller.play();
          if (!mounted) return;
          setState(() {});
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
    final total = clipsProvider.shortFilmsList?.length ?? 0;

    // If near the end (e.g., last 2 items), fetch more
    if (index >= total - 2) {
      _fetchNewData(clipsProvider.currentPage ?? 1);
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () {
      _current.value = index;

      for (final entry in _controllers.entries) {
        final i = entry.key;
        final c = entry.value;
        if (!c.value.isInitialized) continue;

        if (i == index) {
          c.play();
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
          if (clipsProvider.isLoading && !clipsProvider.loadMore) {
            return ShimmerUtils.buildClipsShimmer(
                context, widget.openFrom == "bottom");
          }
          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: clipsProvider.shortFilmsList?.length ?? 0,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final controller = _controllers[index];
                  printLog(
                      "current ====> $current && isInitialized =====> ${controller?.value.isInitialized}");
                  if (controller == null || !controller.value.isInitialized) {
                    return ShimmerUtils.buildClipsShimmer(
                        context, widget.openFrom == "bottom");
                  }
                  return _ShortsPlayer(
                    widget.clipId,
                    widget.openFrom,
                    controller: controller,
                    isCurrent: _current.value == index,
                    vIndex: index,
                    reelsList: clipsProvider.shortFilmsList ?? [],
                    onVideoEnd: () {
                      printLog("ShortsPlayer Auto-scroll triggered for $index");
                      if (index + 1 <
                          (clipsProvider.shortFilmsList?.length ?? 0)) {
                        _pageController.animateToPage(
                          index + 1,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutCubic,
                        );
                      }
                    },
                  );
                },
              ),
              //AppBar
              Positioned(
                top: 0,
                right: 0,
                left: 0,
                child: SafeArea(child: _buildAppBar(current)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(int position) {
    if (widget.openFrom == "bottom") {
      return SizedBox.shrink();
    }
    return Consumer<ClipsProvider>(
      builder: (context, clipsProvider, child) {
        return Container(
          height: kToolbarHeight,
          padding: EdgeInsets.fromLTRB(4, 0, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
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
                  child: SimpleShadow(
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
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  child: MyText(
                    text: (clipsProvider.shortFilmsList != null &&
                            (clipsProvider.shortFilmsList?.length ?? 0) > 0)
                        ? (clipsProvider.shortFilmsList?[position].name ?? "")
                        : "",
                    multilanguage: false,
                    fontsizeNormal: 16,
                    fontsizeWeb: 18,
                    maxline: 1,
                    fontstyle: FontStyle.normal,
                    fontweight: FontWeight.w600,
                    textalign: TextAlign.start,
                    color: titleTextColor,
                    isShadowText: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Single Player widget
class _ShortsPlayer extends StatefulWidget {
  final String openFrom;
  final int clipId;
  final VideoPlayerController controller;
  final bool isCurrent;
  final int vIndex;
  final List<clips.Result> reelsList;
  final VoidCallback? onVideoEnd;
  const _ShortsPlayer(
    this.clipId,
    this.openFrom, {
    required this.controller,
    required this.isCurrent,
    required this.vIndex,
    required this.reelsList,
    this.onVideoEnd,
  });

  @override
  State<_ShortsPlayer> createState() => _ShortsPlayerState();
}

class _ShortsPlayerState extends State<_ShortsPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late ClipsProvider clipsProvider;

  TextEditingController commentController = TextEditingController();
  TextEditingController editCommentController = TextEditingController();

  late AnimationController _heartController;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  /* Like Icon(Heart) colors */
  bool _hasSignalledEnd = false;
  Color _heartColor = colorPrimary;
  final List<Color> _colors = [
    colorPrimary,
    colorPrimaryDark,
    colorAccent,
    complimentryColor,
    white,
  ];

  // Track mute state per index
  final ValueNotifier<Map<int, bool?>> _muteStatesNotifier = ValueNotifier({});

  Future<void> toggleMute(int index) async {
    final currentStates = Map<int, bool>.from(_muteStatesNotifier.value);
    currentStates[index] = !(currentStates[index] ?? false); // default false
    _muteStatesNotifier.value = currentStates;
    final isMuted = currentStates[index] ?? false;
    widget.controller.setVolume(isMuted ? 0.0 : 1.0);
  }

  Timer? _hideTimer;
  bool _showControls = true;
  bool _isVideoStarted = false;

  Future<void> _toggleControls() async {
    printLog("_toggleControls _showControls =====> $_showControls");
    printLog("_toggleControls _isVideoStarted ===> $_isVideoStarted");
    _showControls = !_showControls;
    _isVideoStarted = (widget.controller.value.isPlaying);
    if (!mounted) return;
    if (_showControls) _startHideTimer();
    if (!mounted) return;
    setState(() {});
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();

    if (!mounted) return;
    _showControls = true;
    _isVideoStarted = (widget.controller.value.isPlaying);

    if (!mounted) return;
    // _startHideTimer();
  }

  Future<void> _startHideTimer() async {
    printLog("_startHideTimer _showControls =====> $_showControls");
    printLog("_startHideTimer _isVideoStarted ===> $_isVideoStarted");
    if (_hideTimer != null) {
      _hideTimer?.cancel();
    }
    _hideTimer = Timer(const Duration(seconds: 5), () async {
      _showControls = false;
      _isVideoStarted = (widget.controller.value.isPlaying);
      if (!mounted) return;
      setState(() {});
    });
  }

  final commentScrollController = ScrollController();
  final repliesScrollController = ScrollController();

  Future<void> _commentScrollListener() async {
    if (!commentScrollController.hasClients) return;
    if (commentScrollController.offset >=
            commentScrollController.position.maxScrollExtent &&
        !commentScrollController.position.outOfRange &&
        (clipsProvider.isCommentMorePage ?? false)) {
      clipsProvider.setCommentLoadMore(true);
      await clipsProvider.getComments(
          (clipsProvider.shortFilmsList?[widget.vIndex].id ?? 0),
          (clipsProvider.shortFilmsList?[widget.vIndex].videoType ?? 0),
          0,
          (clipsProvider.currentCommentPage ?? 0) + 1);
    }
  }

  Future<void> _repliesScrollListener() async {
    if (!repliesScrollController.hasClients) return;
    if (repliesScrollController.offset >=
            repliesScrollController.position.maxScrollExtent &&
        !repliesScrollController.position.outOfRange &&
        (clipsProvider.isReplyMorePage ?? false)) {
      clipsProvider.setReplyLoadMore(true);
      await clipsProvider.getReplyComments(
          (clipsProvider
                  .commentList?[clipsProvider.selectedCommentIndex ?? 0].id ??
              0),
          (clipsProvider.currentReplyPage ?? 0) + 1);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    commentScrollController.addListener(_commentScrollListener);
    repliesScrollController.addListener(_repliesScrollListener);

    clipsProvider = Provider.of<ClipsProvider>(context, listen: false);
    _heartAnimInit();

    // Listen for video completion
    widget.controller.addListener(_videoListener);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toggleControls();
    });
  }

  void _heartAnimInit() {
    // Heart animation: grow -> pause -> fade
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // First 0.0–0.4 = scale up, 0.4–0.6 = hold, 0.6–1.0 = fade out
    _scale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: 1.2)
              .chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 40),
      TweenSequenceItem(tween: ConstantTween(1.2), weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 1.2, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 40),
    ]).animate(_heartController);

    _opacity = TweenSequence([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_heartController);
  }

  @override
  void didUpdateWidget(covariant _ShortsPlayer oldWidget) {
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

      final total = clipsProvider.shortFilmsList?.length ?? 0;
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (widget.controller.value.isPlaying) widget.controller.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _hideTimer?.cancel();
    _heartController.dispose();
    widget.controller.removeListener(_videoListener);
    super.dispose();
  }

  @override
  void didPushNext() {
    // another page is pushed on top
    if (!clipsProvider.isDialogOpen) {
      widget.controller.pause();
    }
  }

  @override
  void didPopNext() {
    // returning back to this page
    if (!clipsProvider.isDialogOpen) {
      widget.controller.play();
    }
  }

  void _onDoubleTap() async {
    if (Constant.userID != null &&
        (clipsProvider.shortFilmsList?[widget.vIndex].isUserLike ?? 0) == 0) {
      setState(() {
        _heartColor = _colors[Random().nextInt(_colors.length)];
      });
      _heartController
        ..stop()
        ..reset()
        ..forward();
      await clipsProvider.setLikeDislike(
        context,
        position: widget.vIndex,
        videoId: (clipsProvider.shortFilmsList?[widget.vIndex].id ?? 0),
        subVideoType: 0,
        videoType:
            (clipsProvider.shortFilmsList?[widget.vIndex].videoType ?? 0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vCont = widget.controller;
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: () {
            _isVideoStarted ? vCont.pause() : vCont.play();
            if (!mounted) return;
            _toggleControls();
          },
          onDoubleTap: _onDoubleTap,
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

        Center(child: _buildHitArea()),

        // Heart animation
        // Heart overlay with fade-out
        Center(
          child: AnimatedBuilder(
            animation: _heartController,
            builder: (_, __) {
              if (_heartController.isDismissed) return const SizedBox.shrink();
              return Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Icon(
                    Icons.favorite,
                    color: _heartColor,
                    size: 120,
                  ),
                ),
              );
            },
          ),
        ),

        // Overlays: progress + icons
        Column(
          children: [
            const Spacer(),
            _buildShowDetails(index: widget.vIndex),
            SizedBox(height: 8),
            ValueListenableBuilder<VideoPlayerValue>(
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
                        enabledThumbRadius: 2,
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
          ],
        ),
      ],
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
          show: _showControls,
          onPressed: () async {
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

  Widget _buildShowDetails({required int index}) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 0, 0, 5),
      constraints: BoxConstraints(
        minHeight: 0,
        minWidth: 0,
        maxWidth: MediaQuery.of(context).size.width,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  alignment: Alignment.centerLeft,
                  child: MyText(
                    text: widget.reelsList[widget.vIndex].name ?? "",
                    multilanguage: false,
                    color: white,
                    fontsizeNormal: 16,
                    fontsizeWeb: 18,
                    fontweight: FontWeight.w600,
                    maxline: 2,
                    overflow: TextOverflow.ellipsis,
                    textalign: TextAlign.start,
                    fontstyle: FontStyle.normal,
                    isShadowText: true,
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(minHeight: 0),
                  alignment: Alignment.centerLeft,
                  child: ExpandableText(
                    widget.reelsList[index].description ?? "",
                    expandText: Locales.string(context, "more"),
                    collapseText: Locales.string(context, "less"),
                    expandOnTextTap: true,
                    collapseOnTextTap: true,
                    maxLines: kIsWeb ? 50 : 3,
                    linkColor: colorPrimary,
                    style: TextStyle(
                      fontSize: kIsWeb ? 16 : 13,
                      fontStyle: FontStyle.normal,
                      color: white,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        const Shadow(
                          color: Colors.black,
                          offset: Offset(0.5, 0.5),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          /* Feature Buttons */
          _buildFeatureBtns(index),
        ],
      ),
    );
  }

  Widget _buildFeatureBtns(int index) {
    final vCont = widget.controller;
    return Container(
      padding: EdgeInsets.only(right: 12),
      constraints: const BoxConstraints(minWidth: 45),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /* Mute/Unmute */
          MuteUnmuteButton(
            index: index,
            toggleMute: toggleMute,
            muteStatesNotifier: _muteStatesNotifier,
          ),
          const SizedBox(height: 20),

          /* Like */
          Consumer<ClipsProvider>(
            builder: (context, clipsProvider, child) {
              if ((clipsProvider.shortFilmsList?[index].isLike ?? 0) != 1) {
                return SizedBox.shrink();
              }
              return _buildFeatureIcon(
                iconName:
                    ((clipsProvider.shortFilmsList?[index].isUserLike ?? 0) ==
                            1)
                        ? 'ic_heartfill'
                        : 'ic_heart',
                index: index,
                isTitle: false,
                isActive:
                    (clipsProvider.shortFilmsList?[index].isUserLike ?? 0) == 1,
                count: (clipsProvider.shortFilmsList?[index].totalLike ?? 0)
                    .toString(),
                onClick: () async {
                  printLog("Tapped on Heart! => $index");
                  if (!mounted) return;
                  if (Utils.checkLoginUser(context)) {
                    if ((clipsProvider.shortFilmsList?[index].isUserLike ??
                            0) ==
                        0) {
                      _onDoubleTap();
                    } else {
                      await clipsProvider.setLikeDislike(
                        context,
                        position: index,
                        videoId: (clipsProvider.shortFilmsList?[index].id ?? 0),
                        videoType:
                            (clipsProvider.shortFilmsList?[index].videoType ??
                                0),
                        subVideoType: 0,
                      );
                    }
                  }
                },
              );
            },
          ),

          /* Comment */
          Consumer<ClipsProvider>(
            builder: (context, clipsProvider, child) {
              if ((clipsProvider.shortFilmsList?[index].isComment ?? 0) != 1) {
                return SizedBox.shrink();
              }
              return _buildFeatureIcon(
                iconName: 'ic_comment',
                index: index,
                isTitle: false,
                isActive: false,
                count: (clipsProvider.shortFilmsList?[index].totalComment ?? 0)
                    .toString(),
                onClick: () async {
                  printLog("Tapped on Comment! => $index");
                  if (!mounted) return;
                  if (Utils.checkLoginUser(context)) {
                    clipsProvider.setDialogState(true);
                    clipsProvider.resetCommentData();
                    clipsProvider.getComments(
                        (clipsProvider.shortFilmsList?[index].id ?? 0),
                        (clipsProvider.shortFilmsList?[index].videoType ?? 0),
                        0,
                        1);
                    openCommentSheet(index);
                  }
                },
              );
            },
          ),

          /* Episodes */
          _buildFeatureIcon(
            iconName: "ic_episodes",
            index: index,
            isTitle: true,
            isActive: false,
            count: "episodes",
            onClick: () async {
              printLog("Tapped on Episode! => $index");
              int typeId = clipsProvider.shortFilmsList?[index].typeId ?? 0;
              int videoType =
                  clipsProvider.shortFilmsList?[index].videoType ?? 0;
              int videoId = clipsProvider.shortFilmsList?[index].id ?? 0;
              int subVideoType = 0;
              try {
                clipsProvider.setEpiLoading(true);
                clipsProvider.getShortsDetails(
                    typeId, videoType, videoId, subVideoType,
                    forceRefresh: true);
              } on Exception catch (e) {
                printLog("_buildFeatureIcon Episode Exception => $e");
              }

              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return ClipsEpisodes(
                      videoId: videoId,
                      subVideoType: subVideoType,
                      videoType: videoType,
                      typeId: typeId,
                    );
                  },
                ),
              );
              if (vCont.value.isInitialized && !vCont.value.isPlaying) {
                await vCont.play();
              }
            },
          ),

          /* Share */
          _buildFeatureIcon(
            iconName: 'ic_send',
            index: index,
            count: "share",
            isTitle: true,
            isActive: false,
            onClick: () async {
              printLog("Tapped on Share! => $index");
              ShareModel shareModel = ShareModel(
                newPage: RoutesConstant.clipsPage,
                videoTitle: widget.reelsList[widget.vIndex].name ?? "",
                videoId: widget.reelsList[widget.vIndex].id ?? 0,
                videoType: widget.reelsList[widget.vIndex].videoType ?? 0,
                subVideoType: 0,
                typeId: widget.reelsList[widget.vIndex].typeId ?? 0,
              );
              Utils.openShareDialog(
                context: context,
                shareModel: shareModel,
              );
            },
          ),

          /* BookMark */
          Consumer<ClipsProvider>(
            builder: (context, clipsProvider, child) {
              return _buildFeatureIcon(
                iconName:
                    ((clipsProvider.shortFilmsList?[index].isBookmark ?? 0) ==
                            1)
                        ? 'ic_bookmarkfill'
                        : 'ic_bookmark',
                index: index,
                isTitle: false,
                isActive:
                    (clipsProvider.shortFilmsList?[index].isBookmark ?? 0) == 1,
                count: "",
                onClick: () async {
                  printLog("Tapped on Bookmark! => $index");
                  if (!mounted) return;
                  if (Utils.checkLoginUser(context)) {
                    await clipsProvider.setBookmark(
                      context,
                      position: index,
                      videoId: (clipsProvider.shortFilmsList?[index].id ?? 0),
                      videoType:
                          (clipsProvider.shortFilmsList?[index].videoType ?? 0),
                      subVideoType: 0,
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon({
    required String iconName,
    required int index,
    required String count,
    required bool isTitle,
    required bool isActive,
    required Function() onClick,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 32,
          height: 32,
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
                    color: isActive ? colorPrimary : titleTextColor,
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
        const SizedBox(height: 18),
      ],
    );
  }

  /* Comment Section START ********* */
  void openCommentSheet(int index) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: transparent,
      isScrollControlled: true,
      isDismissible: true,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: transparent,
          resizeToAvoidBottomInset: true,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: Consumer<ClipsProvider>(
              builder: (context, clipsProvider, child) {
                return _buildCommentDialog(index);
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      clipsProvider.setDialogState(false);
      printLog(
          "openCommentSheet totalComment ====>>> ${(kIsWeb) ? (clipsProvider.contentDetailModel.result?[0].totalComment ?? 0) : (clipsProvider.shortFilmsList?[index].totalComment ?? 0)}");
      clipsProvider.updateCommentCount(
          index,
          (kIsWeb)
              ? (clipsProvider.contentDetailModel.result?[0].totalComment ?? 0)
              : (clipsProvider.shortFilmsList?[index].totalComment ?? 0));
      clipsProvider.setDialogType(
        position: 0,
        dialogType: CommentDialogEnum.comments,
      );
    });
  }

  Widget _buildCommentDialog(int videoPos) {
    return AnimatedPadding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      duration: const Duration(milliseconds: 100),
      curve: Curves.decelerate,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.6,
        constraints: BoxConstraints(minHeight: 0),
        decoration: BoxDecoration(
          color: secondaryBgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildDialogHeader(videoPos: videoPos),
              Utils.buildGradLine(),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: 0,
                    maxHeight: MediaQuery.of(context).size.height,
                  ),
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: (clipsProvider.currentDialogPage ==
                            CommentDialogEnum.comments)
                        ? _buildComments(videoPos: videoPos)
                        : _buildReplyComments(
                            videoPos: videoPos,
                            commentIndex:
                                clipsProvider.selectedCommentIndex ?? 0),
                  ),
                ),
              ),

              /* Pagination loader */
              if (clipsProvider.loadCommentMore || clipsProvider.loadReplyMore)
                Container(
                  height: 40,
                  margin: EdgeInsets.only(top: 10, bottom: 10),
                  child: Utils.pageLoader(),
                )
              else
                const SizedBox.shrink(),
              Utils.buildGradLine(),
              Container(
                width: MediaQuery.of(context).size.width,
                height: 50,
                constraints: BoxConstraints(
                  minHeight: 0,
                  maxHeight: MediaQuery.of(context).size.height,
                ),
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 25),
                alignment: Alignment.center,
                decoration:
                    Utils.setBGWithBorder(transparent, titleTextColor, 5, 0.7),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: commentController,
                          maxLines: 1,
                          scrollPhysics: const AlwaysScrollableScrollPhysics(),
                          textAlign: TextAlign.start,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: transparent,
                            border: InputBorder.none,
                            hintText: Locales.string(context, "comment_hint"),
                            hintStyle: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.normal,
                              color: descTextColor,
                            ),
                            contentPadding:
                                const EdgeInsets.only(left: 10, right: 10),
                          ),
                          obscureText: false,
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.normal,
                            color: titleTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        margin: EdgeInsets.only(right: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: () async {
                            printLog("Clicked on Send!");
                            if (!clipsProvider.sending) {
                              await clipsProvider.addComments(
                                  commentController.text.toString(),
                                  (clipsProvider.currentDialogPage ==
                                          CommentDialogEnum.comments)
                                      ? 0
                                      : (clipsProvider
                                              .commentList?[clipsProvider
                                                      .selectedCommentIndex ??
                                                  0]
                                              .id ??
                                          0),
                                  (clipsProvider.shortFilmsList?[videoPos].id ??
                                      0),
                                  (clipsProvider.shortFilmsList?[videoPos]
                                          .videoType ??
                                      0),
                                  0);
                              commentController.clear();
                            }
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            padding: const EdgeInsets.all(4),
                            child: Consumer<ClipsProvider>(
                              builder: (context, clipsProvider, child) {
                                if (!clipsProvider.sending) {
                                  return MyImage(
                                    height: 15,
                                    width: 15,
                                    fit: BoxFit.contain,
                                    imagePath: "ic_send.png",
                                    color: titleTextColor,
                                  );
                                } else {
                                  return Utils.pageLoaderWithStroke(
                                      strokeWidth: 2);
                                }
                              },
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
      ),
    );
  }

  Widget _buildDialogHeader({required int videoPos}) {
    final isReplies =
        clipsProvider.currentDialogPage == CommentDialogEnum.replies;

    final int count = isReplies
        ? (clipsProvider.commentList?[clipsProvider.selectedCommentIndex ?? 0]
                .totalReply ??
            0)
        : (clipsProvider.shortFilmsList?[videoPos].totalComment ?? 0);

    final String label = isReplies
        ? (count > 1 ? "replies" : "reply")
        : (count > 1 ? "comments" : "comment");

    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isReplies)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () {
                  clipsProvider.setDialogType(
                    position: 0,
                    dialogType: CommentDialogEnum.comments,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: MyImage(
                    width: 18,
                    height: 18,
                    imagePath: "back.png",
                    fit: BoxFit.contain,
                    color: titleTextColor,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(left: isReplies ? 0 : 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  MyText(
                    color: titleTextColor,
                    text: Utils.withSuffix(count),
                    fontsizeNormal: 15,
                    fontsizeWeb: 17,
                    fontweight: FontWeight.w600,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    textalign: TextAlign.start,
                    isShadowText: true,
                  ),
                  const SizedBox(width: 5),
                  MyText(
                    color: white,
                    multilanguage: true,
                    text: label,
                    fontsizeNormal: 15,
                    fontsizeWeb: 17,
                    fontweight: FontWeight.w600,
                    maxline: 1,
                    overflow: TextOverflow.ellipsis,
                    textalign: TextAlign.start,
                    isShadowText: true,
                  ),
                ],
              ),
            ),
          ),
          if (!isReplies)
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () {
                  clipsProvider.resetCommentData();
                  Utils.exitPage(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: MyImage(
                    width: 15,
                    height: 15,
                    imagePath: "ic_close.png",
                    fit: BoxFit.contain,
                    color: titleTextColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComments({required int videoPos}) {
    if (clipsProvider.loadingComment && !clipsProvider.loadCommentMore) {
      return Center(child: Utils.pageLoader());
    } else {
      if (clipsProvider.commentList != null &&
          (clipsProvider.commentList?.length ?? 0) > 0) {
        return SingleChildScrollView(
          controller: commentScrollController,
          child: AlignedGridView.count(
            shrinkWrap: true,
            crossAxisCount: 1,
            crossAxisSpacing: 0,
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            mainAxisSpacing: 20,
            itemCount: clipsProvider.commentList?.length ?? 0,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (BuildContext context, int position) {
              return _buildCommentItem(position: position, videoPos: videoPos);
            },
          ),
        );
      } else {
        return const NoData(title: '', subTitle: '');
      }
    }
  }

  Widget _buildCommentItem({required int position, required int videoPos}) {
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: const BoxConstraints(minHeight: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.zero,
            width: 35,
            height: 35,
            decoration:
                Utils.setGradTTBBorderWithBG(white, white, transparent, 20, 1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: MyNetworkImage(
                width: 35,
                height: 35,
                imageUrl: clipsProvider.commentList?[position].userImage ?? "",
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  color: titleTextColor,
                  text: (clipsProvider.commentList?[position].userName ?? ""),
                  fontsizeNormal: 13,
                  fontsizeWeb: 14,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  fontweight: FontWeight.bold,
                  textalign: TextAlign.start,
                  fontstyle: FontStyle.normal,
                  isShadowText: true,
                ),
                const SizedBox(height: 5),
                MyText(
                  color: titleTextColor,
                  text: clipsProvider.commentList?[position].comment ?? "",
                  fontsizeNormal: 12,
                  fontsizeWeb: 14,
                  maxline: 3,
                  overflow: TextOverflow.ellipsis,
                  fontweight: FontWeight.normal,
                  textalign: TextAlign.start,
                  fontstyle: FontStyle.normal,
                  isShadowText: true,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () async {
                        printLog("Clicked on position ==> $position");
                        printLog("Clicked on videoPos ==> $videoPos");
                        clipsProvider.getReplyComments(
                            clipsProvider.commentList?[position].id ?? 0, 1);
                        clipsProvider.setDialogType(
                            position: position,
                            dialogType: CommentDialogEnum.replies);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        child: MyText(
                          color: descTextColor,
                          text: ((clipsProvider
                                          .commentList?[position].totalReply ??
                                      0) >
                                  0)
                              ? "${Utils.withSuffix(clipsProvider.commentList?[position].totalReply ?? 0)} ${Locales.string(context, "reply")}"
                              : Locales.string(context, "reply"),
                          fontsizeNormal: 12,
                          fontsizeWeb: 14,
                          maxline: 3,
                          overflow: TextOverflow.ellipsis,
                          fontweight: FontWeight.normal,
                          textalign: TextAlign.start,
                          fontstyle: FontStyle.normal,
                          isShadowText: true,
                        ),
                      ),
                    ),
                    if (Constant.userID ==
                        (clipsProvider.commentList?[position].userId
                                .toString() ??
                            "0"))
                      Container(
                        margin: EdgeInsets.only(left: 10),
                        child: InkWell(
                          onTap: () async {
                            printLog("Clicked on Edit! ==> $position");
                            editCommentController = TextEditingController(
                                text: clipsProvider
                                        .commentList?[position].comment ??
                                    "");
                            clipsProvider.wantToEditedComment(
                                !clipsProvider.wantToEdit, position);
                          },
                          child: Container(
                            height: 20,
                            width: 20,
                            padding: EdgeInsets.all(3),
                            child: MyImage(
                              imagePath: (clipsProvider.wantToEdit &&
                                      clipsProvider.commentPos == position)
                                  ? "ic_close.png"
                                  : "ic_edit.png",
                              color: descTextColor,
                            ),
                          ),
                        ),
                      ),
                    if (Constant.userID ==
                        (clipsProvider.commentList?[position].userId
                                .toString() ??
                            ""))
                      Container(
                        margin: EdgeInsets.only(left: 12),
                        child: InkWell(
                          onTap: () async {
                            printLog("Clicked on remove!  ==>  $position");
                            if (!clipsProvider.loading) {
                              openConfirDialog(
                                  position: position, videoPos: videoPos);
                            }
                          },
                          child: Container(
                            height: 20,
                            width: 20,
                            padding: EdgeInsets.all(1),
                            child: MyImage(
                              imagePath: "ic_delete.png",
                              color: descTextColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (clipsProvider.wantToEdit &&
                    clipsProvider.commentPos == position)
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: 40,
                    constraints: BoxConstraints(
                      minHeight: 0,
                      maxHeight: MediaQuery.of(context).size.height,
                    ),
                    margin: const EdgeInsets.only(top: 0),
                    alignment: Alignment.center,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: editCommentController,
                              maxLines: 1,
                              scrollPhysics:
                                  const AlwaysScrollableScrollPhysics(),
                              textAlign: TextAlign.left,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: Locales.string(
                                    context, "edit_comment_hint"),
                                hintStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.normal,
                                  color: descTextColor,
                                ),
                                contentPadding:
                                    const EdgeInsets.only(left: 0, right: 10),
                              ),
                              obscureText: false,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.normal,
                                color: titleTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          InkWell(
                            borderRadius: BorderRadius.circular(5),
                            onTap: () async {
                              printLog("Clicked on Send!");
                              if (!clipsProvider.sendingEdited) {
                                await clipsProvider.editComments(
                                  position,
                                  clipsProvider.shortFilmsList?[videoPos].id ??
                                      0,
                                  clipsProvider.shortFilmsList?[position]
                                          .videoType ??
                                      0,
                                  0,
                                  editCommentController.text.toString(),
                                  clipsProvider.commentList?[position].id ?? 0,
                                );
                                editCommentController.clear();
                              }
                            },
                            child: Container(
                                padding: const EdgeInsets.all(4),
                                child: (!clipsProvider.sendingEdited)
                                    ? MyImage(
                                        height: 15,
                                        width: 15,
                                        fit: BoxFit.contain,
                                        imagePath: "ic_send.png",
                                        color: descTextColor,
                                      )
                                    : Utils.pageLoaderWithStroke(
                                        strokeWidth: 2)),
                          ),
                          const SizedBox(width: 10),
                        ],
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildReplyComments({
    required int videoPos,
    required int commentIndex,
  }) {
    if (clipsProvider.loadingReply && !clipsProvider.loadReplyMore) {
      return Center(child: Utils.pageLoader());
    } else {
      if (clipsProvider.commentRepliesList != null &&
          (clipsProvider.commentRepliesList?.length ?? 0) > 0) {
        return SingleChildScrollView(
          controller: repliesScrollController,
          child: AlignedGridView.count(
            shrinkWrap: true,
            crossAxisCount: 1,
            crossAxisSpacing: 0,
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            mainAxisSpacing: 20,
            itemCount: clipsProvider.commentRepliesList?.length ?? 0,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (BuildContext context, int position) {
              return _buildReplyCommentItem(
                  position: position,
                  videoPos: videoPos,
                  commentIndex: commentIndex);
            },
          ),
        );
      } else {
        return const NoData(title: '', subTitle: '');
      }
    }
  }

  Widget _buildReplyCommentItem({
    required int position,
    required int videoPos,
    required int commentIndex,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width,
      constraints: const BoxConstraints(minHeight: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.zero,
            width: 35,
            height: 35,
            decoration:
                Utils.setGradTTBBorderWithBG(white, white, transparent, 20, 1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: MyNetworkImage(
                width: 35,
                height: 35,
                imageUrl:
                    clipsProvider.commentRepliesList?[position].userImage ?? "",
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  color: titleTextColor,
                  text: (clipsProvider.commentRepliesList?[position].userName ??
                      ""),
                  fontsizeNormal: 13,
                  fontsizeWeb: 14,
                  maxline: 1,
                  overflow: TextOverflow.ellipsis,
                  fontweight: FontWeight.bold,
                  textalign: TextAlign.start,
                  fontstyle: FontStyle.normal,
                  isShadowText: true,
                ),
                const SizedBox(height: 5),
                MyText(
                  color: titleTextColor,
                  text:
                      clipsProvider.commentRepliesList?[position].comment ?? "",
                  fontsizeNormal: 12,
                  fontsizeWeb: 14,
                  maxline: 3,
                  overflow: TextOverflow.ellipsis,
                  fontweight: FontWeight.normal,
                  textalign: TextAlign.start,
                  fontstyle: FontStyle.normal,
                  isShadowText: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  void openConfirDialog({
    required int position,
    required int videoPos,
  }) {
    showDialog<dynamic>(
      context: context,
      useSafeArea: true,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _buildDeleteDialog(
          position: position,
          videoPos: videoPos,
        );
      },
    );
  }

  Widget _buildDeleteDialog({
    required int position,
    required int videoPos,
  }) {
    return Dialog(
      alignment: Alignment.centerRight,
      backgroundColor: secondaryBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: EdgeInsets.fromLTRB(
        (MediaQuery.of(context).size.width > 900) ? 50 : 30,
        (MediaQuery.of(context).size.width > 900) ? 50 : 30,
        (MediaQuery.of(context).size.width > 900) ? 50 : 30,
        (MediaQuery.of(context).size.width > 900) ? 50 : 30,
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: AnimatedPadding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        duration: const Duration(milliseconds: 100),
        curve: Curves.decelerate,
        child: Wrap(
          children: [
            Container(
              decoration:
                  Utils.setBGWithBorder(transparent, descTextColor, 8, 0.7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    alignment: Alignment.centerLeft,
                    child: MyText(
                      color: white,
                      text: "confirm_delete_msg",
                      multilanguage: true,
                      textalign: TextAlign.start,
                      fontsizeNormal: 14,
                      fontsizeWeb: 16,
                      fontweight: FontWeight.w500,
                      maxline: 5,
                      overflow: TextOverflow.ellipsis,
                      fontstyle: FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    alignment: Alignment.centerRight,
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: () {
                            Utils.exitPage(context);
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 75,
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: descTextColor,
                                width: .5,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: MyText(
                              color: white,
                              text: "cancel",
                              multilanguage: true,
                              textalign: TextAlign.center,
                              fontsizeNormal: 14,
                              fontsizeWeb: 16,
                              maxline: 1,
                              overflow: TextOverflow.ellipsis,
                              fontweight: FontWeight.w500,
                              fontstyle: FontStyle.normal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: () async {
                            printLog(
                                "comment count ====>>> ${clipsProvider.commentList?.length}");
                            Utils.exitPage(context);
                            await clipsProvider.deleteComments(
                                position,
                                clipsProvider.shortFilmsList?[videoPos].id ?? 0,
                                clipsProvider
                                        .shortFilmsList?[position].videoType ??
                                    0,
                                0,
                                clipsProvider.commentList?[position].id ?? 0,
                                clipsProvider.commentList?[position].userId ??
                                    0);
                            if (!mounted) return;
                            clipsProvider.notifyProvider();
                          },
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 75,
                            ),
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colorAccent,
                              borderRadius: BorderRadius.circular(5),
                              shape: BoxShape.rectangle,
                            ),
                            child: MyText(
                              color: white,
                              text: "delete",
                              textalign: TextAlign.center,
                              fontsizeNormal: 14,
                              fontsizeWeb: 16,
                              multilanguage: true,
                              maxline: 1,
                              overflow: TextOverflow.ellipsis,
                              fontweight: FontWeight.w500,
                              fontstyle: FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  /* ********* Comment Section END */
}
