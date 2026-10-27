# API patterns

These examples connect declarations in the [API reference](api/index.html). For a complete first application,
start with [getting started](getting-started.md); for a map of packages, see the [API guide](api-guide.md).

## Bind properties and track changes

Instantiate `UI.Contexts` at library level for your command package and model. A property holds access to model
subprograms; the view creates and owns the binding adapter. This is the todo example's declaration and use:

```ada
package Todo_UI is new UI.Contexts (Todo_VM.Commands, Todo_VM.Model);

Task_Draft : constant Todo_UI.Text_Property :=
  Todo_UI.Editing (Todo_VM.Draft'Access, Todo_VM.Set_Draft'Access);
Task_Rows : constant Todo_UI.Rows_Property := Todo_UI.Listing (Todo_VM.Row_Model'Access);
Task_Choice : constant Todo_UI.Choice_Property :=
  Todo_UI.Choosing (Todo_VM.Selected_Task'Access, Todo_VM.Select_Task'Access);
```

```ada
Parent.Text_Field (Task_Draft, Add_Task, Placeholder => "What needs doing? Press Return");
Parent.List (Task_Rows, Task_Choice, Grow => 1.0);
```

These expressions are components of a layout; see the complete [declarations](../examples/src/todo.ads) and
[screen](../examples/src/todo.adb). The following table identifies common choices; consult the overloads for
other controls and the handle-returning forms.

| Property | Purpose | Typical control |
| --- | --- | --- |
| `Showing` text | Read-only getter | `Label` |
| `Editing` text | Getter and setter | `Text_Field`, which requires writable text |
| `Showing` flag | Read-only boolean | Command-bound `Check` or `Switch`; `Show_When` |
| `Editing` flag | Getter and setter | Settable `Check` |
| `Showing` fraction | Read-only number | `Progress` |
| `Editing` fraction | Getter and setter | Writable fraction controls |
| `Listing` | Borrowed `List_Model` | `List` rows |
| `Choosing` | Getter and setter for a selected ID | `List` selection |
| `Counting` | A count | `Reveal_After`/`Growth` effect |
| `Doing` | Availability and action subprograms | A control accepting an action instead of an enumeration command |

A text or choice property may specify `Changes`; without it, it watches the model's version. Other properties
use the model version. A setter must ensure that the watched version changes when a value changes. For example,
the todo model stores its draft in a `View_Models.Text_Property`. Its setter calls `VM.Set`, which bumps that
property's version only when the text changes, and its `Parts_Version` includes that version. Selection is a
plain field, so `Select_Task` calls `Mark_Changed` when it changes. See the actual
[model body](../examples/src/view_models/todo_vm.adb). If a custom `Changes` getter is supplied, it must advance
for every change relevant to that property; changing only an unrelated model counter will not refresh it.

