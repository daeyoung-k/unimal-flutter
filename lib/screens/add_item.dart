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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: BackButton(color: Colors.white),
        title: Text('데이로그 작성', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 사진 추가 영역
            Row(
              children: [
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
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Colors.white),
                        Text('사진 추가\n0/15', style: TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
                // ...이미지 썸네일 리스트
              ],
            ),
            SizedBox(height: 16),
            // 안내 문구
            Text('공간에서의 경험이나 정보를 ...', style: TextStyle(color: Colors.white70)),
            // ...
            // 공간 추가, 방문 날짜, 커뮤니티 선택 등
            ListTile(
              title: Text('공간 추가', style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.chevron_right, color: Colors.white),
            ),
            // 방문 날짜
            ListTile(
              title: Text('방문한 날짜', style: TextStyle(color: Colors.white)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('2025년 1월 4일', style: TextStyle(color: Colors.white)),
                  Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
            // 커뮤니티 선택
            ListTile(
              title: Text('커뮤니티 선택', style: TextStyle(color: Colors.white)),
              trailing: Icon(Icons.chevron_right, color: Colors.white),
            ),
            // 전체 공개 스위치
            SwitchListTile(
              title: Text('전체 공개', style: TextStyle(color: Colors.white)),
              value: isPublic,
              onChanged: (v) => setState(() => isPublic = v),
              activeColor: Colors.blue,
            ),
            // 유료 광고 포함 스위치
            SwitchListTile(
              title: Text('유료 광고 포함', style: TextStyle(color: Colors.white)),
              subtitle: Text('...설명...', style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: isAd,
              onChanged: (v) => setState(() => isAd = v),
              activeColor: Colors.blue,
            ),
            // 하단 버튼
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(vertical: 24),
              child: ElevatedButton(
                onPressed: null, // 조건 충족 시 함수로 변경
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  disabledBackgroundColor: Colors.grey[800],
                ),
                child: Text('데이로그 업로드', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
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
