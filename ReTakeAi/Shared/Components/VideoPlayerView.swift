//
//  VideoPlayerView.swift
//  SceneFlow
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    let autoplay: Bool
    @State private var player: AVPlayer?

    init(videoURL: URL, autoplay: Bool = true) {
        self.videoURL = videoURL
        self.autoplay = autoplay
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
                if autoplay {
                    player?.play()
                }
            }
            .onChange(of: videoURL) { _, newURL in
                // When selecting a different take, swap the player item so the preview updates.
                let newPlayerItem = AVPlayerItem(url: newURL)
                if let player {
                    player.replaceCurrentItem(with: newPlayerItem)
                    player.seek(to: .zero)
                    if autoplay {
                        player.play()
                    }
                } else {
                    let newPlayer = AVPlayer(playerItem: newPlayerItem)
                    player = newPlayer
                    if autoplay {
                        newPlayer.play()
                    }
                }
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}
