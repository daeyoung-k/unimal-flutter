import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:unimal/state/auth_state.dart';

/// Firebase Cloud Messaging 푸시 알림 서비스
/// 
/// 이 서비스는 다음과 같은 기능을 제공합니다:
/// 1. FCM 토큰 관리 및 백엔드 서버로 전송
/// 2. 포그라운드/백그라운드/종료 상태에서의 알림 수신 처리
/// 3. 로컬 알림 표시
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final AuthState _authState = Get.find<AuthState>();

  final Logger _logger = Logger();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // FCM 토큰을 저장할 스트림 컨트롤러
  final StreamController<String> _tokenController = StreamController<String>.broadcast();
  Stream<String> get tokenStream => _tokenController.stream;

  // 알림 클릭 이벤트를 저장할 스트림 컨트롤러
  final StreamController<RemoteMessage> _messageController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageController.stream;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  bool _initialized = false;

  /// 푸시 알림 서비스 초기화
  /// 
  /// 앱 시작 시 한 번만 호출해야 합니다.
  /// 권한 요청, 토큰 획득, 알림 핸들러 설정을 수행합니다.
  Future<void> initialize() async {
    if (_initialized) {
      _logger.w('PushNotificationService는 이미 초기화되었습니다.');
      return;
    }

    try {
      // 로컬 알림 초기화
      await _initializeLocalNotifications();

      // 알림 권한 요청 (iOS)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _logger.i('사용자가 알림 권한을 허용했습니다.');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        _logger.i('사용자가 임시 알림 권한을 허용했습니다.');
      } else {
        _logger.w('사용자가 알림 권한을 거부했습니다.');
        return;
      }

      // FCM 토큰 획득 및 업데이트 리스너 설정
      await _getFCMToken();
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _tokenController.add(newToken);
        _logger.i('FCM 토큰이 갱신되었습니다: $newToken');
        _authState.setFCMToken(newToken);
      });

      // 포그라운드 메시지 핸들러 설정
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 백그라운드/종료 상태에서 알림 클릭 시 처리
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _logger.i('알림을 클릭하여 앱이 열렸습니다.');
        _messageController.add(message);
        _handleNotificationClick(message);
      });

      // 앱이 종료된 상태에서 알림을 클릭하여 앱이 시작된 경우
      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        _logger.i('종료 상태에서 알림을 클릭하여 앱이 시작되었습니다.');
        _messageController.add(initialMessage);
        _handleNotificationClick(initialMessage);
      }

      _initialized = true;
      _logger.i('PushNotificationService 초기화 완료');
    } catch (e, stackTrace) {
      _logger.e('PushNotificationService 초기화 실패', error: e, stackTrace: stackTrace);
    }
  }

  /// 로컬 알림 초기화
  /// 
  /// Android와 iOS 플랫폼별로 알림 채널을 설정합니다.
  Future<void> _initializeLocalNotifications() async {
    // Android 초기화 설정
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _logger.i('로컬 알림이 클릭되었습니다: ${response.payload}');
      },
    );

    // Android 알림 채널 생성 (Android 8.0 이상 필수)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // 채널 ID
      'High Importance Notifications', // 채널 이름
      description: 'This channel is used for important notifications.', // 채널 설명
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// FCM 토큰 획득
  /// 
  /// 현재 기기의 FCM 토큰을 가져와서 저장하고 백엔드로 전송합니다.
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      print("fcmToken: $_fcmToken");
      if (_fcmToken != null) {
        _tokenController.add(_fcmToken!);
        _logger.i('FCM 토큰 획득 성공: $_fcmToken');
        _authState.setFCMToken(_fcmToken!);
      } else {
        _logger.w('FCM 토큰을 획득할 수 없습니다.');
      }
    } catch (e, stackTrace) {
      _logger.e('FCM 토큰 획득 실패', error: e, stackTrace: stackTrace);
    }
  }

  /// 포그라운드 메시지 처리
  /// 
  /// 앱이 실행 중일 때 수신된 알림을 로컬 알림으로 표시합니다.
  /// (FCM은 포그라운드에서 자동으로 알림을 표시하지 않으므로 수동 처리 필요)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _logger.i('포그라운드에서 알림 수신: ${message.messageId}');
    _logger.d('알림 데이터: ${message.data}');
    _logger.d('알림 제목: ${message.notification?.title}');
    _logger.d('알림 본문: ${message.notification?.body}');

    // 로컬 알림으로 표시
    if (message.notification != null) {
      await _showLocalNotification(message);
    }
  }

  /// 로컬 알림 표시
  /// 
  /// 포그라운드에서 수신된 FCM 메시지를 로컬 알림으로 표시합니다.
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? '알림',
      message.notification?.body ?? '',
      notificationDetails,
      payload: message.data.toString(),
    );
  }

  /// 알림 클릭 처리
  /// 
  /// 사용자가 알림을 클릭했을 때 실행할 로직을 처리합니다.
  /// 예: 특정 화면으로 이동, 딥링크 처리 등
  void _handleNotificationClick(RemoteMessage message) {
    _logger.i('알림 클릭 처리: ${message.data}');

    // 알림 데이터에서 화면 이동 정보 추출
    final data = message.data;
    
    // 예시: 게시글 상세 화면으로 이동
    if (data.containsKey('boardId')) {
      final boardId = data['boardId'];
      _logger.i('게시글 상세 화면으로 이동: $boardId');
      // TODO: GetX나 Navigator를 사용하여 화면 이동
      // Get.toNamed('/board/detail', arguments: {'boardId': boardId});
    }

    // 예시: 프로필 화면으로 이동
    if (data.containsKey('userId')) {
      final userId = data['userId'];
      _logger.i('프로필 화면으로 이동: $userId');
      // TODO: GetX나 Navigator를 사용하여 화면 이동
      // Get.toNamed('/profile', arguments: {'userId': userId});
    }
  }

  /// 특정 토픽 구독
  /// 
  /// 사용자가 특정 주제의 알림을 받을 수 있도록 토픽을 구독합니다.
  /// 예: 'news', 'board', 'user_123' 등
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      _logger.i('토픽 구독 성공: $topic');
    } catch (e, stackTrace) {
      _logger.e('토픽 구독 실패: $topic', error: e, stackTrace: stackTrace);
    }
  }

  /// 특정 토픽 구독 해제
  /// 
  /// 사용자가 특정 주제의 알림 구독을 해제합니다.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      _logger.i('토픽 구독 해제 성공: $topic');
    } catch (e, stackTrace) {
      _logger.e('토픽 구독 해제 실패: $topic', error: e, stackTrace: stackTrace);
    }
  }

  /// 리소스 정리
  /// 
  /// 앱 종료 시 호출하여 스트림 컨트롤러를 닫습니다.
  void dispose() {
    _tokenController.close();
    _messageController.close();
  }
}
