import UIKit
import Flutter
import CallKit
import AVFAudio
import PushKit
import flutter_callkit_incoming

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {
    
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Setup VoIP
    let mainQueue = DispatchQueue.main
    let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
     // プッシュ通知の受け取り情報をシステムが更新した際に呼ばれる(アプリ初回起動時等)
    print("LOG: pushRegistry")
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    // Save deviceToken to your server
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    // 設定アプリ等でプッシュ通知設定を無効にした際に呼ばれる
    print("LOG: didInvalidatePushTokenFor")
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }
  
  func onAccept(_ call: flutter_callkit_incoming.Call, _ action: CXAnswerCallAction) {
    print("LOG: onAccept")
    action.fulfill()
  }
  
  func onDecline(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    print("LOG: onDecline")
    action.fulfill()
  }
  
  func onEnd(_ call: flutter_callkit_incoming.Call, _ action: CXEndCallAction) {
    print("LOG: onEnd")
    action.fulfill()
  }
  
  func onTimeOut(_ call: flutter_callkit_incoming.Call) {
    print("LOG: onTimeOut")
  }
  
  func didActivateAudioSession(_ audioSession: AVAudioSession) {
    print("LOG: didActivateAudioSession")
  }
  
  func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
    print("LOG: didDeactivateAudioSession")
  }
}
