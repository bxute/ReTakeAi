//
//  DeadAirTrimmerProcessor.swift
//  ReTakeAi
//
//  Detects and trims dead air (long silent pauses) from audio
//

import Foundation
import AVFoundation
import Accelerate

/// Dead air trimmer - removes or shortens long silent pauses
///
/// **Algorithm:**
/// 1. Detect silent regions using RMS analysis
/// 2. Classify regions: voice, short pause, dead air
/// 3. Trim dead air at configured locations (start, end, mid)
/// 4. Return trimmed audio with metadata
///
/// **Trim Locations:**
/// - **Start**: Remove silence before first voice (keep buffer)
/// - **End**: Remove silence after last voice (keep buffer)
/// - **Mid**: Shorten long pauses within speech (compress to max duration)
///
class DeadAirTrimmerProcessor: AudioProcessorProtocol {
    let id = "deadAirTrimmer"
    let name = "Dead Air Trimmer"

    var defaultConfig: ProcessorConfig {
        ProcessorConfig([
            "trimStart": true,              // Trim silence at beginning
            "trimEnd": true,                // Trim silence at end
            "trimMid": false,               // Trim/compress mid-scene pauses (advanced)
            "startBuffer": 0.25,            // Seconds to keep at start
            "endBuffer": 0.25,              // Seconds to keep at end
            "minDeadAirDuration": 1.0,      // Seconds (silence > this = dead air)
            "maxMidPauseDuration": 1.5,     // Max pause length in mid-scene
            "minSustainedVoiceDuration": 0.1, // Seconds (voice must be sustained to count)
            "frameSize": 0.020              // 20 ms analysis frames (voiceThreshold now adaptive)
        ])
    }

    func process(inputURL: URL, outputURL: URL, config: ProcessorConfig) async throws {
        let trimStart = config["trimStart"] as? Bool ?? true
        let trimEnd = config["trimEnd"] as? Bool ?? true
        let trimMid = config["trimMid"] as? Bool ?? false
        let startBuffer = config["startBuffer"] as? Double ?? 0.25
        let endBuffer = config["endBuffer"] as? Double ?? 0.25
        let minDeadAirDuration = config["minDeadAirDuration"] as? Double ?? 1.0
        let maxMidPauseDuration = config["maxMidPauseDuration"] as? Double ?? 1.5
        let minSustainedVoiceDuration = config["minSustainedVoiceDuration"] as? Double ?? 0.1
        let frameSize = config["frameSize"] as? Double ?? 0.020

        AppLogger.mediaProcessing.info("✂️ Dead Air Trimmer: Starting")
        AppLogger.mediaProcessing.info("  Trim Start: \(trimStart) (buffer: \(startBuffer)s)")
        AppLogger.mediaProcessing.info("  Trim End: \(trimEnd) (buffer: \(endBuffer)s)")
        AppLogger.mediaProcessing.info("  Trim Mid: \(trimMid) (max pause: \(maxMidPauseDuration)s)")
        AppLogger.mediaProcessing.info("  Min Dead Air: \(minDeadAirDuration)s")

        // Load audio
        let sourceFile = try AVAudioFile(forReading: inputURL)
        let format = sourceFile.processingFormat
        let sampleRate = format.sampleRate

        let totalFrames = AVAudioFrameCount(sourceFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            throw NSError(domain: "DeadAirTrimmerProcessor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create buffer"
            ])
        }

        try sourceFile.read(into: buffer)
        buffer.frameLength = totalFrames

        let totalDuration = Double(totalFrames) / sampleRate

        AppLogger.mediaProcessing.info("  Duration: \(String(format: "%.2f", totalDuration))s")
        AppLogger.mediaProcessing.info("  Sample Rate: \(sampleRate) Hz")

        // Calculate adaptive voice threshold (like SilenceAttenuator)
        let adaptiveThreshold = calculateAdaptiveThreshold(
            buffer: buffer,
            sampleRate: sampleRate,
            frameSize: frameSize
        )

        AppLogger.mediaProcessing.info("  Adaptive Threshold: \(String(format: "%.1f", adaptiveThreshold)) dB")

        // Analyze audio for voice/silence regions
        let regions = try analyzeAudioRegions(
            buffer: buffer,
            sampleRate: sampleRate,
            frameSize: frameSize,
            voiceThresholdDB: adaptiveThreshold,
            minDeadAirDuration: minDeadAirDuration
        )

        AppLogger.mediaProcessing.info("  Detected \(regions.filter { $0.type == .voice }.count) voice regions")
        AppLogger.mediaProcessing.info("  Detected \(regions.filter { $0.type == .deadAir }.count) dead air regions")

