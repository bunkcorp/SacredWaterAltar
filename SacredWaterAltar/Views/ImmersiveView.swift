import RealityKit
import SwiftUI

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        RealityView { content in
            if appModel.shrineRoot.parent == nil {
                content.add(appModel.shrineRoot)
            }
        } update: { content in
            if appModel.shrineRoot.parent == nil {
                content.add(appModel.shrineRoot)
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    if let index = bowlIndex(from: value.entity) {
                        appModel.strikeBowl(index: index)
                    }
                }
        )
        .ornament(attachmentAnchor: .scene(.bottom)) {
            ImmersiveControlsView()
        }
        .task {
            await appModel.prepareAssetsIfNeeded()
        }
    }

    private func bowlIndex(from entity: Entity) -> Int? {
        var current: Entity? = entity
        while let node = current {
            if let component = node.components[BowlIndexComponent.self] {
                return component.index
            }
            current = node.parent
        }
        return nil
    }
}
