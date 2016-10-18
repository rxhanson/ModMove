import AppKit
import Foundation

enum FlagState {
    case resize
    case drag
    case ignore
}

final class Observer {
    private var monitor: Any?

    func startObserving(handler: @escaping (FlagState) -> Void) {
        self.removeMonitor()
        self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if let state = self?.state(for: event.modifierFlags) {
                handler(state)
            }
        }
    }

    private func state(for flags: NSEventModifierFlags) -> FlagState {
        let hasControlAndOption = flags.contains(.control) && flags.contains(.option)
        let hasShift = flags.contains(.shift)

        if hasShift && hasControlAndOption {
            return .resize
        } else if hasControlAndOption {
            return .drag
        } else {
            return .ignore
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
