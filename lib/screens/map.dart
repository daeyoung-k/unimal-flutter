import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreens extends StatefulWidget {
  const MapScreens({super.key});

  @override
  State<MapScreens> createState() => MapStateScreens();
}

class MapStateScreens extends State<MapScreens> {
  late GoogleMapController mapController;
  Position? _currentPosition;
  bool _isLoading = true;

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
          title: const Text('Unimal Maps'),
          backgroundColor: const Color(0xFFFEF7FF),
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
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF4D91FF),),
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
                        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      ),
                    );
                  } else {
                    _getCurrentLocation();
                  }
                },
                backgroundColor: const Color(0xFFFFFFFF),                
                child: const Icon(Icons.my_location, color: Color(0xFF4D91FF), size: 25,),
              ),
            ),
          ],
        ));
  }
}
