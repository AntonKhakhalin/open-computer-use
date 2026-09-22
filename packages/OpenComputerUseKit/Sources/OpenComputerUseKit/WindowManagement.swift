import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Official window2 window reference: `{app, id, title}` where `id` is the
/// opaque CGWindowID from `list_windows`/`get_window_state`.
public struct WindowRef: Equatable, Sendable {
    public let app: String
    public let id: CGWindowID
    public let title: String?

    public init(app: String, id: CGWindowID, title: String?) {
        self.app = app
        self.id = id
        self.title = title
    }

    var jsonObject: [String: Any] {
        var dictionary: [String: Any] = [
            "app": app,
            "id": Int(id),
        ]
        if let title, !title.isEmpty {
            dictionary["title"] = title
        }
        return dictionary
    }
}

/// One entry from a `CGWindowListCopyWindowInfo` enumeration (front to back).
struct CGWindowEntry: Equatable {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
    let title: String?
    let frontToBackIndex: Int
}

/// A window id that passed the official liveness and safety checks: the
/// window is in the current window list, its owning process is running, and
/// the owning app is not on the deny list.
struct ResolvedWindow {
    let ref: WindowRef
    let pid: pid_t
    let bundleIdentifier: String?
    let runningApplication: NSRunningApplication
    let entry: CGWindowEntry
}

// WindowArgumentParsing mirrors the Windows runtime's optionalWindow /
// windowIDFromValue semantics: the official `window` object ({app, id,
// title}) or the flat `window_id` alias. The id is authoritative; the app
// and title fields are carried for display only.
enum WindowArgumentParsing {
    static func optional(_ arguments: [String: Any]) throws -> WindowRef? {
        if arguments["window"] == nil, let rawWindowID = arguments["window_id"] {
            let id = try windowIDValue(rawWindowID)
            guard id > 0 else {
                return nil
            }
            return WindowRef(app: "", id: CGWindowID(id), title: nil)
        }

        guard let raw = arguments["window"], !(raw is NSNull) else {
            return nil
        }

        guard let object = raw as? [String: Any] else {
            throw ComputerUseError.message("window must be an object with an integer id")
        }

        let app = (object["app"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = object["title"] as? String
        let id = try windowIDValue(object["id"])
        guard id > 0 else {
            throw ComputerUseError.message("window.id must be an integer >= 0")
        }

        return WindowRef(app: app, id: CGWindowID(id), title: title)
    }

    static func required(_ arguments: [String: Any]) throws -> WindowRef? {
        try optional(arguments)
    }

    // Mirrors windowIDFromValue: JSON numbers, integer strings, and NSNumber
    // are accepted; a non-integer number is an explicit error; anything else
    // is treated as a missing id (0).
    private static func windowIDValue(_ value: Any?) throws -> Int {
        guard let value else {
            return 0
        }

        if let number = value as? NSNumber {
            if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() {
                return 0
            }

            let doubleValue = number.doubleValue
            guard doubleValue.isFinite, doubleValue.rounded(.towardZero) == doubleValue else {
                throw ComputerUseError.message("window id must be an integer >= 0")
            }
            guard doubleValue >= Double(Int.min), doubleValue <= Double(Int.max) else {
                return 0
            }
            return Int(doubleValue)
        }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let parsed = Int(trimmed) else {
                throw ComputerUseError.message("window id must be an integer >= 0")
            }
            return parsed
        }

        return 0
    }
}

/// Window enumeration, resolution, activation, and per-window capture for
/// the macOS window2 surface. CGWindowID values come from the system window
/// list; they are never invented.
enum WindowDirectory {
    // MARK: - Enumeration

    static func listEntries(onScreenOnly: Bool) -> [CGWindowEntry] {
        let options: CGWindowListOption = onScreenOnly ? [.optionOnScreenOnly] : []
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return infoList.enumerated().compactMap { offset, info -> CGWindowEntry? in
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t,
                let number = info[kCGWindowNumber as String] as? NSNumber,
                let layer = info[kCGWindowLayer as String] as? Int,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else {
                return nil
            }

            return CGWindowEntry(
                windowID: CGWindowID(number.uint32Value),
                ownerPID: ownerPID,
                layer: layer,
                bounds: bounds,
                title: info[kCGWindowName as String] as? String,
                frontToBackIndex: offset
            )
        }
    }

    /// Targetable windows: on-screen, normal window level, non-zero size.
    /// Titles require Screen Recording; without it they come back empty and
    /// are omitted from the reference, while the id is always present.
    static func listWindows() -> [WindowRef] {
        listEntries(onScreenOnly: true)
            .filter { $0.layer == 0 && $0.bounds.width > 0 && $0.bounds.height > 0 }
            .map { entry in
                WindowRef(
                    app: ownerName(for: entry.ownerPID),
                    id: entry.windowID,
                    title: entry.title?.isEmpty == false ? entry.title : nil
                )
            }
    }

