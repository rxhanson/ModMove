import AppKit
import Foundation

final class Mover {
    private var monitor: Any?
    private var lastMousePosition: CGPoint?
    private var window: AccessibilityElement?

    var state: FlagState = .ignore {
        didSet {
            if self.state != oldValue {
                self.changed(state: self.state)
            }
        }
    }

    private func mouseMoved(handler: (_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Void) {
        let point = Mouse.currentPosition()
        if self.window == nil {
            self.window = AccessibilityElement.systemWideElement.element(at: point)?.window()
        }

        guard let window = self.window else {
            return
        }

        let frontmostPID = NSRunningApplication.current().processIdentifier
        if let pid = window.pid(), pid != frontmostPID {
            NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
        }

        window.bringToFront()
        if let lastPosition = self.lastMousePosition {
            let mouseDelta = CGPoint(x: lastPosition.x - point.x, y: lastPosition.y - point.y)
            handler(window, mouseDelta)
        }

        self.lastMousePosition = point
    }

    private func resizeWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let size = window.size {
            let newSize = CGSize(width: size.width - mouseDelta.x, height: size.height - mouseDelta.y)
            window.size = newSize
        }
    }

    private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let position = window.position {
            let newPosition = CGPoint(x: position.x - mouseDelta.x, y: position.y - mouseDelta.y)
            window.position = newPosition
        }
    }

    private func changed(state: FlagState) {
        self.removeMonitor()

        switch state {
        case .resize:
            self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                self?.mouseMoved(handler: self!.resizeWindow)
            }
        case .drag:
            self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                self?.mouseMoved(handler: self!.moveWindow)
            }
        case .ignore:
            self.lastMousePosition = nil
            self.window = nil
        }
    }

    private func removeMonitor() {
        if let monitor = self.monitor {
            NSEvent.removeMonitor(monitor)
        }

        self.monitor = nil
    }

    deinit {
        self.removeMonitor()
    }
}
