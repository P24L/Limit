//
//  PaginatedScrollView.swift
//  Limit
//
//  Created by Zdenek Indra on 01.06.2025.
//

import SwiftUI

struct PaginatedScrollView: View {
  @State private var posts: [Post] = []
  @State private var page: Int = 0
  @State private var isScrolling: Bool = false
  
  var body: some View {
    TabView {
      Tab {
        NavigationStack {
          ScrollView {
            LazyVStack {
              ForEach(posts) { post in
                VStack {
                    Text("\(post.content)-\(post.number)")
                }
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(.gray)
                .background(in: RoundedRectangle(cornerRadius: 8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
              }
            }
            .scrollTargetLayout()
          }
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button {
                Task {
                  await prependPage()
                }
              } label: {
                Text("Prepend")
              }
            }
          }
          .navigationTitle("Page: \(page)")
          .onScrollPhaseChange({ _, newPhase in
            withAnimation {
              switch newPhase {
              case .idle:
                isScrolling = false
              case .tracking, .interacting, .decelerating, .animating:
                isScrolling = true
              }
            }
          })
          .toolbarVisibility(isScrolling ? .hidden : .visible, for: .navigationBar)
          .toolbarVisibility(isScrolling ? .hidden : .visible,
                             for: .tabBar)
          .onScrollTargetVisibilityChange(idType: Post.ID.self) { postsIds in
            if let lastPost = posts.last, postsIds.contains(where: { $0 == lastPost.id }) {
              page += 1
            }
          }
          .task(id: page) {
            await loadNextPage()
          }
        }
      } label: {
        Label("Home", systemImage: "house")
      }
    }
  }
  
  private func loadNextPage() async {
    posts.append(contentsOf: [Post(), Post(), Post(), Post(), Post()])
  }
  
  private func prependPage() async {
      for _ in 0..<50 {
          posts.insert(contentsOf: [Post(), Post(), Post(), Post(), Post()], at: 0)
      }
    
  }
}

struct Post: Identifiable {
  let id = UUID()
  let content = "Post content"
    let number: Int
    
    init() {
        self.number = Int.random(in: 1...1000)
    }
    

}

#Preview {
  PaginatedScrollView()
}
