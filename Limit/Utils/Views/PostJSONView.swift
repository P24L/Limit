//
//  PostJSONView.swift
//  Limit
//
//  Created by Zdenek Indra on 22.05.2025.
//

import Foundation
import SwiftUI
/*
struct PostJSONView: View {
    @State var post: TimelinePost
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .padding()
            }
            PostItemView(post: post)
            VStack(alignment: .leading, spacing: 4) {
                Text("Post ID \(post.id)")
                Text("isReply: \(post.isReply.description)")
                Text("isSelfThreadReply: \(post.isSelfThreadReply.description)")
                Text("threadRootID: \(post.threadRootID ?? "nil")")
                Text("isReplyToParentOther: \(post.isReplyToParentOther.description)")
                Text("repostedBy:\(post.repostedByIDs.first ?? "nil")")
                Text("JSON is empty:\(String(post.rawData?.isEmpty ?? true))")
            }
            .padding(.horizontal)
            .font(.caption)
            .foregroundStyle(.gray)
            Divider()
            ScrollView {
                if let raw = post.rawData,
                   let data = raw.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data),
                   let dict = jsonObject as? [String: Any] {
                    VStack(alignment: .leading) {
                        JSONNodeView(key: "root", value: dict)
                    }
                    .padding()
                } else {
                    Text("Invalid or empty JSON.")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
*/
struct JSONNodeView: View {
    var key: String
    var value: Any

    var body: some View {
        if let dict = value as? [String: Any] {
            DisclosureGroup(key) {
                ForEach(dict.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                    JSONNodeView(key: k, value: v)
                        .padding(.leading)
                }
            }
        } else if let array = value as? [Any] {
            DisclosureGroup(key) {
                ForEach(0..<array.count, id: \.self) { i in
                    JSONNodeView(key: "[\(i)]", value: array[i])
                        .padding(.leading)
                }
            }
        } else {
            HStack(alignment: .top) {
                Text(key)
                    .bold()
                Spacer()
                Text("\(value as? String ?? "\(value)")")
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
