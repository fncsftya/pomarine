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
dragging, double and triple clicks, copying, zooming and scrolling; freehand
highlighting on pictures and document pages, erasing, direction changes,
overlap without accumulating tint, dark-paper contrast, keyboard and menu
undo/redo (including pictures without OCR), cancelling a
stroke, branching after undo, and bounded path and undo storage). Tests
also check text with `Goldens.Check_Text`, and documents and layouts
without drawing (`document-*`, `layout-*`).

Not pictures: `setters-*` (that the setters a binding calls change what they are given and do nothing for
what the widget has already: no damage, no layout), `painters-*` (what a recording keeps, and that drawing it again
is drawing it), `semantics-*` (the tree as an assistive technology is told it,
and only what changed, and what its actions do), `commands-*` (a widget's own
handlers, a validator, one that is an object, a widget that only triggers a command, keys, and where a command goes), `lists-*` (that a list
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

## Rich text

`document-rich-text` checks style boundaries, merging, multi-paragraph replacement,
undo/redo, the stored markup and its round trip, the conversion of text with no
`<version>`, and rejection of malformed markup or an unknown version without
changing the document. `textarea-rich-text` checks the room for a toolbar (none
by default; with one, the text is below its band whether focused or not, and
`Content_Height` allows for it), shortcuts, typing with a chosen style, and undo.
`widgets-toolbar` checks the editor's buttons: there as soon as the editor is
given a toolbar, with or without the focus, the layout unmoved, a click formatting
the selection without taking the focus from the text, and gone when taken away.

Only editors that ask for it (`Pomarine.Widgets.Editors.Set_Toolbar`) have a
toolbar: four `Buttons`, in Georgia with each letter showing its format, in a tinted band at the top of the text
area, set apart from the text by a line. The text area (`Set_Toolbar`) leaves the
top 32 points for them, above its padding, and its scroll bar starts below.
Single-line fields and read-only views have none. Shortcuts are Command-B,
Command-I, Command-U, and Command-Shift-S. Clipboard text is plain.

`Texts.Documents.Whole` remains plain UTF-8 for search, grammar checking, and
word counts. `Stored` writes version 1 as markup: `<version>1</version>`, then a
`<p>` for each paragraph, in which `<b>`, `<i>`, `<u>` and `<s>` mark bold, italic,
underlined and struck-through runs, and `&`, `<`, `>` are `&amp;`, `&lt;`, `&gt;`.
A run is cut at paragraph boundaries when stored, and a run to the end of one
paragraph and another from the start of the next are joined when loaded.
`Load_Stored` takes text with no `<version>` as plain, a paragraph to each line
(`Upgraded` makes its markup), and rejects an unknown version or markup that is not
well formed. Loading resets history; formatting edits participate in document
state, change tracking, and undo just like text edits.

## View-models

`vm/tests` (`bin/vm_tests`, no SDL) checks the parts of `Pomarine.View_Models`: that counting changes goes round
and does not overflow, that setting a property to what it has is not a change, that a `Watch` sees a version once,
that text has no length it stops at, and that a command's precondition refuses what cannot be done. `Pomarine.Testing`
(`testing/`) is what an application's tests of its views use; the example in `evo/mvvm/example` (`bin/view_test`)
clicks by name and types into the field, and `bin/vm_test` is its view-model alone.

The todo example uses `examples/src/view_models/todo_vm.ads` for draft text, selection,
summary and command rules. Its tests cover command contracts, unchanged versions,
long text, growing task storage and stable row identities; the offscreen test
checks adding, toggling, clearing and deleting by semantic name. Run:

```sh
cd examples/tests
alr build
bin/todo_vm_test
bin/todo_view_test
```

## Views

`Pomarine.UI` (`UI.md`) is tested in `examples/tests`, with `Form_VM` (a model with a text that can normalize, be
changed from elsewhere, and keeps a journal of what was done to it and in what order) and the todo example. Each is
a program with assertions; none opens a window.

```sh
cd examples/tests
alr exec -- gprbuild -P todo_tests.gpr
for t in todo_vm_test todo_view_test example_views_test ui_slice_test ui_ownership_test ui_unchecked_test \
         ui_sync_test ui_reentry_test ui_text_test ui_list_test ui_controls_test; do bin/$t; done
```

* `todo_vm_test`: the todo model alone: command contracts, unchanged versions, long text, growing task storage, and
  a choice that is of a task and not of a row (rows moved, others deleted, the chosen one deleted, a newcomer in its place).
* `example_views_test`: Hello's initial greeting, command contract, click and keyboard bindings, and a model
  change reflected by the next turn; Clock's borrowed face, padding and growth at two sizes and densities,
  accessible time, and teardown that detaches the face without destroying it.
* `ui_slice_test`: a field and commands through a view, as the first slice that was built.
* `ui_ownership_test`: the arenas (`Live_Arenas`, `Live_Views`) are back where they were when views go; borrowed
  widgets are taken out of the tree, untagged, and not finalized, before the application's own objects are;
  a handle outlives its scope, its place is used again and it stays stale; handles and layouts of another view;
  a context outlives its view; a control placed twice, in another tree, a tree with a root, no screen; a mount
  that fails before each of five attachments leaves the tree, the controls, the scopes and the arenas as they were and
  mounts when tried again (this is what found the tree's stale Yoga children); a declaration that fails, a
  component not committed, a child that fails after another succeeded, a parent that fails after its children
  succeeded, a parent that forgives a child.
* `ui_unchecked_test`: stale and foreign handles, a layout of another view, a control twice, and a mount refused, with
  its own `Expect`, not an assertion. Built with assertions ignored and every check off across the whole tree of
  crates, it is still refused:

  ```sh
  printf 'pragma Assertion_Policy (Ignore);\n' > ignore.adc
  alr exec -- gprbuild -f -P todo_tests.gpr --relocate-build-tree=/tmp/unchecked --root-dir=../.. \
        -cargs:Ada -gnatp -gnatec=$PWD/ignore.adc
  /tmp/unchecked/examples/tests/bin/ui_unchecked_test
  ```
* `ui_sync_test`: the first turn is done when `Mount` returns (text shown, commands on or off) and no component is run again
  when a model changes; Return typed in the turn of the typing saves what was typed, in the order `set(..) save(..)`;
  each binding watches its own version (`Name_Reads`, `Status_Reads`: no read when nothing changed, the status not read
  for a change of the name); a model's change from elsewhere is not heard back as an edit; two forms and a todo list, three
  models of two kinds, in one view, with no command of one done by a button of another; a command that is no literal
  of the model's enumeration (`Command_Action`).
* `ui_controls_test`: radios and a switch follow the model, a click the model cannot take is put back, what is
  shown only while a job runs (`Show_When`) comes and goes, a progress bar follows the model, a styled
  column, a scroller and a borrowed widget of any kind are placed, and the handles go stale with the view.
  It also checks late mounting before an existing sibling and teardown of the added components;
  repeated clickable grips with indexed text, flags and commands (including a previously hidden card);
  observer notification after a command changes what is shown; and an app-owned bar and its children
  removed and mounted into another parent through `Put_In` and `Put`.
  Fragments place sibling controls without a wrapper. Faults before each attachment of a nested held
  container leave the original parent unchanged; retry succeeds. A failed late mount leaves earlier
  siblings attached and can also be retried. The fixture uses a `UI.Hosts.Host` to own its embedded view.
  Borrowed command buttons bind selected appearance and availability through `Selected_When` and
  `Enabled_When`, including a click that disables its own button and an external model change that restores it.
  Editable borrowed sliders collect mouse and keyboard edits, preserve an active drag during an external
  update, refresh without setter feedback, and ignore colliding command tags. Borrowed menu events route
  the chosen row independently of the widget tag/index; duplicate event bindings are rejected. Reattaching
  borrowed controls after view teardown does not call their former bindings.
  Menu row snapshots retain their content after the description is cleared, keep checked and disabled
  states, grow to 2,048 rows with 700-character labels, and accept an empty replacement. Replacing content
  during a press cancels that press: releasing it does not choose a row from the replacement.

* `ui_reentry_test`: an event that comes while the view is in the middle of a pass is kept and run as a turn
  of its own when the pass is done (`Queued_Events`), and not inside it; a model that raises leaves the view able to
  go on; the person and the model changing a text in one turn.
* `ui_text_test`: a refresh to the same text keeps the caret, the selection, the document's state and its undo (and
  undo's result is heard); another text replaces the document, forgets the history and puts the caret at the end, the
  start, or where it was; a model that normalizes is shown as it said; an input method's composition is not given to
  the model, is not disturbed by the model's change, and puts it off until it ends (cancelled: the model's text; committed:
  the person's); Return during composition is not a submission, Return after a commit in the same turn submits it.
* `ui_list_test`: a choice follows its item when rows are moved or others deleted, goes with it when it is deleted
  and is not given to the task that takes its row; the first focus is the entry (type with no click); a task added by
  Return is shown even far down the list, and one added by something else is not scrolled to; the names.

The drawing of the todo screen is golden: `ui-todo-opens`, `ui-todo-used` (a choice, text in the entry) and
`ui-todo-wide`, in `tests`, beside the others (`cd tests; bin/golden ui-todo`). They are drawn from `Todo.Build`
with the layout of the screen in them: change a layout and these change.

