//
//  NextcloudMusicApp.swift
//  NextcloudMusic
//
//  Created by agustin on 21/4/25.
//

import SwiftUI
import AVFoundation

@main
struct NextcloudMusicApp: App {
  init() {
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    try? AVAudioSession.sharedInstance().setActive(true)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
