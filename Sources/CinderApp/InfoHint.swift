import SwiftUI
import CinderCore

@MainActor struct InfoHint: View {
    let text: String
    var symbol = "info.circle"
    var label: String? = nil
    var tint: Color = .secondary
    @State private var visible = false
    @State private var iconHovered = false
    @State private var popupHovered = false
    @State private var pinned = false
    @State private var closeTask: Task<Void, Never>?
    var body: some View {
        Button {
            closeTask?.cancel()
            pinned.toggle(); visible = pinned || iconHovered
        } label: {
            Image(systemName: symbol).font(.system(size: 13)).foregroundStyle(tint)
                .frame(width: 24, height: 24).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel(Text(label ?? text))
            .accessibilityHint(Text(text))
            .onHover { hovering in
                iconHovered = hovering
                if hovering { closeTask?.cancel(); visible = true }
                else { scheduleClose() }
            }
            .popover(isPresented: $visible, arrowEdge: .bottom) {
                Text(text).font(.system(size: 13)).lineSpacing(3)
                    .frame(width: 310, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .onHover { hovering in
                        popupHovered = hovering
                        if hovering { closeTask?.cancel() } else { scheduleClose() }
                    }
                    .onExitCommand { pinned = false; visible = false }
            }
            .onChange(of: visible) { _, shown in
                if !shown { pinned = false; popupHovered = false; closeTask?.cancel() }
            }
            .onDisappear { closeTask?.cancel(); closeTask = nil; visible = false; pinned = false }
    }
    private func scheduleClose() {
        closeTask?.cancel()
        closeTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: 200_000_000) } catch { return }
            guard !Task.isCancelled, !iconHovered, !popupHovered, !pinned else { return }
            visible = false; closeTask = nil
        }
    }
}

struct ActionPicker: View {
    @ObservedObject var model: AppModel
    var body: some View {
        HStack {
            Picker(model.t("Action"), selection: Binding(get: { model.settings.selectedProgram }, set: {
                guard !model.isLocked else { return }
                model.settings.program = $0; model.resetProgressForConfiguration()
            })) {
                ForEach(PlaybackProgram.allCases, id: \.self) { program in Text(model.t(program.label)).tag(program) }
            }.disabled(model.isLocked)
            InfoHint(text: model.t("Cycle help"))
        }
    }
}
