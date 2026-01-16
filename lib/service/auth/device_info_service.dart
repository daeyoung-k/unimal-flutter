import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unimal/state/auth_state.dart';

/// 디바이스 정보 서비스
/// 
/// 이 서비스는 다음과 같은 디바이스 정보를 제공합니다:
/// 1. FCM 토큰
/// 2. 디바이스 모델 (Android/iOS)
/// 3. 시스템 이름 (Android/iOS)
/// 4. 시스템 버전
/// 5. 앱 버전 정보
class DeviceInfoService {
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  final Logger _logger = Logger();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final AuthState _authState = Get.find<AuthState>();
  /// 모든 디바이스 정보 가져오기
  /// 
  /// FCM 토큰, 디바이스 모델, 시스템 정보, 앱 정보를 포함한 전체 정보를 반환합니다.
  /// 
  /// Returns:
  /// - Map<String, dynamic>: 디바이스 정보 맵
  Future<Map<String, dynamic>> getAllDeviceInfo() async {
    try {
      final Map<String, dynamic> deviceInfo = {};

      // 플랫폼 정보
      deviceInfo['platform'] = Platform.operatingSystem;
      deviceInfo['platformVersion'] = Platform.operatingSystemVersion;

      // FCM 토큰
      deviceInfo['fcmToken'] = await getFCMToken();

      // 디바이스 정보 (Android/iOS)
      if (Platform.isAndroid) {
        final androidInfo = await getAndroidDeviceInfo();
        deviceInfo.addAll(androidInfo);
      } else if (Platform.isIOS) {
        final iosInfo = await getIOSDeviceInfo();
        deviceInfo.addAll(iosInfo);
      }

      // 앱 정보
      final appInfo = await getAppInfo();
      deviceInfo.addAll(appInfo);

      return deviceInfo;
    } catch (e, stackTrace) {
      _logger.e('디바이스 정보 수집 실패', error: e, stackTrace: stackTrace);
      return {};
    }
  }

  /// FCM 토큰 가져오기
  /// 
  /// Firebase Cloud Messaging 토큰을 가져옵니다.
  /// 
  /// Returns:
  /// - String?: FCM 토큰 (실패 시 null)
  Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      _logger.i('FCM 토큰 획득 성공');
      _authState.setFCMToken(token!);  
      return token;
    } catch (e, stackTrace) {
      _logger.e('FCM 토큰 획득 실패', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> setFCMToken(String token) async {
    _authState.setFCMToken(token);
  }

  /// Android 디바이스 정보 가져오기
  /// 
  /// Android 디바이스의 모델, 시스템 이름, 버전 정보를 반환합니다.
  /// 
  /// Returns:
  /// - Map<String, dynamic>: Android 디바이스 정보
  Future<Map<String, dynamic>> getAndroidDeviceInfo() async {
    try {
      final AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;

      return {
        'deviceModel': androidInfo.model,              // 디바이스 모델 (예: SM-G991N)
        'deviceManufacturer': androidInfo.manufacturer, // 제조사 (예: samsung)
        'deviceBrand': androidInfo.brand,              // 브랜드 (예: samsung)
        'systemName': 'Android',                       // 시스템 이름
        'systemVersion': androidInfo.version.release,     // Android 버전 (예: 13)
        'sdkVersion': androidInfo.version.sdkInt,      // SDK 버전 (예: 33)
        'deviceId': androidInfo.id,                    // Android ID
        'isPhysicalDevice': androidInfo.isPhysicalDevice, // 실제 디바이스 여부
      };
    } catch (e, stackTrace) {
      _logger.e('Android 디바이스 정보 획득 실패', error: e, stackTrace: stackTrace);
      return {};
    }
  }

  /// iOS 디바이스 정보 가져오기
  /// 
  /// iOS 디바이스의 모델, 시스템 이름, 버전 정보를 반환합니다.
  /// 
  /// Returns:
  /// - Map<String, dynamic>: iOS 디바이스 정보
  Future<Map<String, dynamic>> getIOSDeviceInfo() async {
    try {
      final IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;

      return {
        'deviceModel': iosInfo.model,                  // 디바이스 모델 (예: iPhone)
        'deviceName': iosInfo.name,                    // 디바이스 이름 (예: iPhone)
        'systemName': iosInfo.systemName,              // 시스템 이름 (예: iOS)
        'systemVersion': iosInfo.systemVersion,        // iOS 버전 (예: 16.0)
        'deviceId': iosInfo.identifierForVendor,       // 벤더 식별자
        'isPhysicalDevice': iosInfo.isPhysicalDevice,  // 실제 디바이스 여부
      };
    } catch (e, stackTrace) {
      _logger.e('iOS 디바이스 정보 획득 실패', error: e, stackTrace: stackTrace);
      return {};
    }
  }

  /// 앱 정보 가져오기
  /// 
  /// 앱의 버전, 빌드 번호, 패키지명 등의 정보를 반환합니다.
  /// 
  /// Returns:
  /// - Map<String, dynamic>: 앱 정보
  Future<Map<String, dynamic>> getAppInfo() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();

      return {
        'appName': packageInfo.appName,           // 앱 이름
        'packageName': packageInfo.packageName,   // 패키지명 (com.unimal.android)
        'version': packageInfo.version,           // 앱 버전 (1.0.0)
        'buildNumber': packageInfo.buildNumber,   // 빌드 번호 (1)
      };
    } catch (e, stackTrace) {
      _logger.e('앱 정보 획득 실패', error: e, stackTrace: stackTrace);
      return {};
    }
  }

  /// 간단한 디바이스 정보 가져오기
  /// 
  /// FCM 토큰, 모델, 시스템 이름, 버전만 포함한 간단한 정보를 반환합니다.
  /// 
  /// Returns:
  /// - Map<String, dynamic>: 간단한 디바이스 정보
  Future<Map<String, dynamic>> getSimpleDeviceInfo() async {
    try {
      final Map<String, dynamic> info = {
        'fcmToken': await getFCMToken(),
      };

      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        info['model'] = androidInfo.model;
        info['systemName'] = 'Android';
        info['systemVersion'] = androidInfo.version.release;
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        info['model'] = iosInfo.model;
        info['systemName'] = iosInfo.systemName;
        info['systemVersion'] = iosInfo.systemVersion;
      }

      return info;
    } catch (e, stackTrace) {
      _logger.e('간단한 디바이스 정보 획득 실패', error: e, stackTrace: stackTrace);
      return {};
    }
  }
}
