import Foundation

final class APIClient {
    static let shared = APIClient()

    // Use hosted server
    var baseURL = URL(string: "https://famtry-backend-server-rkq1.onrender.com/api")!

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
        // Profile fields
        let avatar: String?
        let gender: String?
        let region: String?
        let phone: String?
        let signature: String?

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case email
            case familyId
            case family
            case avatar
            case gender
            case region
            case phone
            case signature
        }

        var familyIdResolved: String? {
            family?.id ?? familyId
        }
    }

    struct APIFamily: Decodable {
        let id: String
        let name: String
        let avatar: String?
        let description: String?
        let memberIds: [String]

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case avatar
            case description
            case members
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
            description = try container.decodeIfPresent(String.self, forKey: .description)

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
        let email: String?

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case email
        }
    }

    func getFamilyMembers(familyId: String) async throws -> [FamilyMember] {
        try await request("GET", path: "/families/\(familyId)/members", responseType: [FamilyMember].self)
    }

    // MARK: - Family Verify

    struct VerifyFamilyResponse: Decodable {
        let exists: Bool
        let name: String?
        let error: String?
    }

    func verifyFamily(familyId: String) async throws -> VerifyFamilyResponse {
        try await request("GET", path: "/families/\(familyId)/verify", responseType: VerifyFamilyResponse.self)
    }

    struct LeaveFamilyBody: Encodable {
        let userId: String
    }

    struct LeaveFamilyResponse: Decodable {
        let message: String
    }

    func leaveFamily(familyId: String, userId: String) async throws -> LeaveFamilyResponse {
        try await request("POST", path: "/families/\(familyId)/leave", body: LeaveFamilyBody(userId: userId), responseType: LeaveFamilyResponse.self)
    }

    // MARK: - User Profile

    struct UpdateProfileBody: Encodable {
        let name: String?
        let avatar: String?
        let gender: String?
        let region: String?
        let phone: String?
        let signature: String?
    }

    func updateProfile(userId: String, name: String? = nil, avatar: String? = nil, gender: String? = nil, region: String? = nil, phone: String? = nil, signature: String? = nil) async throws -> APIUser {
        try await request("PUT", path: "/users/\(userId)", body: UpdateProfileBody(name: name, avatar: avatar, gender: gender, region: region, phone: phone, signature: signature), responseType: APIUser.self)
    }

    // MARK: - Family Search

    func searchFamilies(query: String, limit: Int = 10) async throws -> [APIFamily] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await request("GET", path: "/families/search?q=\(encodedQuery)&limit=\(limit)", responseType: [APIFamily].self)
    }
    
    // MARK: - Items

    struct APIItemUser: Decodable {
        let id: String
        let name: String

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
        }
    }

    struct APIItem: Decodable {
        let id: String
        let name: String
        let quantity: Int
        let expirationDate: Date?
        let familyId: String?
        let owners: [APIItemUser]
        let pendingOwners: [APIItemUser]

        enum CodingKeys: String, CodingKey {
            case id = "_id"
            case name
            case quantity
            case expirationDate
            case familyId
            case owners
            case pendingOwners
        }

        struct APIFamilyRef: Decodable {
            let id: String

            enum CodingKeys: String, CodingKey {
                case id = "_id"
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            quantity = try container.decode(Int.self, forKey: .quantity)

            if let familyIdString = try? container.decode(String.self, forKey: .familyId) {
                familyId = familyIdString
            } else if let familyRef = try? container.decode(APIFamilyRef.self, forKey: .familyId) {
                familyId = familyRef.id
            } else {
                familyId = nil
            }

            owners = (try? container.decode([APIItemUser].self, forKey: .owners)) ?? []
            pendingOwners = (try? container.decode([APIItemUser].self, forKey: .pendingOwners)) ?? []

            if let dateString = try? container.decode(String.self, forKey: .expirationDate) {
                expirationDate = APIClient.parseFlexibleISODate(dateString)
            } else {
                expirationDate = nil
            }
        }
    }

    struct CreateItemBody: Encodable {
        let name: String
        let quantity: Int
        let expirationDate: Date?
        let ownerId: String
    }

    struct UpdateItemBody: Encodable {
        let quantity: Int?
        let expirationDate: Date?
        let userId: String
    }

    struct RequestOwnershipBody: Encodable {
        let userId: String
    }

    struct ApproverBody: Encodable {
        let approverId: String
    }

    private static func parseFlexibleISODate(_ string: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]

        return fractionalFormatter.date(from: string) ?? standardFormatter.date(from: string)
    }
    
    private func makeItemDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    private func itemRequest<T: Decodable, Body: Encodable>(
        _ method: String,
        path: String,
        body: Body?,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: makeURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else {
            throw APIError(message: "Invalid server response.")
        }

        if (200..<300).contains(http.statusCode) {
            return try makeItemDecoder().decode(T.self, from: data)
        } else {
            if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError(message: err.error)
            }
            throw APIError(message: "Request failed (\(http.statusCode)).")
        }
    }

    private func itemRequest<T: Decodable>(
        _ method: String,
        path: String,
        responseType: T.Type
    ) async throws -> T {
        try await itemRequest(method, path: path, body: Optional<EmptyBody>.none, responseType: responseType)
    }

    private func mapItem(_ apiItem: APIItem) -> PantryItem {
        PantryItem(
            id: apiItem.id,
            name: apiItem.name,
            quantity: apiItem.quantity,
            expirationDate: apiItem.expirationDate,
            familyId: apiItem.familyId,
            owners: apiItem.owners.map { ItemOwner(id: $0.id, name: $0.name) },
            pendingOwners: apiItem.pendingOwners.map { ItemOwner(id: $0.id, name: $0.name) }
        )
    }

    func getItems(familyId: String) async throws -> [PantryItem] {
        let items = try await itemRequest(
            "GET",
            path: "/items/families/\(familyId)/items",
            responseType: [APIItem].self
        )
        return items.map(mapItem)
    }

    func getItem(id: String) async throws -> PantryItem {
        let url = makeURL("/items/\(id)")
        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse {
            print("GET /items/:id status:", http.statusCode)
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            print("GET /items/:id raw JSON:", jsonString)
        }

        let item = try makeItemDecoder().decode(APIItem.self, from: data)
        return mapItem(item)
    }
