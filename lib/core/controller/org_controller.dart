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

  // dawn 2026-05-15 修复团队长功能不展示：兼容组织角色中文别名。
  String _normalizeOrgRole(String role) {
    final aliases = {
      '业务员': 'GroupManager',
      '团队长': 'TermManager',
    };
    return aliases[role.trim()] ?? role.trim();
  }

  // dawn 2026-05-15 修复团队长功能不展示：统一兼容旧 basic、细分权限码和直加好友角色。
  bool hasPermission(String code) {
    final roles = currentOrgRoles;
    final orgRole = _normalizeOrgRole(currentOrg.role ?? '');
    if (code == 'add_friend' &&
        (orgRole == 'GroupManager' || orgRole == 'TermManager')) {
      return true;
    }
    return roles.contains(code) || roles.contains('basic');
  }

  // dawn 2026-06-26 撤回权限：当前用户组织角色(归一化)。
  String get currentOrgRole => _normalizeOrgRole(currentOrg.role ?? '');

  // 官方账号：超管/后台管理员/群管理员(不含团队长)。用于"官方账号撤回不提示"。
  bool get isOfficialAccount {
    const official = {'SuperAdmin', 'BackendAdmin', 'GroupManager'};
    return official.contains(currentOrgRole);
  }

  // 团队长。
  bool get isTermManager => currentOrgRole == 'TermManager';

  // 撤回消息只允许组织后台"管理员"(GroupManager)。
  bool get canRevokeMessage => currentOrgRole == 'GroupManager';

  // dawn 2026-07-06 组织超管/后台管理员：保留全局撤回(审计)权限，可撤任意群/任意人的消息。
  // 业务员(GroupManager)不在此列——撤别人的消息改按【群角色】(群主/群管理员)判定。
  bool get isOrgSuperAdmin =>
      currentOrgRole == 'SuperAdmin' || currentOrgRole == 'BackendAdmin';

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
