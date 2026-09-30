//
//  PhotoCardView.swift
//  PictureCleaner
//
//  Created by Milind Meetarbhan on 2026-06-21.
//

import SwiftUI
import Photos

struct PhotoCardView: View {
    let asset: PHAsset
    let onKeep: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isAnimatingOut = false

    private let swipeThreshold: CGFloat = 140

    private var rotationAngle: Double {
        Double(dragOffset.width / 30)
    }

    private var keepOpacity: Double {
        min(
            max(Double(dragOffset.width / swipeThreshold), 0),
            1
        )
    }

    private var deleteOpacity: Double {
        min(
            max(Double(-dragOffset.width / swipeThreshold), 0),
            1
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.black)

                AssetImageView(
                    asset: asset,
                    targetSize: CGSize(
                        width: geometry.size.width * 2,
                        height: geometry.size.height * 2
                    )
                )
                .padding(12)

                decisionOverlays

                VStack {
                    Spacer()

                    photoInformation
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 24)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(0.25),
                radius: 20,
                x: 0,
                y: 10
            )
            .offset(dragOffset)
            .rotationEffect(.degrees(rotationAngle))
            .gesture(dragGesture)
            .animation(
                .interactiveSpring(
                    response: 0.35,
                    dampingFraction: 0.75
                ),
                value: dragOffset
            )
        }
    }

    private var decisionOverlays: some View {
        ZStack {
            VStack {
                HStack {
                    decisionLabel(
                        title: "DELETE",
                        systemImage: "trash.fill"
                    )
                    .foregroundStyle(.red)
                    .opacity(deleteOpacity)

                    Spacer()
                }

                Spacer()
            }
            .padding(32)

            VStack {
                HStack {
                    Spacer()

                    decisionLabel(
                        title: "KEEP",
                        systemImage: "heart.fill"
                    )
                    .foregroundStyle(.green)
                    .opacity(keepOpacity)
                }

                Spacer()
            }
            .padding(32)
        }
    }

    private func decisionLabel(
        title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title2.bold())
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.black.opacity(0.7))
            .clipShape(Capsule())
    }

    private var photoInformation: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedDate)
                    .font(.headline)

                Text(photoDimensions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .foregroundStyle(.white)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isAnimatingOut else {
                    return
                }

                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isAnimatingOut else {
                    return
                }

                if value.translation.width > swipeThreshold {
                    animateOut(direction: 1, completion: onKeep)
                } else if value.translation.width < -swipeThreshold {
                    animateOut(direction: -1, completion: onDelete)
                } else {
                    dragOffset = .zero
                }
            }
    }

    private func animateOut(
        direction: CGFloat,
        completion: @escaping () -> Void
    ) {
        isAnimatingOut = true

        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = CGSize(
                width: direction * 1_200,
                height: dragOffset.height
            )
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.22
        ) {
            completion()
            dragOffset = .zero
            isAnimatingOut = false
        }
    }

    private var formattedDate: String {
        guard let date = asset.creationDate else {
            return "Unknown date"
        }

        return date.formatted(
            date: .long,
            time: .omitted
        )
    }

    private var photoDimensions: String {
        "\(asset.pixelWidth) × \(asset.pixelHeight)"
    }
}
