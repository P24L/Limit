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
            VStack(alignment: .leading) {
                ForEach(logger.logs.indices, id: \.self) { i in
                    Text(logger.logs[i])
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 2)
                }
                .padding()
            }
        }
        .navigationTitle("Log")
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
