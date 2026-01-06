import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import 'package:unimal/service/image/image_service.dart';

class MapScreens extends StatefulWidget {
  const MapScreens({super.key});

  @override
  State<MapScreens> createState() => MapStateScreens();
}

class MapStateScreens extends State<MapScreens> {
  final ImageService imageService = ImageService();
  late GoogleMapController mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  BitmapDescriptor? _customMarkerIcon;

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    // 위치 서비스 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // 위치 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    // 위치 정보 가져오기
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      // 커스텀 마커 아이콘 로드
      await _loadCustomMarkerIcon();

      // 커스텀 마커 추가
      _addCustomMarker();

      // 위치 정보가 업데이트되면 지도 중심 이동
      mapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomMarkerIcon() async {
    final ImageStream stream = await imageService.getImageStream();
    final Uint8List bytes = await imageService.createMarkerImage(stream);
    _customMarkerIcon = BitmapDescriptor.bytes(bytes, width: 50, height: 50);
  }

  void _addCustomMarker() {
    if (_currentPosition != null && _customMarkerIcon != null) {
      // 현재 위치 근처에 마커 추가 (약간 오프셋)
      final markerPosition = LatLng(
        37.500026 + 0.001, // 약 100m 북쪽
        127.030946 + 0.001, // 약 100m 동쪽
      );

      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('custom_marker'),
            position: markerPosition,
            infoWindow: const InfoWindow(
              title: '커스텀 마커',
              snippet: '이곳에 특별한 장소가 있습니다!',
            ),
            icon: _customMarkerIcon!,
          ),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 새로고침 메서드: 위치 정보와 마커를 다시 로드
  Future<void> refreshMap() async {
    setState(() {
      _markers.clear();
      _customMarkerIcon = null;
    });
    await _getCurrentLocation();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    // 지도가 생성된 후 위치 정보가 있다면 중심 이동
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = LatLng(_currentPosition?.latitude ?? 37.500026,
        _currentPosition?.longitude ?? 127.030946);

    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF4D91FF),
          title: const Text(
            'Unimal',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Stack(
          children: [
            GoogleMap(
              cloudMapId: Platform.isIOS
                  ? dotenv.env["MAP_STYLE_IOS_ID"]
                  : dotenv.env["MAP_STYLE_ANDROID_ID"],
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: 14.0,
              ),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              markers: _markers,
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4D91FF),
                ),
              ),
            Positioned(
              left: 16,
              bottom: 40,
              child: FloatingActionButton(
                mini: true,
                onPressed: () {
                  if (_currentPosition != null) {
                    mapController.animateCamera(
                      CameraUpdate.newLatLng(
                        LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude),
                      ),
                    );
                  } else {
                    _getCurrentLocation();
                  }
                },
                backgroundColor: const Color(0xFFFFFFFF),
                child: const Icon(
                  Icons.my_location,
                  color: Color(0xFF4D91FF),
                  size: 25,
                ),
              ),
            ),
          ],
        ));
  }
}
