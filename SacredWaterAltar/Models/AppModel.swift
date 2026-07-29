import Foundation
import Observation
import RealityKit
import UIKit

enum ViewState {
    case portal
    case immersive
}

enum ImmersiveSpaceState {
    case closed
    case inTransition
    case open
}

enum AssetLoadState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

@Observable
@MainActor
final class AppModel {
    var viewState: ViewState = .portal
    var immersiveSpaceState: ImmersiveSpaceState = .closed
    var assetLoadState: AssetLoadState = .idle
    var loadWarnings: [String] = []
    var showCredits = false

    let shrineRoot = Entity()
    private(set) var isShrineBuilt = false
    private var bowlEntities: [Entity] = []
    private var waterEntities: [Entity] = []
    private var lastStrikeTimes: [Int: Date] = [:]
    private var ambientTasks: [Task<Void, Never>] = []
    private var audioResources: [AudioFileResource] = []

    private let strikeCooldown: TimeInterval = 0.45

    func prepareAssetsIfNeeded() async {
        guard assetLoadState == .idle || isFailure(assetLoadState) else { return }
        assetLoadState = .loading
        loadWarnings.removeAll()

        do {
            try await buildShrineIfNeeded()
            assetLoadState = .ready
        } catch {
            assetLoadState = .failed(error.localizedDescription)
        }
    }

    func enterAltar() {
        guard assetLoadState == .ready || isShrineBuilt else { return }
        viewState = .immersive
    }

    func exitAltar() {
        viewState = .portal
    }

    func handleBackground() {
        if immersiveSpaceState == .open {
            viewState = .portal
        }
    }

    func strikeBowl(index: Int) {
        guard bowlEntities.indices.contains(index) else { return }
        let now = Date()
        if let last = lastStrikeTimes[index], now.timeIntervalSince(last) < strikeCooldown {
            return
        }
        lastStrikeTimes[index] = now

        let bowl = bowlEntities[index]
        playTone(index: index, on: bowl)
        emitRipples(around: waterEntities[safe: index] ?? bowl)
        pulseWater(waterEntities[safe: index])
        pulseBowl(bowl)
    }

    // MARK: - Build

    private func buildShrineIfNeeded() async throws {
        guard !isShrineBuilt else { return }

        shrineRoot.name = "ShrineRoot"
        shrineRoot.children.removeAll()
        bowlEntities.removeAll()
        waterEntities.removeAll()
        cancelAmbientTasks()

        // Place the whole shrine a comfortable distance in front of the user.
        shrineRoot.position = SIMD3(0, 0, -0.15)

        shrineRoot.addChild(ShrineBuilder.makeEnvironment())
        shrineRoot.addChild(ShrineBuilder.makeAltar())

        async let goldenTask = loadResult(named: "Golden_Buddha_Statue", targetHeight: 0.58, style: .original)
        async let seatedTask = loadResult(named: "1973", targetHeight: 0.42, style: .original)
        async let vajraTask = loadResult(named: "Vajrasattva_Full", targetHeight: 0.50, style: .bronzeGold)
        async let bowlTask = loadResult(named: "Tibetan_Singing_Bowl", targetHeight: 0.08, style: .original)

        let golden = await goldenTask
        let seated = await seatedTask
        let vajra = await vajraTask
        let bowl = await bowlTask

        switch golden {
        case .success(let entity):
            placeAnchored(entity, at: SIMD3(0, 0.74, -1.49), name: "GoldenBuddha")
        case .failure(let error):
            loadWarnings.append("Golden Buddha failed: \(error.localizedDescription)")
        }

        switch seated {
        case .success(let entity):
            placeAnchored(entity, at: SIMD3(-0.48, 0.74, -1.47), name: "SeatedBuddha1973")
        case .failure(let error):
            loadWarnings.append("Seated Buddha failed: \(error.localizedDescription)")
        }

        switch vajra {
        case .success(let entity):
            placeAnchored(entity, at: SIMD3(0.48, 0.74, -1.47), name: "Vajrasattva")
        case .failure(let error):
            loadWarnings.append("Vajrasattva failed: \(error.localizedDescription)")
        }

        switch bowl {
        case .success(let template):
            try await prepareAudioResources()
            placeBowls(using: template)
        case .failure(let error):
            loadWarnings.append("Singing bowls failed: \(error.localizedDescription)")
        }

        let loadedAny =
            golden.isSuccess || seated.isSuccess || vajra.isSuccess || bowl.isSuccess
        guard loadedAny else {
            throw ShrineError.noAssetsLoaded
        }

        isShrineBuilt = true
    }

