//
//  TimelinePostWrapper.swift
//  Limit
//
//  Created by Zdenek Indra on 13.06.2025.
//

import ATProtoKit
import Foundation
import LinkPresentation
import SwiftData
import SwiftUI

@Observable
final class TimelinePostWrapper: Identifiable, Hashable, Equatable {
  public let uri: String
  public let cid: String
  var storageID: String?
  private let uuid = UUID()
  public var id: String { uri + uuid.uuidString }

  let createdAt: Date
  var type: TimelinePostType
  let authorID: String
  let authorHandle: String
  let authorDisplayName: String?
  let authorAvatarURL: URL?

  let text: String
  var facets: PostFacets?

  var likeCount: Int
  var replyCount: Int
  var repostCount: Int
  var quoteCount: Int

  var embeds: [ImageEmbed] = []
  var linkExt: LinkEmbed?
  var postVideo: VideoEmbed?

  var quotedPost: TimelinePostWrapper?
  //var replyTo: TimelinePostWrapper?

  var parentPost: TimelinePostWrapper?
  var rootPost: TimelinePostWrapper?

  var repostedByID: String?
  var repostedByHandle: String?
  var repostedByDisplayName: String?
  var repostedByAvatarURL: URL?

  var fetchedWithCursor: String?

  var viewerLikeURI: String?
  var viewerRepostURI: String?
  var viewerIsPinned: Bool = false
  var viewerIsThreadMuted: Bool = false
  var viewerAreRepliesDisabled: Bool = false
  var viewerIsEmbeddingDisabled: Bool = false

  var isLiked: Bool {
    viewerLikeURI != nil
  }

  struct ImageEmbed {
    let id: String
    let url: URL
    let thumbURL: URL?
    let altText: String
  }

  struct LinkEmbed {
    let desc: String
    let thumbnailImageURL: URL?
    let title: String
    let uri: String
  }

  struct VideoEmbed {
    let id: String
    let altText: String?
    let playlistURI: String
    let thumbImageURL: String?
    let height: Int?
    let width: Int?
  }

  struct ProcessedFacet {
    let range: NSRange
    let type: FacetType
    let data: FacetData
    // Enhanced Link Presentation metadata
    var title: String?
    var thumbnailURL: String?
    var metadataFetched: Bool = false
  }

  enum FacetType {
    case link, mention, tag

    // Convert to SwiftData FacetType
    var swiftDataType: Limit.FacetType {
      switch self {
      case .link: return .link
      case .mention: return .mention
      case .tag: return .tag
      }
    }

    // Convert from SwiftData FacetType
    init(from swiftDataType: Limit.FacetType) {
      switch swiftDataType {
      case .link: self = .link
      case .mention: self = .mention
      case .tag: self = .tag
      }
    }
  }

  enum FacetData {
    case link(uri: String)
    case mention(did: String, handle: String?)
    case tag(tag: String)
  }

  struct PostFacets {
    let facets: [ProcessedFacet]

    var isEmpty: Bool {
      facets.isEmpty
    }

    var links: [ProcessedFacet] {
      facets.filter { $0.type == .link }
    }

    var mentions: [ProcessedFacet] {
      facets.filter { $0.type == .mention }
    }

    var tags: [ProcessedFacet] {
      facets.filter { $0.type == .tag }
    }

    /// Returns facet links that are not already displayed in the main link embed
    func uniqueLinks(excluding embedLinkURI: String?) -> [ProcessedFacet] {
      guard let embedURI = embedLinkURI else { return links }

      return links.filter { facet in
        if case .link(let uri) = facet.data {
          return uri != embedURI
        }
        return false
      }
    }
  }

  // MARK: - Facet Processing Helper

  private static func convertByteRangeToStringRange(text: String, byteStart: Int, byteEnd: Int)
    -> NSRange?
  {
    let utf8Data = text.data(using: .utf8) ?? Data()
    guard byteStart >= 0, byteEnd <= utf8Data.count, byteStart < byteEnd else { return nil }

    let startData = utf8Data.prefix(byteStart)
    let endData = utf8Data.prefix(byteEnd)

    guard let startString = String(data: startData, encoding: .utf8),
      let endString = String(data: endData, encoding: .utf8)
    else {
      return nil
    }

    let startIndex = startString.count
    let endIndex = endString.count

    guard startIndex <= text.count, endIndex <= text.count else { return nil }

    return NSRange(location: startIndex, length: endIndex - startIndex)
  }

