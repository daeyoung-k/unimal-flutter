import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:unimal/service/auth/authentication_service.dart';
import 'package:unimal/utils/custom_alert.dart';

class IdFindScreen extends StatefulWidget {
  const IdFindScreen({super.key});

  @override
  State<IdFindScreen> createState() => _IdFindScreenState();
}

class _IdFindScreenState extends State<IdFindScreen> {
  final TextEditingController _telController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final CustomAlert _customAlert = CustomAlert();
  final AuthenticationCodeService _authService = AuthenticationCodeService();

  bool _isVerificationSent = false;
  bool _isSendLoading = false;
  bool _isVerifyLoading = false;

  Timer? _timer;
  int _remainingSeconds = 300;
  bool _isTimerRunning = false;

  String _tel = '';
  String _verificationCode = '';
  String _foundEmail = '';

  // ── 디자인 토큰 ──────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF3578E5);
  static const Color _disabledColor = Color(0xFF9CA3AF);
  static const Color _textPrimary = Color(0xFF1A1A2E);
  static const Color _textSecondary = Color(0xFF374151);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _hintColor = Color(0xFFCBD5E1);

  @override
  void dispose() {
    _telController.dispose();
    _codeController.dispose();
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

  // ── 비즈니스 로직 ────────────────────────────────────────────────────────────

  bool _isValidPhone(String phone) =>
      RegExp(r'^01[0-9]\d{3,4}\d{4}$').hasMatch(phone);

  Future<void> _sendVerificationCode() async {
    _tel = _telController.text;
    if (!_isValidPhone(_tel)) {
      _customAlert.showTextAlert('입력 오류', '올바른 전화번호 형식을 입력해주세요.\n예: 01012345678');
      return;
    }
    setState(() => _isSendLoading = true);
    try {
      final bool sent = await _authService.sendTelVerificationCode(_tel);
      if (sent) {
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
          _customAlert.showTextAlert('전송 실패', '인증번호 전송에 실패했습니다.\n잠시 후 다시 시도해주세요.');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSendLoading = false);
        _customAlert.showTextAlert('전송 실패', '인증번호 전송에 실패했습니다.\n잠시 후 다시 시도해주세요.');
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
    if (_verificationCode.isEmpty) {
      _customAlert.showTextAlert('입력 오류', '인증번호를 입력해주세요.');
      return;
    }
    if (_verificationCode.length != 6) {
      _customAlert.showTextAlert('입력 오류', '인증번호는 6자리로 입력해주세요.');
      return;
    }
    setState(() => _isVerifyLoading = true);
    try {
      final findEmailInfo = await _authService
          .verifyTelVerificationCodeIdFind(_tel, _verificationCode);
      if (mounted) setState(() => _isVerifyLoading = false);
      if (findEmailInfo.isSuccess) {
        _stopTimer();
        if (mounted) {
          setState(() => _foundEmail = findEmailInfo.email ?? '');
        }
      } else {
        if (mounted) {
          _customAlert.showTextAlert(
              '인증 실패', findEmailInfo.message ?? '아이디 찾기 실패');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isVerifyLoading = false);
        _customAlert.showTextAlert('인증 실패', '인증번호가 올바르지 않습니다.\n다시 확인해주세요.');
      }
    }
  }

  // ── UI 헬퍼 ──────────────────────────────────────────────────────────────────

  InputDecoration _inputDecoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _hintColor,
        fontSize: 15,
        fontFamily: 'Pretendard',
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      suffix: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    final bool phoneActive =
        _isValidPhone(_telController.text) && !_isSendLoading && _foundEmail.isEmpty;
    final bool codeActive =
        _verificationCode.length == 6 && !_isVerifyLoading;

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
          '아이디 찾기',
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
            // ── 섹션 타이틀 ──────────────────────────────────────────────────
            const Text(
              '전화번호 인증',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
                fontFamily: 'Pretendard',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '아이디 찾기를 위해\n전화번호 인증이 필요해요.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textMuted,
                fontFamily: 'Pretendard',
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),

            // ── 전화번호 입력 행 ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: TextField(
                      controller: _telController,
                      keyboardType: TextInputType.phone,
                      enabled: _foundEmail.isEmpty,
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
                        fillColor: _foundEmail.isNotEmpty
                            ? const Color(0xFFF1F5F9)
                            : Colors.white,
                        prefixIcon: const Icon(Icons.local_phone_outlined,
                            color: _textMuted, size: 22),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _borderColor, width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _borderColor, width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _primary, width: 1.5),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _borderColor, width: 1),
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
                        onPressed: (_isSendLoading || _foundEmail.isNotEmpty)
                            ? null
                            : _resendVerificationCode,
                        active: _foundEmail.isEmpty,
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
                        onPressed: phoneActive ? _sendVerificationCode : null,
                        active: phoneActive,
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

            // ── 인증번호 입력 행 (전송 후 표시) ──────────────────────────────
            if (_isVerificationSent && _foundEmail.isEmpty) ...[
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
                    onPressed:
                        (codeActive && _isTimerRunning) ? _verifyCode : null,
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

            // ── 찾은 아이디 결과 ──────────────────────────────────────────────
            if (_foundEmail.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF7AB3FF).withValues(alpha: 0.4), width: 1),
                ),
                child: Column(
                  children: [
                    const Text(
                      '찾은 아이디',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _foundEmail,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    '로그인하러 가기',
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
