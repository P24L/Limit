//
//  LogViewer.swift
//  Limit
//
//  Created by Zdenek Indra on 20.05.2025.
//

import SwiftUI

struct LogViewer: View {
    @State private var logger = DevLogger.shared
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(logger.logs.reversed().indices, id: \.self) { i in
                    Text(logger.logs.reversed()[i])
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding()
        }
        .navigationTitle("Debug Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Button("Clear") {
                    logger.clear()
                }
            }
        }
    }
}

#Preview {
    LogViewer()
}
