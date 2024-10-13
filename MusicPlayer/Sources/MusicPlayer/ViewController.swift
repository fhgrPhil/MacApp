import Cocoa
import AVFoundation

/// The main view controller for the Music Player application.
/// This class manages the UI and interactions for multiple audio players.
class ViewController: NSViewController {
    // MARK: - Properties
    
    /// Array to store Player instances
    var players: [Player] = []
    
    /// Array to store NSView instances for each player
    var playerViews: [NSView] = []
    
    /// Button to add new players
    var addPlayerButton: NSButton!
    
    /// Scroll view to contain multiple player views
    var scrollView: NSScrollView!
    
    /// Content view inside the scroll view
    var contentView: NSView!
    
    /// Timer to update player views periodically
    var updateTimer: Timer?

    // MARK: - View Lifecycle

    override func loadView() {
        // Initialize the main view
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 400))
        self.view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the user interface
        setupUI()

        // Start a timer to update player views every 0.1 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateAllPlayerViews()
        }
    }

    // MARK: - UI Setup

    /// Sets up the main user interface elements
    func setupUI() {
        // Create and configure the scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        view.addSubview(scrollView)

        // Create and configure the content view
        contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        // Create and configure the add player button
        addPlayerButton = NSButton()
        addPlayerButton.translatesAutoresizingMaskIntoConstraints = false
        addPlayerButton.title = "Add Player"
        addPlayerButton.bezelStyle = .rounded
        addPlayerButton.target = self
        addPlayerButton.action = #selector(addPlayer)
        view.addSubview(addPlayerButton)

        // Set up constraints for the UI elements
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: addPlayerButton.topAnchor, constant: -10),

            addPlayerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            addPlayerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            addPlayerButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            addPlayerButton.heightAnchor.constraint(equalToConstant: 30),

            contentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Set the content view's height to match its intrinsic content size
        contentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.heightAnchor).isActive = true
    }

    // MARK: - Player Management

    /// Adds a new player by opening a file dialog and creating a Player instance
    @objc func addPlayer() {
        // Configure and present the open panel for file selection
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["mp3", "wav", "m4a"]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.beginSheetModal(for: self.view.window!) { response in
            if response == .OK, let url = openPanel.url {
                // Create a new Player instance immediately with just the URL
                let player = Player(url: url)
                self.players.append(player)
                self.addPlayerView(for: player)
                
                // Start loading the audio file and performing analysis in the background
                self.loadAudioFileInBackground(for: player)
            }
        }
    }
    
    /// Loads the audio file and performs analysis in the background
    /// - Parameter player: The Player instance to load and analyze
    func loadAudioFileInBackground(for player: Player) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try player.loadAudioFile()
                
                DispatchQueue.main.async {
                    if let index = self.players.firstIndex(where: { $0 === player }),
                       index < self.playerViews.count {
                        self.updatePlayerView(playerView: self.playerViews[index], player: player)
                    }
                }
            } catch {
                print("Error loading audio file: \(error)")
                DispatchQueue.main.async {
                    // Handle the error (e.g., show an alert to the user)
                    let alert = NSAlert()
                    alert.messageText = "Error Loading Audio File"
                    alert.informativeText = "An error occurred while loading the audio file: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
            }
        }
    }
    
    /// Creates and adds a view for a given player
    /// - Parameter player: The Player instance to create a view for
    func addPlayerView(for player: Player) {
        // Create the main player view
        let playerView = NSView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.wantsLayer = true
        playerView.layer?.backgroundColor = NSColor.lightGray.withAlphaComponent(0.2).cgColor
        playerView.layer?.cornerRadius = 10
        contentView.addSubview(playerView)
        
        // Create and add subviews (buttons, labels, etc.)
        let playPauseButton = createButton(title: "Play", action: #selector(playPauseAction(_:)))
        playerView.addSubview(playPauseButton)

        let stopButton = createButton(title: "Stop", action: #selector(stopAction(_:)))
        playerView.addSubview(stopButton)

        let removeButton = createButton(title: "Remove", action: #selector(removePlayer(_:)))
        playerView.addSubview(removeButton)

        let artworkImageView = NSImageView()
        artworkImageView.translatesAutoresizingMaskIntoConstraints = false
        artworkImageView.image = player.artworkImage ?? NSImage(named: "defaultArtwork")
        playerView.addSubview(artworkImageView)

        let fileNameLabel = createLabel(text: player.audioFileURL?.lastPathComponent ?? "Unknown")
        playerView.addSubview(fileNameLabel)

        let navigationBar = NSSlider()
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        navigationBar.minValue = 0
        navigationBar.maxValue = 1 // Will be updated when audio file is loaded
        navigationBar.target = self
        navigationBar.action = #selector(navigationBarChanged(_:))
        playerView.addSubview(navigationBar)

        let waveformView = WaveformView()
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        playerView.addSubview(waveformView)

        let infoLabel = createLabel(text: "Loading...")
        playerView.addSubview(infoLabel)

        // Add pitch control buttons and label
        let decreasePitchButton = createButton(title: "▼", action: #selector(decreasePitch(_:)))
        playerView.addSubview(decreasePitchButton)

        let increasePitchButton = createButton(title: "▲", action: #selector(increasePitch(_:)))
        playerView.addSubview(increasePitchButton)

        let pitchLabel = createLabel(text: "Pitch: 0")
        playerView.addSubview(pitchLabel)

        // Set up constraints for the player view and its subviews
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: playerViews.last?.bottomAnchor ?? contentView.topAnchor, constant: 10),
            playerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            playerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            playerView.heightAnchor.constraint(equalToConstant: 240),

            playPauseButton.topAnchor.constraint(equalTo: playerView.topAnchor, constant: 10),
            playPauseButton.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 10),
            playPauseButton.widthAnchor.constraint(equalToConstant: 80),
            playPauseButton.heightAnchor.constraint(equalToConstant: 30),

            stopButton.topAnchor.constraint(equalTo: playerView.topAnchor, constant: 10),
            stopButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 10),
            stopButton.widthAnchor.constraint(equalToConstant: 80),
            stopButton.heightAnchor.constraint(equalToConstant: 30),

            removeButton.topAnchor.constraint(equalTo: playerView.topAnchor, constant: 10),
            removeButton.leadingAnchor.constraint(equalTo: stopButton.trailingAnchor, constant: 10),
            removeButton.widthAnchor.constraint(equalToConstant: 80),
            removeButton.heightAnchor.constraint(equalToConstant: 30),

            artworkImageView.topAnchor.constraint(equalTo: playPauseButton.bottomAnchor, constant: 10),
            artworkImageView.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 10),
            artworkImageView.widthAnchor.constraint(equalToConstant: 40),
            artworkImageView.heightAnchor.constraint(equalToConstant: 40),

            fileNameLabel.centerYAnchor.constraint(equalTo: artworkImageView.centerYAnchor),
            fileNameLabel.leadingAnchor.constraint(equalTo: artworkImageView.trailingAnchor, constant: 10),
            fileNameLabel.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -10),

            navigationBar.topAnchor.constraint(equalTo: artworkImageView.bottomAnchor, constant: 10),
            navigationBar.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 10),
            navigationBar.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -10),
            navigationBar.heightAnchor.constraint(equalToConstant: 20),

            waveformView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: 10),
            waveformView.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 10),
            waveformView.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -10),
            waveformView.heightAnchor.constraint(equalToConstant: 30),

            infoLabel.topAnchor.constraint(equalTo: waveformView.bottomAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 10),
            infoLabel.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -10),

            decreasePitchButton.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 10),
            decreasePitchButton.leadingAnchor.constraint(equalTo: playerView.leadingAnchor, constant: 10),
            decreasePitchButton.widthAnchor.constraint(equalToConstant: 30),
            decreasePitchButton.heightAnchor.constraint(equalToConstant: 30),

            increasePitchButton.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 10),
            increasePitchButton.leadingAnchor.constraint(equalTo: decreasePitchButton.trailingAnchor, constant: 10),
            increasePitchButton.widthAnchor.constraint(equalToConstant: 30),
            increasePitchButton.heightAnchor.constraint(equalToConstant: 30),

            pitchLabel.centerYAnchor.constraint(equalTo: decreasePitchButton.centerYAnchor),
            pitchLabel.leadingAnchor.constraint(equalTo: increasePitchButton.trailingAnchor, constant: 10),
            pitchLabel.trailingAnchor.constraint(equalTo: playerView.trailingAnchor, constant: -10),
            pitchLabel.bottomAnchor.constraint(equalTo: playerView.bottomAnchor, constant: -10)
        ])

        playerViews.append(playerView)
        
        // Update content view height
        updateContentViewHeight()
        
        // Scroll to the bottom to show the newly added player
        scrollToBottom()
        
        // Force layout update
        view.layoutSubtreeIfNeeded()
        
        updatePlayerView(playerView: playerView, player: player)
    }
    
    // MARK: - Player Actions

    /// Handles play/pause action for a player
    /// - Parameter sender: The button that triggered the action
    @objc func playPauseAction(_ sender: NSButton) {
        guard let playerView = sender.superview,
              let index = playerViews.firstIndex(of: playerView) else {
            return
        }
        
        let player = players[index]
        if player.isPlaying() {
            player.pause()
            sender.title = "Play"
        } else {
            player.play()
            sender.title = "Pause"
        }
    }
    
    /// Handles stop action for a player
    /// - Parameter sender: The button that triggered the action
    @objc func stopAction(_ sender: NSButton) {
        guard let playerView = sender.superview,
              let index = playerViews.firstIndex(of: playerView) else {
            return
        }
        
        let player = players[index]
        player.stop()
        if let playPauseButton = playerView.subviews.first(where: { $0 is NSButton }) as? NSButton {
            playPauseButton.title = "Play"
        }
        updatePlayerView(playerView: playerView, player: player)
    }
    
    /// Removes a player and its associated view
    /// - Parameter sender: The button that triggered the action
    @objc func removePlayer(_ sender: NSButton) {
        guard let playerView = sender.superview,
              let index = playerViews.firstIndex(of: playerView) else {
            return
        }
        
        players.remove(at: index)
        playerView.removeFromSuperview()
        playerViews.remove(at: index)
        
        // Update content view height
        updateContentViewHeight()
        
        // Force layout update
        view.layoutSubtreeIfNeeded()
    }

    /// Handles changes in the navigation bar (seek)
    /// - Parameter sender: The slider that triggered the action
    @objc func navigationBarChanged(_ sender: NSSlider) {
        guard let playerView = sender.superview,
              let index = playerViews.firstIndex(of: playerView) else {
            return
        }
        
        let player = players[index]
        player.seek(to: sender.doubleValue)
        updatePlayerView(playerView: playerView, player: player)
    }

    /// Decreases the pitch of the track
    /// - Parameter sender: The button that triggered the action
    @objc func decreasePitch(_ sender: NSButton) {
        guard let playerView = sender.superview,
              let index = playerViews.firstIndex(of: playerView) else {
            return
        }
        
        let player = players[index]
        player.changePitch(by: -1)
        updatePlayerView(playerView: playerView, player: player)
    }

    /// Increases the pitch of the track
    /// - Parameter sender: The button that triggered the action
    @objc func increasePitch(_ sender: NSButton) {
        guard let playerView = sender.superview,
              let index = playerViews.firstIndex(of: playerView) else {
            return
        }
        
        let player = players[index]
        player.changePitch(by: 1)
        updatePlayerView(playerView: playerView, player: player)
    }

    // MARK: - Helper Methods

    /// Updates all player views
    func updateAllPlayerViews() {
        for (index, playerView) in playerViews.enumerated() {
            let player = players[index]
            updatePlayerView(playerView: playerView, player: player)
        }
    }

    /// Updates a specific player view with current player information
    /// - Parameters:
    ///   - playerView: The view to update
    ///   - player: The associated Player instance
    func updatePlayerView(playerView: NSView, player: Player) {
        if let navigationBar = playerView.subviews.first(where: { $0 is NSSlider }) as? NSSlider {
            navigationBar.maxValue = player.duration
            navigationBar.doubleValue = player.currentTime
        }

        if let waveformView = playerView.subviews.first(where: { $0 is WaveformView }) as? WaveformView {
            waveformView.updateWaveform(with: player.waveformData)
        }

        if let infoLabel = playerView.subviews.first(where: { $0 is NSTextField }) as? NSTextField {
            if player.isLoaded {
                let remainingTime = Int(player.remainingTime)
                let minutes = remainingTime / 60
                let seconds = remainingTime % 60
                infoLabel.stringValue = String(format: "BPM: %.0f | Length: %.0f:%.0f | Remaining: %02d:%02d",
                                               player.bpm,
                                               floor(player.length / 60), player.length.truncatingRemainder(dividingBy: 60),
                                               minutes, seconds)
            } else {
                infoLabel.stringValue = "Loading..."
            }
        }

        if let pitchLabel = playerView.subviews.last as? NSTextField {
            pitchLabel.stringValue = String(format: "Pitch: %.1f", player.pitch)
        }
    }

    /// Creates a button with specified title and action
    /// - Parameters:
    ///   - title: The button title
    ///   - action: The action to perform when the button is clicked
    /// - Returns: A configured NSButton
    private func createButton(title: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        return button
    }

    /// Creates a label with specified text
    /// - Parameter text: The text to display in the label
    /// - Returns: A configured NSTextField
    private func createLabel(text: String) -> NSTextField {
        let label = NSTextField()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = text
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.cell?.wraps = false
        label.cell?.isScrollable = true
        return label
    }

    /// Updates the content view height based on the number of player views
    private func updateContentViewHeight() {
        let newHeight = max(CGFloat(playerViews.count) * 250, scrollView.frame.height)
        
        // Remove existing height constraint if any
        if let existingConstraint = contentView.constraints.first(where: { $0.firstAttribute == .height }) {
            contentView.removeConstraint(existingConstraint)
        }
        
        // Add new height constraint
        contentView.heightAnchor.constraint(equalToConstant: newHeight).isActive = true
        
        // Update scroll view's document view
        scrollView.documentView?.frame.size.height = newHeight
    }

    /// Scrolls the scroll view to the bottom
    private func scrollToBottom() {
        let bottomPoint = NSPoint(x: 0, y: max(0, contentView.frame.height - scrollView.contentView.bounds.height))
        scrollView.contentView.scroll(bottomPoint)
    }
}
