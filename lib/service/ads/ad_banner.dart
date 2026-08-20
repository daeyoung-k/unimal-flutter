import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:unimal/service/ads/ad_service.dart';
import 'package:unimal/theme/app_colors.dart';

/// 재사용 배너 광고 위젯.
///
/// 화면 어디든 `const AdBanner()` 한 줄로 삽입한다.
/// 화면 너비에 맞춘 어댑티브 배너를 로드하고, **로드에 성공했을 때만** 표시한다.
/// (미로드/실패 시 빈 공간을 차지하지 않아 레이아웃이 흔들리지 않는다.)
///
/// 좌우에 여백을 두고 싶으면 [AdBanner.inset] 을 쓴다.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, this.onLoadedChanged}) : horizontalInset = 0;

  /// 좌우 [horizontalInset] 만큼 여백을 두고 **남은 폭에 맞춘** 어댑티브 배너.
  ///
  /// 320x50 같은 고정 크기를 쓰면 요즘 폰(390~430pt)에서는 좌우가 휑하고,
  /// iPhone SE 1세대(320pt)에서는 여백이 0 이 되어 어느 쪽에도 맞지 않는다.
  /// 어댑티브는 "이 폭에 맞는 광고를 달라"고 요청하는 방식이라 기기마다 알아서 맞는다.
  ///
  /// 비율(예: 화면의 10%)이 아니라 고정 pt 인 이유: 비율로 잡으면 폰에서 오히려
  /// 320 보다 좁아진다(390 * 0.8 = 312).
  ///
  /// 기본값 20 은 호출부가 광고를 4pt 패딩의 카드로 감싸는 것을 감안한 값이다
  /// (20 - 4 = 화면 가장자리로부터 16pt).
  const AdBanner.inset({
    super.key,
    this.horizontalInset = 20,
    this.onLoadedChanged,
  });

  /// 0 이면 화면 전체 폭.
  final double horizontalInset;

  /// 광고가 실제로 그려지는지 알려준다 (로드 성공 true / 실패·미로드 false).
  ///
  /// **호출부가 광고를 카드·테두리·여백으로 감쌀 때 반드시 이 값을 봐야 한다.**
  /// 이 위젯은 미로드 시 [SizedBox.shrink] 를 돌려주지만, 감싸는 쪽이 그걸 모르고
  /// 패딩과 배경색을 그리면 **광고 없이 껍데기만 남아 작은 회색 점**이 된다.
  /// (실제로 지도 피드 시트에서 그렇게 보였다 — 2026-08.)
  final ValueChanged<bool>? onLoadedChanged;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면 너비(MediaQuery)가 필요해 didChangeDependencies에서 1회 로드.
    if (_banner == null) {
      _loadBanner();
    }
  }

  Future<void> _loadBanner() async {
    // 광고를 끈 빌드(스토어 스크린샷용)에서는 요청 자체를 하지 않는다.
    if (!AdService.enabled) return;

    // AdService 가 없으면(초기화 실패 / 위젯 테스트) 광고 없이 조용히 넘어간다.
    if (!Get.isRegistered<AdService>()) return;

    // 여백을 뺀 폭으로 요청한다. 폭이 좁은 기기면 좁은 광고가 와서 오버플로가 없다.
    final available = MediaQuery.of(context).size.width -
        widget.horizontalInset * 2;
    final width = available.truncate();
    if (width <= 0) return;

    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;

    final banner = BannerAd(
      adUnitId: AdService.to.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
          widget.onLoadedChanged?.call(true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // 실패 이유를 남긴다. 실패는 운영 중에도 **정상적으로 자주** 일어나는데
          // (code 3 = NO_FILL, 재고 없음), 로그가 없으면 그게 정상인지 설정
          // 사고(잘못된 유닛 ID, 미승인 앱 = code 0/1)인지 구분할 방법이 없다.
          debugPrint('[ads] 배너 로드 실패 '
              'code=${error.code} domain=${error.domain} ${error.message}');
          // 실패한 배너를 계속 들고 있으면 두 가지가 잘못된다.
          // 1. 위젯 dispose 때 `_banner?.dispose()` 가 또 불려 이중 해제.
          // 2. didChangeDependencies 의 `_banner == null` 가드에 걸려 재시도가
          //    영영 막힌다 (네트워크가 늦게 붙은 경우에도 광고가 안 뜬다).
          _banner = null;
          if (!mounted) return;
          // 이미 false 지만 명시적으로 알린다 — 호출부가 "응답이 왔고 광고는
          // 없다"를 알아야 자리 잡아둔 껍데기를 치울 수 있다.
          widget.onLoadedChanged?.call(false);
        },
      ),
    );
    _banner = banner;
    await banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    if (!_loaded || banner == null) {
      return const SizedBox.shrink();
    }

    // 여백이 있는 배너는 광고 크기만큼만 차지한다.
    // 정렬·라운드 처리는 호출부가 결정한다 (시트에서는 라운드 카드로 감싼다).
    if (widget.horizontalInset > 0) {
      return SizedBox(
        width: banner.size.width.toDouble(),
        height: banner.size.height.toDouble(),
        child: AdWidget(ad: banner),
      );
    }

    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      height: banner.size.height.toDouble(),
      color: colors.surface,
      alignment: Alignment.center,
      child: AdWidget(ad: banner),
    );
  }
}
