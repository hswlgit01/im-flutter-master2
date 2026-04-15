
class Lottery {
  String? id;
  String? imServerUserId;
  String? lotteryId;
  String? lotteryUserTicketId;
  String? winTime;
  bool? isWin;
  String? rewardId;
  int? status;
  String? createdAt;
  String? updatedAt;
  RewardInfo? rewardInfo;

  Lottery({this.id, this.imServerUserId, this.lotteryId, this.lotteryUserTicketId, this.winTime, this.isWin, this.rewardId, this.status, this.createdAt, this.updatedAt, this.rewardInfo});

  Lottery.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["im_server_user_id"] is String) {
      imServerUserId = json["im_server_user_id"];
    }
    if(json["lottery_id"] is String) {
      lotteryId = json["lottery_id"];
    }
    if(json["lottery_user_ticket_id"] is String) {
      lotteryUserTicketId = json["lottery_user_ticket_id"];
    }
    if(json["win_time"] is String) {
      winTime = json["win_time"];
    }
    if(json["is_win"] is bool) {
      isWin = json["is_win"];
    }
    if(json["reward_id"] is String) {
      rewardId = json["reward_id"];
    }
    if(json["status"] is int) {
      status = json["status"];
    }
    if(json["created_at"] is String) {
      createdAt = json["created_at"];
    }
    if(json["updated_at"] is String) {
      updatedAt = json["updated_at"];
    }
    if(json["reward_info"] is Map) {
      rewardInfo = json["reward_info"] == null ? null : RewardInfo.fromJson(json["reward_info"]);
    }
  }

  static List<Lottery> fromList(List<Map<String, dynamic>> list) {
    return list.map(Lottery.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["im_server_user_id"] = imServerUserId;
    _data["lottery_id"] = lotteryId;
    _data["lottery_user_ticket_id"] = lotteryUserTicketId;
    _data["win_time"] = winTime;
    _data["is_win"] = isWin;
    _data["reward_id"] = rewardId;
    _data["status"] = status;
    _data["created_at"] = createdAt;
    _data["updated_at"] = updatedAt;
    if(rewardInfo != null) {
      _data["reward_info"] = rewardInfo?.toJson();
    }
    return _data;
  }
}

class RewardInfo {
  String? id;
  String? createAt;
  bool? entity;
  String? img;
  String? name;
  String? orgId;
  String? remark;
  int? status;
  String? type;

  RewardInfo({this.id, this.createAt, this.entity, this.img, this.name, this.orgId, this.remark, this.status, this.type});

  RewardInfo.fromJson(Map<String, dynamic> json) {
    if(json["_id"] is String) {
      id = json["_id"];
    }
    if(json["create_at"] is String) {
      createAt = json["create_at"];
    }
    if(json["entity"] is bool) {
      entity = json["entity"];
    }
    if(json["img"] is String) {
      img = json["img"];
    }
    if(json["name"] is String) {
      name = json["name"];
    }
    if(json["org_id"] is String) {
      orgId = json["org_id"];
    }
    if(json["remark"] is String) {
      remark = json["remark"];
    }
    if(json["status"] is int) {
      status = json["status"];
    }
    if(json["type"] is String) {
      type = json["type"];
    }
  }

  static List<RewardInfo> fromList(List<Map<String, dynamic>> list) {
    return list.map(RewardInfo.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["_id"] = id;
    _data["create_at"] = createAt;
    _data["entity"] = entity;
    _data["img"] = img;
    _data["name"] = name;
    _data["org_id"] = orgId;
    _data["remark"] = remark;
    _data["status"] = status;
    _data["type"] = type;
    return _data;
  }
}

// 轮盘抽奖详情模型
class LotteryDetail {
  String? id;
  String? name;
  String? desc;
  List<LotteryConfig>? lotteryConfig;

  LotteryDetail({this.id, this.name, this.desc, this.lotteryConfig});

  LotteryDetail.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["name"] is String) {
      name = json["name"];
    }
    if(json["desc"] is String) {
      desc = json["desc"];
    }
    if(json["lottery_config"] is List) {
      lotteryConfig = (json["lottery_config"] as List)
          .map((e) => LotteryConfig.fromJson(e))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["name"] = name;
    _data["desc"] = desc;
    if(lotteryConfig != null) {
      _data["lottery_config"] = lotteryConfig?.map((e) => e.toJson()).toList();
    }
    return _data;
  }
}

// 轮盘配置项
class LotteryConfig {
  String? id;
  String? left;
  String? right;
  LotteryRewardInfo? lotteryRewardInfo;

  LotteryConfig({this.id, this.left, this.right, this.lotteryRewardInfo});

  LotteryConfig.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["left"] is String) {
      left = json["left"];
    }
    if(json["right"] is String) {
      right = json["right"];
    }
    if(json["lottery_reward_info"] is Map) {
      lotteryRewardInfo = json["lottery_reward_info"] == null 
          ? null 
          : LotteryRewardInfo.fromJson(json["lottery_reward_info"]);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["left"] = left;
    _data["right"] = right;
    if(lotteryRewardInfo != null) {
      _data["lottery_reward_info"] = lotteryRewardInfo?.toJson();
    }
    return _data;
  }
}

// 轮盘奖励信息
class LotteryRewardInfo {
  String? name;
  String? img;

  LotteryRewardInfo({this.name, this.img});

  LotteryRewardInfo.fromJson(Map<String, dynamic> json) {
    if(json["name"] is String) {
      name = json["name"];
    }
    if(json["img"] is String) {
      img = json["img"];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["name"] = name;
    _data["img"] = img;
    return _data;
  }
}

// 抽奖结果模型
class LotteryResult {
  String? id;
  bool? isWin;
  String? rewardId;
  LotteryRewardConfig? rewardConfig;

  LotteryResult({this.id, this.isWin, this.rewardId, this.rewardConfig});

  LotteryResult.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["is_win"] is bool) {
      isWin = json["is_win"];
    }
    if(json["reward_id"] is String) {
      rewardId = json["reward_id"];
    }
    if(json["reward_config"] is Map) {
      rewardConfig = json["reward_config"] == null 
          ? null 
          : LotteryRewardConfig.fromJson(json["reward_config"]);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["is_win"] = isWin;
    _data["reward_id"] = rewardId;
    if(rewardConfig != null) {
      _data["reward_config"] = rewardConfig?.toJson();
    }
    return _data;
  }
}

class LotteryRewardConfig {
  String? id;
  String? name;
  String? img;

  LotteryRewardConfig({this.id, this.name, this.img});

  LotteryRewardConfig.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["name"] is String) {
      name = json["name"];
    }
    if(json["img"] is String) {
      img = json["img"];
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["name"] = name;
    _data["img"] = img;
    return _data;
  }
}