    private func placeAnchored(_ entity: Entity, at position: SIMD3<Float>, name: String) {
        let anchor = Entity()
        anchor.name = "\(name)_Anchor"
        anchor.position = position
        entity.name = name
        // Reset local pose; normalize already planted the mesh on y = 0.
        entity.position = .zero
        replantOnGround(entity)
        anchor.addChild(entity)
        shrineRoot.addChild(anchor)
    }

    private func placeBowls(using template: Entity) {
        let count = 7
        let spacing: Float = 0.24
        let startX = -spacing * Float(count - 1) / 2
        let altarTopY: Float = 0.735
        let bowlZ: Float = -1.20

        for index in 0..<count {
            let bowl = template.clone(recursive: true)
            let anchor = Entity()
            anchor.name = "BowlAnchor_\(index + 1)"
            anchor.position = SIMD3(startX + spacing * Float(index), altarTopY, bowlZ)

            bowl.name = "Bowl_\(index + 1)"
            bowl.position = .zero
            bowl.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            replantOnGround(bowl)
            makeImportedMaterialsOpaqueAndDoubleSided(on: bowl)
            configureBowlInteraction(bowl, index: index)

            // Parent the USDZ first, then measure it in anchor coordinates. The USDZ root carries
            // a tiny normalization scale; adding the fill beneath that root made it microscopic.
            anchor.addChild(bowl)
            let bowlBounds = bowl.visualBounds(recursive: true, relativeTo: anchor)
            let fillRadius = max(0.018, min(bowlBounds.extents.x, bowlBounds.extents.z) * 0.42)
            let fillHeight = max(0.025, bowlBounds.extents.y * 0.75)
            let center = bowlBounds.center

            // Opaque fill plugs the holey photogrammetry shell so the altar cannot show through.
            let fill = ShrineBuilder.makeBowlCore(
                radius: fillRadius,
                height: fillHeight,
                index: index
            )
            fill.position = SIMD3(
                center.x,
                bowlBounds.min.y + fillHeight * 0.5,
                center.z
            )
            anchor.addChild(fill)

            // Keep water well inside the opening so it doesn't cover the rear rim.
            let water = ShrineBuilder.makeWaterSurface(radius: fillRadius * 0.70, index: index)
            water.position = SIMD3(
                center.x,
                bowlBounds.min.y + fillHeight * 0.76,
                center.z
            )
            anchor.addChild(water)

            shrineRoot.addChild(anchor)
            bowlEntities.append(bowl)
            waterEntities.append(water)
            startAmbientWaterMotion(for: water, index: index)
        }
    }

    private func configureBowlInteraction(_ bowl: Entity, index: Int) {
        let bounds = bowl.visualBounds(recursive: true, relativeTo: bowl)
        let shape = ShapeResource.generateBox(size: bounds.extents + SIMD3(repeating: 0.03))
            .offsetBy(translation: bounds.center)
        bowl.components.set(CollisionComponent(shapes: [shape], mode: .trigger))
        bowl.components.set(InputTargetComponent())
        // Avoid HoverEffect — in mixed immersion it can read as a translucent wash.
        bowl.components.set(BowlIndexComponent(index: index))
        bowl.components.set(GroundingShadowComponent(castsShadow: true))
    }

