//
//  VideoPlayerView.swift
//  SceneFlow
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
                player?.play()
            }
            .onChange(of: videoURL) { _, newURL in
                // When selecting a different take, swap the player item so the preview updates.
                let newPlayerItem = AVPlayerItem(url: newURL)
                if let player {
                    player.replaceCurrentItem(with: newPlayerItem)
                    player.seek(to: .zero)
                    player.play()
                } else {
                    let newPlayer = AVPlayer(playerItem: newPlayerItem)
                    player = newPlayer
                    newPlayer.play()
                }
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}
