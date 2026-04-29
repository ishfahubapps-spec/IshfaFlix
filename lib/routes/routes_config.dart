import 'package:provider/provider.dart';

import '../model/playermodel.dart';
import '../webpages/webclipsepisodes.dart';
import '../pages/activetv.dart';
import '../pages/find.dart';
import '../players/player_vdocipher.dart';
import '../provider/homeprovider.dart';
import '../subscription/allpayment.dart';
import '../subscription/contactus.dart';
import '../subscription/mypurchaselist.dart';
import '../pages/myspace.dart';
import '../pages/mywatchlist.dart';
import '../pages/profile.dart';
import '../pages/profileavatar.dart';
import '../pages/profileedit.dart';
import '../pages/settings.dart';
import '../players/player_vimeo.dart';
import '../routes/routes_constant.dart';
import '../subscription/mysubscribedplan.dart';
import '../subscription/subscription.dart';
import '../subscription/subscriptionhistory.dart';
import '../webpages/webmyspace.dart';
import '../webpages/webprofile.dart';
import '../webpages/webprofileavatar.dart';
import '../webpages/webprofileedit.dart';
import '../webpages/websearch.dart';
import '../webpages/websectionviewall.dart';
import '../webpages/websettings.dart';
import '../webpages/webviewall.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../main.dart';
import '../pages/aboutprivacyterms.dart';
import '../pages/rentstore.dart';
import '../pages/splash.dart';
import '../players/player_video.dart';
import '../players/player_youtube.dart';
import '../webpages/weberrorpage.dart';
import '../webpages/webaboutprivacyterms.dart';
import '../webpages/webhome.dart';
import '../webpages/webcontentvideodetails.dart';
import '../webpages/webrentstore.dart';
import '../webpages/webcontentshowdetails.dart';
import '../webpages/webcontentbyid.dart';
import '../webpages/webmywatchlist.dart';
import '../utils/constant.dart';
import '../utils/utils.dart';

