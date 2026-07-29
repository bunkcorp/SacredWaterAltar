import RealityKit

struct BowlIndexComponent: Component, Codable {
    var index: Int

    static func register() {
        BowlIndexComponent.registerComponent()
    }
}
