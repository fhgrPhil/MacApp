import Cocoa

class WaveformView: NSView {
    var waveformData: [Float] = []
    var color: NSColor = .systemBlue
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateWaveform(with data: [Float]) {
        self.waveformData = data
        self.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let width = self.bounds.width
        let height = self.bounds.height
        let midY = height / 2
        let barWidth = width / CGFloat(waveformData.count)
        
        context.setFillColor(color.cgColor)
        
        for (index, amplitude) in waveformData.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(amplitude) * height
            let rect = CGRect(x: x, y: midY - barHeight / 2, width: barWidth, height: barHeight)
            context.fill(rect)
        }
    }
}
