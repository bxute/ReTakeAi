//
//  VideoPlayerView.swift
//  SceneFlow
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    let autoplay: Bool
    let onFinished: (() -> Void)?
    @State private var player: AVPlayer?
    @State private var didEndObserver: NSObjectProtocol?

    init(videoURL: URL, autoplay: Bool = true, onFinished: (() -> Void)? = nil) {
        self.videoURL = videoURL
        self.autoplay = autoplay
        self.onFinished = onFinished
    }
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: videoURL)
                installDidEndObserver()
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
                    installDidEndObserver()
                    if autoplay {
                        player.play()
                    }
                } else {
                    let newPlayer = AVPlayer(playerItem: newPlayerItem)
                    player = newPlayer
                    installDidEndObserver()
                    if autoplay {
                        newPlayer.play()
                    }
                }
            }
            .onDisappear {
                uninstallDidEndObserver()
                player?.pause()
                player = nil
            }
    }

    private func installDidEndObserver() {
        uninstallDidEndObserver()
        guard let item = player?.currentItem, onFinished != nil else { return }
        didEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            onFinished?()
        }
    }

    private func uninstallDidEndObserver() {
        if let didEndObserver {
            NotificationCenter.default.removeObserver(didEndObserver)
            self.didEndObserver = nil
        }
    }
}
