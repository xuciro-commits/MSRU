import Testing
@testable import AppFoundation

@MainActor
private final class Signal {
    private var signaled = false
    private var waiter: CheckedContinuation<Void, Never>?

    func wait() async {
        if signaled { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func fire() {
        signaled = true
        waiter?.resume()
        waiter = nil
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
}
