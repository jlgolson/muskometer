Task 1 mechanical split verification

Base: `308bb9fb5510f9c6300f558c05dbb4f014c4daa4`
Implementation: `0c085d8b3c1936592fd059ea441115f906580787`

The baseline, split-source, and executed XCTest identifier lists contain the same 248 tests. All test method bodies and 756 assertion calls are unchanged. Declaration comparison permits only the six shared helpers losing `private` visibility. The full XCTest run passed 248 tests with zero failures or skips.

Command: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -scheme Muskometer -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath build/task-1-tests -resultBundlePath build/task-1-evidence/test-results.xcresult -quiet`

The retained local result bundle is `build/task-1-evidence/test-results.xcresult`; the full build log is `build/task-1-evidence/xcodebuild-test.log`. The task runner independently read the result bundle with `xcrun xcresulttool get test-results summary`, confirming the counts in `test-summary.json`. `preservation.json` retains declaration and method hashes.
