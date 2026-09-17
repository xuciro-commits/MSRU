//
//  PlaybackDiagnostics.swift
//  MSRU
//

import Foundation


enum PlaybackDiagnosticOutcome:
    String,
    Sendable {

    case skipped

    case succeeded

    case failed

    case resolveFailed
}


struct PlaybackDiagnosticEvent:
    Identifiable,
    Sendable {

    let id:
        UUID

    let requestID:
        UUID

    let trackID:
        String

    let providerID:
        PlaybackProviderID?

    let outcome:
        PlaybackDiagnosticOutcome

    let latencyMilliseconds:
        Double?

    let message:
        String?

    let timestamp:
        Date


    init(
        id:
            UUID = UUID(),
        requestID:
            UUID,
        trackID:
            String,
        providerID:
            PlaybackProviderID?,
        outcome:
            PlaybackDiagnosticOutcome,
        latencyMilliseconds:
            Double? = nil,
        message:
            String? = nil,
        timestamp:
            Date = .now
    ) {

        self.id =
            id

        self.requestID =
            requestID

        self.trackID =
            trackID

        self.providerID =
            providerID

        self.outcome =
            outcome

        self.latencyMilliseconds =
            latencyMilliseconds

        self.message =
            message

        self.timestamp =
            timestamp
    }
}


// MARK: - Diagnostics Store

actor PlaybackDiagnostics {

    private let capacity:
        Int

    private var events:
        [PlaybackDiagnosticEvent] = []


    init(
        capacity:
            Int = 200
    ) {

        self.capacity =
            max(
                20,
                capacity
            )
    }


    // MARK: Record

    func record(
        _ event:
            PlaybackDiagnosticEvent
    ) {

        events.append(
            event
        )


        let overflow =
            events.count
            - capacity


        if overflow > 0 {

            events.removeFirst(
                overflow
            )
        }
    }


    // MARK: Snapshot

    func recentEvents(
        limit:
            Int = 50
    ) -> [PlaybackDiagnosticEvent] {

        let count =
            min(
                max(
                    limit,
                    0
                ),
                events.count
            )


        return Array(
            events.suffix(
                count
            )
        )
    }


    // MARK: Clear

    func clear() {

        events.removeAll(
            keepingCapacity:
                true
        )
    }
}
