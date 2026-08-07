import 'package:flutter/material.dart';
import 'package:unimal/service/report/model/report_reason.dart';
import 'package:unimal/service/report/report_api_service.dart';
import 'package:unimal/theme/app_colors.dart';

/// 신고 바텀시트.
///
/// 게시글·댓글이 같은 시트를 쓴다. 대상 종류에 따라 문구만 달라지고 흐름은 같다.
///
/// ```dart
/// ReportSheet.show(
///   context,
///   targetType: ReportTargetType.post,
///   targetId: post.id,
///   targetLabel: '게시글',
/// );
/// ```
///
/// 결과 안내는 시트가 스스로 한다(스낵바). 호출부가 성공/실패를 따로 처리할 일이
/// 없어서다 — 신고는 접수되면 그걸로 끝이고 화면을 갱신할 것도 없다.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
  });

  final ReportTargetType targetType;

  /// 게시글·댓글이면 Hashids 문자열, 회원이면 이메일.
  final String targetId;

  /// 문구에 들어갈 대상 이름. '게시글' / '댓글' 등.
  final String targetLabel;

  static Future<void> show(
    BuildContext context, {
    required ReportTargetType targetType,
    required String targetId,
    required String targetLabel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportSheet(
        targetType: targetType,
        targetId: targetId,
        targetLabel: targetLabel,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _reportApiService = ReportApiService();
  final _descriptionController = TextEditingController();

  ReportReason? _selectedReason;
  bool _submitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// 제출 가능 여부.
  ///
  /// '기타'는 상세 내용이 필수다. 서버도 같은 검증을 하지만, 다 적고 나서
  /// 거절당하는 것보다 버튼이 비활성인 편이 낫다.
  bool get _canSubmit {
    if (_submitting || _selectedReason == null) return false;
    if (_selectedReason!.requiresDescription) {
      return _descriptionController.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null) return;

    setState(() => _submitting = true);

    final result = await _reportApiService.report(
      targetType: widget.targetType,
      targetId: widget.targetId,
      reason: reason,
      description: _descriptionController.text,
    );

    if (!mounted) return;

    // 시트를 먼저 닫고 안내한다. 시트 위에 스낵바를 띄우면 가려진다.
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      // 키보드가 올라오면 시트가 가려지므로 그만큼 밀어 올린다.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: colors.borderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.targetLabel} 신고',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '신고 사유를 선택해주세요. 검토 후 조치됩니다.',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              ...ReportReason.values.map((reason) {
                final selected = _selectedReason == reason;

                return InkWell(
                  onTap: _submitting
                      ? null
                      : () => setState(() => _selectedReason = reason),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: selected ? colors.primary : colors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          reason.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Pretendard',
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected
                                ? colors.textPrimary
                                : colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // '기타'를 골랐을 때만 입력칸을 연다. 늘 보여주면 시트가 길어지고,
              // 다른 사유에서는 적어도 서버가 쓰지 않는다.
              if (_selectedReason?.requiresDescription ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: TextField(
                    controller: _descriptionController,
                    maxLength: 500,
                    maxLines: 3,
                    enabled: !_submitting,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '어떤 점이 문제인지 알려주세요.',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                        color: colors.textMuted,
                      ),
                      filled: true,
                      fillColor: colors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.danger,
                      disabledBackgroundColor: colors.surfaceMuted,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: colors.textMuted,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '신고하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
