//
//  AppSettings.swift
//  ChordProMac
//
//  Created by Nick Berendsen on 27/05/2024.
//

import Foundation

/// All the settings for the application
struct AppSettings: Codable, Equatable {

    // MARK: Fonts

    /// The font style of the editor
    var fontStyle: FontStyle = .monospaced
    /// The font size of the editor
    var fontSize: Double = 14

    // MARK: Templates

    /// Bool to use an additional library
    var useAdditionalLibrary: Bool = false

    /// Bool to use a custom song template
    var useCustomSongTemplate: Bool = false

    /// Bool to use a custom config instead of system
    var useCustomConfig: Bool = false
    /// The system config to use
    var systemConfig: String = "guitar"
    /// Optional custom config URL
    var customConfig: URL?
    /// The label to show in the ``StatusView``
    var configLabel: String {
        if useCustomConfig, let url = try? FileBookmark.getBookmarkURL(CustomFile.customConfig) {
            return url.lastPathComponent
        }
        return systemConfig
    }

    /// Bool not to use default configurations
    var noDefaultConfigs: Bool = false

    // MARK: Transpose

    /// Bool if the song should be transcoded
    var transcode: Bool = false
    /// The optional transcode to use
    var transcodeNotation: String = "common"

    // MARK: Transpose

    /// Bool if the song should be transposed
    var transpose: Bool = false
    /// The note to transpose from
    var transposeFrom: Note = .c
    /// The note to transpose to
    var transposeTo: Note = .c
    /// The transpose accents
    var transposeAccents: Accents = .defaults
    /// The calculated optional transpose value
    var transposeValue: Int? {
        guard
            let fromNote = Note.noteValueDict[transposeFrom],
            let toNote = Note.noteValueDict[transposeTo]
        else {
            return nil
        }
        var transpose: Int = toNote - fromNote
        transpose += transpose < 0 ? 12 : 0
        switch transposeAccents {
        case .defaults:
            break
        case .sharps:
            transpose += 12
        case .flats:
            transpose -= 12
        }
        return transpose == 0 ? nil : transpose
    }

    // MARK: Other

    /// Show only lyrics
    var lyricsOnly: Bool = false
    /// Suppress chord diagrams
    var noChordGrids: Bool = false
    /// Eliminate capo settings by transposing the song
    var deCapo: Bool = false
}

extension AppSettings {

    /// Load the application settings
    /// - Returns: The ``AppSettings``
    static func load() -> AppSettings {
        if let settings = try? Cache.get(key: "ChordProMacSettings", struct: AppSettings.self) {
            return settings
        }
        /// No settings found; return defaults
        return AppSettings()
    }

    /// Save the application settings to the cache
    /// - Parameter settings: The ``AppSettings``
    static func save(settings: AppSettings) throws {
        do {
            try Cache.set(key: "ChordProMacSettings", object: settings)
        } catch {
            throw AppError.saveSettingsError
        }
    }
}
