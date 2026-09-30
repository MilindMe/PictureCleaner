//
//  AssetImageView.swift
//  PictureCleaner
//
//  Created by Milind Meetarbhan on 2026-06-21.
//

import SwiftUI
import Photos
import AppKit

struct AssetImageView: View {
    let asset: PHAsset
    let targetSize: CGSize

    @State private var image: NSImage?
    @State private var requestID: PHImageRequestID?

    private let imageManager =
        PHCachingImageManager.default()

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView("Loading photo…")
                    .controlSize(.large)
            }
        }
        .task(id: asset.localIdentifier) {
            loadImage()
        }
        .onDisappear {
            cancelRequest()
        }
    }

    private func loadImage() {
        cancelRequest()

        image = nil

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        requestID = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { result, info in
            let wasCancelled =
                info?[PHImageCancelledKey] as? Bool ?? false

            let error =
                info?[PHImageErrorKey] as? Error

            guard !wasCancelled, error == nil else {
                return
            }

            guard let result else {
                return
            }

            Task { @MainActor in
                image = result
            }
        }
    }

    private func cancelRequest() {
        guard let requestID else {
            return
        }

        imageManager.cancelImageRequest(requestID)
        self.requestID = nil
    }
}
