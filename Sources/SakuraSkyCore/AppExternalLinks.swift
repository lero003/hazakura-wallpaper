import Foundation

public enum AppExternalLinks {
    public static let labSiteURLString = "https://hazakuralab.pages.dev"

    public static var labSiteURL: URL? {
        URL(string: labSiteURLString)
    }
}
