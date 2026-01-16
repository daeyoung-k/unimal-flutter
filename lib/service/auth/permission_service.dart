import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

/// 권한 요청 서비스
/// 
/// 이 서비스는 다음과 같은 권한 요청 기능을 제공합니다:
/// 1. 알림 권한 (Firebase Messaging)
/// 2. 카메라 권한
/// 3. 위치 권한
/// 4. 사진/갤러리 권한
/// 5. 사진첩/저장소 권한
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  final Logger _logger = Logger();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// 알림 권한 요청
  /// 
  /// Firebase Messaging을 사용하여 알림 권한을 요청합니다.
  /// iOS와 Android 모두 지원합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨
  Future<bool> requestNotificationPermission() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _logger.i('사용자가 알림 권한을 허용했습니다.');
        return true;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        _logger.i('사용자가 임시 알림 권한을 허용했습니다.');
        return true;
      } else {
        _logger.w('사용자가 알림 권한을 거부했습니다.');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('알림 권한 요청 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 알림 권한 상태 확인
  /// 
  /// 현재 알림 권한 상태를 확인합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨 또는 확인 불가
  Future<bool> checkNotificationPermission() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
             settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e, stackTrace) {
      _logger.e('알림 권한 확인 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 카메라 권한 요청
  /// 
  /// 카메라 사용 권한을 요청합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨
  Future<bool> requestCameraPermission() async {
    try {
      PermissionStatus status = await Permission.camera.request();
      
      if (status.isGranted) {
        _logger.i('사용자가 카메라 권한을 허용했습니다.');
        return true;
      } else if (status.isPermanentlyDenied) {
        _logger.w('사용자가 카메라 권한을 영구적으로 거부했습니다. 설정에서 수동으로 허용해야 합니다.');
        return false;
      } else {
        _logger.w('사용자가 카메라 권한을 거부했습니다.');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('카메라 권한 요청 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 카메라 권한 상태 확인
  /// 
  /// 현재 카메라 권한 상태를 확인합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨 또는 확인 불가
  Future<bool> checkCameraPermission() async {
    try {
      PermissionStatus status = await Permission.camera.status;
      return status.isGranted;
    } catch (e, stackTrace) {
      _logger.e('카메라 권한 확인 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 위치 권한 요청
  /// 
  /// 위치 정보 사용 권한을 요청합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨
  Future<bool> requestLocationPermission() async {
    try {
      PermissionStatus status = await Permission.location.request();
      
      if (status.isGranted) {
        _logger.i('사용자가 위치 권한을 허용했습니다.');
        return true;
      } else if (status.isPermanentlyDenied) {
        _logger.w('사용자가 위치 권한을 영구적으로 거부했습니다. 설정에서 수동으로 허용해야 합니다.');
        return false;
      } else {
        _logger.w('사용자가 위치 권한을 거부했습니다.');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('위치 권한 요청 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 위치 권한 상태 확인
  /// 
  /// 현재 위치 권한 상태를 확인합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨 또는 확인 불가
  Future<bool> checkLocationPermission() async {
    try {
      PermissionStatus status = await Permission.location.status;
      return status.isGranted;
    } catch (e, stackTrace) {
      _logger.e('위치 권한 확인 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 사진/갤러리 권한 요청
  /// 
  /// 사진 라이브러리 접근 권한을 요청합니다.
  /// iOS와 Android 모두 지원합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨
  Future<bool> requestPhotosPermission() async {
    try {
      // iOS는 photos, Android는 storage 또는 photos 사용
      Permission permission;
      
      // 플랫폼에 따라 적절한 권한 선택
      // iOS 14 이상: Permission.photos
      // Android: Permission.photos (Android 13+) 또는 Permission.storage (Android 12 이하)
      permission = Permission.photos;
      
      PermissionStatus status = await permission.request();
      
      if (status.isGranted) {
        _logger.i('사용자가 사진 권한을 허용했습니다.');
        return true;
      } else if (status.isPermanentlyDenied) {
        _logger.w('사용자가 사진 권한을 영구적으로 거부했습니다. 설정에서 수동으로 허용해야 합니다.');
        return false;
      } else {
        _logger.w('사용자가 사진 권한을 거부했습니다.');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('사진 권한 요청 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 사진/갤러리 권한 상태 확인
  /// 
  /// 현재 사진 라이브러리 접근 권한 상태를 확인합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨 또는 확인 불가
  Future<bool> checkPhotosPermission() async {
    try {
      PermissionStatus status = await Permission.photos.status;
      return status.isGranted;
    } catch (e, stackTrace) {
      _logger.e('사진 권한 확인 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 사진첩/저장소 권한 요청
  /// 
  /// 사진첩 및 저장소 접근 권한을 요청합니다.
  /// Android 12 이하에서는 storage 권한, Android 13+에서는 photos 권한을 사용합니다.
  /// iOS에서는 photos 권한을 사용합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨
  Future<bool> requestStoragePermission() async {
    try {
      // Android 13 이상: Permission.photos
      // Android 12 이하: Permission.storage
      // iOS: Permission.photos
      
      // 먼저 photos 권한 시도 (Android 13+, iOS)
      PermissionStatus photosStatus = await Permission.photos.status;
      
      if (photosStatus.isDenied) {
        photosStatus = await Permission.photos.request();
      }
      
      // Android 12 이하를 위한 storage 권한도 확인
      PermissionStatus storageStatus = await Permission.storage.status;
      
      if (storageStatus.isDenied) {
        storageStatus = await Permission.storage.request();
      }
      
      // 둘 중 하나라도 허용되면 성공
      bool isGranted = photosStatus.isGranted || storageStatus.isGranted;
      
      if (isGranted) {
        _logger.i('사용자가 사진첩/저장소 권한을 허용했습니다.');
        return true;
      } else if (photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        _logger.w('사용자가 사진첩/저장소 권한을 영구적으로 거부했습니다. 설정에서 수동으로 허용해야 합니다.');
        return false;
      } else {
        _logger.w('사용자가 사진첩/저장소 권한을 거부했습니다.');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('사진첩/저장소 권한 요청 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 사진첩/저장소 권한 상태 확인
  /// 
  /// 현재 사진첩 및 저장소 접근 권한 상태를 확인합니다.
  /// 
  /// Returns:
  /// - true: 권한이 허용됨
  /// - false: 권한이 거부됨 또는 확인 불가
  Future<bool> checkStoragePermission() async {
    try {
      // photos 권한과 storage 권한 둘 다 확인
      PermissionStatus photosStatus = await Permission.photos.status;
      PermissionStatus storageStatus = await Permission.storage.status;
      
      // 둘 중 하나라도 허용되면 true 반환
      return photosStatus.isGranted || storageStatus.isGranted;
    } catch (e, stackTrace) {
      _logger.e('사진첩/저장소 권한 확인 실패', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 모든 권한 요청
  /// 
  /// 알림, 카메라, 위치, 사진, 사진첩 권한을 한 번에 요청합니다.
  /// 
  /// Returns:
  /// - Map<String, bool>: 각 권한별 허용 여부
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};
    
    results['notification'] = await requestNotificationPermission();
    results['camera'] = await requestCameraPermission();
    results['location'] = await requestLocationPermission();
    results['photos'] = await requestPhotosPermission();
    results['storage'] = await requestStoragePermission();
    
    _logger.i('모든 권한 요청 완료: $results');
    return results;
  }

  /// 알림, 위치 권한 요청
  /// 
  /// Returns:
  /// - Map<String, bool>: 각 권한별 허용 여부
  Future<Map<String, bool>> requestNotificationAndLocationPermissions() async {
    final results = <String, bool>{};
    
    results['notification'] = await requestNotificationPermission();
    results['location'] = await requestLocationPermission();
    
    _logger.i('알림, 위치 권한 요청 완료: $results');
    return results;
  }

  /// 모든 권한 상태 확인
  /// 
  /// 알림, 카메라, 위치, 사진, 사진첩 권한의 현재 상태를 확인합니다.
  /// 
  /// Returns:
  /// - Map<String, bool>: 각 권한별 허용 여부
  Future<Map<String, bool>> checkAllPermissions() async {
    final results = <String, bool>{};
    
    results['notification'] = await checkNotificationPermission();
    results['camera'] = await checkCameraPermission();
    results['location'] = await checkLocationPermission();
    results['photos'] = await checkPhotosPermission();
    results['storage'] = await checkStoragePermission();
    
    _logger.i('모든 권한 상태 확인: $results');
    return results;
  }

  /// 설정 화면 열기
  /// 
  /// 권한이 영구적으로 거부된 경우 앱 설정 화면을 열어줍니다.
  Future<void> openSettings() async {
    try {
      await openAppSettings();
      _logger.i('앱 설정 화면을 열었습니다.');
    } catch (e, stackTrace) {
      _logger.e('앱 설정 화면 열기 실패', error: e, stackTrace: stackTrace);
    }
  }
}
