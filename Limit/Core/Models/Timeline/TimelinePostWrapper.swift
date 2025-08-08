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
  
  // Track active metadata fetching tasks for cancellation
  private var metadataFetchTask: Task<Void, Never>?

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
  
  var isReposted: Bool {
    viewerRepostURI != nil
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

  // MARK: - Media Processing Helper
  
  private func processMediaUnion(_ media: AppBskyLexicon.Embed.RecordWithMediaDefinition.View.MediaUnion) {
    switch media {
    case .embedImagesView(let imagesView):
      self.embeds = imagesView.images.map { image in
        TimelinePostWrapper.ImageEmbed(
          id: image.id,
          url: image.fullSizeImageURL,
          thumbURL: image.thumbnailImageURL,
          altText: image.altText
        )
      }
    case .embedExternalView(let externalView):
      self.linkExt = TimelinePostWrapper.LinkEmbed(
        desc: externalView.external.description,
        thumbnailImageURL: externalView.external.thumbnailImageURL,
        title: externalView.external.title,
        uri: externalView.external.uri
      )
    case .embedVideoView(let videoView):
      self.postVideo = TimelinePostWrapper.VideoEmbed(
        id: videoView.id,
        altText: videoView.altText,
        playlistURI: videoView.playlistURI,
        thumbImageURL: videoView.thumbnailImageURL,
        height: videoView.aspectRatio?.height,
        width: videoView.aspectRatio?.width
      )
    case .unknown:
      break
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
      // Process both the quoted record and the media
      self.quotedPost = TimelinePostWrapper(from: quotedView)
      self.quotedPost?.type = .quoted
      
      // Process the media component and add it to this post
      self.processMediaUnion(combo.media)
    }

    //Viewer
    if let viewer = postView.viewer {
      self.viewerLikeURI = viewer.likeURI
      self.viewerRepostURI = viewer.repostURI
      self.viewerIsPinned = viewer.isPinned ?? false
      self.viewerIsThreadMuted = viewer.isThreadMuted
      self.viewerAreRepliesDisabled = viewer.areRepliesDisabled ?? false
      self.viewerIsEmbeddingDisabled = viewer.isEmbeddingDisabled ?? false
    }

    // Check if we need to fetch metadata for link facets
    let hasUnfetchedLinks = self.facets?.links.contains { !$0.metadataFetched } ?? false
    
    if hasUnfetchedLinks {
      // Cancel any existing metadata fetch task
      metadataFetchTask?.cancel()
      
      // Background fetch metadata for link facets (non-blocking with delay)
      metadataFetchTask = Task { [weak self] in
        // Add small delay to prioritize main UI loading
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        await self?.fetchLinkMetadataInWrapper()
      }
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
      viewRecord.indexedAt.timeIntervalSince1970 > 0
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
      createdAt: viewRecord.indexedAt,
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

    // Process embeds array
    if let embeds = viewRecord.embeds {
      for embed in embeds {
        switch embed {
        case .embedImagesView(let imagesView):
          self.embeds = imagesView.images.map { image in
            TimelinePostWrapper.ImageEmbed(
              id: image.id,
              url: image.fullSizeImageURL,
              thumbURL: image.thumbnailImageURL,
              altText: image.altText
            )
          }
        case .embedExternalView(let externalView):
          self.linkExt = TimelinePostWrapper.LinkEmbed(
            desc: externalView.external.description,
            thumbnailImageURL: externalView.external.thumbnailImageURL,
            title: externalView.external.title,
            uri: externalView.external.uri
          )
        case .embedVideoView(let videoView):
          self.postVideo = TimelinePostWrapper.VideoEmbed(
            id: videoView.id,
            altText: videoView.altText,
            playlistURI: videoView.playlistURI,
            thumbImageURL: videoView.thumbnailImageURL,
            height: videoView.aspectRatio?.height,
            width: videoView.aspectRatio?.width
          )
        case .embedRecordWithMediaView(let combo):
          // Process the media component
          self.processMediaUnion(combo.media)
        default:
          break
        }
      }
    }

    // Check if we need to fetch metadata for link facets
    let hasUnfetchedLinks = self.facets?.links.contains { !$0.metadataFetched } ?? false
    
    if hasUnfetchedLinks {
      // Cancel any existing metadata fetch task
      metadataFetchTask?.cancel()
      
      // Background fetch metadata for link facets (non-blocking with delay)
      metadataFetchTask = Task { [weak self] in
        // Add small delay to prioritize main UI loading
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        await self?.fetchLinkMetadataInWrapper()
      }
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
    if let quoted = model.quotedPost {
      self.quotedPost = TimelinePostWrapper(from: quoted)
    }
    self.repostedByID = model.repostedByID
    self.repostedByHandle = model.repostedByHandle
    self.repostedByDisplayName = model.repostedByDisplayName
    self.repostedByAvatarURL = model.repostedByAvatarURL

    // Check if we need to fetch metadata for SwiftData loaded posts
    let hasUnfetchedLinks = self.facets?.links.contains { !$0.metadataFetched } ?? false
    
    if hasUnfetchedLinks {
      // Cancel any existing metadata fetch task
      metadataFetchTask?.cancel()
      
      // Background fetch metadata for link facets if not already fetched (for SwiftData loaded posts)
      metadataFetchTask = Task { [weak self] in
        // Add delay for SwiftData loaded posts to avoid blocking initial rendering
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second for cached posts
        
        // Check if task was cancelled
        guard !Task.isCancelled else { return }
        
        await self?.fetchLinkMetadataIfNeeded()
      }
    } 
  }
  
  deinit {
    // Cancel any running metadata fetch task to prevent memory leaks
    metadataFetchTask?.cancel()
  }

  func toModel(context: ModelContext, accountDID: String) -> TimelinePost {
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
      quotedPost: quotedPost?.toModel(context: context, accountDID: accountDID),
      fetchedWithCursor: fetchedWithCursor,
      parentPost: parentPost?.toModel(context: context, accountDID: accountDID),
      rootPost: rootPost?.toModel(context: context, accountDID: accountDID),
      repostedByID: repostedByID,
      repostedByHandle: repostedByHandle,
      repostedByDisplayName: repostedByDisplayName,
      repostedByAvatarURL: repostedByAvatarURL,
      accountDID: accountDID,
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

// Global set to track URLs currently being fetched to prevent duplicates
private actor URLFetchingTracker {
  private var fetchingURLs: Set<String> = []
  
  func startFetching(_ url: String) -> Bool {
    if fetchingURLs.contains(url) {
      return false // Already being fetched
    }
    fetchingURLs.insert(url)
    return true // Can proceed with fetch
  }
  
  func completeFetching(_ url: String) {
    fetchingURLs.remove(url)
  }
}

private let urlTracker = URLFetchingTracker()

  /// Checks if any link facets need metadata and fetches them if necessary
  func fetchLinkMetadataIfNeeded() async {
    guard let facets = self.facets else { 
      return 
    }

    // Only fetch for links that haven't been fetched yet
    let needsMetadata = facets.links.contains { facet in
      !facet.metadataFetched
    }

    await MainActor.run {
      if needsMetadata {
        let unprocessedLinks = facets.links.filter { !$0.metadataFetched }
        _ = unprocessedLinks.compactMap { facet in
          if case .link(let uri) = facet.data { return uri }
          return nil
        }
      }
    }

    if needsMetadata {
      await fetchLinkMetadataInWrapper()
    } 
  }

  /// Loads metadata from SwiftData for link facets that already have it stored
  @MainActor
  private func loadMetadataFromSwiftData(facets: [ProcessedFacet]) async -> [ProcessedFacet] {
    // Get the main context from LinkMetadataService
    guard let context = LinkMetadataService.shared.context else {
      return facets
    }

    var updatedFacets: [ProcessedFacet] = []
    
    for facet in facets {
      var updatedFacet = facet
      
      // Only check link facets that don't have metadata yet
      if case .link(let uri) = facet.data, !facet.metadataFetched {        
        // Check if we have this URL in SwiftData
        let descriptor = FetchDescriptor<PostFacet>(
          predicate: #Predicate<PostFacet> { storedFacet in
            storedFacet.uri == uri && storedFacet.metadataFetched == true
          }
        )
        
        do {
          let results = try context.fetch(descriptor)
          if let storedFacet = results.first {
            // Found existing metadata in SwiftData, use it
            updatedFacet.title = storedFacet.title
            updatedFacet.thumbnailURL = storedFacet.thumbnailURL
            updatedFacet.metadataFetched = true
          } 
        } catch {
          DevLogger.shared.log("TimelinePostWrapper.swift - loadMetadataFromSwiftData: ERROR querying SwiftData for \(uri): \(error)")
        }
      }      
      updatedFacets.append(updatedFacet)
    }
    return updatedFacets
  }

  /// Saves newly fetched metadata to SwiftData for future use
  @MainActor
  private func saveNewMetadataToSwiftData(updatedFacets: [ProcessedFacet]) async {
    guard let context = LinkMetadataService.shared.context else { return }
    
    for facet in updatedFacets {
      if case .link(let uri) = facet.data, facet.metadataFetched {
        // Check if this facet already exists in SwiftData
        let descriptor = FetchDescriptor<PostFacet>(
          predicate: #Predicate<PostFacet> { storedFacet in
            storedFacet.uri == uri
          }
        )
        
        if let existingFacet = try? context.fetch(descriptor).first {
          // Update existing facet
          existingFacet.title = facet.title
          existingFacet.thumbnailURL = facet.thumbnailURL
          existingFacet.metadataFetched = true
        } else {
          // Create new facet
          let newFacet = PostFacet(
            facetType: .link,
            startIndex: facet.range.location,
            endIndex: facet.range.location + facet.range.length,
            uri: uri,
            did: nil,
            tag: nil,
            handle: nil,
            title: facet.title,
            linkDescription: nil,
            thumbnailURL: facet.thumbnailURL,
            metadataFetched: true
          )
          context.insert(newFacet)
        }
      }
    }
    
    do {
      try context.save()
    } catch {
      DevLogger.shared.log("TimelinePostWrapper.swift - saveNewMetadataToSwiftData: Failed to save: \(error.localizedDescription)")
    }
  }

  /// Fetches metadata for link facets using SwiftData-first approach
  func fetchLinkMetadataInWrapper() async {
    guard let facets = self.facets else { 
      return 
    }
    
    // Check if task is cancelled early
    guard !Task.isCancelled else { return }

    _ = facets.facets.filter { facet in
      if case .link = facet.data { return true }
      return false
    }.count

    // First check SwiftData for existing metadata
    let updatedFacetsFromData = await loadMetadataFromSwiftData(facets: facets.facets)
    
    // Check if task is cancelled after SwiftData check
    guard !Task.isCancelled else { return }
    
    // Filter only link facets that still need metadata fetching after SwiftData check
    let linkFacetsToProcess = updatedFacetsFromData.filter { facet in
      if case .link = facet.data, !facet.metadataFetched {
        return true
      }
      return false
    }

    // If no facets need fetching, just update with SwiftData results
    if linkFacetsToProcess.isEmpty {
      await MainActor.run {
        self.facets = PostFacets(facets: updatedFacetsFromData)
      }
      return
    }

    // Create a map to store newly fetched link facets by their URI
    var updatedLinkFacets: [String: ProcessedFacet] = [:]

    // Process link facets in batches with concurrency control
    for (_, batch) in linkFacetsToProcess.chunked(into: 2).enumerated() {
      // Check if task is cancelled before processing each batch
      guard !Task.isCancelled else { return }
      
      let batchResults = await withTaskGroup(of: (String, ProcessedFacet).self, returning: [(String, ProcessedFacet)].self) { group in
        for facet in batch {
          group.addTask {
            var updatedFacet = facet
            var facetKey = ""
            
            if case .link(let uri) = facet.data {
              facetKey = uri             
              guard let url = URL(string: uri) else {
                updatedFacet.metadataFetched = true
                return (facetKey, updatedFacet)
              }

              // Check if this URL is already being fetched to prevent duplicates
              guard await self.urlTracker.startFetching(uri) else {
                updatedFacet.metadataFetched = true // Mark as processed to avoid retry
                return (facetKey, updatedFacet)
              }

              do {
                let metadataProvider = LPMetadataProvider()
                
                // Add timeout to prevent hanging
                let metadata = try await withTimeout(seconds: 8) {
                  try await metadataProvider.startFetchingMetadata(for: url)
                }

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
              
              // Mark URL as no longer being fetched
              await self.urlTracker.completeFetching(uri)
            }
            
            return (facetKey, updatedFacet)
          }
        }
        
        var results: [(String, ProcessedFacet)] = []
        for await (key, updatedFacet) in group {
          results.append((key, updatedFacet))
        }
        return results
      }
      
      // Store results in map
      for (key, facet) in batchResults {
        if !key.isEmpty {
          updatedLinkFacets[key] = facet
        }
      }
      
      // Small delay between batches
      try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }

    _ = updatedLinkFacets.count

    // Create final facets array combining SwiftData results with newly fetched data
    let finalFacets = updatedFacetsFromData.map { facet in
      // If this is a link facet that was newly updated, use the updated version
      if case .link(let uri) = facet.data,
         let updatedFacet = updatedLinkFacets[uri] {
        return updatedFacet
      }
      // Otherwise, return the facet (which may already have SwiftData metadata)
      return facet
    }
    
    // Save newly fetched metadata to SwiftData for future use
    await saveNewMetadataToSwiftData(updatedFacets: Array(updatedLinkFacets.values))

    // Update facets with new metadata on main thread
    await MainActor.run {
      _ = finalFacets.filter { facet in
        if case .link = facet.data { return true }
        return false
      }
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
      let success = await client.deleteRecord(.recordURI(atURI: likeURI))
      if !success {
        viewerLikeURI = likeURI
        likeCount += 1
      }
    } else {
      viewerLikeURI = "optimistic"
      likeCount += 1
      let strongRef = ComAtprotoLexicon.Repository.StrongReference(recordURI: uri, cidHash: cid)
      let result = await client.createLikeRecord(strongRef)
      if let recordURI = result?.recordURI {
        viewerLikeURI = recordURI
      } else {
        viewerLikeURI = originalURI
        likeCount = max(0, likeCount - 1)
      }
    }
  }
  
  // MARK: - ToggleRepost
  func toggleRepost(using client: BlueskyClient) async {
    let originalURI = viewerRepostURI
    if let repostURI = viewerRepostURI {
      viewerRepostURI = nil
      repostCount = max(0, repostCount - 1)
      let success = await client.deleteRecord(.recordURI(atURI: repostURI))
      if !success {
        viewerRepostURI = repostURI
        repostCount += 1
      }
    } else {
      viewerRepostURI = "optimistic"
      repostCount += 1
      let strongRef = ComAtprotoLexicon.Repository.StrongReference(recordURI: uri, cidHash: cid)
      let result = await client.createRepostRecord(
        strongRef,
        createdAt: Date(),
        shouldValidate: true
      )
      if let recordURI = result?.recordURI {
        viewerRepostURI = recordURI
      } else {
        viewerRepostURI = originalURI
        repostCount = max(0, repostCount - 1)
      }
    }
  }
}

extension TimelinePostWrapper.ImageEmbed {
  func toDisplayImage() -> ImageDisplayData {
    ImageDisplayData(id: id, url: url, thumbURL: thumbURL, altText: altText)
  }
}

// MARK: - Timeout Helper (local copy for TimelinePostWrapper)
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self, returning: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        guard let result = try await group.next() else {
            throw TimeoutError()
        }
        
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        return "Operation timed out"
    }
}

