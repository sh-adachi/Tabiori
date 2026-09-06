import SwiftUI

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = AppSettings()
    @State private var templateText = ""
    @State private var initialized = false
    @State private var errorMessage: String?
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            Form {
                if store.settingsLoadFailed {
                    Section {
                        Label("保存した設定を読み込めませんでした。", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                        Button("設定を再読み込み") {
                            store.reloadSettings()
                            if !store.settingsLoadFailed { loadDraft() }
                            else { consumeStoreError() }
                        }
                    } footer: {
                        Text("保存済みの設定を保護するため、再読み込みできるまで変更を停止しています。")
                    }
                }

                Section {
                    Picker("外観", selection: $draft.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { appearance in
                            Text(appearance == .system ? "自動" : appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.appearance")
                } header: { Text("表示") } footer: { Text("自動ではiPhoneのライト／ダーク設定に合わせます。") }
                .disabled(store.settingsLoadFailed)

                Section {
                    Picker("通貨", selection: $draft.defaultCurrencyCode) {
                        ForEach(AppSettings.currencyCodes, id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityIdentifier("settings.currency")
                    NavigationLink {
                        TimeZoneEditorView(selection: $draft.defaultTimeZoneIdentifier)
                    } label: {
                        LabeledContent("タイムゾーン", value: draft.defaultTimeZoneIdentifier)
                    }
                    .accessibilityIdentifier("settings.timezone")
                } header: { Text("新しい旅の初期設定") } footer: {
                    Text("これから作成する旅に適用します。旅ごとに変更でき、既存の旅には影響しません。")
                }
                .disabled(store.settingsLoadFailed)

                Section {
                    Toggle("チェックリストを自動で追加", isOn: $draft.addsChecklistAutomatically)
                        .accessibilityIdentifier("settings.checklist")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("チェックリストのテンプレート").font(.subheadline).foregroundStyle(.secondary)
                        TextField("1 行に 1 項目を入力", text: $templateText, axis: .vertical)
                            .lineLimit(5...12)
                            .accessibilityLabel("チェックリストのテンプレート")
                            .accessibilityIdentifier("settings.template")
                    }
                    .padding(.vertical, 4)
                } header: { Text("旅の準備") } footer: {
                    Text("新しい旅に追加する持ち物や確認事項です。1 行に 1 項目、100 項目まで登録できます。空の行は保存時に除きます。")
                }
                .disabled(store.settingsLoadFailed)

                Section {
                    Picker("優先する移動手段", selection: $draft.directionsMode) {
                        ForEach(DirectionsMode.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
                    }
                    .accessibilityIdentifier("settings.directions")
                } header: { Text("マップの経路") } footer: {
                    Text("Apple マップで経路を調べるときの移動手段です。マップを開いたあとにも変更できます。")
                }
                .disabled(store.settingsLoadFailed)

                Section {
                    Toggle("旅程の共有に予約番号を含める", isOn: $draft.includesReservationCodesInShare)
                        .accessibilityIdentifier("settings.sharing")
                } header: { Text("共有") } footer: {
                    Text("オフにすると「予約番号」欄の内容を共有テキストから省きます。メモや添付書類に書かれた情報はそのまま共有されます。")
                }
                .disabled(store.settingsLoadFailed)
                Section {
                    Button { showAbout = true } label: {
                        Label("たびおりについて・使い方", systemImage: "info.circle")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }.accessibilityIdentifier("settings.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).fontWeight(.semibold)
                        .disabled(store.settingsLoadFailed)
                        .accessibilityIdentifier("settings.save")
                }
            }
            .onAppear {
                guard !initialized else { return }
                initialized = true
                loadDraft()
            }
            .sheet(isPresented: $showAbout) { AboutView() }
            .alert("設定を保存できませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .tint(AppTheme.teal)
    }

    private func loadDraft() {
        draft = store.settings
        templateText = draft.checklistTemplate.joined(separator: "\n")
    }

    private func save() {
        draft.checklistTemplate = templateText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if store.saveSettings(draft) { dismiss() }
        else { consumeStoreError() }
    }

    private func consumeStoreError() {
        errorMessage = store.errorMessage ?? "設定を保存できませんでした。もう一度お試しください。"
        store.errorMessage = nil
    }
}
