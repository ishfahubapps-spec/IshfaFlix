import '../model/contentdetailmodel.dart';
import '../pages/contentbyid.dart';
import '../provider/videobyidprovider.dart';
import '../routes/routes_constant.dart';
import '../utils/color.dart';
import '../utils/constant.dart';
import '../utils/dimens.dart';
import '../utils/utils.dart';
import '../widget/mytext.dart';
import '../widget/myusernetworkimg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:responsive_grid_list/responsive_grid_list.dart';

class CastCrew extends StatefulWidget {
  final String? newPage;
  final List<Cast>? castList;
  const CastCrew({required this.castList, required this.newPage, super.key});

  @override
  State<CastCrew> createState() => _CastCrewState();
}

class _CastCrewState extends State<CastCrew> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: Dimens.isBigScreen(context) ? 35 : 20),
        Container(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.only(
            left: Dimens.isBigScreen(context) ? 35 : 12,
            right: Dimens.isBigScreen(context) ? 35 : 12,
          ),
          child: MyText(
            color: titleTextColor,
            text: "castandcrew",
            multilanguage: true,
            textalign: TextAlign.start,
            fontsizeNormal: 17,
            fontsizeWeb: 19,
            fontweight: FontWeight.w500,
            maxline: 1,
            overflow: TextOverflow.ellipsis,
            fontstyle: FontStyle.normal,
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width,
          height: 0.5,
          color: grayDark,
          margin: EdgeInsets.fromLTRB(
            Dimens.isBigScreen(context) ? 35 : 12,
            5,
            Dimens.isBigScreen(context) ? 35 : 12,
            18,
          ),
        ),
        _buildCAndCLayout(),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildCAndCLayout() {
    if (widget.castList != null && (widget.castList?.length ?? 0) > 0) {
      return Container(
        padding: EdgeInsets.only(
          left: Dimens.isBigScreen(context) ? 35 : 12,
          right: Dimens.isBigScreen(context) ? 35 : 12,
        ),
        child: ResponsiveGridList(
          minItemWidth: Dimens.isBigScreen(context)
              ? Dimens.widthCastWeb
              : Dimens.widthCast,
          verticalGridSpacing: 8,
          horizontalGridSpacing: 8,
          minItemsPerRow: 3,
          maxItemsPerRow: 15,
          listViewBuilderOptions: ListViewBuilderOptions(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
          children: List.generate(
            (widget.castList?.length ?? 0),
            (position) {
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                focusColor: white,
                onTap: () async {
                  printLog("Item Clicked! => $position");
                  final videoByIDProvider =
                      Provider.of<VideoByIDProvider>(context, listen: false);
                  videoByIDProvider.setLoading(true);
                  if (!mounted) return;
                  if (kIsWeb || Constant.isTV) {
                    context.go(
                      "/${RoutesConstant.videoByCastPage}/${(widget.castList?[position].id ?? 0)}",
                      extra: {
                        'newpage': widget.newPage.toString(),
                        'itemid':
                            (widget.castList?[position].id ?? 0).toString(),
                        'title': widget.castList?[position].name ?? '',
                        'layouttype': 'ByCast',
                      },
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) {
                        return ContentByID(
                          widget.castList?[position].id ?? 0,
                          widget.castList?[position].name ?? "",
                          'ByCast',
                        );
                      }),
                    );
                  }
                },
                child: Column(
                  children: <Widget>[
                    SizedBox(
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
                          imageUrl: widget.castList?[position].image ?? "",
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(2),
                      width: Dimens.isBigScreen(context)
                          ? Dimens.widthCastWeb
                          : Dimens.widthCast,
                      child: MyText(
                        color: titleTextColor,
                        multilanguage: false,
                        text: widget.castList?[position].name ?? "",
                        fontstyle: FontStyle.normal,
                        maxline: 1,
                        fontsizeNormal: 12,
                        fontsizeWeb: 15,
                        fontweight: FontWeight.w500,
                        overflow: TextOverflow.ellipsis,
                        textalign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
