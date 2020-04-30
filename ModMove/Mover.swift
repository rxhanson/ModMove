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
    private var scaleFactor: CGFloat?

    private var prevMousePosition: CGPoint?
    private var prevDate: Date = Date()
    // Mouse speed is in pixels/second.
    private var mouseSpeed: CGFloat = 0
    private let FAST_MOUSE_SPEED_THRESHOLD: CGFloat = 1000
    // Weight given to latest mouse speed for averaging.
    private let MOUSE_SPEED_WEIGHT: CGFloat = 0.1

    private func mouseMoved(handler: (_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Void) {
        let curMousePos = Mouse.currentPosition()
        if self.window == nil {
            self.window = AccessibilityElement.systemWideElement.element(at: curMousePos)?.window()
        }
        guard let window = self.window else {
            return
        }

        if self.initialMousePosition == nil {
            self.prevMousePosition = curMousePos
            self.initialMousePosition = curMousePos
            self.initialWindowPosition = window.position
            self.initialWindowSize = window.size
            self.closestCorner = self.getClosestCorner(window: window, mouse: curMousePos)
            (self.frame, self.scaleFactor) = getUsableScreen()

            let currentPid = NSRunningApplication.current.processIdentifier
            if let pid = window.pid(), pid != currentPid {
                NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
            }
            window.bringToFront()
        } else if let initMousePos = self.initialMousePosition {
            self.trackMouseSpeed(curMousePos: curMousePos)
            let mouseDelta = CGPoint(x: curMousePos.x - initMousePos.x, y: curMousePos.y - initMousePos.y)
            handler(window, mouseDelta)
        }
    }

    private func trackMouseSpeed(curMousePos: CGPoint) {
        if let prevMousePos = self.prevMousePosition, let scale = self.scaleFactor {
            let mouseDist: CGFloat = sqrt(
                pow((curMousePos.x - prevMousePos.x) / scale, 2)
                + pow((curMousePos.y - prevMousePos.y) / scale, 2))
            let now = Date()
            let timeDiff: CGFloat = CGFloat(now.timeIntervalSince(prevDate))
            let latestMouseSpeed = mouseDist / timeDiff
            self.mouseSpeed = latestMouseSpeed * MOUSE_SPEED_WEIGHT + self.mouseSpeed * (1 - MOUSE_SPEED_WEIGHT)
            self.prevMousePosition = curMousePos
            self.prevDate = now
            // NSLog("timeD: %.3f\tmouseD: %.1f\tmouseSpeed: %.1f", timeDiff, mouseDist, scale, self.mouseSpeed)
        }
    }

    private func getUsableScreen() -> (NSRect, CGFloat) {
        if var visible = NSScreen.main?.visibleFrame, let full = NSScreen.main?.frame, let scale = NSScreen.main?.backingScaleFactor {
            // For some reason, visibleFrame still has minY = 0 even though the menubar is there?
            visible.origin.y = full.size.height - visible.size.height
            return (visible, scale)
        }
        return (NSRect.zero, 1)
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
            var mdx = mouseDelta.x
            var mdy = mouseDelta.y
            switch corner {
            case .TopLeft:
                if shouldConstrainMouseDelta(window, mouseDelta) {
                    mdx = max(mouseDelta.x, frame.minX - initWinPos.x)
                    mdy = max(mouseDelta.y, frame.minY - initWinPos.y)
                }
                window.position =  CGPoint(x: initWinPos.x + mdx, y: initWinPos.y + mdy)
                window.size = CGSize(width: initWinSize.width - mdx, height: initWinSize.height - mdy)
            case .TopRight:
                if shouldConstrainMouseDelta(window, mouseDelta) {
                    mdx = min(mouseDelta.x, frame.maxX - (initWinPos.x + initWinSize.width))
                    mdy = max(mouseDelta.y, frame.minY - initWinPos.y)
                }
                window.position = CGPoint(x: initWinPos.x, y: initWinPos.y + mdy)
                window.size = CGSize(width: initWinSize.width + mdx, height: initWinSize.height - mdy )
            case .BottomLeft:
                if shouldConstrainMouseDelta(window, mouseDelta) {
                    mdx = max(mouseDelta.x, frame.minX - initWinPos.x)
                    mdy = min(mouseDelta.y, frame.maxY - (initWinPos.y + initWinSize.height))
                }
                window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y)
                window.size = CGSize(width: initWinSize.width - mdx, height: initWinSize.height + mdy)
            case .BottomRight:
                if shouldConstrainMouseDelta(window, mouseDelta) {
                    mdx = min(mouseDelta.x, frame.maxX - (initWinPos.x + initWinSize.width))
                    mdy = min(mouseDelta.y, frame.maxY - (initWinPos.y + initWinSize.height))
                }
                window.size = CGSize(width: initWinSize.width + mdx, height: initWinSize.height + mdy)
            }
        }
    }

    private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let initWinPos = self.initialWindowPosition, let initWinSize = self.initialWindowSize, let frame = self.frame {
            var mdx = mouseDelta.x
            var mdy = mouseDelta.y
            if shouldConstrainMouseDelta(window, mouseDelta) {
                mdx = min(max(mouseDelta.x, frame.minX - initWinPos.x),
                          frame.maxX - (initWinPos.x + initWinSize.width))
                mdy = min(max(mouseDelta.y, frame.minY - initWinPos.y),
                          frame.maxY - (initWinPos.y + initWinSize.height))
            }
            window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y + mdy)
        }
    }

    private func shouldConstrainMouseDelta(_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Bool {
        // Slow moves get constrained. But once a window is out of the frame, we don't constrain it anymore.
        if let frame = self.frame {
            return self.mouseSpeed < FAST_MOUSE_SPEED_THRESHOLD && windowInsideFrame(window, frame)
        }
        return false
    }

    private func windowInsideFrame(_ window: AccessibilityElement, _ frame: CGRect) -> Bool {
        if let pos = window.position, let size = window.size {
            return frame.contains(NSMakeRect(pos.x, pos.y, size.width, size.height))
        }
        return true
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
