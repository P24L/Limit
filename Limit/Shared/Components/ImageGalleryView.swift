//
//  ImageGalleryView.swift
//  Limit
//
//  Created by Zdenek Indra on 23.05.2025.
//

import SDWebImageSwiftUI
import SwiftUI

struct ImageDisplayData: Identifiable, Hashable {
    let id: String
    let url: URL
    let thumbURL: URL?
    let altText: String
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    @Binding var zoomResetTrigger: Int
    let content: Content

    init(zoomResetTrigger: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._zoomResetTrigger = zoomResetTrigger
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        let hostedView = UIHostingController(rootView: content)
        hostedView.view.translatesAutoresizingMaskIntoConstraints = false
        hostedView.view.backgroundColor = .clear
        scrollView.addSubview(hostedView.view)
        context.coordinator.scrollView = scrollView
        context.coordinator.hostedView = hostedView.view

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        NSLayoutConstraint.activate([
            hostedView.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hostedView.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if context.coordinator.lastResetTrigger != zoomResetTrigger {
            uiView.setZoomScale(1.0, animated: false)
            context.coordinator.lastResetTrigger = zoomResetTrigger
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var hostedView: UIView?
        var lastResetTrigger: Int = 0

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostedView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
        }
        
        private func centerContent(in scrollView: UIScrollView) {
            guard let hostedView = hostedView else { return }
            
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            
            hostedView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > 1 {
                scrollView.setZoomScale(1, animated: true)
            } else {
                scrollView.setZoomScale(3, animated: true)
            }
        }
    }
}

struct ImageGalleryView: View {
    @Binding var images: [PostImage]
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var zoomResetCounter = 0
    @State private var dragOffset = CGSize.zero
    private let dragDismissThreshold: CGFloat = 100
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .padding()
            }
            
            TabView(selection: $selectedIndex) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    VStack {
                        ZStack(alignment: .bottom) {
                            ZoomableScrollView(zoomResetTrigger: $zoomResetCounter) {
                                // Check if the image is a GIF
                                if image.url.absoluteString.lowercased().hasSuffix(".gif") {
                                    // Use AnimatedImage for GIFs
                                    AnimatedImage(url: image.url)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(Color.black)
                                } else {
                                    // Use WebImage for static images
                                    WebImage(url: image.url) { phase in
                                        switch phase {
                                        case .empty:
                                            ProgressView()
                                                .scaledToFit()
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(Color.black)
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(Color.black)
                                        case .failure(_):
                                            Rectangle()
                                                .foregroundStyle(.gray)
                                                .scaledToFit()
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(Color.black)
                                        }
                                    }
                                }
                            }
                            
                            Text(image.altText)
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .frame(maxWidth:.infinity, alignment: .leading)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .offset(y: dragOffset.height)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dragDismissThreshold {
                            dismiss()
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .onChange(of: selectedIndex) {
                zoomResetCounter += 1
            }
        }
        .background(Color(.secondarySystemBackground).ignoresSafeArea(.all))
    }
}

// TODO: Dodělat lepší zoom
struct FullScreenImageView: View {
    let images: [ImageDisplayData]
    let initialIndex: Int
    let namespace: Namespace.ID
    let onDismiss: () -> Void

    @State private var currentImage: ImageDisplayData
    @State private var scrollPosition: ImageDisplayData?
    @State private var zoom: CGFloat = 1.0

    init(images: [ImageDisplayData], initialIndex: Int, namespace: Namespace.ID, onDismiss: @escaping () -> Void) {
        self.images = images
        self.initialIndex = initialIndex
        self.namespace = namespace
        self.onDismiss = onDismiss
        _currentImage = State(initialValue: images[initialIndex])
    }

    var body: some View {
        NavigationStack {
            TabView(selection: Binding(
                get: { 
                    images.firstIndex(where: { $0.url == currentImage.url }) ?? 0 
                },
                set: { index in 
                    if images.indices.contains(index) {
                        currentImage = images[index]
                        zoom = 1.0
                    }
                }
            )) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    ZoomableScrollView(zoomResetTrigger: .constant(0)) {
                        WebImage(url: image.url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            case .failure(_):
                                Rectangle()
                                    .foregroundStyle(.gray)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .navigationTransition(.zoom(sourceID: currentImage.url, in: namespace))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveImage()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: currentImage.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private func saveImage() {
        let url = currentImage.url
        SDWebImageDownloader.shared.downloadImage(with: url) { image, _, _, _ in
            if let uiImage = image {
                UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            }
        }
    }
}

