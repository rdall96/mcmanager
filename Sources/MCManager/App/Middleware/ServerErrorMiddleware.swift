//
//  ApplicationErrorMiddleware.swift
//  MCManager
//
//  Created by Ricky Dall'Armellina on 11/13/25.
//

import Foundation
import Vapor
import VaporToOpenAPI

@OpenAPIDescriptable
/// MCManager error response.
struct ErrorResponse: Codable {
    /// Always set to true to indicate this response is an error.
    /// Clients should be looking at the HTTP error code, but just in case they don't, this is a reliable way to check.
    let error: Bool = true

    /// Error code.
    let code: UInt

    /// The reason for the error.
    let reason: String

    /// A brief suggestion to fix the error.
    let suggestion: String?

    init(code: UInt = 0, reason: String, suggestion: String? = nil) {
        self.code = code
        self.reason = reason
        self.suggestion = suggestion
    }

    init(from applicationError: any ApplicationError) {
        self.init(
            code: applicationError.code,
            reason: applicationError.reason,
            suggestion: applicationError.recoverySuggestion
        )
    }

    enum CodingKeys: String, CodingKey {
        case error
        case code
        case reason
        case suggestion
    }
}

struct ApplicationErrorMiddleware: Middleware {
    func respond(
        to request: Request,
        chainingTo next: any Responder
    ) -> NIOCore.EventLoopFuture<Response> {
        next.respond(to: request).flatMapErrorThrowing { error in
            let status: HTTPResponseStatus
            let errorResponse: ErrorResponse

            if let applicationError = error as? ApplicationError {
                status = applicationError.status
                errorResponse = ErrorResponse(from: applicationError)

                request.logger.report(error: applicationError)
            }
            else if let abortError = error as? AbortError {
                status = abortError.status
                errorResponse = ErrorResponse(reason: abortError.reason)

                request.logger.report(error: abortError)
            }
            else {
                // Convert all unknown errors to 500.
                status = .internalServerError
                errorResponse = ErrorResponse(reason: "An unknown error occurred, please try again later.")

                request.logger.report(error: error)
            }

            return Response(
                status: status,
                headers: [:],
                body: .init(errorResponse)
            )
        }
    }
}

// MARK: - Helpers
fileprivate extension Response.Body {
    init<T: Encodable>(_ value: T) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(value)
            self.init(data: data)
        }
        catch {
            self.init(stringLiteral: "Failed encode error response: \(error.localizedDescription)")
        }
    }
}
