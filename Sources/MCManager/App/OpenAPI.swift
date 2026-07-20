//
//  OpenAPI.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 7/13/26.
//

import Foundation
import Fluent
import Vapor
@preconcurrency import VaporToOpenAPI

// MCManager OpenAPI tags
extension TagObject {

    /// Application info.
    static let application = TagObject(name: "Application", description: "General application info.")

    /// User authentication.
    static let auth = TagObject(name: "Authentication", description: "User authentication.")

    /// Role management.
    static let roles = TagObject(name: "Roles", description: "Role management.")

    /// Minecraft server management.
    static let servers = TagObject(name: "Servers", description: "Minecraft server management.")

    /// Minecraft server files.
    static let serverFiles = TagObject(name: "Server files", description: "Minecraft server files.")

    /// Minecraft server player management.
    static let serverPlayerManagement = TagObject(name: "Server player management", description: "Minecraft server player management.")

    /// Minecraft server properties.
    static let serverProperties = TagObject(name: "Server properties", description: "Minecraft server properties.")

    /// Application settings.
    static let settings = TagObject(name: "Settings", description: "Application settings.")

    /// User management.
    static let users = TagObject(name: "Users", description: "User management.")

}

struct OpenAPIRoutes: RouteCollection {

    private let app: Application

    init(_ app: Application) {
        self.app = app
    }

    private var publicDirectoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // App/
            .deletingLastPathComponent() // MCManager/
            .deletingLastPathComponent() // Sources/
            .deletingLastPathComponent() // project root/
            .appendingPathComponent("Public")
    }

    func boot(routes: any RoutesBuilder) throws {
        // Only register OpenAPI routes for DEBUG builds
        #if DEBUG
        // OAS file
        routes.get("oas.json") { req throws -> Response in
            guard let openAPIVersion = SwiftOpenAPI.Version(AppVersion.latest.description) else {
                throw Abort(.internalServerError, reason: "Failed to get app version")
            }
            let appInfo = InfoObject(title: "MCManager API", version: openAPIVersion)
            let spec = req.application.routes.openAPI(info: appInfo)

            // Encode the spec with sorted keys and make it pretty-printed
            // This allows for a repeatable result when fetching the OAS file
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            let data = try encoder.encode(spec)

            return Response(status: .ok, body: .init(data: data))
        }
        .excludeFromOpenAPI()

        // Swagger UI
        routes.get("Swagger") { req in
            try await req.fileio.asyncStreamFile(at: publicDirectoryURL.appendingPathComponent("Swagger/index.html").path)
        }
        .excludeFromOpenAPI()

        // Serve files from public directory
        app.middleware.use(FileMiddleware(publicDirectory: publicDirectoryURL.path))
        #endif // DEBUG
    }
}

// MARK: - Requests

/// Helper object to wrap an API request into OpenAPI metadata used to annotate endpoints.
struct OpenAPIRequest {
    let query: OpenAPIParameters?
    let body: OpenAPIBody?
    let contentType: MediaType
    let requiresAuthentication: Bool

    init(
        query: OpenAPIParameters? = nil,
        body: OpenAPIBody? = nil,
        contentType: MediaType = .any,
        requiresAuthentication: Bool = false
    ) {
        self.query = query
        self.body = body
        self.contentType = contentType
        self.requiresAuthentication = requiresAuthentication
    }

    init<Body: Encodable>(
        body: Body,
        contentType: MediaType,
        requiresAuthentication: Bool
    ) {
        self.init(
            body: .type(of: body),
            contentType: contentType,
            requiresAuthentication: requiresAuthentication
        )
    }

    init<Query: Encodable>(query: Query, requiresAuthentication: Bool) {
        self.init(
            query: .type(of: query),
            requiresAuthentication: requiresAuthentication
        )
    }

    init<Query: Encodable, Body: Encodable>(
        query: Query,
        body: Body,
        contentType: MediaType,
        requiresAuthentication: Bool
    ) {
        self.init(
            query: .type(of: query),
            body: .type(of: body),
            contentType: contentType,
            requiresAuthentication: requiresAuthentication
        )
    }
}

// Request auth
extension AuthSchemeObject {
    static let mcmanagerUserToken: Self = .bearer(format: "JWT", description: "User authentication token.")
}

// Example requests
extension OpenAPIRequest {

    /// User authentication credentials.
    static let userCredentialsRequest = OpenAPIRequest(
        body: ModelCredentials(username: "admin", password: "mcmanager"),
        contentType: .application(.urlEncoded),
        requiresAuthentication: false
    )

