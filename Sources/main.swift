import AppKit
import Carbon.HIToolbox
import Foundation
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum Constants {
        static let hotKeyID: UInt32 = 1
        static let hotKeySignature: OSType = OSType(0x50534E50) // 'PSNP'
    }

    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var statusItem: NSStatusItem?

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
            button.toolTip = "Print Screen App"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Screen (Ctrl+Option+P)", action: #selector(captureFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }

        item.menu = menu
        statusItem = item
    }

    @objc
    private func captureFromMenu() {
        captureScreen()
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
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
        let outputURL = desktopURL.appendingPathComponent(filename)

        // Keep the UI responsive while the screenshot command runs.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-x", outputURL.path]

            do {
                try task.run()
                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    self?.showCaptureNotification(filename: filename)
                } else {
                    self?.showErrorNotification(message: "screencapture failed with status \(task.terminationStatus)")
                }
            } catch {
                self?.showErrorNotification(message: error.localizedDescription)
            }
        }
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
        postNotification(title: "Print Screen App", body: "Ready. Press Control + Option + P to capture the screen.")
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
