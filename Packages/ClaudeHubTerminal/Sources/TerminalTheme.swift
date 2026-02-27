import AppKit
import SwiftTerm

/// Color schemes and font configuration for the terminal.
public struct TerminalTheme {
    public let name: String
    public let background: NSColor
    public let foreground: NSColor
    public let cursor: NSColor
    public let selectionColor: NSColor
    public let ansiColors: [NSColor]  // 16 ANSI colors
    public let fontName: String
    public let fontSize: CGFloat

    public static let defaultFontName = "Menlo"
    public static let defaultFontSize: CGFloat = 13.0

    /// Dark theme inspired by VS Code's default terminal
    public static let dark = TerminalTheme(
        name: "Dark",
        background: NSColor(red: 0.067, green: 0.067, blue: 0.078, alpha: 1.0),  // #111114
        foreground: NSColor(red: 0.847, green: 0.855, blue: 0.878, alpha: 1.0),  // #D8DAE0
        cursor: NSColor(red: 0.847, green: 0.855, blue: 0.878, alpha: 1.0),
        selectionColor: NSColor(red: 0.263, green: 0.282, blue: 0.353, alpha: 0.5),
        ansiColors: [
            NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),       // Black
            NSColor(red: 0.804, green: 0.243, blue: 0.243, alpha: 1.0), // Red
            NSColor(red: 0.357, green: 0.682, blue: 0.373, alpha: 1.0), // Green
            NSColor(red: 0.851, green: 0.733, blue: 0.400, alpha: 1.0), // Yellow
            NSColor(red: 0.361, green: 0.545, blue: 0.863, alpha: 1.0), // Blue
            NSColor(red: 0.698, green: 0.404, blue: 0.769, alpha: 1.0), // Magenta
            NSColor(red: 0.318, green: 0.706, blue: 0.741, alpha: 1.0), // Cyan
            NSColor(red: 0.847, green: 0.855, blue: 0.878, alpha: 1.0), // White
            // Bright variants
            NSColor(red: 0.400, green: 0.400, blue: 0.400, alpha: 1.0), // Bright Black
            NSColor(red: 0.925, green: 0.365, blue: 0.365, alpha: 1.0), // Bright Red
            NSColor(red: 0.471, green: 0.824, blue: 0.490, alpha: 1.0), // Bright Green
            NSColor(red: 0.957, green: 0.863, blue: 0.518, alpha: 1.0), // Bright Yellow
            NSColor(red: 0.482, green: 0.667, blue: 0.969, alpha: 1.0), // Bright Blue
            NSColor(red: 0.816, green: 0.525, blue: 0.890, alpha: 1.0), // Bright Magenta
            NSColor(red: 0.439, green: 0.824, blue: 0.859, alpha: 1.0), // Bright Cyan
            NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),       // Bright White
        ],
        fontName: defaultFontName,
        fontSize: defaultFontSize
    )

    /// Light theme
    public static let light = TerminalTheme(
        name: "Light",
        background: NSColor(red: 0.976, green: 0.976, blue: 0.976, alpha: 1.0),
        foreground: NSColor(red: 0.149, green: 0.149, blue: 0.161, alpha: 1.0),
        cursor: NSColor(red: 0.149, green: 0.149, blue: 0.161, alpha: 1.0),
        selectionColor: NSColor(red: 0.678, green: 0.745, blue: 0.882, alpha: 0.5),
        ansiColors: [
            NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.698, green: 0.133, blue: 0.133, alpha: 1.0),
            NSColor(red: 0.133, green: 0.545, blue: 0.133, alpha: 1.0),
            NSColor(red: 0.604, green: 0.533, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.0, green: 0.0, blue: 0.804, alpha: 1.0),
            NSColor(red: 0.502, green: 0.0, blue: 0.502, alpha: 1.0),
            NSColor(red: 0.0, green: 0.545, blue: 0.545, alpha: 1.0),
            NSColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1.0),
            NSColor(red: 0.498, green: 0.498, blue: 0.498, alpha: 1.0),
            NSColor(red: 0.804, green: 0.243, blue: 0.243, alpha: 1.0),
            NSColor(red: 0.243, green: 0.682, blue: 0.243, alpha: 1.0),
            NSColor(red: 0.749, green: 0.682, blue: 0.0, alpha: 1.0),
            NSColor(red: 0.337, green: 0.467, blue: 0.878, alpha: 1.0),
            NSColor(red: 0.667, green: 0.333, blue: 0.667, alpha: 1.0),
            NSColor(red: 0.333, green: 0.682, blue: 0.682, alpha: 1.0),
            NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
        ],
        fontName: defaultFontName,
        fontSize: defaultFontSize
    )

    public var font: NSFont {
        NSFont(name: fontName, size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    public func withFontSize(_ size: CGFloat) -> TerminalTheme {
        TerminalTheme(
            name: name,
            background: background,
            foreground: foreground,
            cursor: cursor,
            selectionColor: selectionColor,
            ansiColors: ansiColors,
            fontName: fontName,
            fontSize: size
        )
    }
}
