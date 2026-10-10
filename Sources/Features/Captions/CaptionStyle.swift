import CoreGraphics

struct CaptionStyle {
    var fontSize: CGFloat = 28
    var horizontalPadding: CGFloat = 20
    var verticalPadding: CGFloat = 12
    var cornerRadius: CGFloat = 12
    var backgroundOpacity = 0.7
    var pendingOpacity = 0.6
    var maxWidthRatio: CGFloat = 0.7
    var fallbackScreenWidth: CGFloat = 1200
}
