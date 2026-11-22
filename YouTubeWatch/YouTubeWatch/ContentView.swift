import SwiftUI
import AVKit

private let defaultInstance = "https://inv.nadeko.net"

struct VideoResult: Identifiable, Decodable {
    let videoId: String
    let title: String
    let author: String?
    let videoThumbnails: [Thumbnail]?

    var id: String { videoId }
    var thumbnailURL: URL? {
        guard let value = videoThumbnails?.first(where: { $0.quality == "medium" })?.url
                ?? videoThumbnails?.first?.url else { return nil }
        return URL(string: value)
    }
}

struct Thumbnail: Decodable {
    let url: String
    let quality: String?
}

struct VideoDetails: Decodable {
    let title: String
    let formatStreams: [Stream]?
    let adaptiveFormats: [Stream]?
}

struct Stream: Decodable {
    let url: String
    let type: String?
    let quality: String?
    let qualityLabel: String?
    let container: String?
}

@MainActor
final class YouTubeModel: ObservableObject {
    @Published var query = ""
    @Published var results: [VideoResult] = []
    @Published var selectedTitle = ""
    @Published var player: AVPlayer?
    @Published var isSearching = false
    @Published var message = "Search for a video"
    @Published var instance = defaultInstance

    func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { message = "Type a search"; return }
        isSearching = true
        message = "Searching…"
        defer { isSearching = false }

        do {
            var components = URLComponents(string: instance + "/api/v1/search")!
            components.queryItems = [URLQueryItem(name: "q", value: term),
                                     URLQueryItem(name: "type", value: "video")]
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 20
            request.setValue("YouTubeWatch/1.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            let found = try JSONDecoder().decode([VideoResult].self, from: data)
            results = Array(found.prefix(20))
            message = results.isEmpty ? "No videos found" : ""
        } catch {
            message = "Search failed. Try again later."
        }
    }

    func play(_ video: VideoResult) async {
        selectedTitle = video.title
        message = "Loading video…"
        do {
            let url = URL(string: instance + "/api/v1/videos/" + video.videoId)!
            var request = URLRequest(url: url)
            request.timeoutInterval = 25
            request.setValue("YouTubeWatch/1.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            let details = try JSONDecoder().decode(VideoDetails.self, from: data)

            let streams = (details.formatStreams ?? []) + (details.adaptiveFormats ?? [])
            let playable = streams.first {
                ($0.container == "mp4" || ($0.type?.contains("video/mp4") ?? false))
                && URL(string: $0.url) != nil
            } ?? streams.first { URL(string: $0.url) != nil }

            guard let stream = playable, let streamURL = URL(string: stream.url) else {
                message = "No playable stream found"
                return
            }

            let item = AVPlayerItem(url: streamURL)
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer
            newPlayer.play()
            message = ""
        } catch {
            message = "Couldn't load this video"
        }
    }
}

struct ContentView: View {
    @StateObject private var model = YouTubeModel()
    @State private var showingPlayer = false

    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                Text("YouTube Watch")
                    .font(.headline)
                    .foregroundColor(.red)

                HStack(spacing: 5) {
                    TextField("Search videos", text: $model.query)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        Task { await model.search() }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(model.isSearching)
                }

                if model.isSearching {
                    ProgressView()
                }

                if !model.message.isEmpty {
                    Text(model.message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }

                List(model.results) { video in
                    Button {
                        Task {
                            await model.play(video)
                            if model.player != nil { showingPlayer = true }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(video.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(2)
                            if let author = video.author {
                                Text(author)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .listStyle(.carousel)
            }
            .padding(.horizontal, 4)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingPlayer) {
                PlayerScreen(title: model.selectedTitle, player: model.player)
            }
        }
    }
}

struct PlayerScreen: View {
    let title: String
    let player: AVPlayer?
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let player = player {
                VideoPlayer(player: player)
                    .frame(maxHeight: 145)
            }

            HStack {
                Button {
                    if let player = player {
                        player.rate == 0 ? player.play() : player.pause()
                    }
                } label: {
                    Image(systemName: "playpause.fill")
                }
                Button {
                    player?.seek(to: .zero)
                    player?.play()
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                Button {
                    player?.pause()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .padding(8)
    }
}
