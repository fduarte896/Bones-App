//
//  DemoGuide.swift
//  Bones
//
//  Created by Felipe Duarte on 13/03/26.
//

import SwiftUI

enum DemoGuideStep: Int, CaseIterable {
    case summary = 0
    case addPet = 1
    case detail = 2
    case upcoming = 3
    case health = 4
    case grooming = 5
    case weight = 6
    case done = 7
}

enum DemoGuideAnchor: Hashable {
    case dashboardHeader
    case addPetButton
    case detailButton
    case tabUpcoming
    case tabHealth
    case tabGrooming
    case tabWeight
}

struct DemoGuideAnchorKey: PreferenceKey {
    static var defaultValue: [DemoGuideAnchor: Anchor<CGRect>] = [:]

    static func reduce(value: inout [DemoGuideAnchor: Anchor<CGRect>], nextValue: () -> [DemoGuideAnchor: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func demoGuideAnchor(_ anchor: DemoGuideAnchor) -> some View {
        anchorPreference(key: DemoGuideAnchorKey.self, value: .bounds) { [anchor: $0] }
    }
}

struct DemoGuideOverlay: View {
    enum PresentationStyle {
        case auto
        case centered
    }

    let targetRect: CGRect
    let title: String
    let message: String
    let primaryActionTitle: String?
    let onPrimaryAction: (() -> Void)?
    let onSkip: () -> Void
    let presentationStyle: PresentationStyle

    @State private var bubbleSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let showBelow = targetRect.midY < proxy.size.height * 0.55
            let maxX = proxy.size.width - 140
            let minX: CGFloat = 140
            let defaultBubbleX = min(max(targetRect.midX, minX), maxX)
            let baseBubbleY = showBelow
                ? targetRect.maxY + 16 + bubbleSize.height / 2
                : targetRect.minY - 16 - bubbleSize.height / 2
            let proposedBubbleRect = CGRect(
                x: defaultBubbleX - bubbleSize.width / 2,
                y: baseBubbleY - bubbleSize.height / 2,
                width: bubbleSize.width,
                height: bubbleSize.height
            )
            let needsPush = proposedBubbleRect.intersects(targetRect)
            let pushDistance = targetRect.height / 2 + bubbleSize.height / 2 + 28
            let autoBubbleY = needsPush
                ? (showBelow ? targetRect.midY + pushDistance : targetRect.midY - pushDistance)
                : baseBubbleY

            let bubblePosition: CGPoint = {
                switch presentationStyle {
                case .auto:
                    return CGPoint(x: defaultBubbleX, y: autoBubbleY)
                case .centered:
                    return CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.55)
                }
            }()
            let bubbleX = bubblePosition.x
            let bubbleY = bubblePosition.y

            ZStack {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: 2)
                        .frame(width: targetRect.width + 10, height: targetRect.height + 10)
                        .position(x: targetRect.midX, y: targetRect.midY)
                }
                .allowsHitTesting(false)

                guideBubble
                    .frame(width: 280)
                    .background(
                        GeometryReader { bubbleProxy in
                            Color.clear
                                .preference(key: DemoGuideBubbleSizeKey.self, value: bubbleProxy.size)
                        }
                    )
                    .position(x: bubbleX, y: bubbleY)

            }
            .onPreferenceChange(DemoGuideBubbleSizeKey.self) { size in
                bubbleSize = size
            }
        }
        .transition(.opacity)
    }

    private var guideBubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Saltar guía", action: onSkip)
                    .font(.subheadline)

                Spacer()

                if let primaryActionTitle, let onPrimaryAction {
                    Button(primaryActionTitle, action: onPrimaryAction)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 18, x: 0, y: 6)
    }
}

private struct DemoGuideBubbleSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
