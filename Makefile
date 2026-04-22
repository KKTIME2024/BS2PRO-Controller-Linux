.PHONY: all build build-core build-gui dev run clean install uninstall test

APP_NAME    := BS2PRO-Controller
CORE_NAME   := BS2PRO-Core
VERSION     := $(shell grep '"productVersion"' wails.json | sed 's/.*: "\(.*\)".*/\1/')
BUILD_DIR   := build/bin
GO_FLAGS    := -ldflags "-X github.com/TIANLI0/BS2PRO-Controller/internal/version.BuildVersion=$(VERSION)"
GO_FLAGS_CORE := -ldflags "-X github.com/TIANLI0/BS2PRO-Controller/internal/version.BuildVersion=$(VERSION) -s -w"

all: build

build: build-core build-gui

build-core:
	@echo "Building $(CORE_NAME) v$(VERSION)..."
	go build $(GO_FLAGS_CORE) -o $(BUILD_DIR)/$(CORE_NAME) ./cmd/core/

build-gui:
	@echo "Building $(APP_NAME) v$(VERSION)..."
	wails build -platform linux/amd64 -o $(APP_NAME)
	@mkdir -p $(BUILD_DIR)
	@mv build/bin/$(APP_NAME) $(BUILD_DIR)/$(APP_NAME) 2>/dev/null || true

dev:
	wails dev

run: build
	./$(BUILD_DIR)/$(APP_NAME)

clean:
	rm -rf $(BUILD_DIR)
	rm -f frontend/dist/index.html

install: build
	install -Dm755 $(BUILD_DIR)/$(APP_NAME) $(DESTDIR)/usr/local/bin/$(APP_NAME)
	install -Dm755 $(BUILD_DIR)/$(CORE_NAME) $(DESTDIR)/usr/local/bin/$(CORE_NAME)
	install -Dm644 build/appicon.png $(DESTDIR)/usr/local/share/icons/hicolor/256x256/apps/bs2pro-controller.png

uninstall:
	rm -f $(DESTDIR)/usr/local/bin/$(APP_NAME)
	rm -f $(DESTDIR)/usr/local/bin/$(CORE_NAME)
	rm -f $(DESTDIR)/usr/local/share/icons/hicolor/256x256/apps/bs2pro-controller.png

test:
	go test ./...

tidy:
	go mod tidy
	cd frontend && bun install