    private func makeImportedMaterialsOpaqueAndDoubleSided(on entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map { material in
                guard var pbr = material as? PhysicallyBasedMaterial else {
                    return material
                }
                pbr.blending = .opaque
                pbr.faceCulling = .none
                return pbr
            }
            entity.components.set(model)
        }
        for child in entity.children {
            makeImportedMaterialsOpaqueAndDoubleSided(on: child)
        }
    }

    // MARK: - Loading / materials

    private func loadResult(
        named name: String,
        targetHeight: Float,
        style: MaterialStyle
    ) async -> Result<Entity, Error> {
        do {
            return .success(try await loadNormalizedModel(named: name, targetHeight: targetHeight, materialStyle: style))
        } catch {
            return .failure(error)
        }
    }

    private func loadNormalizedModel(
        named name: String,
        targetHeight: Float,
        materialStyle: MaterialStyle
    ) async throws -> Entity {
        // Resource folders may be flattened into the app bundle root by Xcode.
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz")
                ?? Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "Models") else {
            throw ShrineError.missingAsset(name)
        }

        let entity = try await Entity(contentsOf: url)
        entity.name = name
        normalize(entity, targetHeight: targetHeight)

        if materialStyle == .bronzeGold {
            applyBronzeGoldMaterial(to: entity)
        }

        entity.components.set(GroundingShadowComponent(castsShadow: true))
        return entity
    }

    private func normalize(_ entity: Entity, targetHeight: Float) {
        entity.scale = .one
        entity.position = .zero
        entity.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

        var bounds = entity.visualBounds(recursive: true, relativeTo: nil)
        let height = max(bounds.extents.y, 0.001)
        let scale = targetHeight / height
        entity.scale = SIMD3(repeating: scale)
        replantOnGround(entity)
    }

    private func replantOnGround(_ entity: Entity) {
        // Use nil so this works before the entity is parented into the shrine.
        let bounds = entity.visualBounds(recursive: true, relativeTo: nil)
        entity.position.x -= bounds.center.x
        entity.position.y -= bounds.min.y
        entity.position.z -= bounds.center.z
    }

    private func applyBronzeGoldMaterial(to entity: Entity) {
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor(red: 0.82, green: 0.66, blue: 0.28, alpha: 1))
        material.metallic = .float(0.85)
        material.roughness = .float(0.35)
        applyMaterialRecursively(material, to: entity)
    }

    private func applyMaterialRecursively(_ material: SimpleMaterial, to entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = Array(repeating: material, count: max(model.materials.count, 1))
            entity.components.set(model)
        }
        for child in entity.children {
            applyMaterialRecursively(material, to: child)
        }
    }

    // MARK: - Audio / interaction effects

    private func prepareAudioResources() async throws {
        audioResources.removeAll()
        for index in 1...7 {
            let name = "bowl_tone_\(index)"
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav")
                    ?? Bundle.main.url(forResource: name, withExtension: "wav", subdirectory: "Audio") else {
                throw ShrineError.missingAsset(name)
            }
            let resource = try await AudioFileResource(contentsOf: url)
            audioResources.append(resource)
        }
    }

    private func playTone(index: Int, on entity: Entity) {
        guard audioResources.indices.contains(index) else { return }
        let controller = entity.playAudio(audioResources[index])
        controller.gain = -6
    }

    private func emitRipples(around water: Entity) {
        Task { @MainActor in
            for ring in 0..<3 {
                let ripple = ShrineBuilder.makeRippleRing(radius: 0.008)
                ripple.position = SIMD3(0, 0.002 + Float(ring) * 0.001, 0)
                water.addChild(ripple)

                let delay = Double(ring) * 0.08
                try? await Task.sleep(for: .seconds(delay))

                var transform = ripple.transform
                transform.scale = SIMD3(repeating: 3.4)
                ripple.move(to: transform, relativeTo: water, duration: 0.9, timingFunction: .easeOut)

                if var model = ripple.components[ModelComponent.self] {
                    var material = SimpleMaterial()
                    material.color = .init(tint: UIColor(red: 0.55, green: 0.78, blue: 0.95, alpha: 0.05))
                    material.roughness = .float(0.2)
                    model.materials = [material]
                    ripple.components.set(model)
                }

                try? await Task.sleep(for: .seconds(0.95))
                ripple.removeFromParent()
            }
        }
    }

    private func pulseWater(_ water: Entity?) {
        guard let water else { return }
        let original = water.transform
        var up = original
        up.scale = SIMD3(1.08, 1.0, 1.08)
        water.move(to: up, relativeTo: water.parent, duration: 0.12, timingFunction: .easeOut)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.12))
            water.move(to: original, relativeTo: water.parent, duration: 0.35, timingFunction: .easeInOut)
        }
    }

    private func pulseBowl(_ bowl: Entity) {
        let original = bowl.transform
        var nudged = original
        nudged.rotation = original.rotation * simd_quatf(angle: 0.035, axis: SIMD3(1, 0, 0.1))
        bowl.move(to: nudged, relativeTo: bowl.parent, duration: 0.08, timingFunction: .easeOut)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.08))
            bowl.move(to: original, relativeTo: bowl.parent, duration: 0.28, timingFunction: .easeInOut)
        }
    }

    private func startAmbientWaterMotion(for water: Entity, index: Int) {
        let task = Task { @MainActor in
            let base = water.transform
            var phase: Float = Float(index) * 0.7
            while !Task.isCancelled {
                phase += 0.035
                var next = base
                let bob = sin(phase) * 0.0012
                let breathe = 1.0 + sin(phase * 0.85) * 0.012
                next.translation.y = base.translation.y + bob
                next.scale = SIMD3(breathe, 1, breathe)
                water.transform = next
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
        ambientTasks.append(task)
    }

    private func cancelAmbientTasks() {
        for task in ambientTasks {
            task.cancel()
        }
        ambientTasks.removeAll()
    }

    private func isFailure(_ state: AssetLoadState) -> Bool {
        if case .failed = state { return true }
        return false
    }
}

private enum MaterialStyle {
    case original
    case bronzeGold
}

enum ShrineError: LocalizedError {
    case missingAsset(String)
    case noAssetsLoaded

    var errorDescription: String? {
        switch self {
        case .missingAsset(let name):
            return "Missing asset: \(name)"
        case .noAssetsLoaded:
            return "No shrine assets could be loaded."
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
