import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:openim/pages/contacts/group_profile_panel/group_profile_panel_logic.dart';
import 'package:openim/routes/app_navigator.dart';
import 'package:openim_common/openim_common.dart';
import 'package:scan/scan.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();

  static Future<String?> scanQrcode() async {
    final String? reslut = await Get.to(const ScanPage());
    return reslut;
  }
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  final ScanController controller = ScanController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      controller.resume();
    }
  }

  void onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction == 0) {
      controller.pause();
    } else {
      controller.resume();
    }
  }

  onTapAlbum() async {
    final assets = await AssetPicker.pickAssets(Get.context!,
        pickerConfig: const AssetPickerConfig(
            requestType: RequestType.image, maxAssets: 1));
    if (assets != null && assets.isNotEmpty) {
      final asset = assets.first;
      final file = await asset.file; // 获取图片文件
      if (file != null) {
        final path = file.path; // 获取文件路径
        final qrCode = await Scan.parse(path); // 解析二维码
        if (qrCode != null) {
          Get.back(result: qrCode);
        }
      }
    }
  }

  onToMyQrcode() {
    AppNavigator.startMyQrcode();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: VisibilityDetector(
            key: const Key('ScanViewVisibility'),
            onVisibilityChanged: onVisibilityChanged,
            child: ScanView(
              controller: controller,
              scanAreaScale: .7,
              scanLineColor: Colors.green.shade400,
              onCapture: (data) {
                Get.back(result: data);
              },
            ),
          ),
        ),
        Positioned(
            child: TitleBar.back(
          backgroundColor: Colors.transparent,
          backIconColor: Colors.white,
        )),
        Positioned(
          bottom: 30.h,
          left: 30.w,
          right: 30.w,
          child: SafeArea(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ImageRes.mineQr.toImage
                ..color = Colors.white
                ..width = 28.w
                ..onTap = onToMyQrcode,
              ImageRes.chatSearchPic.toImage
                ..color = Colors.white
                ..width = 40.w
                ..onTap = onTapAlbum
            ],
          )),
        )
      ],
    );
  }
}

class ScanUtil {
  static scan() async {
    final result = await ScanPage.scanQrcode();
    if (result != null) {
      if (result.startsWith(Config.friendScheme)) {
        final id = result.substring(Config.friendScheme.length);
        // 处理提取的id，跳转到添加好友页面
        var list = await LoadingView.singleton.wrap(
          asyncFunction: () => Apis.getUserFullInfo(
            userIDList: [id],
            pageNumber: 1,
            showNumber: 1,
          ),
        );
        if (list != null && list.isNotEmpty) {
          final info = list.first;
          AppNavigator.startUserProfilePane(
              userID: info.userID!,
              nickname: info.nickname,
              faceURL: info.faceURL,
              account: info.account!);
        } else {
          // 未查询到好友，弹窗提示
          Get.dialog(
            CustomDialog(
              title: StrRes.noFoundUser,
              rightText: StrRes.confirm,
              showLeft: false,
              onTapRight: () {
                Get.back(); // 关闭弹窗
              },
            ),
            barrierDismissible: false,
          );
        }
      } else if (result.startsWith(Config.groupScheme)) {
        final id = result.substring(Config.groupScheme.length);
        AppNavigator.startGroupProfilePanel(
          groupID: id,
          joinGroupMethod: JoinGroupMethod.qrcode,
        );
      }
    }
  }
}
