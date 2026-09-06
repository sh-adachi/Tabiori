import SwiftUI

struct TripEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Trip
    @State private var budget: String
    @State private var errorMessage: String?
    @State private var initializedDefaults = false
    private let isNew: Bool

    init(trip: Trip? = nil) {
        isNew = trip == nil
        let initial = trip ?? Trip(title: "", destination: "", startDate: Date(), endDate: Date())
        _draft = State(initialValue: initial)
        _budget = State(initialValue: EditorAmount.string(initial.budget))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("次の旅を、一冊のしおりに。", systemImage: "suitcase.rolling.fill")
                        .font(.headline).foregroundStyle(AppTheme.teal)
                    TextField("旅のタイトル", text: $draft.title)
                        .accessibilityIdentifier("trip.title")
                    TextField("行き先（京都・大阪など）", text: $draft.destination)
                        .accessibilityIdentifier("trip.destination")
                } header: { Text("旅のこと") }

                Section {
                    DatePicker("出発日", selection: $draft.startDate, displayedComponents: .date)
                    DatePicker("帰宅日", selection: $draft.endDate, in: draft.startDate..., displayedComponents: .date)
                    NavigationLink {
                        TimeZoneEditorView(selection: $draft.timeZoneIdentifier)
                    } label: {
                        LabeledContent("旅先のタイムゾーン", value: draft.timeZoneIdentifier)
                    }
                } header: { Text("日程") } footer: {
                    Text("予定の日時は、このタイムゾーンで表示します。海外旅行では旅先に合わせてください。")
                }

                Section {
                    Picker("通貨", selection: $draft.currencyCode) {
                        ForEach(currencyCodes, id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityIdentifier("trip.currency")
                    HStack {
                        Text("旅の予算")
                        Spacer()
                        TextField("0", text: $budget)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .accessibilityLabel("旅の予算")
                        Text(draft.currencyCode).foregroundStyle(.secondary)
                    }
                } header: { Text("お金のこと") } footer: {
                    Text("予算は任意です。予定ごとに費用を記録すると、旅全体の合計を確認できます。")
                }

                Section("旅のメモ") {
                    TextField("やりたいこと、持ち物、気をつけたいこと…", text: $draft.notes, axis: .vertical)
                        .lineLimit(4...10)
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
            }
            .environment(\.timeZone, draft.timeZone)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isNew ? "新しい旅" : "旅を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).fontWeight(.semibold)
                        .accessibilityIdentifier("editor.save")
                }
            }
            .onChange(of: draft.startDate) { _, newValue in
                if draft.endDate < newValue { draft.endDate = newValue }
            }
            .onAppear {
                guard isNew, !initializedDefaults else { return }
                initializedDefaults = true
                draft.currencyCode = store.settings.defaultCurrencyCode
                draft.timeZoneIdentifier = store.settings.defaultTimeZoneIdentifier
            }
            .alert("保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .tint(AppTheme.teal)
    }

    private var currencyCodes: [String] {
        Array(Set(AppSettings.currencyCodes + [draft.currencyCode])).sorted()
    }

    private func save() {
        guard let value = EditorAmount.parse(budget) else {
            errorMessage = "予算は 0 以上の数値で入力してください。"
            return
        }
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.destination = draft.destination.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.budget = value
        if isNew {
            draft.checklist = store.settings.addsChecklistAutomatically
                ? store.settings.checklistTemplate.map { ChecklistItem(title: $0) }
                : []
        }
        var candidate = draft
        if !isNew {
            guard var latest = store.trip(id: draft.id) else {
                errorMessage = "この旅は削除されています。画面を閉じて旅行一覧を確認してください。"
                return
            }
            // A photo import can finish while this form is open. Preserve the
            // latest itinerary, documents, and checklist when saving metadata.
            latest.title = draft.title
            latest.destination = draft.destination
            latest.startDate = draft.startDate
            latest.endDate = draft.endDate
            latest.timeZoneIdentifier = draft.timeZoneIdentifier
            latest.currencyCode = draft.currencyCode
            latest.budget = draft.budget
            latest.notes = draft.notes
            candidate = latest
        }
        if store.save(candidate) { store.errorMessage = nil; dismiss() }
        else {
            errorMessage = store.errorMessage ?? "旅を保存できませんでした。もう一度お試しください。"
            store.errorMessage = nil
        }
    }
}

struct TimeZoneEditorView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        List {
            ForEach(TimeZone.knownTimeZoneIdentifiers.filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }, id: \.self) { identifier in
                Button {
                    selection = identifier
                    dismiss()
                } label: {
                    HStack {
                        Text(identifier).foregroundStyle(.primary)
                        Spacer()
                        if identifier == selection { Image(systemName: "checkmark").foregroundStyle(AppTheme.teal) }
                    }
                }
            }
        }
        .navigationTitle("タイムゾーン")
        .searchable(text: $query, prompt: "Tokyo、Paris、New_York など")
    }
}

enum EditorAmount {
    static func string(_ value: Double) -> String {
        let raw = value == 0 ? "" : String(value)
        return raw.replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }

    static func parse(_ value: String) -> Double? {
        let input = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.isEmpty { return 0 }
        let normalized = input.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
        guard let amount = Double(normalized), amount.isFinite, amount >= 0 else { return nil }
        return amount
    }
}
