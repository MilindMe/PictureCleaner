//
//  PhotoLibraryService.swift
//  PictureCleaner
//
//  Created by Milind Meetarbhan on 2026-06-21.
//

import Foundation
import Photos

enum PhotoLibraryError: LocalizedError {
    case accessDenied
    case deletionFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photo library access was denied. You can enable access in System Settings."
        case .deletionFailed(let message):
            return "The selected photos could not be deleted: \(message)"
        }
    }
}

final class PhotoLibraryService {
    static let shared = PhotoLibraryService()

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> PHAuthorizationStatus {
        let currentStatus =
            PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if currentStatus != .notDetermined {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Fetching

    func fetchPhotosFromTodayInHistory(
        limit: Int,
        excluding identifiers: Set<String>
    ) -> [PHAsset] {
        let calendar = Calendar.current
        let today = Date()

        let currentMonth = calendar.component(.month, from: today)
        let currentDay = calendar.component(.day, from: today)

        let options = PHFetchOptions()

        // Newest first before the final random selection.
        options.sortDescriptors = [
            NSSortDescriptor(
                key: "creationDate",
                ascending: false
            )
        ]

        let fetchResult = PHAsset.fetchAssets(
            with: .image,
            options: options
        )

        var matchingAssets: [PHAsset] = []

        fetchResult.enumerateObjects { asset, _, _ in
            guard
                let creationDate = asset.creationDate,
                !identifiers.contains(asset.localIdentifier)
            else {
                return
            }

            let month = calendar.component(
                .month,
                from: creationDate
            )

            let day = calendar.component(
                .day,
                from: creationDate
            )

            guard month == currentMonth, day == currentDay else {
                return
            }

            matchingAssets.append(asset)
        }

        return Array(
            matchingAssets
                .shuffled()
                .prefix(limit)
        )
    }

    // MARK: - Deletion

    func deleteAssets(_ assets: [PHAsset]) async throws {
        guard !assets.isEmpty else {
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    let message =
                        error?.localizedDescription
                        ?? "Unknown Photos library error."

                    continuation.resume(
                        throwing: PhotoLibraryError.deletionFailed(message)
                    )
                }
            }
        }
    }
}
