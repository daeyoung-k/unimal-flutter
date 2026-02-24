class UserInfoModel {
  final String email;
  final String provider;
  final String name;
  final String nickname;
  final String tel;
  final String introduction;
  final String birthday;
  final String gender;
  final String? profileImage;

  UserInfoModel({
    required this.email,
    required this.provider,
    required this.name,
    required this.nickname,
    required this.tel,
    required this.introduction,
    required this.birthday,
    required this.gender,
    this.profileImage,
  });

  factory UserInfoModel.fromJson(Map<String, dynamic> json) {
    return UserInfoModel(
      email: json['email'] ?? '',
      provider: json['provider'] ?? '',
      name: json['name'] ?? '',
      nickname: json['nickname'] ?? '',
      tel: json['tel'] ?? '',
      introduction: json['introduction'] ?? '',
      birthday: json['birthday'] ?? '',
      gender: json['gender'] ?? '',
      profileImage: json['profileImage'] as String?,
    );
  }
}
