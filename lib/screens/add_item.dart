import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class AddItemScreens extends StatefulWidget {
  const AddItemScreens({super.key});

  @override
  State<AddItemScreens> createState() => _AddItemScreensState();
}

class _AddItemScreensState extends State<AddItemScreens> {
  final TextEditingController _contentController = TextEditingController();

  final _maxImageLength = 10; // 최대 사진 개수
  final List<File> _images = []; // 여러 사진을 순서대로 저장할 리스트

  Position? _currentPosition;
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

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });
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
                const Text('첫번째 사진이 대표 사진이 됩니다.',
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
                              // 순서 번호 표시
                              Positioned(
                                top: 4, left: 4,
                                child: Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
                    leading: Icon(Icons.location_on, color: Colors.grey[600]),
                    title: Text('내 위치 추가', 
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        )),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
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
                    title: Text('전체 공개', 
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        )),
                    subtitle: Text('위치 적용 후 전체 공개 시 지도위에 표시됩니다.', 
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
                  height: 50,
                  child: ElevatedButton(
                    onPressed: null, // 조건 충족 시 함수로 변경
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text('소식 업로드', 
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
