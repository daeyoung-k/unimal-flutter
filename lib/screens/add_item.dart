import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:unimal/service/board/board_api_service.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'package:unimal/service/map/geocoding_api_service.dart';
import 'package:unimal/service/map/models/geocoding_models.dart';

class AddItemScreens extends StatefulWidget {
  const AddItemScreens({super.key});

  @override
  State<AddItemScreens> createState() => _AddItemScreensState();
}

class _AddItemScreensState extends State<AddItemScreens> {

  final BoardApiService _boardApiService = BoardApiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final _maxImageLength = 10; // 최대 사진 개수
  final List<File> _images = []; // 여러 사진을 순서대로 저장할 리스트
  GeocodingModel? _myLocation;
  bool _isLoadingLocation = false; // 위치 로딩 상태

  final ImagePicker _picker = ImagePicker();
  bool isPublic = false;
  bool isAd = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    await _getMyLocation();
  }

  Future<void> _getMyLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      Position position = await Geolocator.getCurrentPosition();
      GeocodingModel geocoding = await GeocodingApiService().getGeocoding(position.latitude.toString(), position.longitude.toString());
      setState(() {
        _myLocation = geocoding;
        _myLocation?.latitude = position.latitude.toDouble();
        _myLocation?.longitude = position.longitude.toDouble();

        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _getImage(ImageSource source) async {
    if (_images.length >= _maxImageLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 ${_maxImageLength}장까지만 추가할 수 있습니다.')),
      );
      return;
    }
    
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _images.add(File(image.path)); // 리스트에 순서대로 추가
      });
    }
  }

  Future<void> _getMultipleImages() async {
    // 현재 추가된 사진 개수 확인
    int remainingSlots = _maxImageLength - _images.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('최대 ${_maxImageLength}장까지만 추가할 수 있습니다.')),
      );
      return;
    }

    // 최대 선택 가능한 개수를 남은 슬롯으로 제한
    final List<XFile> images = await _picker.pickMultipleMedia(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      setState(() {
        // 남은 슬롯만큼만 추가
        int imagesToAdd = images.length > remainingSlots ? remainingSlots : images.length;
        for (int i = 0; i < imagesToAdd; i++) {
          _images.add(File(images[i].path));
        }
      });

      // 선택한 사진이 남은 슬롯보다 많을 경우 알림
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
      backgroundColor: const Color(0xFF4D91FF),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '공유하기',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 사진 추가 영역
                const Text('대표 이미지는 지도에 노출돼요.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    )),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // 추가 사진 영역
                      GestureDetector(
                        onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [                              
                              ListTile(
                                leading: const Icon(Icons.photo_library_outlined),
                                title: const Text('사진첩'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _getMultipleImages();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('카메라'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _getImage(ImageSource.camera);
                                },
                              ),
                            ],
                          ),
                        );
                        },
                        child: Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: Colors.grey[600]),
                              Text('사진 ${_images.length}/${_maxImageLength}', 
                                  style: TextStyle(
                                    color: Colors.grey[600], 
                                    fontSize: 12,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w600,
                                  ), 
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 추가된 사진들을 순서대로 표시
                      ..._images.asMap().entries.map((entry) {
                        int index = entry.key;
                        File image = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Container(
                                width: 80, height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: DecorationImage(
                                    image: FileImage(image),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // 첫 번째 사진에만 "대표" 라벨 표시
                              if (index == 0)
                                Positioned(
                                  top: 4, left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4D91FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '대표',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Pretendard',
                                      ),
                                    ),
                                  ),
                                ),
                              // // 순서 번호 표시 (첫 번째 사진이 아닌 경우에만)
                              // if (index != 0) 번호표시 제거
                              //   Positioned(
                              //     top: 4, left: 4,
                              //     child: Container(
                              //       width: 20, height: 20,
                              //       decoration: BoxDecoration(
                              //         color: Colors.black54,
                              //         borderRadius: BorderRadius.circular(10),
                              //       ),
                              //       child: Center(
                              //         child: Text(
                              //           '${index + 1}',
                              //           style: const TextStyle(
                              //             color: Colors.white,
                              //             fontSize: 12,
                              //             fontWeight: FontWeight.bold,
                              //           ),
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              // 삭제 버튼
                              Positioned(
                                top: 4, right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _images.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('제목',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  onChanged: (value) => setState(() {}), // 실시간 버튼 상태 업데이트
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 15),

                // 내용 입력
                const Text('내용',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  onChanged: (value) => setState(() {}), // 실시간 버튼 상태 업데이트
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: '우리 주변 친구들의 소식을 공유해주세요.',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                // 위치 추가
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: _isLoadingLocation 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                            ),
                          )
                        : Icon(Icons.location_on, color: Colors.grey[600]),
                    title: Text(
                        _isLoadingLocation 
                            ? '위치 정보를 가져오는 중...'
                            : (_myLocation?.streetName ?? '내 위치 추가'), 
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                    trailing: _isLoadingLocation 
                        ? null 
                        : Icon(Icons.chevron_right, color: Colors.grey[600]),
                    onTap: _isLoadingLocation ? null : () async {
                      await _getMyLocation();
                    },
                  ),
                ),   
                const SizedBox(height: 20),

                // 전체 공개 스위치
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text('지도 노출', 
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text('노출 설정시 지도위에 표시됩니다.', 
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontFamily: 'Pretendard',
                        )),
                    value: isPublic,
                    onChanged: (v) => setState(() => isPublic = v),
                    activeColor: const Color(0xFF4D91FF),
                  ),
                ),
                
                const SizedBox(height: 32),

                // 하단 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _canUpload() ? _uploadPost : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canUpload() ? Colors.white : Colors.grey[300],
                      foregroundColor: _canUpload() ? const Color(0xFF4D91FF) : Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _canUpload() ? 4 : 0,
                      shadowColor: _canUpload() ? Colors.black.withValues(alpha: 0.1) : Colors.transparent,
                    ),
                    child: _canUpload() 
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upload_rounded,
                                size: 20,
                                color: const Color(0xFF4D91FF),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '소식 업로드',
                                style: TextStyle(
                                  color: const Color(0xFF4D91FF),
                                  fontSize: 16,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upload_rounded,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '소식 업로드',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
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

  // 업로드 가능 여부 확인
  bool _canUpload() {
    return _titleController.text.trim().isNotEmpty &&
           _contentController.text.trim().isNotEmpty &&
           _myLocation != null &&
           _myLocation!.streetName.isNotEmpty &&
           _myLocation!.postalCode.isNotEmpty;
  }

  // 소식 업로드 함수
  void _uploadPost() async {
    await _boardApiService.createBoard(
      _titleController.text,
      _contentController.text,
      _images,
      isPublic,
      _myLocation?.latitude ?? 0,
      _myLocation?.longitude ?? 0,
      _myLocation?.postalCode ?? '',
      _myLocation?.streetName ?? '',
      _myLocation?.siDo ?? '',
      _myLocation?.guGun ?? '',
      _myLocation?.dong ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
