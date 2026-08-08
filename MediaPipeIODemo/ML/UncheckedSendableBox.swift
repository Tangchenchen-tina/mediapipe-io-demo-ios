import Foundation

/// Carries a non-`Sendable` reference (the MediaPipe SDK's ObjC-bridged task classes aren't
/// audited for `Sendable`) across an isolation boundary into a `Task.detached` closure. Safe here
/// specifically because each box is used for exactly one call and never shared or mutated
/// concurrently — see the engines' doc comments for why the detachment itself matters.
struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
