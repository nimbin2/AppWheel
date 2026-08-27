# appwheel — Makefile
#
#   make            build (SDL3 linked dynamically, via pkg-config)   -> ./appwheel
#   make static     build with SDL3 baked in (no libSDL3.so needed at runtime)
#   make strict     build with -Wall -Wextra (for hacking on it)
#   make run        build and run
#   make install    install to $(PREFIX)/bin           (default: ~/.local)
#   make config     write a default config to ~/.config/appwheel/config
#   make clean
#
# Requires: a C compiler, pkg-config, and SDL3 dev files.
# `make static` additionally needs the SDL3 *static* library (libSDL3.a). Distro
# packages don't always ship it; if it's missing, build SDL from source with
# -DSDL_STATIC=ON (see README) or just use the default dynamic `make`.
#
# Note: even a "static" build still loads your system's Wayland/X11 libraries at
# runtime (that's how SDL finds a display) — it removes the SDL install
# requirement, not every runtime dependency.

CC          ?= cc
PKG_CONFIG  ?= pkg-config
CFLAGS      ?= -O2
PREFIX      ?= $(HOME)/.local
bindir      ?= $(PREFIX)/bin

BUILD       := $(shell md5sum appwheel.c 2>/dev/null | cut -c1-8)
SRC         := appwheel.c
BIN         := appwheel

SDL_CFLAGS  := $(shell $(PKG_CONFIG) --cflags sdl3)
SDL_LIBS    := $(shell $(PKG_CONFIG) --libs sdl3)
SDL_LDPATH  := $(shell $(PKG_CONFIG) --libs-only-L sdl3)
# transitive libs SDL needs when it is linked statically, minus SDL itself:
SDL_STATIC_EXTRA := $(filter-out -lSDL3,$(shell $(PKG_CONFIG) --static --libs sdl3))

.PHONY: all static strict run install config clean

all: $(BIN)

$(BIN): $(SRC) stb_truetype.h stb_image.h sw_theme.h
	$(CC) $(CFLAGS) -DAPPWHEEL_BUILD='"$(BUILD)"' $(SDL_CFLAGS) $(SRC) -o $(BIN) $(SDL_LIBS) -lm
	@./$(BIN) --version

# Link libSDL3.a statically while keeping system libs dynamic.
static: $(SRC) stb_truetype.h stb_image.h sw_theme.h
	$(CC) $(CFLAGS) -DAPPWHEEL_BUILD='"$(BUILD)"' $(SDL_CFLAGS) $(SRC) -o $(BIN) \
	  $(SDL_LDPATH) -Wl,-Bstatic -lSDL3 -Wl,-Bdynamic $(SDL_STATIC_EXTRA) -lm
	@echo "built ./$(BIN) with SDL baked in:"; \
	 ldd $(BIN) | grep -qi SDL3 && echo "  (warning: still links libSDL3.so)" \
	   || echo "  no libSDL3.so dependency."

strict: $(SRC) stb_truetype.h stb_image.h sw_theme.h
	$(CC) -O2 -Wall -Wextra -Wno-misleading-indentation -DAPPWHEEL_BUILD='"$(BUILD)"' \
	  $(SDL_CFLAGS) $(SRC) -o $(BIN) $(SDL_LIBS) -lm

run: all
	./$(BIN)

install: all
	install -Dm755 $(BIN) $(DESTDIR)$(bindir)/$(BIN)
	@echo "installed to $(DESTDIR)$(bindir)/$(BIN)"
	@./$(BIN) --version

config: all
	@mkdir -p $(HOME)/.config/appwheel
	./$(BIN) --dump-config > $(HOME)/.config/appwheel/config
	@echo "wrote $(HOME)/.config/appwheel/config"

clean:
	rm -f $(BIN)
