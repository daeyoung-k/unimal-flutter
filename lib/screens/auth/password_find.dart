import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/utils/custom_alert.dart';

class PasswordFindScreen extends StatefulWidget {
  const PasswordFindScreen({super.key});

  @override
  State<PasswordFindScreen> createState() => _PasswordFindScreenState();
}

class _PasswordFindScreenState extends State<PasswordFindScreen> {
  // 이메일 — 아이디 / 도메인 분리
  final TextEditingController _emailIdController = TextEditingController();
  final TextEditingController _emailDomainInputController =
      TextEditingController();
  final FocusNode _emailDomainFocusNode = FocusNode();
  String? _selectedEmailDomain = 'naver.com';
  final List<String> _emailDomains = [
    'naver.com',
    'gmail.com',
    'daum.net',
    'kakao.com',
    '직접입력',
  ];

  final TextEditingController _telController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final CustomAlert _customAlert = CustomAlert();
  final AuthenticationCodeService _authService = AuthenticationCodeService();

  bool _isVerificationSent = false;
  bool _isSendLoading = false;
  bool _isVerifyLoading = false;
  bool _isVerificationCompleted = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Timer? _timer;
  int _remainingSeconds = 300;
  bool _isTimerRunning = false;

  String _email = '';
  String _tel = '';
  String _verificationCode = '';

