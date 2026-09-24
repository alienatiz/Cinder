import Foundation
import CinderCore

extension AppModel {
    func setSchedule() {
        guard !isLocked else { return }
        guard device != nil else { error = t("Select an output device first."); return }
        guard scheduleDate > Date(), (0...365).contains(repeatDays), (1...365).contains(sessionCount) else {
            error = t("Choose a future date and valid repeat settings."); return
        }
        do { try settings.validate() } catch { self.error = error.localizedDescription; return }
        if let musicProblem { error = musicProblem; return }
        repeatAnchor = scheduleDate; repeatRemaining = repeatDays == 0 ? 1 : sessionCount
        armed = scheduleDate; scheduleMessage = t("Waiting for scheduled start — no sound")
        armScheduleTimer()
    }
    func armScheduleTimer() {
        if settings.keepAwake { awake.begin() }
        scheduleTicker.start(interval: 1) { [weak self] in self?.checkSchedule() }
    }
    func checkSchedule() {
        guard let target = armed else { return }
        updateSessionRecord(snapshot: AudioSnapshot())
        switch ScheduleRules.due(target: target, now: Date()) {
        case "due":
            scheduleTicker.stop(); armed = nil
            if planRun?.nextStart != nil {
                guard planRun?.startNextSession(at: Date()) == true else {
                    finishSessionRecord(.missedSchedule); cancelSchedule(); error = t("The scheduled time was missed. Set the schedule again."); return
                }
                scheduleMessage = t("Preparing scheduled session…")
                startCurrentSession()
            } else {
                repeatRemaining = max(0, repeatRemaining - 1)
                scheduleMessage = t("Preparing scheduled session…")
                guard device != nil else { cancelSchedule(); error = t("Select an output device first."); return }
                start()
            }
        case "missed":
            if sessionRecorder == nil { beginSessionRecord() }
            finishSessionRecord(.missedSchedule)
            cancelSchedule(); error = t("The scheduled time was missed. Set the schedule again.")
        default: break
        }
    }
    func cancelSchedule() {
        if planRun?.nextStart != nil { finishSessionRecord(.stopped) }
        scheduleTicker.stop(); armed = nil
        planRun?.cancel()
        repeatRemaining = 0; repeatAnchor = nil; scheduleMessage = ""
        if !state.locksSettings { awake.end() }
    }
    func rearmRepeat() {
        guard repeatRemaining > 0, repeatDays > 0, let anchor = repeatAnchor else { return }
        do {
            armed = try ScheduleRules.next(anchor: anchor, days: repeatDays, after: Date())
            scheduleMessage = t("Waiting for scheduled start — no sound")
            armScheduleTimer()
        } catch { cancelSchedule(); self.error = error.localizedDescription }
    }
}
