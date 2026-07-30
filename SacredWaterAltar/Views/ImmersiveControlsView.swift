#if os(visionOS)
import SwiftUI

struct ImmersiveControlsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sacred Water Altar")
                    .font(.headline)
                Text("Tap a bowl to strike its tone")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Exit", systemImage: "xmark.circle.fill") {
                appModel.exitAltar()
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}
#endif
