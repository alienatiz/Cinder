import SwiftUI
import CinderCore

struct SessionHistoryView: View {
    @ObservedObject var model: AppModel
    @State private var page = 0
    @State private var query = ""
    @State private var selectedID: UUID?
    private let pageSize = 3
    private var records: [SessionRecord] {
        model.sessionHistory.records.filter { query.isEmpty || $0.outputName.localizedCaseInsensitiveContains(query) || model.t($0.outcome.label).localizedCaseInsensitiveContains(query) }
    }
    private var pageCount: Int { max(1, (records.count + pageSize - 1) / pageSize) }
    private var pageRecords: [SessionRecord] { Array(records.dropFirst(min(page, pageCount - 1) * pageSize).prefix(pageSize)) }
    private var selected: SessionRecord? {
        records.first { $0.id == selectedID } ?? pageRecords.first
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(model.t("Session history")).font(.title2)
                Spacer()
                Text(model.t("Recorded signal time") + " · " + Cycle.time(model.sessionHistory.records.reduce(0) { $0 + $1.signalSeconds })).monospacedDigit()
            }
            Text(model.t("The latest 500 runs stay on this Mac. Interrupted runs keep their last checkpoint; reopening never starts playback."))
                .font(.callout).foregroundStyle(.secondary)
            if let issue = model.historyError { Text(issue).foregroundStyle(.orange) }
            TextField(model.t("Search output or result"), text: $query).onChange(of: query) { _, _ in page = 0; selectedID = nil }
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(pageRecords) { record in
                        Button { selectedID = record.id } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.outputName).font(.headline).lineLimit(1)
                                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                                Text(model.t(record.outcome.label) + " · " + Cycle.time(record.signalSeconds)).font(.callout)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                .background(selected?.id == record.id ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    }
                    if records.isEmpty { Text(model.t("No sessions recorded yet.")) }
                    Spacer(minLength: 0)
                    HStack {
                        Button(model.t("Previous")) { page = max(0, page - 1); selectedID = nil }.disabled(page == 0)
                        Text("\(min(page + 1, pageCount)) / \(pageCount)").monospacedDigit()
                        Button(model.t("Next")) { page = min(pageCount - 1, page + 1); selectedID = nil }.disabled(page + 1 >= pageCount)
                    }
                }.frame(width: 350)
                if let record = selected {
                    Panel(title: model.t(record.outcome.label), compact: true) {
                        Text(model.sessionSummary(record)).font(.system(size: 12)).textSelection(.enabled)
                        HStack {
                            Button(model.t("Copy summary")) { model.copySessionSummary(record) }
                            Button(model.t("Export summary…")) { model.exportSessionSummary(record) }
                        }
                    }
                } else { Spacer() }
            }.frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
