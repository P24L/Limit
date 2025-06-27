//
//  VideoPlayerView.swift
//  Limit
//
//  Created by Zdenek Indra on 27.05.2025.
//

import AVKit
import SwiftUI
import AVFoundation

struct EmbeddedVideoView: View {
    let playlistURL: URL
    var height: Int? = nil
    var width: Int? = nil

    @State private var isVisible: Bool = false
    @State private var isFullScreen: Bool = false
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
                .frame(height: UIScreen.main.bounds.width / computedAspectRatio)
                .onAppear {
                    DispatchQueue.main.async {
                        /*do {
                            let session = AVAudioSession.sharedInstance()
                            try session.setCategory(.ambient, mode: .moviePlayback, options: [.mixWithOthers])
                            // Není nutné: try session.setActive(true)
                        } catch {
                            DevLogger.shared.log("VideoPlayerView.swift - Chyba při nastavení audio session category: \(error.localizedDescription)")
                        }*/
                        player.isMuted = true
                        player.replaceCurrentItem(with: AVPlayerItem(url: playlistURL))
                    }
                }
                .onChange(of: isVisible) {
                    if isVisible {
                        player.play()
                    } else {
                        player.pause()
                    }
                }
                .background(
                    VisibilityDetector { visible in
                        isVisible = visible
                    }
                )

            Rectangle()
                .foregroundColor(Color.clear)
                .contentShape(Rectangle())
                .frame(height: UIScreen.main.bounds.width / computedAspectRatio)
                .onTapGesture {
                    isFullScreen = true
                }
        }
        .allowsHitTesting(false)
        .fullScreenCover(isPresented: $isFullScreen) {
            FullscreenVideoView(videoURL: playlistURL)
        }
    }
}

struct FullscreenVideoView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer = AVPlayer()

    var body: some View {
        ZStack {
            VideoPlayer(player: player)
                .onAppear {
                    player.replaceCurrentItem(with: AVPlayerItem(url: videoURL))
                    player.isMuted = false
                    player.play()
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

struct VisibilityDetector: View {
    var onChange: (Bool) -> Void

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: VisibilityPreferenceKey.self, value: geometry.frame(in: .global).intersects(UIScreen.main.bounds))
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
