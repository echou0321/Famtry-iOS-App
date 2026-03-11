//
//  PantryOverviewScreen.swift
//  famtry
//
//  Created by Frecesca Wang.
//

import Foundation

final class APIClient {
    static let shared = APIClient()

    // Local development server
    var baseURL = URL(string: "http://localhost:5001/api")!

    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // Used for requests without a JSON body
    private struct EmptyBody: Encodable {}

    struct APIError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct ErrorResponse: Decodable {
        let error: String
    }

    // MARK: - Models (Decoding)

    struct APIUser: Decodable {
        let id: String
        let name: String
        let email: String
        let familyId: String?
        let family: APIFamily?

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case email
            case familyId
            case family
        }

        var familyIdResolved: String? {
            family?.id ?? familyId
        }
    }

    struct APIFamily: Decodable {
        let id: String
        let name: String
        let memberIds: [String]

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case members
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)

            if let stringIds = try? container.decode([String].self, forKey: .members) {
                memberIds = stringIds
            } else if let users = try? container.decode([APIUserStub].self, forKey: .members) {
                memberIds = users.map(\.id)
            } else {
                memberIds = []
            }
        }

        struct APIUserStub: Decodable {
            let id: String
            enum CodingKeys: String, CodingKey { case id = "_id" }
        }
    }

    struct LoginResponse: Decodable {
        let message: String
        let user: APIUser
    }

    typealias RegisterResponse = APIUser

    // MARK: - Requests

    private func makeURL(_ path: String) -> URL {
        baseURL.appending(path: path)
    }

    private func request<T: Decodable, Body: Encodable>(
        _ method: String,
        path: String,
        body: Body?,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response.")
        }

        if (200..<300).contains(http.statusCode) {
            return try JSONDecoder().decode(T.self, from: data)
        } else {
            if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError(message: err.error)
            }
            throw APIError(message: "Request failed (\(http.statusCode)).")
        }
    }

    private func request<T: Decodable>(
        _ method: String,
        path: String,
        responseType: T.Type
    ) async throws -> T {
        return try await request(method, path: path, body: Optional<EmptyBody>.none, responseType: responseType)
    }

    // MARK: - Auth

    struct RegisterBody: Encodable {
        let name: String
        let email: String
        let password: String
        let familyId: String?
    }

    func register(name: String, email: String, password: String, familyId: String? = nil) async throws -> RegisterResponse {
        try await request("POST", path: "/users/register", body: RegisterBody(name: name, email: email, password: password, familyId: familyId), responseType: RegisterResponse.self)
    }

    struct LoginBody: Encodable {
        let email: String
        let password: String
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        try await request("POST", path: "/users/login", body: LoginBody(email: email, password: password), responseType: LoginResponse.self)
    }

    // MARK: - Family

    struct CreateFamilyBody: Encodable {
        let name: String
        let userId: String?
    }

    func createFamily(name: String, userId: String) async throws -> APIFamily {
        try await request("POST", path: "/families", body: CreateFamilyBody(name: name, userId: userId), responseType: APIFamily.self)
    }

    struct JoinFamilyBody: Encodable {
        let userId: String
    }

    func joinFamily(familyId: String, userId: String) async throws -> APIFamily {
        try await request("POST", path: "/families/\(familyId)/join", body: JoinFamilyBody(userId: userId), responseType: APIFamily.self)
    }

    func getFamily(id: String) async throws -> APIFamily {
        try await request("GET", path: "/families/\(id)", responseType: APIFamily.self)
    }

    // MARK: - Family Members

    struct FamilyMember: Decodable, Identifiable {
        let id: String
        let name: String
        let email: String

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case email
        }
    }

    func getFamilyMembers(familyId: String) async throws -> [FamilyMember] {
        try await request("GET", path: "/families/\(familyId)/members", responseType: [FamilyMember].self)
    }
}

