import SnapDeckCore
import SwiftUI

struct ZonePreviewView: View {
    let zone: SnapZone

    var body: some View {
        GlassBackground(cornerRadius: 20, veilOpacity: 0.17)
            .padding(6)
            .accessibilityLabel(zone.title)
    }
}
