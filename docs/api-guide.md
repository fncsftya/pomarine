# Finding your way around the API

Pomarine is an alpha Ada GUI library for macOS. Start with [the first app](getting-started.md) for installation,
a complete runnable example, and a model-bound window. The generated [API reference](api/index.html) is a
reference to declarations and their source comments; generate it using the command in the [README](../README.md).
The generated directory is local and is not included in a checkout.

For worked call sequences covering bindings, embedding, direct widgets, lists, text and layout, see
[API patterns](api-patterns.md).

The reference index lists compilation units alphabetically, including dependencies such as `SDL3`, `CoreText`,
`Texts`, `Typeset`, Yoga and SQLite when present in the project graph. Their presence does not mean they are
Pomarine's application-level API. The reference generated from `pomarine.gpr` does not include the separate
`pomarine_testing` crate: use its [specification](../testing/src/pomarine-testing.ads) and
[testing guide](testing.md). Private implementation units are not a substitute for public contracts.

## Choose a starting point

| Task | Start here | Working example or guide |
| --- | --- | --- |
| Open a window with one screen | `Pomarine.UI.Run_Window` | [First app](getting-started.md) |
| Describe a screen and layouts | `Pomarine.UI`, `Pomarine.UI.Contexts` | [UI guide](ui.md), [todo](../examples/src/todo.adb) |
| Define commands and track changes | `Pomarine.View_Models.Command_Models` and `Properties` | [Greeter model](../tutorial/src/view_models/greeter_vm.ads), [todo model](../examples/src/view_models/todo_vm.ads) |
| Bind text, commands, lists and choices | `Pomarine.UI.Contexts` | [Todo bindings](../examples/src/todo.ads) |
| Supply rows to a list | `Pomarine.Models.List_Model`, `Pomarine.Widgets.Lists` | [Todo model](../examples/src/view_models/todo_vm.ads) |
| Use widgets directly | `Pomarine.Widgets` and its child packages | [Gallery](../examples/src/) |
| Test interaction and accessibility | `Pomarine.Testing`, `Pomarine.Semantics` | [Testing guide](testing.md), [tutorial capture](../tutorial/src/capture.adb) |
| Paint or inspect output | `Pomarine.Widgets`, `SDL3.Painters` | [Testing guide](testing.md) |

In the generated reference, select a compilation unit in the left-hand index, then an entity on its page. The
source comments explain behavior and lifetime requirements that signatures alone cannot show. For a larger
workflow, read the guides and examples alongside the reference.

## Build a model-bound screen

Instantiate `Command_Models` for the model's command enumeration and `UI.Contexts` at library level for that
model type. Declare properties using model subprograms, bind a context to the model, compose controls with `Row`
and `Column`, and `Mount` the result. `Run_Window` manages a standalone window and tree; the
[UI guide](ui.md) also describes embedding a view in an existing tree.

A view owns the controls, documents and bindings it creates. The caller owns the model: it must outlive every
use of the view. The tree must outlive the view as well. `Run_Window` arranges the tree and view for its call,
but the caller still initializes and owns the model. A borrowed widget remains the application's responsibility.
Contexts and property subprograms must have the library-level accessibility described in `UI.Contexts`.

`Can_Execute` controls whether a command is available. Call `Execute`, not the `Perform` hook; the latter does
not check the command or mark the model changed. When a setter changes visible state, account for it through
`Mark_Changed` or `Parts_Version`. Bindings refresh from versions, so a model that changes without updating its
version can leave the display stale. The [first-app walkthrough](getting-started.md#define-the-model) explains
assertion policy and the command contract.

## Lists and identity

Implement `Pomarine.Models.List_Model` over your own storage: return a row count, a version that changes when
rows or their contents change, a distinct positive `Row_Id` for each live item, and its `Row_Content`. Row
positions are one-based and can change as items move. An ID must stay with its item while it is alive; do not
reuse an ID for a different live item. `Choosing` reads and writes the ID, with zero meaning no selection.
The rows model and its storage must remain available while the list uses them.

`Text_List` is a fixed-capacity convenience for a bounded set of rows. Use growing application storage for
user-created content. `Row_Content` is a presentation buffer: its text and detail are limited to 160 bytes,
and action names to 24 bytes. The setters truncate at UTF-8 character boundaries; keep the full text in your
model. A row supports up to three actions. See `Pomarine.Models` for the contracts and `Pomarine.Widgets.Lists`
for list behavior.

## Diagnose common problems

- **A control does not update:** check that the getter reads the expected model and that its watched version
  changes when the displayed value changes. See the synchronization and text sections of [UI guide](ui.md).
- **A command stays disabled:** check `Can_Execute` for the command and its index, and ensure the model's
  version changes when availability changes. The initial mount synchronizes controls before use.
- **Mount fails:** call `UI.Check` to obtain a `Mount_Problem`. Common causes include placing a control twice,
  using a stale or foreign layout, and attaching a widget already in a tree. `Mount` raises `Mount_Refused` for
  a refused description; the [UI guide](ui.md#mount-and-failure) lists the cases.
- **A semantic test cannot find a control:** inspect `Testing.Screen`, then check its accessible name, role,
  visibility and, for repeated names, `Nth`. `Testing.Open` requires a tree with a root. See
  [testing guide](testing.md) for setup and golden image tests.