  private static func processFacets(
    from atprotoFacets: [AppBskyLexicon.RichText.Facet], text: String
  ) -> PostFacets? {
    var processedFacets: [ProcessedFacet] = []

    for facet in atprotoFacets {
      guard
        let range = convertByteRangeToStringRange(
          text: text,
          byteStart: facet.index.byteStart,
          byteEnd: facet.index.byteEnd
        )
      else { continue }

      // Priority: Link > Mention > Tag
      var selectedType: FacetType?
      var selectedData: FacetData?

      for feature in facet.features {
        switch feature {
        case .link(let link):
          selectedType = .link
          selectedData = .link(uri: link.uri)
          break  // Highest priority, stop here

        case .mention(let mention):
          if selectedType == nil {
            selectedType = .mention
            selectedData = .mention(did: mention.did, handle: nil)
          }

        case .tag(let tag):
          if selectedType == nil {
            selectedType = .tag
            selectedData = .tag(tag: tag.tag)
          }

        case .unknown:
          continue
        }
      }

      if let type = selectedType, let data = selectedData {
        let processedFacet = ProcessedFacet(range: range, type: type, data: data)
        processedFacets.append(processedFacet)
      }
    }

    return processedFacets.isEmpty ? nil : PostFacets(facets: processedFacets)
  }

  // MARK: - SwiftData Conversion Helpers

  /// Convert wrapper facets to SwiftData PostFacet models
  private func convertFacetsToSwiftData() -> [PostFacet] {
    guard let facets = self.facets else { return [] }

    return facets.facets.map { processedFacet in
      let (uri, did, tag, handle): (String?, String?, String?, String?) = {
        switch processedFacet.data {
        case .link(let uri):
          return (uri, nil, nil, nil)
        case .mention(let did, let handle):
          return (nil, did, nil, handle)
        case .tag(let tag):
          return (nil, nil, tag, nil)
        }
      }()

      return PostFacet(
        facetType: processedFacet.type.swiftDataType,
        startIndex: processedFacet.range.location,
        endIndex: processedFacet.range.location + processedFacet.range.length,
        uri: uri,
        did: did,
        tag: tag,
        handle: handle,
        title: processedFacet.title,
        linkDescription: nil,
        thumbnailURL: processedFacet.thumbnailURL,
        metadataFetched: processedFacet.metadataFetched
      )
    }
  }

  /// Convert SwiftData PostFacet models to wrapper facets
  private static func convertFacetsFromSwiftData(_ swiftDataFacets: [PostFacet]) -> PostFacets? {
    guard !swiftDataFacets.isEmpty else { return nil }

    let processedFacets = swiftDataFacets.compactMap { facet -> ProcessedFacet? in
      let range = NSRange(location: facet.startIndex, length: facet.endIndex - facet.startIndex)
      let wrapperType = FacetType(from: facet.facetType)

      let data: FacetData
      switch facet.facetType {
      case .link:
        guard let uri = facet.uri else { return nil }
        data = .link(uri: uri)
      case .mention:
        guard let did = facet.did else { return nil }
        data = .mention(did: did, handle: facet.handle)
      case .tag:
        guard let tag = facet.tag else { return nil }
        data = .tag(tag: tag)
      }

      return ProcessedFacet(
        range: range,
        type: wrapperType,
        data: data,
        title: facet.title,
        thumbnailURL: facet.thumbnailURL,
        metadataFetched: facet.metadataFetched
      )
    }

    return processedFacets.isEmpty ? nil : PostFacets(facets: processedFacets)
  }

