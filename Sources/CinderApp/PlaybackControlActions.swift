import CinderCore

extension AppModel {
    var canStart: Bool { !isLocked && device != nil && musicProblem == nil }
    var canTogglePause: Bool { state == .playing || state == .paused }
    var canStartOrResume: Bool { state == .paused || canStart }
    var canStop: Bool { (state.locksSettings || armed != nil) && state != .stopping }

    var primaryPlaybackTitle: String {
        switch state {
        case .playing: return "Pause"
        case .paused: return "Resume"
        default: return "Start"
        }
    }

    var canPerformPrimaryPlaybackAction: Bool { canTogglePause || canStart }

    /// The playback menu and its keyboard shortcut use the same guarded action.
    func performPrimaryPlaybackAction() {
        if canTogglePause {
            togglePause()
        } else if canStart {
            start()
        }
    }
}
