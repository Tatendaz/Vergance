import SwiftUI
import GazeKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Vergance Companion")
                .font(.title2.weight(.bold))
            Text("Streams TrueDepth gaze + face data to the Mac.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Phase 7 — not wired yet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
