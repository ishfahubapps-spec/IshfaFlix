import '../provider/avatarprovider.dart';
import '../shimmer/shimmerutils.dart';
import '../utils/dimens.dart';
import '../utils/utils.dart';
import '../webpages/webcomman.dart';
import '../widget/myusernetworkimg.dart';
import '../widget/nodata.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

class WebProfileAvatar extends StatefulWidget {
  final String? newPage, oldPage;
  final dynamic reqText;
  const WebProfileAvatar({
    required this.newPage,
    required this.oldPage,
    required this.reqText,
    super.key,
  });

  @override
  State<WebProfileAvatar> createState() => _WebProfileAvatarState();
}

class _WebProfileAvatarState extends State<WebProfileAvatar> {
  late AvatarProvider avatarProvider;
  String? pickedImageId, pickedImageUrl;

  @override
  void initState() {
    super.initState();
    _getData();
  }

  Future<void> _getData() async {
    avatarProvider = Provider.of<AvatarProvider>(context, listen: false);
    await avatarProvider.getAvatar();
    Future.delayed(Duration.zero).then((value) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    avatarProvider.clearProvider();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebComman(
      newPage: widget.newPage,
      oldPage: widget.oldPage,
      reqText: '',
      newChild: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            Dimens.isBigScreen(context) ? 40 : 25,
            (Dimens.homeTabHeight + 20),
            Dimens.isBigScreen(context) ? 40 : 25,
            25,
          ),
          child: _buildPage(),
        ),
      ),
    );
  }

  Widget _buildPage() {
    if (avatarProvider.loading) {
      return ShimmerUtils.buildAvatarGridWebShimmer(
          context,
          (Dimens.isBigScreen(context))
              ? Dimens.heightAvatarWeb
              : Dimens.heightAvatar,
          (Dimens.isBigScreen(context))
              ? Dimens.widthAvatarWeb
              : Dimens.widthAvatar,
          15,
          50);
    } else {
      if (avatarProvider.avatarModel.status == 200 &&
          avatarProvider.avatarModel.result != null) {
        if ((avatarProvider.avatarModel.result?.length ?? 0) > 0) {
          return ResponsiveGridList(
            minItemWidth: (Dimens.isBigScreen(context))
                ? Dimens.widthAvatarWeb
                : Dimens.widthAvatar,
            verticalGridSpacing: 15,
            horizontalGridSpacing: 15,
            minItemsPerRow: 3,
            maxItemsPerRow: 15,
            listViewBuilderOptions: ListViewBuilderOptions(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
            children: List.generate(
              (avatarProvider.avatarModel.result?.length ?? 0),
              (position) {
                return InkWell(
                  borderRadius: BorderRadius.circular(
                      ((Dimens.isBigScreen(context))
                              ? Dimens.widthAvatarWeb
                              : Dimens.widthAvatar) /
                          2),
                  onTap: () {
                    printLog("Clicked position =====> $position");
                    pickedImageId = avatarProvider
                            .avatarModel.result?[position].id
                            .toString() ??
                        "0";
                    pickedImageUrl = avatarProvider
                            .avatarModel.result?[position].image
                            .toString() ??
                        "0";
                    printLog("pickedImageId =====> $pickedImageId");
                    printLog("pickedImageUrl ====> $pickedImageUrl");
                    if (GoRouter.of(context).canPop()) {
                      GoRouter.of(context)
                          .pop([pickedImageId ?? "", pickedImageUrl ?? ""]);
                    }
                  },
                  child: Container(
                    width: (Dimens.isBigScreen(context))
                        ? Dimens.widthAvatarWeb
                        : Dimens.widthAvatar,
                    height: (Dimens.isBigScreen(context))
                        ? Dimens.heightAvatarWeb
                        : Dimens.heightAvatar,
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                          ((Dimens.isBigScreen(context))
                                  ? Dimens.widthAvatarWeb
                                  : Dimens.widthAvatar) /
                              2),
                      child: MyUserNetworkImage(
                        imageUrl: avatarProvider
                                .avatarModel.result?[position].image
                                .toString() ??
                            "",
                        fit: BoxFit.cover,
                        height: MediaQuery.of(context).size.height,
                        width: MediaQuery.of(context).size.width,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        } else {
          return const NoData(title: '', subTitle: '');
        }
      } else {
        return const NoData(title: '', subTitle: '');
      }
    }
  }
}
