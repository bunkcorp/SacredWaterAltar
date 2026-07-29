import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("3D Assets")
                        .font(.title2.weight(.semibold))

                    credit(
                        title: "Golden Buddha Statue",
                        author: "Triative",
                        license: "Sketchfab Standard",
                        url: "https://sketchfab.com/3d-models/golden-buddha-statue-dd9941ffa797441589f9ca644a5998b0"
                    )
                    credit(
                        title: "1973.85 Seated Buddha",
                        author: "Cleveland Museum of Art",
                        license: "CC0-1.0",
                        url: "https://sketchfab.com/3d-models/197385-seated-buddha-d86bda08fa92458397596d2a42b30f46"
                    )
                    credit(
                        title: "Tibetan Singing Bowl",
                        author: "db4",
                        license: "CC-BY-4.0",
                        url: "https://sketchfab.com/3d-models/tibetan-singing-bowl-52228c0d0cb44e6cacdeb3851e0743fc"
                    )
                    credit(
                        title: "Vajrasattva Full",
                        author: "advayavajra",
                        license: "CC-BY-4.0",
                        url: "https://sketchfab.com/3d-models/vajrasattva-full-5deb88eed021488ea72c18f97c9250e0"
                    )
                    credit(
                        title: "Medicine Buddha Mantra Wheel",
                        author: "katherinemunro33",
                        license: "CC-BY-4.0",
                        url: "https://sketchfab.com/3d-models/medicine-buddha-mantra-wheel-c305fd3fc4c8447db8ed278781d2b6ae"
                    )
                    credit(
                        title: "Om Mani Padme Hum Mantra with Lotus",
                        author: "katherinemunro33",
                        license: "CC-BY-4.0",
                        url: "https://sketchfab.com/3d-models/om-mani-padme-hum-mantra-with-lotus-a5b2c506f43e449ba1eb68dc885785b8"
                    )
                    credit(
                        title: "Green Tara Mantra",
                        author: "katherinemunro33",
                        license: "CC-BY-4.0",
                        url: "https://sketchfab.com/3d-models/green-tara-mantra-fa07c9b2f48c46d29b2b0e96fa9afa5d"
                    )

                    Text("Notes")
                        .font(.headline)
                    Text("Vajrasattva’s USDZ export lost vertex colors from the source GLB, so this app applies a warm bronze/gold material at runtime. Bowl tones are synthesized WAV files bundled with the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .navigationTitle("Credits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func credit(title: String, author: String, license: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text("Author: \(author)")
            Text("License: \(license)")
            if let link = URL(string: url) {
                Link(url, destination: link)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