  static func == (lhs: TimelinePostWrapper, rhs: TimelinePostWrapper) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  init(from postView: AppBskyLexicon.Feed.PostViewDefinition) {
    self.uri = postView.uri
    self.cid = postView.cid
    self.createdAt =
      postView.record.getRecord(ofType: AppBskyLexicon.Feed.PostRecord.self)?.createdAt
      ?? postView.indexedAt
    self.text = postView.record.getRecord(ofType: AppBskyLexicon.Feed.PostRecord.self)?.text ?? ""
    self.type = .post

    // Process facets for rich text
    if let postRecord = postView.record.getRecord(ofType: AppBskyLexicon.Feed.PostRecord.self),
      let atprotoFacets = postRecord.facets
    {
      self.facets = TimelinePostWrapper.processFacets(from: atprotoFacets, text: self.text)
    }

    self.authorID = postView.author.actorDID
    self.authorHandle = postView.author.actorHandle
    self.authorDisplayName = postView.author.displayName
    self.authorAvatarURL = postView.author.avatarImageURL

    self.likeCount = postView.likeCount ?? 0
    self.replyCount = postView.replyCount ?? 0
    self.repostCount = postView.repostCount ?? 0
    self.quoteCount = postView.quoteCount ?? 0

    // Embeds - obrázky
    if case .embedImagesView(let imagesView) = postView.embed {
      self.embeds = imagesView.images.map({ image in
        TimelinePostWrapper.ImageEmbed(
          id: image.id,
          url: image.fullSizeImageURL,
          thumbURL: image.thumbnailImageURL,
          altText: image.altText
        )
      })
    }

    // Embed - externí link
    if case .embedExternalView(let ext) = postView.embed {
      self.linkExt = TimelinePostWrapper.LinkEmbed(
        desc: ext.external.description,
        thumbnailImageURL: ext.external.thumbnailImageURL,
        title: ext.external.title,
        uri: ext.external.uri
      )
    }

    // Embed - video
    if case .embedVideoView(let video) = postView.embed {
      self.postVideo = TimelinePostWrapper.VideoEmbed(
        id: video.id,
        altText: video.altText,
        playlistURI: video.playlistURI,
        thumbImageURL: video.thumbnailImageURL,
        height: video.aspectRatio?.height,
        width: video.aspectRatio?.width
      )
    }

    // Quoted
    if case .embedRecordView(let record) = postView.embed,
      case .viewRecord(let quotedView) = record.record
    {
      self.quotedPost = TimelinePostWrapper(from: quotedView)
      self.quotedPost?.type = .quoted
    } else if case .embedRecordWithMediaView(let combo) = postView.embed,
      case .viewRecord(let quotedView) = combo.record.record
    {
      self.quotedPost = TimelinePostWrapper(from: quotedView)
      self.quotedPost?.type = .quoted
    }
    if let viewer = postView.viewer {
      self.viewerLikeURI = viewer.likeURI
      self.viewerRepostURI = viewer.repostURI
      self.viewerIsPinned = viewer.isPinned ?? false
      self.viewerIsThreadMuted = viewer.isThreadMuted
      self.viewerAreRepliesDisabled = viewer.areRepliesDisabled ?? false
      self.viewerIsEmbeddingDisabled = viewer.isEmbeddingDisabled ?? false
    }

    // Background fetch metadata for link facets (non-blocking)
    Task.detached { [weak self] in
      await self?.fetchLinkMetadataInWrapper()
    }
  }

  convenience init?(from feedPost: AppBskyLexicon.Feed.FeedViewPostDefinition) {
    self.init(from: feedPost.post)

    guard !self.uri.isEmpty,
      !self.cid.isEmpty,
      !self.authorID.isEmpty,
      !self.authorHandle.isEmpty,
      self.createdAt.timeIntervalSince1970 > 0
    else {
      print("❌ Skipping invalid wrapper during init (feedPost): \(feedPost.post.uri)")
      return nil
    }

    self.type = .post

    // Repost info
    if case .reasonRepost(let actor) = feedPost.reason {
      self.repostedByID = actor.by.actorDID
      self.repostedByHandle = actor.by.actorHandle
      self.repostedByDisplayName = actor.by.displayName
      self.repostedByAvatarURL = actor.by.avatarImageURL
    }

    // Reply info
    if let reply = feedPost.reply {
      if case .postView(let parentView) = reply.parent {
        self.parentPost = TimelinePostWrapper(from: parentView)
        self.parentPost?.type = .parent
      }
      if case .postView(let rootView) = reply.root {
        self.rootPost = TimelinePostWrapper(from: rootView)
        self.rootPost?.type = .root

      }
    }
  }

