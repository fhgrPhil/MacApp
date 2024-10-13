import Cocoa
import AVFoundation

class MusicPlayerApp: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var player: AVAudioPlayer?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the window
        window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 300, height: 200),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.title = "Music Player"
        window.makeKeyAndOrderFront(nil)
        
        // Create a button
        let button = NSButton(frame: NSRect(x: 100, y: 100, width: 100, height: 30))
        button.title = "Open Music File"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(openFile)
        
        window.contentView?.addSubview(button)
    }
    
    @objc func openFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.mp3, .wav, .mpeg4Audio]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.beginSheetModal(for: window) { response in
            if response == .OK, let url = openPanel.url {
                self.playAudio(url: url)
            }
        }
    }
    
    func playAudio(url: URL) {
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
}

// Create and run the application
let app = NSApplication.shared
let delegate = MusicPlayerApp()
app.delegate = delegate
app.run()
