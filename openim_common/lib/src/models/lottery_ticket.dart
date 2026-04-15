class LotteryTicket {
  String? id;
  String? imServerUserId;
  String? lotteryId;
  bool? use;
  String? usedAt;
  String? expiredAt;
  String? createdAt;
  String? updatedAt;
  LotteryInfo? lotteryInfo;

  LotteryTicket(
      {this.id,
      this.imServerUserId,
      this.lotteryId,
      this.use,
      this.usedAt,
      this.expiredAt,
      this.createdAt,
      this.updatedAt,
      this.lotteryInfo});

  LotteryTicket.fromJson(Map<String, dynamic> json) {
    if (json["id"] is String) {
      id = json["id"];
    }
    if (json["im_server_user_id"] is String) {
      imServerUserId = json["im_server_user_id"];
    }
    if (json["lottery_id"] is String) {
      lotteryId = json["lottery_id"];
    }
    if (json["use"] is bool) {
      use = json["use"];
    }
    if (json["used_at"] is String) {
      usedAt = json["used_at"];
    }
    if (json["expired_at"] is String) {
      expiredAt = json["expired_at"];
    }
    if (json["created_at"] is String) {
      createdAt = json["created_at"];
    }
    if (json["updated_at"] is String) {
      updatedAt = json["updated_at"];
    }
    if (json["lottery_info"] is Map) {
      lotteryInfo = json["lottery_info"] == null
          ? null
          : LotteryInfo.fromJson(json["lottery_info"]);
    }
  }

  static List<LotteryTicket> fromList(List<Map<String, dynamic>> list) {
    return list.map(LotteryTicket.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["im_server_user_id"] = imServerUserId;
    _data["lottery_id"] = lotteryId;
    _data["use"] = use;
    _data["used_at"] = usedAt;
    _data["expired_at"] = expiredAt;
    _data["created_at"] = createdAt;
    _data["updated_at"] = updatedAt;
    if (lotteryInfo != null) {
      _data["lottery_info"] = lotteryInfo?.toJson();
    }
    return _data;
  }
}

class LotteryInfo {
  String? id;
  String? orgId;
  String? name;
  String? desc;
  int? validDays;
  String? createdAt;
  String? updatedAt;

  LotteryInfo(
      {this.id,
      this.orgId,
      this.name,
      this.desc,
      this.validDays,
      this.createdAt,
      this.updatedAt});

  LotteryInfo.fromJson(Map<String, dynamic> json) {
    if (json["id"] is String) {
      id = json["id"];
    }
    if (json["org_id"] is String) {
      orgId = json["org_id"];
    }
    if (json["name"] is String) {
      name = json["name"];
    }
    if (json["desc"] is String) {
      desc = json["desc"];
    }
    if (json["valid_days"] is int) {
      validDays = json["valid_days"];
    }
    if (json["created_at"] is String) {
      createdAt = json["created_at"];
    }
    if (json["updated_at"] is String) {
      updatedAt = json["updated_at"];
    }
  }

  static List<LotteryInfo> fromList(List<Map<String, dynamic>> list) {
    return list.map(LotteryInfo.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["org_id"] = orgId;
    _data["name"] = name;
    _data["desc"] = desc;
    _data["valid_days"] = validDays;
    _data["created_at"] = createdAt;
    _data["updated_at"] = updatedAt;
    return _data;
  }
}
