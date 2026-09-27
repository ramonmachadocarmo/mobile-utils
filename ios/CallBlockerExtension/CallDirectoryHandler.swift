import CallKit
import Foundation

/// Call Directory Extension: o iOS pede a lista de números a bloquear e a
/// aplica sozinho. Recarregada pelo app sempre que a configuração muda.
class CallDirectoryHandler: CXCallDirectoryProvider {
  private let appGroup = "group.com.ramonmachadocarmo.mobile_utils"
  private let configKey = "call_blocker_config"

  override func beginRequest(with context: CXCallDirectoryExtensionContext) {
    context.delegate = self
    // Sempre recarrega a lista inteira (sem incremental) para ficar simples.
    if context.isIncremental {
      context.removeAllBlockingEntries()
    }
    for number in blockedNumbers() {
      context.addBlockingEntry(withNextSequentialPhoneNumber: number)
    }
    context.completeRequest()
  }

  /// Números em formato E.164 (só dígitos, com DDI), ordenados e sem repetição,
  /// como o CallKit exige.
  private func blockedNumbers() -> [CXCallDirectoryPhoneNumber] {
    guard
      let raw = UserDefaults(suiteName: appGroup)?.string(forKey: configKey),
      let data = raw.data(using: .utf8),
      let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      config["enabled"] as? Bool == true,
      let numbers = config["numbers"] as? [[String: Any]]
    else { return [] }

    let countryCode = config["countryCode"] as? String ?? "55"
    let set = Set(numbers.compactMap { entry -> CXCallDirectoryPhoneNumber? in
      guard let number = entry["number"] as? String else { return nil }
      return Self.toE164(number, countryCode: countryCode)
    })
    return set.sorted()
  }

  /// "+55 (11) 91234-5678" -> 5511912345678; "(11) 91234-5678" -> 55 + 11912345678.
  static func toE164(_ number: String, countryCode: String) -> CXCallDirectoryPhoneNumber? {
    let trimmed = number.trimmingCharacters(in: .whitespaces)
    var digits = trimmed.filter(\.isNumber)
    if !trimmed.hasPrefix("+") {
      while digits.hasPrefix("0") { digits.removeFirst() }
      if !(digits.hasPrefix(countryCode) && digits.count >= 12) {
        digits = countryCode + digits
      }
    }
    return digits.count >= 8 ? CXCallDirectoryPhoneNumber(digits) : nil
  }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
  func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
    NSLog("CallBlockerExtension falhou: \(error.localizedDescription)")
  }
}