class RoutesConfig {
  GoRouter goRouter = GoRouter(
    initialLocation: '/',
    observers: [routeObserver], //HERE
    routes: [
      /* Initial route by Platform */
      GoRoute(
        path: '/',
        name: RoutesConstant.homePage,
        builder: (context, state) {
          if (kIsWeb || Constant.isTV) {
            return const WebHome(
              newPage: RoutesConstant.homePage,
              oldPage: RoutesConstant.homePage,
              reqText: '',
            );
          }
          return const Splash();
        },
      ),

      /* Search */
      GoRoute(
        name: RoutesConstant.searchPage,
        path: '/${RoutesConstant.searchPage}',
        builder: (context, state) {
          String newPage = "";
          printLog("searchPage extra ====> ${state.extra}");
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("searchPage newPage ==> $newPage");

            if (kIsWeb || Constant.isTV) {
              return WebSearch(
                newPage: RoutesConstant.searchPage,
                oldPage: newPage,
                reqText: '',
              );
            }
            return Find(viewFrom: newPage);
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Rent */
      GoRoute(
        name: RoutesConstant.storePage,
        path: '/${RoutesConstant.storePage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null) {
            newPage = state.extra as String;

            printLog("newPage =====> $newPage");
            if (kIsWeb || Constant.isTV) {
              return WebRentStore(
                newPage: RoutesConstant.storePage,
                oldPage: newPage,
                reqText: '',
              );
            }
            return const RentStore();
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Watchlist */
      GoRoute(
        name: RoutesConstant.myWatchlistPage,
        path: '/${RoutesConstant.myWatchlistPage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null) {
            newPage = state.extra as String;

            printLog("newPage =====> $newPage");
            if (kIsWeb || Constant.isTV) {
              return WebMyWatchlist(
                newPage: RoutesConstant.myWatchlistPage,
                oldPage: newPage,
                reqText: '',
              );
            }
            return const MyWatchlist();
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Clip's Episodes */
      GoRoute(
        path:
            '/${RoutesConstant.clipsEpisodesPage}/:videotype/:typeid/:videoid/:subvideotype',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          final videoTypeStr = state.pathParameters['videotype'];
          final typeIdStr = state.pathParameters['typeid'];
          final videoIdStr = state.pathParameters['videoid'];
          final subVideoTypeStr = state.pathParameters['subvideotype'];

          final int videoType = int.tryParse(videoTypeStr ?? "0") ?? 0;
          final int typeId = int.tryParse(typeIdStr ?? "0") ?? 0;
          final int videoId = int.tryParse(videoIdStr ?? "0") ?? 0;
          final int subVideoType = int.tryParse(subVideoTypeStr ?? "0") ?? 0;

          String newPage = "";
          if (state.extra is Map<String, dynamic>) {
            newPage = (state.extra as Map<String, dynamic>)['newpage'] ?? "";
          }

          homeProvider.getSectionType();

          return WebClipsEpisodes(
            newPage: RoutesConstant.clipsEpisodesPage,
            oldPage: newPage,
            reqText: "",
            videoId: videoId,
            videoType: videoType,
            typeId: typeId,
            subVideoType: subVideoType,
          );
        },
      ),
      GoRoute(
        path:
            '/${RoutesConstant.clipsEpisodesPage}/:videotype/:typeid/:videoid',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          final videoTypeStr = state.pathParameters['videotype'];
          final typeIdStr = state.pathParameters['typeid'];
          final videoIdStr = state.pathParameters['videoid'];

          final int videoType = int.tryParse(videoTypeStr ?? "0") ?? 0;
          final int typeId = int.tryParse(typeIdStr ?? "0") ?? 0;
          final int videoId = int.tryParse(videoIdStr ?? "0") ?? 0;

          String newPage = "";
          if (state.extra is Map<String, dynamic>) {
            newPage = (state.extra as Map<String, dynamic>)['newpage'] ?? "";
          }

          homeProvider.getSectionType();

          return WebClipsEpisodes(
            newPage: RoutesConstant.clipsEpisodesPage,
            oldPage: newPage,
            reqText: "",
            videoId: videoId,
            videoType: videoType,
            typeId: typeId,
            subVideoType: 0,
          );
        },
      ),

      /* Video/Show Details */
      GoRoute(
        path:
            '/${RoutesConstant.contentDetailsPage}/:videotype/:typeid/:videoid/:subvideotype',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          final videoTypeStr = state.pathParameters['videotype'];
          final typeIdStr = state.pathParameters['typeid'];
          final videoIdStr = state.pathParameters['videoid'];
          final subVideoTypeStr = state.pathParameters['subvideotype'];

          final int videoType = int.tryParse(videoTypeStr ?? "0") ?? 0;
          final int typeId = int.tryParse(typeIdStr ?? "0") ?? 0;
          final int videoId = int.tryParse(videoIdStr ?? "0") ?? 0;
          final int subVideoType = int.tryParse(subVideoTypeStr ?? "0") ?? 0;

          String newPage = "";
          if (state.extra is Map<String, dynamic>) {
            newPage = (state.extra as Map<String, dynamic>)['newpage'] ?? "";
          }

          homeProvider.getSectionType();

          final bool isShowDetails =
              (videoType == Constant.upcomingContentType ||
                      videoType == Constant.channelContentType ||
                      videoType == Constant.kidsContentType)
                  ? subVideoType == Constant.showContentType
                  : videoType == Constant.showContentType;

          return isShowDetails
              ? WebContentShowDetails(
                  videoId,
                  subVideoType,
                  videoType,
                  typeId,
                  newPage: RoutesConstant.contentDetailsPage,
                  oldPage: newPage,
                  reqText: "deeplink",
                  key: ValueKey("$videoId$videoType$typeId$subVideoType"),
                )
              : WebContentVideoDetails(
                  videoId,
                  subVideoType,
                  videoType,
                  typeId,
                  newPage: RoutesConstant.contentDetailsPage,
                  oldPage: newPage,
                  reqText: "deeplink",
                  key: ValueKey("$videoId$videoType$typeId$subVideoType"),
                );
        },
      ),
      GoRoute(
        path:
            '/${RoutesConstant.contentDetailsPage}/:videotype/:typeid/:videoid',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          final videoTypeStr = state.pathParameters['videotype'];
          final typeIdStr = state.pathParameters['typeid'];
          final videoIdStr = state.pathParameters['videoid'];

          final int videoType = int.tryParse(videoTypeStr ?? "0") ?? 0;
          final int typeId = int.tryParse(typeIdStr ?? "0") ?? 0;
          final int videoId = int.tryParse(videoIdStr ?? "0") ?? 0;

          String newPage = "";
          if (state.extra is Map<String, dynamic>) {
            newPage = (state.extra as Map<String, dynamic>)['newpage'] ?? "";
          }

          homeProvider.getSectionType();

          final bool isShowDetails = (videoType == Constant.showContentType);

          return isShowDetails
              ? WebContentShowDetails(
                  videoId,
                  0,
                  videoType,
                  typeId,
                  newPage: RoutesConstant.contentDetailsPage,
                  oldPage: newPage,
                  reqText: "deeplink",
                  key: ValueKey("$videoId$videoType$typeId"),
                )
              : WebContentVideoDetails(
                  videoId,
                  0,
                  videoType,
                  typeId,
                  newPage: RoutesConstant.contentDetailsPage,
                  oldPage: newPage,
                  reqText: "deeplink",
                  key: ValueKey("$videoId$videoType$typeId"),
                );
        },
      ),

      /* Related Contents */
      GoRoute(
        path: '/${RoutesConstant.relatedContentPage}',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          String newPage = "";
          String? appBarTitle;
          if (state.extra is Map<String, dynamic>) {
            final extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] ?? "";
            appBarTitle = extraData['title'] ?? "";
          }

          homeProvider.getSectionType();

          return WebViewAll(
            appBarTitle: appBarTitle ?? "",
            videoId: 0,
            subVideoType: 0,
            videoType: 0,
            typeId: 0,
            newPage: RoutesConstant.relatedContentPage,
            oldPage: newPage,
            reqText: '',
          );
        },
      ),

