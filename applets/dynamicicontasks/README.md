# Dynamic Icons-Only Task Manager

This is a Plasma 6.7.4-compatible fork of KDE Plasma's task manager. It keeps
the stock task model and interactions, while adding:

- high-contrast running-task indicators derived from application icons;
- stronger matching edge indicators beside lower-opacity active and hovered backgrounds;
- three configurable indicator styles: Plasma standard, equal per-window segments,
  or a long active-window segment with the other windows represented by squares;
- configurable minimum length for the small inactive-window markers, capped
  automatically when required to keep every marker inside the task button;
- configurable shared opacity for inactive task edges and inactive-window
  markers in both segmented modes;
- optional MPRIS playback progress in the existing edge indicator for
  single-window media players, with a dimmed frozen fill while paused and an
  selectable album-art or app-icon color with automatic fallback;
- configurable audio-indicator visibility: always, hover only, or persist
  while muted and otherwise appear on hover;
- shared, configurable task-desktop-ID to MPRIS-ID aliases used by media
  progress, tooltip controls, context-menu actions, and mouse media actions;
- optional album-art task icons with automatic application-icon fallback and
  an optional shadowed application-icon corner badge, plus a per-application exclusion
  list editable from Media settings or each matched player's context menu;
  configurable inset padding, metadata gap, and square, adjustable-squircle,
  or rounded/circular cover shapes, with optional rotation for circular covers
  while playback is active;
- buffered album-art changes that retain the previous cover while the next one
  loads, then cross-fade between them without flashing the application icon;
- optional wider playing/paused media tasks on horizontal panels, with a
  configurable responsive minimum/maximum width while non-media and
  album-art-excluded tasks remain icon-only; wide tasks prefer their minimum
  width without absorbing spare panel space and use the maximum only as a
  content-growth ceiling, with optional artist/track metadata in stacked,
  inline, or automatic responsive layouts, plus previous/play-next/shuffle/repeat controls
  whose visibility mode and displayed buttons can be configured independently;
  thumbnail-preview transport, shuffle, and repeat buttons have separate
  settings from the panel buttons and sit together in the tooltip;
- a dedicated Media settings tab for playback controls, progress, album art,
  exclusions, and task-to-MPRIS ID mappings;
- a seek bar in media thumbnail tooltips for players that support seeking;
- optional animations for segment emphasis, position, size, shape, and entry;
- the stock group-expander badge is shown only in Plasma-standard mode;
- linked or independently configurable background corner radii;
- fixed-color fallback and configurable appearance.

The upstream code is GPL-2.0-or-later and comes from `plasma-desktop` tag
`v6.7.4`. The plugin uses the separate ID
`org.janzon.plasma.dynamicicontasks`, so it does not replace RPM-owned files.

Build, then install the uniquely named plugin into Plasma's Fedora plugin
directory:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
sudo install -o root -g root -m 0755 \
    build/bin/plasma/applets/org.janzon.plasma.dynamicicontasks.so \
    /usr/lib64/qt6/plugins/plasma/applets/org.janzon.plasma.dynamicicontasks.so
```

Restart `plasma-plasmashell.service` after upgrading the plugin. Plasma does
not discover compiled applet plugins from the ordinary user-local plugin path
on this Fedora installation.

To remove it, first replace the widget in the panel with Plasma's stock
Icons-Only Task Manager, then remove
`/usr/lib64/qt6/plugins/plasma/applets/org.janzon.plasma.dynamicicontasks.so`
and restart Plasma Shell.
