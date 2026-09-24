import Foundation

/// A single main-run-loop timer, without a Task allocation on each tick.
@MainActor public final class MainRunLoopTicker {
    private var timer: Timer?
    private var interval: TimeInterval?
    private var action: (() -> Void)?
    private let target = TickTarget()
    public init() { target.owner = self }
    public func start(interval: TimeInterval, action: @escaping () -> Void) {
        self.action = action
        guard timer == nil || self.interval != interval else { return }
        timer?.invalidate()
        self.interval = interval
        let timer = Timer(timeInterval: interval, target: target, selector: #selector(TickTarget.fire), userInfo: nil, repeats: true)
        timer.tolerance = interval * 0.2
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    public func stop() {
        timer?.invalidate(); timer = nil; interval = nil; action = nil
    }
    fileprivate func fire() { action?() }
    isolated deinit { timer?.invalidate() }
}

@MainActor private final class TickTarget: NSObject {
    weak var owner: MainRunLoopTicker?
    @objc func fire() { owner?.fire() }
}