      /* Players */
      GoRoute(
        name: RoutesConstant.playerPage,
        path: '/${RoutesConstant.playerPage}',
        builder: (context, state) {
          String newPage = "";
          PlayerModel playerModel;
          if (state.extra != null && state.extra is PlayerModel) {
            playerModel = state.extra as PlayerModel;
            printLog("newPage =====> $newPage");
            if (playerModel.uploadType == "youtube") {
              return PlayerYoutube(playerModel: playerModel);
            } else if (playerModel.uploadType == "external") {
              if ((playerModel.videoUrl ?? "").contains('youtube')) {
                return PlayerYoutube(playerModel: playerModel);
              } else if ((playerModel.videoUrl ?? "").contains("vimeo")) {
                return PlayerVimeo(playerModel: playerModel);
              } else {
                return PlayerVideo(playerModel: playerModel);
              }
            } else if (playerModel.uploadType == "live_stream_url") {
              if ((playerModel.videoUrl ?? "").contains('youtube')) {
                return PlayerYoutube(playerModel: playerModel);
              } else if ((playerModel.videoUrl ?? "").contains("vimeo")) {
                return PlayerVimeo(playerModel: playerModel);
              } else {
                return PlayerVideo(playerModel: playerModel);
              }
            } else if (playerModel.uploadType == "vimeo") {
              return PlayerVimeo(playerModel: playerModel);
            } else if (playerModel.uploadType == Constant.vdocipherPlayType) {
              return PlayerVdoCipher(playerModel: playerModel);
            } else {
              return PlayerVideo(playerModel: playerModel);
            }
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Section ViewAll */
      GoRoute(
        name: RoutesConstant.sectionDetailsPage,
        path: '/${RoutesConstant.sectionDetailsPage}/:itemid/:videotype',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          String newPage = "";
          String? videoType, itemID, screenLayout, appBarTitle;
          // Extract parameters from URL, not `state.extra`
          itemID = state.pathParameters['itemid'];
          videoType = state.pathParameters['videotype'];
          printLog("sectionDetails videoId =======> $itemID");
          printLog("sectionDetails videoType =====> $videoType");

          Map<String, dynamic> extraData = {};
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            screenLayout = extraData['screenlayout'] as String;
            appBarTitle = extraData['title'] as String;
          }
          printLog("sectionDetails newPage =======> $newPage");
          printLog("sectionDetails screenLayout ==> $screenLayout");
          printLog("sectionDetails appBarTitle ===> $appBarTitle");

          if (itemID != null && videoType != null) {
            homeProvider.getSectionType();
            return WebSectionViewAll(
              sectionId: int.parse(itemID),
              videoType: int.parse(videoType),
              appBarTitle: appBarTitle ?? "",
              screenLayout: screenLayout ?? "",
              newPage: RoutesConstant.sectionDetailsPage,
              oldPage: newPage,
              reqText: itemID,
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Video By Category */
      GoRoute(
        name: RoutesConstant.videoByCatPage,
        path: '/${RoutesConstant.videoByCatPage}/:itemid',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          String newPage = "";
          String? itemID, layoutType, appBarTitle;
          // Extract parameters from URL, not `state.extra`
          itemID = state.pathParameters['itemid'];
          printLog("videoByCatPage itemID =======> $itemID");

          Map<String, dynamic> extraData = {};
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            layoutType = extraData['layouttype'] as String;
            appBarTitle = extraData['title'] as String;
          }
          printLog("videoByCatPage newPage =======> $newPage");
          printLog("videoByCatPage screenLayout ==> $layoutType");
          printLog("videoByCatPage appBarTitle ===> $appBarTitle");

          if (itemID != null) {
            homeProvider.getSectionType();
            return WebVideosByID(
              int.parse(itemID),
              appBarTitle ?? "",
              layoutType ?? "",
              newPage: RoutesConstant.videoByCatPage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Video By Language */
      GoRoute(
        name: RoutesConstant.videoByLanguagePage,
        path: '/${RoutesConstant.videoByLanguagePage}/:itemid',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          String newPage = "";
          String? itemID, layoutType, appBarTitle;
          // Extract parameters from URL, not `state.extra`
          itemID = state.pathParameters['itemid'];
          printLog("videoByLanguage itemID =======> $itemID");

          Map<String, dynamic> extraData = {};
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            layoutType = extraData['layouttype'] as String;
            appBarTitle = extraData['title'] as String;
          }
          printLog("videoByLanguage newPage =======> $newPage");
          printLog("videoByLanguage screenLayout ==> $layoutType");
          printLog("videoByLanguage appBarTitle ===> $appBarTitle");

          if (itemID != null) {
            homeProvider.getSectionType();
            return WebVideosByID(
              int.parse(itemID),
              appBarTitle ?? "",
              layoutType ?? "",
              newPage: RoutesConstant.videoByLanguagePage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Video By Channel */
      GoRoute(
        name: RoutesConstant.videoByChannelPage,
        path: '/${RoutesConstant.videoByChannelPage}/:itemid',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          String newPage = "";
          String? itemID, layoutType, appBarTitle;
          // Extract parameters from URL, not `state.extra`
          itemID = state.pathParameters['itemid'];
          printLog("videoByChannel itemID =======> $itemID");

          Map<String, dynamic> extraData = {};
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            layoutType = extraData['layouttype'] as String;
            appBarTitle = extraData['title'] as String;
          }
          printLog("videoByChannel newPage =======> $newPage");
          printLog("videoByChannel screenLayout ==> $layoutType");
          printLog("videoByChannel appBarTitle ===> $appBarTitle");

          if (itemID != null) {
            homeProvider.getSectionType();
            return WebVideosByID(
              int.parse(itemID),
              appBarTitle ?? "",
              layoutType ?? "",
              newPage: RoutesConstant.videoByChannelPage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Video By Cast */
      GoRoute(
        name: RoutesConstant.videoByCastPage,
        path: '/${RoutesConstant.videoByCastPage}/:itemid',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          String newPage = "";
          String? itemID, layoutType, appBarTitle;
          // Extract parameters from URL, not `state.extra`
          itemID = state.pathParameters['itemid'];
          printLog("videoByCast itemID =======> $itemID");

          Map<String, dynamic> extraData = {};
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            layoutType = extraData['layouttype'] as String;
            appBarTitle = extraData['title'] as String;
          }
          printLog("videoByCast newPage =======> $newPage");
          printLog("videoByCast screenLayout ==> $layoutType");
          printLog("videoByCast appBarTitle ===> $appBarTitle");

          if (itemID != null) {
            homeProvider.getSectionType();
            return WebVideosByID(
              int.parse(itemID),
              appBarTitle ?? "",
              layoutType ?? "",
              newPage: RoutesConstant.videoByCastPage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Related Content (ViewAll) */
      GoRoute(
        path:
            '/${RoutesConstant.relatedContentPage}/:itemid/:typeid/:videotype/:subvideotype',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          String newPage = "";
          String? itemID, appBarTitle, subVideoType, videoType, typeId;
          // Extract parameters from URL, not `state.extra`
          itemID = state.pathParameters['itemid'];
          subVideoType = state.pathParameters['subvideotype'];
          videoType = state.pathParameters['videotype'];
          typeId = state.pathParameters['typeid'];
          printLog("relatedContent itemID =======> $itemID");
          printLog("relatedContent subVideoType =======> $subVideoType");
          printLog("relatedContent itemID =======> $itemID");
          printLog("relatedContent itemID =======> $itemID");

          Map<String, dynamic> extraData = {};
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            appBarTitle = extraData['title'] as String;
          }
          printLog("relatedContent newPage =======> $newPage");
          printLog("relatedContent appBarTitle ===> $appBarTitle");

          if (itemID != null) {
            homeProvider.getSectionType();
            return WebViewAll(
              appBarTitle: appBarTitle ?? "",
              videoId: int.parse(itemID),
              subVideoType: int.parse(subVideoType ?? "0"),
              videoType: int.parse(videoType ?? "0"),
              typeId: int.parse(typeId ?? "0"),
              newPage: RoutesConstant.relatedContentPage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),
      GoRoute(
        path:
            '/${RoutesConstant.relatedContentPage}/:itemid/:typeid/:videotype',
        builder: (context, state) {
          final homeProvider =
              Provider.of<HomeProvider>(context, listen: false);

          String newPage = "";
          String? itemID, appBarTitle, videoType, typeId;
          // Extract parameters from URL, not `state.extra`
          itemID = state.pathParameters['itemid'];
          videoType = state.pathParameters['videotype'];
          typeId = state.pathParameters['typeid'];
          printLog("relatedContent itemID =======> $itemID");
          printLog("relatedContent itemID =======> $itemID");
          printLog("relatedContent itemID =======> $itemID");

          Map<String, dynamic> extraData = {};
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            appBarTitle = extraData['title'] as String;
          }
          printLog("relatedContent newPage =======> $newPage");
          printLog("relatedContent appBarTitle ===> $appBarTitle");

          if (itemID != null) {
            homeProvider.getSectionType();
            return WebViewAll(
              appBarTitle: appBarTitle ?? "",
              videoId: int.parse(itemID),
              subVideoType: 0,
              videoType: int.parse(videoType ?? "0"),
              typeId: int.parse(typeId ?? "0"),
              newPage: RoutesConstant.relatedContentPage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Continue Watching (ViewAll) */
      GoRoute(
        name: RoutesConstant.continueWatchPage,
        path: '/${RoutesConstant.continueWatchPage}',
        builder: (context, state) {
          String newPage = "";
          Map<String, dynamic> extraData = {};
          String? appBarTitle;
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            appBarTitle = extraData['title'] as String;

            printLog("newPage =====> $newPage");
            return WebViewAll(
              appBarTitle: appBarTitle,
              videoId: 0,
              subVideoType: 0,
              videoType: 0,
              typeId: 0,
              newPage: RoutesConstant.continueWatchPage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* About Us, Privacy Policy & etc. */
      GoRoute(
        name: RoutesConstant.aboutPrivacyTermsPage,
        path: '/${RoutesConstant.aboutPrivacyTermsPage}',
        builder: (context, state) {
          String newPage = "";
          Map<String, dynamic> extraData = {};
          String? appBarTitle, url;
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            appBarTitle = extraData['title'] as String;
            url = extraData['url'] as String;

            printLog("newPage =====> $newPage");
            if (kIsWeb || Constant.isTV) {
              return WebAboutPrivacyTerms(
                newPage: RoutesConstant.aboutPrivacyTermsPage,
                oldPage: newPage,
                reqText: '',
                appBarTitle: appBarTitle,
                loadURL: url,
              );
            }
            return AboutPrivacyTerms(
              appBarTitle: appBarTitle,
              loadURL: url,
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Login */
      // GoRoute(
      //   name: RoutesConstant.loginSocialPage,
      //   path: '/${RoutesConstant.loginSocialPage}',
      //   builder: (context, state) {
      //     String newPage = "";
      //     if (state.extra != null && state.extra is String) {
      //       newPage = state.extra as String;
      //       printLog("newPage =====> $newPage");
      //       if (kIsWeb || Constant.isTV) {
      //         return WebLoginSocial(
      //           newPage: RoutesConstant.loginSocialPage,
      //           oldPage: newPage,
      //           reqText: '',
      //         );
      //       }
      //       return const LoginSocial();
      //     } else {
      //       return WebErrorPage(state.error!);
      //     }
      //   },
      // ),

      /* Login OTP */
      // GoRoute(
      //   name: RoutesConstant.loginOTPPage,
      //   path: '/${RoutesConstant.loginOTPPage}',
      //   builder: (context, state) {
      //     String newPage = "", mobileNumber = "";
      //     Map<String, dynamic> extraData = {};
      //     if (state.extra != null && state.extra is Map<String, dynamic>) {
      //       extraData = state.extra as Map<String, dynamic>;
      //       newPage = extraData['newpage'] as String;
      //       mobileNumber = extraData['mobile'] as String;
      //       printLog("newPage =======> $newPage");
      //       printLog("mobileNumber ==> $mobileNumber");
      //       if (kIsWeb || Constant.isTV) {
      //         return WebOTPVerify(
      //           mobileNumber,
      //           newPage: RoutesConstant.loginOTPPage,
      //           oldPage: newPage,
      //           reqText: '',
      //         );
      //       }
      //       return OTPVerify(mobileNumber);
      //     } else {
      //       return WebErrorPage(state.error!);
      //     }
      //   },
      // ),

      /* Avatar */
      GoRoute(
        name: RoutesConstant.avatarPage,
        path: '/${RoutesConstant.avatarPage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");

            if (kIsWeb || Constant.isTV) {
              return WebProfileAvatar(
                newPage: RoutesConstant.avatarPage,
                oldPage: newPage,
                reqText: '',
              );
            }
            return const ProfileAvatar();
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Profile */
      GoRoute(
        name: RoutesConstant.myProfilePage,
        path: '/${RoutesConstant.myProfilePage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");

            if (kIsWeb || Constant.isTV) {
              return WebProfile(
                newPage: RoutesConstant.myProfilePage,
                oldPage: newPage,
                reqText: '',
              );
            }
            return const Profile();
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* My Sapce */
      GoRoute(
        name: RoutesConstant.mySpacePage,
        path: '/${RoutesConstant.mySpacePage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");

            if (kIsWeb || Constant.isTV) {
              return WebMySpace(
                newPage: RoutesConstant.mySpacePage,
                oldPage: newPage,
                reqText: '',
              );
            }
            return const MySpace();
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Settings */
      GoRoute(
        name: RoutesConstant.settingsPage,
        path: '/${RoutesConstant.settingsPage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");

            if (kIsWeb || Constant.isTV) {
              return WebSettings(
                newPage: RoutesConstant.settingsPage,
                oldPage: newPage,
                reqText: '',
              );
            }
            return const Settings();
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Edit Profile */
      GoRoute(
        name: RoutesConstant.editProfilePage,
        path: '/${RoutesConstant.editProfilePage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");

            if (kIsWeb || Constant.isTV) {
              return WebProfileEdit(
                newPage: RoutesConstant.editProfilePage,
                oldPage: newPage,
                reqText: '',
              );
            }
            return const ProfileEdit();
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Active TV */
      GoRoute(
        name: RoutesConstant.activeTVPage,
        path: '/${RoutesConstant.activeTVPage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");
            return ActiveTV(
              newPage: RoutesConstant.activeTVPage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Subscription */
      GoRoute(
        name: RoutesConstant.subscriptionPage,
        path: '/${RoutesConstant.subscriptionPage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");

            return Subscription(
              newPage: RoutesConstant.subscriptionPage,
              oldPage: newPage,
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* My Subscription */
      GoRoute(
        name: RoutesConstant.mySubscribePlanPage,
        path: '/${RoutesConstant.mySubscribePlanPage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");

            return MySubscribedPlan(
              newPage: RoutesConstant.mySubscribePlanPage,
              oldPage: newPage,
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Contact Us */
      GoRoute(
        name: RoutesConstant.contactUsPage,
        path: '/${RoutesConstant.contactUsPage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");

            return ContactUs(
              newPage: RoutesConstant.contactUsPage,
              oldPage: newPage,
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* All Payments Page */
      GoRoute(
        name: RoutesConstant.paymentPage,
        path: '/${RoutesConstant.paymentPage}',
        builder: (context, state) {
          String newPage = "";
          Map<String, dynamic> extraData = {};
          final String? payType,
              producerId,
              itemId,
              price,
              itemTitle,
              typeId,
              videoType,
              subVideoType,
              productPackage,
              currency;
          if (state.extra != null && state.extra is Map<String, dynamic>) {
            extraData = state.extra as Map<String, dynamic>;
            newPage = extraData['newpage'] as String;
            itemId = extraData['itemid'] as String;
            producerId = extraData['producerid'] as String;
            payType = extraData['paytype'] as String;
            price = extraData['price'] as String;
            itemTitle = extraData['title'] as String;
            typeId = extraData['typeid'] as String;
            videoType = extraData['videotype'] as String;
            subVideoType = extraData['subvideotype'] as String;
            productPackage = extraData['productpackage'] as String;
            currency = extraData['currency'] as String;

            printLog("newPage =====> $newPage");
            return AllPayment(
              newPage: RoutesConstant.paymentPage,
              oldPage: newPage,
              reqText: '',
              payType: payType,
              producerId: producerId,
              itemId: itemId,
              price: price,
              itemTitle: itemTitle,
              typeId: typeId,
              videoType: videoType,
              subVideoType: subVideoType,
              productPackage: productPackage,
              currency: currency,
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Subscription History */
      GoRoute(
        name: RoutesConstant.subsHistoryPage,
        path: '/${RoutesConstant.subsHistoryPage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");
            return SubscriptionHistory(
              newPage: RoutesConstant.subsHistoryPage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Rent Purchases */
      GoRoute(
        name: RoutesConstant.rentPurchasePage,
        path: '/${RoutesConstant.rentPurchasePage}',
        builder: (context, state) {
          String newPage = "";
          if (state.extra != null && state.extra is String) {
            newPage = state.extra as String;
            printLog("newPage =======> $newPage");
            return MyPurchaselist(
              newPage: RoutesConstant.rentPurchasePage,
              oldPage: newPage,
              reqText: '',
            );
          } else {
            return WebErrorPage(state.error!);
          }
        },
      ),

      /* Payment Success */
      GoRoute(
        name: RoutesConstant.paymentSuccessPage,
        path: '/${RoutesConstant.paymentSuccessPage}',
        builder: (context, state) {
          return const SuccessPage();
        },
      ),

      /* Payment Cancel */
      GoRoute(
        name: RoutesConstant.paymentCancelPage,
        path: '/${RoutesConstant.paymentCancelPage}',
        builder: (context, state) {
          return const CancelPage();
        },
      ),
    ],
    errorBuilder: (context, state) {
      return WebErrorPage(state.error!);
    },
    debugLogDiagnostics: true,
  );
}