    static func currentBounds(for id: CGWindowID) -> CGRect? {
        listEntries(onScreenOnly: false).first(where: { $0.windowID == id })?.bounds
    }

    /// Resolves a pid to a descriptor. Uses `NSRunningApplication` directly
    /// instead of `NSWorkspace.shared.runningApplications`: that list only
    /// contains LaunchServices-registered apps and misses bare executables
    /// (such as the test fixture) that own windows.
    static func runningApp(for pid: pid_t) -> RunningAppDescriptor? {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return nil
        }

        return RunningAppDescriptor(
            name: app.localizedName ?? "Unknown",
            bundleIdentifier: app.bundleIdentifier,
            pid: app.processIdentifier,
            runningApplication: app
        )
    }

    // MARK: - Resolution

    /// Resolves a CGWindowID against the current window list and running
    /// apps: stale-window, dead-process, and deny-list checks in the
    /// official order.
    static func resolve(
        id: CGWindowID,
        entries: [CGWindowEntry]? = nil,
        runningApps: [RunningAppDescriptor]? = nil
    ) throws -> ResolvedWindow {
        let windowList = entries ?? listEntries(onScreenOnly: false)
        guard let entry = windowList.first(where: { $0.windowID == id }) else {
            throw ComputerUseError.message(
                "staleWindowHandle(\(id)): the window is no longer open; re-observe with list_windows."
            )
        }

        let descriptor: RunningAppDescriptor?
        if let runningApps {
            descriptor = runningApps.first { $0.pid == entry.ownerPID }
        } else {
            descriptor = runningApp(for: entry.ownerPID)
        }
        guard let descriptor else {
            throw ComputerUseError.message(
                "staleWindowHandle(\(id)): the owning process is no longer running; re-observe with list_windows."
            )
        }

        if let bundleIdentifier = descriptor.bundleIdentifier, AppSafetyPolicy.isBlocked(bundleIdentifier: bundleIdentifier) {
            throw AppSafetyPolicy.permissionDenied(bundleIdentifier: bundleIdentifier)
        }

        return ResolvedWindow(
            ref: WindowRef(
                app: descriptor.name,
                id: id,
                title: entry.title?.isEmpty == false ? entry.title : nil
            ),
            pid: descriptor.pid,
            bundleIdentifier: descriptor.bundleIdentifier,
            runningApplication: descriptor.runningApplication,
            entry: entry
        )
    }

    // MARK: - Activation

    /// Brings one window to the foreground using NSRunningApplication and
    /// the accessibility API (unminimize, AXRaise, AXMain/AXFocused) — no
    /// AppleScript or shell. Bounded retries; the outcome is verified
    /// against the frontmost app and the app's focused window.
    static func activate(
        _ resolved: ResolvedWindow,
        axWindow: AXUIElement? = nil,
        attempts: Int = 3,
        delay: TimeInterval = 0.25
    ) throws -> WindowRef {
        var appElement: AXUIElement?
        var targetWindow = axWindow

        for attempt in 0..<max(attempts, 1) {
            if resolved.entry.bounds.height > 0 {
                unminimizeIfNeeded(resolved.pid, windowID: resolved.ref.id)
            }

            resolved.runningApplication.activate(options: [.activateAllWindows])

            if targetWindow == nil {
                appElement = AXUIElementCreateApplication(resolved.pid)
                targetWindow = matchAXWindow(
                    appElement: appElement!,
                    entry: WindowDirectory.currentEntry(for: resolved.ref.id) ?? resolved.entry
                )
            }

            if let window = targetWindow {
                raiseAXWindow(window)
                _ = setAXBoolAttribute(window, kAXMainAttribute as String, true)
                _ = setAXBoolAttribute(window, kAXFocusedAttribute as String, true)
            }

            if isFrontmost(resolved.pid, focusedWindow: targetWindow) {
                return resolved.ref
            }

            if attempt < max(attempts, 1) - 1 {
                Thread.sleep(forTimeInterval: delay)
            }
        }

        throw ComputerUseError.message(
            "activateWindow(\(resolved.ref.id)): the window could not be brought to the foreground; re-observe with list_windows."
        )
    }

    static func currentEntry(for id: CGWindowID) -> CGWindowEntry? {
        listEntries(onScreenOnly: false).first(where: { $0.windowID == id })
    }

    static func isFrontmost(_ pid: pid_t, focusedWindow: AXUIElement?) -> Bool {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
            return true
        }

        guard let focusedWindow else {
            return false
        }

        let appElement = AXUIElementCreateApplication(pid)
        guard let appFocused = axElement(of: appElement, attribute: kAXFocusedWindowAttribute as String) else {
            return false
        }

