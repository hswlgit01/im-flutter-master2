
class OrgRule {
  String? id;
  String? orgId;
  String? role;
  String? permissionCode;
  String? createdAt;
  String? updatedAt;

  OrgRule({this.id, this.orgId, this.role, this.permissionCode, this.createdAt, this.updatedAt});

  OrgRule.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["org_id"] is String) {
      orgId = json["org_id"];
    }
    if(json["role"] is String) {
      role = json["role"];
    }
    if(json["permission_code"] is String) {
      permissionCode = json["permission_code"];
    }
    if(json["created_at"] is String) {
      createdAt = json["created_at"];
    }
    if(json["updated_at"] is String) {
      updatedAt = json["updated_at"];
    }
  }

  static List<OrgRule> fromList(List<Map<String, dynamic>> list) {
    return list.map(OrgRule.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["org_id"] = orgId;
    _data["role"] = role;
    _data["permission_code"] = permissionCode;
    _data["created_at"] = createdAt;
    _data["updated_at"] = updatedAt;
    return _data;
  }
}