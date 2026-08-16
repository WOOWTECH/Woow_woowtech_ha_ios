import Foundation

public enum ExternalLink {
    public static var companionAppDocs = URL(string: "https://aiot.woowtech.io")!
    public static var discord = URL(string: "https://discord.com/channels/330944238910963714/1284965926336335993")!
    public static var githubReportIssue = URL(string: "https://aiot.woowtech.io/issues/new/choose")!
    public static func githubSearchIssue(domain: String) -> URL? {
        URL(string: "https://aiot.woowtech.io/search?q=\(domain)&type=issues")
    }

    public static var customWidgetsDocumentation =
        URL(string: "https://aiot.woowtech.io/docs/integrations/ios-widgets")!
}
