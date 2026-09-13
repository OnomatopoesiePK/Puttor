//
//  DataTransferSection.swift
//  Puttor
//
//  Export and import, in Settings. Export writes every round and drill to one
//  file wherever the player chooses to keep it; import reads such a file back
//  and adds what is not already here.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataTransferSection: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportDocument: PuttorArchiveDocument?
    @State private var exportCounts = (rounds: 0, sessions: 0)
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var message: TransferMessage?

    private struct TransferMessage: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    private var defaultFilename: String {
        "Puttor-Export-\(Date().formatted(.iso8601.year().month().day()))"
    }

    var body: some View {
        VStack(spacing: 8) {
            row(icon: "square.and.arrow.up", title: L("data.export"), subtitle: L("data.export.desc")) {
                prepareExport()
            }
            row(icon: "square.and.arrow.down", title: L("data.import"), subtitle: L("data.import.desc")) {
                showingImporter = true
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: defaultFilename
        ) { result in
            switch result {
            case .success:
                message = TransferMessage(
                    title: L("data.exported.title"),
                    body: String(format: L("data.exported.body"), exportCounts.rounds, exportCounts.sessions)
                )
            case .failure(let error):
                if !isCancellation(error) { showFailure() }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importArchive(at: url)
            case .failure(let error):
                if !isCancellation(error) { showFailure() }
            }
        }
        .alert(item: $message) { message in
            Alert(title: Text(message.title), message: Text(message.body), dismissButton: .default(Text(L("common.done"))))
        }
    }

    // MARK: - Actions

    private func prepareExport() {
        do {
            let archive = try PuttorArchive.make(from: modelContext)
            exportDocument = PuttorArchiveDocument(data: try archive.encoded())
            exportCounts = (archive.rounds.count, archive.sessions.count)
            showingExporter = true
        } catch {
            showFailure()
        }
    }

    private func importArchive(at url: URL) {
        // Files picked from outside the app's own container are only readable
        // while access to them is held.
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        do {
            let archive = try PuttorArchive.decode(try Data(contentsOf: url))
            let summary = try archive.restore(into: modelContext)
            message = TransferMessage(
                title: L("data.imported.title"),
                body: String(format: L("data.imported.body"), summary.roundsAdded, summary.sessionsAdded, summary.skipped)
            )
        } catch {
            showFailure()
        }
    }

    private func showFailure() {
        message = TransferMessage(title: L("data.failed.title"), body: L("data.failed.body"))
    }

    private func isCancellation(_ error: Error) -> Bool {
        (error as? CocoaError)?.code == .userCancelled
    }

    // MARK: - Layout

    private func row(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).foregroundStyle(Theme.primary).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(Theme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
            }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
