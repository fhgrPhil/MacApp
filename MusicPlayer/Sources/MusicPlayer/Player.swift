import Cocoa
import AVFoundation

class Player {
    var audioPlayer: AVAudioPlayer?
    var audioFileURL: URL?
    var artworkImage: NSImage?
    var waveformData: [Float] = []
    
    var bpm: Float = 0
    var length: TimeInterval = 0
    var isLoaded: Bool = false
    var pitch: Float = 0.0
    
    var currentTime: TimeInterval {
        get { return audioPlayer?.currentTime ?? 0 }
        set { audioPlayer?.currentTime = newValue }
    }
    
    var duration: TimeInterval {
        return audioPlayer?.duration ?? 0
    }
    
    var remainingTime: TimeInterval {
        return duration - currentTime
    }
    
    init(url: URL) {
        self.audioFileURL = url
        loadArtwork(url: url)
    }
    
    func loadAudioFile() throws {
        guard let url = audioFileURL else {
            throw NSError(domain: "PlayerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Audio file URL is nil"])
        }
        
        try setupAudioPlayer(url: url)
        try analyzeAudio(url: url)
        isLoaded = true
    }
    
    private func setupAudioPlayer(url: URL) throws {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.enableRate = true
            length = audioPlayer?.duration ?? 0
        } catch {
            throw error
        }
    }
    
    func play() {
        audioPlayer?.play()
    }
    
    func pause() {
        audioPlayer?.pause()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
    }
    
    func isPlaying() -> Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
    }
    
    func changePitch(by semitones: Float) {
        pitch += semitones
        audioPlayer?.rate = pow(2, pitch / 12)
    }
    
    private func loadArtwork(url: URL) {
        let asset = AVAsset(url: url)
        for item in asset.commonMetadata {
            if item.commonKey == .commonKeyArtwork, let data = item.dataValue, let image = NSImage(data: data) {
                artworkImage = image
                return
            }
        }
        artworkImage = NSImage(named: "NSApplicationIcon") // Default image if no artwork found
    }
    
    private func analyzeAudio(url: URL) throws {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let sampleRate = format.sampleRate
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioFile.length)) else {
                throw NSError(domain: "PlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"])
            }
            
            try audioFile.read(into: buffer)
            
            guard let channelData = buffer.floatChannelData else {
                throw NSError(domain: "PlayerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to get channel data"])
            }
            
            let channelCount = Int(buffer.format.channelCount)
            let sampleCount = Int(buffer.frameLength)
            
            // Generate waveform data
            let samplesPerPixel = sampleCount / 200 // Adjust this value to change waveform resolution
            for i in stride(from: 0, to: sampleCount, by: samplesPerPixel) {
                let endIndex = min(i + samplesPerPixel, sampleCount)
                var maxAmplitude: Float = 0
                
                for j in i..<endIndex {
                    for channel in 0..<channelCount {
                        let sample = abs(channelData[channel][j])
                        maxAmplitude = max(maxAmplitude, sample)
                    }
                }
                
                waveformData.append(maxAmplitude)
            }
            
            // Normalize waveform data
            let maxAmplitude = waveformData.max() ?? 1.0
            waveformData = waveformData.map { $0 / maxAmplitude }
            
            // Improved BPM detection using autocorrelation
            bpm = detectBPM(buffer: buffer, sampleRate: sampleRate)
            
            // Set length
            length = Double(audioFile.length) / sampleRate
            
        } catch {
            throw error
        }
    }
    
    private func detectBPM(buffer: AVAudioPCMBuffer, sampleRate: Double) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        
        let channelCount = Int(buffer.format.channelCount)
        let sampleCount = Int(buffer.frameLength)
        
        // Combine channels and calculate energy
        var energySignal = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            var sum: Float = 0
            for channel in 0..<channelCount {
                sum += channelData[channel][i] * channelData[channel][i]
            }
            energySignal[i] = sum / Float(channelCount)
        }
        
        // Perform autocorrelation
        let maxLag = min(sampleCount, Int(sampleRate * 2)) // 2 seconds maximum
        var autocorrelation = [Float](repeating: 0, count: maxLag)
        
        for lag in 0..<maxLag {
            var sum: Float = 0
            for i in 0..<(sampleCount - lag) {
                sum += energySignal[i] * energySignal[i + lag]
            }
            autocorrelation[lag] = sum
        }
        
        // Find peaks in autocorrelation
        var peaks = [Int]()
        for i in 2..<(maxLag - 1) {
            if autocorrelation[i] > autocorrelation[i-1] && autocorrelation[i] > autocorrelation[i+1] {
                peaks.append(i)
            }
        }
        
        // Calculate BPM from peak intervals
        var intervalSum: Float = 0
        var intervalCount = 0
        
        for i in 1..<peaks.count {
            let interval = peaks[i] - peaks[i-1]
            if interval > Int(sampleRate * 0.3) && interval < Int(sampleRate * 1.5) {
                intervalSum += Float(interval)
                intervalCount += 1
            }
        }
        
        if intervalCount > 0 {
            let averageInterval = intervalSum / Float(intervalCount)
            print("Average Interval: \(averageInterval)") // Debugging log
            return 60.0 * Float(sampleRate) / averageInterval
        }
        
        print("No valid intervals found") // Debugging log
        return 0
    }
}
