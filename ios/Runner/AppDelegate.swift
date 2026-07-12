import Flutter
import UIKit
import NaverThirdPartyLogin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene 마이그레이션: 플러그인 등록은 didFinishLaunchingWithOptions가 아니라 여기서 수행한다.
  // https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // UIScene 적용 후에는 호출되지 않지만, 폴백으로 유지한다.
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
      var applicationResult = false
      if (!applicationResult) {
         applicationResult = NaverThirdPartyLoginConnection.getSharedInstance().application(app, open: url, options: options)
      }
      // if you use other application url process, please add code here.

      if (!applicationResult) {
         applicationResult = super.application(app, open: url, options: options)
      }
      return applicationResult
  }
}

// UIScene lifecycle 델리게이트.
// FlutterSceneDelegate가 URL 오픈 등을 플러그인(kakao/google 로그인 등)에 전달하고,
// 플러그인 방식이 아닌 네이버 로그인 SDK만 여기서 직접 처리한다.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      NaverThirdPartyLoginConnection.getSharedInstance().application(
        UIApplication.shared,
        open: context.url,
        options: [:]
      )
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
