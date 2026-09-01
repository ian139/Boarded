import SwiftUI

struct LogClimbSheet: View {
    let route: Route
    let onSave: (String?, Int?, String?, Bool) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedGrade: String
    @State private var rating = 0
    @State private var notes = ""
    @State private var flashed = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var notesFocused: Bool

    init(route: Route, onSave: @escaping (String?, Int?, String?, Bool) async throws -> Void) {
        self.route = route
        self.onSave = onSave
        _selectedGrade = State(initialValue: route.gradeV ?? "V0")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                formPanel
                    .frame(maxWidth: AppLayout.contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppLayout.horizontalPadding)
                    .padding(.vertical, AppSpacing.space16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColor.backgroundBase.ignoresSafeArea())
            .navigationTitle("Log Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: AppLayout.minimumControlHeight, minHeight: AppLayout.minimumControlHeight)
                        .accessibilityInputLabels(["Cancel", "Close Log Send"])
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDragIndicator(.visible)
        .accessibilityAction(.escape) { dismiss() }
    }

    private var formPanel: some View {
        let panelShape = RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
        return VStack(alignment: .leading, spacing: AppSpacing.space20) {
            routeHeader
            Divider().overlay(AppColor.divider)

            fieldHeading("Your Grade Proposal")
            Picker("Your Grade Proposal", selection: $selectedGrade) {
                ForEach(VGradeOption.all) { option in Text(option.label).tag(option.label) }
            }
            .pickerStyle(.menu)
            .tint(AppColor.accentDefault)
            .frame(maxWidth: .infinity, minHeight: AppLayout.minimumControlHeight, alignment: .leading)
            .accessibilityValue(selectedGrade)

            Divider().overlay(AppColor.divider)
            fieldHeading("Rating")
            if dynamicTypeSize.isAccessibilitySize {
                Picker("Route Rating", selection: $rating) {
                    Text("No rating").tag(0)
                    ForEach(1...5, id: \.self) { Text("\($0) stars").tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: AppLayout.minimumControlHeight, alignment: .leading)
            } else {
                Picker("Route Rating", selection: $rating) {
                    Text("—").tag(0)
                    ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: AppLayout.minimumControlHeight)
            }

            Divider().overlay(AppColor.divider)
            Toggle(isOn: $flashed) {
                VStack(alignment: .leading, spacing: AppSpacing.space4) {
                    Text("Flashed (First Try)").font(AppTypography.headline).foregroundStyle(AppColor.textPrimary)
                    Text("Completed on your very first attempt").font(AppTypography.label).foregroundStyle(AppColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(AppColor.accentDefault)
            .frame(minHeight: AppLayout.minimumControlHeight)
            .accessibilityLabel("Flashed on first try")

            Divider().overlay(AppColor.divider)
            fieldHeading("Notes or Beta (Optional)")
            TextField("Add beta, hold feel, or conditions", text: $notes, axis: .vertical)
                .focused($notesFocused)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(3...8)
                .padding(AppSpacing.space12)
                .frame(minHeight: AppSpacing.space64, alignment: .topLeading)
                .boardedGlassSurface(in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous), interactive: true)
                .boardedFocusRing(isFocused: notesFocused, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .accessibilityLabel("Notes or beta")

            if let errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.label)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(AppSpacing.space12)
                    .background(AppColor.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .accessibilityLabel("Unable to save send. \(errorMessage)")
            }

            Button(action: save) {
                HStack(spacing: AppSpacing.space8) {
                    if isSaving { ProgressView().tint(AppColor.accentOnAccent) }
                    else { Image(systemName: "checkmark.circle.fill") }
                    Text(isSaving ? "Saving Send" : "Log Send")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(BoardedButtonStyle(.primary))
            .disabled(isSaving)
            .accessibilityLabel(isSaving ? "Saving send" : "Log send")
            .accessibilityHint("Saves this ascent")
            .accessibilityInputLabels(["Log Send", "Save Send"])
        }
        .padding(AppSpacing.space20)
        .boardedGlassSurface(in: panelShape)
    }

    @ViewBuilder
    private var routeHeader: some View {
        let grade = Text(route.gradeV ?? "—")
            .font(AppTypography.displayLarge)
            .foregroundStyle(AppColor.textPrimary)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Route grade \(route.gradeV ?? "unknown")")

        let details = VStack(alignment: .leading, spacing: AppSpacing.space4) {
            Text(route.name).font(AppTypography.title).foregroundStyle(AppColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            Text(route.userName ?? "Setter").font(AppTypography.label).foregroundStyle(AppColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.space8) { grade; details }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.space16) { grade; details }
        }
    }

    private func fieldHeading(_ title: String) -> some View {
        Text(title).font(AppTypography.headline).foregroundStyle(AppColor.textPrimary).fixedSize(horizontal: false, vertical: true)
    }

    private func save() {
        Task {
            isSaving = true
            errorMessage = nil
            defer { isSaving = false }
            do {
                try await onSave(selectedGrade, rating > 0 ? rating : nil, notes.trimmingCharacters(in: .whitespacesAndNewlines), flashed)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