    /// Empty request that requires authentication.
    static let requiresAuthentication = OpenAPIRequest(requiresAuthentication: true)

    /// Update settings.
    static let updateSettingsRequest = OpenAPIRequest(
        body: Settings.defaults,
        contentType: .application(.json),
        requiresAuthentication: true
    )

    private static let userRequestExample = UserRequest(username: "steve", password: "mcmanager", isAdmin: false, role: UUID())

    /// Create/edit a user.
    static let userRequest = OpenAPIRequest(
        body: userRequestExample,
        contentType: .application(.json),
        requiresAuthentication: true
    )

    private static let roleRequestExample = RoleRequest(name: "Moderator", permissions: PermissionsRequest())

    /// Create/edit a role.
    static let roleRequest = OpenAPIRequest(
        body: roleRequestExample,
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Edit permissions.
    static let permissionsRequest = OpenAPIRequest(
        body: PermissionsRequest(application: [], users: [.readUsers], servers: [.startStopServers]),
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Fetch servers.
    static let fetchServersRequest = OpenAPIRequest(
        query: MinecraftServerFetchRequest(type: .java),
        requiresAuthentication: true
    )

    /// Create a server.
    static let serverCreateRequest = OpenAPIRequest(
        body: MinecraftServerRequest(
            name: "Vanilla server",
            type: .java,
            version: MinecraftServer.Version(major: 26, minor: 2),
            port: MinecraftServerRuntime.Defaults.minecraftServerPort
        ),
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Edit a server.
    static let serverEditRequest = OpenAPIRequest(
        body: MinecraftServerRequest(
            name: "Vanilla server",
            type: nil, // intentionally omitted
            version: MinecraftServer.Version(major: 26, minor: 2),
            port: MinecraftServerRuntime.Defaults.minecraftServerPort
        ),
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Edit server properties.
    static let serverPropertiesRequest = OpenAPIRequest(
        body: MinecraftServer.Properties.defaults,
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Send a command to a server.
    static let sendServerCommandRequest = OpenAPIRequest(
        body: "weather clear",
        contentType: .text(.plain),
        requiresAuthentication: true
    )

    /// Fetch the server logs.
    static let fetchServerLogsRequest = OpenAPIRequest(
        query: MinecraftServerFetchLogsRequest(tail: 100),
        requiresAuthentication: true
    )

    /// Server files filter.
    static let serverFilesRequest = OpenAPIRequest(
        query: FileRequest(path: "world"),
        requiresAuthentication: true
    )

    private static let fileUploadRequestExample = FileUploadRequest(
        filePath: "world/datapacks/MyAwesomeDatapack.zip",
        fileType: .file,
        checksum: "9dcfdb6d63f79d08df509422748e7723"
    )

    /// Upload a file.
    static let serverFileUploadRequest = OpenAPIRequest(
        query: .type(of: fileUploadRequestExample),
        body: .schema(.string(format: .binary)),
        contentType: .application(.octetStream),
        requiresAuthentication: true
    )

    private static let serverPlayerExample = MinecraftPlayerInfo(name: "Notch")

    private static let serverOperatorExample = MinecraftServer.Operator(
        name: "Notch",
        level: 3,
        ignoresPlayerLimit: false
    )

    /// Add a server operator.
    static let addServerOperatorRequest = OpenAPIRequest(
        body: .any(of: .type(of: serverOperatorExample), .type(of: serverPlayerExample)),
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Remove a server operator.
    static let removeServerOperatorRequest = OpenAPIRequest(
        body: serverPlayerExample,
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Add whitelisted player.
    static let addWhitelistedPlayerRequest = OpenAPIRequest(
        body: serverPlayerExample,
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Remove a server operator.
    static let removeWhitelistedPlayerRequest = OpenAPIRequest(
        body: serverPlayerExample,
        contentType: .application(.json),
        requiresAuthentication: true
    )

    private static let bannedPlayerExample = MinecraftServer.BannedPlayer(name: "Notch", reason: "Too good at the game")

    /// Ban a player.
    static let banPlayerRequest = OpenAPIRequest(
        body: .any(of: .type(of: bannedPlayerExample), .type(of: serverPlayerExample)),
        contentType: .application(.json),
        requiresAuthentication: true
    )

    /// Pardon a player.
    static let pardonPlayerRequest = OpenAPIRequest(
        body: serverPlayerExample,
        contentType: .application(.json),
        requiresAuthentication: true
    )

}

// MARK: - Responses

/// Helper object to wrap an API response into OpenAPI metadata used to annotate endpoints.
struct OpenAPIResponse {
    let statusCode: ResponsesObject.Key
    let body: OpenAPIBody?
    let contentType: MediaType
    let description: String

    init(
        statusCode: ResponsesObject.Key,
        body: OpenAPIBody? = nil,
        contentType: MediaType = .any,
        description: String? = nil
    ) {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
        self.description = description ?? statusCode.description
    }

    init<T: Encodable>(
        statusCode: ResponsesObject.Key,
        example: T,
        contentType: MediaType,
        description: String? = nil
    ) {
        self.init(
            statusCode: statusCode,
            body: .type(of: example),
            contentType: contentType,
            description: description
        )
    }

    init<E: ApplicationError>(error: E, contentType: MediaType) {
        self.init(
            statusCode: ResponsesObject.Key(error.status),
            body: .type(ErrorResponse.self),
            contentType: contentType,
            description: error.description
        )
    }
}

extension ErrorResponse: WithExample {
    // Create an ErrorReponse example to avoid letting OpenAPI choose one for us.
    // See OpenAPIResponse(statusCode:error:contentType:description:)
    static var example: ErrorResponse {
        ErrorResponse(code: 9999, reason: "An error occurred.", suggestion: "Try again.")
    }
}

// Example responses
extension OpenAPIResponse {

    /// App version.
    static let appVersion = OpenAPIResponse(
        statusCode: .ok,
        example: AppVersion.latest,
        contentType: .text(.plain),
        description: "Application version"
    )

    /// Empty response.
    static let emptyResponse = OpenAPIResponse(statusCode: .noContent, description: "")

    /// Operation succeeded.
    static func success(_ description: String? = nil) -> OpenAPIResponse {
        OpenAPIResponse(statusCode: .ok, description: description)
    }

    /// An ApplicationError reponse.
    static func applicationError<E: ApplicationError>(_ error: E) -> OpenAPIResponse {
        OpenAPIResponse(error: error, contentType: .application(.json))
    }

    /// Decoding error.
    static let badRequestResponse = OpenAPIResponse(
        statusCode: .badRequest,
        body: .type(ErrorResponse.self),
        contentType: .application(.json),
        description: "Invalid request data"
    )

    /// User is not authenticated.
    static let notAuthenticatedResponse = applicationError(AuthenticationError.notAuthenticated)

    /// Invalid user credentials.
    static let invalidCredentialsResponse = applicationError(AuthenticationError.invalidCredentials)

    /// User session token.
    static let authenticationSuccessfulResponse = OpenAPIResponse(
        statusCode: .ok,
        example: ClientSession(accessToken: "jws"),
        contentType: .application(.json),
        description: "Successful authentication"
    )

    /// Public key.
    static let publicKeyResponse = OpenAPIResponse(
        statusCode: .ok,
        body: .type(String.self),
        contentType: .text(.plain),
        description: "Public key"
    )

    /// Application settings.
    static let applicationSettingsResponse = OpenAPIResponse(
        statusCode: .ok,
        example: Settings.defaults,
        contentType: .application(.json),
        description: "Application settings"
    )

    private static let userExample = try! User(username: "steve", password: "creeper", isAdmin: false, roleID: UUID())

    /// Users.
    static let usersResponse = OpenAPIResponse(
        statusCode: .ok,
        example: [userExample],
        contentType: .application(.json),
        description: "List of users"
    )

    /// User.
    static let userResponse = OpenAPIResponse(
        statusCode: .ok,
        example: userExample,
        contentType: .application(.json),
        description: "User information"
    )

    /// User already exists.
    static let duplicateUserResponse = applicationError(UserError.alreadyExists)

    /// User not found.
    static let userNotFoundResponse = applicationError(UserError.notFound)

    /// Admin required for this operation.
    static let adminRequiredResponse = applicationError(UserError.adminRequired)

    /// Missing user name.
    static let missingUsernameResponse = applicationError(UserError.missingUsername)

    /// The admin can't be deleted.
    static let cantDeleteAdminResponse = applicationError(UserError.cantDeleteAdmin)

    private static let permissionsExample = Permissions(users: [.readUsers], servers: [.createServers, .editServers, .editServerProperties, .deleteServers, .startStopServers])
    private static let roleExample = RoleResponse(name: "Moderator", permissions: permissionsExample)

    /// Roles.
    static let rolesResponse = OpenAPIResponse(
        statusCode: .ok,
        example: [roleExample],
        contentType: .application(.json),
        description: "List of roles"
    )

    /// Role.
    static let roleResponse = OpenAPIResponse(
        statusCode: .ok,
        example: roleExample,
        contentType: .application(.json),
        description: "Role information"
    )

    /// Role already exists.
    static let duplicateRoleResponse = applicationError(RoleError.alreadyExists)

    /// Role not found.
    static let roleNotFoundResponse = applicationError(RoleError.notFound)

    /// Role not found.
    static let cantDeleteRoleResponse = applicationError(RoleError.notFound)

    /// Default permissions response.
    static let defaultPermissionsResponse = OpenAPIResponse(
        statusCode: .ok,
        example: permissionsExample,
        contentType: .application(.json),
        description: "Default user permissions"
    )

    private static let supportedServerRuntimesExample = [
        MinecraftServer.RuntimeSupport(type: .java, versions: ["26.2", "26.1.2", "1.21.4"].compactMap { MinecraftServer.Version(string: $0) }),
    ]

    /// Server runtime support.
    static let serverRuntimeSupportResponse = OpenAPIResponse(
        statusCode: .ok,
        example: supportedServerRuntimesExample,
        contentType: .application(.json),
        description: "Supported server runtimes"
    )

    /// Server properties.
    static let serverPropertiesResponse = OpenAPIResponse(
        statusCode: .ok,
        example: MinecraftServer.Properties.defaults,
        contentType: .application(.json),
        description: "Minecraft server properties"
    )

    private static let minecraftServerExample = MinecraftServer(
        name: "Vanilla server",
        type: .java,
        version: MinecraftServer.Version(major: 26, minor: 2),
        port: MinecraftServerRuntime.Defaults.minecraftServerPort
    )

    /// Minecraft servers.
    static let minecraftServersResponse = OpenAPIResponse(
        statusCode: .ok,
        example: [minecraftServerExample],
        contentType: .application(.json),
        description: "Minecraft servers"
    )

    /// Minecraft server.
    static let minecraftServerResponse = OpenAPIResponse(
        statusCode: .ok,
        example: minecraftServerExample,
        contentType: .application(.json),
        description: "Minecraft server"
    )

    /// Server not found.
    static let serverNotFoundResponse = applicationError(MinecraftServerError.notFound)

    private static let serverInfoExample = MinecraftServer.Info(
        status: .running,
        needsRestart: false,
        onlinePlayers: ["Notch"]
    )

    /// Server info.
    static let serverInfoResponse = OpenAPIResponse(
        statusCode: .ok,
        example: serverInfoExample,
        contentType: .application(.json),
        description: "Server info"
    )

    private static let serverStatsExample = MinecraftServer.Stats(
        cpuPercent: 0.24,
        memoryUsage: 12288000
    )

    /// Server stats.
    static let serverStatsResponse = OpenAPIResponse(
        statusCode: .ok,
        example: serverStatsExample,
        contentType: .application(.json),
        description: "Server system resources usage"
    )

    static let maxRunningServersLimitReachedResponse = applicationError(MinecraftServerError.tooManyRunningServers)

    static let serverPortInUseResponse = applicationError(MinecraftServerError.portAlreadyInUse)

    static let serverRunningResponse = applicationError(MinecraftServerError.running)

    static let serverStoppedResponse = applicationError(MinecraftServerError.stopped)

    /// Server logs.
    static let serverLogsResponse = OpenAPIResponse(
        statusCode: .ok,
        example: [""],
        contentType: .application(.json),
        description: "Minecraft server logs"
    )

    /// Minecraft server archive.
    static let serverArchiveResponse = OpenAPIResponse(
        statusCode: .ok,
        body: .schema(.string(format: .binary)),
        contentType: .application(.zip),
        description: "Minecraft server zip archive"
    )

    /// Minecraft server files info.
    static let serverFilesResponse = OpenAPIResponse(
        statusCode: .ok,
        example: FileBrowser(
            relativePath: "world",
            files: ["DIM-1", "datapacks"]
        ),
        contentType: .application(.json),
        description: "Minecraft server files info"
    )

    static let serverFileDoesNotExistResponse = applicationError(MinecraftServerError.fileDoesNotExist)

    /// Server file download.
    static let serverFileDownloadResponse = OpenAPIResponse(
        statusCode: .ok,
        body: .schema(.string(format: .binary)),
        contentType: .application(.octetStream),
        description: "A file"
    )

    private static let serverOperatorExample = MinecraftServer.Operator(
        name: "Notch",
        level: 3,
        ignoresPlayerLimit: false
    )

    /// Server operators.
    static let serverOperatorsResponse = OpenAPIResponse(
        statusCode: .ok,
        example: [serverOperatorExample],
        contentType: .application(.json),
        description: "Server operators"
    )

    private static let serverWhitelistedPlayerExample = MinecraftPlayerInfo(name: "Notch")

    /// Server whitelist.
    static let serverWhitelistResponse = OpenAPIResponse(
        statusCode: .ok,
        example: [serverWhitelistedPlayerExample],
        contentType: .application(.json),
        description: "Server whitelist"
    )

    private static let serverBannedPlayerExample = MinecraftServer.BannedPlayer(name: "Notch", reason: "Too good at the game")

    /// Server banned players.
    static let serverBannedPlayersResponse = OpenAPIResponse(
        statusCode: .ok,
        example: [serverBannedPlayerExample],
        contentType: .application(.json),
        description: "Banned players"
    )

}

// MARK: - Route helpers
// Helper methods to add OpenAPI annotations to the server APIs and remove as much boilerplate as possible

extension Route {

    /// Add OpenAPI annotation to a route.
    @discardableResult
    func openAPIMetadata(
        summary: String,
        tag: TagObject? = nil,
        request: OpenAPIRequest = OpenAPIRequest(),
        permissions: Permissions? = nil,
        responses: OpenAPIResponse...
    ) -> Route {
        var route = self

        if request.requiresAuthentication {
            // add summary, request info, and auth
            route = self.openAPI(
                summary: summary.openAPIDescription,
                query: request.query,
                body: request.body,
                contentType: request.contentType,
                auth: .mcmanagerUserToken
            )
        }
        else {
            // add summary and request info
            route = self.openAPI(
                summary: summary.openAPIDescription,
                query: request.query,
                body: request.body,
                contentType: request.contentType
            )
        }

        // add tags
        if let tag {
            // VaporToOpenAPI doens't provide an easy way to "add" tags
            // without overwriting the existing openAPI annotations,
            // so we need to manually merge the new tag with the existing ones.
            route = route.openAPI(custom: \.tags) { tags in
                tags = (tags ?? []) + [tag.name]
            }
        }

        // add responses
        route = route.openAPIResponses(responses)

        // if the request has a body, automatically add a 'badRequest' response since we have to parse that data
        if request.body != nil {
            route = route.openAPIResponse(.badRequestResponse)
        }

        // if the request requires any permissions, automatically add an unauthorized response
        if permissions != nil {
            // FIXME: Add info regarding the actual user permissions required for this action
            route = route.openAPIResponse(.applicationError(UserError.unauthorized))
        }

        return route
    }

    /// Add OpenAPI response information to a route.
    @discardableResult
    private func openAPIResponse(_ response: OpenAPIResponse) -> Route {
        return self.response(
            statusCode: response.statusCode,
            body: response.body,
            contentType: response.contentType,
            description: response.description.openAPIDescription
        )
    }

    /// Add multiple OpenAPI responses to a route.
    @discardableResult
    private func openAPIResponses(_ responses: [OpenAPIResponse]) -> Route {
        return responses.reduce(self) { result, response in
            result.openAPIResponse(response)
        }
    }
}

extension RoutesBuilder {
    /// Add OpenAPI info to a group of routes.
    func openAPIMetadata(
        tags: TagObject...,
        requiresAuthentication: Bool = false
    ) -> any RoutesBuilder {
        if requiresAuthentication {
            return self.groupedOpenAPI(tags: tags)
                .groupedOpenAPI(auth: .mcmanagerUserToken)
                .openAPIResponse(.notAuthenticatedResponse)
        }
        else {
            return self.groupedOpenAPI(tags: tags)
        }
    }

    /// Add OpenAPI response information to a group of routes.
    @discardableResult
    func openAPIResponse(_ response: OpenAPIResponse) -> any RoutesBuilder {
        return self.groupedOpenAPIResponse(
            statusCode: response.statusCode,
            body: response.body,
            contentType: response.contentType,
            description: response.description.openAPIDescription
        )
    }
}

// MARK: - Type conversions

fileprivate extension String {
    /// Format the string as an OpenAPI description.
    var openAPIDescription: String {
        // Ensure there's a period at the end of every sentence.
        last == "." ? self : self + "."
    }
}

fileprivate extension ResponsesObject.Key {
    init(_ status: HTTPStatus) {
        self.init(integerLiteral: Int(status.code))
    }
}

fileprivate extension MediaType.Application {
    static let zip: Self = "zip"
}
