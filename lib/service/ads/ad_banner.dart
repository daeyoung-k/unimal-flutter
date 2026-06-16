import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:unimal/service/ads/ad_service.dart';
import 'package:unimal/theme/app_colors.dart';

/// 재사용 배너 광고 위젯.
///
/// 화면 어디든 `const AdBanner()` 한 줄로 삽입한다.
/// 화면 너비에 맞춘 어댑티브 배너를 로드하고, **로드에 성공했을 때만** 표시한다.
/// (미로드/실패 시 빈 공간을 차지하지 않아 레이아웃이 흔들리지 않는다.)
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

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
    final width = MediaQuery.of(context).size.width.truncate();
    final size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;

    final banner = BannerAd(
      adUnitId: AdService.to.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
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
