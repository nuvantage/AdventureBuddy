import SwiftUI

struct OutingMapPin: View {
    let symbolName: String
    var isSelected = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? AdventureTheme.forest : AdventureTheme.ember)
                    .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                    .shadow(color: AdventureTheme.trail.opacity(0.35), radius: 5, y: 3)
                Image(systemName: symbolName)
                    .font(isSelected ? .headline : .subheadline)
                    .foregroundStyle(AdventureTheme.sand)
            }
            Image(systemName: "triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? AdventureTheme.forest : AdventureTheme.ember)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
        .animation(.spring(duration: 0.28), value: isSelected)
    }
}

#Preview {
    ZStack {
        AdventureTheme.sand
        OutingMapPin(symbolName: "figure.walk", isSelected: true)
    }
}
