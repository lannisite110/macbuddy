import AppKit
import ApplicationServices
import Foundation

public enum PermissionBroker {
    public static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

public enum SelectionReader {
    public static func readSelectedText() throws -> String {
        guard PermissionBroker.isAccessibilityTrusted() else {
            throw WorkSkillsError.accessibilityDenied
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        guard focusResult == .success, let focusedRef else {
            throw WorkSkillsError.noSelection
        }
        let focused = focusedRef as! AXUIElement

        var selectedRef: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedRef)
        if selectedResult == .success, let selectedRef, let text = selectedRef as? String, !text.isEmpty {
            return text
        }

        var valueRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &valueRef)
        if valueResult == .success, let valueRef, let text = valueRef as? String, !text.isEmpty {
            return text
        }

        throw WorkSkillsError.noSelection
    }

    public static func replaceSelectedText(_ text: String) throws {
        guard PermissionBroker.isAccessibilityTrusted() else {
            throw WorkSkillsError.accessibilityDenied
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef
        else {
            throw WorkSkillsError.noSelection
        }
        let focused = focusedRef as! AXUIElement
        let result = AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if result != .success {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            throw WorkSkillsError.noSelection
        }
    }
}