  // Internal initializer using all properties, as requested
  init(
    uri: String,
    cid: String,
    createdAt: Date,
    type: TimelinePostType,
    authorID: String,
    authorHandle: String,
    authorDisplayName: String?,
    authorAvatarURL: URL?,
    text: String,
    likeCount: Int,
    replyCount: Int,
    repostCount: Int,
    quoteCount: Int,
    embeds: [TimelinePostWrapper.ImageEmbed] = [],
    linkExt: TimelinePostWrapper.LinkEmbed? = nil,
    postVideo: TimelinePostWrapper.VideoEmbed? = nil,
    facets: PostFacets? = nil
  ) {
    self.uri = uri
    self.cid = cid
    self.createdAt = createdAt
    self.type = type
    self.authorID = authorID
    self.authorHandle = authorHandle
    self.authorDisplayName = authorDisplayName
    self.authorAvatarURL = authorAvatarURL
    self.text = text
    self.likeCount = likeCount
    self.replyCount = replyCount
    self.repostCount = repostCount
    self.quoteCount = quoteCount
    self.embeds = embeds
    self.linkExt = linkExt
    self.postVideo = postVideo
    self.facets = facets
  }

  convenience init?(from viewRecord: AppBskyLexicon.Embed.RecordDefinition.ViewRecord) {
    guard let postRecord = viewRecord.value.getRecord(ofType: AppBskyLexicon.Feed.PostRecord.self)
    else {
      return nil
    }

    guard !viewRecord.uri.isEmpty,
      !viewRecord.cid.isEmpty,
      !viewRecord.author.actorDID.isEmpty,
      !viewRecord.author.actorHandle.isEmpty,
      (viewRecord.indexedAt ?? postRecord.createdAt).timeIntervalSince1970 > 0
    else {
      print("❌ Skipping invalid wrapper during init (quoted): \(viewRecord.uri)")
      return nil
    }

    let facets =
      postRecord.facets != nil
      ? TimelinePostWrapper.processFacets(from: postRecord.facets!, text: postRecord.text) : nil

    self.init(
      uri: viewRecord.uri,
      cid: viewRecord.cid,
      createdAt: viewRecord.indexedAt ?? postRecord.createdAt,
      type: .quoted,
      authorID: viewRecord.author.actorDID,
      authorHandle: viewRecord.author.actorHandle,
      authorDisplayName: viewRecord.author.displayName,
      authorAvatarURL: viewRecord.author.avatarImageURL,
      text: postRecord.text,
      likeCount: viewRecord.likeCount ?? 0,
      replyCount: viewRecord.replyCount ?? 0,
      repostCount: viewRecord.repostCount ?? 0,
      quoteCount: viewRecord.quoteCount ?? 0,
      facets: facets
    )

    // Background fetch metadata for link facets (non-blocking)
    Task.detached { [weak self] in
      await self?.fetchLinkMetadataInWrapper()
    }
  }

