## Golden image tests

`tests/` draws the library's widgets offscreen, with SDL's software
renderer, and compares each picture with `tests/golden/<name>.png`:
the `Pomarine.Text_Areas` component by itself (`textarea-*`: typing, caret
movement, clicks and drags, selection, the clipboard, undo, input methods,
blinking, scrolling), single-line fields (`field-*`), the widget tree
(`widgets-*`: layout, damage, focus, hiding, removing), the widgets as the
design's sheet shows them (`sheet-*`: every kind on one board, pressed,
focused and hovered states, and what each does with clicks and keys), and
selecting words over a picture (`pictures-*`, with made-up `Pomarine.Words`:
dragging, double and triple clicks, copying, zooming and scrolling). Tests
also check text with `Goldens.Check_Text`, and documents and layouts
without drawing (`document-*`, `layout-*`).

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