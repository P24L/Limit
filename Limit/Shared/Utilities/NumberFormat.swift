
import Foundation

extension Int {
    var abbreviated: String {
        self.formatted(.number.notation(.compactName))
    }
    
    var abbreviatedRounded: String {
        self.formatted(.number.notation(.compactName).precision(.fractionLength(0)))
    }
}