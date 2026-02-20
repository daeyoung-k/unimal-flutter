// import 'dart:convert'; // 실제 서버 API 연동 시 주석 해제
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // 실제 서버 API 연동 시 주석 해제
import 'package:get/get.dart';
// import 'package:http/http.dart' as http; // 실제 서버 API 연동 시 주석 해제
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unimal/utils/api_uri.dart';
import 'package:url_launcher/url_launcher.dart';

/// 앱 업데이트 확인 서비스
/// 
/// 이 서비스는 다음과 같은 기능을 제공합니다:
/// 1. 현재 앱 버전 확인
/// 2. 서버에서 최신 버전 정보 확인
/// 3. 업데이트 필요 여부 판단
/// 4. 강제 업데이트 여부 확인
/// 5. 앱 스토어로 이동
class UpdateCheckService {
  static final UpdateCheckService _instance = UpdateCheckService._internal();
  factory UpdateCheckService() => _instance;
  UpdateCheckService._internal();

  final Logger _logger = Logger();
  
  // 실제 서버 API 연동 시 주석 해제
  // final host = Platform.isAndroid
  //     ? dotenv.env['ANDORID_SERVER']
  //     : dotenv.env['IOS_SERVER'];
  
  // final headers = {"Content-Type": "application/json;charset=utf-8"};

  PackageInfo? _packageInfo;
  String? _currentVersion;
  int? _currentBuildNumber;

