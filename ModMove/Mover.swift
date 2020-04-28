import AppKit
import Foundation

final class Mover {
    var state: FlagState = .Ignore {
        didSet {
            if self.state != oldValue {
                self.changed(state: self.state)
            }
        }
    }

    private var monitor: Any?
    private var initialMousePosition: CGPoint?
    private var initialWindowPosition: CGPoint?
    private var initialWindowSize: CGSize?
    private var closestCorner: Int?
    private var window: AccessibilityElement?

    private func mouseMoved(handler: (_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Void) {
        let point = Mouse.currentPosition()
        if self.window == nil {
            self.window = AccessibilityElement.systemWideElement.element(at: point)?.window()
        }
        guard let window = self.window else {
            return
        }

        if self.initialMousePosition == nil {
            self.initialMousePosition = point
            self.initialWindowPosition = window.position
            self.initialWindowSize = window.size
            self.closestCorner = self.getClosestCorner(window: window, mouse: point)

            let currentPid = NSRunningApplication.current.processIdentifier
            if let pid = window.pid(), pid != currentPid {
                NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
            }
            window.bringToFront()
        } else if let initialMousePosition = self.initialMousePosition {
            let mouseDelta = CGPoint(x: point.x - initialMousePosition.x, y: point.y - initialMousePosition.y)
            handler(window, mouseDelta)
        }
    }

    private func getClosestCorner(window: AccessibilityElement, mouse: CGPoint) -> Int {
        if let size = window.size, let position = window.position {
            let xmid = position.x + size.width / 2
            let ymid = position.y + size.height / 2
            if mouse.x < xmid && mouse.y < ymid {
                return 0  // top left
            } else if mouse.x >= xmid && mouse.y < ymid {
                return 1  // top right
            } else if mouse.x < xmid && mouse.y >= ymid {
                return 2  // bottom left
            } else {
                return 3  // bottom right
            }
        }
        return 3
    }

    private func resizeWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let initWinSize = self.initialWindowSize, let initWinPos = self.initialWindowPosition, let corner = self.closestCorner {
            switch corner {
            case 0:
                window.position = CGPoint(x: initWinPos.x + mouseDelta.x, y: initWinPos.y + mouseDelta.y)
                window.size = CGSize(width: initWinSize.width - mouseDelta.x, height: initWinSize.height - mouseDelta.y)
            case 1:
                window.position = CGPoint(x: initWinPos.x, y: initWinPos.y + mouseDelta.y)
                window.size = CGSize(width: initWinSize.width + mouseDelta.x, height: initWinSize.height - mouseDelta.y)
            case 2:
                window.position = CGPoint(x: initWinPos.x + mouseDelta.x, y: initWinPos.y)
                window.size = CGSize(width: initWinSize.width - mouseDelta.x, height: initWinSize.height + mouseDelta.y)
            case 3:
                window.size = CGSize(width: initWinSize.width + mouseDelta.x, height: initWinSize.height + mouseDelta.y)
            default: break
            }
        }
    }

    private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
    if let initWinPos = self.initialWindowPosition {
            window.position = CGPoint(x: initWinPos.x + mouseDelta.x, y: initWinPos.y + mouseDelta.y)
        }
    }

    private func changed(state: FlagState) {
        self.removeMonitor()

        switch state {
        case .Resize:
            self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                self.mouseMoved(handler: self.resizeWindow)
            }
        case .Drag:
            self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                self.mouseMoved(handler: self.moveWindow)
            }
        case .Ignore:
            self.initialMousePosition = nil
            self.initialWindowPosition = nil
            self.initialWindowSize = nil
            self.closestCorner = nil
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