On a synchronization turn, edits are collected before a command is checked and executed, then changed properties
are refreshed and commands revalidated. A model-driven text replacement clears the field document's undo history;
an unchanged value leaves it alone. Composition is deferred until the input method commits or cancels it. See
[UI guide](ui.md#synchronization) for the ordering, conflict rules and model lifetime.

## Embed a view in an existing tree

A standalone `Mount` supplies the tree's root and validator. To add model-bound controls inside an existing
application-owned tree, the host keeps those responsibilities. The following is adapted from the executable
[`A_View_Can_Live_In_A_Panel_Of_The_Application` test](../examples/tests/src/ui_controls_test.adb):

```ada
--  The application's validator routes the view's tags and handles its own others.
function Validate (Self : Host_Judge; Tag : Integer; Index : Natural) return Widgets.Command_State
is (if UI.Owns_Tag (Self.Screen.all, Tag)
    then UI.Command_State (Self.Screen.all, Tag, Index)
    else Widgets.Enabled);

--  Tree, Model and Root outlive Screen; Root is already attached to Tree.
UI.Use_Tags_From (Screen, 1000);  -- before building any command bindings
--  Install the host validator with Widgets.Set_Validator, then build Part
--  from a context bound to Screen and Model.
UI.Mount_Into (Screen, Root, Part.Layout);

--  On a later host update, after Model changes outside a view event:
UI.Synchronize (Screen);
```

The test shows the validator type, `Bind`, control construction, and teardown. Select a starting tag that does
not overlap the host's tags or another view's tags, and account for the tags the view creates. Route each owned
tag to its view in the validator. The view's bound widgets have their own event handlers; keep the host listener
for its own widgets. Mount into an attached parent with `Mount_Into`, or before an attached sibling with
`Mount_Before`. A later committed component can be mounted the same way; its `Component` guard rolls back its
scope if construction fails. Use `Synchronize` from the host's update path for model changes outside events.

Destroy the view before the tree and borrowed objects. Before destroying it, remove any host validator reference
to it, as the test does. Finalizing the view detaches its controls; the host's root and application-owned widgets
remain. A standalone mount and an embedded mount have different ownership and synchronization rules; see the
`Mount`, `Mount_Into`, `Mount_Before`, and `Synchronize` comments in `Pomarine.UI`.

## Use a widget tree directly

Choose direct widgets when the application needs to own or customize the controls and their event loop. The
application supplies a renderer, tree, root, child widgets, and any listener or validator; these objects must stay
alive while used. Configure the tree, attach the root with `Set_Root`, then `Add` children and set their layouts.
`Layouts.Add` combines attachment and styling. For example, with an attached `Footer`:

```ada
Layouts.Add (Footer, Summary, (Grow => 1.0, Height => 24.0, others => <>));
```

After attaching, lay out before hit-testing or drawing. For each input event, call `Dispatch`; call `Update` with
the current time for timers and model updates. `Paint` performs layout as needed and draws damage, but does not
present a window target. `Needs_Paint` and `Until_Update` help a host avoid unnecessary work. Use
`Retained => True` only when the target retains its previous contents; a swapped window frame does not. See
[`command_tests.adb`](../tests/src/command_tests.adb) for a tree, listener, layout and dispatched events, and
[`capture.adb`](../tutorial/src/capture.adb) for offscreen layout and painting.

A widget may have its own callback or listener, and a tree may have a listener for events. Widget events are
delivered after the input event or update has been given to widgets, allowing handlers to change the tree. A
validator answers whether tagged commands are available; `Revalidate` updates affected widgets when that answer
changes. See `Pomarine.Widgets.Callbacks` and the listener and validator declarations in `Pomarine.Widgets`.

## List selection through changes

`List_Model.Count`, `Describe_Row`, and `Selected` use one-based positions; `Row_Id`, `Chosen_Id`, and
`Choosing` use stable positive identities. Zero means no selection. Suppose positions 1 and 2 have IDs 41 and
73, and ID 73 is selected. Deleting position 1 moves ID 73 to position 1: `Selected` becomes 1, while
`Chosen_Id` remains 73. Deleting ID 73 clears the selection; an item later occupying position 1 must not inherit
it. After a model change, call `Catch_Up` before asking `Chosen_Id` if the list has not yet had an update.

`Select_Row` and `Select_Id` scroll the choice into view and do not emit an event. User selection emits `Choose`
with a row position; a pointer selection also emits `Click`. An action button emits `Act` with row and action
positions without selecting the row. Convert the row to its ID while it still refers to the intended item. See
`Pomarine.Widgets.Lists` for keyboard behavior and the [todo model](../examples/src/view_models/todo_vm.adb)
for ID-based selection.

## Text fields, editors and documents

Use a context `Text_Field` for a model-bound single line; `Editing` provides its getter and setter. For a widget
with a document, multiple lines, rich formatting or a toolbar, use `Widgets.Editors.Editor`; it wraps a
`Text_Areas.Text_Area` and lets the widget tree handle focus, layout, drawing and input. Use `Text_Area` directly
when implementing a custom owner that will place, draw and feed it events itself.

Configure the editor or text area before attaching its `Texts.Documents.Document`. The application owns the
document and renderer and must keep both alive for the editor's use; a text area is drawn to the renderer it was
created for. Multiple areas can show a document: they have their own caret and selection, while undo history is
shared by the document. See `Configure`, `Attach`, `Set_Single_Line`, and `Set_Read_Only` in the respective specs,
and the [gallery](../examples/src/gallery.adb) for editor setup. For bound fields, the synchronization rules for
replacement and input method composition are in [UI guide](ui.md#synchronization).

## Layout sizing

`UI.Row` and `UI.Column` describe a layout for mounting; `Widgets.Layouts` styles already attached widgets (or
attaches and styles with `Layouts.Add`). Both use Yoga's flow. In a row, `Grow` and `Shrink` distribute extra or
insufficient width among siblings; `Align` places children across the row, and `Spread` distributes them along
it. In a column those axes are reversed. `Gap` separates children, `Padding` is inside the container, and `Margin`
is outside a child. A control's width and height can be explicit or use the UI control's fallback size; controls
are not yet sized to their content.

Lengths are points by default and the tree applies display density. `In_Points` and `In_Pixels` make the units
of a computed value explicit. In direct `Set_Layout`, `Unset`, `Unchanged`, and `As_Is` leave the corresponding
setting alone; they do not reset it to zero. The `Row` helper in `UI` defaults to centered cross-axis alignment,
whereas `Column` leaves alignment unspecified. See `Pomarine.UI`, `Pomarine.Widgets.Layouts` and
[UI guide](ui.md#mount-and-failure) for the full parameters and mount checks.
