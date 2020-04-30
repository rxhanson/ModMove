import AppKit
import Foundation

enum Corner {
    case TopLeft
    case TopRight
    case BottomLeft
    case BottomRight
}

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
    private var closestCorner: Corner?
    private var window: AccessibilityElement?
    private var frame: NSRect?

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
            self.frame = getUsableScreen()

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

    private func getUsableScreen() -> NSRect? {
        if var visible = NSScreen.main?.visibleFrame, let full = NSScreen.main?.frame {
            // For some reason, visibleFrame still has minY = 0 even though the menubar is there?
            visible.origin.y = full.size.height - visible.size.height
            return visible
        }
        return NSRect.zero
    }

    private func getClosestCorner(window: AccessibilityElement, mouse: CGPoint) -> Corner {
        if let size = window.size, let position = window.position {
            let xmid = position.x + size.width / 2
            let ymid = position.y + size.height / 2
            if mouse.x < xmid && mouse.y < ymid {
                return .TopLeft
            } else if mouse.x >= xmid && mouse.y < ymid {
                return .TopRight
            } else if mouse.x < xmid && mouse.y >= ymid {
                return .BottomLeft
            } else {
                return .BottomRight
            }
        }
        return .BottomRight
    }

    private func resizeWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let initWinSize = self.initialWindowSize, let initWinPos = self.initialWindowPosition,
            let corner = self.closestCorner, let frame = self.frame {
            switch corner {
            case .TopLeft:
                let mdx = max(mouseDelta.x, frame.minX - initWinPos.x)
                let mdy = max(mouseDelta.y, frame.minY - initWinPos.y)
                window.position =  CGPoint(x: initWinPos.x + mdx, y: initWinPos.y + mdy)
                window.size = CGSize(width: initWinSize.width - mdx, height: initWinSize.height - mdy)
            case .TopRight:
                let mdx = min(mouseDelta.x, frame.maxX - (initWinPos.x + initWinSize.width))
                let mdy = max(mouseDelta.y, frame.minY - initWinPos.y)
                window.position = CGPoint(x: initWinPos.x, y: initWinPos.y + mdy)
                window.size = CGSize(width: initWinSize.width + mdx, height: initWinSize.height - mdy )
            case .BottomLeft:
                let mdx = max(mouseDelta.x, frame.minX - initWinPos.x)
                let mdy = min(mouseDelta.y, frame.maxY - (initWinPos.y + initWinSize.height))
                window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y)
                window.size = CGSize(width: initWinSize.width - mdx, height: initWinSize.height + mdy)
            case .BottomRight:
                let mdx = min(mouseDelta.x, frame.maxX - (initWinPos.x + initWinSize.width))
                let mdy = min(mouseDelta.y, frame.maxY - (initWinPos.y + initWinSize.height))
                window.size = CGSize(width: initWinSize.width + mdx, height: initWinSize.height + mdy)
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
        self.resetState()

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
            break
        }
    }

    private func resetState() {
        self.initialMousePosition = nil
        self.initialWindowPosition = nil
        self.initialWindowSize = nil
        self.closestCorner = nil
        self.window = nil
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
