import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Privacy guard channel: Flutter tells native when a safe frame
    // (LockScreen, or the resumed screen) is actually on screen, so the
    // overlay is released only then — never a frame early. Optional binding
    // on purpose: if there is no controller yet, the channel is simply
    // skipped and the become-active safety timer below still recovers.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "omen_vault/privacy",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        if call.method == "releasePrivacyOverlay" {
          self?.privacyOverlay?.removeFromSuperview()
          self?.privacyOverlay = nil
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Privacy guard: cover the window the moment the app resigns active,
  // so the OS task-switcher snapshot captures a black screen, not vault content.
  // Native overlay, not a Flutter widget: the OS snapshot is taken from the
  // native window, and a Flutter-side widget can lose that race.
  override func applicationWillResignActive(_ application: UIApplication) {
    if privacyOverlay != nil { return }
    guard let window = self.window else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .black
    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    // Safety net only — Flutter releases the overlay as soon as a safe
    // frame is rendered. If that signal never arrives, never strand the
    // user on a black screen: drop it after 1.5s.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      self?.privacyOverlay?.removeFromSuperview()
      self?.privacyOverlay = nil
    }
  }
}
