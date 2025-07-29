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
  File? _image;
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
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
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
                const Text('사진 추가',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                    )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // 메인사진 추가 영역
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('사진첩'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _getImage(ImageSource.gallery);
                                  print(_currentPosition?.latitude);
                                  print(_currentPosition?.longitude);
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
                        width: 80, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.grey[600]),
                            Text('메인사진\n추가', 
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
                    const SizedBox(width: 12),
                    // 추가 사진 영역
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('사진첩'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _getImage(ImageSource.gallery);
                                  print(_currentPosition?.latitude);
                                  print(_currentPosition?.longitude);
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
                        width: 80, height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.grey[600]),
                            Text('사진 추가\n0/15', 
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
                    // ...이미지 썸네일 리스트
                  ],
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
