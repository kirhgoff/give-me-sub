import SwiftUI

struct LanguagePicker: View {
    static let title = "Language"
    static let auto = "Auto"

    @Binding var selection: Language?

    var body: some View {
        Picker(Self.title, selection: $selection) {
            Text(Self.auto).tag(Language?.none)
            ForEach(Language.allCases) { language in
                Text(language.displayName).tag(Optional(language))
            }
        }
    }
}

#Preview {
    LanguagePicker(selection: .constant(.english))
        .padding()
}