//
//    func getItem(id: String) async throws -> PantryItem {
//        let item = try await itemRequest(
//            "GET",
//            path: "/items/\(id)",
//            responseType: APIItem.self
//        )
//        return mapItem(item)
//    }

    func createItem(
        familyId: String,
        name: String,
        quantity: Int,
        expirationDate: Date?,
        ownerId: String
    ) async throws -> PantryItem {
        let item = try await itemRequest(
            "POST",
            path: "/items/families/\(familyId)/items",
            body: CreateItemBody(
                name: name,
                quantity: quantity,
                expirationDate: expirationDate,
                ownerId: ownerId
            ),
            responseType: APIItem.self
        )
        return mapItem(item)
    }

    func updateItem(
        id: String,
        quantity: Int?,
        expirationDate: Date?,
        userId: String
    ) async throws -> PantryItem {
        let item = try await itemRequest(
            "PUT",
            path: "/items/\(id)",
            body: UpdateItemBody(
                quantity: quantity,
                expirationDate: expirationDate,
                userId: userId
            ),
            responseType: APIItem.self
        )
        return mapItem(item)
    }

    func requestOwnership(itemId: String, userId: String) async throws -> PantryItem {
        let item = try await itemRequest(
            "POST",
            path: "/items/\(itemId)/request-ownership",
            body: RequestOwnershipBody(userId: userId),
            responseType: APIItem.self
        )
        return mapItem(item)
    }

    func approveOwnership(itemId: String, requestedUserId: String, approverId: String) async throws -> PantryItem {
        let item = try await itemRequest(
            "POST",
            path: "/items/\(itemId)/approve-ownership/\(requestedUserId)",
            body: ApproverBody(approverId: approverId),
            responseType: APIItem.self
        )
        return mapItem(item)
    }

    func rejectOwnership(itemId: String, requestedUserId: String, approverId: String) async throws -> PantryItem {
        let item = try await itemRequest(
            "POST",
            path: "/items/\(itemId)/reject-ownership/\(requestedUserId)",
            body: ApproverBody(approverId: approverId),
            responseType: APIItem.self
        )
        return mapItem(item)
    }
}