  /// 현재 앱 버전 정보 초기화
  /// 
  /// 앱 시작 시 한 번 호출하여 현재 버전 정보를 가져옵니다.
  Future<void> initialize() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = _packageInfo?.version;
      _currentBuildNumber = int.tryParse(_packageInfo?.buildNumber ?? '0');
      _logger.i('현재 앱 버전: $_currentVersion (빌드: $_currentBuildNumber)');
    } catch (e, stackTrace) {
      _logger.e('앱 버전 정보 초기화 실패', error: e, stackTrace: stackTrace);
    }
  }

  /// 현재 앱 버전 가져오기
  /// 
  /// Returns:
  /// - String: 현재 앱 버전 (예: "1.0.0")
  String? getCurrentVersion() {
    return _currentVersion;
  }

  /// 현재 빌드 번호 가져오기
  /// 
  /// Returns:
  /// - int: 현재 빌드 번호
  int? getCurrentBuildNumber() {
    return _currentBuildNumber;
  }

  /// 서버에서 최신 버전 정보 확인
  /// 
  /// 서버 API를 통해 최신 앱 버전 정보를 가져옵니다.
  /// 
  /// Returns:
  /// - UpdateInfo?: 최신 버전 정보 (실패 시 null)
  Future<UpdateInfo?> checkLatestVersion() async {
    // 임시: 테스트용 고정 값 (실제 서버 API 연동 시 아래 주석 해제)
    return UpdateInfo.fromJson({
      'version': '1.0.1',
      'buildNumber': 2,
      'isForceUpdate': false,
      'updateMessage': '새로운 버전이 출시되었습니다.',
      'releaseNotes': '버그 수정 및 성능 개선',
    });
    
    /* 실제 서버 API 연동 시 사용
    try {
      final url = ApiUri.resolve('/app/version/check');
      
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.w('버전 확인 요청 타임아웃');
          throw TimeoutException('버전 확인 요청이 시간 초과되었습니다.');
        },
      );

      if (response.statusCode == 200) {
        final bodyData = jsonDecode(utf8.decode(response.bodyBytes));
        
        if (bodyData['code'] == 200) {
          final data = bodyData['data'];
          return UpdateInfo.fromJson(data);
        } else {
          _logger.w('버전 확인 실패: ${bodyData['message']}');
          return null;
        }
      } else {
        _logger.w('버전 확인 실패: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      _logger.e('버전 확인 중 오류 발생', error: e, stackTrace: stackTrace);
      return null;
    }
    */
  }

  /// 업데이트 필요 여부 확인
  /// 
  /// 현재 버전과 최신 버전을 비교하여 업데이트가 필요한지 확인합니다.
  /// 
  /// Returns:
  /// - UpdateStatus: 업데이트 상태 (업데이트 불필요, 선택적 업데이트, 강제 업데이트)
  Future<UpdateStatus> checkUpdateStatus() async {
    try {
      // 현재 버전 정보가 없으면 초기화
      if (_currentVersion == null) {
        await initialize();
      }

      // 초기화 후에도 버전 정보가 없으면 오류 반환
      if (_currentVersion == null) {
        _logger.w('현재 앱 버전 정보를 가져올 수 없습니다.');
        return UpdateStatus.unknown;
      }

      // 최신 버전 정보 가져오기
      final latestVersionInfo = await checkLatestVersion();
      
      if (latestVersionInfo == null) {
        _logger.w('최신 버전 정보를 가져올 수 없습니다.');
        return UpdateStatus.unknown;
      }

      // 버전 비교 (null 체크 후 안전하게 사용)
      final currentVersion = _currentVersion!;
      final currentVersionParts = currentVersion.split('.');
      final latestVersionParts = latestVersionInfo.version.split('.');

      // 메이저, 마이너, 패치 버전 비교
      for (int i = 0; i < 3; i++) {
        final current = int.tryParse(currentVersionParts[i]) ?? 0;
        final latest = int.tryParse(latestVersionParts[i]) ?? 0;

        if (latest > current) {
          // 강제 업데이트 여부 확인
          if (latestVersionInfo.isForceUpdate) {
            _logger.i('강제 업데이트가 필요합니다. 최신 버전: ${latestVersionInfo.version}');
            return UpdateStatus.forceUpdate;
          } else {
            _logger.i('선택적 업데이트가 있습니다. 최신 버전: ${latestVersionInfo.version}');
            return UpdateStatus.optionalUpdate;
          }
        } else if (latest < current) {
          // 현재 버전이 더 높은 경우 (개발/테스트 환경)
          break;
        }
      }

      // 빌드 번호 비교 (버전이 같을 경우)
      if (_currentBuildNumber != null && 
          latestVersionInfo.buildNumber != null &&
          latestVersionInfo.buildNumber! > _currentBuildNumber!) {
        if (latestVersionInfo.isForceUpdate) {
          return UpdateStatus.forceUpdate;
        } else {
          return UpdateStatus.optionalUpdate;
        }
      }

      _logger.i('앱이 최신 버전입니다.');
      return UpdateStatus.upToDate;
    } catch (e, stackTrace) {
      _logger.e('업데이트 상태 확인 중 오류 발생', error: e, stackTrace: stackTrace);
      return UpdateStatus.unknown;
    }
  }

  /// 앱 스토어로 이동
  /// 
  /// 플랫폼에 따라 Google Play Store 또는 App Store로 이동합니다.
  /// 
  /// Returns:
  /// - bool: 이동 성공 여부
  Future<bool> openAppStore() async {
    try {
      String url;
      
      if (Platform.isAndroid) {
        // Google Play Store URL
        // TODO: 실제 패키지 이름으로 변경 필요
        url = 'https://play.google.com/store/apps/details?id=com.unimal.android';
      } else if (Platform.isIOS) {
        // App Store URL
        // TODO: 실제 앱 ID로 변경 필요
        url = 'https://apps.apple.com/app/id1234567890';
      } else {
        _logger.w('지원하지 않는 플랫폼입니다.');
        return false;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _logger.i('앱 스토어로 이동했습니다: $url');
        return true;
      } else {
        _logger.w('앱 스토어를 열 수 없습니다: $url');
        return false;
      }
    } catch (e, stackTrace) {
      _logger.e('앱 스토어 이동 중 오류 발생', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 업데이트 확인 및 처리
  /// 
  /// 업데이트 상태를 확인하고, 버전이 다르면 알림창을 표시합니다.
  /// 
  /// Returns:
  /// - UpdateStatus: 업데이트 상태
  Future<UpdateStatus> checkAndHandleUpdate() async {
    final status = await checkUpdateStatus();
    
    // 현재 버전과 최신 버전이 다른 경우 알림창 표시
    if (status == UpdateStatus.optionalUpdate || status == UpdateStatus.forceUpdate) {
      final latestVersionInfo = await checkLatestVersion();
      if (latestVersionInfo != null) {
        await _showUpdateDialog(latestVersionInfo);
      }
    }
    
    return status;
  }

  /// 업데이트 알림 다이얼로그 표시
  /// 
  /// 배경 터치 불가, 확인 버튼으로 앱 스토어 이동, 취소 버튼으로 앱 종료
  Future<void> _showUpdateDialog(UpdateInfo updateInfo) async {
    await Get.dialog(
      PopScope(
        canPop: false, // 뒤로가기 버튼 비활성화
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          // 뒤로가기 시 아무 동작도 하지 않음
        },
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 제목
                const Text(
                  '업데이트',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 16),
                // 메시지
                Text(
                  '업데이트를 진행해주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                  ),
                ),                
                const SizedBox(height: 24),
                // 버튼들
                Row(
                  children: [
                    // 취소 버튼 (앱 종료)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // 앱 종료
                          if (Platform.isAndroid) {
                            SystemNavigator.pop();
                          } else {
                            exit(0);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 확인 버튼 (앱 스토어 이동)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Get.back(); // 다이얼로그 닫기
                          await openAppStore();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4D91FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false, // 배경 터치로 닫기 불가
    );
  }
}

/// 업데이트 정보 모델
class UpdateInfo {
  final String version;
  final int? buildNumber;
  final bool isForceUpdate;
  final String? updateMessage;
  final String? releaseNotes;

  UpdateInfo({
    required this.version,
    this.buildNumber,
    required this.isForceUpdate,
    this.updateMessage,
    this.releaseNotes,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String,
      buildNumber: json['buildNumber'] as int?,
      isForceUpdate: json['isForceUpdate'] as bool? ?? false,
      updateMessage: json['updateMessage'] as String?,
      releaseNotes: json['releaseNotes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'isForceUpdate': isForceUpdate,
      'updateMessage': updateMessage,
      'releaseNotes': releaseNotes,
    };
  }
}

/// 업데이트 상태 열거형
enum UpdateStatus {
  upToDate,        // 최신 버전
  optionalUpdate, // 선택적 업데이트
  forceUpdate,    // 강제 업데이트
  unknown,        // 확인 불가
}

/// TimeoutException 클래스
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => message;
}
