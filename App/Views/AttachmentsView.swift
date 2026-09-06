import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

struct AttachmentsView: View {
    @Environment(AppStore.self) private var store
    let tripID: UUID
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingFiles = false
    @State private var isImporting = false
    @State private var relatedItemID: UUID?
    @State private var preview: AttachmentPreview?
    @State private var pendingDelete: TravelAttachment?
    @State private var errorMessage: String?

    private var trip: Trip? { store.trip(id: tripID) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("チケットも、予約書類も。", systemImage: "doc.text.image")
                        .font(.headline).foregroundStyle(AppTheme.ink)
                    Text("旅に必要な写真と PDF を、ひとまとめに。保存した書類はオフラインでも開けます。")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                if let trip, !trip.items.isEmpty {
                    Picker("追加先の予定", selection: $relatedItemID) {
                        Text("旅全体の書類").tag(UUID?.none)
                        ForEach(trip.sortedItems) { item in Text(item.title).tag(Optional(item.id)) }
                    }
                    .disabled(isImporting)
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images, preferredItemEncoding: .current) {
                    Label("写真から追加", systemImage: "photo.on.rectangle.angled")
                }
                .disabled(isImporting || store.loadFailed || trip == nil)
                .accessibilityIdentifier("documents.photo")
                Button { showingFiles = true } label: {
                    Label("ファイルから追加", systemImage: "folder.badge.plus")
                }
                .disabled(isImporting || store.loadFailed || trip == nil)
                .accessibilityIdentifier("documents.add")
                if isImporting {
                    HStack(spacing: 10) { ProgressView(); Text("書類を保存しています…").font(.subheadline).foregroundStyle(.secondary) }
                }
            } footer: {
                Text("画像・PDF、1 件 25 MB まで。写真は長辺 2,560 px 以下の JPEG に変換します。書類はこの iPhone 内に保存されます。")
            }

