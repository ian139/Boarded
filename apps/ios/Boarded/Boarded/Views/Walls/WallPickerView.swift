import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct WallPickerView: View {
    @EnvironmentObject var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @ObservedObject var viewModel: WallsViewModel
    var onSelect: ((Wall) -> Void)? = nil
    var canSaveWallEdit: ((Wall, String, Data?) -> Bool)? = nil
    var navigationTitle = "Select Wall"
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var editingWall: Wall? = nil
    @State private var editName = ""
    @State private var editImageUrl = ""
    @State private var editPhotoItem: PhotosPickerItem?
    @State private var editImageData: Data? = nil
    @FocusState private var focusedField: WallField?

    var body: some View {
        let hasNewWallImage = viewModel.newWallImageData != nil
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                List {
                    Section("Walls") {
                        if viewModel.isLoading && viewModel.walls.isEmpty {
                            HStack(spacing: AppSpacing.space12) {
                                ProgressView()
                                Text("Loading walls")
                            }
                            .accessibilityElement(children: .combine)
                        } else if let error = viewModel.errorMessage, viewModel.walls.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.space8) {
                                Label("Unable to load walls", systemImage: "exclamationmark.triangle")
                                    .font(AppTypography.headline)
                                Text(error).font(AppTypography.body).foregroundStyle(AppColor.textSecondary)
                                Button("Try again") { Task { await viewModel.load(userId: session.userId) } }
                                    .frame(minHeight: AppLayout.minimumControlHeight)
                            }
                        } else if viewModel.walls.isEmpty {
                            Label("Add a wall below to start mapping routes.", systemImage: "square.3.layers.3d")
                                .foregroundStyle(AppColor.textSecondary)
                        }

                        ForEach(viewModel.walls) { wall in
                            Button {
                                viewModel.selectWall(id: wall.id)
                                onSelect?(wall)
                                dismiss()
                            } label: {
                                HStack(spacing: AppSpacing.space12) {
                                    wallThumbnail(urlString: wall.imageUrl)
                                    Text(wall.name)
                                        .font(AppTypography.body)
                                        .foregroundStyle(AppColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: AppSpacing.space8)
                                    if viewModel.selectedWallId == wall.id {
                                        if differentiateWithoutColor {
                                            Label("Selected", systemImage: "checkmark.circle.fill")
                                                .foregroundStyle(AppColor.accentDefault)
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppColor.accentDefault)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                }
                                .frame(minHeight: AppLayout.minimumControlHeight)
                                .contentShape(Rectangle())
                            }
                            .accessibilityLabel(wall.name)
                            .accessibilityValue(viewModel.selectedWallId == wall.id ? "Selected" : "Not selected")
                            .accessibilityHint("Selects this wall and closes the picker")
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if wall.userId == session.userId?.uuidString {
                                    Button("Edit") {
                                        editName = wall.name
                                        editImageUrl = wall.imageUrl ?? ""
                                        editImageData = nil
                                        editingWall = wall
                                    }
                                    .tint(AppColor.accentDefault)
                                    Button("Delete", role: .destructive) {
                                        Task { await viewModel.deleteWall(id: wall.id, userId: session.userId) }
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        TextField("Wall name", text: $viewModel.newWallName)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .imageURL }
                        TextField("Image URL (optional)", text: $viewModel.newWallImageUrl)
                            .focused($focusedField, equals: .imageURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label(hasNewWallImage ? "Change image" : "Choose image", systemImage: "photo")
                                .frame(minHeight: AppLayout.minimumControlHeight)
                        }
                        #if canImport(UIKit)
                        if let data = viewModel.newWallImageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 120)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                                .accessibilityLabel("Selected wall image")
                        }
                        #endif
                        Button {
                            Task { await viewModel.addWall(userId: session.userId) }
                        } label: {
                            Label("Add wall", systemImage: "plus")
                                .frame(maxWidth: .infinity, minHeight: AppLayout.minimumControlHeight)
                        }
                        .accessibilityIdentifier("Add Wall")
                        .disabled(viewModel.newWallName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } header: {
                        Text("Add wall")
                    } footer: {
                        Text("A photo helps identify the wall when drawing route geometry.")
                    }
                }
                .accessibilityIdentifier("Wall manager")
                .listStyle(.insetGrouped)
                .environment(\.defaultMinListRowHeight, AppLayout.minimumControlHeight)
                .scrollContentBackground(.hidden)
                .background(AppColor.backgroundBase)
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await viewModel.load(userId: session.userId)
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        viewModel.newWallImageData = data
                    }
                }
            }
            .sheet(item: $editingWall) { wall in
                editWallSheet(for: wall)
            }
        }
    }

    @ViewBuilder
    private func editWallSheet(for wall: Wall) -> some View {
        EditWallSheet(
            name: $editName,
            imageUrl: $editImageUrl,
            imageData: $editImageData,
            photoItem: $editPhotoItem,
            canSave: { canSaveEdit(for: wall) },
            onSave: {
                Task {
                    await viewModel.updateWall(
                        id: wall.id,
                        name: editName,
                        imageUrl: editImageUrl,
                        imageData: editImageData,
                        userId: session.userId
                    )
                    editingWall = nil
                }
            },
            onCancel: { editingWall = nil }
        )
    }

    private func canSaveEdit(for wall: Wall) -> Bool {
        canSaveWallEdit?(wall, editImageUrl, editImageData) ?? true
    }

    private func wallThumbnail(urlString: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColor.surface)
                .frame(width: 48, height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColor.border, lineWidth: 1)
                )
            if let normalized = normalizedRemoteImageURLString(urlString),
               let url = URL(string: normalized) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Color.clear
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Image("DefaultWall").resizable().scaledToFill()
                    @unknown default:
                        Color.clear
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image("DefaultWall")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

private enum WallField: Hashable {
    case name
    case imageURL
}

private struct EditWallSheet: View {
    @Binding var name: String
    @Binding var imageUrl: String
    @Binding var imageData: Data?
    @Binding var photoItem: PhotosPickerItem?
    let canSave: () -> Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                VStack(spacing: 12) {
                    TextField("Wall name", text: $name)
                        .accessibilityIdentifier("Edit wall name")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                                .stroke(AppColor.border, lineWidth: 1)
                        )

                    TextField("Image URL (optional)", text: $imageUrl)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadius)
                                .stroke(AppColor.border, lineWidth: 1)
                        )

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text(imageData == nil ? "Pick Image" : "Change Image")
                    }
                    #if canImport(UIKit)
                    if let data = imageData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 120)
                            .clipped()
                            .cornerRadius(AppLayout.cornerRadius)
                    }
                    #endif
                    if !canSave() {
                        Text("Clear the current route holds before replacing this wall image.")
                            .font(AppTypography.label)
                            .foregroundColor(AppColor.destructive)
                    }
                    Spacer()
                }
                .padding(AppLayout.horizontalPadding)
            }
            .navigationTitle("Edit Wall")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(!canSave())
                }
            }
            .onChange(of: photoItem) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }
}
