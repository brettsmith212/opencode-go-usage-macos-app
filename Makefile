# Build/launch driver for GoUsage on macOS.
#
# Every build is piped through `xcode-build-server parse -av` so `.compile`
# stays fresh for sourcekit-lsp.

SCHEME      := GoUsage
PROJECT     := GoUsage.xcodeproj
DESTINATION := platform=macOS,arch=arm64
DD          := build
APP         := $(DD)/Build/Products/Debug/$(SCHEME).app

.PHONY: all gen build run launch kill clean test refresh-lsp lsp-config logs

all: run

gen:
	xcodegen generate

build:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	  -configuration Debug \
	  -destination "$(DESTINATION)" \
	  -derivedDataPath $(DD) \
	  build \
	  | xcode-build-server parse -av

kill:
	@pkill -x $(SCHEME) 2>/dev/null || true

launch: kill
	@sleep 0.3
	@echo "▶ Launching $(APP)"
	@open "$(CURDIR)/$(APP)" || (sleep 0.5 && open "$(CURDIR)/$(APP)")

run: build launch

test:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	  -destination "$(DESTINATION)" \
	  -derivedDataPath $(DD) \
	  test \
	  | xcode-build-server parse -av

lsp-config:
	xcode-build-server config -scheme $(SCHEME) -project $(PROJECT)

refresh-lsp:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
	  -configuration Debug \
	  -destination "$(DESTINATION)" \
	  -derivedDataPath $(DD) \
	  clean build \
	  | xcode-build-server parse -av

logs:
	log stream --level=debug \
	  --predicate 'subsystem == "com.brettsmith.GoUsage" OR process == "$(SCHEME)"'

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean || true
	rm -rf $(DD) .compile .bsp