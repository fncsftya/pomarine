# Model-bound views

`Pomarine.UI` builds a retained widget tree from layouts and model bindings. Start with
[getting started](getting-started.md) and the [todo example](../examples/src/todo.adb). See
[API patterns](api-patterns.md) for property types, embedded views, lists, text and layout.

## Build a screen

Instantiate `UI.Contexts` at library level. Declare properties from library-level model subprograms, bind the
model, and mount a layout. Components accept `Context'Class` and return `UI.Layout`.

```ada
package Todo_UI is new UI.Contexts (Todo_VM.Commands, Todo_VM.Model);
Task_Draft : constant Todo_UI.Text_Property :=
  Todo_UI.Editing (Todo_VM.Draft'Access, Todo_VM.Set_Draft'Access);

function Task_Entry (Parent : Todo_UI.Context'Class) return UI.Layout
is (Parent.Text_Field
      (Task_Draft, Add_Task, Placeholder => "What needs doing? Press Return", Focus_Initially => True));

procedure Build (Screen : in out UI.View; Model : not null access Todo_VM.Model) is
   Bound : constant Todo_UI.Context'Class := Todo_UI.Bind (Screen, Model);
   Whole : constant UI.Layout := Task_Screen (Bound);
begin
   UI.Mount (Screen, Whole);
end Build;
```

Use `Pomarine.UI.Run_Window` to create a window, tree and view for one screen. A standalone `Mount` installs the
root and command validator; the tree synchronizes the view during `Update`. One view can bind multiple models.
For an existing tree, use `Mount_Into` or `Mount_Before` and follow the
[embedded view protocol](api-patterns.md#embed-a-view-in-an-existing-tree).

Control constructors can return a placed layout or a handle. Use a handle with `UI.Place`, `Widget_Of`,
`Focus_Of` or `Reveal_Of` when the control is needed later. Dimensions are points; controls have fallback sizes,
not content-based sizing. Tab order follows placement order. `Row` defaults to centered cross-axis alignment;
`Column` leaves alignment unspecified.

## Ownership and scopes

| Object | Lifetime |
| --- | --- |
| Tree | Caller-owned; outlives the view. |
| Model | Caller-owned; outlives every use of the view. Ada cannot enforce this. |
| View-created controls, documents, bindings and layouts | Owned by the view's scope arenas; finalized when the scope or view is destroyed. |
| Borrowed widget | Caller-owned; outlives the view's use. The view detaches it and removes its binding handlers on teardown. |
| Observer | Caller-owned; outlives registration. Call `Observe (Screen, null)` to unregister. |

A `Component` is a scope guard. `Commit` or `Finish` keeps the scope provisionally; failure or finalization
without commit destroys it, including committed child scopes. The scope becomes permanent after a successful
mount. Use a guard when a component must roll back as a unit. See
[`ui_ownership_test`](../examples/tests/src/ui_ownership_test.adb).

Handles and layouts identify their view and scope generation. `Is_Live` checks them; `Widget_Of` raises
`Stale_Handle` or `Foreign_Handle` when invalid, even with assertions disabled. A control may be placed only once.
A layout can be copied while its scope lives.

## Mount and failure

`Place`, `Row`, `Column`, `Hold` and `Fragment` describe layouts. `Mount` checks the complete description,
attaches it and synchronizes it once. Use `Check` to inspect a `Mount_Problem` before mounting.

| Problem | Cause |
| --- | --- |
| `Already_Mounted`, `Tree_Has_Root` | The view or tree already has a standalone screen. |
| `No_Screen` | The layout places nothing. |
| `Foreign_Layout`, `Stale_Layout`, `Stale_Control` | A value belongs to another view or a destroyed scope. |
| `Duplicate_Placement` | A control appears more than once. |
| `Attachment_Conflict` | A control is already attached to a tree. |

A failed mount rolls back its attachments and can be retried. Embedded mounts preserve previously attached
siblings on failure. Replacing a standalone screen and keyed repeated components are not implemented.

## Synchronization

Each turn collects widget edits, checks and executes the command, refreshes changed bindings, then revalidates
commands. Mount performs the first refresh. Nested events are queued until the current turn finishes. A pass may
repeat up to `Synchronization_Passes_Limit` when bindings change each other's inputs.

Text and choice bindings can watch a specific version; otherwise they watch the model version. Setters must
account for changes through `Mark_Changed` or `Parts_Version`. Call `Execute`, not `Perform`. An unchanged text
refresh preserves the caret, selection and undo history. A changed value replaces the field document and resets
undo; `Replacement` controls the caret. Input method composition defers refresh and submission until it ends.
A committed edit is collected first; a cancelled composition allows the pending model value to appear.

`Focus_Initially` focuses at mount. `Focus_When` responds to a flag becoming true; declare it after the binding
that makes the target visible. `Reveal_After` with `Growth` scrolls a list when the named command grows the count.
`Caption_From` binds a button's caption to text. `Show_When`, `Selected_When` and `Enabled_When` bind appearance
and availability. `Observe` reports synchronization turns that changed widget state.

## Borrowing, events and dynamic content

`Borrow_Label`, `Borrow_Button`, `Borrow_Field`, `Borrow_List` and `Borrow_Widget` integrate application-owned
widgets. A borrowed widget must be unattached when mounted. `Put` places an unbound widget; `Put_In` places an
application-owned container with layout children. `Hold` places children inside a grip or borrowed container.
`Fragment` places siblings without a panel; `Styled` sets a raw box style.

`On_Event`, `On_List_Actions`, `On_Frame_Event`, `On_Editor_Event` and `On_Canvas_Event` connect events to model
commands. Their binding owns the relevant event handler until its scope ends. Do not replace that handler while
it is bound. Frame move and resize remain view gestures. For indexed repeated controls, pass a positive row index;
the model must handle identity separately from row position.

Embedded views can commit and mount components after their first mount. `UI.Hosts.Host` can own a view when its
tree is known only at build time. For menu content, build a `UI.Menus.Content` value and replace the snapshot:

```ada
Content : constant UI.Menus.Content :=
  [UI.Menus.Row (Menus.Heading, "Actions"),
   UI.Menus.Row (Menus.Check, "Chosen", Checked => True),
   UI.Menus.Row (Menus.Separator),
   UI.Menus.Row (Menus.Action, "Remove", Menus.Danger)];
UI.Menus.Set_Content (Menu, Content);
```

The menu owns its snapshot after `Set_Content`; the description can be changed or destroyed. Replacing content
resets scrolling, hover and pressed rows. Placement and event routing remain the host's responsibility.