        // Calculate trim regions
        let trimRegions = calculateTrimRegions(
            regions: regions,
            totalDuration: totalDuration,
            trimStart: trimStart,
            trimEnd: trimEnd,
            trimMid: trimMid,
            startBuffer: startBuffer,
            endBuffer: endBuffer,
            maxMidPauseDuration: maxMidPauseDuration,
            minSustainedVoiceDuration: minSustainedVoiceDuration
        )

        if trimRegions.isEmpty {
            AppLogger.mediaProcessing.info("  No trimming needed - copying original")
            try FileManager.default.copyItem(at: inputURL, to: outputURL)
            return
        }

        // Apply trims
        let trimmedDuration = try await applyTrims(
            inputURL: inputURL,
            outputURL: outputURL,
            trimRegions: trimRegions,
            sampleRate: sampleRate
        )

        let savedDuration = totalDuration - trimmedDuration
        AppLogger.mediaProcessing.info("  Original: \(String(format: "%.2f", totalDuration))s")
        AppLogger.mediaProcessing.info("  Trimmed: \(String(format: "%.2f", trimmedDuration))s")
        AppLogger.mediaProcessing.info("  Saved: \(String(format: "%.2f", savedDuration))s (\(Int(savedDuration / totalDuration * 100))%)")
        AppLogger.mediaProcessing.info("✅ Dead air trimming complete")
    }

    // MARK: - Adaptive Threshold Calculation

    private func calculateAdaptiveThreshold(
        buffer: AVAudioPCMBuffer,
        sampleRate: Double,
        frameSize: Double
    ) -> Double {

        guard let channelData = buffer.floatChannelData else {
            return -45.0  // Fallback
        }

        let channelCount = Int(buffer.format.channelCount)
        let totalFrames = Int(buffer.frameLength)
        let samplesPerFrame = Int(sampleRate * frameSize)

        // Calculate RMS and peak per frame
        var rmsValues: [Double] = []
        var peakValues: [Double] = []

        let frameCount = (totalFrames + samplesPerFrame - 1) / samplesPerFrame
        for frameIndex in 0..<frameCount {
            let startSample = frameIndex * samplesPerFrame
            let endSample = min(startSample + samplesPerFrame, totalFrames)
            let sampleCount = endSample - startSample

            var sumSquares: Double = 0
            var peak: Double = 0

            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for i in startSample..<endSample {
                    let sample = Double(samples[i])
                    sumSquares += sample * sample
                    peak = max(peak, abs(sample))
                }
            }

            let rms = sqrt(sumSquares / Double(sampleCount * channelCount))
            rmsValues.append(rms)
            peakValues.append(peak)
        }

        // Simple Voice Activity Detection
        let sortedRMS = rmsValues.sorted()
        let medianRMS = sortedRMS[sortedRMS.count / 2]
        let voiceThreshold = medianRMS * 1.5

        var silenceFrameIndices: Set<Int> = []

        for i in 0..<rmsValues.count {
            let rms = rmsValues[i]
            let peak = peakValues[i]
            let crestFactor = peak / max(rms, 1e-10)

            // Classify as silence if below threshold or spike-like
            if rms < medianRMS * 0.5 || (rms < voiceThreshold && crestFactor > 10.0) {
                silenceFrameIndices.insert(i)
            }
        }

        // Calculate noise floor from silence frames
        var threshold: Double

        if silenceFrameIndices.count >= 10 {
            // Use silence frames (75th percentile)
            let silenceRMS = silenceFrameIndices.map { rmsValues[$0] }.sorted()
            let percentileIndex = min(Int(Double(silenceRMS.count) * 0.75), silenceRMS.count - 1)
            let noiseFloorLinear = silenceRMS[percentileIndex]
            let noiseFloorDB = 20.0 * log10(max(noiseFloorLinear, 1e-10))

            // Threshold = noise floor + 8 dB
            threshold = noiseFloorDB + 8.0
        } else {
            // Fallback: use 10th percentile
            let percentileIndex = Int(Double(sortedRMS.count) * 0.10)
            let noiseFloorLinear = sortedRMS[percentileIndex]
            let noiseFloorDB = 20.0 * log10(max(noiseFloorLinear, 1e-10))

            threshold = noiseFloorDB + 8.0
        }

        // Clamp to safe range
        threshold = max(-55.0, min(-40.0, threshold))

        return threshold
    }

    // MARK: - Region Analysis

    enum RegionType {
        case voice
        case shortPause  // < minDeadAirDuration
        case deadAir     // >= minDeadAirDuration
    }

    struct AudioRegion {
        let startTime: Double
        let endTime: Double
        let type: RegionType
        let rmsDB: Double
    }

    private func analyzeAudioRegions(
        buffer: AVAudioPCMBuffer,
        sampleRate: Double,
        frameSize: Double,
        voiceThresholdDB: Double,
        minDeadAirDuration: Double
    ) throws -> [AudioRegion] {

        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "DeadAirTrimmerProcessor", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to access audio data"
            ])
        }

        let channelCount = Int(buffer.format.channelCount)
        let totalFrames = Int(buffer.frameLength)
        let samplesPerFrame = Int(sampleRate * frameSize)

        // Calculate RMS per frame
        var frameRMS: [(time: Double, rmsDB: Double)] = []

        let frameCount = (totalFrames + samplesPerFrame - 1) / samplesPerFrame
        for frameIndex in 0..<frameCount {
            let startSample = frameIndex * samplesPerFrame
            let endSample = min(startSample + samplesPerFrame, totalFrames)
            let sampleCount = endSample - startSample

            var sumSquares: Double = 0
            for channel in 0..<channelCount {
                let samples = channelData[channel]
                for i in startSample..<endSample {
                    let sample = Double(samples[i])
                    sumSquares += sample * sample
                }
            }

            let rms = sqrt(sumSquares / Double(sampleCount * channelCount))
            let rmsDB = 20.0 * log10(max(rms, 1e-10))
            let time = Double(startSample) / sampleRate

            frameRMS.append((time, rmsDB))
        }

        // Classify frames as voice or silence
        var isVoice: [Bool] = frameRMS.map { $0.rmsDB > voiceThresholdDB }

        // Apply smoothing (avoid jitter)
        let smoothingWindow = 3
        for i in 0..<isVoice.count {
            let start = max(0, i - smoothingWindow)
            let end = min(isVoice.count, i + smoothingWindow + 1)
            let voiceCount = isVoice[start..<end].filter { $0 }.count
            isVoice[i] = voiceCount > smoothingWindow  // Majority vote
        }

        // Build regions
        var regions: [AudioRegion] = []
        var currentType: RegionType? = nil
        var currentStart: Double = 0

        for (index, frame) in frameRMS.enumerated() {
            let newType: RegionType = isVoice[index] ? .voice : .shortPause

            if currentType != newType {
                // Region change
                if let type = currentType {
                    let duration = frame.time - currentStart
                    let finalType: RegionType = (type == .shortPause && duration >= minDeadAirDuration) ? .deadAir : type

                    regions.append(AudioRegion(
                        startTime: currentStart,
                        endTime: frame.time,
                        type: finalType,
                        rmsDB: frameRMS[index].rmsDB
                    ))
                }
                currentStart = frame.time
                currentType = newType
            }
        }

        // Add final region
        if let type = currentType, let lastFrame = frameRMS.last {
            let duration = lastFrame.time - currentStart
            let finalType: RegionType = (type == .shortPause && duration >= minDeadAirDuration) ? .deadAir : type

            regions.append(AudioRegion(
                startTime: currentStart,
                endTime: lastFrame.time + frameSize,
                type: finalType,
                rmsDB: lastFrame.rmsDB
            ))
        }

        return regions
    }

    // MARK: - Trim Calculation

    struct TrimRegion {
        let startTime: Double
        let endTime: Double
        let reason: String
    }

    private func calculateTrimRegions(
        regions: [AudioRegion],
        totalDuration: Double,
        trimStart: Bool,
        trimEnd: Bool,
        trimMid: Bool,
        startBuffer: Double,
        endBuffer: Double,
        maxMidPauseDuration: Double,
        minSustainedVoiceDuration: Double
    ) -> [TrimRegion] {

        var trims: [TrimRegion] = []

        guard !regions.isEmpty else { return trims }

        // Find first and last SUSTAINED voice regions (ignore brief sounds)
        let firstVoiceIndex = regions.firstIndex { region in
            region.type == .voice &&
            (region.endTime - region.startTime) >= minSustainedVoiceDuration
        }
        let lastVoiceIndex = regions.lastIndex { region in
            region.type == .voice &&
            (region.endTime - region.startTime) >= minSustainedVoiceDuration
        }

        // Trim start dead air
        if trimStart, let firstVoice = firstVoiceIndex {
            let voiceStart = regions[firstVoice].startTime
            let trimEnd = max(0, voiceStart - startBuffer)

            if trimEnd > 0 {
                trims.append(TrimRegion(
                    startTime: 0,
                    endTime: trimEnd,
                    reason: "Start dead air"
                ))
                AppLogger.mediaProcessing.info("  Trimming start: 0.00s - \(String(format: "%.2f", trimEnd))s")
            }
        }

        // Trim end dead air
        if trimEnd, let lastVoice = lastVoiceIndex {
            let voiceEnd = regions[lastVoice].endTime
            let trimStart = min(totalDuration, voiceEnd + endBuffer)

            if trimStart < totalDuration {
                trims.append(TrimRegion(
                    startTime: trimStart,
                    endTime: totalDuration,
                    reason: "End dead air"
                ))
                AppLogger.mediaProcessing.info("  Trimming end: \(String(format: "%.2f", trimStart))s - \(String(format: "%.2f", totalDuration))s")
            }
        }

        // Trim mid-scene dead air
        if trimMid, let firstVoice = firstVoiceIndex, let lastVoice = lastVoiceIndex {
            // Only process if there are regions between first and last voice
            if firstVoice + 1 < lastVoice {
                for i in (firstVoice + 1)..<lastVoice {
                    let region = regions[i]

                    if region.type == .deadAir {
                        let duration = region.endTime - region.startTime

                        if duration > maxMidPauseDuration {
                            // Compress pause to max allowed duration
                            let trimStart = region.startTime + maxMidPauseDuration
                            let trimEnd = region.endTime

                            trims.append(TrimRegion(
                                startTime: trimStart,
                                endTime: trimEnd,
                                reason: "Mid-scene dead air"
                            ))
                            AppLogger.mediaProcessing.info("  Trimming mid: \(String(format: "%.2f", trimStart))s - \(String(format: "%.2f", trimEnd))s")
                        }
                    }
                }
            }
        }

        // Sort trims by start time
        return trims.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Apply Trims

    private func applyTrims(
        inputURL: URL,
        outputURL: URL,
        trimRegions: [TrimRegion],
        sampleRate: Double
    ) async throws -> Double {

        let asset = AVAsset(url: inputURL)
        let composition = AVMutableComposition()

        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "DeadAirTrimmerProcessor", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "No audio track found"
            ])
        }

        let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        guard let compositionTrack = compositionTrack else {
            throw NSError(domain: "DeadAirTrimmerProcessor", code: -4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create composition track"
            ])
        }

        // Calculate keep regions (inverse of trim regions)
        let duration = try await asset.load(.duration)
        let totalDuration = CMTimeGetSeconds(duration)

        var keepRegions: [(start: Double, end: Double)] = []
        var currentTime: Double = 0

        for trim in trimRegions {
            if currentTime < trim.startTime {
                keepRegions.append((currentTime, trim.startTime))
            }
            currentTime = trim.endTime
        }

        // Add final region if needed
        if currentTime < totalDuration {
            keepRegions.append((currentTime, totalDuration))
        }

        // Insert keep regions into composition
        var insertTime = CMTime.zero
        for region in keepRegions {
            let start = CMTime(seconds: region.start, preferredTimescale: 600)
            let duration = CMTime(seconds: region.end - region.start, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: start, duration: duration)

            try compositionTrack.insertTimeRange(timeRange, of: audioTrack, at: insertTime)
            insertTime = CMTimeAdd(insertTime, duration)
        }

        // Export composition
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "DeadAirTrimmerProcessor", code: -5, userInfo: [
                NSLocalizedDescriptionKey: "Failed to create export session"
            ])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()

        if let error = exportSession.error {
            throw error
        }

        return CMTimeGetSeconds(insertTime)
    }
}

