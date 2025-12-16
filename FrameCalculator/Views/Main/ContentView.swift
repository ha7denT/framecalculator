import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Frame Calculator")
                .font(.title)
            Text("Sprint 1: Core Models Complete")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 320, minHeight: 200)
    }
}

#Preview {
    ContentView()
}