  convenience init(from model: TimelinePost) {
    self.init(
      uri: model.uri,
      cid: model.cid,
      createdAt: model.createdAt,
      type: model.type,
      authorID: model.authorID,
      authorHandle: model.authorHandle,
      authorDisplayName: model.authorDisplayName,
      authorAvatarURL: model.authorAvatarURL,
      text: model.text,
      likeCount: model.likeCount,
      replyCount: model.replyCount,
      repostCount: model.repostCount,
      quoteCount: model.quoteCount,
      embeds: model.embeds.map {
        TimelinePostWrapper.ImageEmbed(
          id: $0.id.uuidString,
          url: $0.url,
          thumbURL: $0.thumbURL,
          altText: $0.altText
        )
      },
      linkExt: model.linkExt.map {
        TimelinePostWrapper.LinkEmbed(
          desc: $0.desc,
          thumbnailImageURL: $0.thumbnailImageURL,
          title: $0.title,
          uri: $0.uri
        )
      },
      postVideo: model.postVideo.map {
        TimelinePostWrapper.VideoEmbed(
          id: $0.id,
          altText: $0.altText,
          playlistURI: $0.playlistURI,
          thumbImageURL: $0.thumbImageURL,
          height: $0.height,
          width: $0.width
        )
      },
      facets: TimelinePostWrapper.convertFacetsFromSwiftData(model.facets)
    )
    self.storageID = model.id
    self.viewerLikeURI = model.viewerLikeURI
    self.viewerRepostURI = model.viewerRepostURI
    self.viewerIsPinned = model.viewerIsPinned
    self.viewerIsThreadMuted = model.viewerIsThreadMuted
    self.viewerAreRepliesDisabled = model.viewerAreRepliesDisabled
    self.viewerIsEmbeddingDisabled = model.viewerIsEmbeddingDisabled
    if let parent = model.parentPost {
      self.parentPost = TimelinePostWrapper(from: parent)
    }
    if let root = model.rootPost {
      self.rootPost = TimelinePostWrapper(from: root)
    }
    self.repostedByDisplayName = model.repostedByDisplayName
    self.repostedByAvatarURL = model.repostedByAvatarURL

    // Background fetch metadata for link facets if not already fetched (for SwiftData loaded posts)
    Task.detached { [weak self] in
      await self?.fetchLinkMetadataIfNeeded()
    }
  }

  func toModel(context: ModelContext) -> TimelinePost {
    let model = TimelinePost(
      id: storageID ?? uri + UUID().uuidString,
      uri: uri,
      cid: cid,
      createdAt: createdAt,
      type: type,
      authorID: authorID,
      authorHandle: authorHandle,
      authorDisplayName: authorDisplayName,
      authorAvatarURL: authorAvatarURL,
      text: text,
      //replyTo: replyTo?.toModel(context: context),
      likeCount: likeCount,
      replyCount: replyCount,
      repostCount: repostCount,
      quoteCount: quoteCount,
      quotedPost: quotedPost?.toModel(context: context),
      fetchedWithCursor: fetchedWithCursor,
      parentPost: parentPost?.toModel(context: context),
      rootPost: rootPost?.toModel(context: context),
      repostedByID: repostedByID,
      repostedByHandle: repostedByHandle,
      repostedByDisplayName: repostedByDisplayName,
      repostedByAvatarURL: repostedByAvatarURL,
      viewerLikeURI: viewerLikeURI,
      viewerRepostURI: viewerRepostURI,
      viewerIsPinned: viewerIsPinned,
      viewerIsThreadMuted: viewerIsThreadMuted,
      viewerAreRepliesDisabled: viewerAreRepliesDisabled,
      viewerIsEmbeddingDisabled: viewerIsEmbeddingDisabled
    )

    model.embeds = embeds.map {
      PostImage(id: $0.id, url: $0.url, thumbURL: $0.thumbURL, altText: $0.altText)
    }

    if let link = linkExt {
      model.linkExt = PostLinkExt(
        desc: link.desc, thumbnailImageURL: link.thumbnailImageURL, title: link.title, uri: link.uri
      )
    }

    if let video = postVideo {
      model.postVideo = PostVideo(
        id: video.id, altText: video.altText, playlistURI: video.playlistURI,
        thumbImageURL: video.thumbImageURL, height: video.height, width: video.width)
    }

    // Convert and assign facets
    model.facets = convertFacetsToSwiftData()

    return model
  }

  // MARK: - Link Metadata Management

  /// Checks if any link facets need metadata and fetches them if necessary
  func fetchLinkMetadataIfNeeded() async {
    guard let facets = self.facets else { return }

    // Only fetch for links that haven't been fetched yet
    let needsMetadata = facets.links.contains { facet in
      !facet.metadataFetched
    }

    if needsMetadata {
      await fetchLinkMetadataInWrapper()
    }
  }

