class CheckinReward {
  String? id;
  String? imServerUserId;
  String? checkinRewardConfigId;
  String? checkinId;
  String? type;
  String? rewardId;
  String? amount;
  String? status;
  String? createdAt;
  String? updatedAt;
  RewardCurrencyInfo? rewardCurrencyInfo;
  RewardLotteryInfo? rewardLotteryInfo;

  CheckinReward({this.id, this.imServerUserId, this.checkinRewardConfigId, this.checkinId, this.type, this.rewardId, this.amount, this.status, this.createdAt, this.updatedAt, this.rewardCurrencyInfo, this.rewardLotteryInfo});

  CheckinReward.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["im_server_user_id"] is String) {
      imServerUserId = json["im_server_user_id"];
    }
    if(json["checkin_reward_config_id"] is String) {
      checkinRewardConfigId = json["checkin_reward_config_id"];
    }
    if(json["checkin_id"] is String) {
      checkinId = json["checkin_id"];
    }
    if(json["type"] is String) {
      type = json["type"];
    }
    if(json["reward_id"] is String) {
      rewardId = json["reward_id"];
    }
    if(json["amount"] is String) {
      amount = json["amount"];
    }
    if(json["status"] is String) {
      status = json["status"];
    }
    if(json["created_at"] is String) {
      createdAt = json["created_at"];
    }
    if(json["updated_at"] is String) {
      updatedAt = json["updated_at"];
    }
    if(json["reward_currency_info"] is Map) {
      rewardCurrencyInfo = json["reward_currency_info"] == null ? null : RewardCurrencyInfo.fromJson(json["reward_currency_info"]);
    }
    if(json["reward_lottery_info"] is Map) {
      rewardLotteryInfo = json["reward_lottery_info"] == null ? null : RewardLotteryInfo.fromJson(json["reward_lottery_info"]);
    }
  }

  static List<CheckinReward> fromList(List<Map<String, dynamic>> list) {
    return list.map(CheckinReward.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["im_server_user_id"] = imServerUserId;
    _data["checkin_reward_config_id"] = checkinRewardConfigId;
    _data["checkin_id"] = checkinId;
    _data["type"] = type;
    _data["reward_id"] = rewardId;
    _data["amount"] = amount;
    _data["status"] = status;
    _data["created_at"] = createdAt;
    _data["updated_at"] = updatedAt;
    if(rewardCurrencyInfo != null) {
      _data["reward_currency_info"] = rewardCurrencyInfo?.toJson();
    }
    if(rewardLotteryInfo != null) {
      _data["reward_lottery_info"] = rewardLotteryInfo?.toJson();
    }
    return _data;
  }
}

class RewardCurrencyInfo {
  String? id;
  String? name;
  String? icon;
  int? order;
  String? exchangeRate;
  String? minAvailableAmount;
  int? maxTotalSupply;
  String? maxRedPacketAmount;
  String? creatorId;
  int? decimals;
  String? createdAt;
  String? updatedAt;

  RewardCurrencyInfo({this.id, this.name, this.icon, this.order, this.exchangeRate, this.minAvailableAmount, this.maxTotalSupply, this.maxRedPacketAmount, this.creatorId, this.decimals, this.createdAt, this.updatedAt});

  RewardCurrencyInfo.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["name"] is String) {
      name = json["name"];
    }
    if(json["icon"] is String) {
      icon = json["icon"];
    }
    if(json["order"] is int) {
      order = json["order"];
    }
    if(json["exchange_rate"] is String) {
      exchangeRate = json["exchange_rate"];
    }
    if(json["min_available_amount"] is String) {
      minAvailableAmount = json["min_available_amount"];
    }
    if(json["max_total_supply"] is int) {
      maxTotalSupply = json["max_total_supply"];
    }
    if(json["max_red_packet_amount"] is String) {
      maxRedPacketAmount = json["max_red_packet_amount"];
    }
    if(json["creator_id"] is String) {
      creatorId = json["creator_id"];
    }
    if(json["decimals"] is int) {
      decimals = json["decimals"];
    }
    if(json["created_at"] is String) {
      createdAt = json["created_at"];
    }
    if(json["updated_at"] is String) {
      updatedAt = json["updated_at"];
    }
  }

  static List<RewardCurrencyInfo> fromList(List<Map<String, dynamic>> list) {
    return list.map(RewardCurrencyInfo.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["name"] = name;
    _data["icon"] = icon;
    _data["order"] = order;
    _data["exchange_rate"] = exchangeRate;
    _data["min_available_amount"] = minAvailableAmount;
    _data["max_total_supply"] = maxTotalSupply;
    _data["max_red_packet_amount"] = maxRedPacketAmount;
    _data["creator_id"] = creatorId;
    _data["decimals"] = decimals;
    _data["created_at"] = createdAt;
    _data["updated_at"] = updatedAt;
    return _data;
  }
}

class RewardLotteryInfo {
  String? id;
  String? orgId;
  String? name;
  String? desc;
  int? validDays;
  String? createdAt;
  String? updatedAt;

  RewardLotteryInfo({this.id, this.orgId, this.name, this.desc, this.validDays, this.createdAt, this.updatedAt});

  RewardLotteryInfo.fromJson(Map<String, dynamic> json) {
    if(json["id"] is String) {
      id = json["id"];
    }
    if(json["org_id"] is String) {
      orgId = json["org_id"];
    }
    if(json["name"] is String) {
      name = json["name"];
    }
    if(json["desc"] is String) {
      desc = json["desc"];
    }
    if(json["valid_days"] is int) {
      validDays = json["valid_days"];
    }
    if(json["created_at"] is String) {
      createdAt = json["created_at"];
    }
    if(json["updated_at"] is String) {
      updatedAt = json["updated_at"];
    }
  }

  static List<RewardLotteryInfo> fromList(List<Map<String, dynamic>> list) {
    return list.map(RewardLotteryInfo.fromJson).toList();
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