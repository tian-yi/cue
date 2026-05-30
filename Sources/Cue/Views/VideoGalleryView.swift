import SwiftUI

struct VideoGalleryView: View {
    let videos: [VideoSummary]
    let selectedVideoID: String?
    let accessory: (VideoSummary) -> String?
    let action: (VideoSummary) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 236, maximum: 340), spacing: 22, alignment: .top)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
                ForEach(videos) { video in
                    Button {
                        action(video)
                    } label: {
                        VideoGalleryCard(
                            video: video,
                            accessory: accessory(video),
                            isSelected: selectedVideoID == video.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
    }
}

struct VideoGalleryCard: View {
    let video: VideoSummary
    var accessory: String?
    var isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(video.channelTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                metadata
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(isHovering ? 1.015 : 1)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .onHover { isHovering = $0 }
    }

    private var thumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: video.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                        }
                case .empty:
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            ProgressView()
                                .controlSize(.small)
                        }
                @unknown default:
                    Rectangle().fill(.quaternary)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipped()

            HStack(alignment: .bottom) {
                if let accessory {
                    Text(accessory)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.72), in: Capsule())
                }

                Spacer(minLength: 8)

                Text(video.displayDuration)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 5))
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        }
        .shadow(color: .black.opacity(isHovering ? 0.18 : 0.08), radius: isHovering ? 12 : 4, y: isHovering ? 5 : 2)
    }

    private var metadata: some View {
        HStack(spacing: 6) {
            if !AppFormatters.compactCount(video.viewCount).isEmpty {
                Text("\(AppFormatters.compactCount(video.viewCount)) views")
            }

            if accessory == "Ready" || accessory == "Best Ready" {
                Text("Downloaded")
            } else if accessory == "Preview" || accessory == "Upgrading" {
                Text(accessory == "Upgrading" ? "Upgrading quality" : "Streaming preview")
            } else {
                Text("Download to play")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}
