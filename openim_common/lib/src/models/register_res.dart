class RegisterRes {
  String userId;
  String chatToken;
  String imToken;
  String organizationId;
  String? inviteUserId;

  RegisterRes(
      {required this.userId,
      required this.chatToken,
      required this.imToken,
      required this.organizationId,
      this.inviteUserId});

  RegisterRes.fromJson(Map<String, dynamic> json)
      : userId = json['user_id'] as String,
        chatToken = json['chat_token'] as String,
        imToken = json['im_token'] as String,
        organizationId = json['organization_id'] as String,
        inviteUserId = json['invite_user_id'];

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['user_id'] = this.userId;
    data['chat_token'] = this.chatToken;
    data['im_token'] = this.imToken;
    data['organization_id'] = this.organizationId;
    if (this.inviteUserId != null) {
      data['invite_user_id'] = this.inviteUserId;
    }
    return data;
  }
}
