import SwiftUI
import AVFoundation
import MediaPlayer

struct Track: Identifiable {
  let id = UUID()
  let url: URL
  var title: String
  var artist: String
}

struct AlbumView: View {
  let folder: Folder
  @State private var subfolders: [Folder]? = nil
  @State private var tracks: [Track] = []

  @State private var player = AVQueuePlayer()
  @State private var currentIndex = 0
  @State private var isPlaying = false
  @State private var currentTime: Double = 0
  @State private var duration: Double = 0
  @State private var timer: Timer? = nil

  var body: some View {
    VStack {
      if let folders = subfolders {
        List(folders) { f in
          NavigationLink(destination: AlbumView(folder: f)) {
            Text(f.name)
          }
        }
      } else {
        List(tracks.indices, id: \.self) { idx in
          let track = tracks[idx]
          Button {
            play(at: idx)
          } label: {
            VStack(alignment: .leading) {
              Text(track.title)
              if !track.artist.isEmpty {
                Text(track.artist)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
            }
          }
        }
        if player.currentItem != nil {
          Slider(value: $currentTime, in: 0...duration, onEditingChanged: { editing in
            if !editing {
              player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
            }
          })
          HStack {
            Text(formatTime(currentTime))
            Spacer()
            Text(formatTime(duration))
          }
          HStack {
            Button(action: skipPrev) {
              Image(systemName: "backward.fill").font(.title)
            }
            Spacer()
            Button {
              if isPlaying { player.pause() } else { player.play() }
              isPlaying.toggle()
            } label: {
              Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.title)
            }
            Spacer()
            Button(action: skipNext) {
              Image(systemName: "forward.fill").font(.title)
            }
          }
          .padding(.top, 8)
          .padding(.horizontal)
        }
      }
    }
    .navigationTitle(folder.name)
    .onAppear {
      loadTracks()
      setupRemoteCommands()
    }
  }

  func loadTracks() {
    var request = URLRequest(url: folder.url)
    request.httpMethod = "PROPFIND"
    request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
    request.setValue("1", forHTTPHeaderField: "Depth")

    let login = "\(Config.username):\(Config.password)"
    let creds = login.data(using: .utf8)!.base64EncodedString()
    request.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")

    URLSession.shared.dataTask(with: request) { data, _, _ in
      guard let data = data,
            let xml = String(data: data, encoding: .utf8) else { return }

      let allEntries = xml
        .components(separatedBy: "<d:href>")
        .compactMap { $0.components(separatedBy: "</d:href>").first }
        .dropFirst()

      let base = folder.url.path
        .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        + "/"

      var folders: [Folder] = []
      var temp: [Track] = []

      for href in allEntries {
        guard href.hasPrefix(base), href != base else { continue }
        let decoded = href.removingPercentEncoding ?? href
        let name = decoded
          .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
          .components(separatedBy: "/").last ?? ""
        guard !name.hasPrefix("._") else { continue }
        let fullURL = URL(string: "https://cloud.ag.uy" + decoded)!

        if href.hasSuffix("/") {
          folders.append(Folder(name: name, url: fullURL))
        } else if let ext = name.split(separator: ".").last?.lowercased(),
                  ["mp3","m4a","ogg"].contains(ext) {
          var track = Track(url: fullURL, title: name, artist: "")
          temp.append(track)

          Task {
            do {
              let asset = AVURLAsset(url: fullURL)
              let items = try await asset.load(.commonMetadata)
              if let tItem = items.first(where: { $0.commonKey == .commonKeyTitle }),
                 let t = try await tItem.load(.stringValue) {
                track.title = t
              }
              if let aItem = items.first(where: { $0.commonKey == .commonKeyArtist }),
                 let a = try await aItem.load(.stringValue) {
                track.artist = a
              }
              DispatchQueue.main.async {
                if let i = temp.firstIndex(where: { $0.id == track.id }) {
                  temp[i] = track
                  tracks = temp
                }
              }
            } catch { }
          }
        }
      }

        DispatchQueue.main.async {
          if folders.isEmpty {
            subfolders = nil
            tracks     = temp
          } else {
            subfolders = folders
            tracks     = []
          }
        }

    }.resume()
  }

  func play(at index: Int) {
    timer?.invalidate()
    player.pause()
    player.removeAllItems()

    for i in index..<tracks.count {
      let item = AVPlayerItem(url: tracks[i].url)
      player.insert(item, after: nil)
    }

    currentIndex = index
    isPlaying    = true
    player.play()


    var info: [String: Any] = [
      MPMediaItemPropertyTitle:  tracks[index].title,
      MPMediaItemPropertyArtist: tracks[index].artist
    ]
      info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info


    Task {
      let dur = try await player.currentItem?.asset.load(.duration)
      if let d = dur?.seconds, d.isFinite {
        duration = d
          info[MPMediaItemPropertyPlaybackDuration] = d
          info[MPNowPlayingInfoPropertyPlaybackRate]    = 1.0
          MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      }
    }

    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
      let t = player.currentTime().seconds
      currentTime = t
      MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = t
    }
  }

  func skipNext() {
    let next = currentIndex + 1
    guard next < tracks.count else { return }
    play(at: next)
  }

  func skipPrev() {
    let prev = currentIndex - 1
    guard prev >= 0 else { return }
    play(at: prev)
  }

  func setupRemoteCommands() {
    let cc = MPRemoteCommandCenter.shared()
    cc.nextTrackCommand.removeTarget(nil)
    cc.previousTrackCommand.removeTarget(nil)
    cc.nextTrackCommand.addTarget { _ in skipNext(); return .success }
    cc.previousTrackCommand.addTarget { _ in skipPrev(); return .success }
  }

  func formatTime(_ seconds: Double) -> String {
    let m = Int(seconds) / 60
    let s = Int(seconds) % 60
    return String(format: "%d:%02d", m, s)
  }
}
