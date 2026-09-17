//
//  ProviderHealth.swift
//  MSRU
//

import Foundation


enum ProviderHealthStatus:
    String,
    Codable,
    Sendable {

    case available

    case degraded

    case unavailable

    case authenticationRequired
}


struct ProviderHealth:
    Sendable {

    let status:
        ProviderHealthStatus

    let message:
        String?

    let checkedAt:
        Date


    init(
        status:
            ProviderHealthStatus,
        message:
            String? = nil,
        checkedAt:
            Date = .now
    ) {

        self.status =
            status

        self.message =
            message

        self.checkedAt =
            checkedAt
    }
}


// MARK: - Convenience

extension ProviderHealth {

    static var available:
        ProviderHealth {

        ProviderHealth(
            status:
                .available
        )
    }


    static func degraded(
        _ message:
            String
    ) -> ProviderHealth {

        ProviderHealth(
            status:
                .degraded,
            message:
                message
        )
    }


    static func unavailable(
        _ message:
            String? = nil
    ) -> ProviderHealth {

        ProviderHealth(
            status:
                .unavailable,
            message:
                message
        )
    }


    static func authenticationRequired(
        _ message:
            String? = nil
    ) -> ProviderHealth {

        ProviderHealth(
            status:
                .authenticationRequired,
            message:
                message
        )
    }
}
