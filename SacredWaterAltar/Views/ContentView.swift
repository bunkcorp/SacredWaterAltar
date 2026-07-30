import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Sacred Water Altar")
                        .font(.largeTitle.weight(.semibold))
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                Group {
                    switch appModel.assetLoadState {
                    case .idle, .loading:
                        ProgressView("Preparing shrine assets…")
                            .padding(.vertical, 12)
                    case .ready:
                        Label("Shrine ready", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failed(let message):
                        VStack(spacing: 8) {
                            Label("Could not prepare shrine", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await appModel.prepareAssetsIfNeeded() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if !appModel.loadWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loaded with warnings")
                            .font(.caption.weight(.semibold))
                        ForEach(appModel.loadWarnings, id: \.self) { warning in
                            Text("• \(warning)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How to interact")
                        .font(.headline)
                    ForEach(howToLines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))

                Button {
                    appModel.enterAltar()
                } label: {
                    Text(enterButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appModel.assetLoadState != .ready && !appModel.isShrineBuilt)

                Button("Credits & Licenses") {
                    appModel.showCredits = true
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }
            .padding(28)
#if os(visionOS)
            .frame(minWidth: 460, minHeight: 560)
#endif
            .task {
                await appModel.prepareAssetsIfNeeded()
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-autoEnterAltar"),
                   appModel.assetLoadState == .ready {
                    try? await Task.sleep(for: .seconds(1))
                    appModel.enterAltar()
                }
#endif
            }
            .sheet(isPresented: $appModel.showCredits) {
                CreditsView()
                    .environment(appModel)
            }
#if os(iOS)
            .fullScreenCover(isPresented: phoneShrinePresented) {
                PhoneShrineView()
                    .environment(appModel)
            }
#endif
        }
    }

    private var subtitle: String {
#if os(visionOS)
        "A mixed-reality shrine with three statues and seven offering bowls."
#else
        "A 3D shrine with three statues and seven offering bowls you can explore on iPhone."
#endif
    }

    private var enterButtonTitle: String {
#if os(visionOS)
        "Enter Altar"
#else
        "Open Altar"
#endif
    }

    private var howToLines: [String] {
#if os(visionOS)
        [
            "• Look at a singing bowl and tap to strike it",
            "• Each bowl plays a unique tone and ripples its water",
            "• Use Exit in the immersive space to return here"
        ]
#else
        [
            "• Drag to orbit the shrine",
            "• Pinch to zoom in and out",
            "• Tap a singing bowl to strike its tone and ripples"
        ]
#endif
    }

#if os(iOS)
    private var phoneShrinePresented: Binding<Bool> {
        Binding(
            get: { appModel.viewState == .immersive },
            set: { isPresented in
                if !isPresented {
                    appModel.exitAltar()
                }
            }
        )
    }
#endif
}
