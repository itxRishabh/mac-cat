import SwiftUI
import AppKit

/// Offscreen renderer used to verify the cat visually.
/// `swift run -c release RenderTests` style harness, invoked via a flag.
@MainActor
enum RenderTests {

    static func run(outputDir: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let speciesList: [PetSpecies] = [.tuxedo, .ginger, .tabby, .siamese, .calico, .midnight, .cream, .snow]
        let poses: [(String, CatSkeleton)] = [
            ("standing", PoseLibrary.standing(phase: 0, t: 0)),
            ("sitting", PoseLibrary.sitting(phase: 0, t: 0)),
            ("sleeping", PoseLibrary.sleeping(phase: 0, t: 0)),
            ("stretching", PoseLibrary.stretching(phase: 0, t: 0)),
            ("playful", PoseLibrary.playful(phase: 0, t: 0))
        ]

        // Species sheet.
        for species in speciesList {
            let img = render(skeleton: PoseLibrary.standing(phase: 0, t: 0),
                             palette: species.palette,
                             accessory: .none,
                             size: CGSize(width: 320, height: 320))
            save(img, to: "\(outputDir)/species-\(species.rawValue).png")
        }

        // Pose sheet for the default palette.
        for (name, skel) in poses {
            let img = render(skeleton: skel,
                             palette: PetSpecies.tuxedo.palette,
                             accessory: .none,
                             size: CGSize(width: 320, height: 320))
            save(img, to: "\(outputDir)/pose-\(name).png")
        }

        // Accessories sheet.
        for accessory in Accessory.allCases {
            let img = render(skeleton: PoseLibrary.sitting(phase: 0, t: 0),
                             palette: PetSpecies.cream.palette,
                             accessory: accessory,
                             size: CGSize(width: 320, height: 320))
            save(img, to: "\(outputDir)/accessory-\(accessory.rawValue).png")
        }

        print("rendered to \(outputDir)")
    }

    private static func render(skeleton: CatSkeleton,
                               palette: PetPalette,
                               accessory: Accessory,
                               size: CGSize) -> NSImage {
        let view = RenderHarness(skeleton: skeleton, palette: palette, accessory: accessory)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return NSImage(size: size) }
        return NSImage(cgImage: cg, size: size)
    }

    private static func save(_ image: NSImage, to path: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

struct RenderHarness: View {
    let skeleton: CatSkeleton
    let palette: PetPalette
    let accessory: Accessory

    var body: some View {
        Canvas { ctx, size in
            let r = CatRenderer(skeleton: skeleton,
                                palette: palette,
                                blink: 1,
                                earTwitch: 0,
                                tailWag: 0.2,
                                mouthOpen: 0,
                                headTilt: 0,
                                eyeLook: .zero,
                                accessory: accessory,
                                isSpeaking: false,
                                facingRight: true)
            r.draw(in: ctx, size: size)
        }
        .background(Color.white)
    }
}
