import CoreGraphics
import Foundation

public enum OverlayWindowGeometry {
    public static func contentFrame(for screenFrame: CGRect) -> CGRect {
        CGRect(origin: .zero, size: screenFrame.size)
    }

    public static func localPointerPosition(
        mouseLocation: CGPoint,
        screenFrame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: mouseLocation.x - screenFrame.minX,
            y: screenFrame.maxY - mouseLocation.y
        )
    }
}
