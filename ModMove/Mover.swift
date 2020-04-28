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
    private var lastMousePosition: CGPoint?
    private var window: AccessibilityElement?

    private func mouseMoved(handler: (_ window: AccessibilityElement, _ mouseDelta: CGPoint, _ corner: Int) -> Void) {
        let point = Mouse.currentPosition()
        if self.window == nil {
            self.window = AccessibilityElement.systemWideElement.element(at: point)?.window()
        }

        guard let window = self.window else {
            return
        }

        let currentPid = NSRunningApplication.current.processIdentifier
        if let pid = window.pid(), pid != currentPid {
            NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
        }

        window.bringToFront()
        if let lastPosition = self.lastMousePosition {
            let mouseDelta = CGPoint(x: point.x - lastPosition.x, y: point.y - lastPosition.y)
            handler(window, mouseDelta, closestCorner(window: window, mouse: point))
        }

        self.lastMousePosition = point
    }

    private func closestCorner(window: AccessibilityElement, mouse: CGPoint) -> Int {
        if let size = window.size {
            if let position = window.position {
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
        }
        return 3
    }

    private func resizeWindow(window: AccessibilityElement, mouseDelta: CGPoint, corner: Int) {
        if let size = window.size {
            if let position = window.position {
                switch corner {
                case 0:
                    window.position = CGPoint(x: position.x + mouseDelta.x, y: position.y + mouseDelta.y)
                    window.size = CGSize(width: size.width - mouseDelta.x, height: size.height - mouseDelta.y)
                case 1:
                    window.position = CGPoint(x: position.x, y: position.y + mouseDelta.y)
                    window.size = CGSize(width: size.width + mouseDelta.x, height: size.height - mouseDelta.y)
                case 2:
                    window.position = CGPoint(x: position.x + mouseDelta.x, y: position.y)
                    window.size = CGSize(width: size.width - mouseDelta.x, height: size.height + mouseDelta.y)
                case 3:
                    window.size = CGSize(width: size.width + mouseDelta.x, height: size.height + mouseDelta.y)
                default: break
                }
            }
        }
    }

    private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint, corner: Int) {
        if let position = window.position {
            let newPosition = CGPoint(x: position.x + mouseDelta.x, y: position.y + mouseDelta.y)
            window.position = newPosition
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
