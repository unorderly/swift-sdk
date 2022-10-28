import XCTest
@testable import ConfigCat

class AutoPollingTests: XCTestCase {
    private let testJsonFormat = #"{ "f": { "fakeKey": { "v": "%@", "p": [], "r": [] } } }"#

    override func setUp() {
        super.setUp()
        MockHTTP.reset()
    }

    func testGet() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testGetFailedRequest() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 500))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testOnConfigChanged() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        var called = false
        let hooks = Hooks()
        hooks.addOnConfigChanged { _ in
            called = true
        }
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: hooks, sdkKey: "", offline: false)

        sleep(1)

        XCTAssertTrue(called)

        sleep(3)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testRequestTimeout() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 3))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        sleep(2)

        XCTAssertEqual(1, MockHTTP.requests.count)

        sleep(2)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)
    }

    func testInitWaitTimeTimeout() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 5))

        let start = Date()
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertTrue(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        XCTAssert(elapsedTimeInSeconds > 1)
        XCTAssert(elapsedTimeInSeconds < 2)
    }

    func testCache() throws {
        let mockCache = InMemoryConfigCache()
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: mockCache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertTrue(mockCache.store.values.first?.contains("test") ?? false)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)

        XCTAssertEqual(1, mockCache.store.count)
        XCTAssertTrue(mockCache.store.values.first?.contains("test2") ?? false)
    }

    func testCacheFails() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test2"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: FailingCache(), pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        sleep(3)

        let expectation2 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test2", settingsResult.settings["fakeKey"]?.value as? String)
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 5)
    }

    func testPollIntervalRespectsCacheExpiration() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let initValue = String(format: testJsonFormat, "test").asEntryString()
        let cache = SingleValueCache(initValue: initValue)
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 2)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        XCTAssertEqual(0, MockHTTP.requests.count)

        sleep(3)

        XCTAssertEqual(1, MockHTTP.requests.count)
    }

    func testOnlineOffline() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        Thread.sleep(forTimeInterval: 1.5)

        service.setOffline()
        XCTAssertTrue(service.isOffline)
        XCTAssertEqual(2, MockHTTP.requests.count)

        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(2, MockHTTP.requests.count)
        service.setOnline()
        XCTAssertFalse(service.isOffline)

        waitFor {
            MockHTTP.requests.count >= 3
        }
    }

    func testInitOffline() {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200))

        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: nil, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: true)

        XCTAssertTrue(service.isOffline)
        Thread.sleep(forTimeInterval: 2)

        XCTAssertEqual(0, MockHTTP.requests.count)

        service.setOnline()

        XCTAssertFalse(service.isOffline)
        waitFor {
            MockHTTP.requests.count >= 2
        }
    }

    func testInitWaitTimeIgnoredWhenCacheIsNotExpired() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 5))

        let initValue = String(format: testJsonFormat, "test").asEntryString()
        let cache = SingleValueCache(initValue: initValue)
        let start = Date()
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertFalse(settingsResult.settings.isEmpty)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        XCTAssert(elapsedTimeInSeconds < 1)
    }

    func testInitWaitTimeReturnCached() throws {
        MockHTTP.enqueueResponse(response: Response(body: String(format: testJsonFormat, "test"), statusCode: 200, delay: 5))

        let initValue = String(format: testJsonFormat, "test").asEntryString(date: Date.distantPast)
        let cache = SingleValueCache(initValue: initValue)
        let start = Date()
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 60, maxInitWaitTimeInSeconds: 1)
        let fetcher = ConfigFetcher(session: MockHTTP.session(), logger: Logger.noLogger, sdkKey: "", mode: mode.identifier, dataGovernance: .global)
        let service = ConfigService(log: Logger.noLogger, fetcher: fetcher, cache: cache, pollingMode: mode, hooks: Hooks(), sdkKey: "", offline: false)

        let expectation1 = expectation(description: "wait for settings")
        service.settings { settingsResult in
            XCTAssertEqual("test", settingsResult.settings["fakeKey"]?.value as? String)
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 5)

        let endTime = Date()
        let elapsedTimeInSeconds = endTime.timeIntervalSince(start)
        XCTAssert(elapsedTimeInSeconds > 1)
        XCTAssert(elapsedTimeInSeconds < 2)
    }
}
