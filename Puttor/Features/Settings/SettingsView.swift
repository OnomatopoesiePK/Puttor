//
//  SettingsView.swift
//  Puttor
//
//  Tab 4 root. Ported from (tabs)/settings.tsx, plus the language picker
//  (DE/EN, default EN) driving LocalizationManager.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Putter.name) private var putters: [Putter]

    @AppStorage(AppStorageKeys.units) private var unitsPref: String = "metric"
    @AppStorage(AppStorageKeys.haptics) private var hapticsEnabled: Bool = true
    @AppStorage(AppStorageKeys.defaultFirstPuttDistance) private var defaultDistance: Double = 5.0
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var addingPutter = false
    @State private var newPutterName = ""
    @State private var putterToDelete: Putter?

    private var useFeet: Bool { unitsPref == "imperial" }

    private var defaultDistanceDisplay: Binding<Double> {
        Binding(
            get: { useFeet ? UnitConverter.metresToFeet(defaultDistance).rounded() : defaultDistance },
            set: { newValue in defaultDistance = useFeet ? UnitConverter.feetToMetres(newValue) : newValue }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sectionHeader(L("settings.appearance"))
                    HStack(spacing: 10) {
                        appearanceButton(L("settings.dark"), icon: "moon.fill", active: themeManager.appearance == .dark) { themeManager.setAppearance(.dark) }
                        appearanceButton(L("settings.light"), icon: "sun.max.fill", active: themeManager.appearance == .light) { themeManager.setAppearance(.light) }
                    }
                    .padding(.bottom, 8)

                    sectionHeader(L("settings.language"))
                    HStack(spacing: 10) {
                        langButton("English", code: "en")
                        langButton("Deutsch", code: "de")
                    }
                    .padding(.bottom, 8)

                    sectionHeader(L("settings.units"))
                    HStack(spacing: 10) {
                        unitButton(L("settings.metres"), emoji: "📏", active: unitsPref == "metric") { unitsPref = "metric" }
                        unitButton(L("settings.feet"), emoji: "🦶", active: unitsPref == "imperial") { unitsPref = "imperial" }
                    }
                    .padding(.bottom, 8)

                    sectionHeader(L("settings.defaultDistance"))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(useFeet
                             ? String(format: L("settings.defaultDistance.value.ft"), defaultDistanceDisplay.wrappedValue)
                             : String(format: L("settings.defaultDistance.value"), defaultDistance))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Slider(value: defaultDistanceDisplay, in: useFeet ? 3...50 : 1...15, step: useFeet ? 1 : 0.5)
                            .tint(Theme.primary)
                    }
                    .padding(Theme.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                    .padding(.bottom, 8)

                    sectionHeader(L("settings.inputMode"))
                    NavigationLink {
                        CustomModeSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3").foregroundStyle(Theme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("settings.customMode")).foregroundStyle(Theme.text)
                                Text(L("settings.customMode.desc")).font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
                        }
                        .padding(Theme.Spacing.md)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)

                    sectionHeader(L("settings.feedback"))
                    Toggle(isOn: $hapticsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("settings.haptics")).foregroundStyle(Theme.text)
                            Text(L("settings.haptics.desc")).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .tint(Theme.primary)
                    .padding(Theme.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                    .padding(.bottom, 8)

                    sectionHeader(L("settings.myPutters"))
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(putters) { p in
                            HStack {
                                Text("🏌️")
                                Text(p.name).foregroundStyle(Theme.text)
                                Spacer()
                                Button {
                                    putterToDelete = p
                                } label: {
                                    Text("✕").foregroundStyle(Theme.error)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .overlay(Rectangle().fill(Theme.borderLight).frame(height: 1), alignment: .bottom)
                        }

                        if addingPutter {
                            HStack {
                                TextField(L("setup.putterNamePlaceholder"), text: $newPutterName)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(Theme.card))
                                    .foregroundStyle(Theme.text)
                                Button(L("common.add")) {
                                    let name = newPutterName.trimmingCharacters(in: .whitespaces)
                                    guard !name.isEmpty else { return }
                                    modelContext.insert(Putter(name: name))
                                    try? modelContext.save()
                                    newPutterName = ""
                                    addingPutter = false
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.primary)
                                Button("✕") { addingPutter = false; newPutterName = "" }
                                    .foregroundStyle(Theme.textMuted)
                            }
                        } else {
                            Button("+ \(L("setup.addPutter"))") { addingPutter = true }
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                    .padding(.bottom, 8)

                    sectionHeader(L("settings.reference"))
                    NavigationLink {
                        StatsReferenceView()
                    } label: {
                        HStack {
                            Image(systemName: "function").foregroundStyle(Theme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("reference.title")).foregroundStyle(Theme.text)
                                Text(L("settings.reference.desc")).font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
                        }
                        .padding(Theme.Spacing.md)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md).stroke(Theme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, 40)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                ScreenTitle(text: L("settings.title"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .screenHeaderPadding()
                    .background(Theme.background)
            }
            .alert(L("settings.deletePutterTitle"), isPresented: Binding(get: { putterToDelete != nil }, set: { if !$0 { putterToDelete = nil } })) {
                Button(L("common.cancel"), role: .cancel) {}
                Button(L("onCourse.delete"), role: .destructive) {
                    if let p = putterToDelete {
                        modelContext.delete(p)
                        try? modelContext.save()
                    }
                }
            } message: {
                Text(putterToDelete.map { String(format: L("settings.deletePutterMessage"), $0.name) } ?? "")
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.4)
            .foregroundStyle(Theme.textMuted)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }

    private func langButton(_ title: String, code: String) -> some View {
        let active = localization.languageCode == code
        return Button {
            localization.setLanguage(code)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(active ? Theme.primary : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(active ? Theme.primary.opacity(0.13) : Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(active ? Theme.primary : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func appearanceButton(_ title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(active ? Theme.primary : Theme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(active ? Theme.primary.opacity(0.13) : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(active ? Theme.primary : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func unitButton(_ title: String, emoji: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji)
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(active ? Theme.primary : Theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm).fill(active ? Theme.primary.opacity(0.13) : Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(active ? Theme.primary : Theme.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