            if let trip, !trip.attachments.isEmpty {
                Section("保存した書類（\(trip.attachments.count)）") {
                    ForEach(trip.attachments.sorted { $0.createdAt > $1.createdAt }) { attachment in
                        Button { open(attachment) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: attachment.kind == .pdf ? "doc.richtext" : "photo")
                                    .font(.title2).foregroundStyle(attachment.kind == .pdf ? AppTheme.coral : AppTheme.teal)
                                    .frame(width: 46, height: 54)
                                    .background((attachment.kind == .pdf ? AppTheme.coral : AppTheme.teal).opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(attachment.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2)
                                    if let id = attachment.itemID, let item = trip.items.first(where: { $0.id == id }) {
                                        Label(item.title, systemImage: item.kind.symbol).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Text(attachment.createdAt, format: .dateTime.year().month().day()).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .accessibilityIdentifier("document.\(attachment.id.uuidString)")
                        .swipeActions {
                            Button("削除", role: .destructive) { pendingDelete = attachment }
                        }
                        .contextMenu {
                            Button { open(attachment) } label: { Label("開く・共有", systemImage: "doc.viewfinder") }
                            Button(role: .destructive) { pendingDelete = attachment } label: { Label("削除", systemImage: "trash") }
                        }
                    }
                }
            } else {
                Section {
                    ContentUnavailableView("書類を旅のおともに", systemImage: "ticket", description: Text("搭乗券、ホテルの予約確認、行きたいお店の写真などを追加しましょう。"))
                }
            }
        }
        .navigationTitle("書類")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppTheme.teal)
        .fileImporter(isPresented: $showingFiles, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importFiles(urls)
            case .failure(let error):
                if (error as NSError).code != NSUserCancelledError { errorMessage = "ファイルを開けませんでした。\(error.localizedDescription)" }
            }
        }
        .onChange(of: selectedPhoto) { _, photo in
            if let photo { importPhoto(photo) }
        }
        .sheet(item: $preview) { file in
            AttachmentPreviewView(file: file)
        }
        .confirmationDialog("この書類を削除しますか？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            if let attachment = pendingDelete {
                Button("書類を削除", role: .destructive) { delete(attachment) }
            }
            Button("キャンセル", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("この旅に保存したコピーが削除されます。元の写真やファイルには影響しません。")
        }
        .alert("書類を確認してください", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func importPhoto(_ photo: PhotosPickerItem) {
        guard !isImporting else { return }
        isImporting = true
        let itemID = relatedItemID
        Task { @MainActor in
            defer { isImporting = false; selectedPhoto = nil }
            do {
                guard let imported = try await photo.loadTransferable(type: ImportedPhoto.self) else { throw AttachmentImportError.invalidPhoto }
                let name = "写真 \(Date().formatted(.dateTime.year().month().day().hour().minute())).jpg"
                let prepared = try await Task.detached(priority: .userInitiated) {
                    try AttachmentImport.preparePhoto(imported.data, displayName: name)
                }.value
                try commit(prepared, itemID: itemID)
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func importFiles(_ urls: [URL]) {
        guard !isImporting, !urls.isEmpty else { return }
        isImporting = true
        let itemID = relatedItemID
        Task { @MainActor in
            defer { isImporting = false }
            var failures: [String] = []
            for url in urls {
                do {
                    let prepared = try await Task.detached(priority: .userInitiated) {
                        try AttachmentImport.prepareFile(url)
                    }.value
                    try commit(prepared, itemID: itemID)
                } catch { failures.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
            }
            if !failures.isEmpty { errorMessage = failures.joined(separator: "\n\n") }
        }
    }

    /// Save the metadata only after writing the file. If persistence fails, remove
    /// the new file so an unsuccessful import does not leave a hidden copy behind.
    private func commit(_ prepared: PreparedAttachment, itemID: UUID?) throws {
        guard var trip else { throw AttachmentImportError.message("この旅が見つかりません。") }
        let validItemID = itemID.flatMap { id in trip.items.contains(where: { $0.id == id }) ? id : nil }
        let attachment = try store.attachmentRepository.store(data: prepared.data, displayName: prepared.displayName, kind: prepared.kind, itemID: validItemID)
        trip.attachments.append(attachment)
        if !store.save(trip) {
            let reason = store.errorMessage ?? "書類の情報を保存できませんでした。"
            store.errorMessage = nil
            do { try store.attachmentRepository.remove(attachment) }
            catch { throw AttachmentImportError.message("\(reason)\n読み込んだファイルの後片付けにも失敗しました：\(error.localizedDescription)") }
            throw AttachmentImportError.message(reason)
        }
    }

    private func open(_ attachment: TravelAttachment) {
        do {
            let url = try store.attachmentRepository.url(for: attachment)
            guard FileManager.default.fileExists(atPath: url.path) else { throw AttachmentImportError.message("書類のファイルが見つかりません。元のファイルを追加し直してください。") }
            preview = AttachmentPreview(id: attachment.id, title: attachment.displayName, url: url)
        } catch { errorMessage = error.localizedDescription }
    }

    private func delete(_ attachment: TravelAttachment) {
        pendingDelete = nil
        guard let original = trip else { return }
        var updated = original
        updated.attachments.removeAll { $0.id == attachment.id }
        guard store.save(updated) else {
            errorMessage = store.errorMessage ?? "書類を削除できませんでした。"
            store.errorMessage = nil
            return
        }
        do { try store.attachmentRepository.remove(attachment) }
        catch {
            let deletionError = error.localizedDescription
            if store.save(original) { errorMessage = "書類を削除できませんでした。\(deletionError)" }
            else {
                errorMessage = "書類一覧から削除しましたが、ファイルの削除に失敗しました。\(deletionError)"
                store.errorMessage = nil
            }
        }
    }
}

private struct AttachmentPreview: Identifiable {
    let id: UUID
    let title: String
    let url: URL
}

private struct AttachmentPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let file: AttachmentPreview

    var body: some View {
        NavigationStack {
            QuickLookFileView(url: file.url)
                .navigationTitle(file.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } }
                    ToolbarItem(placement: .bottomBar) {
                        ShareLink(item: file.url) { Label("書類を共有", systemImage: "square.and.arrow.up") }
                    }
                }
        }
        .tint(AppTheme.teal)
    }
}

private struct QuickLookFileView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        if context.coordinator.url != url {
            context.coordinator.url = url
            controller.reloadData()
        }
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { url as NSURL }
    }
}
