import 'package:get/get.dart';
import 'package:openim_common/openim_common.dart';

class OrgController extends GetxService {
  final orgList = <OrgData>[].obs;
  final currentOrgId = DataSp.getOrgId().obs;
  final orgRules = <OrgRule>[].obs;

  OrgData get currentOrg {
    return orgList.firstWhere(
      (org) => org.organizationId == currentOrgId.value,
      orElse: () => OrgData(),
    );
  }

  List<String> get currentOrgRoles {
    return orgRules
        .where((rule) => rule.orgId == currentOrgId.value)
        .map((rule) => rule.permissionCode ?? "")
        .toList();
  }

  // dawn 2026-05-15 修复团队长功能不展示：统一兼容旧 basic、细分权限码和直加好友角色。
  bool hasPermission(String code) {
    final roles = currentOrgRoles;
    final orgRole = currentOrg.role ?? '';
    if (code == 'add_friend' &&
        (orgRole == 'GroupManager' || orgRole == 'TermManager')) {
      return true;
    }
    return roles.contains(code) || roles.contains('basic');
  }

  bool get canAddFriend => hasPermission('add_friend');
  bool get canCreateGroup => hasPermission('create_group');
  bool get canSendFile => hasPermission('send_file');
  bool get canSendBusinessCard => hasPermission('send_business_card');
  bool get canModifyNickname => hasPermission('modify_nickname');

  @override
  void onInit() {
    super.onInit();
    _getOrgList();
    _getRules();
    currentOrgId.listen((value) {
      if (value != "") {
        _getRules();
      }
    });
  }

  _getOrgList() async {
    final allOrgRes = await Apis.getSelfAllOrg();
    orgList.value = allOrgRes.data ?? [];
  }

  _getRules() async {
    final orgRule = await Apis.getSelfOrgRules();
    orgRules.value = orgRule;
  }

  refreshOrgList() {
    _getOrgList();
  }

  refreshOrg() {
    refreshOrgList();
    currentOrgId.value = DataSp.getOrgId();
    _getRules();
  }

  refreshRules() {
    _getRules();
  }

  resetOrg() {
    orgList.clear();
    currentOrgId.value = '';
    DataSp.putOrgId('');
  }
}
