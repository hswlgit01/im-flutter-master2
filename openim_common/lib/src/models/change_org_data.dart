class ChangeOrgData {
  String? orgId;
  String? imToken;
  String? imServerUserId;

  ChangeOrgData({this.orgId, this.imToken, this.imServerUserId});

  ChangeOrgData.fromJson(Map<String, dynamic> json) {
    orgId = json['org_id'];
    imToken = json['im_token'];
    imServerUserId = json['im_server_user_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['org_id'] = this.orgId;
    data['im_token'] = this.imToken;
    data['im_server_user_id'] = this.imServerUserId;
    return data;
  }
}
