import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreens extends StatefulWidget {
  const MapScreens({super.key});

  @override
  State<MapScreens> createState() => MapStateScreens();
}

class MapStateScreens extends State<MapScreens> {
  late GoogleMapController mapController;

  final LatLng _center = const LatLng(37.540972, 127.086811);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Unimal Maps'),
          backgroundColor: const Color(0xFFFEF7FF),
        ),
        body: GoogleMap(
          cloudMapId: Platform.isIOS
              ? dotenv.env["MAP_STYLE_IOS_ID"]
              : dotenv.env["MAP_STYLE_ANDROID_ID"],
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _center,
            zoom: 14.0,
          ),
        ));
  }
}