  // ── 디자인 토큰 ──────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF3578E5);
  static const Color _disabledColor = Color(0xFF9CA3AF);
  static const Color _errorColor = Color(0xFFEF4444);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF374151);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _hintColor = Color(0xFFCBD5E1);
  static const Color _helperColor = Color(0xFF94A3B8);

  @override
  void dispose() {
    _emailIdController.dispose();
    _emailDomainInputController.dispose();
    _emailDomainFocusNode.dispose();
    _telController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── 타이머 ───────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = 300;
    _isTimerRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timer != timer) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _isTimerRunning = false;
            _timer?.cancel();
            _timer = null;
          }
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _isTimerRunning = false);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── 유효성 검사 ──────────────────────────────────────────────────────────────

  bool _isValidPhone(String phone) =>
      RegExp(r'^01[0-9]\d{3,4}\d{4}$').hasMatch(phone);

  bool _isValidPassword(String pw) =>
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,20}$')
          .hasMatch(pw);

  bool _isEmailFilled() =>
      _emailIdController.text.isNotEmpty &&
      (_selectedEmailDomain != null &&
              _selectedEmailDomain != '직접입력' ||
          _emailDomainInputController.text.isNotEmpty);

  String _buildEmail() {
    final domain = _selectedEmailDomain == '직접입력'
        ? _emailDomainInputController.text
        : _selectedEmailDomain!;
    return '${_emailIdController.text}@$domain';
  }

  bool get _canSend =>
      _isEmailFilled() &&
      _isValidPhone(_telController.text) &&
      !_isSendLoading;

  // ── 비즈니스 로직 ────────────────────────────────────────────────────────────

  Future<void> _sendVerificationCode() async {
    _email = _buildEmail();
    _tel = _telController.text;
    setState(() => _isSendLoading = true);
    try {
      final String msg =
          await _authService.sendEmailTelCheckVerificationCode(_email, _tel);
      if (msg == 'ok') {
        if (mounted) {
          setState(() {
            _isVerificationSent = true;
            _isSendLoading = false;
          });
          _startTimer();
          _customAlert.showSnackBar(context, '인증번호가 전송되었습니다.', isError: false);
        }
      } else {
        if (mounted) {
          setState(() => _isSendLoading = false);
          _customAlert.showTextAlert('전송 실패', msg);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSendLoading = false);
        _customAlert.showTextAlert(
            '전송 실패', '인증번호 전송에 실패했습니다.\n잠시 후 다시 시도해주세요.');
      }
    }
  }

  Future<void> _resendVerificationCode() async {
    _stopTimer();
    setState(() {
      _codeController.clear();
      _verificationCode = '';
    });
    await _sendVerificationCode();
  }

  Future<void> _verifyCode() async {
    setState(() => _isVerifyLoading = true);
    try {
      final String msg = await _authService
          .verifyEmailTelVerificationCode(_email, _tel, _verificationCode);
      if (msg == 'ok') {
        if (mounted) {
          setState(() {
            _isVerifyLoading = false;
            _isVerificationCompleted = true;
          });
          _stopTimer();
        }
      } else {
        if (mounted) {
          setState(() => _isVerifyLoading = false);
          _customAlert.showTextAlert('인증 실패', msg);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isVerifyLoading = false);
        _customAlert.showTextAlert('인증 실패', '인증번호가 올바르지 않습니다.\n다시 확인해주세요.');
      }
    }
  }

  Future<void> _changePassword() async {
    final String password = _passwordController.text;
    final String confirm = _confirmPasswordController.text;
    if (!_isValidPassword(password)) {
      _customAlert.showTextAlert(
          '입력 오류', '비밀번호는 영어, 숫자, 특수문자를 포함하여\n8~20자로 입력해주세요.');
      return;
    }
    if (password != confirm) {
      _customAlert.showTextAlert('입력 오류', '비밀번호가 일치하지 않습니다.');
      return;
    }
    final String msg =
        await UserInfoService().changePassword(_email, password, confirm);
    if (msg == 'ok') {
      _customAlert.pageMovingWithshowTextAlert(
          '비밀번호 변경', '비밀번호가 성공적으로 변경되었습니다.', '/login');
    } else {
      if (mounted) _customAlert.showTextAlert('비밀번호 변경 실패', msg);
    }
  }

  // ── UI 헬퍼 ──────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String hint,
      {Widget? suffix, bool isError = false, bool isDisabled = false}) {
    final Color borderNormal = isError ? _errorColor : _borderColor;
    final Color borderFocused = isError ? _errorColor : _primary;
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _hintColor,
        fontSize: 15,
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: isDisabled ? const Color(0xFFF1F5F9) : Colors.white,
      suffix: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderNormal, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderFocused, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
    );
  }

  Widget _button({
    required String label,
    required VoidCallback? onPressed,
    required bool active,
    double width = 120,
    Widget? child,
  }) {
    return SizedBox(
      width: width,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? _primary : _disabledColor,
          disabledBackgroundColor: active ? _primary : _disabledColor,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
        child: child ??
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
              ),
            ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
            fontFamily: 'Pretendard',
          ),
        ),
      );

  Widget _domainDropdown() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _isVerificationSent ? const Color(0xFFF1F5F9) : Colors.white,
        border: Border.all(color: _borderColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedEmailDomain,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: _helperColor),
          style: const TextStyle(
            fontSize: 15,
            fontFamily: 'Pretendard',
            color: _textPrimary,
          ),
          items: _emailDomains
              .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(d,
                        style: const TextStyle(
                            fontFamily: 'Pretendard', fontSize: 15)),
                  ))
              .toList(),
          onChanged: _isVerificationSent
              ? null
              : (value) {
                  setState(() {
                    _selectedEmailDomain = value;
                    if (value == '직접입력') {
                      _emailDomainFocusNode.requestFocus();
                    } else if (value != null) {
                      _emailDomainInputController.text = value;
                    }
                  });
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool codeActive =
        _verificationCode.length == 6 && !_isVerifyLoading;

    final String pwText = _passwordController.text;
    final String confirmText = _confirmPasswordController.text;
    final bool passwordInvalid = pwText.isNotEmpty && !_isValidPassword(pwText);
    final bool passwordMismatch =
        confirmText.isNotEmpty && pwText != confirmText;
    final bool canChangePassword =
        _isValidPassword(pwText) && pwText == confirmText;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: _textPrimary, size: 28),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '비밀번호 찾기',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isVerificationCompleted ? '새 비밀번호 설정' : '전화번호 인증',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
                fontFamily: 'Pretendard',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isVerificationCompleted
                  ? '새로운 비밀번호를 입력해주세요.'
                  : '비밀번호 찾기를 위해\n전화번호 인증이 필요해요.',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textMuted,
                fontFamily: 'Pretendard',
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),

            if (!_isVerificationCompleted) ...[
              // ── 이메일 (아이디 @ 도메인) ────────────────────────────────────
              _label('이메일 (아이디)'),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _emailIdController,
                        enabled: !_isVerificationSent,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 15,
                          fontFamily: 'Pretendard',
                          color: _textPrimary,
                        ),
                        decoration: _inputDecoration('이메일',
                            isDisabled: _isVerificationSent),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.alternate_email,
                        color: _helperColor, size: 24),
                  ),
                  Expanded(
                    child: _selectedEmailDomain == '직접입력'
                        ? SizedBox(
                            height: 56,
                            child: TextField(
                              controller: _emailDomainInputController,
                              focusNode: _emailDomainFocusNode,
                              enabled: !_isVerificationSent,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 15,
                                fontFamily: 'Pretendard',
                                color: _textPrimary,
                              ),
                              decoration: _inputDecoration('도메인 입력',
                                  isDisabled: _isVerificationSent),
                            ),
                          )
                        : _domainDropdown(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── 전화번호 입력 행 ───────────────────────────────────────────
              _label('전화번호'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: TextField(
                        controller: _telController,
                        keyboardType: TextInputType.phone,
                        enabled: !_isVerificationSent,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 15,
                          fontFamily: 'Pretendard',
                          color: _textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '전화번호',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 15,
                            fontFamily: 'Pretendard',
                          ),
                          filled: true,
                          fillColor: _isVerificationSent
                              ? const Color(0xFFF1F5F9)
                              : Colors.white,
                          prefixIcon: const Icon(Icons.local_phone_outlined,
                              color: _textMuted, size: 22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _borderColor, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _borderColor, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: _primary, width: 1.5),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: _borderColor, width: 1),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 17, vertical: 17),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _isVerificationSent
                      ? _button(
                          label: '재발송',
                          onPressed: _isSendLoading
                              ? null
                              : _resendVerificationCode,
                          active: true,
                          width: 90,
                          child: _isSendLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : null,
                        )
                      : _button(
                          label: '인증번호 전송',
                          onPressed: _canSend ? _sendVerificationCode : null,
                          active: _canSend,
                          width: 120,
                          child: _isSendLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : null,
                        ),
                ],
              ),

              // ── 인증번호 입력 행 ───────────────────────────────────────────
              if (_isVerificationSent) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onChanged: (v) =>
                              setState(() => _verificationCode = v),
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'Pretendard',
                            color: _textPrimary,
                          ),
                          decoration: _inputDecoration(
                            '인증번호',
                            suffix: _isTimerRunning
                                ? Text(
                                    _formatTime(_remainingSeconds),
                                    style: const TextStyle(
                                      color: _primary,
                                      fontSize: 13,
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    _button(
                      label: '인증하기',
                      onPressed: (codeActive && _isTimerRunning)
                          ? _verifyCode
                          : null,
                      active: codeActive && _isTimerRunning,
                      width: 100,
                      child: _isVerifyLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ] else ...[
              // ── 새 비밀번호 설정 ───────────────────────────────────────────
              _label('새 비밀번호'),
              SizedBox(
                height: 56,
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    color: _textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '새 비밀번호',
                    hintStyle: const TextStyle(
                        color: _hintColor,
                        fontSize: 15,
                        fontFamily: 'Pretendard'),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: _helperColor,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _borderColor, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: passwordInvalid ? _errorColor : _borderColor,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: passwordInvalid ? _errorColor : _primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 17, vertical: 17),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '영어 + 숫자 + 특수문자 포함, 8~20자',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Pretendard',
                  color: passwordInvalid ? _errorColor : _helperColor,
                ),
              ),
              const SizedBox(height: 14),

              _label('새 비밀번호 확인'),
              SizedBox(
                height: 56,
                child: TextField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    color: _textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '새 비밀번호 확인',
                    hintStyle: const TextStyle(
                        color: _hintColor,
                        fontSize: 15,
                        fontFamily: 'Pretendard'),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: _helperColor,
                        size: 20,
                      ),
                      onPressed: () => setState(() =>
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _borderColor, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: passwordMismatch ? _errorColor : _borderColor,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: passwordMismatch ? _errorColor : _primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 17, vertical: 17),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: canChangePassword ? _changePassword : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canChangePassword ? _primary : _disabledColor,
                    disabledBackgroundColor:
                        canChangePassword ? _primary : _disabledColor,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    '비밀번호 변경',
                    style: TextStyle(
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
