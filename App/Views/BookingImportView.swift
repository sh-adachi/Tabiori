import SwiftUI

struct BookingImportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tripID: UUID
    let attachment: TravelAttachment
    @State private var candidates: [BookingCandidate] = []
    @State private var destination = ""
    @State private var updatesDestination = false
    @State private var expandsTripDates = false
    @State private var warnings: [String] = []
    @State private var isReading = true
    @State private var readAttempt = 0
    @State private var activeReadID = UUID()
    @State private var readingError: String?
    @State private var savingError: String?
    @State private var sourcePreview: AttachmentPreview?

    private var trip: Trip? { store.trip(id: tripID) }
    private var selectedCount: Int { candidates.filter(\.isSelected).count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: previewSource) {
                        Label("元の画像を確認", systemImage: "photo")
                    }.accessibilityIdentifier("booking.source")
                    Text("画像の文字を端末内AIで読み取ります。画像は端末外に送信しません。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("キャンセルしても、取り込んだ画像は旅行の書類に残ります。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if isReading {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("日程や行き先を読み取っています…")
                        }
                    }
                } else if let readingError {
                    Section {
                        Label(readingError, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                        Button("もう一度読み取る") { readAttempt += 1 }
                        Button("画像を見ながら手入力する") {
                            self.readingError = nil
                            candidates = [BookingCandidate()]
                        }.accessibilityIdentifier("booking.manual")
                    }
                } else if let trip {
                    Section {
                        Text("日時と行き先を画像と照合し、追加する予定を選んでください。未設定の開始日時は入力が必要です。")
                            .font(.subheadline)
                        ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                            Label(warning, systemImage: "exclamationmark.bubble")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Section("旅の行き先の候補") {
                        TextField("行き先", text: $destination)
                            .accessibilityIdentifier("booking.destination")
                        Toggle("旅行の行き先に反映", isOn: $updatesDestination)
                            .accessibilityIdentifier("booking.destination.apply")
                    }
                    ForEach($candidates) { $candidate in
                        BookingCandidateSection(candidate: $candidate, trip: trip)
                    }
                    if candidates.isEmpty {
                        Section {
                            Text("予定の候補が見つかりませんでした。日時や施設名がはっきり写った画像をお試しください。")
                            Button("手入力で候補を追加") { candidates.append(BookingCandidate()) }
                        }
                    }
                    Section {
                        Toggle("必要に応じて旅行期間を広げる", isOn: $expandsTripDates)
                            .accessibilityIdentifier("booking.expand")
                        Text("現在の日程：\(TripDate.range(trip))")
                            .font(.caption).foregroundStyle(.secondary)
                    } footer: {
                        Text("旅行期間外の予定を追加する場合にオンにしてください。追加する予定の開始・終了日に合わせて広げます。最大366日です。")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("画像から予定を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }.accessibilityIdentifier("booking.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(selectedCount)件を追加", action: save)
                        .disabled(isReading || readingError != nil || selectedCount == 0 || store.loadFailed || trip == nil)
                        .accessibilityIdentifier("booking.save")
                }
            }
            .task(id: readAttempt) { await read() }
            .sheet(item: $sourcePreview) { AttachmentPreviewView(file: $0) }
            .alert("予定を追加できませんでした", isPresented: Binding(get: { savingError != nil }, set: { if !$0 { savingError = nil } })) {
                Button("OK", role: .cancel) { savingError = nil }
            } message: { Text(savingError ?? "") }
        }
        .tint(AppTheme.teal)
    }

    @MainActor private func read() async {
        let requestID = UUID()
        activeReadID = requestID
        isReading = true
        readingError = nil
        defer { if activeReadID == requestID { isReading = false } }
        do {
            guard let trip, trip.attachments.contains(where: { $0.id == attachment.id }) else {
                throw TravelDataError.attachmentMissing
            }
            let url = try store.attachmentRepository.url(for: attachment)
            let data = try await Task.detached(priority: .userInitiated) {
                try AttachmentImport.readLimited(url)
            }.value
            try Task.checkCancellation()
            let result: BookingExtraction
            #if DEBUG
            if let fixture = BookingImportTestFixture.extraction(for: trip) {
                result = fixture
            } else {
                result = try await BookingExtractionService.extract(photoData: data, trip: trip)
            }
            #else
            result = try await BookingExtractionService.extract(photoData: data, trip: trip)
            #endif
            try Task.checkCancellation()
            guard activeReadID == requestID else { return }
            guard let latest = self.trip else { throw TravelDataError.invalid("旅行が見つかりません。") }
            candidates = result.candidates.map { candidate in
                var draft = candidate
                if BookingImport.duplicate(of: draft, in: latest) != nil { draft.isSelected = false }
                return draft
            }
            destination = result.destination
            warnings = result.warnings
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, activeReadID == requestID else { return }
            readingError = error.localizedDescription
        }
    }

    private func previewSource() {
        do {
            let url = try store.attachmentRepository.url(for: attachment)
            guard FileManager.default.fileExists(atPath: url.path) else { throw TravelDataError.attachmentMissing }
            sourcePreview = AttachmentPreview(id: attachment.id, title: attachment.displayName, url: url)
        } catch { savingError = error.localizedDescription }
    }

    private func save() {
        do {
            guard let trip else { throw TravelDataError.invalid("旅行が見つかりません。") }
            let updated = try BookingImport.applying(candidates, sourceAttachmentID: attachment.id,
                destination: updatesDestination ? destination : nil, expandTripDates: expandsTripDates, to: trip)
            guard store.save(updated) else {
                let reason = store.errorMessage ?? "予定を保存できませんでした。"
                store.errorMessage = nil
                throw TravelDataError.invalid(reason)
            }
            dismiss()
        } catch { savingError = error.localizedDescription }
    }
}

