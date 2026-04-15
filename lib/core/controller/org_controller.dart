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

  @override
  void onInit() {
    super.onInit();
    _getOrgList();
    _getRules();
    currentOrgId.listen((value) {
      if (value != null && value != "") {
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
