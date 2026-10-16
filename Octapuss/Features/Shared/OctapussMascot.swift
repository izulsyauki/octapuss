import SwiftUI

struct OctapussMascot: View {
    var compact = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: AppPalette.sunshine).opacity(0.24))
            Image(nsImage: PointerArtwork.companionImage(pack: .blush))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(compact ? 5 : 8)
        }
        .frame(width: compact ? 34 : 58, height: compact ? 34 : 58)
        .accessibilityHidden(true)
    }
}
