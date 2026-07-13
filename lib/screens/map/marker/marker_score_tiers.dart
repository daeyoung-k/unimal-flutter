import 'marker_constants.dart';

/// score 크기 위계 판정 (피그마 "17 마커 변형 시트" §2).
///
/// 서버 score 를 그대로 쓰되, 절대 임계값 대신 **화면에 로드된 마커들 내
/// 상대 백분위**로 4단계 크기를 정한다. 지역별 score 편차가 커도
/// (한적한 동네 vs 핫플 밀집 지역) 어느 화면에서든 위계가 살아남는다.
///
/// 경계 조건:
/// - 표본이 [kMarkerTierMinSample] 미만이거나 score 가 전부 같으면 위계 비활성
///   (전부 기본 크기) — 마커 3개 중 1개가 "핫플"이 되는 왜곡 방지.
/// - 동점 구간이 백분위 경계에 걸치면 아래 티어로 흡수된다
///   (예: 대부분이 score 0이면 0점 글은 절대 hot/upper 가 되지 않음).
class MarkerScoreTiers {
  final bool enabled;
  final double _p25;
  final double _p75;
  final double _p95;

  const MarkerScoreTiers.disabled()
      : enabled = false,
        _p25 = 0,
        _p75 = 0,
        _p95 = 0;

  const MarkerScoreTiers._(this._p25, this._p75, this._p95) : enabled = true;

  factory MarkerScoreTiers.fromScores(Iterable<double> scores) {
    final sorted = scores.toList()..sort();
    if (sorted.length < kMarkerTierMinSample) {
      return const MarkerScoreTiers.disabled();
    }
    // 전부 동점이면 위계 무의미
    if (sorted.first == sorted.last) {
      return const MarkerScoreTiers.disabled();
    }
    double q(double p) => sorted[((sorted.length - 1) * p).round()];
    return MarkerScoreTiers._(
      q(kMarkerTierLowerPercentile),
      q(kMarkerTierUpperPercentile),
      q(kMarkerTierHotPercentile),
    );
  }

  /// 핫플(상위 5%) 여부 — 66px + 캡션 우선권 대상.
  /// `> _p75` 조건: 동점 다수가 p95 경계까지 차지하는 분포에서
  /// 전원이 hot 판정되는 것을 막는다.
  bool isHot(double score) => enabled && score >= _p95 && score > _p75;

  /// 이 score 의 마커 표시 크기(dp).
  double sizeFor(double score) {
    if (!enabled) return kNormalMarkerSize;
    if (isHot(score)) return kMarkerSizeHot;
    if (score >= _p75 && score > _p25) return kMarkerSizeUpper;
    if (score < _p25) return kMarkerSizeLower;
    return kNormalMarkerSize;
  }
}
