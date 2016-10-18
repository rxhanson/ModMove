import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let observer = Observer()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AccessibilityHelper.askForAccessibilityIfNeeded()

        let mover = Mover()
        self.observer.startObserving { state in
            mover.state = state
        }
    }
}

let delegate = AppDelegate()
let app = NSApplication.shared()
app.delegate = delegate
app.run()
