import Flutter
import UIKit
import GoogleMaps
import NaverThirdPartyLogin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      GMSServices.provideAPIKey(Storage().googleMapsApiKey)

    GeneratedPluginRegistrant.register(with: self)    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

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
