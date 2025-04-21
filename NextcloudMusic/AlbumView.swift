//
//  AlbumView.swift
//  NextcloudMusic
//
//  Created by agustin on 21/4/25.
//

import SwiftUI
import AVFoundation

struct AlbumView: View {
  let folder: Folder
  @State private var tracks: [URL] = []
  @State private var subfolders: [Folder]? = nil

  @State private var player: AVPlayer? = nil
  @State private var isPlaying = false
  @State private var currentTime: Double = 0
  @State private var duration: Double = 1
  @State private var timer: Timer? = nil

  var body: some View {
    VStack {
      if let folders = subfolders {
        List(folders) { folder in
          NavigationLink(destination: AlbumView(folder: folder)) {
            Text(folder.name)
          }
        }
      } else {
        List(tracks, id: \.self) { track in
          Button {
            play(track)
          } label: {
            Text(track.lastPathComponent)
          }
        }
        if player != nil {
          Slider(value: $currentTime, in: 0...duration, onEditingChanged: { editing in
            if !editing, let p = player {
              p.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600))
            }
          })
          HStack {
            Text(formatTime(currentTime))
            Spacer()
            Text(formatTime(duration))
          }
          Button {
            guard let p = player else { return }
            if isPlaying { p.pause() } else { p.play() }
            isPlaying.toggle()
          } label: {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
              .font(.title)
          }
          .padding(.top, 8)
          .padding(.horizontal)
        }
      }
    }
    .navigationTitle(folder.name)
    .onAppear { loadTracks() }
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

        let base = folder.url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)! + "/"

        var folders: [Folder] = []
        var files: [URL] = []

        for href in allEntries {
          if href.hasPrefix(base), href != base {
            let decoded = href.removingPercentEncoding ?? href
            let name = decoded
              .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
              .components(separatedBy: "/").last ?? "?"
            let fullURL = URL(string: "https://cloud.ag.uy" + decoded)!

            if href.hasSuffix("/") {
              folders.append(Folder(name: name, url: fullURL))
            } else if !name.hasPrefix("._"),
                      name.hasSuffix(".mp3") || name.hasSuffix(".m4a") || name.hasSuffix(".ogg") {
              files.append(fullURL)
            }
          }
        }

        DispatchQueue.main.async {
          subfolders = folders.isEmpty ? nil : folders
          tracks = folders.isEmpty ? files : []
        }
      }.resume()
    }


  func play(_ url: URL) {
    timer?.invalidate()
    let item = AVPlayerItem(url: url)
    player = AVPlayer(playerItem: item)
    player?.play()
    isPlaying = true

      Task {
        do {
          let durationCMTime = try await item.asset.load(.duration)
          let secs = durationCMTime.seconds
          if secs.isFinite {
            duration = secs
          }
        } catch {
          print("Failed to load duration:", error)
        }
      }

    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
      currentTime = player?.currentTime().seconds ?? 0
    }
  }

  func formatTime(_ seconds: Double) -> String {
    let m = Int(seconds) / 60
    let s = Int(seconds) % 60
    return String(format: "%d:%02d", m, s)
  }
}
