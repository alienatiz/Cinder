import Foundation
import CinderCore

extension AppModel {
    func selectPlanMode(_ mode: PlaybackPlan.Mode) {
        guard !isLocked else { return }
        var plan = settings.selectedPlan; plan.mode = mode
        settings.playbackPlan = plan
        resetProgressForConfiguration(); savePlanPreference()
    }
    func applySplitPlan(sessionMinutes: Int, restMinutes: Int) {
        guard !isLocked else { return }
        let plan = PlaybackPlan(mode: .split40, sessionMinutes: sessionMinutes, restMinutes: restMinutes)
        do { try plan.validate() } catch { self.error = t(error.localizedDescription); return }
        settings.playbackPlan = plan
        resetProgressForConfiguration(); savePlanPreference()
    }
    func savePlanPreference() {
        do { try storage.savePlaybackPlan(settings.selectedPlan, customHours: settings.hours) }
        catch { self.error = t(error.localizedDescription) }
    }
    var planSummary: String {
        let runs = settings.plannedSessions
        switch settings.selectedPlan.mode {
        case .continuous40: return t("One 40-hour session")
        case .custom: return t("One session") + " · " + Cycle.time(settings.durationSeconds)
        case .split40:
            return String(format: t("%d sessions · last session %@"), runs.count, Cycle.time(Double((runs.last ?? 0) * 60)))
        }
    }
    var planProgress: String? {
        guard let run = planRun else { return nil }
        let completed = String(format: t("%d of %d sessions completed"), run.completedSessions, run.sessions.count)
        switch run.phase {
        case .resting(let until): return completed + " · " + t("Next session") + " " + until.formatted(date: .abbreviated, time: .shortened)
        case .completed: return completed + " · " + t("Plan completed")
        case .cancelled: return completed + " · " + t("Plan cancelled")
        case .playing: return completed
        }
    }
}
