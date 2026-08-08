import PhotosUI
import SwiftData
import SwiftUI

private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

/// The Sticker tab's two subsections live here: creating a new sticker (camera or photo library,
/// via the toolbar "+" button) and browsing the cached gallery of previously-made stickers (the
/// grid itself).
struct StickerListView: View {
    @State private var viewModel: StickerListViewModel
    @Query(sort: \Sticker.createdAtMillis, order: .reverse) private var stickers: [Sticker]

    @State private var isSourceDialogPresented = false
    @State private var isCameraPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var editingImage: UIImage?
    @State private var isEditorPresented = false

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: StickerListViewModel(repository: container.stickerRepository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if stickers.isEmpty {
                    ContentUnavailableView(
                        "No Stickers Yet",
                        systemImage: "face.smiling",
                        description: Text("Tap + to create one from a photo.")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(stickers) { sticker in
                            StickerThumbnail(image: viewModel.images[sticker.id])
                                .onAppear { viewModel.loadImageIfNeeded(for: sticker) }
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        viewModel.delete(sticker)
                                    }
                                }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Stickers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSourceDialogPresented = true
                    } label: {
                        Label("New Sticker", systemImage: "plus")
                    }
                }
            }
            .confirmationDialog("New Sticker", isPresented: $isSourceDialogPresented, titleVisibility: .visible) {
                Button("Take Photo") { isCameraPresented = true }
                Button("Choose from Library") { isPhotoPickerPresented = true }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $isCameraPresented) {
                CameraCaptureView(
                    onCapture: { image in
                        isCameraPresented = false
                        editingImage = image
                        isEditorPresented = true
                    },
                    onCancel: { isCameraPresented = false }
                )
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)
            .task(id: selectedPhotoItem) {
                guard let selectedPhotoItem else { return }
                defer { self.selectedPhotoItem = nil }
                if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self),
                    let image = UIImage(data: data)
                {
                    editingImage = image
                    isEditorPresented = true
                }
            }
            .fullScreenCover(isPresented: $isEditorPresented) {
                if let editingImage {
                    NavigationStack {
                        StickerEditorView(image: editingImage, container: container)
                    }
                }
            }
        }
    }
}

private struct StickerThumbnail: View {
    let image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(6)
            } else {
                ProgressView()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
