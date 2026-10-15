## Golden image tests

`tests/` draws the library's widgets offscreen, with SDL's software
renderer, and compares each picture with `tests/golden/<name>.png`:
the `Pomarine.Text_Areas` component by itself (`textarea-*`: typing, caret
movement, clicks and drags, selection, the clipboard, undo, input methods,
blinking, scrolling), single-line fields (`field-*`), the widget tree
(`widgets-*`: layout, damage, focus, hiding, removing), what widgets say to a
listener (`listener-*`: clicks, tags and commands, a widget's own listener,
events heard after the event that caused them, checks, grips and fields) and
the layout helpers (`layouts-*`), the widgets as the
design's sheet shows them (`sheet-*`: every kind on one board, pressed,
focused and hovered states, and what each does with clicks and keys), and
selecting words over a picture (`pictures-*`, with made-up `Pomarine.Words`:
dragging, double and triple clicks, copying, zooming and scrolling). Tests
also check text with `Goldens.Check_Text`, and documents and layouts
without drawing (`document-*`, `layout-*`).

Not pictures: `painters-*` (what a recording keeps, and that drawing it again
is drawing it), `semantics-*` (the tree as an assistive technology is told it,
and only what changed, and what its actions do), `commands-*` (a widget's own
handlers, a validator, keys, and where a command goes), `lists-*` (that a list
asks for only the rows that show, how it is chosen from and described, and the
buttons at the ends of its rows),
`layout-*` (a label sized to its text, and what is placed again),
`animation-*`, `keyboard-*` (the focus going round, in a dialog's scope, a click
not taking it from a field, the ring only after a key, and what a widget does
with the keys), and `application-*`, `menus-*`, `settings-*` (work posted from other
threads, what is chosen from the menu bar, and the system's settings).
`semantics-*` and the rest use a sink or a listener that writes down what it is
told, so they do not draw.

The `native/` crate (`pomarine_native`, which the tests use) builds a small Rust
library first: it needs `cargo`, and a network the first time. Checking the
system's own accessibility is by hand: run the application and ask it with
System Events (`entire contents of window 1` of the process, and `perform
action "AXPress"`), or turn on VoiceOver.

The library has no icons of its own: the tests draw plain shapes from
`tests/icons`, given to the widgets by `Test_Icons`. The `pictures-*`
tests read `golden/textarea-typing.png` as their picture: when that
changes, run `UPDATE_GOLDEN=1 bin/golden pictures` again after updating
the rest.

The software renderer gives the same pixels every run, so no pixel may
differ.

```sh
cd tests
alr build
bin/golden                     # every test; exits non-zero on a failure
bin/golden zoom                # the tests whose names contain "zoom"
UPDATE_GOLDEN=1 bin/golden     # rewrite the goldens from what is drawn now
```

A mismatch writes `tests/out/<name>-actual.png` and `<name>-diff.png`
(differing pixels in red over a dimmed golden). Check that a change is
intended before regenerating the goldens.

The software renderer samples geometry without smoothing, so these tests
do not see how the GPU smooths scaled glyphs. CoreText may also rasterize
slightly differently on another macOS release; if so, regenerate the
goldens there or pass a tolerance to `Goldens.Check`.