// MARK: - Array Extension for Chunking (local copy for TimelinePostWrapper)
extension Array {
  func chunked(into size: Int) -> [[Element]] {
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
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
  private var currentAccountDID: String?
  
  // Memory management constants
  private let maxPostsInMemory = 500           // Maximum posts to keep in memory
  private let maxPostsInDatabase = 1500        // Maximum posts to keep in database (3x memory)
  private let keepInDatabaseWhenCleaning = 1000 // Posts to keep when cleaning database
  private let softCleanupThreshold = 750       // When to start soft trim (preserves context)
  private let hardCleanupThreshold = 2000      // When to force hard trim (aggressive cleanup)
  private let keepAroundVisible = 30           // Posts to keep below visible post in soft trim

  init(context: ModelContext, client: BlueskyClient) {
    self.context = context
    self.client = client
    Task { @MainActor in
      self.currentAccountDID = client.currentDID
    }
  }

  func updateClient(_ newClient: BlueskyClient) {
    self.client = newClient
    Task { @MainActor in
      self.currentAccountDID = newClient.currentDID
    }
  }

  func loadFromStorage() {
    guard let accountDID = currentAccountDID else {
      print("No current account DID available for loading posts")
      posts = []
      oldestCursor = nil
      return
    }
    
    do {
      var descriptor = FetchDescriptor<TimelinePost>(
        predicate: #Predicate<TimelinePost> { post in
          post.accountDID == accountDID
        },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
      )
      descriptor.relationshipKeyPathsForPrefetching = [
        \.parentPost,
        \.rootPost,
        \.quotedPost,
        \.embeds,
        \.linkExt,
        \.postVideo,
        \.facets,
      ]

      let storedPosts = try context.fetch(descriptor)
      self.posts = storedPosts.map { TimelinePostWrapper(from: $0) }
      self.oldestCursor = storedPosts.last?.fetchedWithCursor
      print("Load from storage finished for account: \(accountDID)")
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
    
    // Apply memory management after adding posts
    trimMemoryIfNeeded()
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

    // Apply memory management after adding posts
    trimMemoryIfNeeded()
    
    // Pokud cursor přišel (většinou nil), tak jej neměníme — to se používá pro oldestCursor
    saveToStorage()
  }

  @MainActor
  func saveToStorage() {
    let newWrappers = posts.filter { $0.storageID == nil }
    guard let accountDID = currentAccountDID else {
      print("No current account DID available for saving posts")
      return
    }
    
    do {
      for wrapper in newWrappers {
        // Create and insert the model, letting SwiftData cascade to relationships
        let postModel = wrapper.toModel(context: context, accountDID: accountDID)
        context.insert(postModel)
        wrapper.storageID = postModel.id
      }
      try context.save()
      
      // Cleanup old posts if database is getting too large
      cleanupOldPostsIfNeeded()
    } catch {
      print("Failed to save timeline: \(error)")
    }
  }
  
  private func cleanupOldPostsIfNeeded() {
    guard let accountDID = currentAccountDID else { return }
    
    do {
      let descriptor = FetchDescriptor<TimelinePost>(
        predicate: #Predicate<TimelinePost> { post in
          post.accountDID == accountDID
        }
      )
      let allPosts = try context.fetch(descriptor)
      let postTypePosts = allPosts.filter { $0.type == .post }
        .sorted { $0.createdAt > $1.createdAt } // Sort newest first
      
      if postTypePosts.count > maxPostsInDatabase {
        // Keep keepInDatabaseWhenCleaning newest posts, delete the rest
        let postsToDelete = Array(postTypePosts.dropFirst(keepInDatabaseWhenCleaning))
        postsToDelete.forEach { context.delete($0) }
        try context.save()
        
        DevLogger.shared.log("TimelineFeed.swift - DB cleanup: removed \(postsToDelete.count) old posts for account \(accountDID), keeping \(keepInDatabaseWhenCleaning) newest")
      }
    } catch {
      print("Failed to cleanup old posts: \(error)")
    }
  }
  
