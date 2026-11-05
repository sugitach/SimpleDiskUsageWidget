# Development workflow

Use test-driven development (TDD) for every fix and behavior change.

1. Before changing production code, add or update a test for the desired behavior. Run it against the current code and confirm it fails for the expected reason.
2. Make the smallest production change that passes the test. Run the targeted test again, then run the full unit and UI suites.
3. Refactor with the tests green. Include the regression test in the same change as the fix.

Test module entry points rather than private helpers. Use the UI tests for behavior a user can observe. The UI tests render the shared widget view in a test window with controlled volume data. Verify WidgetKit integration and macOS desktop placement on a Mac, since macOS owns those surfaces.

Run both suites with `xcodebuild -project DiskUsage.xcodeproj -scheme DiskUsage -destination 'platform=macOS' -parallel-testing-enabled NO test`.
