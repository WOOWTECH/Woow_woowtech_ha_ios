import Foundation
import Shared

class OnboardingAuthDetails: Equatable {
    var url: URL
    var scheme: String
    var exceptions: SecurityExceptions = .init()
    var clientCertificate: ClientCertificate?

    init(baseURL: URL) throws {
        guard var components = URLComponents(url: baseURL.serverBaseURL(), resolvingAgainstBaseURL: false) else {
            throw OnboardingAuthError(kind: .invalidURL)
        }

        components.path = "/auth/authorize"
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: AppConstants.OAuth.clientID),
            URLQueryItem(name: "redirect_uri", value: AppConstants.OAuth.redirectURI),
        ]

        guard let authURL = components.url else {
            throw OnboardingAuthError(kind: .invalidURL)
        }

        self.url = authURL
        self.scheme = AppConstants.urlScheme
    }

    static func == (lhs: OnboardingAuthDetails, rhs: OnboardingAuthDetails) -> Bool {
        lhs.url == rhs.url &&
            lhs.scheme == rhs.scheme &&
            lhs.exceptions == rhs.exceptions &&
            lhs.clientCertificate == rhs.clientCertificate
    }
}
