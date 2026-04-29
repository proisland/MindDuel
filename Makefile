.PHONY: setup generate build test clean

SCHEME       = MindDuel
DESTINATION  = platform=iOS Simulator,name=iPhone 16,OS=latest
CONFIG       = Debug
SIGN_FLAGS   = CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM=""

setup:
	brew install xcodegen
	$(MAKE) generate

generate:
	xcodegen generate

build: generate
	set -o pipefail && xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-configuration $(CONFIG) \
		$(SIGN_FLAGS)

test: generate
	set -o pipefail && xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-configuration $(CONFIG) \
		$(SIGN_FLAGS)

clean:
	rm -rf MindDuel.xcodeproj
	rm -rf DerivedData
