import AppKit
import UniformTypeIdentifiers
import CinderCore
import CinderStorage

extension AppModel {
    func loadSessionHistory() {
        do {
            sessionHistory = try SessionHistoryStore(directory: storage.directory).load()
            if sessionHistory.recoverInterrupted() { saveSessionHistory() }
        } catch {
            historyWritable = false
            historyError = t("Session history could not be loaded. The existing file has been preserved.")
        }
    }
    func beginSessionRecord(now: Date = Date(), uptime: Double = ProcessInfo.processInfo.systemUptime) {
        guard sessionRecorder == nil else { return }
        sessionRecorder = SessionRecorder(settings: settings, outputName: device?.name ?? t("Unknown output"), now: now, uptime: uptime)
        updateSessionRecord(snapshot: AudioSnapshot(), now: now, uptime: uptime, force: true)
    }
    private var recordingPhase: SessionPhase {
        if planRun?.nextStart != nil { return .resting }
        if state == .paused { return .paused }
        if state == .preparing || state == .idle { return .preparing }
        return .playing
    }
    func updateSessionRecord(snapshot: AudioSnapshot, now: Date = Date(), uptime: Double = ProcessInfo.processInfo.systemUptime, force: Bool = false) {
        guard sessionRecorder != nil else { return }
        sessionRecorder?.update(snapshot: snapshot, phase: recordingPhase, gain: settings.gainDB, now: now, uptime: uptime)
        guard force || uptime - lastHistorySave >= 5 else { return }
        lastHistorySave = uptime
        if let record = sessionRecorder?.record { sessionHistory.upsert(record); saveSessionHistory() }
    }
    func finishSessionRecord(_ outcome: SessionOutcome, snapshot: AudioSnapshot? = nil, now: Date = Date(), uptime: Double = ProcessInfo.processInfo.systemUptime) {
        guard sessionRecorder != nil else { return }
        updateSessionRecord(snapshot: snapshot ?? AudioSnapshot(), now: now, uptime: uptime)
        sessionRecorder?.finish(outcome, at: now)
        if let record = sessionRecorder?.record {
            sessionHistory.upsert(record)
            notificationTask = Task { [weak self] in await self?.deliverSessionNotification(record) }
        }
        sessionRecorder = nil; saveSessionHistory()
    }
    func saveSessionHistory() {
        guard historyWritable else { return }
        historyWriter.save(sessionHistory) { [weak self] saved in
            Task { @MainActor [weak self] in
                self?.historyError = saved ? nil : self?.t("Session history could not be saved. Recent progress remains available until the app quits.")
            }
        }
    }
    func sessionSummary(_ record: SessionRecord) -> String {
        let fields = [
            "Cinder · " + t("Session history"),
            t("Started") + ": " + record.startedAt.formatted(date: .abbreviated, time: .standard),
            t("Last recorded") + ": " + record.updatedAt.formatted(date: .abbreviated, time: .standard),
            t("Result") + ": " + t(record.outcome.label),
            t("Output device") + ": " + record.outputName,
            t("Action") + ": " + t(record.settings.selectedProgram.label),
            t("Session time") + ": " + Cycle.time(record.elapsedSeconds),
            t("Signal stages") + ": " + Cycle.time(record.signalSeconds),
            t("Cycle rests") + ": " + Cycle.time(record.cycleRestSeconds),
            t("Between sessions") + ": " + Cycle.time(record.betweenRestSeconds),
            t("Paused time") + ": " + Cycle.time(record.pausedSeconds),
            t("Preparation time") + ": " + Cycle.time(record.preparingSeconds),
            t("App gain range") + ": " + GainPolicy.display(record.minimumGainDB) + " … " + GainPolicy.display(record.maximumGainDB),
            String(format: t("%d of %d sessions completed"), record.completedSessions, record.plannedSessions),
            t("Recorded signal time describes app playback, not measured headphone output.")
        ]
        return fields.joined(separator: "\n") + "\n"
    }
    func copySessionSummary(_ record: SessionRecord) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(sessionSummary(record), forType: .string)
    }
    func exportSessionSummary(_ record: SessionRecord) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Cinder-session-" + record.id.uuidString.prefix(8) + ".txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try sessionSummary(record).write(to: url, atomically: true, encoding: .utf8) }
        catch { self.error = t("Could not export the session summary.") }
    }
}
