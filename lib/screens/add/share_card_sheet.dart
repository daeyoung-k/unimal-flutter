import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unimal/service/auth/permission_service.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/map/geocoding_api_service.dart';
import 'package:unimal/service/map/models/geocoding_models.dart';
import 'package:unimal/theme/app_colors.dart';

/// 지도 위에 올라오는 공유하기 바텀시트.
///
/// 기존 전체 화면 [`AddItemScreens`]를 대체. 타이틀은 선택, 위치는 필수.
/// docs/share-card-redesign.md §4 디자인 스펙 참고.
///
/// 업로드 성공 시 `Navigator.pop(true)` — 시트를 연 쪽에서 지도 새로고침과
/// 스낵바를 처리한다.
class ShareCardSheet extends StatefulWidget {
  const ShareCardSheet({super.key});

  @override
  State<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends State<ShareCardSheet>
    with WidgetsBindingObserver {
  final BoardApiService _boardApiService = BoardApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  static const int _maxImages = 10;

  final List<File> _images = [];
  GeocodingModel? _myLocation;
  bool _isLoadingLocation = false;
  bool _locationFailed = false;
  bool _locationServiceDisabled = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _myLocation == null &&
        !_isLoadingLocation) {
      _retryLocationSilently();
    }
  }

  bool _canUpload() =>
      _contentController.text.trim().isNotEmpty &&
      _myLocation != null &&
      _myLocation!.streetName.isNotEmpty;

  // ────────────────────────────────────────────────────────────────
  // 위치
  // ────────────────────────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setLocationFailed(serviceDisabled: true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      try {
        permission = await Geolocator.requestPermission();
      } on PermissionRequestInProgressException {
        permission = await Geolocator.checkPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLocationFailed();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setLocationFailed();
      return;
    }

    await _getMyLocation();
  }

  /// 앱 복귀 시 호출 — 권한 프롬프트를 다시 띄우지 않고, 허용된 상태일 때만 재조회.
  Future<void> _retryLocationSilently() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    await _getMyLocation();
  }

  void _setLocationFailed({bool serviceDisabled = false}) {
    if (!mounted) return;
    setState(() {
      _locationFailed = true;
      _locationServiceDisabled = serviceDisabled;
      _isLoadingLocation = false;
    });
  }

  Future<void> _getMyLocation() async {
    if (!mounted) return;
    setState(() => _isLoadingLocation = true);

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) rethrow;
      }

      GeocodingModel geocoding = await GeocodingApiService().getGeocoding(
        position.latitude.toString(),
        position.longitude.toString(),
      );

      if (!mounted) return;
      setState(() {
        _myLocation = geocoding;
        _myLocation?.latitude = position!.latitude.toDouble();
        _myLocation?.longitude = position!.longitude.toDouble();
        _locationFailed = false;
        _locationServiceDisabled = false;
        _isLoadingLocation = false;
      });
    } catch (e) {
      _setLocationFailed();
    }
  }

  Future<void> _openLocationSettings() async {
    if (_locationServiceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await openAppSettings();
    }
  }

  // ────────────────────────────────────────────────────────────────
  // 이미지
  // ────────────────────────────────────────────────────────────────

  Future<bool> _requestPhotoPermission() async {
    final status = await Permission.photos.status;
    if (status.isGranted || status.isLimited) return true;

    final result = await PermissionService().requestPhotosPermission();
    if (result) return true;

    final denied = await Permission.photos.isPermanentlyDenied;
    if (!mounted) return false;
    if (denied) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('사진 접근 권한 필요'),
          content: const Text('사진첩에 접근하려면 설정에서 권한을 허용해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('설정으로 이동'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 접근 권한이 필요합니다.')),
      );
    }
    return false;
  }

  Future<void> _getImage(ImageSource source) async {
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 $_maxImages장까지만 추가할 수 있습니다.')),
      );
      return;
    }
    if (source == ImageSource.gallery) {
      final granted = await _requestPhotoPermission();
      if (!granted) return;
    }
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null && mounted) {
      setState(() => _images.add(File(image.path)));
    }
  }

  Future<void> _getMultipleImages() async {
    int remainingSlots = _maxImages - _images.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 $_maxImages장까지만 추가할 수 있습니다.')),
      );
      return;
    }
    final granted = await _requestPhotoPermission();
    if (!granted) return;

    final List<XFile> images = await _picker.pickMultipleMedia(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (images.isNotEmpty && mounted) {
      setState(() {
        int imagesToAdd =
            images.length > remainingSlots ? remainingSlots : images.length;
        for (int i = 0; i < imagesToAdd; i++) {
          _images.add(File(images[i].path));
        }
      });
      if (images.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$remainingSlots장만 추가되었습니다. (최대 $_maxImages장 제한)')),
        );
      }
    }
  }

  void _onTapAddPhoto() {
    final colors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: colors.primary),
              title: Text(
                '사진첩',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: colors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _getMultipleImages();
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt_outlined, color: colors.primary),
              title: Text(
                '카메라',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  color: colors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // 업로드
  // ────────────────────────────────────────────────────────────────

  Future<void> _onUpload() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      await _boardApiService.createBoard(
        _titleController.text.trim(),
        _contentController.text.trim(),
        _images,
        true, // 지도 노출 토글 제거 — 항상 공개
        _myLocation?.latitude ?? 0,
        _myLocation?.longitude ?? 0,
        _myLocation?.postalCode ?? '',
        _myLocation?.streetName ?? '',
        _myLocation?.siDo ?? '',
        _myLocation?.guGun ?? '',
        _myLocation?.dong ?? '',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      // 실패 알림은 BoardApiService 가 표시 — 폼 상태는 유지.
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final sheetHeight = (media.size.height * 0.88).clamp(
      0.0,
      media.size.height - keyboardInset - 24,
    );

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _DragHandle(color: colors.divider),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Header(color: colors.textPrimary),
                        const SizedBox(height: 16),
                        _TitleField(
                          controller: _titleController,
                          colors: colors,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _ContentField(
                            controller: _contentController,
                            colors: colors,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PhotoRow(
                          images: _images,
                          maxImages: _maxImages,
                          colors: colors,
                          onTap: _onTapAddPhoto,
                          onRemove: (index) =>
                              setState(() => _images.removeAt(index)),
                        ),
                        const SizedBox(height: 16),
                        _LocationCard(
                          streetName: _myLocation?.streetName,
                          isLoading: _isLoadingLocation,
                          hasFailed: _locationFailed,
                          showHint: _images.isEmpty,
                          colors: colors,
                          onTap: _isLoadingLocation ? null : _getCurrentLocation,
                          onOpenSettings: _openLocationSettings,
                        ),
                        const SizedBox(height: 16),
                        _UploadCta(
                          enabled: _canUpload() && !_isUploading,
                          isUploading: _isUploading,
                          colors: colors,
                          onPressed: _onUpload,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Subwidgets
// ────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  final Color color;
  const _DragHandle({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Color color;
  const _Header({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '공유하기',
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  final TextEditingController controller;
  final AppColors colors;
  const _TitleField({required this.controller, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.next,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 15,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: '제목 (선택) — 비우면 내용 첫 줄이 표시돼요.',
          hintStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            color: colors.textMuted,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _ContentField extends StatelessWidget {
  final TextEditingController controller;
  final AppColors colors;
  final VoidCallback onChanged;
  const _ContentField({
    required this.controller,
    required this.colors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          color: colors.textPrimary,
          height: 1.5,
        ),
        decoration: InputDecoration(
          hintText:
              '이 장소에서 느낀 순간을 자유롭게 기록해보세요.\n발길 닿은 곳의 이야기가 지도 위에 남겨져요.',
          hintStyle: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            color: colors.textMuted,
            height: 1.5,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _PhotoRow extends StatelessWidget {
  final List<File> images;
  final int maxImages;
  final AppColors colors;
  final VoidCallback onTap;
  final void Function(int index) onRemove;

  const _PhotoRow({
    required this.images,
    required this.maxImages,
    required this.colors,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: _DashedBorder(
              color: colors.border,
              radius: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '사진 추가',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${images.length}/$maxImages',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '선택사항이에요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              color: colors.textMuted,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == images.length) {
                return GestureDetector(
                  onTap: onTap,
                  child: _DashedBorder(
                    color: colors.border,
                    radius: 12,
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 18,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${images.length}/$maxImages',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return _Thumbnail(
                image: images[index],
                isFirst: index == 0,
                colors: colors,
                onRemove: () => onRemove(index),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '첫 번째 사진이 대표 이미지가 돼요.',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final File image;
  final bool isFirst;
  final AppColors colors;
  final VoidCallback onRemove;

  const _Thumbnail({
    required this.image,
    required this.isFirst,
    required this.colors,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: FileImage(image),
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (isFirst)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                // 사진 위 오버레이 — 사진 콘텐츠 기준이라 테마 무관 고정.
                color: const Color(0x8C000000),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '대표',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors.danger,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                // 사진 위 오버레이 — 테마 무관 고정.
                color: Color(0xFFFFFFFF),
                size: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String? streetName;
  final bool isLoading;
  final bool hasFailed;
  final bool showHint;
  final AppColors colors;
  final VoidCallback? onTap;
  final VoidCallback onOpenSettings;

  const _LocationCard({
    required this.streetName,
    required this.isLoading,
    required this.hasFailed,
    required this.showHint,
    required this.colors,
    required this.onTap,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = streetName?.isNotEmpty == true;
    final showFailed = hasFailed && !isLoading && !hasLocation;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: showFailed
                          ? colors.surfaceMuted
                          : colors.primaryWash,
                      shape: BoxShape.circle,
                    ),
                    child: isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(colors.primary),
                            ),
                          )
                        : Icon(
                            showFailed
                                ? Icons.location_off_rounded
                                : Icons.location_on_rounded,
                            size: 16,
                            color: showFailed
                                ? colors.textMuted
                                : colors.primary,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isLoading
                          ? '위치 정보를 가져오는 중...'
                          : showFailed
                              ? '위치를 확인할 수 없어요'
                              : (hasLocation ? streetName! : '내 위치 추가'),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: (hasLocation || showFailed)
                            ? colors.textSecondary
                            : colors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showFailed)
                    GestureDetector(
                      onTap: onOpenSettings,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Text(
                          '설정 열기',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.primaryStrong,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: colors.textMuted,
                    ),
                ],
              ),
            ),
          ),
          if (showHint) ...[
            Container(height: 1, color: colors.border),
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '사진 없이 올리면 지도에 48시간 동안 노출돼요.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadCta extends StatelessWidget {
  final bool enabled;
  final bool isUploading;
  final AppColors colors;
  final VoidCallback onPressed;

  const _UploadCta({
    required this.enabled,
    required this.isUploading,
    required this.colors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // CTA 전경: primary 배경에는 흰색 고정 (테마 무관). signup.dart 등 기존 패턴과 동일.
    const white = Color(0xFFFFFFFF);
    final fg = enabled ? white : colors.textMuted;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? colors.primary : colors.surfaceVariant,
          disabledBackgroundColor: colors.surfaceVariant,
          foregroundColor: fg,
          disabledForegroundColor: colors.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isUploading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(colors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '업로드 중...',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Text(
                    '소식 업로드',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// Dashed rounded border helper
// ────────────────────────────────────────────────────────────────

class _DashedBorder extends StatelessWidget {
  final Color color;
  final double radius;
  final Widget child;

  const _DashedBorder({
    required this.color,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dashLen = 4.0;
    const gapLen = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashLen;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
