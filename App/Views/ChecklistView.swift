import SwiftUI

struct ChecklistView: View {
    @Environment(AppStore.self) private var store
    let tripID: UUID
    @State private var title = ""

    var body: some View {
        Group {
            if let trip = store.trip(id: tripID) {
                List {
                    Section { progress(for: trip) }
                    Section("持ち物・やること") {
                        ForEach(trip.checklist) { item in
                            checklistRow(item, trip: trip)
                        }.onDelete { indices in
                            var updated = trip
                            updated.checklist.remove(atOffsets: indices)
                            store.save(updated)
                        }
                        addRow(trip)
                    }
                    Section { Text("項目をタップして完了に。左にスワイプすると削除できます。").font(.caption).foregroundStyle(.secondary) }
                }.navigationTitle("旅の準備").navigationBarTitleDisplayMode(.inline)
            } else { ContentUnavailableView("旅行が見つかりません", systemImage: "checklist") }
        }
    }

    private func progress(for trip: Trip) -> some View {
        let count = trip.checklist.filter(\.isChecked).count
        return VStack(alignment: .leading, spacing: 12) {
            SmallLabel(text: "READY FOR YOUR JOURNEY?")
            Text("忘れものなく、出発。").font(.system(size: 25, weight: .bold, design: .serif))
            ProgressView(value: Double(count), total: Double(max(1, trip.checklist.count)))
            Text("\(count) / \(trip.checklist.count) 項目の準備ができました").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 10)
    }

    private func checklistRow(_ item: ChecklistItem, trip: Trip) -> some View {
        Button {
            var updated = trip
            if let index = updated.checklist.firstIndex(where: { $0.id == item.id }) {
                updated.checklist[index].isChecked.toggle()
                store.save(updated)
            }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(item.isChecked ? AppTheme.teal : Color.secondary)
                Text(item.title).foregroundStyle(item.isChecked ? Color.secondary : AppTheme.ink)
                    .strikethrough(item.isChecked)
                Spacer()
            }.padding(.vertical, 5).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityIdentifier("checklist.toggle.\(item.title)")
            .accessibilityLabel(item.title).accessibilityValue(item.isChecked ? "完了" : "未完了")
    }

    private func addRow(_ trip: Trip) -> some View {
        HStack {
            TextField("項目を追加（例：充電器）", text: $title).submitLabel(.done).onSubmit { add(to: trip) }
                .accessibilityIdentifier("checklist.title")
            Button { add(to: trip) } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("チェック項目を追加")
        }
    }

    private func add(to trip: Trip) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        var updated = trip
        updated.checklist.append(ChecklistItem(title: cleanTitle))
        if store.save(updated) { title = "" }
    }
}