        return CFEqual(appFocused, focusedWindow)
    }

    private static func unminimizeIfNeeded(_ pid: pid_t, windowID: CGWindowID) {
        let appElement = AXUIElementCreateApplication(pid)
        guard let window = matchAXWindow(appElement: appElement, entry: currentEntry(for: windowID) ?? CGWindowEntry(windowID: windowID, ownerPID: pid, layer: 0, bounds: .zero, title: nil, frontToBackIndex: 0)) else {
            return
        }

        guard axBool(of: window, attribute: kAXMinimizedAttribute as String) == true else {
            return
        }

        _ = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }

    private static func raiseAXWindow(_ window: AXUIElement) {
        guard axActions(of: window).contains(where: { $0.caseInsensitiveCompare(kAXRaiseAction as String) == .orderedSame }) else {
            return
        }

        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private static func setAXBoolAttribute(_ element: AXUIElement, _ attribute: String, _ value: Bool) -> Bool {
        AXUIElementSetAttributeValue(element, attribute as CFString, value as CFBoolean) == .success
    }

    // MARK: - Accessibility window matching

    /// Matches the app's accessibility windows to a CGWindowID by geometry.
    /// Titles are only a tie-breaker — identical titles are common, and the
    /// CGWindowID (plus its bounds) is the authoritative identity.
    static func matchAXWindow(appElement: AXUIElement, entry: CGWindowEntry) -> AXUIElement? {
        guard let windows = axArray(of: appElement, attribute: kAXWindowsAttribute as String) else {
            return nil
        }

        let focused = axElement(of: appElement, attribute: kAXFocusedWindowAttribute as String)
        let candidates: [(element: AXUIElement, frame: CGRect, title: String?, isFocused: Bool)] = windows.compactMap { element in
            guard
                axString(of: element, attribute: kAXRoleAttribute as String) == kAXWindowRole as String,
                let frame = axFrame(of: element)
            else {
                return nil
            }

            return (
                element: element,
                frame: frame,
                title: axString(of: element, attribute: kAXTitleAttribute as String),
                isFocused: focused != nil && CFEqual(element, focused)
            )
        }

        let target = entry.bounds
        let tolerance: CGFloat = 2
        func frameMatches(_ frame: CGRect) -> Bool {
            abs(frame.minX - target.minX) <= tolerance
                && abs(frame.minY - target.minY) <= tolerance
                && abs(frame.width - target.width) <= tolerance
                && abs(frame.height - target.height) <= tolerance
        }

        let frameMatches = candidates.filter { frameMatches($0.frame) }
        if !frameMatches.isEmpty {
            if let titled = frameMatches.first(where: { entry.title?.isEmpty == false && $0.title == entry.title }) {
                return titled.element
            }
            if let focusedMatch = frameMatches.first(where: { $0.isFocused }) {
                return focusedMatch.element
            }
            return frameMatches.first?.element
        }

        // Last resort: a uniquely titled window (never titles alone when
        // several candidates share the title).
        guard let title = entry.title, !title.isEmpty else {
            return nil
        }

        let titleMatches = candidates.filter { $0.title == title }
        return titleMatches.count == 1 ? titleMatches.first?.element : nil
    }

    // MARK: - Capture

    /// Captures one specific window by CGWindowID through the shared
    /// ScreenCaptureKit path (no second screenshot implementation).
    static func capture(entry: CGWindowEntry) -> WindowCapture {
        WindowCapture.capture(windowID: entry.windowID, bounds: entry.bounds, layer: entry.layer)
    }

    // MARK: - App name

    private static func ownerName(for pid: pid_t) -> String {
        if let running = NSRunningApplication(processIdentifier: pid),
           let name = running.localizedName, !name.isEmpty
        {
            return name
        }

        return "Unknown"
    }

    // MARK: - AX helpers (local to this file; the snapshot layer keeps its own)

    private static func axUIElement(from value: CFTypeRef) -> AXUIElement? {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private static func axValue(from value: CFTypeRef) -> AXValue? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        return (value as! AXValue)
    }

    private static func axElement(of element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value else {
            return nil
        }
        return axUIElement(from: value)
    }

    private static func axArray(of element: AXUIElement, attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value else {
            return nil
        }
        return value as? [AXUIElement]
    }

    private static func axString(of element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value else {
            return nil
        }
        return value as? String
    }

    private static func axBool(of element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success, let value else {
            return nil
        }
        return (value as? NSNumber)?.boolValue
    }

    private static func axActions(of element: AXUIElement) -> [String] {
        var actions: CFArray?
        guard AXUIElementCopyActionNames(element, &actions) == .success else {
            return []
        }
        return actions as? [String] ?? []
    }

    private static func axFrame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
            let positionValue,
            let sizeValue,
            let positionAXValue = axValue(from: positionValue),
            let sizeAXValue = axValue(from: sizeValue)
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAXValue, .cgPoint, &position), AXValueGetValue(sizeAXValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }
}
