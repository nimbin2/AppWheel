appwheel
========

A radial "weapon-wheel" application launcher for Linux (Wayland and X11),
in a single C file. Point at a slice to pick an app, type to filter, Enter
to launch.

![AppWheel screenshot](screenshot.png)

This is a vibe-coded project: 100% written by Claude (Anthropic) from a chat.
It builds clean and was tested headless, but not on real hardware — read it
before you trust it.


Requirements
------------

A C compiler, pkg-config, and the SDL3 development files.

Arch:

```sh
sudo pacman -S sdl3
```

Fedora:

```sh
sudo dnf install SDL3-devel
```

Debian / Ubuntu (24.10 or newer):

```sh
sudo apt install libsdl3-dev
```

If your distro has no SDL3 package, build it once from source:

```sh
git clone --depth 1 https://github.com/libsdl-org/SDL
cmake -S SDL -B SDL/build -DCMAKE_BUILD_TYPE=Release
cmake --build SDL/build -j
sudo cmake --install SDL/build && sudo ldconfig
```


Build
-----

  Keep stb_truetype.h and stb_image.h next to appwheel.c, then:

      make

  or by hand:

      cc appwheel.c -o appwheel $(pkg-config --cflags --libs sdl3) -lm


Install
-------

      make install          # copies appwheel to ~/.local/bin

  Then bind a key to `appwheel` in your compositor, e.g.:

      Hyprland   bind = SUPER, A, exec, appwheel
      sway       bindsym $mod+a exec appwheel
      i3         bindsym $mod+a exec appwheel


Usage
-----

  Mouse over the top of the ring     highlight an app
  Bottom-left / bottom-right         page through long lists (further = faster)
  Scroll wheel                       move one at a time
  Type                               filter by name
  Enter or left-click                launch
  Esc                                clear the filter, or quit
  Right-click                        quit

  Apps you launch are remembered and shown first next time.


Configuration
-------------

  Optional — appwheel works with no config. To create one:

      mkdir -p ~/.config/appwheel
      appwheel --dump-config > ~/.config/appwheel/config

  Edit that file (one key=value per line). Every key also works on the
  command line, so you can try things without editing anything:

      appwheel slots=8 ssaa=3 ui_scale=1.3

  The main keys:

      slots=10          apps shown around the top of the ring
      arc=240           degrees of the ring used for apps
      page_ms=110       paging speed (higher = slower)
      icons=1           show .desktop icons (icon_px=46 for size)
      ui_scale=1.0      overall text size
      font=...          a .ttf path or a family name; default is your
                        desktop font. Also label_px/title_px/search_px.
      ssaa=2            edge smoothing, 1..4
      sort=recent       recent (most-used first) or alpha
      include=a,b,c     show only these apps, in this order
      exclude=a,b       hide these
      colors            bg ring ring2 hl text hltext center accent dim
                        (as #rrggbb or #rrggbbaa; bg alpha < ff = transparent)

  Run `appwheel --help` for the full list, and `appwheel --list` to see the
  app ids you use with include/exclude.


Running on another distro
-------------------------

  A binary built on a new distro may fail on an older one with
  "GLIBC_2.xx not found". Build it on the older machine, or use the included
  script to build inside an old Ubuntu container (needs Docker or Podman):

      ./build-portable.sh

  The result runs on that Ubuntu release and anything newer.


License
-------

  GPL-2.0 (see LICENSE). The bundled stb headers are public domain and SDL3
  is under the zlib license; both are compatible.
