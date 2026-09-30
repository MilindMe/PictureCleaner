//
//  ContentView.swift
//  PictureCleaner
//
//  Created by Milind Meetarbhan on 2026-06-21.
//

import SwiftUI
import Photos
import AppKit

struct ContentView: View {
    @StateObject private var viewModel =
        PhotoReviewViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                background

                content
                    .padding(28)
            }
            .navigationTitle("On This Day")
            .toolbar {
                toolbarContent
            }
        }
        .task {
            if viewModel.state == .idle {
                await viewModel.startReview()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle,
             .requestingPermission,
             .loading:

            loadingView

        case .ready:
            reviewView

        case .noPhotos:
            noPhotosView

        case .permissionDenied:
            permissionDeniedView

        case .deleting:
            deletingView

        case .completed:
            completedView

        case .failed(let message):
            errorView(message: message)
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .underPageBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Review

    private var reviewView: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photos from this day")
                        .font(.title2.bold())

                    Text(viewModel.progressText)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(
                    "\(viewModel.deletionCount) marked",
                    systemImage: "trash"
                )
                .foregroundStyle(
                    viewModel.deletionCount > 0
                    ? .red
                    : .secondary
                )
            }

            ZStack {
                cardBackground(offset: 18, opacity: 0.15)
                cardBackground(offset: 9, opacity: 0.25)

                if let photo = viewModel.currentPhoto {
                    PhotoCardView(
                        asset: photo,
                        onKeep: {
                            viewModel.keepCurrentPhoto()
                        },
                        onDelete: {
                            viewModel.markCurrentPhotoForDeletion()
                        }
                    )
                    .id(photo.localIdentifier)
                }
            }
            .frame(maxWidth: 620, maxHeight: 500)

            reviewButtons

            Text("Swipe left to delete • Swipe right to keep")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func cardBackground(
        offset: CGFloat,
        opacity: Double
    ) -> some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(.secondary.opacity(opacity))
            .offset(y: offset)
            .scaleEffect(1 - offset / 500)
    }

    private var reviewButtons: some View {
        HStack(spacing: 28) {
            Button {
                viewModel.markCurrentPhotoForDeletion()
            } label: {
                actionButton(
                    title: "Delete",
                    systemImage: "trash.fill",
                    color: .red
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button {
                viewModel.undoLastDecision()
            } label: {
                actionButton(
                    title: "Undo",
                    systemImage: "arrow.uturn.backward",
                    color: .secondary
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canUndo)
            .keyboardShortcut("z", modifiers: .command)

            Button {
                viewModel.keepCurrentPhoto()
            } label: {
                actionButton(
                    title: "Keep",
                    systemImage: "heart.fill",
                    color: .green
                )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 54, height: 54)
                .background(color.opacity(0.15))
                .foregroundStyle(color)
                .clipShape(Circle())

            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Completion

    private var completedView: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("Review complete")
                .font(.largeTitle.bold())

            Text(
                "\(viewModel.keepCount) kept and " +
                "\(viewModel.deletionCount) marked for deletion."
            )
            .foregroundStyle(.secondary)

            if viewModel.deletionCount > 0 {
                Button {
                    Task {
                        await viewModel.finishReview()
                    }
                } label: {
                    Label(
                        "Delete \(viewModel.deletionCount) Photos",
                        systemImage: "trash"
                    )
                    .frame(minWidth: 220)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button("Cancel deletion") {
                    viewModel.finishWithoutDeleting()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Review another group") {
                    Task {
                        await viewModel.beginAnotherSession()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if viewModel.canUndo {
                Button("Undo last decision") {
                    viewModel.undoLastDecision()
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 520)
    }

    // MARK: - Other states

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text(
                viewModel.state == .requestingPermission
                ? "Requesting Photos access…"
                : "Finding photos from this day…"
            )
            .foregroundStyle(.secondary)
        }
    }

    private var deletingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("Updating your Photos library…")
                .foregroundStyle(.secondary)
        }
    }

    private var noPhotosView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 68))
                .foregroundStyle(.secondary)

            Text("No photos to review")
                .font(.largeTitle.bold())

            Text(
                "There are no unreviewed photos from this " +
                "calendar date in your library."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Button("Include previously reviewed photos") {
                viewModel.resetReviewHistory()

                Task {
                    await viewModel.startReview()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: 480)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Photos access is required")
                .font(.largeTitle.bold())

            Text(
                "Allow this app to access your Photos library " +
                "in System Settings → Privacy & Security → Photos."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Button("Open System Settings") {
                openPhotosPrivacySettings()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: 520)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.largeTitle.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Try again") {
                Task {
                    await viewModel.startReview()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: 520)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Picker(
                    "Photos per session",
                    selection: $viewModel.numberOfPhotos
                ) {
                    ForEach(10...15, id: \.self) { number in
                        Text("\(number) photos")
                            .tag(number)
                    }
                }

                Divider()

                Button("Reset reviewed-photo history") {
                    viewModel.resetReviewHistory()
                }
            } label: {
                Label("Options", systemImage: "slider.horizontal.3")
            }
        }
    }

    private func openPhotosPrivacySettings() {
        guard let url = URL(
            string:
                "x-apple.systempreferences:" +
                "com.apple.preference.security?Privacy_Photos"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
