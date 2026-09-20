import Testing
@testable import AppFoundation

@MainActor
private final class Signal {
    private var signaled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if signaled { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func fire() {
        signaled = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }
}

@MainActor
private enum LifetimeFeature: Feature {
    final class State { var values: [Int] = [] }
    enum Action {
        case run(FeatureTask<Action>)
        case received(Int)
    }
    struct Service: FeatureService {
        func handle(_ action: Action, state: State) -> [FeatureTask<Action>] {
            switch action {
            case .run(let task): return [task]
            case .received(let value): state.values.append(value); return []
            }
        }
    }
    static func makeInitialState() -> State { State() }
}

@MainActor
struct FeatureTaskLifetimeTests {
    @Test(arguments: [false, true])
    func canceledNonCooperativeOperationCannotSend(anonymous: Bool) async {
        let host = FeatureHost<LifetimeFeature>(service: .init())
        let started = Signal(), release = Signal(), finished = Signal()
        host.send(.run(.run(id: anonymous ? nil : "load") { send in
            started.fire()
            await release.wait() // Deliberately ignores Task cancellation.
            send(.received(1))
            finished.fire()
        }))
        await started.wait()
        if anonymous { host.cancelAll() } else { host.cancel(id: "load") }
        release.fire()
        await finished.wait()
        #expect(host.state.values.isEmpty)
    }

    @Test
    func replacementRejectsOldResultAndAcceptsNewResult() async {
        let host = FeatureHost<LifetimeFeature>(service: .init())
        let started = Signal(), release = Signal(), oldFinished = Signal(), newFinished = Signal()
        host.send(.run(.run(id: "load") { send in
            started.fire()
            await release.wait()
            send(.received(1))
            oldFinished.fire()
        }))
        await started.wait()
        host.send(.run(.run(id: "load", cancelInFlight: true) { send in
            send(.received(2))
            newFinished.fire()
        }))
        await newFinished.wait()
        release.fire()
        await oldFinished.wait()
        #expect(host.state.values == [2])
    }

    @Test
    func escapedCallbackExpiresWhenOperationReturns() async {
        let host = FeatureHost<LifetimeFeature>(service: .init())
        let finished = Signal()
        var callback: FeatureTask<LifetimeFeature.Action>.Send?
        host.send(.run(.run { send in
            callback = send
            send(.received(1))
            finished.fire()
        }))
        await finished.wait()
        callback?(.received(2))
        #expect(host.state.values == [1])
    }

    @Test
    func stopRevokesCallbackAndPreventsFurtherSends() async {
        let host = FeatureHost<LifetimeFeature>(service: .init())
        let started = Signal(), release = Signal(), finished = Signal()

        host.send(.run(.run(id: "operation") { send in
            started.fire()
            await release.wait() // Deliberately ignores Task cancellation.
            send(.received(1))
            finished.fire()
        }))

        await started.wait()
        host.stop()
        #expect(host.isStopped)

        release.fire()
        await finished.wait()
        #expect(host.state.values.isEmpty)

        // Subsequent sends are completely dropped after stop
        host.send(.received(99))
        #expect(host.state.values.isEmpty)
    }

    @Test
    func concurrentTasksWithSameIDWithoutCancellation() async {
        let host = FeatureHost<LifetimeFeature>(service: .init())
        let started1 = Signal(), release1 = Signal(), finished1 = Signal()
        let started2 = Signal(), release2 = Signal(), finished2 = Signal()

        host.send(.run(.run(id: "group", cancelInFlight: false) { send in
            started1.fire()
            await release1.wait()
            send(.received(1))
            finished1.fire()
        }))
        await started1.wait()

        host.send(.run(.run(id: "group", cancelInFlight: false) { send in
            started2.fire()
            await release2.wait()
            send(.received(2))
            finished2.fire()
        }))
        await started2.wait()

        release1.fire()
        await finished1.wait()
        #expect(host.state.values == [1])

        release2.fire()
        await finished2.wait()
        #expect(host.state.values == [1, 2])
    }

    @Test
    func concurrentTasksWithSameIDCanceledSimultaneously() async {
        let host = FeatureHost<LifetimeFeature>(service: .init())
        let started1 = Signal(), finished1 = Signal()
        let started2 = Signal(), finished2 = Signal()
        let release = Signal()

        host.send(.run(.run(id: "group", cancelInFlight: false) { send in
            started1.fire()
            await release.wait() // Ignores cancellation
            send(.received(1))
            finished1.fire()
        }))
        host.send(.run(.run(id: "group", cancelInFlight: false) { send in
            started2.fire()
            await release.wait() // Ignores cancellation
            send(.received(2))
            finished2.fire()
        }))

        await started1.wait()
        await started2.wait()

        host.cancel(id: "group")

        release.fire()
        await finished1.wait()
        await finished2.wait()

        #expect(host.state.values.isEmpty)
    }
}