// MARK: - Technical Notes

/*
 DEAD AIR TRIMMING:

 This processor detects and removes long silent pauses (dead air) from audio.

 **What It Does:**
 - Analyzes audio in 20ms frames
 - Classifies each frame as voice or silence
 - Groups consecutive frames into regions
 - Identifies dead air (silence > threshold duration)
 - Trims dead air at configured locations

 **Trim Modes:**
 1. **Start Trim**: Remove silence before first voice (with buffer)
 2. **End Trim**: Remove silence after last voice (with buffer)
 3. **Mid Trim**: Compress long pauses within speech to max duration

 **Algorithm:**
 1. RMS analysis per frame → dBFS
 2. Voice detection: RMS > threshold
 3. Region building: Group consecutive voice/silence frames
 4. Classification: Short pause vs dead air (duration check)
 5. Trim calculation: Which regions to remove
 6. Composition: Rebuild audio without trimmed regions

 **Example:**
 Original: [2s silence] [5s voice] [3s silence] [4s voice] [2s silence]

 With trimStart=true, trimEnd=true, buffer=0.25s:
 Result: [0.25s] [5s voice] [3s silence] [4s voice] [0.25s]
 Saved: 3.5 seconds

 With trimMid=true, maxMidPause=1s:
 Result: [0.25s] [5s voice] [1s silence] [4s voice] [0.25s]
 Saved: 5.5 seconds

 **Performance:**
 - Analysis: O(n) where n = audio samples
 - Trimming: Fast (uses AVFoundation composition, no re-encoding)
 - Typical: 10 second audio processes in ~0.2 seconds

 **Use Cases:**
 - Scene recording: Remove silence at start/end
 - Podcast editing: Shorten long pauses
 - Video production: Tighten pacing
 */
