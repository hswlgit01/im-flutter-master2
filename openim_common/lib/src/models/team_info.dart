class TeamInfo {
  final String userId;
  final int teamSize;
  final int directDownlineCount;
  final String invitationCode;

  TeamInfo({
    required this.userId,
    this.teamSize = 0,
    this.directDownlineCount = 0,
    this.invitationCode = '',
  });

  TeamInfo.fromJson(Map<String, dynamic> json)
      : userId = json['user_id'] ?? '',
        teamSize = json['team_size'] ?? 0,
        directDownlineCount = json['direct_downline_count'] ?? 0,
        invitationCode = json['invitation_code'] ?? '';

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'team_size': teamSize,
      'direct_downline_count': directDownlineCount,
      'invitation_code': invitationCode,
    };
  }
}