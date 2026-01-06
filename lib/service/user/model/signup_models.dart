class SignupModel {
  final String nickname;
  final String email;
  final String tel;
  final String password;
  final String checkPassword;

  SignupModel({
    required this.nickname,
    required this.email,
    required this.tel,
    required this.password,
    required this.checkPassword,
  });

  factory SignupModel.fromJson(Map<String, dynamic> json) {
    return SignupModel(
      nickname: json['nickname'],
      email: json['email'],
      tel: json['tel'],
      password: json['password'],
      checkPassword: json['checkPassword'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'email': email,
      'tel': tel,
      'password': password,
      'checkPassword': checkPassword,
    };
  }
}
