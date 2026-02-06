import SwiftUI

/// Cinematic still image header for episode detail view
private struct EpisodeStillHeaderView: View {
    let episode: TVEpisodeMetadata

    @EnvironmentObject private var metadataService: MetadataService

    #if os(iOS)
    private var headerHeight: CGFloat { UIScreen.main.bounds.height * 0.35 }
    #elseif os(tvOS)
    private var headerHeight: CGFloat { UIScreen.main.bounds.height * 0.40 }
    #endif

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                stillImage
                    .frame(width: geometry.size.width, height: headerHeight)
                    .clipped()

                gradientOverlay
            }
        }
        .frame(height: headerHeight)
    }

    @ViewBuilder
    private var stillImage: some View {
        if let localURL = metadataService.stillURL(for: episode.id, size: .row) {
            AsyncImage(url: localURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty:
                    placeholderView
                        .overlay { ProgressView() }
                case .failure:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else if let stillPath = episode.stillPath,
                  let url = TMDbService.stillURL(path: stillPath, size: .w300) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty:
                    placeholderView
                        .overlay { ProgressView() }
                case .failure:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
            }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.4),
                .init(color: .black.opacity(0.7), location: 0.75),
                .init(color: .black, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Apple TV app-style episode detail view with cinematic still header and glass buttons
struct EpisodeDetailView: View {
    let episode: TVEpisodeMetadata
    let showName: String
    let onPlay: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var metadataService: MetadataService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Cinematic still image
                    EpisodeStillHeaderView(episode: episode)

                    // Centered content below still
                    VStack(spacing: 16) {
                        titleSection
                        episodeLabel
                        buttonRow
                        synopsisSection
                        metadataInfoRow
                    }
                    #if os(iOS)
                    .padding(.horizontal, 20)
                    #elseif os(tvOS)
                    .padding(.horizontal, 80)
                    #endif
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color.black)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #elseif os(tvOS)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(episode.name)
            #if os(iOS)
            .font(.title.bold())
            #elseif os(tvOS)
            .font(.largeTitle.bold())
            #endif
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Episode Label

    private var episodeLabel: some View {
        Text("\(episode.formattedEpisode) \u{00B7} \(showName)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Button Row

    private var buttonRow: some View {
        HStack(spacing: 16) {
            Button(action: onPlay) {
                Label("Play Episode", systemImage: "play.fill")
                    .font(.headline)
            }
            .buttonStyle(.adaptiveGlassProminent)

            Button {
                // Secondary action placeholder
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.adaptiveGlassCircle)
        }
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Synopsis

    @ViewBuilder
    private var synopsisSection: some View {
        if let overview = episode.overview, !overview.isEmpty {
            ExpandableText(text: overview, lineLimit: 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
    }

    // MARK: - Metadata Info Row (Air Date, Runtime, Rating)

    @ViewBuilder
    private var metadataInfoRow: some View {
        let parts = metadataComponents
        if !parts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Text("\u{00B7}")
                            .foregroundStyle(.secondary)
                    }
                    part
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private var metadataComponents: [AnyView] {
        var components: [AnyView] = []

        if let airDate = episode.formattedAirDate {
            components.append(AnyView(Text(airDate)))
        }

        if let runtime = episode.formattedRuntime {
            components.append(AnyView(Text(runtime)))
        }

        if let rating = episode.voteAverage, rating > 0 {
            components.append(AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                }
            ))
        }

        return components
    }
}

#Preview {
    let episode = TVEpisodeMetadata(
        id: UUID(),
        seriesTmdbId: 1399,
        seasonNumber: 1,
        episodeNumber: 1,
        name: "Winter Is Coming",
        overview: "Lord Eddard Stark is summoned to court by his old friend, King Robert Baratheon, to serve as Hand of the King. Meanwhile, across the Narrow Sea, the exiled Targaryen siblings plot to reclaim the Iron Throne.",
        stillPath: "/wrGWeW4WKxnaeA8sxJb2T9O6ryo.jpg",
        airDate: Date(),
        runtime: 62,
        voteAverage: 8.3
    )

    return EpisodeDetailView(
        episode: episode,
        showName: "Game of Thrones"
    ) {
        print("Play")
    }
    .environmentObject(MetadataService())
}
