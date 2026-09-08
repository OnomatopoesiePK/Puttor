//
//  LegalDocumentView.swift
//  Puttor
//
//  The three legal documents, kept as plain text files in the bundle rather
//  than as localised strings: they are long, they are amended as documents
//  rather than as sentences, and the same files are what a website will need
//  later. One file per document per language, with "# " marking a heading and
//  a blank line marking a paragraph.
//

import SwiftUI

enum LegalDocument: String, Identifiable, CaseIterable {
    case impressum
    case privacy
    case eula

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .impressum: return "legal.impressum"
        case .privacy: return "legal.privacy"
        case .eula: return "legal.eula"
        }
    }

    var subtitleKey: String {
        switch self {
        case .impressum: return "legal.impressum.desc"
        case .privacy: return "legal.privacy.desc"
        case .eula: return "legal.eula.desc"
        }
    }

    var icon: String {
        switch self {
        case .impressum: return "building.2"
        case .privacy: return "lock.shield"
        case .eula: return "doc.text"
        }
    }

    /// The document in the app's current language, then English, then German.
    /// These are Austrian documents and the German wording is the binding one,
    /// but a reader who chose Spanish is better served by the English text
    /// than by a German one they cannot read.
    func text(languageCode: String) -> String {
        load("\(rawValue)_\(languageCode)") ?? load("\(rawValue)_en") ?? load("\(rawValue)_de") ?? ""
    }

    private func load(_ name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    switch block {
                    case .heading(let text):
                        Text(text)
                            .font(.system(size: 13, weight: .bold)).tracking(0.8)
                            .foregroundStyle(Theme.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    case .paragraph(let text):
                        Text(text)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L(document.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private enum Block {
        case heading(String)
        case paragraph(String)
    }

    /// Splits the file on blank lines; a block opening with "# " is a heading,
    /// everything else is kept as written, line breaks and all.
    private var blocks: [Block] {
        document.text(languageCode: localization.languageCode)
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { block in
                block.hasPrefix("# ")
                    ? .heading(String(block.dropFirst(2)))
                    : .paragraph(block)
            }
    }
}