  /// Fetches metadata for link facets directly in wrapper (background)
  func fetchLinkMetadataInWrapper() async {
    guard let facets = self.facets else { return }

    var updatedFacets: [ProcessedFacet] = []

    for facet in facets.facets {
      var updatedFacet = facet

      // Only fetch for links that haven't been fetched yet
      if case .link(let uri) = facet.data, !facet.metadataFetched {
        guard let url = URL(string: uri) else {
          updatedFacet.metadataFetched = true
          updatedFacets.append(updatedFacet)
          continue
        }

        do {
          let metadataProvider = LPMetadataProvider()
          let metadata = try await metadataProvider.startFetchingMetadata(for: url)

          // Update facet with metadata
          updatedFacet.title = metadata.title

          // Handle thumbnail using Google Favicon Service
          if let domain = url.host {
            let googleFaviconAPI = "https://www.google.com/s2/favicons?domain=\(domain)&sz=256"
            updatedFacet.thumbnailURL = googleFaviconAPI
          }

          updatedFacet.metadataFetched = true

        } catch {
          updatedFacet.metadataFetched = true  // Mark as attempted
        }
      }

      updatedFacets.append(updatedFacet)
    }

    // Update facets with new metadata
    let finalFacets = updatedFacets  // Capture before MainActor
    await MainActor.run {
      self.facets = PostFacets(facets: finalFacets)
    }
  }

  /// Fetches metadata for all link facets in this post (SwiftData version)
  func fetchLinkMetadata(context: ModelContext) async {
    guard let facets = self.facets else { return }

    // Get SwiftData facets from database
    let linkFacets = facets.links.compactMap { processedFacet -> PostFacet? in
      guard case .link(let uri) = processedFacet.data else { return nil }

      // Find corresponding PostFacet in database by URI only
      let descriptor = FetchDescriptor<PostFacet>(
        predicate: #Predicate<PostFacet> { facet in
          facet.uri == uri
        }
      )

      return try? context.fetch(descriptor).first
    }

    await LinkMetadataService.shared.fetchMetadataForLinks(linkFacets)
  }

  // MARK: - ToggleLike
  func toggleLike(using client: BlueskyClient) async {
    let originalURI = viewerLikeURI
    if let likeURI = viewerLikeURI {
      viewerLikeURI = nil
      likeCount = max(0, likeCount - 1)
      do {
        try await client.bskyClient?.deleteRecord(.recordURI(atURI: likeURI))
      } catch {
        viewerLikeURI = likeURI
        likeCount += 1
      }
    } else {
      viewerLikeURI = "optimistic"
      likeCount += 1
      do {
        let result = try await client.bskyClient?.createLikeRecord(
          .init(recordURI: uri, cidHash: cid)
        )
        viewerLikeURI = result?.recordURI
      } catch {
        viewerLikeURI = originalURI
        likeCount = max(0, likeCount - 1)
      }
    }
  }
}

extension TimelinePostWrapper.ImageEmbed {
  func toDisplayImage() -> ImageDisplayData {
    ImageDisplayData(id: id, url: url, thumbURL: thumbURL, altText: altText)
  }
}

// MARK: - TimelinePostRepresentable Protocol

protocol TimelinePostRepresentable: Identifiable {
  var id: String { get }
  var createdAt: Date { get }
  var type: TimelinePostType { get }
  var authorID: String { get }
  var authorHandle: String { get }
  var authorDisplayName: String? { get }
  var authorAvatarURL: URL? { get }
  var text: String { get }
  var likeCount: Int { get }
  var replyCount: Int { get }
  var repostCount: Int { get }
  var quoteCount: Int { get }
  var embeds: [TimelinePostWrapper.ImageEmbed] { get }
  var linkExt: TimelinePostWrapper.LinkEmbed? { get }
  var postVideo: TimelinePostWrapper.VideoEmbed? { get }
}

extension TimelinePostWrapper: TimelinePostRepresentable {}

@Observable
final class TimelineFeed {
  private(set) var posts: [TimelinePostWrapper] = []
  var postTimeline: [TimelinePostWrapper] {
    posts.filter { post in
      post.type == .post
    }
  }

  private(set) var oldestCursor: String?
  private let context: ModelContext

  private var client: BlueskyClient

  init(context: ModelContext, client: BlueskyClient) {
    self.context = context
    self.client = client
  }

