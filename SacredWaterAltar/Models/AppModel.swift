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
    private var bowlGroups: [Entity] = []
    private var waterEntities: [Entity] = []
    private var rippleHosts: [Entity] = []
    private var rippleRadii: [Float] = []
    private var strikeEnergy: [Float] = []
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

        let group = bowlGroups[safe: index] ?? bowlEntities[index]
        playTone(index: index, on: group)
        emitRipples(index: index)
        // The ambient loop owns the water transform; a strike just adds energy for it to spend.
        if strikeEnergy.indices.contains(index) {
            strikeEnergy[index] = 1
        }
        pulseGroup(group)
    }

    // MARK: - Build

    private func buildShrineIfNeeded() async throws {
        guard !isShrineBuilt else { return }

        shrineRoot.name = "ShrineRoot"
        shrineRoot.children.removeAll()
        bowlEntities.removeAll()
        bowlGroups.removeAll()
        waterEntities.removeAll()
        rippleHosts.removeAll()
        rippleRadii.removeAll()
        strikeEnergy.removeAll()
        cancelAmbientTasks()

        // Place the whole shrine a comfortable distance in front of the user.
        shrineRoot.position = SIMD3(0, 0, -0.15)

        shrineRoot.addChild(ShrineBuilder.makeEnvironment())
        shrineRoot.addChild(ShrineBuilder.makeAltar())

        async let goldenTask = loadResult(named: "Golden_Buddha_Statue", targetHeight: 0.58, style: .original)
        async let seatedTask = loadResult(named: "1973", targetHeight: 0.42, style: .original)
        async let vajraTask = loadResult(named: "Vajrasattva_Full", targetHeight: 0.50, style: .bronzeGold)
        async let bowlTask = loadResult(named: "Tibetan_Singing_Bowl", targetHeight: 0.08, style: .original)
        async let medicineTask = loadMantraResult(named: "Medicine_Buddha_Mantra_Wheel", targetSize: 0.20)
        async let omManiTask = loadMantraResult(named: "Om_Mani_Padme_Hum_Mantra_with_Lotus", targetSize: 0.15)
        async let taraTask = loadMantraResult(named: "Green_Tara_Mantra", targetSize: 0.20)

        let golden = await goldenTask
        let seated = await seatedTask
        let vajra = await vajraTask
        let bowl = await bowlTask
        let medicine = await medicineTask
        let omMani = await omManiTask
        let tara = await taraTask

        switch golden {
        case .success(let entity):
            placeAnchored(entity, at: SIMD3(0, 0.74, -1.63), name: "GoldenBuddha")
        case .failure(let error):
            loadWarnings.append("Golden Buddha failed: \(error.localizedDescription)")
        }

        switch seated {
        case .success(let entity):
            placeAnchored(entity, at: SIMD3(-0.62, 0.74, -1.61), name: "SeatedBuddha1973")
        case .failure(let error):
            loadWarnings.append("Seated Buddha failed: \(error.localizedDescription)")
        }

        switch vajra {
        case .success(let entity):
            placeAnchored(entity, at: SIMD3(0.80, 0.74, -1.66), name: "Vajrasattva")
        case .failure(let error):
            loadWarnings.append("Vajrasattva failed: \(error.localizedDescription)")
        }

        // Evenly centered middle row, pulled toward the bowls so it stays clear of the statues.
        placeMantra(medicine, at: SIMD3(-0.42, 0.735, -1.25), name: "MedicineBuddhaMantra", spin: true)
        placeMantra(omMani, at: SIMD3(0, 0.735, -1.25), name: "OmManiPadmeHum", spin: true)
        placeMantra(tara, at: SIMD3(0.42, 0.735, -1.25), name: "GreenTaraMantra", spin: true)

        switch bowl {
        case .success(let template):
            try await prepareAudioResources()
            placeBowls(using: template)
        case .failure(let error):
            loadWarnings.append("Singing bowls failed: \(error.localizedDescription)")
        }

        let loadedAny =
            golden.isSuccess || seated.isSuccess || vajra.isSuccess || bowl.isSuccess
            || medicine.isSuccess || omMani.isSuccess || tara.isSuccess
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

    private func placeMantra(
        _ result: Result<Entity, Error>,
        at position: SIMD3<Float>,
        name: String,
        spin: Bool
    ) {
        switch result {
        case .success(let entity):
            let anchor = Entity()
            anchor.name = "\(name)_Anchor"
            anchor.position = position

            entity.name = name
            entity.position = .zero
            replantOnGround(entity)
            // Keep authored mantra colors/emissive — don't force the bowl-shell material pass.
            entity.components.set(GroundingShadowComponent(castsShadow: true))

            anchor.addChild(entity)
            shrineRoot.addChild(anchor)

            if spin {
                // Green Tara's USDZ was authored in the opposite direction from the other
                // two wheels. Reverse its playback so every mantra turns clockwise together.
                let playbackSpeed: Float = name == "GreenTaraMantra" ? -0.4 : 0.4
                playMantraAnimation(on: entity, speed: playbackSpeed)
            }
        case .failure(let error):
            loadWarnings.append("\(name) failed: \(error.localizedDescription)")
        }
    }

    private func playMantraAnimation(on entity: Entity, speed: Float) {
        // Prefer the authored Sketchfab spin; it keeps the letter ring posed correctly.
        if let animation = entity.availableAnimations.first {
            let controller = entity.playAnimation(animation.repeat())
            controller.speed = speed
            return
        }
        for child in entity.children {
            playMantraAnimation(on: child, speed: speed)
        }
    }

    private func placeBowls(using template: Entity) {
        let count = 7
        let spacing: Float = 0.28
        let startX = -spacing * Float(count - 1) / 2
        let altarTopY: Float = 0.735
        let bowlZ: Float = -1.06

        for index in 0..<count {
            let bowl = template.clone(recursive: true)
            let anchor = Entity()
            anchor.name = "BowlAnchor_\(index + 1)"
            anchor.position = SIMD3(startX + spacing * Float(index), altarTopY, bowlZ)

            // Shell, fill, and water all hang off this node so a strike animates them as one
            // object, pivoting at the bowl's base instead of the USDZ root's far-off origin.
            let group = Entity()
            group.name = "BowlGroup_\(index + 1)"
            anchor.addChild(group)

            bowl.name = "Bowl_\(index + 1)"
            bowl.position = .zero
            bowl.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            replantOnGround(bowl)
            makeImportedMaterialsOpaqueAndDoubleSided(on: bowl)
            bowl.components.set(GroundingShadowComponent(castsShadow: true))

            // Parent the USDZ first, then measure it in group coordinates. The USDZ root carries
            // a tiny normalization scale; adding the fill beneath that root made it microscopic.
            group.addChild(bowl)
            let bowlBounds = bowl.visualBounds(recursive: true, relativeTo: group)
            let fillRadius = max(0.018, min(bowlBounds.extents.x, bowlBounds.extents.z) * 0.42)
            let fillHeight = max(0.025, bowlBounds.extents.y * 0.75)
            let center = bowlBounds.center

            configureBowlInteraction(on: group, bounds: bowlBounds, index: index)

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
            group.addChild(fill)

            // Keep water well inside the opening so it doesn't cover the rear rim.
            let waterRadius = fillRadius * 0.70
            let waterThickness = max(0.004, waterRadius * 0.16)
            let water = ShrineBuilder.makeWaterSurface(radius: waterRadius, index: index)
            water.position = SIMD3(
                center.x,
                bowlBounds.min.y + fillHeight + waterThickness * 0.5 + 0.0005,
                center.z
            )
            group.addChild(water)

            // Ripples ride a static node just above the water so the water's own bob and
            // breathe animation doesn't scale or drag them around.
            let rippleHost = Entity()
            rippleHost.name = "RippleHost_\(index + 1)"
            rippleHost.position = SIMD3(
                water.position.x,
                water.position.y + waterThickness * 0.5 + 0.0008,
                water.position.z
            )
            group.addChild(rippleHost)

            shrineRoot.addChild(anchor)
            bowlEntities.append(bowl)
            bowlGroups.append(group)
            waterEntities.append(water)
            rippleHosts.append(rippleHost)
            rippleRadii.append(waterRadius * 0.92)
            strikeEnergy.append(0)
            startAmbientWaterMotion(for: water, index: index)
            startAmbientRipples(index: index)
        }
    }

    private func configureBowlInteraction(on group: Entity, bounds: BoundingBox, index: Int) {
        let shape = ShapeResource.generateBox(size: bounds.extents + SIMD3(repeating: 0.03))
            .offsetBy(translation: bounds.center)
        group.components.set(CollisionComponent(shapes: [shape], mode: .trigger))
        group.components.set(InputTargetComponent())
        // Avoid HoverEffect — in mixed immersion it can read as a translucent wash.
        group.components.set(BowlIndexComponent(index: index))
        group.components.set(SpatialAudioComponent(gain: -6))
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

    private func loadMantraResult(named name: String, targetSize: Float) async -> Result<Entity, Error> {
        do {
            return .success(try await loadMantraModel(named: name, targetSize: targetSize))
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

    private func loadMantraModel(named name: String, targetSize: Float) async throws -> Entity {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz")
                ?? Bundle.main.url(forResource: name, withExtension: "usdz", subdirectory: "Models") else {
            throw ShrineError.missingAsset(name)
        }

        let entity = try await Entity(contentsOf: url)
        entity.name = name
        // Use the longest axis so horizontal letter rings and taller lotus pieces both fit.
        normalizeByLargestExtent(entity, targetSize: targetSize)
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

    private func normalizeByLargestExtent(_ entity: Entity, targetSize: Float) {
        entity.scale = .one
        entity.position = .zero
        entity.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

        let bounds = entity.visualBounds(recursive: true, relativeTo: nil)
        let largest = max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.001)
        entity.scale = SIMD3(repeating: targetSize / largest)
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
        entity.playAudio(audioResources[index])
    }

    private func emitRipples(index: Int) {
        guard let host = rippleHosts[safe: index], let maxRadius = rippleRadii[safe: index] else { return }
        Task { @MainActor in
            for ring in 0..<3 {
                spawnRipple(on: host, maxRadius: maxRadius, lift: Float(ring) * 0.0006)
                try? await Task.sleep(for: .seconds(0.09))
            }
        }
    }

    private func spawnRipple(on host: Entity, maxRadius: Float, lift: Float) {
        let startRadius = max(0.002, maxRadius * 0.28)
        let ripple = ShrineBuilder.makeRippleRing(radius: startRadius)
        ripple.position = SIMD3(0, lift, 0)
        host.addChild(ripple)

        var grown = ripple.transform
        grown.scale = SIMD3(repeating: maxRadius / startRadius)
        ripple.move(to: grown, relativeTo: host, duration: 0.85, timingFunction: .easeOut)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.85))
            ripple.removeFromParent()
        }
    }

    private func pulseGroup(_ group: Entity) {
        var tipped = Transform()
        tipped.rotation = simd_quatf(angle: 0.03, axis: SIMD3(1, 0, 0))
        group.move(to: tipped, relativeTo: group.parent, duration: 0.09, timingFunction: .easeOut)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.09))
            group.move(to: Transform(), relativeTo: group.parent, duration: 0.3, timingFunction: .easeInOut)
        }
    }

    private func startAmbientWaterMotion(for water: Entity, index: Int) {
        let task = Task { @MainActor in
            let base = water.transform
            var phase: Float = Float(index) * 0.7
            while !Task.isCancelled {
                phase += 0.035
                let energy = strikeEnergy[safe: index] ?? 0
                var next = base
                let bob = sin(phase) * 0.0012 + sin(phase * 5.2) * 0.0016 * energy
                let breathe = 1.0 + sin(phase * 0.85) * 0.012 + sin(phase * 4.6) * 0.04 * energy
                next.translation.y = base.translation.y + bob
                next.scale = SIMD3(breathe, 1, breathe)
                water.transform = next
                if strikeEnergy.indices.contains(index) {
                    strikeEnergy[index] = max(0, energy - 0.013)
                }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
        ambientTasks.append(task)
    }

    private func startAmbientRipples(index: Int) {
        guard let host = rippleHosts[safe: index],
              let maxRadius = rippleRadii[safe: index] else { return }

        let task = Task { @MainActor in
            // Stagger the bowls so the altar feels alive without every surface pulsing together.
            try? await Task.sleep(for: .milliseconds(350 * index))
            while !Task.isCancelled {
                spawnRipple(on: host, maxRadius: maxRadius * 0.88, lift: 0)
                let interval = 2.4 + Double(index % 3) * 0.35
                try? await Task.sleep(for: .seconds(interval))
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
