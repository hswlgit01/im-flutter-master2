import 'checkin_reward.dart';

/// 签到接口（POST 打卡）的响应：奖励列表 + 本次签到后的连续天数与今日记录，供前端直接回显
class CheckinResult {
  int streak;
  Checkin? todayCheckin;
  List<CheckinReward> checkinRewards;

  CheckinResult({
    required this.streak,
    this.todayCheckin,
    List<CheckinReward>? checkinRewards,
  }) : checkinRewards = checkinRewards ?? [];

  factory CheckinResult.fromJson(Map<String, dynamic> json) {
    int streak = 0;
    if (json["streak"] is int) {
      streak = json["streak"] as int;
    }
    Checkin? todayCheckin;
    if (json["today_checkin"] != null && json["today_checkin"] is Map) {
      todayCheckin = Checkin.fromJson(Map<String, dynamic>.from(json["today_checkin"]));
    }
    List<CheckinReward> rewards = [];
    if (json["checkin_rewards"] is List) {
      rewards = (json["checkin_rewards"] as List)
          .map((e) => CheckinReward.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return CheckinResult(streak: streak, todayCheckin: todayCheckin, checkinRewards: rewards);
  }
}

class CheckinHistore {
  int streak;
  Checkin? todayCheckin;
  List<Checkin> checkinRecord;

  CheckinHistore(
      {required this.streak, this.todayCheckin, List<Checkin>? checkinRecord})
      : checkinRecord = checkinRecord ?? [];

  CheckinHistore.fromJson(Map<String, dynamic> json)
      : streak = json["streak"] is int ? json["streak"] : 0,
        todayCheckin = json["today_checkin"] == null
            ? null
            : Checkin.fromJson(json["today_checkin"]),
        checkinRecord = json["checkin_record"] is List
            ? Checkin.fromList(
                List<Map<String, dynamic>>.from(json["checkin_record"]))
            : [];

  static List<CheckinHistore> fromList(List<Map<String, dynamic>> list) {
    return list.map(CheckinHistore.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["streak"] = streak;
    if (todayCheckin != null) {
      _data["today_checkin"] = todayCheckin?.toJson();
    }
    _data["checkin_record"] = checkinRecord;
    return _data;
  }
}

class Checkin {
  String? id;
  String? imServerUserId;
  String? orgId;
  String? date;
  int? streak;
  String? createdAt;

  Checkin(
      {this.id,
      this.imServerUserId,
      this.orgId,
      this.date,
      this.streak,
      this.createdAt});

  Checkin.fromJson(Map<String, dynamic> json) {
    if (json["id"] != null) {
      id = json["id"].toString();
    }
    if (json["im_server_user_id"] is String) {
      imServerUserId = json["im_server_user_id"];
    }
    if (json["org_id"] != null) {
      orgId = json["org_id"].toString();
    }
    if (json["date"] != null) {
      date = json["date"] is String ? json["date"] as String : json["date"].toString();
    }
    if (json["streak"] is int) {
      streak = json["streak"];
    }
    if (json["created_at"] != null) {
      createdAt = json["created_at"] is String ? json["created_at"] as String : json["created_at"].toString();
    }
  }

  static List<Checkin> fromList(List<Map<String, dynamic>> list) {
    return list.map(Checkin.fromJson).toList();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> _data = <String, dynamic>{};
    _data["id"] = id;
    _data["im_server_user_id"] = imServerUserId;
    _data["org_id"] = orgId;
    _data["date"] = date;
    _data["streak"] = streak;
    _data["created_at"] = createdAt;
    return _data;
  }
}
