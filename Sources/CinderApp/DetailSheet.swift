import SwiftUI

struct DetailSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let done: String
    let content: Content
    init(title: String, done: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.done = done; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.title2)
                Spacer()
                Button(done) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }.padding(24).frame(width: 1050, height: 640)
    }
}

struct PageControls: View {
    @ObservedObject var model: AppModel
    @Binding var page: Int
    let count: Int
    var body: some View {
        HStack {
            Button(model.t("Previous")) { page = max(0, page - 1) }.disabled(page == 0)
            Text("\(min(page + 1, max(1, count))) / \(max(1, count))").monospacedDigit()
            Button(model.t("Next")) { page = min(count - 1, page + 1) }.disabled(page + 1 >= count)
        }
    }
}
