.PHONY: generate build clean test

generate:
	xcodegen generate --spec project.yml

build: generate
	xcodebuild \
	  -project CameraTether.xcodeproj \
	  -scheme CameraTether \
	  -destination 'generic/platform=iOS' \
	  build

test: generate
	xcodebuild \
	  -project CameraTether.xcodeproj \
	  -scheme CameraTetherTests \
	  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
	  test

clean:
	rm -rf CameraTether.xcodeproj DerivedData
