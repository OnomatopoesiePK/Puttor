//
//  CustomModeSettingsView.swift
//  Puttor
//
//  Field editor for Custom input mode: Distance is always included first,
//  Result is always included last (simple/complex configurable), and any
//  number of optional fields can be added, removed, and reordered between
//  them. Adding, deleting, reordering, and simple/complex toggling are only
//  possible in edit mode; the checkmark commits the draft, and leaving via
//  the back button while edits are pending confirms whether to save.
//

import SwiftUI

struct CustomModeSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var savedConfig: CustomModeConfig = CustomModeConfig.load()
    @State private var draftConfig: CustomModeConfig = CustomModeConfig.load()
    @State private var isEditing = false
    @State private var hasPendingChanges = false
    @State private var showAddField = false
    @State private var showUnsavedConfirm = false

    private var availableKinds: [CustomFieldKind] {
        CustomFieldKind.allCases.filter { kind in !draftConfig.fields.contains { $0.kind == kind } }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "ruler").foregroundStyle(Theme.primary).frame(width: 24)
                    Text(L("custom.field.distance")).foregroundStyle(Theme.text)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { draftConfig.distanceComplexity },
                        set: { draftConfig.distanceComplexity = $0 }
                    )) {
                        ForEach(FieldComplexity.allCases, id: \.self) { c in
                            Text(L(c.labelKey)).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .disabled(!isEditing)
                }
                .listRowBackground(Theme.surface)
            } header: {
                Text(L("custom.alwaysIncluded"))
            } footer: {
                Text(L("custom.distance.desc"))
            }

            Section {
                ForEach(draftConfig.fields) { field in
                    fieldRow(field)
                }
                .onMove { indices, newOffset in
                    draftConfig.fields.move(fromOffsets: indices, toOffset: newOffset)
                }
                .onDelete { indices in
                    draftConfig.fields.remove(atOffsets: indices)
                    hasPendingChanges = true
                }

                if isEditing {
                    Button {
                        showAddField = true
                    } label: {
                        Label(L("custom.addField"), systemImage: "plus.circle.fill")
                            .foregroundStyle(Theme.primary)
                    }
                    .disabled(availableKinds.isEmpty)
                    .listRowBackground(Theme.surface)
                }
            } header: {
                Text(L("custom.optionalFields"))
            } footer: {
                Text(L("custom.reorderHint"))
            }

            Section {
                HStack {
                    Image(systemName: "flag.fill").foregroundStyle(Theme.primary).frame(width: 24)
                    Text(L("custom.field.result")).foregroundStyle(Theme.text)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { draftConfig.resultComplexity },
                        set: { draftConfig.resultComplexity = $0 }
                    )) {
                        ForEach(FieldComplexity.allCases, id: \.self) { c in
                            Text(L(c.labelKey)).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .disabled(!isEditing)
                }
                .listRowBackground(Theme.surface)
            } header: {
                Text(L("custom.alwaysIncluded"))
            } footer: {
                Text(L("custom.result.desc"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .navigationTitle(L("custom.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    attemptLeave()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L("common.back"))
                    }
                }
                .foregroundStyle(Theme.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button {
                        commitSave()
                    } label: {
                        Image(systemName: "checkmark").fontWeight(.bold)
                    }
                    .foregroundStyle(Theme.primary)
                } else {
                    Button(L("common.edit")) {
                        beginEditing()
                    }
                    .foregroundStyle(Theme.primary)
                }
            }
        }
        .sheet(isPresented: $showAddField) {
            addFieldSheet
        }
        .confirmationDialog(L("custom.unsavedTitle"), isPresented: $showUnsavedConfirm, titleVisibility: .visible) {
            Button(L("common.save")) {
                commitSave()
                dismiss()
            }
            Button(L("custom.discardChanges"), role: .destructive) {
                isEditing = false
                hasPendingChanges = false
                dismiss()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("custom.unsavedMessage"))
        }
        .onAppear {
            reload()
        }
        .preferredColorScheme(ThemeManager.shared.colorScheme)
    }

    private func reload() {
        let fresh = CustomModeConfig.load()
        savedConfig = fresh
        draftConfig = fresh
        isEditing = false
        hasPendingChanges = false
    }

    private func beginEditing() {
        draftConfig = savedConfig
        hasPendingChanges = false
        isEditing = true
    }

    private func commitSave() {
        savedConfig = draftConfig
        savedConfig.save()
        isEditing = false
        hasPendingChanges = false
    }

    private func attemptLeave() {
        if isEditing && hasPendingChanges {
            showUnsavedConfirm = true
        } else {
            dismiss()
        }
    }

    private func fieldRow(_ field: CustomField) -> some View {
        HStack {
            Image(systemName: field.kind.icon).foregroundStyle(Theme.primary).frame(width: 24)
            Text(L(field.kind.titleKey)).foregroundStyle(Theme.text)
            Spacer()
            if field.kind.supportsComplexity {
                Picker("", selection: Binding(
                    get: { field.complexity },
                    set: { newValue in
                        if let idx = draftConfig.fields.firstIndex(where: { $0.id == field.id }) {
                            draftConfig.fields[idx].complexity = newValue
                        }
                    }
                )) {
                    ForEach(FieldComplexity.allCases, id: \.self) { c in
                        Text(L(c.labelKey)).tag(c)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .disabled(!isEditing)
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var addFieldSheet: some View {
        NavigationStack {
            List(availableKinds) { kind in
                Button {
                    draftConfig.fields.append(CustomField(kind: kind))
                    hasPendingChanges = true
                    showAddField = false
                } label: {
                    HStack {
                        Image(systemName: kind.icon).foregroundStyle(Theme.primary).frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L(kind.titleKey)).foregroundStyle(Theme.text)
                            Text(L(kind.descKey)).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("custom.addField"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("common.cancel")) { showAddField = false }
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(ThemeManager.shared.colorScheme)
    }
}

#Preview {
    NavigationStack {
        CustomModeSettingsView()
    }
}
