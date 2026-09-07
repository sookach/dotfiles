import AppKit
import ApplicationServices
import CoreGraphics

let stateURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("sketchybar-apple-menu-open")

func pressEscape() {
    let source = CGEventSource(stateID: .hidSystemState)

    let keyDown = CGEvent(
        keyboardEventSource: source,
        virtualKey: 53,
        keyDown: true
    )

    let keyUp = CGEvent(
        keyboardEventSource: source,
        virtualKey: 53,
        keyDown: false
    )

    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
}

func pressAppleMenu() -> Bool {
    guard let finder = NSRunningApplication
        .runningApplications(withBundleIdentifier: "com.apple.finder")
        .first else {
        fputs("Finder is not running\n", stderr)
        return false
    }

    let finderElement = AXUIElementCreateApplication(
        finder.processIdentifier
    )

    var menuBarValue: CFTypeRef?

    let menuBarResult = AXUIElementCopyAttributeValue(
        finderElement,
        kAXMenuBarAttribute as CFString,
        &menuBarValue
    )

    guard menuBarResult == .success,
          let menuBarValue else {
        fputs("Unable to access Finder's menu bar\n", stderr)
        return false
    }

    let menuBar = menuBarValue as! AXUIElement

    var childrenValue: CFTypeRef?

    let childrenResult = AXUIElementCopyAttributeValue(
        menuBar,
        kAXChildrenAttribute as CFString,
        &childrenValue
    )

    guard childrenResult == .success,
          let menuItems = childrenValue as? [AXUIElement],
          let appleMenu = menuItems.first else {
        fputs("Unable to find the Apple menu\n", stderr)
        return false
    }

    let pressResult = AXUIElementPerformAction(
        appleMenu,
        kAXPressAction as CFString
    )

    guard pressResult == .success else {
        fputs("Unable to press the Apple menu\n", stderr)
        return false
    }

    return true
}

let fileManager = FileManager.default

if fileManager.fileExists(atPath: stateURL.path) {
    pressEscape()
    try? fileManager.removeItem(at: stateURL)
} else if pressAppleMenu() {
    fileManager.createFile(
        atPath: stateURL.path,
        contents: nil
    )
}
