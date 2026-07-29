import RealityKit
import UIKit

enum ShrineBuilder {
    static func makeEnvironment() -> Entity {
        let root = Entity()
        root.name = "Environment"

        // Soft platform under the shrine.
        let floorMesh = MeshResource.generateBox(width: 2.8, height: 0.02, depth: 2.0, cornerRadius: 0.03)
        var floorMaterial = SimpleMaterial()
        floorMaterial.color = .init(tint: UIColor(red: 0.18, green: 0.14, blue: 0.11, alpha: 1))
        floorMaterial.roughness = .float(0.85)
        let floor = ModelEntity(mesh: floorMesh, materials: [floorMaterial])
        floor.name = "Floor"
        floor.position = SIMD3(0, -0.01, -1.55)
        floor.components.set(GroundingShadowComponent(castsShadow: false))
        root.addChild(floor)

        // Warm rear backdrop — kept thin and behind statues.
        let backdropMesh = MeshResource.generatePlane(width: 2.4, height: 1.5, cornerRadius: 0.03)
        var backdropMaterial = SimpleMaterial()
        backdropMaterial.color = .init(tint: UIColor(red: 0.28, green: 0.16, blue: 0.10, alpha: 1))
        backdropMaterial.roughness = .float(0.92)
        let backdrop = ModelEntity(mesh: backdropMesh, materials: [backdropMaterial])
        backdrop.name = "Backdrop"
        backdrop.position = SIMD3(0, 0.85, -2.45)
        root.addChild(backdrop)

        root.addChild(makePointLight(
            name: "KeyLight",
            color: UIColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 1),
            intensity: 1400,
            radius: 7,
            position: SIMD3(-0.5, 1.8, -0.8)
        ))
        root.addChild(makePointLight(
            name: "FillLight",
            color: UIColor(red: 0.75, green: 0.85, blue: 1.0, alpha: 1),
            intensity: 600,
            radius: 6,
            position: SIMD3(0.8, 1.5, -1.0)
        ))
        root.addChild(makePointLight(
            name: "RimLight",
            color: UIColor(red: 1.0, green: 0.8, blue: 0.55, alpha: 1),
            intensity: 800,
            radius: 5,
            position: SIMD3(0, 1.5, -2.7)
        ))

        return root
    }

    private static func makePointLight(
        name: String,
        color: UIColor,
        intensity: Float,
        radius: Float,
        position: SIMD3<Float>
    ) -> Entity {
        let light = Entity()
        light.name = name
        light.position = position
        light.components.set(
            PointLightComponent(color: color, intensity: intensity, attenuationRadius: radius)
        )
        return light
    }

    static func makeAltar() -> Entity {
        let root = Entity()
        root.name = "Altar"

        var wood = SimpleMaterial()
        wood.color = .init(tint: UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1))
        wood.roughness = .float(0.7)
        wood.metallic = .float(0.05)

        var cloth = SimpleMaterial()
        cloth.color = .init(tint: UIColor(red: 0.55, green: 0.12, blue: 0.12, alpha: 1))
        cloth.roughness = .float(0.8)

        var gold = SimpleMaterial()
        gold.color = .init(tint: UIColor(red: 0.85, green: 0.68, blue: 0.28, alpha: 1))
        gold.metallic = .float(0.9)
        gold.roughness = .float(0.3)

        let base = ModelEntity(
            mesh: .generateBox(width: 2.05, height: 0.68, depth: 0.80, cornerRadius: 0.02),
            materials: [wood]
        )
        base.name = "AltarBase"
        base.position = SIMD3(0, 0.34, -1.35)
        base.components.set(GroundingShadowComponent(castsShadow: true))
        root.addChild(base)

        let top = ModelEntity(
            mesh: .generateBox(width: 2.15, height: 0.04, depth: 0.86, cornerRadius: 0.015),
            materials: [wood]
        )
        top.name = "AltarTop"
        top.position = SIMD3(0, 0.70, -1.35)
        root.addChild(top)

        let runner = ModelEntity(
            mesh: .generateBox(width: 1.92, height: 0.008, depth: 0.66, cornerRadius: 0.004),
            materials: [cloth]
        )
        runner.name = "AltarCloth"
        runner.position = SIMD3(0, 0.725, -1.35)
        root.addChild(runner)

        for x in [-0.985, 0.985] as [Float] {
            let trim = ModelEntity(
                mesh: .generateBox(width: 0.025, height: 0.035, depth: 0.82, cornerRadius: 0.005),
                materials: [gold]
            )
            trim.position = SIMD3(x, 0.715, -1.35)
            root.addChild(trim)
        }

        return root
    }

    static func makeBowlCore(radius: Float, height: Float, index: Int) -> Entity {
        let mesh = MeshResource.generateCylinder(height: height, radius: radius)
        // Dark matte interior fill — clearly plugs shell holes from any angle.
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor(red: 0.35, green: 0.26, blue: 0.14, alpha: 1))
        material.metallic = .float(0.1)
        material.roughness = .float(0.7)
        let core = ModelEntity(mesh: mesh, materials: [material])
        core.name = "BowlCore_\(index + 1)"
        return core
    }

    static func makeWaterSurface(radius: Float, index: Int) -> Entity {
        let mesh = MeshResource.generateCylinder(height: max(0.004, radius * 0.16), radius: radius)
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor(red: 0.22, green: 0.55, blue: 0.88, alpha: 1))
        material.roughness = .float(0.1)
        material.metallic = .float(0.0)

        let water = ModelEntity(mesh: mesh, materials: [material])
        water.name = "Water_\(index + 1)"
        return water
    }

    static func makeRippleRing(radius: Float) -> Entity {
        let mesh = MeshResource.generateCylinder(height: 0.0012, radius: radius)
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor(red: 0.65, green: 0.85, blue: 1.0, alpha: 0.55))
        material.roughness = .float(0.2)
        let ring = ModelEntity(mesh: mesh, materials: [material])
        ring.name = "Ripple"
        return ring
    }
}
