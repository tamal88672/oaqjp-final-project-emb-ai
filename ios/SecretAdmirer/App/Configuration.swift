import Foundation

struct Configuration {
    let apiBaseURL: URL
    let publicBaseURL: URL

    static let `default` = Configuration(
        apiBaseURL: URL(string: "http://localhost:8080")!,
        publicBaseURL: URL(string: "http://localhost:5173")!
    )
}
