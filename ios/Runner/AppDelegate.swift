import CallKit
import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CallBlockerPlugin") {
      CallBlockerPlugin.register(with: registrar.messenger())
      QuickNotesWidgetPlugin.register(with: registrar.messenger())
    }
  }
}

/// Ponte com o Flutter para o bloqueio de chamadas. A configuração fica no
/// App Group para a CallBlockerExtension (Call Directory Extension) ler.
enum CallBlockerPlugin {
  static let appGroup = "group.com.ramonmachadocarmo.mobileUtils"
  static let extensionId = "com.ramonmachadocarmo.mobileUtils.CallBlockerExtension"
  static let configKey = "call_blocker_config"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mobile_utils/call_blocker", binaryMessenger: messenger)
    let defaults = UserDefaults(suiteName: appGroup)
    let manager = CXCallDirectoryManager.sharedInstance

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getConfig":
        result(defaults?.string(forKey: configKey) ?? "{}")

      case "saveConfig":
        defaults?.set(call.arguments as? String, forKey: configKey)
        manager.reloadExtension(withIdentifier: extensionId) { error in
          DispatchQueue.main.async {
            result(error.map { "Falha ao atualizar a lista de bloqueio: \($0.localizedDescription)" })
          }
        }

      case "isServiceEnabled":
        manager.getEnabledStatusForExtension(withIdentifier: extensionId) { status, _ in
          DispatchQueue.main.async { result(status == .enabled) }
        }

      case "requestServiceEnabled":
        if #available(iOS 13.4, *) {
          manager.openSettings { _ in DispatchQueue.main.async { result(false) } }
        } else {
          UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
          result(false)
        }

      // A extensão não é avisada das chamadas bloqueadas, então não há histórico no iOS.
      case "getLog":
        result("[]")
      case "clearLog":
        result(nil)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Repassa as notas fixadas para o QuickNotesWidget (extensão WidgetKit) via App Group.
enum QuickNotesWidgetPlugin {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "mobile_utils/widgets", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "updateQuickNotes" else {
        result(FlutterMethodNotImplemented)
        return
      }
      UserDefaults(suiteName: CallBlockerPlugin.appGroup)?
        .set(call.arguments as? String, forKey: "quick_notes_widget")
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadTimelines(ofKind: "QuickNotesWidget")
      }
      result(nil)
    }
  }
}
