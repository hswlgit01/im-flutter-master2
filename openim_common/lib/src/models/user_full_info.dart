class UserFullInfo {
  String? userID;
  String? password;
  String? account;
  String? invitationCode;
  String? phoneNumber;
  String? areaCode;
  String? nickname;
  String? remark;
  String? englishName;
  String? faceURL;
  int? gender;
  String? mobileAreaCode;
  String? mobile;
  String? telephone;
  int? level;
  int? birth;
  String? email;
  int? order;
  int? status;
  int? allowAddFriend;
  int? allowBeep;
  int? allowVibration;
  int? forbidden;
  String? ex;
  String? station;
  int? globalRecvMsgOpt;
  int? points;
  int? canSendFreeMsg; // 0=普通用户需好友验证，1=可跳过消息验证
  bool isFriendship = false;
  bool isBlacklist = false;
  List<DepartmentInfo>? departmentList;
  // 实名认证字段
  bool? isRealNameVerified; // 是否已实名认证
  String? realName; // 真实姓名
  int? verifiedTime; // 认证通过时间（秒时间戳）
  // 团队数据字段
  int? teamSize; // 团队总人数
  int? directDownlineCount; // 直接下线数量

  bool get isMale => gender == 1;

  String get showName => remark?.isNotEmpty == true ? remark! : (nickname?.isNotEmpty == true ? nickname! : userID!);

  UserFullInfo({
    this.userID,
    this.password,
    this.account,
    this.invitationCode,
    this.phoneNumber,
    this.areaCode,
    this.nickname,
    this.remark,
    this.englishName,
    this.faceURL,
    this.gender,
    this.mobileAreaCode,
    this.mobile,
    this.telephone,
    this.level,
    this.birth,
    this.email,
    this.order,
    this.status,
    this.allowAddFriend,
    this.allowBeep,
    this.allowVibration,
    this.forbidden,
    this.station,
    this.ex,
    this.globalRecvMsgOpt,
    this.points,
    this.canSendFreeMsg,
    this.isFriendship = false,
    this.isBlacklist = false,
    this.departmentList,
    this.isRealNameVerified,
    this.realName,
    this.verifiedTime,
    this.teamSize,
    this.directDownlineCount,
  });

  UserFullInfo.fromJson(Map<String, dynamic> json) {
    userID = json['userID'];
    password = json['password'];
    account = json['account'];
    invitationCode = json['invitationCode'];
    phoneNumber = json['phoneNumber'];
    areaCode = json['areaCode'];
    nickname = json['nickname'];
    remark = json['remark'];
    englishName = json['englishName'];
    faceURL = json['faceURL'];
    gender = json['gender'];
    mobileAreaCode = json['mobileAreaCode'];
    mobile = json['mobile'];
    telephone = json['telephone'];
    level = json['level'];
    birth = json['birth'];
    email = json['email'];
    order = json['order'];
    status = json['status'];
    allowAddFriend = json['allowAddFriend'];
    allowBeep = json['allowBeep'];
    allowVibration = json['allowVibration'];
    forbidden = json['forbidden'];
    station = json['station'];
    ex = json['ex'];
    globalRecvMsgOpt = json['globalRecvMsgOpt'];
    points = json['points'];
    canSendFreeMsg = json['can_send_free_msg'];
    isFriendship = json['isFriendship'] ?? false;
    isBlacklist = json['isBlacklist'] ?? false;
    departmentList = json['departmentList'] == null
        ? null
        : (json['departmentList'] as List).map((e) => DepartmentInfo.fromJson(e)).toList();
    isRealNameVerified = json['is_real_name_verified'];
    realName = json['real_name'];
    verifiedTime = json['verified_time'];
    teamSize = json['team_size'] ?? json['teamSize'];
    directDownlineCount = json['direct_downline_count'] ?? json['directDownlineCount'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['userID'] = userID;
    data['password'] = password;
    data['account'] = account;
    data['invitationCode'] = invitationCode;
    data['phoneNumber'] = phoneNumber;
    data['areaCode'] = areaCode;
    data['nickname'] = nickname;
    data['remark'] = remark;
    data['englishName'] = englishName;
    data['faceURL'] = faceURL;
    data['gender'] = gender;
    data['mobileAreaCode'] = mobileAreaCode;
    data['telephone'] = telephone;
    data['level'] = level;
    data['birth'] = birth;
    data['email'] = email;
    data['order'] = order;
    data['status'] = status;
    data['allowAddFriend'] = allowAddFriend;
    data['allowBeep'] = allowBeep;
    data['allowVibration'] = allowVibration;
    data['forbidden'] = forbidden;
    data['station'] = station;
    data['ex'] = ex;
    data['globalRecvMsgOpt'] = globalRecvMsgOpt;
    data['points'] = points;
    data['canSendFreeMsg'] = canSendFreeMsg;
    data['isFriendship'] = isFriendship;
    data['isBlacklist'] = isBlacklist;
    data['departmentList'] = departmentList?.map((e) => e.toJson()).toList();
    data['is_real_name_verified'] = isRealNameVerified;
    data['real_name'] = realName;
    data['verified_time'] = verifiedTime;
    data['team_size'] = teamSize;
    data['direct_downline_count'] = directDownlineCount;
    return data;
  }
}

class DepartmentInfo {
  String? departmentID;
  String? departmentFaceURL;
  String? departmentName;
  String? departmentParentID;
  int? departmentOrder;
  int? departmentDepartmentType;
  String? departmentRelatedGroupID;
  int? departmentCreateTime;
  int? memberOrder;
  String? memberPosition;
  int? memberLeader;
  int? memberStatus;
  int? memberEntryTime;
  int? memberTerminationTime;
  int? memberCreateTime;

  DepartmentInfo(
      {this.departmentID,
      this.departmentFaceURL,
      this.departmentName,
      this.departmentParentID,
      this.departmentOrder,
      this.departmentDepartmentType,
      this.departmentRelatedGroupID,
      this.departmentCreateTime,
      this.memberOrder,
      this.memberPosition,
      this.memberLeader,
      this.memberStatus,
      this.memberEntryTime,
      this.memberTerminationTime,
      this.memberCreateTime});

  DepartmentInfo.fromJson(Map<String, dynamic> json) {
    departmentID = json['departmentID'];
    departmentFaceURL = json['departmentFaceURL'];
    departmentName = json['departmentName'];
    departmentParentID = json['departmentParentID'];
    departmentOrder = json['departmentOrder'];
    departmentDepartmentType = json['departmentDepartmentType'];
    departmentRelatedGroupID = json['departmentRelatedGroupID'];
    departmentCreateTime = json['departmentCreateTime'];
    memberOrder = json['memberOrder'];
    memberPosition = json['memberPosition'];
    memberLeader = json['memberLeader'];
    memberStatus = json['memberStatus'];
    memberEntryTime = json['memberEntryTime'];
    memberTerminationTime = json['memberTerminationTime'];
    memberCreateTime = json['memberCreateTime'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['departmentID'] = departmentID;
    data['departmentFaceURL'] = departmentFaceURL;
    data['departmentName'] = departmentName;
    data['departmentParentID'] = departmentParentID;
    data['departmentOrder'] = departmentOrder;
    data['departmentDepartmentType'] = departmentDepartmentType;
    data['departmentRelatedGroupID'] = departmentRelatedGroupID;
    data['departmentCreateTime'] = departmentCreateTime;
    data['memberOrder'] = memberOrder;
    data['memberPosition'] = memberPosition;
    data['memberLeader'] = memberLeader;
    data['memberStatus'] = memberStatus;
    data['memberEntryTime'] = memberEntryTime;
    data['memberTerminationTime'] = memberTerminationTime;
    data['memberCreateTime'] = memberCreateTime;
    return data;
  }
}

class IdentityVerifyInfo {
  int? status; // 0-未认证 1-审核中 2-已认证 3-已拒绝
  String? realName; // 真实姓名
  String? idCardNumber; // 身份证号
  String? idCardFront; // 身份证正面
  String? idCardBack; // 身份证反面
  String? rejectReason; // 拒绝原因
  int? applyTime; // 申请时间戳
  int? verifyTime; // 认证时间戳

  IdentityVerifyInfo({
    this.status,
    this.realName,
    this.idCardNumber,
    this.idCardFront,
    this.idCardBack,
    this.rejectReason,
    this.applyTime,
    this.verifyTime,
  });

  IdentityVerifyInfo.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    realName = json['realName'];
    idCardNumber = json['idCardNumber'];
    idCardFront = json['idCardFront'];
    idCardBack = json['idCardBack'];
    rejectReason = json['rejectReason'];
    applyTime = json['applyTime'];
    verifyTime = json['verifyTime'];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['status'] = status;
    data['realName'] = realName;
    data['idCardNumber'] = idCardNumber;
    data['idCardFront'] = idCardFront;
    data['idCardBack'] = idCardBack;
    data['rejectReason'] = rejectReason;
    data['applyTime'] = applyTime;
    data['verifyTime'] = verifyTime;
    return data;
  }

  // 辅助方法
  bool get isVerified => status == 2;
  bool get isReviewing => status == 1;
  bool get isRejected => status == 3;
  bool get isNotVerified => status == 0 || status == null;
}