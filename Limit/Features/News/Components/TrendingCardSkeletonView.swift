//
//  TrendingCardSkeletonView.swift
//  Limit
//
//  Created by Claude
//

import SwiftUI

struct TrendingCardSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header skeleton
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 80, height: 12)
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 40, height: 10)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Image skeleton
            Rectangle()
                .fill(skeletonGradient)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            
            // Title skeleton with bookmark
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 240, height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 180, height: 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Bookmark skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Description skeleton
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(height: 14)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 200, height: 14)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Spacer(minLength: 12)
            
            // Bottom bar skeleton
            HStack(spacing: 20) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 40, height: 12)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 40, height: 12)
                }
                
                Spacer()
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 80, height: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.warmBackground.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .background(Color.warmBackground)
        .cornerRadius(16)
        .cardShadow()
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var skeletonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.subtleGray.opacity(isAnimating ? 0.3 : 0.5),
                Color.subtleGray.opacity(isAnimating ? 0.5 : 0.7),
                Color.subtleGray.opacity(isAnimating ? 0.3 : 0.5)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}