#if os(iOS)
import RealityKit
import SwiftUI

/// iPhone presentation of the shared shrine: orbit, pinch-zoom, and bowl taps.
struct PhoneShrineView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var orbitYaw: Float = 0.18
    @State private var orbitPitch: Float = 0.22
    @State private var zoom: Float = 1.0
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1

    private let orbitRoot = Entity()
    /// Explicit camera so the dolly distance below is in known metres rather than
    /// whatever pose RealityKit picks for its implicit virtual camera.
    private let camera = PerspectiveCamera()

    /// Shrine pose inside the orbit root: visionOS authors in world meters, so the
    /// phone framing shrinks it and drops it to eye level.
    private let phoneScale: Float = 0.42
    private let phoneOffset = SIMD3<Float>(0, -0.42, 0)
    /// Orbit pivot in shrine-local meters, sitting just behind the bowl row so that
    /// pushing all the way in lands the camera among the bowls instead of in front of them.
    private let focusLocal = SIMD3<Float>(0, 0.82, -1.20)
    /// Camera distance from the pivot at zoom 1; zooming dollies in and out of this.
    private let baseDistance: Float = 2.5
    private let minZoom: Float = 0.45
    private let maxZoom: Float = 16
    private let minDistance: Float = 0.1
    private let maxDistance: Float = 5.6
    private let minPitch: Float = -0.45
    private let maxPitch: Float = 1.15

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RealityView { content in
                content.camera = .virtual
                prepareCamera()
                if camera.parent == nil {
                    content.add(camera)
                }
                prepareOrbitRootIfNeeded()
                if orbitRoot.parent == nil {
                    content.add(orbitRoot)
                }
                applyOrbitTransform(animated: false)
            } update: { content in
                if camera.parent == nil {
                    content.add(camera)
                }
                if orbitRoot.parent == nil {
                    content.add(orbitRoot)
                }
                applyOrbitTransform(animated: false)
            }
            .gesture(orbitDrag)
            .simultaneousGesture(zoomPinch)
            .gesture(bowlTap)
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        appModel.exitAltar()
                        dismiss()
                    } label: {
                        Label("Exit", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)

                    Spacer()

                    Text("Drag to orbit · Pinch to zoom · Tap a bowl")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding()

                Spacer()
            }
        }
        .statusBarHidden()
        .task {
            await appModel.prepareAssetsIfNeeded()
            prepareOrbitRootIfNeeded()
            applyOrbitTransform(animated: false)
        }
        .onDisappear {
            // Detach and restore world-scale pose for any later visionOS session.
            appModel.shrineRoot.removeFromParent()
            appModel.shrineRoot.scale = .one
            appModel.shrineRoot.position = SIMD3(0, 0, -0.15)
            orbitRoot.children.removeAll()
        }
    }

    private var orbitDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($dragOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                orbitYaw += Float(value.translation.width) * 0.005
                orbitPitch = clamp(
                    orbitPitch + Float(value.translation.height) * 0.004,
                    min: minPitch,
                    max: maxPitch
                )
                applyOrbitTransform(animated: false)
            }
    }

    private var zoomPinch: some Gesture {
        MagnifyGesture()
            .updating($pinchScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                zoom = clamp(zoom * Float(value.magnification), min: minZoom, max: maxZoom)
                applyOrbitTransform(animated: false)
            }
    }

    private var bowlTap: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                if let index = bowlIndex(from: value.entity) {
                    appModel.strikeBowl(index: index)
                }
            }
    }

    private func prepareCamera() {
        // Near plane has to stay small so the shrine does not clip away when the
        // camera is pushed in to a few centimetres from a bowl.
        camera.camera.near = 0.01
        camera.camera.far = 60
        camera.camera.fieldOfViewInDegrees = 55
        camera.transform = Transform()
    }

    private func prepareOrbitRootIfNeeded() {
        guard appModel.isShrineBuilt || appModel.assetLoadState == .ready else { return }
        if appModel.shrineRoot.parent !== orbitRoot {
            appModel.shrineRoot.removeFromParent()
            // VisionOS places the shrine in world meters; scale it down for phone framing.
            appModel.shrineRoot.scale = SIMD3(repeating: phoneScale)
            appModel.shrineRoot.position = phoneOffset
            orbitRoot.addChild(appModel.shrineRoot)
        }
    }

    private func applyOrbitTransform(animated: Bool) {
        let liveYaw = orbitYaw + Float(dragOffset.width) * 0.005
        let livePitch = clamp(
            orbitPitch + Float(dragOffset.height) * 0.004,
            min: minPitch,
            max: maxPitch
        )
        let liveZoom = clamp(zoom * Float(pinchScale), min: minZoom, max: maxZoom)
        let distance = clamp(baseDistance / liveZoom, min: minDistance, max: maxDistance)

        let yaw = simd_quatf(angle: liveYaw, axis: SIMD3(0, 1, 0))
        let pitch = simd_quatf(angle: livePitch, axis: SIMD3(1, 0, 0))
        let rotation = pitch * yaw

        // Counter-rotate about the pivot so the camera (fixed at the origin, facing -Z)
        // effectively orbits the focus point at `distance` instead of the shrine scaling in place.
        let focus = focusLocal * phoneScale + phoneOffset
        var transform = Transform()
        transform.rotation = rotation
        transform.scale = .one
        transform.translation = SIMD3(0, 0, -distance) - rotation.act(focus)

        if animated {
            orbitRoot.move(to: transform, relativeTo: nil, duration: 0.2)
        } else {
            orbitRoot.transform = transform
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

    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.min(max, Swift.max(min, value))
    }
}
#endif
