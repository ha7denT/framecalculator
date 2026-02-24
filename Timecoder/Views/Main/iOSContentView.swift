#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// iOS-specific content view with adaptive layout for iPhone and iPad.
struct iOSContentView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var calculatorVM: CalculatorViewModel
    @ObservedObject var playerVM: VideoPlayerViewModel
    @ObservedObject var markerVM: MarkerListViewModel

    /// Callback to open or restore a video session.
    var onOpenVideoOrRestore: () -> Void

    /// Callback to switch to calculator mode (preserving session).
    var onSwitchToCalculator: () -> Void

    /// Callback to open the file importer.
    var onOpenVideoFile: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingSettings = false

    var body: some View {
        Group {
            switch appState.mode {
            case .calculator:
                calculatorModeView

            case .videoInspector:
                videoModeView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.mode)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                PreferencesView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSettings)) { _ in
            showingSettings = true
        }
    }

    // MARK: - Calculator Mode

    private var calculatorModeView: some View {
        NavigationStack {
            CalculatorView(
                viewModel: calculatorVM,
                modeButtonIcon: appState.hasStoredSession ? "film.stack" : "play.rectangle",
                modeButtonHelp: appState.hasStoredSession ? "Return to video" : "Open video",
                onModeButtonTapped: onOpenVideoOrRestore
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
    }

    // MARK: - Video Mode

    private var videoModeView: some View {
        Group {
            if horizontalSizeClass == .compact {
                iPhoneVideoLayout
            } else {
                iPadVideoLayout
            }
        }
    }

    // MARK: - iPhone Video Layout (Stacked)

    private var iPhoneVideoLayout: some View {
        iOSVideoInspectorView(
            appState: appState,
            calculatorVM: calculatorVM,
            playerVM: playerVM,
            markerVM: markerVM,
            isCompact: true,
            onSwitchToCalculator: onSwitchToCalculator
        )
    }

    // MARK: - iPad Video Layout (Side-by-Side)

    private var iPadVideoLayout: some View {
        iOSVideoInspectorView(
            appState: appState,
            calculatorVM: calculatorVM,
            playerVM: playerVM,
            markerVM: markerVM,
            isCompact: false,
            onSwitchToCalculator: onSwitchToCalculator
        )
    }
}
#endif
