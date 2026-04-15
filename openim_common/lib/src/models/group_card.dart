class GroupCardData {
  final int customType;
  final GroupData data;

  GroupCardData({
    required this.customType,
    required this.data,
  });

  factory GroupCardData.fromJson(Map<String, dynamic> json) {
    return GroupCardData(
      customType: json['customType'] as int,
      data: GroupData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customType': customType,
      'data': data.toJson(),
    };
  }
}

class GroupData {
  final String groupID;
  final String groupName;
  final String groupAvatar;

  GroupData({
    required this.groupID,
    required this.groupName,
    required this.groupAvatar,
  });

  factory GroupData.fromJson(Map<String, dynamic> json) {
    return GroupData(
      groupID: json['groupID'] as String,
      groupName: json['groupName'] as String,
      groupAvatar: json['groupAvatar'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupID': groupID,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
    };
  }
}