import SwiftUI

@MainActor
final class PhotosViewModel: ObservableObject {
    @Published var photos: [UnsplashPhoto] = []
    @Published var isLoading = false
    
    private let client: UnsplashApiClient
    private var page = 1
    
    init(client: UnsplashApiClient) {
        self.client = client
    }
    
    func fetch() async throws {
        isLoading = true
        while page < 10 {
            let photosPage = try await client.photos(page: page)
            page += 1
            for photo in photosPage.results {
                if !photos.contains(where: { $0.id == photo.id }) {
                    photos.append(photo)
                }
            }
            print("we have \(photos.count) photos")
            try? await Task.sleep(nanoseconds: NSEC_PER_SEC / 5)
        }
        isLoading = false
    }
}

struct ContentView: View, Sendable {
    @ObservedObject var viewModel: PhotosViewModel
    
    var cols: [GridItem] {
        [
            GridItem(.adaptive(minimum: 200, maximum: 600), spacing: 1)
        ]
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: cols) {
                ForEach(viewModel.photos) { photo in
                    PhotoView(photo: photo)
                }
            }
            .padding()
        }
        .frame(minWidth: 400, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity)
        .overlay(
            ProgressView("Loading").opacity(viewModel.isLoading ? 1 : 0)
        )
        .task {
            try? await self.viewModel.fetch()
        }
    }
    
    func square(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .aspectRatio(1, contentMode: .fill)
    }
}

@MainActor
final class PhotoViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var image: NSImage?
    
    let photo: UnsplashPhoto
    let url: URL
    
    init(photo: UnsplashPhoto) {
        self.photo = photo
        url = photo.urls[.small]!
    }
    
    func loadImage() async {
        let url = self.photo.urls[.regular]!
        self.isLoading = true
        
        if let (data, _) = try? await URLSession.shared.data(from: url, delegate: nil) {
            self.image = NSImage(data: data)
        }
        
        self.isLoading = false
    }
}

@MainActor
struct PhotoView: View {
    @StateObject var viewModel: PhotoViewModel
    
    init(photo: UnsplashPhoto) {
        _viewModel = StateObject<PhotoViewModel>.init(wrappedValue: .init(photo: photo))
    }
    
    var body: some View {
        ZStack {
            Color.clear
                .background (
                    Image(nsImage: viewModel.image ?? NSImage())
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .layoutPriority(-1)
                        .transition(.opacity)
                )
                .overlay(
                    ProgressView().opacity(viewModel.isLoading ? 1 : 0)
                )
        }
        .clipped()
        .aspectRatio(1, contentMode: .fit)
        .layoutPriority(1)
        .task {
            await viewModel.loadImage()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: .init(client: .init()))
            .frame(width: 1200, height: 1000)
    }
}
