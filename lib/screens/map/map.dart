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
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  BitmapDescriptor? _customMarkerIcon;

  static const LatLng _seoulStation = LatLng(37.5547, 126.9706);

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } on PermissionRequestInProgressException {
          permission = await Geolocator.checkPermission();
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;
      setState(() => _currentPosition = position);

      await _loadCustomMarkerIcon();
      _addCustomMarker();

      try {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      } catch (_) {}
    } catch (_) {
      // 권한 없음 또는 타임아웃 시 서울역 기본값 유지
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      try {
        controller.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          ),
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _seoulStation;

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
                heroTag: 'map_location_fab',
                mini: true,
                onPressed: () {
                  if (_currentPosition != null) {
                    try {
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLng(
                          LatLng(_currentPosition!.latitude,
                              _currentPosition!.longitude),
                        ),
                      );
                    } catch (_) {}
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
