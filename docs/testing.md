# Testing Pomarine

Run commands from the directories shown. Tests use Ada assertions and contracts. The native crate also needs
`cargo`; its first build may need network access.

## Choose a test

| Change | Test |
| --- | --- |
| View-model rules and contracts | `vm/tests` or an example's `*_vm_test`; no widgets or SDL. |
| Binding, input, focus or accessibility | `examples/tests`, using `Pomarine.Testing` by semantic name. |
| Rendering, layout or theme | `tests/bin/golden`; inspect changed images. |
| Native accessibility or system dialogs | Manual check on macOS with VoiceOver or System Events. |

`Pomarine.Testing.Open` requires a tree with a root. `Click_On`, `Type_Text`, `Press` and `Act_On` exercise the
view; use `Screen` to inspect accessible names and roles. `Act_On` requests an accessibility action, while
`Click_On` sends pointer input. `Feed` sends an event without settling; `Compose` simulates input method
composition. The tree and any attached application must outlive the session.

```ada
Testing.Open (Window, Tree, Width => 640, Height => 480);
Testing.Click_On (Window, "Done");
pragma Assert (Testing.Is_Disabled (Window, "Delete"));
pragma Assert (Testing.Shows (Window, "1 of 2 left"));
```

See [`Pomarine.Testing`](../testing/src/pomarine-testing.ads) and the runnable
[tutorial capture](../tutorial/src/capture.adb).

## View-model and view tests

```sh
cd vm/tests
alr build
bin/vm_tests
```

```sh
cd examples/tests
alr exec -- gprbuild -P todo_tests.gpr
set -e
for t in todo_vm_test todo_view_test example_views_test ui_slice_test ui_ownership_test ui_unchecked_test \
         ui_sync_test ui_reentry_test ui_text_test ui_list_test ui_properties_test ui_controls_test \
         gallery_vm_test gallery_view_test; do bin/$t; done
bin/windows_test  # opens a real window briefly
```

The UI tests cover scope rollback and stale handles, mount failure, synchronization and reentrancy, text
composition, stable list selection, embedded views, controls and borrowing. `todo_vm_test` covers command
contracts, long text and growing task storage; `todo_view_test` exercises its bindings. Gallery tests cover the
model and interactions on the general controls. Add new controls to the gallery and its tests.

To check handle and mount validation with assertions and runtime checks disabled, from `examples/tests`:

```sh
printf 'pragma Assertion_Policy (Ignore);\n' > ignore.adc
alr exec -- gprbuild -f -P todo_tests.gpr --relocate-build-tree=/tmp/unchecked --root-dir=../.. \
  -cargs:Ada -gnatp -gnatec=$PWD/ignore.adc
/tmp/unchecked/examples/tests/bin/ui_unchecked_test
```

## Golden and library tests

```sh
cd tests
alr build
bin/golden                 # all tests
bin/golden gallery         # filter by name
bin/golden ui-todo
bin/golden controls
bin/golden popup
```

`bin/golden` includes non-image assertions as well as software-rendered PNG comparisons. Image mismatches write
`out/<name>-actual.png` and `out/<name>-diff.png`; differing pixels are red. Inspect the actual image and diff
before accepting changes:

```sh
UPDATE_GOLDEN=1 bin/golden gallery
```

Goldens compare every pixel. CoreText rasterization may differ across macOS releases; use a suitable tolerance
in `Goldens.Check` when the test requires it. The software renderer does not show GPU smoothing. Picture tests
use `golden/textarea-typing.png` as input: after changing it, regenerate `pictures` after the other goldens.
Test icons come from `tests/icons`.

Useful filters include `gallery` (light, dark, density and accessible description), `ui-todo`, `textarea`,
`document`, `widgets`, `lists`, `semantics`, `commands`, `overlay`, `popup`, `controls`, `number-field`,
`pictures`, `keyboard` and `surface`. Find the individual test names in [`tests/src`](../tests/src).
`surface` checks SDL input and native file-dialog contracts but does not dismiss system panels.

## Manual platform checks

Run the application and inspect its accessibility tree with System Events or VoiceOver; exercise actions such as
`AXPress`. Native file panels and real window behavior require manual checks. Automated semantic tests exercise
Pomarine's accessibility representation, not the operating system's complete accessibility integration.
