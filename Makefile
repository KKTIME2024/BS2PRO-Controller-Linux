.PHONY: all build build-core build-gui dev run clean install uninstall test setup-webkit-compat

APP_NAME    := BS2PRO-Controller
CORE_NAME   := BS2PRO-Core
VERSION     := $(shell grep '"productVersion"' wails.json | sed 's/.*: "\(.*\)".*/\1/')
BUILD_DIR   := build/bin
GO_FLAGS    := -ldflags "-X github.com/TIANLI0/BS2PRO-Controller/internal/version.BuildVersion=$(VERSION)"
GO_FLAGS_CORE := -ldflags "-X github.com/TIANLI0/BS2PRO-Controller/internal/version.BuildVersion=$(VERSION) -s -w"

# Arch Linux: webkit2gtk-4.0 was removed, only 4.1 is available.
# Wails v2.12 requires -4.0, so we provide a compat .pc file.
WEBKIT_COMPAT_DIR := $(HOME)/.local/share/pkgconfig
PKG_CONFIG_PATH   := $(WEBKIT_COMPAT_DIR):$(PKG_CONFIG_PATH)
CGO_LDFLAGS       := -ljavascriptcoregtk-4.1
export PKG_CONFIG_PATH
export CGO_LDFLAGS

all: setup-webkit-compat build

build: setup-webkit-compat build-core build-gui

setup-webkit-compat:
	@mkdir -p $(WEBKIT_COMPAT_DIR)
	@if [ ! -f "$(WEBKIT_COMPAT_DIR)/webkit2gtk-4.0.pc" ]; then \
		echo "Creating webkit2gtk-4.0 compat .pc for Arch Linux..."; \
		printf 'prefix=/usr\nexec_prefix=$${prefix}\nlibdir=/usr/lib\nincludedir=$${prefix}/include\n\nName: WebKitGTK 4.0 (compat via 4.1)\nDescription: Web content engine for GTK (compatibility wrapper)\nVersion: 2.52.0\nRequires: glib-2.0 gtk+-3.0 libsoup-3.0 javascriptcoregtk-4.1\nLibs: -L$${libdir} -lwebkit2gtk-4.1\nCflags: -I$${includedir}/webkitgtk-4.1\n' > $(WEBKIT_COMPAT_DIR)/webkit2gtk-4.0.pc; \
	fi

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
	install -Dm644 build/bs2pro-controller.desktop $(DESTDIR)/usr/local/share/applications/bs2pro-controller.desktop
	install -Dm644 build/99-bs2pro-controller.rules $(DESTDIR)/usr/lib/udev/rules.d/99-bs2pro-controller.rules
	install -Dm644 build/bs2pro-controller.user.service $(DESTDIR)/usr/lib/systemd/user/bs2pro-controller.service
	install -Dm755 scripts/install-systemd.sh $(DESTDIR)/usr/local/share/bs2pro-controller/install-systemd.sh
	install -Dm755 scripts/uninstall-systemd.sh $(DESTDIR)/usr/local/share/bs2pro-controller/uninstall-systemd.sh

install-systemd:
	@echo "Installing systemd user service and udev rules..."
	@if [ -f "$(BUILD_DIR)/$(APP_NAME)" ] && [ -f "$(BUILD_DIR)/$(CORE_NAME)" ]; then \
		install -Dm755 $(BUILD_DIR)/$(APP_NAME) $(HOME)/.local/bin/$(APP_NAME); \
		install -Dm755 $(BUILD_DIR)/$(CORE_NAME) $(HOME)/.local/bin/$(CORE_NAME); \
		./scripts/install-systemd.sh; \
	else \
		echo "Please run 'make build' first to build the binaries."; \
		exit 1; \
	fi

uninstall-systemd:
	@echo "Removing systemd user service..."
	@./scripts/uninstall-systemd.sh

user-install: build
	@echo "Installing for current user..."
	@mkdir -p $(HOME)/.local/bin
	install -Dm755 $(BUILD_DIR)/$(APP_NAME) $(HOME)/.local/bin/$(APP_NAME)
	install -Dm755 $(BUILD_DIR)/$(CORE_NAME) $(HOME)/.local/bin/$(CORE_NAME)
	@mkdir -p $(HOME)/.local/share/icons/hicolor/256x256/apps
	install -Dm644 build/appicon.png $(HOME)/.local/share/icons/hicolor/256x256/apps/bs2pro-controller.png
	@mkdir -p $(HOME)/.local/share/applications
	install -Dm644 build/bs2pro-controller.desktop $(HOME)/.local/share/applications/bs2pro-controller.desktop
	@echo "Installation complete! You can now run:"
	@echo "  ~/.local/bin/BS2PRO-Controller"
	@echo "To enable systemd service, run: make install-systemd"

uninstall:
	rm -f $(DESTDIR)/usr/local/bin/$(APP_NAME)
	rm -f $(DESTDIR)/usr/local/bin/$(CORE_NAME)
	rm -f $(DESTDIR)/usr/local/share/icons/hicolor/256x256/apps/bs2pro-controller.png
	rm -f $(DESTDIR)/usr/local/share/applications/bs2pro-controller.desktop
	rm -f $(DESTDIR)/usr/lib/udev/rules.d/99-bs2pro-controller.rules
	rm -f $(DESTDIR)/usr/lib/systemd/user/bs2pro-controller.service
	rm -rf $(DESTDIR)/usr/local/share/bs2pro-controller

user-uninstall:
	@echo "Uninstalling from user directory..."
	rm -f $(HOME)/.local/bin/$(APP_NAME)
	rm -f $(HOME)/.local/bin/$(CORE_NAME)
	rm -f $(HOME)/.local/share/icons/hicolor/256x256/apps/bs2pro-controller.png
	rm -f $(HOME)/.local/share/applications/bs2pro-controller.desktop
	@echo "User installation removed. System service files may still exist."
	@echo "To remove systemd service, run: make uninstall-systemd"

test:
	go test ./...

tidy:
	go mod tidy
	cd frontend && bun install