  func updateClient(_ newClient: BlueskyClient) {
    self.client = newClient
  }

  func loadFromStorage() {
    do {

      var descriptor = FetchDescriptor<TimelinePost>(
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
      )
      descriptor.relationshipKeyPathsForPrefetching = [
        \.parentPost,
        \.rootPost,
        \.embeds,
        \.linkExt,
        \.postVideo,
      ]

      let storedPosts = try context.fetch(descriptor)
      self.posts = storedPosts.map { TimelinePostWrapper(from: $0) }
      self.oldestCursor = storedPosts.last?.fetchedWithCursor
      print("Load from storage finished")
    } catch {
      print("Failed to load timeline from storage: \(error)")
    }
  }

  @MainActor
  func appendPosts(from definitions: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?)
  {
    for def in definitions {
      guard let wrapper = TimelinePostWrapper(from: def) else { continue }
      wrapper.fetchedWithCursor = cursor
      posts.append(wrapper)
    }
    if oldestCursor == nil, let cursor = cursor {
      oldestCursor = cursor
    }
    saveToStorage()
  }

  /// Přidá nové příspěvky na začátek timeline, odstraní duplicity podle URI.
  @MainActor
  func getFreshPosts(
    from definitions: [AppBskyLexicon.Feed.FeedViewPostDefinition], cursor: String?
  ) {
    var newWrappers: [TimelinePostWrapper] = []
    for def in definitions {
      guard let wrapper = TimelinePostWrapper(from: def) else { continue }
      wrapper.fetchedWithCursor = cursor
      newWrappers.append(wrapper)
    }

    // Přidáme nové posty na začátek a zároveň odstraníme duplicity podle URI
    let existingPostURIs = Set(posts.filter { $0.type == .post }.map { $0.uri })
    let uniqueNewWrappers = newWrappers.filter { !existingPostURIs.contains($0.uri) }

    posts.insert(contentsOf: uniqueNewWrappers, at: 0)

    // Pokud cursor přišel (většinou nil), tak jej neměníme — to se používá pro oldestCursor
    saveToStorage()
  }

  @MainActor
  func saveToStorage() {
    let newWrappers = posts.filter { $0.storageID == nil }
    do {
      for wrapper in newWrappers {
        // Create and insert the model, letting SwiftData cascade to relationships
        let postModel = wrapper.toModel(context: context)
        context.insert(postModel)
        wrapper.storageID = postModel.id
      }
      try context.save()
    } catch {
      print("Failed to save timeline: \(error)")
    }
  }

  func clearStorage() {
    do {
      let descriptor = FetchDescriptor<TimelinePost>()
      let stored = try context.fetch(descriptor)
      for post in stored {
        context.delete(post)
      }
      try context.save()
      posts.removeAll()
      oldestCursor = nil
    } catch {
      print("Failed to clear timeline: \(error)")
    }
  }

  /// Načte nové příspěvky z klienta a přidá je na začátek timeline.
  /// Nepoužívá context, neukládá do DB.
  func refreshTimeline() async {
    if let newestPost = posts.filter({ $0.type == .post }).sorted(by: {
      $0.createdAt > $1.createdAt
    }).first {
      let result = await client.fetchTimeline(since: newestPost.uri)
      let newPosts = result.posts
      let cursor = result.cursor
      await getFreshPosts(from: newPosts, cursor: cursor)
    } else {
      let result = await client.fetchTimeline()
      let newPosts = result.posts
      let cursor = result.cursor
      oldestCursor = cursor
      await getFreshPosts(from: newPosts, cursor: cursor)
    }
  }

  /// Načte starší příspěvky z klienta podle oldestCursor a přidá je do timeline.
  func loadOlderTimeline() async {
    guard let cursor = oldestCursor else {
      print("No cursor available for loading older timeline.")
      return
    }

    let result = await client.loadOlderPosts(from: cursor)
    let olderPosts = result.posts
    let newCursor = result.cursor

    await appendPosts(from: olderPosts, cursor: newCursor)
    // Explicitně nastavíme oldestCursor podle nového kurzoru
    if let newCursor = result.cursor {
      oldestCursor = newCursor
    }
  }

}
