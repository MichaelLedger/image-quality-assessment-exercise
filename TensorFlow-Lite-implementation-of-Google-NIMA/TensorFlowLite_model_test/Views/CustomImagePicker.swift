import UIKit

class CustomImagePicker: UIImagePickerController {
    enum ScoringType {
        case nima
        case vision
    }
    
    var scoringType: ScoringType = .nima
}
