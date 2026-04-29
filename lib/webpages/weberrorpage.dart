import '../utils/color.dart';
import '../widget/myimage.dart';
import '../widget/mytext.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WebErrorPage extends StatelessWidget {
  const WebErrorPage(this.error, {super.key});
  final Exception error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBgColor,
        title: MyText(
          multilanguage: false,
          color: redColor,
          text: "404 Page Not Found!",
          maxline: 2,
          textalign: TextAlign.center,
          fontstyle: FontStyle.normal,
          fontsizeNormal: 18,
          fontsizeWeb: 20,
          overflow: TextOverflow.ellipsis,
          fontweight: FontWeight.w600,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MyImage(
              height: 230,
              fit: BoxFit.contain,
              imagePath: "ic_404.png",
            ),
            const SizedBox(height: 20),
            SelectableText(error.toString()),
            MyText(
              multilanguage: false,
              color: white,
              text: error.toString(),
              maxline: 10,
              textalign: TextAlign.center,
              fontstyle: FontStyle.normal,
              fontsizeNormal: 15,
              fontsizeWeb: 17,
              overflow: TextOverflow.ellipsis,
              fontweight: FontWeight.w500,
            ),
            TextButton(
              onPressed: () => context.go('/'),
              child: MyText(
                multilanguage: false,
                color: colorPrimary,
                text: "Go to Home",
                maxline: 1,
                textalign: TextAlign.center,
                fontstyle: FontStyle.normal,
                fontsizeNormal: 18,
                fontsizeWeb: 20,
                overflow: TextOverflow.ellipsis,
                fontweight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