private struct BookingCandidateSection: View {
    @Binding var candidate: BookingCandidate
    let trip: Trip

    var body: some View {
        Section {
            Toggle("この予定を追加", isOn: $candidate.isSelected)
                .accessibilityIdentifier("booking.select.\(candidate.id)")
            if BookingImport.duplicate(of: candidate, in: trip) != nil {
                Label("同じ内容の予定が登録されています", systemImage: "square.on.square")
                    .font(.caption).foregroundStyle(AppTheme.coral)
            }
            TextField("予定のタイトル", text: $candidate.title)
                .accessibilityIdentifier("booking.title.\(candidate.id)")
            Picker("種類", selection: $candidate.kind) {
                ForEach(ItemKind.allCases) { kind in Text(kind.title).tag(kind) }
            }
            BookingDateField(title: "開始日時", date: $candidate.startDate, fallback: trip.startDate)
            BookingDateField(title: "終了日時（任意）", date: $candidate.endDate, fallback: candidate.startDate ?? trip.startDate)
            Text("表示時刻：\(trip.timeZoneIdentifier)").font(.caption).foregroundStyle(.secondary)
            if candidate.kind.isTransport {
                TextField("出発地", text: $candidate.departure)
                TextField("到着地", text: $candidate.arrival)
                TextField("便名・列車名", text: $candidate.serviceNumber)
            }
            TextField("予約番号", text: $candidate.reservationCode)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
            TextField("施設・場所の名前", text: $candidate.placeName)
            TextField("住所", text: $candidate.placeAddress, axis: .vertical)
            TextField("メモ", text: $candidate.notes, axis: .vertical).lineLimit(2...6)
            ForEach(Array(candidate.warnings.enumerated()), id: \.offset) { _, warning in
                Label(warning, systemImage: "exclamationmark.bubble")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text(candidate.title.isEmpty ? "予定の候補" : candidate.title)
        } footer: {
            Text("施設名・住所はメモに保存します。地図に表示するには、追加後の予定編集で場所を指定してください。")
        }
        .environment(\.timeZone, trip.timeZone)
    }
}

private struct BookingDateField: View {
    let title: String
    @Binding var date: Date?
    let fallback: Date

    var body: some View {
        if let value = date {
            DatePicker(title, selection: Binding(get: { date ?? value }, set: { date = $0 }))
            Button("\(title)を未設定に戻す", role: .destructive) { date = nil }.font(.caption)
        } else {
            Button("\(title)を設定") { date = fallback }
        }
    }
}
