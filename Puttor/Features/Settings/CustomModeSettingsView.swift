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
    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    /// The fold-out that says what this layout can be read for.
    @State private var showPreview = false
    /// Which fields have their own preview folded out, by field id.
    @State private var expandedPreviews: Set<String> = []

    private var availableKinds: [CustomFieldKind] {
        CustomFieldKind.allCases.filter { kind in !draftConfig.fields.contains { $0.kind == kind } }
    }

    var body: some View {
        List {
            // What the layout is worth, before the layout itself.
            previewSection

            Section {
                HStack {
                    Image(systemName: "ruler").foregroundStyle(Theme.primary).frame(width: 24)
                    Text(L("custom.field.distance")).foregroundStyle(Theme.text)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { draftConfig.distanceStyle },
                        set: { draftConfig.distanceStyle = $0 }
                    )) {
                        ForEach(DistanceInputStyle.allCases, id: \.self) { style in
                            Text(L(style.labelKey)).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .disabled(!isEditing)
                }
                .listRowBackground(Theme.surface)

                fieldPreview("distance", .distance(draftConfig.distanceStyle))
                    .listRowBackground(Theme.surface)
            } header: {
                Text(L("custom.firstInput"))
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
                        get: { draftConfig.resultStyle },
                        set: { draftConfig.resultStyle = $0 }
                    )) {
                        ForEach(ResultInputStyle.allCases, id: \.self) { style in
                            Text(L(style.labelKey)).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 230)
                    .disabled(!isEditing)
                }
                .listRowBackground(Theme.surface)

                fieldPreview("result", .result(draftConfig.resultStyle))
                    .listRowBackground(Theme.surface)
            } header: {
                Text(L("custom.lastInput"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .navigationTitle(L("custom.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // Swiped back like any other screen, unless there are changes to ask
        // about: then the swipe asks, as the button does.
        .swipeBack(allowed: !(isEditing && hasPendingChanges)) { showUnsavedConfirm = true }
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

    /// What the chosen fields are worth: a tap on the arrow lists the
    /// statistics this layout feeds, and what is still missing for the rest.
    private var previewSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showPreview) {
                ForEach(CustomModePreview.lines(for: draftConfig)) { line in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: line.available ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(line.available ? Theme.primary : Theme.textMuted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L(line.key))
                                .font(.system(size: 14))
                                .foregroundStyle(line.available ? Theme.text : Theme.textMuted)
                            if let missing = line.missingKey {
                                Text(String(format: L("custom.preview.needs"), L(missing)))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            } label: {
                Text(L("custom.preview.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .tint(Theme.primary)
            .listRowBackground(Theme.surface)
        } footer: {
            Text(L("custom.preview.desc"))
        }
    }

    /// The arrow under a field: it folds out that field exactly as a round
    /// shows it, so the choice above can be seen rather than described.
    private func fieldPreview(_ id: String, _ subject: CustomFieldPreview.Subject) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expandedPreviews.contains(id) },
            set: { open in
                if open { expandedPreviews.insert(id) } else { expandedPreviews.remove(id) }
            }
        )) {
            CustomFieldPreview(subject: subject, useFeet: unitsPref == "imperial")
                .padding(.vertical, 4)
        } label: {
            Text(L("custom.preview.field"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .tint(Theme.primary)
    }

    private func fieldRow(_ field: CustomField) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            fieldHeader(field)
            if field.kind == .intention {
                ForEach(IntentionPart.allCases) { part in
                    intentionToggle(part, of: field)
                }
                // Opens while the fields are edited, as long as the pace is asked.
                if isEditing && field.intentionParts.contains(.speed) {
                    normalPaceSlider(of: field)
                        .transition(.opacity)
                }
            }
            if field.kind == .girOpportunity {
                girOpportunityPresetPicker(of: field)
            }
            fieldPreview(field.id.uuidString, .field(field))
                .padding(.top, 2)
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .listRowBackground(Theme.surface)
    }

    /// How far past the hole the normal pace finishes, from 20 to 80 cm.
    private func normalPaceSlider(of field: CustomField) -> some View {
        let useFeet = unitsPref == "imperial"
        let shown = PuttSpeed.pastText(field.normalPastM, useFeet: useFeet)
        let binding = Binding(
            get: { field.normalPastM },
            set: { newValue in
                guard let idx = draftConfig.fields.firstIndex(where: { $0.id == field.id }) else { return }
                draftConfig.fields[idx].normalPastM = newValue
                hasPendingChanges = true
            }
        )
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L("intention.settings.normalPace"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(shown)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.primary)
            }
            Slider(value: binding, in: PuttSpeed.normalPastRange, step: useFeet ? 0.0254 : 0.01)
                .tint(Theme.primary)
                .accessibilityLabel(L("intention.settings.normalPace"))
                .accessibilityValue(shown)
        }
        .padding(.leading, 32)
        .padding(.vertical, 6)
    }

    /// What each hole's first putt starts on: yes or no.
    private func girOpportunityPresetPicker(of field: CustomField) -> some View {
        HStack(spacing: 8) {
            Text(L("custom.girOpportunity.preset"))
                .font(.subheadline)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Picker(L("custom.girOpportunity.preset"), selection: Binding(
                get: { field.girOpportunityPreset },
                set: { newValue in
                    guard let idx = draftConfig.fields.firstIndex(where: { $0.id == field.id }) else { return }
                    draftConfig.fields[idx].girOpportunityPreset = newValue
                    hasPendingChanges = true
                }
            )) {
                Text(L("common.yes")).tag(true)
                Text(L("common.no")).tag(false)
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .frame(minHeight: 44)
        .padding(.leading, 32)
        .disabled(!isEditing)
    }

    /// Switches one part of the intention on or off; the last one stays on.
    private func intentionToggle(_ part: IntentionPart, of field: CustomField) -> some View {
        let isOn = field.intentionParts.contains(part)
        let binding = Binding(
            get: { isOn },
            set: { on in
                guard let idx = draftConfig.fields.firstIndex(where: { $0.id == field.id }) else { return }
                var parts = draftConfig.fields[idx].intentionParts
                if on { parts.append(part) } else { parts.removeAll { $0 == part } }
                draftConfig.fields[idx].intentionParts = parts
                hasPendingChanges = true
            }
        )
        // Laid out by hand: the switch sets the row's height, so rows never
        // run into each other however the label wraps.
        return HStack(spacing: 8) {
            Image(systemName: part.icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 20)
            Text(L(part == .situation ? "intention.settings.situation" : part.titleKey))
                .font(.subheadline)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Toggle("", isOn: binding)
                .labelsHidden()
                .fixedSize()
                .tint(Theme.primary)
        }
        .frame(minHeight: 44)
        .padding(.leading, 32)
        .disabled(!isEditing || (isOn && field.intentionParts.count == 1))
    }

    private func fieldHeader(_ field: CustomField) -> some View {
        // The choice sits under the name, so editing — with its delete and
        // move controls taking width — never squeezes the name out.
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: field.kind.icon).foregroundStyle(Theme.primary).frame(width: 24)
                Text(L(field.kind.titleKey)).foregroundStyle(Theme.text).lineLimit(1)
                Spacer()
            }
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
                .padding(.leading, 32)
                .disabled(!isEditing)
            }
        }
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
