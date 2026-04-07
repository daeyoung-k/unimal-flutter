import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unimal/screens/profile/setting/permission_setting.dart';
import 'package:unimal/service/auth/permission_service.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'dart:io';

import 'package:unimal/service/map/geocoding_api_service.dart';
import 'package:unimal/service/map/models/geocoding_models.dart';

class AddItemScreens extends StatefulWidget {
  const AddItemScreens({super.key});

  @override
  State<AddItemScreens> createState() => _AddItemScreensState();
}

class _AddItemScreensState extends State<AddItemScreens>
    with SingleTickerProviderStateMixin {
  final BoardApiService _boardApiService = BoardApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final _maxImageLength = 10;
  final List<File> _images = [];
  GeocodingModel? _myLocation;
  bool _isLoadingLocation = false;
  bool _isUploading = false;

  final ImagePicker _picker = ImagePicker();
  bool isShow = true;

  bool _lastTickerEnabled = false;

  static const Color _primary = Color(0xFF7AB3FF);
  static const Color _primaryDark = Color(0xFF3578E5);

  late AnimationController _ctrl;
  late Animation<Offset> _headerSlide;
  late Animation<double> _headerFade;
  late Animation<Offset> _card1Slide;
  late Animation<double> _card1Fade;
  late Animation<Offset> _card2Slide;
  late Animation<double> _card2Fade;
  late Animation<Offset> _card3Slide;
  late Animation<double> _card3Fade;
  late Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _headerSlide = Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _headerFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
    );
    _card1Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.5, curve: Curves.easeOut)),
    );
    _card1Fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.45, curve: Curves.easeOut)),
    );
    _card2Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.65, curve: Curves.easeOut)),
    );
    _card2Fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );
    _card3Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.8, curve: Curves.easeOut)),
    );
    _card3Fade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.75, curve: Curves.easeOut)),
    );
    _btnFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)),
    );

  }


  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationRequiredDialog();
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
        _showLocationRequiredDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationRequiredDialog();
      return;
    }

    await _getMyLocation();
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
        position!.latitude.toString(),
        position.longitude.toString(),
      );

      if (!mounted) return;
      setState(() {
        _myLocation = geocoding;
        _myLocation?.latitude = position!.latitude.toDouble();
        _myLocation?.longitude = position!.longitude.toDouble();
        _isLoadingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLocation = false);
      _showLocationRequiredDialog();
    }
  }

  void _showLocationRequiredDialog() {
    if (!mounted) return;
    if (!TickerMode.of(context)) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Color(0xFF7AB3FF)),
            SizedBox(width: 8),
            Text(
              '위치 정보 필요',
              style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          '위치 정보 없이는 게시글을 올릴 수 없습니다.\n지도 화면에서 위치 권한을 허용해 주세요.',
          style: TextStyle(fontFamily: 'Pretendard', fontSize: 14, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Get.to(() => const PermissionSettingScreen());
            },
            child: const Text(
              '권한설정으로 이동',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
                color: Color(0xFF7AB3FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () { Navigator.pop(context); openAppSettings(); },
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
    if (_images.length >= _maxImageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 ${_maxImageLength}장까지만 추가할 수 있습니다.')),
      );
      return;
    }
    if (source == ImageSource.gallery) {
      final granted = await _requestPhotoPermission();
      if (!granted) return;
    }
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() => _images.add(File(image.path)));
    }
  }

  Future<void> _getMultipleImages() async {
    int remainingSlots = _maxImageLength - _images.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 ${_maxImageLength}장까지만 추가할 수 있습니다.')),
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

    if (images.isNotEmpty) {
      setState(() {
        int imagesToAdd = images.length > remainingSlots ? remainingSlots : images.length;
        for (int i = 0; i < imagesToAdd; i++) {
          _images.add(File(images[i].path));
        }
      });
      if (images.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${remainingSlots}장만 추가되었습니다. (최대 ${_maxImageLength}장 제한)')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryDark, _primary, Color(0xFFA8CCFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 헤더
              FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '공유하기',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 본문
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 이미지 영역 (card1)
                      FadeTransition(
                        opacity: _card1Fade,
                        child: SlideTransition(
                          position: _card1Slide,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      // 안내 텍스트
                      const Text(
                        '첫 번째 사진이 지도 위 스토리의 대표 이미지로 표시돼요.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 이미지 업로드 영역
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // 추가 버튼
                            GestureDetector(
                              onTap: () => showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (context) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 40, height: 4,
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300],
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo_library_outlined, color: _primary),
                                        title: const Text('사진첩', style: TextStyle(fontFamily: 'Pretendard')),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _getMultipleImages();
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt_outlined, color: _primary),
                                        title: const Text('카메라', style: TextStyle(fontFamily: 'Pretendard')),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _getImage(ImageSource.camera);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.95),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _primary.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add_rounded, color: _primary, size: 22),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_images.length}/$_maxImageLength',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11,
                                        fontFamily: 'Pretendard',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 추가된 이미지들
                            ..._images.asMap().entries.map((entry) {
                              int index = entry.key;
                              File image = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        image: DecorationImage(
                                          image: FileImage(image),
                                          fit: BoxFit.cover,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (index == 0)
                                      Positioned(
                                        top: 6, left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _primary,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '대표',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontFamily: 'Pretendard',
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Positioned(
                                      top: 4, right: 4,
                                      child: GestureDetector(
                                        onTap: () => setState(() => _images.removeAt(index)),
                                        child: Container(
                                          width: 20, height: 20,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFF6B6B),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),

                      // 제목 + 내용 카드 (card2)
                      FadeTransition(
                        opacity: _card2Fade,
                        child: SlideTransition(
                          position: _card2Slide,
                          child: Column(
                            children: [
                      // 제목 카드
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '제목',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _titleController,
                              onChanged: (v) => setState(() {}),
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 16,
                                color: Color(0xFF1A1A2E),
                              ),
                              decoration: const InputDecoration(
                                hintText: '이 장소의 이야기를 제목으로 남겨보세요.',
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontFamily: 'Pretendard',
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 내용 카드
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '내용',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _contentController,
                              onChanged: (v) => setState(() {}),
                              maxLines: 5,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 15,
                                color: Color(0xFF1A1A2E),
                              ),
                              decoration: const InputDecoration(
                                hintText: '이 장소에서 느낀 순간을 자유롭게 기록해보세요.\n발길 닿은 곳의 이야기가 지도 위에 남겨져요.',
                                hintStyle: TextStyle(
                                  color: Colors.grey,
                                  fontFamily: 'Pretendard',
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),

                      // 위치 + 토글 카드 (card3)
                      FadeTransition(
                        opacity: _card3Fade,
                        child: SlideTransition(
                          position: _card3Slide,
                          child: Column(
                            children: [
                      // 위치 카드
                      GestureDetector(
                        onTap: _isLoadingLocation ? null : _getCurrentLocation,
                        child: _buildCard(
                          child: Row(
                            children: [
                              _isLoadingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(_primary),
                                      ),
                                    )
                                  : const Icon(Icons.location_on_rounded, color: _primary, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isLoadingLocation
                                      ? '위치 정보를 가져오는 중...'
                                      : (_myLocation?.streetName ?? '내 위치 추가'),
                                  style: TextStyle(
                                    color: _myLocation != null ? const Color(0xFF1A1A2E) : Colors.grey,
                                    fontFamily: 'Pretendard',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 지도 노출 토글 카드
                      _buildCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '지도 노출',
                                    style: TextStyle(
                                      color: Color(0xFF1A1A2E),
                                      fontFamily: 'Pretendard',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '켜두면 내 스토리가 지도에 핀으로 표시돼요.',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontFamily: 'Pretendard',
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isShow,
                              onChanged: (v) => setState(() => isShow = v),
                              activeColor: _primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 업로드 버튼
                      FadeTransition(
                        opacity: _btnFade,
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_canUpload() && !_isUploading) ? _uploadPost : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _canUpload() && !_isUploading
                                  ? Colors.white.withOpacity(0.95)
                                  : Colors.white.withOpacity(0.4),
                              foregroundColor: _primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: _canUpload() && !_isUploading ? 6 : 0,
                              shadowColor: Colors.black.withOpacity(0.15),
                            ),
                            child: _isUploading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(_primary),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        '업로드 중...',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: _primary,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        size: 18,
                                        color: _canUpload() ? _primary : Colors.grey,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '소식 업로드',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: _canUpload() ? _primary : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),  // FadeTransition 업로드 버튼
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  bool _canUpload() {
    return _titleController.text.trim().isNotEmpty &&
        _contentController.text.trim().isNotEmpty &&
        _myLocation != null &&
        _myLocation!.streetName.isNotEmpty;
  }

  void _clearForm() {
    _titleController.clear();
    _contentController.clear();
    setState(() {
      _images.clear();
      _myLocation = null;
      isShow = true;
    });
  }

  void _uploadPost() async {
    setState(() => _isUploading = true);
    try {
      await _boardApiService.createBoard(
        _titleController.text,
        _contentController.text,
        _images,
        isShow,
        _myLocation?.latitude ?? 0,
        _myLocation?.longitude ?? 0,
        _myLocation?.postalCode ?? '',
        _myLocation?.streetName ?? '',
        _myLocation?.siDo ?? '',
        _myLocation?.guGun ?? '',
        _myLocation?.dong ?? '',
      );
      _clearForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업로드에 실패했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void onTabEntered() {
    _ctrl.forward(from: 0);
    if (_myLocation == null && !_isLoadingLocation) {
      _getCurrentLocation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.of(context);
    if (tickerEnabled && !_lastTickerEnabled) {
      _ctrl.forward(from: 0);
    }
    _lastTickerEnabled = tickerEnabled;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
