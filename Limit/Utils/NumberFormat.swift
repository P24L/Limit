
import Foundation

extension Int {
    var abbreviated: String {
        self.formatted(.number.notation(.compactName))
    }
}