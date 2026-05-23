import SwiftUI

struct CanvasView: View {
    let image: UIImage?

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = max(1, lastScale * value)
                                    }
                                    .onEnded { _ in lastScale = scale },
                                DragGesture()
                                    .onChanged { value in
                                        guard scale > 1 else { return }
                                        offset = value.translation
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation { scale = 1; offset = .zero; lastScale = 1 }
                        }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo").font(.system(size: 48)).foregroundColor(.gray)
                        Text("No photo selected").foregroundColor(.gray)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .background(Color.black)
    }
}
