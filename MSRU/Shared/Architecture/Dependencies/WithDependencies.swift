//
//  WithDependencies.swift
//  MSRU
//

import Foundation


// MARK: - Existing Values

@MainActor
func withDependencies<Result>(
    _ values:
        DependencyValues,
    operation:
        () throws -> Result
) rethrows -> Result {

    try DependencyContext
        .$current
        .withValue(
            values
        ) {

            try operation()
        }
}


// MARK: - Existing Values + Async

@MainActor
func withDependencies<Result>(
    _ values:
        DependencyValues,
    operation:
        () async throws -> Result
) async rethrows -> Result {

    try await DependencyContext
        .$current
        .withValue(
            values
        ) {

            try await operation()
        }
}


// MARK: - Mutate Current Values

@MainActor
func withDependencies<Result>(
    _ update:
        (
            inout DependencyValues
        ) -> Void,
    operation:
        () throws -> Result
) rethrows -> Result {

    var values =
        DependencyValues
            .current


    update(
        &values
    )


    return
        try withDependencies(
            values,
            operation:
                operation
        )
}


// MARK: - Mutate Current Values + Async

@MainActor
func withDependencies<Result>(
    _ update:
        (
            inout DependencyValues
        ) -> Void,
    operation:
        () async throws -> Result
) async rethrows -> Result {

    var values =
        DependencyValues
            .current


    update(
        &values
    )


    return
        try await withDependencies(
            values,
            operation:
                operation
        )
}
