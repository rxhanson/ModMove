import Foundation

extension AXValue {
    func toValue<T>() -> T? {
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        let success = AXValueGetValue(self, AXValueGetType(self), pointer)
        return success ? pointer.pointee : nil
    }

    static func from<T>(value: T, type: AXValueType) -> AXValue? {
        var value = value
        return AXValueCreate(type, &value)
    }
}