  /// Trim in-memory posts if we exceed the limit
  @MainActor
  private func trimMemoryIfNeeded() {
    let postTypePosts = posts.filter { $0.type == .post }
    
    if postTypePosts.count > hardCleanupThreshold {
      // HARD TRIM - too many posts, must clean aggressively regardless of position
      let sortedPosts = posts.sorted { $0.createdAt > $1.createdAt }
      let postsToKeep = Array(sortedPosts.prefix(maxPostsInMemory))
      posts = postsToKeep
      
      DevLogger.shared.log("TimelineFeed - HARD trim: removed \(sortedPosts.count - postsToKeep.count) posts, keeping \(postsToKeep.count)")
      
    } else if postTypePosts.count > softCleanupThreshold {
      // SOFT TRIM - preserve context around visible post
      let visiblePostID = TimelinePositionManager.shared.getTimelinePosition()
      let sortedPosts = posts.sorted { $0.createdAt > $1.createdAt }
      
      if let visibleID = visiblePostID,
         let visibleIndex = sortedPosts.firstIndex(where: { $0.uri == visibleID }) {
        
        // Keep:
        // 1. All posts ABOVE visible (newer)
        // 2. The visible post
        // 3. keepAroundVisible posts BELOW visible
        
        let keepUntilIndex = min(visibleIndex + keepAroundVisible, sortedPosts.count - 1)
        let postsToKeep = Array(sortedPosts.prefix(keepUntilIndex + 1))
        
        // But maximum maxPostsInMemory
        let finalPosts = Array(postsToKeep.prefix(maxPostsInMemory))
        posts = finalPosts
        
        DevLogger.shared.log("TimelineFeed - SOFT trim around visible post: removed \(sortedPosts.count - finalPosts.count) posts, kept \(visibleIndex) posts above + \(min(keepAroundVisible, keepUntilIndex - visibleIndex)) below visible")
        
      } else {
        // Visible post not found or not set - standard trim
        let postsToKeep = Array(sortedPosts.prefix(maxPostsInMemory))
        posts = postsToKeep
        
        DevLogger.shared.log("TimelineFeed - SOFT trim (no visible): removed \(sortedPosts.count - postsToKeep.count) posts, keeping \(postsToKeep.count)")
      }
    }
    // If count is below softCleanupThreshold, do nothing
  }

  func clearStorage(forAllAccounts: Bool = false) {
    do {
      let descriptor: FetchDescriptor<TimelinePost>
      
      if forAllAccounts {
        // Clear all posts regardless of account
        descriptor = FetchDescriptor<TimelinePost>()
      } else {
        // Clear only posts for current account
        guard let accountDID = currentAccountDID else {
          print("No current account DID available for clearing posts")
          return
        }
        descriptor = FetchDescriptor<TimelinePost>(
          predicate: #Predicate<TimelinePost> { post in
            post.accountDID == accountDID
          }
        )
      }
      
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
    let recentPosts = posts
      .filter({ $0.type == .post })
      .sorted(by: { $0.createdAt > $1.createdAt })
      .prefix(20)  // Posledních 20 postů pro robustní matching
    
    if !recentPosts.isEmpty {
      let knownURIs = Set(recentPosts.map { $0.uri })
      let result = await client.fetchTimeline(since: knownURIs)
      let newPosts = result.posts
      let cursor = result.cursor
      await getFreshPosts(from: newPosts, cursor: cursor)
    } else {
      // Fallback pro prázdný timeline
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
