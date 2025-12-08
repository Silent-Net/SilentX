import XCTest

/// Shared UI test harness to centralize app launch configuration.
final class TestHarness {
    static func launchApp(disableWindowRestoration: Bool = true,
                          environment: [String: String] = [:],
                          arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        if disableWindowRestoration {
            app.launchArguments.append("-NSQuitAlwaysKeepsWindows");
            app.launchArguments.append("0")
        }
        app.launchArguments.append(contentsOf: arguments)
        environment.forEach { key, value in
            app.launchEnvironment[key] = value
        }
        app.launch()
        return app
    }
}
