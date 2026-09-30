//
//  PhotoReviewViewModel.swift
//  PictureCleaner
//
//  Created by Milind Meetarbhan on 2026-06-21.
//

import Foundation
import Photos
import Combine

@MainActor
final class PhotoReviewViewModel: ObservableObject {
    enum LoadingState: Equatable {
        case idle
        case requestingPermission
        case loading
        case ready
        case noPhotos
        case deleting
        case completed
        case permissionDenied
        case failed(String)
    }

    enum Decision {
        case keep
        case delete
    }

    struct ReviewAction {
        let asset: PHAsset
        let decision: Decision
    }

    @Published private(set) var state: LoadingState = .idle
    @Published private(set) var photos: [PHAsset] = []
    @Published private(set) var pendingDeletion: [PHAsset] = []
    @Published private(set) var keptPhotos: [PHAsset] = []
    @Published private(set) var reviewedCount = 0

    @Published var numberOfPhotos = 12

    private let service: PhotoLibraryService
    private var history: [ReviewAction] = []

    private let reviewedIdentifiersKey =
        "reviewedPhotoLocalIdentifiers"

    init(
        service: PhotoLibraryService = .shared
    ) {
        self.service = service
    }

    var currentPhoto: PHAsset? {
        photos.first
    }

    var remainingCount: Int {
        photos.count
    }

    var canUndo: Bool {
        !history.isEmpty && state == .ready
    }

    var progressText: String {
        "\(reviewedCount) reviewed • \(remainingCount) remaining"
    }

    var deletionCount: Int {
        pendingDeletion.count
    }

    var keepCount: Int {
        keptPhotos.count
    }

    // MARK: - Loading

    func startReview() async {
        resetSession()
        state = .requestingPermission

        let authorization =
            await service.requestAuthorization()

        guard authorization == .authorized ||
              authorization == .limited
        else {
            state = .permissionDenied
            return
        }

        state = .loading

        let alreadyReviewed = loadReviewedIdentifiers()

        let selectedPhotos =
            service.fetchPhotosFromTodayInHistory(
                limit: numberOfPhotos,
                excluding: alreadyReviewed
            )

        photos = selectedPhotos

        state = selectedPhotos.isEmpty
            ? .noPhotos
            : .ready
    }

    private func resetSession() {
        photos = []
        pendingDeletion = []
        keptPhotos = []
        history = []
        reviewedCount = 0
    }

    // MARK: - Decisions

    func keepCurrentPhoto() {
        makeDecision(.keep)
    }

    func markCurrentPhotoForDeletion() {
        makeDecision(.delete)
    }

    private func makeDecision(_ decision: Decision) {
        guard state == .ready, let asset = photos.first else {
            return
        }

        photos.removeFirst()

        switch decision {
        case .keep:
            keptPhotos.append(asset)

        case .delete:
            pendingDeletion.append(asset)
        }

        history.append(
            ReviewAction(
                asset: asset,
                decision: decision
            )
        )

        reviewedCount += 1

        if photos.isEmpty {
            state = .completed
        }
    }

    // MARK: - Undo

    func undoLastDecision() {
        guard state == .ready || state == .completed else {
            return
        }

        guard let lastAction = history.popLast() else {
            return
        }

        switch lastAction.decision {
        case .keep:
            keptPhotos.removeAll {
                $0.localIdentifier ==
                lastAction.asset.localIdentifier
            }

        case .delete:
            pendingDeletion.removeAll {
                $0.localIdentifier ==
                lastAction.asset.localIdentifier
            }
        }

        photos.insert(lastAction.asset, at: 0)
        reviewedCount = max(0, reviewedCount - 1)
        state = .ready
    }

    // MARK: - Finish

    func finishReview() async {
        state = .deleting

        do {
            try await service.deleteAssets(pendingDeletion)

            let reviewedIdentifiers = Set(
                history.map {
                    $0.asset.localIdentifier
                }
            )

            saveReviewedIdentifiers(reviewedIdentifiers)
            state = .completed
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func finishWithoutDeleting() {
        let keptIdentifiers = Set(
            keptPhotos.map {
                $0.localIdentifier
            }
        )

        saveReviewedIdentifiers(keptIdentifiers)
        pendingDeletion.removeAll()
        state = .completed
    }

    func beginAnotherSession() async {
        await startReview()
    }

    // MARK: - Persistence

    private func loadReviewedIdentifiers() -> Set<String> {
        let values =
            UserDefaults.standard.stringArray(
                forKey: reviewedIdentifiersKey
            ) ?? []

        return Set(values)
    }

    private func saveReviewedIdentifiers(
        _ newIdentifiers: Set<String>
    ) {
        var existing = loadReviewedIdentifiers()
        existing.formUnion(newIdentifiers)

        UserDefaults.standard.set(
            Array(existing),
            forKey: reviewedIdentifiersKey
        )
    }

    func resetReviewHistory() {
        UserDefaults.standard.removeObject(
            forKey: reviewedIdentifiersKey
        )
    }
}
