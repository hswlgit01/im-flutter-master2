import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openim_common/openim_common.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_openim_sdk/flutter_openim_sdk.dart';

class IdentityVerifyPage extends StatefulWidget {
  final IdentityVerifyInfo? initialInfo;
  
  const IdentityVerifyPage({super.key, this.initialInfo});

  @override
  State<IdentityVerifyPage> createState() => _IdentityVerifyPageState();
}

class _IdentityVerifyPageState extends State<IdentityVerifyPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idCardController = TextEditingController();

  File? _idCardFrontFile;
  File? _idCardBackFile;
  String? _idCardFrontUrl;
  String? _idCardBackUrl;

  final ImagePicker _picker = ImagePicker();
  bool _isSubmitting = false;

  // 是否为审核中状态（status = 1）
  bool get _isReviewing => widget.initialInfo?.status == 1;

  // 是否为已认证状态（status = 2）
  bool get _isVerified => widget.initialInfo?.status == 2;

  // 是否为已拒绝状态（status = 3）
  bool get _isRejected => widget.initialInfo?.status == 3;

  // 是否为只读模式（审核中或已认证）
  bool get _isReadOnly => _isReviewing || _isVerified;

  // 检查表单是否完整
  bool get _isFormComplete {
    return _nameController.text.trim().isNotEmpty &&
           _idCardController.text.trim().isNotEmpty &&
           (_idCardFrontFile != null || _idCardFrontUrl != null) &&
           (_idCardBackFile != null || _idCardBackUrl != null);
  }
  
  @override
  void initState() {
    super.initState();
    if (widget.initialInfo != null) {
      _nameController.text = widget.initialInfo!.realName ?? '';
      _idCardController.text = widget.initialInfo!.idCardNumber ?? '';
      _idCardFrontUrl = widget.initialInfo!.idCardFront;
      _idCardBackUrl = widget.initialInfo!.idCardBack;
    }

    // 监听文本输入变化以更新按钮状态
    _nameController.addListener(_updateButtonState);
    _idCardController.addListener(_updateButtonState);
  }

  void _updateButtonState() {
    setState(() {
      // 触发重建以更新按钮状态
    });
  }
  
  @override
  void dispose() {
    _nameController.removeListener(_updateButtonState);
    _idCardController.removeListener(_updateButtonState);
    _nameController.dispose();
    _idCardController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // 按钮是否可用：可编辑 && 表单完整 && 未提交中
    final bool canSubmit = !_isReadOnly && _isFormComplete && !_isSubmitting;

    return Scaffold(
      appBar: TitleBar.back(
        title: StrRes.identityVerify ?? '身份认证',
        right: _isReadOnly ? null : TextButton(
          onPressed: canSubmit ? _submitVerify : null,
          child: Text(
            StrRes.submitVerify ?? '提交',
            style: TextStyle(
              color: canSubmit ? Color(0xFF0089FF) : Color(0xFF999999),
              fontSize: 17.sp,
            ),
          ),
        ),
      ),
      backgroundColor: Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态提示（审核中或已认证或已拒绝时显示）
            if (_isReviewing) ...[
              _buildReviewingStatusCard(),
              SizedBox(height: 20.h),
            ],
            if (_isVerified) ...[
              _buildVerifiedStatusCard(),
              SizedBox(height: 20.h),
            ],
            if (_isRejected) ...[
              _buildRejectedStatusCard(),
              SizedBox(height: 20.h),
            ],

            // 提示信息
            _buildTipsCard(),
            SizedBox(height: 20.h),

            // 真实姓名
            _buildInputField(
              label: StrRes.realName ?? '真实姓名',
              hintText: StrRes.pleaseEnterRealName ?? '请输入与身份证一致的真实姓名',
              controller: _nameController,
              enabled: !_isReadOnly,
            ),
            SizedBox(height: 20.h),

            // 身份证号
            _buildInputField(
              label: StrRes.idCardNumber ?? '身份证号',
              hintText: StrRes.pleaseEnterIdCard ?? '请输入身份证号码',
              controller: _idCardController,
              isIdCard: true,
              enabled: !_isReadOnly,
            ),
            SizedBox(height: 20.h),
            
            // 身份证正面
            _buildUploadCard(
              label: StrRes.idCardFront ?? '身份证正面',
              imageFile: _idCardFrontFile,
              imageUrl: _idCardFrontUrl,
              isFront: true,
            ),
            SizedBox(height: 20.h),
            
            // 身份证反面
            _buildUploadCard(
              label: StrRes.idCardBack ?? '身份证反面',
              imageFile: _idCardBackFile,
              imageUrl: _idCardBackUrl,
              isFront: false,
            ),
            SizedBox(height: 40.h),
            
            // 提交按钮
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
  
  // 提示信息卡片
  Widget _buildTipsCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Color(0xFFE8EAEF),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16.w,
                color: Color(0xFF0089FF),
              ),
              SizedBox(width: 4.w),
              Text(
                StrRes.verifyTipsTitle ?? '认证须知',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Color(0xFF0089FF),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            StrRes.verifyTipsContent ?? '1. 请确保信息真实有效\n2. 身份证照片需清晰可见\n3. 审核通常需要1-3个工作日\n4. 信息仅用于身份验证，严格保密',
            style: TextStyle(
              fontSize: 12.sp,
              color: Color(0xFF0C1C33),
            ),
          ),
        ],
      ),
    );
  }

  // 审核状态提示卡片
  Widget _buildReviewingStatusCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: Color(0xFFFFD591),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            size: 20.w,
            color: Color(0xFFFA8C16),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '审核中',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFA8C16),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '您的身份认证申请正在审核中，暂时无法修改信息',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Color(0xFF8C6E3F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 已认证状态提示卡片
  Widget _buildVerifiedStatusCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Color(0xFFF6FFED),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: Color(0xFFB7EB8F),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 20.w,
            color: Color(0xFF52C41A),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已认证',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF52C41A),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '您已通过实名认证',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Color(0xFF389E0D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 已拒绝状态提示卡片
  Widget _buildRejectedStatusCard() {
    final rejectReason = widget.initialInfo?.rejectReason ?? '未通过审核';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(
          color: Color(0xFFFFCCC7),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cancel,
            size: 20.w,
            color: Color(0xFFFF4D4F),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '审核未通过',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF4D4F),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '拒绝原因：$rejectReason',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Color(0xFFCF1322),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '请根据拒绝原因修改后重新提交',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Color(0xFF8C8C8C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 输入框
  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool isIdCard = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 17.sp,
            color: Color(0xFF0C1C33),
          ),
        ),
        SizedBox(height: 10.h),
        Container(
          height: 44.h,
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(color: Color(0xFFE8EAEF)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
              isDense: true,
              // 44.h 固定高度下，vertical padding 太大会让文本视觉上偏上，这里调小一点更居中
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              hintStyle: TextStyle(
                fontSize: 16.sp,
                color: Color(0xFF999999),
              ),
            ),
            style: TextStyle(
              fontSize: 16.sp,
              color: enabled ? Color(0xFF0C1C33) : Color(0xFF999999),
            ),
            keyboardType: isIdCard ? TextInputType.number : TextInputType.text,
            // 身份证号输入限制：只允许数字和X
            inputFormatters: isIdCard
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]'))]
                : null,
          ),
        ),
      ],
    );
  }
  
  // 上传身份证卡片
  Widget _buildUploadCard({
    required String label,
    required File? imageFile,
    required String? imageUrl,
    required bool isFront,
  }) {
    final hasImage = imageFile != null || imageUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 17.sp,
            color: Color(0xFF0C1C33),
          ),
        ),
        SizedBox(height: 10.h),

        GestureDetector(
          onTap: _isReadOnly ? null : () => _pickImage(isFront),
          child: Container(
            width: double.infinity,
            height: 180.h,
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(
                color: Color(0xFFE8EAEF),
                width: 1,
              ),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6.r),
                    child: imageFile != null
                        ? Image.file(
                            imageFile,
                            fit: BoxFit.cover,
                          )
                        : (imageUrl != null && _isValidImageUrl(imageUrl)
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildImagePlaceholder();
                                },
                              )
                            : _buildImagePlaceholder()),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 40.w,
                        color: Color(0xFF999999),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        StrRes.clickToUpload ?? '点击上传',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        SizedBox(height: 8.h),
        Text(
          isFront
              ? (StrRes.uploadFrontHint ?? '请上传身份证人像面')
              : (StrRes.uploadBackHint ?? '请上传身份证国徽面'),
          style: TextStyle(
            fontSize: 12.sp,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }

  // 验证图片URL是否有效
  bool _isValidImageUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  // 图片占位符
  Widget _buildImagePlaceholder() {
    return Container(
      color: Color(0xFFF0F0F0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image,
            size: 50.w,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 8.h),
          Text(
            '图片加载中',
            style: TextStyle(
              fontSize: 14.sp,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
  
  // 提交按钮
  Widget _buildSubmitButton() {
    // 只读模式（审核中或已认证）时不显示底部提交按钮
    if (_isReadOnly) {
      return SizedBox.shrink();
    }

    // 按钮是否可用：表单完整 && 未提交中
    final bool canSubmit = _isFormComplete && !_isSubmitting;

    return SizedBox(
      width: double.infinity,
      height: 44.h,
      child: ElevatedButton(
        onPressed: canSubmit ? _submitVerify : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSubmit ? Color(0xFF0089FF) : Color(0xFFCCCCCC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6.r),
          ),
        ),
        child: Text(
          StrRes.submitVerify ?? '提交认证',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
  
  /// 将相册/相机返回的临时文件复制到应用文档目录，避免 cache 下 scaled 文件在提交前被删除。
  Future<File?> _persistPickedImage(XFile xFile) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = xFile.name.contains('.')
          ? xFile.name.substring(xFile.name.lastIndexOf('.'))
          : '.jpg';
      final name =
          'identity_${DateTime.now().millisecondsSinceEpoch}_${xFile.name.hashCode & 0x7fffffff}$ext';
      final dest = File('${dir.path}/$name');

      // Android 某些机型上 xFile.path 指向的 scaled_mmexport 临时图无法直接 open，
      // saveTo 由插件侧处理复制，成功率比 Dart 层 readAsBytes 更高。
      try {
        await xFile.saveTo(dest.path);
        if (await dest.exists() && await dest.length() > 0) {
          return dest;
        }
      } catch (e) {
        Logger.print('identity_verify saveTo failed: $e');
      }

      try {
        final source = File(xFile.path);
        if (await source.exists()) {
          final copied = await source.copy(dest.path);
          if (await copied.exists() && await copied.length() > 0) {
            return copied;
          }
        }
      } catch (e) {
        Logger.print('identity_verify file copy failed: $e');
      }

      final bytes = await xFile.readAsBytes();
      if (bytes.isEmpty) return null;
      await dest.writeAsBytes(bytes, flush: true);
      return dest;
    } catch (e) {
      Logger.print('identity_verify persist image failed: $e');
      return null;
    }
  }

  // 选择图片
  Future<void> _pickImage(bool isFront) async {
    final source = await Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text(StrRes.takePhoto ?? '拍照'),
                onTap: () => Get.back(result: ImageSource.camera),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text(StrRes.fromAlbum ?? '从相册选择'),
                onTap: () => Get.back(result: ImageSource.gallery),
              ),
              Divider(height: 1),
              ListTile(
                leading: Icon(Icons.cancel),
                title: Text(StrRes.cancel ?? '取消', style: TextStyle(color: Colors.red)),
                onTap: () => Get.back(),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (source == null) return;
    
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        // image_picker 在 Android 上常用 cache/scaled_*.jpg，易被系统清理；提交时再读会报 no such file。
        final file = await _persistPickedImage(image);
        if (!mounted) return;
        if (file == null) {
          Get.snackbar('错误', '保存所选图片失败，请重试');
          return;
        }
        setState(() {
          if (isFront) {
            _idCardFrontFile = file;
            _idCardFrontUrl = null;
          } else {
            _idCardBackFile = file;
            _idCardBackUrl = null;
          }
        });
      }
    } catch (e) {
      Get.snackbar('错误', '选择图片失败: $e');
    }
  }
  
  // 身份证验证函数
  bool _validateIdCard(String idCard) {
    if (idCard.length != 18) return false;
    
    // 简单验证：前17位数字，最后一位数字或X
    final pattern = RegExp(r'^\d{17}[\dXx]$');
    if (!pattern.hasMatch(idCard)) return false;
    
    return true;
  }
  
  // 提交验证
  void _submitVerify() async {
    // 验证表单
    if (_nameController.text.isEmpty) {
      Get.snackbar('提示', StrRes.pleaseEnterRealName ?? '请输入真实姓名');
      return;
    }
    
    if (_idCardController.text.isEmpty) {
      Get.snackbar('提示', StrRes.pleaseEnterIdCard ?? '请输入身份证号');
      return;
    }
    
    // 验证身份证格式
    if (!_validateIdCard(_idCardController.text)) {
      Get.snackbar('提示', '身份证格式不正确');
      return;
    }
    
    if (_idCardFrontFile == null && _idCardFrontUrl == null) {
      Get.snackbar('提示', StrRes.uploadFrontHint ?? '请上传身份证正面照片');
      return;
    }
    
    if (_idCardBackFile == null && _idCardBackUrl == null) {
      Get.snackbar('提示', StrRes.uploadBackHint ?? '请上传身份证反面照片');
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. 上传图片（如果有新图片）
      String? frontUrl = _idCardFrontUrl;
      String? backUrl = _idCardBackUrl;

      // 上传身份证正面
      if (_idCardFrontFile != null) {
        if (!await _idCardFrontFile!.exists()) {
          throw StateError('身份证正面文件已失效，请重新选择照片');
        }
        final result = await LoadingView.singleton.wrap(
          asyncFunction: () => OpenIM.iMManager.uploadFile(
            id: 'identity_front_${DateTime.now().millisecondsSinceEpoch}',
            filePath: _idCardFrontFile!.path,
            fileName: _idCardFrontFile!.path.split('/').last,
          ),
        );
        if (result is String) {
          final data = jsonDecode(result);
          frontUrl = data['url'];
        }
      }

      // 上传身份证反面
      if (_idCardBackFile != null) {
        if (!await _idCardBackFile!.exists()) {
          throw StateError('身份证反面文件已失效，请重新选择照片');
        }
        final result = await LoadingView.singleton.wrap(
          asyncFunction: () => OpenIM.iMManager.uploadFile(
            id: 'identity_back_${DateTime.now().millisecondsSinceEpoch}',
            filePath: _idCardBackFile!.path,
            fileName: _idCardBackFile!.path.split('/').last,
          ),
        );
        if (result is String) {
          final data = jsonDecode(result);
          backUrl = data['url'];
        }
      }

      // 2. 调用真实 API 提交认证信息
      final result = await LoadingView.singleton.wrap(
        asyncFunction: () => Apis.submitIdentity(
          realName: _nameController.text.trim(),
          idCardNumber: _idCardController.text.trim(),
          idCardFront: frontUrl!,
          idCardBack: backUrl!,
        ),
      );

      // 3. 提交成功，构建返回信息
      final newInfo = IdentityVerifyInfo(
        status: result['status'] ?? 1, // 审核中
        realName: _nameController.text.trim(),
        idCardNumber: _idCardController.text.trim(),
        idCardFront: frontUrl,
        idCardBack: backUrl,
        applyTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // 4. 返回结果
      Get.back(result: newInfo);
      Get.snackbar('成功', StrRes.submitSuccessMsg ?? '身份认证已提交，请等待审核');

    } catch (e) {
      Get.snackbar('错误', '${StrRes.submitFailed ?? '提交失败'}: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
