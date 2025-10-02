//
//  VideoPlayerView.swift
//  Limit
//
//  Created by Zdenek Indra on 27.05.2025.
//

import AVKit
import SwiftUI
import AVFoundation

/// Video player component for timeline posts with automatic muting and fullscreen support
struct EmbeddedVideoView: View {
    let playlistURL: URL
    var height: Int? = nil
    var width: Int? = nil

    @Environment(UserPreferences.self) private var preferences
    @State private var isVisible: Bool = false
    @State private var isFullScreen: Bool = false
    @State private var isPlaying: Bool = false
    @State private var player = AVPlayer()

    var computedAspectRatio: CGFloat {
        if let w = width, let h = height, h != 0 {
            return CGFloat(w) / CGFloat(h)
        } else {
            return 16.0 / 9.0
        }
    }

    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .aspectRatio(computedAspectRatio, contentMode: .fit)
                .onAppear {
                    DispatchQueue.main.async {
                        do {
                            let session = AVAudioSession.sharedInstance()
                            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
                            try session.setActive(true)
                        } catch {
                            DevLogger.shared.log("VideoPlayerView.swift - Error setting audio session category: \(error.localizedDescription)")
                        }
                        player.isMuted = true
                        player.replaceCurrentItem(with: AVPlayerItem(url: playlistURL))
                    }
                }
                .onChange(of: isVisible) {
                    if isVisible && preferences.autoPlayVideos {
                        player.play()
                        isPlaying = true
                    } else if !isVisible {
                        player.pause()
                        isPlaying = false
                    }
                }
                .background(
                    VisibilityDetector { visible in
                        isVisible = visible
                    }
                )
                .onDisappear {
                    player.pause()
                    player.replaceCurrentItem(with: nil)
                }
        }
        .aspectRatio(computedAspectRatio, contentMode: .fit)
        .contentShape(Rectangle())
        .overlay {
            // Show play button overlay when video is not playing and auto-play is off
            if !isPlaying && !preferences.autoPlayVideos {
                ZStack {
                    Color.black.opacity(0.4)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .shadow(radius: 8)
                }
            }
        }
        .onTapGesture {
            // If not playing and auto-play is off, start playing
            if !isPlaying && !preferences.autoPlayVideos {
                player.play()
                isPlaying = true
            } else {
                // Otherwise open fullscreen
                isFullScreen = true
            }
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            FullscreenVideoView(videoURL: playlistURL)
        }
    }
}

/// Fullscreen video player with audio enabled
struct FullscreenVideoView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer = AVPlayer()

    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .onAppear {
                    do {
                        let session = AVAudioSession.sharedInstance()
                        try session.setCategory(.playback, mode: .moviePlayback, options: [])
                        try session.setActive(true)
                    } catch {
                        DevLogger.shared.log("FullscreenVideoView.swift - Error setting audio session category: \(error.localizedDescription)")
                    }
                    player.replaceCurrentItem(with: AVPlayerItem(url: videoURL))
                    player.isMuted = false
                    player.play()
                }
                .onDisappear {
                    player.pause()
                    player.replaceCurrentItem(with: nil)
                }
                .edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        player.pause()
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}

/// Detects when a view becomes visible on screen to control video playback
struct VisibilityDetector: View {
    var onChange: (Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: VisibilityPreferenceKey.self, value: geometry.frame(in: .global).intersects(CGRect(x: 0, y: 0, width: 400, height: 800)))
        }
        .onPreferenceChange(VisibilityPreferenceKey.self, perform: onChange)
    }
}

struct VisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue()
    }
}
