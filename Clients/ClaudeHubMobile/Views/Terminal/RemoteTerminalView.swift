import SwiftTerm
import SwiftUI
import UIKit

struct RemoteTerminalView: UIViewRepresentable {
    let transcript: String
    let onInitialSize: (Int, Int) -> Void
    let onInput: (String) -> Void
    let onResize: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onInitialSize: onInitialSize,
            onInput: onInput,
            onResize: onResize
        )
    }

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView(frame: .zero)
        view.terminalDelegate = context.coordinator
        view.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.09, alpha: 1.0)
        view.nativeBackgroundColor = .clear
        view.nativeForegroundColor = UIColor(red: 0.82, green: 0.88, blue: 0.92, alpha: 1.0)
        view.caretColor = UIColor(red: 0.22, green: 0.9, blue: 0.47, alpha: 1.0)
        view.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        view.optionAsMetaKey = false
        view.allowMouseReporting = false
        context.coordinator.render(transcript, in: view)
        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        context.coordinator.render(transcript, in: uiView)
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        private let onInitialSize: (Int, Int) -> Void
        private let onInput: (String) -> Void
        private let onResize: (Int, Int) -> Void
        private var lastTranscript = ""
        private var lastSize: (Int, Int)?
        private var hasSentInitialSize = false

        init(
            onInitialSize: @escaping (Int, Int) -> Void,
            onInput: @escaping (String) -> Void,
            onResize: @escaping (Int, Int) -> Void
        ) {
            self.onInitialSize = onInitialSize
            self.onInput = onInput
            self.onResize = onResize
        }

        func render(_ transcript: String, in terminalView: TerminalView) {
            guard transcript != lastTranscript else { return }

            if transcript.hasPrefix(lastTranscript) {
                let delta = String(transcript.dropFirst(lastTranscript.count))
                if !delta.isEmpty {
                    terminalView.feed(text: delta)
                }
            } else {
                terminalView.feed(text: "\u{001B}c")
                terminalView.feed(text: transcript)
            }

            lastTranscript = transcript
        }

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let text = String(decoding: data, as: UTF8.self)
            guard !text.isEmpty else { return }
            onInput(text)
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            let size = (newCols, newRows)
            if let lastSize, lastSize == size {
                return
            }
            lastSize = size
            if !hasSentInitialSize {
                hasSentInitialSize = true
                onInitialSize(newCols, newRows)
                return
            }
            onResize(newCols, newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {
        }

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        }

        func scrolled(source: TerminalView, position: Double) {
        }

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        }

        func clipboardCopy(source: TerminalView, content: Data) {
        }

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        }
    }
}
