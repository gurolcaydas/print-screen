import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum Constants {
        static let hotKeyID: UInt32 = 1
        static let hotKeySignature: OSType = OSType(0x50534E50) // 'PSNP'
        static let targetFolderDefaultsKey = "targetFolderPath"
        static let defaultFolderName = "PrintScreenApp"
    }

    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var statusItem: NSStatusItem?
    private var targetFolderMenuItem: NSMenuItem?
    private var didShowScreenRecordingAlertThisLaunch = false

    // Current shortcut: Control + Option + P
    private let hotKeyCode: UInt32 = UInt32(kVK_ANSI_P)
    private let hotKeyModifiers: UInt32 = UInt32(controlKey | optionKey)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        requestNotificationPermission()
        installHotKeyHandler()
        registerHotKey()
        showStartupNotification()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        if let hotKeyHandler {
            RemoveEventHandler(hotKeyHandler)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.title = "PS"
            button.toolTip = "PrintScreenApp"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Capture Screen (Ctrl+Option+P)", action: #selector(captureFromMenu), keyEquivalent: ""))
        targetFolderMenuItem = NSMenuItem(title: "", action: #selector(selectTargetFolder), keyEquivalent: "")
        if let targetFolderMenuItem {
            menu.addItem(targetFolderMenuItem)
        }
        menu.addItem(NSMenuItem(title: "Open Target Folder", action: #selector(openTargetFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        refreshTargetFolderMenuTitle()

        item.menu = menu
        statusItem = item
    }

    @objc
    private func captureFromMenu() {
        captureScreen()
    }

    @objc
    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "PrintScreenApp"
        alert.informativeText = "Free app made by Gürol Çaydaş."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc
    private func selectTargetFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Target Folder"
        panel.message = "Screenshots will be saved in this folder."
        panel.prompt = "Choose"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = currentTargetFolderURL()

        if panel.runModal() == .OK, let selectedURL = panel.url {
            UserDefaults.standard.set(selectedURL.path, forKey: Constants.targetFolderDefaultsKey)
            refreshTargetFolderMenuTitle()
            postNotification(title: "Target folder updated", body: selectedURL.path)
        }
    }

    @objc
    private func openTargetFolder() {
        NSWorkspace.shared.open(currentTargetFolderURL())
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func installHotKeyHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else {
                    return noErr
                }

                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if result == noErr, hotKeyID.id == Constants.hotKeyID {
                    delegate.captureScreen()
                }

                return noErr
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &hotKeyHandler
        )

        if status != noErr {
            NSLog("Failed to install hotkey handler: \(status)")
        }
    }

    private func registerHotKey() {
        let hotKeyID = EventHotKeyID(signature: Constants.hotKeySignature, id: Constants.hotKeyID)

        let status = RegisterEventHotKey(
            hotKeyCode,
            hotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            NSLog("Failed to register hotkey: \(status)")
        }
    }

    private func captureScreen() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"

        let filename = "print-screen-\(formatter.string(from: Date())).png"
        let targetFolderURL = currentTargetFolderURL()
        let outputURL = targetFolderURL.appendingPathComponent(filename)

        // Keep the UI responsive while the screenshot command runs.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let cgImage = CGWindowListCreateImage(
                .infinite,
                .optionOnScreenOnly,
                kCGNullWindowID,
                [.bestResolution]
            ) else {
                let hasAccess = self?.currentScreenRecordingAccessState() ?? false
                let runtimeIdentity = self?.currentRuntimeIdentity() ?? "(unknown runtime identity)"
                self?.showScreenRecordingPermissionAlert()
                self?.showErrorNotification(message: "Unable to capture screen image. Screen Recording access is \(hasAccess ? "granted" : "denied") for \(runtimeIdentity).")
                return
            }

            do {
                try self?.savePNGImage(cgImage, to: outputURL)
                self?.showCaptureNotification(filename: filename)
            } catch {
                self?.showErrorNotification(message: "Failed to save screenshot: \(error.localizedDescription)")
            }
        }
    }

    private func savePNGImage(_ image: CGImage, to outputURL: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "PrintScreenApp", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination."])
        }

        CGImageDestinationAddImage(destination, image, nil)
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "PrintScreenApp", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not finalize PNG file."])
        }
    }

    private func currentScreenRecordingAccessState() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    private func currentRuntimeIdentity() -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? "(no bundle id)"
        let bundlePath = Bundle.main.bundlePath
        return "\(bundleID) @ \(bundlePath)"
    }

    private func showScreenRecordingPermissionAlert() {
        if didShowScreenRecordingAlertThisLaunch {
            return
        }
        didShowScreenRecordingAlertThisLaunch = true

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording permission required"
            alert.informativeText = "Enable Screen Recording for this app in System Settings -> Privacy & Security -> Screen Recording, then restart the app."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning

            let response = alert.runModal()
            if response == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func currentTargetFolderURL() -> URL {
        if let savedPath = UserDefaults.standard.string(forKey: Constants.targetFolderDefaultsKey), !savedPath.isEmpty {
            let savedURL = URL(fileURLWithPath: savedPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: savedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return savedURL
            }
        }

        let defaultURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent(Constants.defaultFolderName, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: defaultURL, withIntermediateDirectories: true)
        } catch {
            NSLog("Failed to create default target folder at \(defaultURL.path): \(error.localizedDescription)")
        }

        return defaultURL
    }

    private func refreshTargetFolderMenuTitle() {
        let folderPath = currentTargetFolderURL().path
        targetFolderMenuItem?.title = "Set Target Folder (Current: \(folderPath))"
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                NSLog("Notification permission error: \(error.localizedDescription)")
                return
            }

            if !granted {
                NSLog("Notification permission not granted")
            }
        }
    }

    private func showStartupNotification() {
        postNotification(title: "PrintScreenApp", body: "Ready. Press Control + Option + P to capture the screen.")
    }

    private func showCaptureNotification(filename: String) {
        postNotification(title: "Screenshot saved", body: filename)
    }

    private func showErrorNotification(message: String) {
        postNotification(title: "Print Screen error", body: message)
    }

    private func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
