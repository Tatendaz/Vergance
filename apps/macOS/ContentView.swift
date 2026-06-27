import SwiftUI
import GazeKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "eye")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Vergance")
                .font(.largeTitle.weight(.bold))
            Text("Gaze + voice, fed to Claude.")
                .foregroundStyle(.secondary)
            Text("Phase 1 — webcam probe. Capture pipeline not wired yet.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(minWidth: 460, minHeight: 320)
        .padding()
    }
}

#Preview {
    ContentView()
}
