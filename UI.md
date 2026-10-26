# Views: a retained UI owned by a view

`Pomarine.UI` (in `ui/src/pomarine/views/`) is a way to make a screen of widgets, tied to a view-model, that the
application does not have to declare, place, hear or keep in step by hand. A **component** is a function: it
makes controls, each together with what ties it to the model, and returns a **layout**. The screen is those
functions, the layouts they return put together, and one `Mount`. The todo example
(`examples/src/todo.adb`, run by `todo_gui`) is the model of how it reads, and what the spelling below was
settled by.

```ada
function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout is
   Bound   : aliased Todo_UI.Component (Parent'Access);
   Summary : constant UI.Label_Handle := Bound.Label (Text => Task_Summary);
   Done    : constant UI.Layout := Command_Button (Bound, "Done", Toggle_Chosen, Width => 70.0);
   Delete  : constant UI.Layout := Command_Button (Bound, "Delete", Remove_Chosen, Width => 70.0, Look => Danger);
   Clear   : constant UI.Layout := Command_Button (Bound, "Clear done", Sweep_Done, Width => 100.0);
   Result  : constant UI.Layout := UI.Row ([UI.Place (Summary, Grow => 1.0), Done, Delete, Clear], Gap => 8.0);
begin
   Bound.Commit;
   return Result;
end Task_Actions;

function Task_Screen (Bound : Todo_UI.Context'Class) return UI.Layout is
   Entry_Area : constant Entry_Part := Task_Entry (Bound);
   Content    : constant Content_Part := Task_Content (Bound);
   Actions    : constant UI.Layout := Task_Actions (Bound);
begin
   Bound.Focus_Initially (Entry_Area.Focus);
   Bound.Reveal_After (Add_Task, Content.Reveal, Task_Count);
   return UI.Column ([Entry_Area.Layout, Content.Layout, Actions], Padding => 12.0, Gap => 8.0);
end Task_Screen;

procedure Build (Screen : in out UI.View; Model : not null access Todo_VM.Model) is
   Bound : constant Todo_UI.Context'Class := Todo_UI.Bind (Screen, Model);
   Whole : constant UI.Layout := Task_Screen (Bound);
begin
   UI.Mount (Screen, Whole);
end Build;
```

Nothing else is needed: no widget is a field of the application, there is no `Sync`, no command-routing callback
and no validator. `Todo_GUI` declares the window, the tree, the model, and `Screen : Todo.UI.View (Tree'Access)`.

Where this differs from the first sketch, and why:

* `Bind` returns `Context'Class`, and a component takes `Context'Class`. A component's scope is a `Component`,
  which *is* a `Context` (so `Bound.Label (...)` is the same call in both) and Ada does not let a function that
  returns a tagged type be inherited without being overridden. So there are no primitives that return a
  context but `Bind`, which is class-wide.
* A component declares its guard (`Bound : aliased ... Component (Parent'Access)`) and `Commit`s before the
  return. A function cannot do something after its result, and the commit must be the last thing that can go
  right.
* A control is placed with `UI.Place (Handle, Width => ...)`: buttons have no size of their own, so the layout
  says it (a button is 80 x 32 points, a field 38 high, a label 24 high, if it does not).
* Row's `Align` is `Center` unless said (it was what the old footer said by hand); Column's is not set.

## What is owned, and until when

| Thing | Owner | Lives until |
| --- | --- | --- |
| Widgets the view makes, their documents, binding records, layout descriptions | the `View`, in the arena of the scope that made them | that scope is destroyed |
| Panels of the mounted screen, and the root | the `View`, in its mount arena | the mount fails, or the view goes |
| Widgets the application borrows (`Borrow_*`) | the application | they are not touched but to take them out of the tree |
| The model | **the caller** | it must outlive every use of the view |
| Adapters (`Read_Text`, `Edit_Text`, `Counter`, `Row_Source`, `Choice`, `Command_Action`) | the program (library-level objects) | the program |
| The tree | the caller, declared before the view | it outlives the view (an access discriminant) |

**Arenas** (`Pomarine.UI.Arenas`) are subpools of one stateless pool: growing blocks that never move, so every
object has a stable address and no object is freed alone. Destroying an arena finalizes the controlled objects in
it (widgets, documents, and any binding record that holds one) in reverse order of creation and returns the blocks.
An access type that allocates in an arena is pool-specific and declared at library level; Ada refuses any deeper
one, which is what stops anything allocating in an arena that could outlive it.

**The model's lifetime** is the one thing Ada cannot check here. `Bind (View, Model)` takes the model as an access
parameter (`Model'Access`); the binding keeps it as an unchecked pointer, for as long as its scope lives. Declare
the model before the view. Destroying a view does not call the model, so a model that is gone first is harmless
until the view is *used*.

**Accessibility, as far as it goes.** What Ada can check, it does:

* A `View` has an access discriminant, the tree: `Screen : UI.View (Tree'Access)`. A view cannot outlive its tree.
* `Pomarine.UI.Contexts` and every adapter generic are instantiated in packages. Instantiated in a subprogram,
  `Contexts` is a compile error ("subpool access type has deeper accessibility level than pool"), and an
  adapter a warning that `Program_Error` will be raised ("non-local pointer cannot point to local object",
  which is an error in the Alire profiles, where warnings are errors). So a binding keeps a pointer to a
  library-level adapter and nothing nested, and no callback is a closure over locals.
* Handles, layouts and scopes are values that name a view, a slot and a generation, and are looked at before
  storage is (below).

What it cannot: a `Context` with access discriminants for the view and the model (tried in the prototype, and it
did) cannot be made for a nested component, because the discriminant of one object cannot be the value of
another's ("level of ... is statically too deep", "discriminant in constraint must appear alone"). So a `Context`
is limited, holds the view by number and the model by a named access value, and cannot be copied into anything but
a limited object.

## The view and the tree

A `View` is made for a tree, and owns the tree's validator (`Judge`): it answers each command widget's
`Can_Execute`. It is not the tree's listener: every widget it makes, or borrows, has a handler of its own
(`Callbacks`) for the one event it hears (a button's `Click`, a field's `Submit`, a list's `Choose`), so the
application's own widgets, and the tree's listener, are heard as before. `Mount` makes the view's root, a
`Sync_Root`, the tree's root, and the tree has it synchronize each turn (`Update`). A tree has one validator, so a
tree has one view with commands; two views need two trees, or one view with two contexts (below).

**Teardown**, when a view is finalized:

1. it is forgotten by the registry, so every handle, scope and layout it made is stale from now on;
2. the tree's validator is let go;
3. for each scope, newest first, children before parents: its bindings are told to `Detach` and are
   unregistered (and their tags forgotten); the handler, tag and place in the tree of each of its widgets are
   taken away (a borrowed widget stays in existence, its handler gone and out of the tree); its handles are made
   stale;
4. the mounted screen's panels are finalized, the root last;
5. the arenas are destroyed: what the view owns is finalized, and the storage returned.

Nothing is reclaimed that something still points to, and the model is not touched. The same, for one scope, is
what happens when a component fails.

## Scopes, handles and failure

Every control and every binding belongs to a **scope**. The view's root scope owns the screen; a `Component` opens
a scope for one component, a child of the one it was made under. `Commit` makes it stay, but provisionally: it is
released with its parent if the parent fails, whatever the child did, and it is final once `Mount` succeeds.
A component that is not committed when its guard is finalized (an exception in a declaration, in the body, or the
function returning without `Commit`) destroys its scope with everything in it. A guard is a controlled object, so
this covers failures in the declarative part of the component, where most components make their controls.

A **handle** (`Label_Handle`, `Button_Handle`, `Field_Handle`, `List_Handle`) is a view number, a slot and a
generation. It can be copied, returned and lost: the control stays until its scope goes. Using one after that,
with another view, or from a failed component, is refused by a test the program makes itself, *before any storage
is looked at* (`Resolve`, `Check_Handle`), and not by an assertion or a contract: `Widget_Of` raises `Stale_Handle`
or `Foreign_Handle`, `Is_Live` says no, and `Check` says `Stale_Control`, `Foreign_Layout`. `ui_unchecked_test`,
built with assertions ignored and all checks off, shows it (TESTING.md). The places in the tables are used again by
later controls, with another generation, so a stale handle never meets another control.

A handle is not handed up. A component that must give its caller something (the first focus, a row to show) says
so in its result, as `Entry_Part` and `Content_Part` do in the todo example: a layout and a `Focus_Target` or
`Reveal_Target`, which can be used for those and for nothing else.

## Layouts and `Mount`

`Place`, `Row` and `Column` make descriptions, kept in the arena of the scope that is open, and change nothing
else. A `Layout` is a small value to copy; mounting does not consume it, and it can be used again (but a control
cannot be in two places). It is good while its scope is.

`Mount` first checks the whole description (`Check` says what is wrong, without changing anything but marks):

| `Mount_Problem` | |
| --- | --- |
| `Already_Mounted`, `Tree_Has_Root` | the view has a screen, or the tree has a root of its own |
| `No_Screen` | the layout places nothing |
| `Foreign_Layout` | a layout or a control is another view's |
| `Stale_Layout`, `Stale_Control` | its scope is gone |
| `Duplicate_Placement` | a control is placed twice |
| `Attachment_Conflict` | a control is in a tree already (a borrowed widget of the application's) |

then prepares everything that can fail for want of storage (the root and the panels, in a new arena), then
attaches, then synchronizes once and gives the first focus; only then do the scopes stop being provisional.
Anything that fails undoes it: the panels are finalized (the widgets they hold go back to being as before
they were added, and the tree's root is let go) and the validator is let go, and the view is left unmounted,
with its scopes and layouts as they were, so `Mount` may be tried again. (`Inject_Fault` makes a mount fail
after so many attachments, for the tests that look.) Replacing a screen is deferred.

## Keeping in step

See the comment of `Pomarine.UI.Syncing` for the order. In short, a turn of passes: **collect** what the person
did to the widgets and give it to the model by the setters; then, if the turn was begun by a command's event,
**check `Can_Execute` against that model and execute**; then **refresh** each binding whose model version is not
what it showed; then, if anything changed, `Revalidate` the commands for the widgets. The first turn, in `Mount`,
refreshes everything before the screen can be used. Later changes of the model are shown by the tree's `Update`
(the existing UI-thread mechanism) without running a component again.

* **Watches.** Each binding has its own `Version` (an adapter says which: a text's own, or the model's whole by
  default), so a change of one is not a refresh of the others. A setter given what the model has is no change (the
  view-models' `Set` says so), and a widget given what it shows does nothing.
* **Feedback.** What the view shows is never heard back as an edit: the field remembers the document's state and
  the text it last agreed with the model on, and the list the id it last agreed on.
* **Reentrancy.** A turn that is going on is completed first. Events that come while it does (from a model that
  calls back, or a nested `Dispatch`) are kept (`Queued_Events`) and each is a turn of its own, in order, when
  the pass is over. A pass that changes what another reads is run again, at most `Synchronization_Passes_Limit`
  times a turn. A model that raises leaves the view able to go on.
* **Simultaneous edits.** In a turn where the person edited a field and the model changed its text too, the
  person's edit is the model's first (collect goes before refresh); what the model then says is what is shown,
  so a model that normalizes (`Form_VM.Shouting`) is shown as it said it.
* **Commands** are the model's `Command_Models` literals (`Button ("Done", Command => Toggle_Chosen)`), or, for one
  that is no literal, a `Command_Action` adapter (`Allowed` and `Perform`, which the buttons that do it follow).
  They are routed by binding: each widget's tag is the number of its command binding, never used twice
  in a view, and the validator and the event both look the binding up, which knows its model. So two contexts of
  one view, with models of one kind or of two, cannot be mixed up (`ui_sync_test`: two forms and a todo list in
  one view).
* **Widgets decide for themselves** whether they take an input, by the state they were last told: a button not
  yet turned on by the turn after typing takes no click in the turn of the typing. A field's Return, which is
  always taken, sees the edit (`A_Command_Sees_The_Edit_Before_It`).

### Text

A field is bound to a `Text_Property`: a getter, a setter, a version. The widget's own document is the view's.

* A refresh to the text the field already has leaves the caret, the selection, the undo history and an input
  method's composition alone.
* A refresh to another text (another thread, a command, a normalizing model) **replaces the document**: `Load`,
  which forgets the undo history (the history was of that text), and puts the caret by the field's `Replacement`:
  `Caret_At_End` (to begin with), `Caret_At_Start`, or `Caret_Kept` (the same offset, if the text has it).
* While an input method is **composing**, nothing of it is the person's word yet: it is not given to the model,
  and the model's text is not shown over it. The refresh is put off, and made when the composition ends. If the
  composition is committed, it is an edit, and wins over the text put off; if it is cancelled, it is no edit (the
  document's text is what the field last agreed on), and the model's text is shown. Return while composing is the
  input method's, and not a submission (the editor does not say `Submit`); Return after a commit in the same turn
  submits what was committed, as the model says it (`ui_text_test`).

### Lists

A list shows the existing model-backed rows (`Pomarine.Models`): a `Row_Source` adapter hands the list the model's
rows, and nothing is copied. The selection is bound by **id**, not row (`Choice`: `Get` and `Set` of the id that
`Row_Id` says): the list keeps the chosen id, the model keeps the chosen id, and the view says one to the other
when either moves. So the choice stays with its item when others are deleted or the rows are moved, a row that
goes takes its choice with it, and a new row that takes the place of the one that went is not chosen for it
(`ui_list_test`, `todo_vm_test`). Keyed repeated components are deferred.

### Effects of the view

`Focus_Initially (Target)` gives the focus when the screen is mounted. `Reveal_After (Command, Target, Count)`
scrolls a list to its last row when a command of the screen has made the count grow; the model knows nothing of
scrolling, and a row added by something else is not scrolled to.

## Borrowing

`Borrow_Label`, `Borrow_Button`, `Borrow_Field` (with the document it shows) and `Borrow_List` bring widgets the
application owns into a view, to bind and place them like the view's own, for a screen that is moved over a piece
at a time. The view takes over the handler of the one event it hears (`Click`, `Submit`, `Choose`). Destroying
the view takes them out of the tree, leaves them as they were, and does not finalize them (`ui_ownership_test`).
A borrowed widget that is in a tree already is an `Attachment_Conflict`.

## What building it found

* **Prototype first.** Four mechanics were tried in a small program before the API was spelled: subpool arenas
  that finalize their contents; adapters as library-level generics with `'Access` of a constant, and that a nested
  instantiation is refused; limited contexts with access discriminants (above); and a construction guard that
  rolls back when a *declaration* fails. The subpool needs a pool-specific access type (the compiler says "subpool
  cannot be used on general access type"), whose level is the pool's, and `new (Arenas.Make) T` finalizes in reverse
  order when the arena goes.
* **GNAT 16.1** crashes (`gnat_to_gnu_entity`) on `new (Arena_Of (Home, Scope)) T` in a generic instance; the
  handle goes in a constant first (`Where`).
* **A tree is large** (the state of every widget it could hold: about 4 MB), so two trees in one test need a larger
  main stack (`-Wl,-stack_size`), as `pomarine/tests` has.
* **A bug of the tree**, found by the failed-mount test: finalizing the root widget left its children's Yoga nodes
  in Yoga's root, so the next root, after a failed mount, was laid out with ghost children. `Widget.Finalize` of a
  root now deletes them.
* `Lists.Catch_Up`, `Chosen_Id` and `Select_Id` (a choice by id, and a choice that is gone let go of when asked
  rather than at the next `Update`), `Testing.Feed` and `Testing.Compose` (a turn of several events, and an input
  method) were added.

## Deferred

Conditional mounting, replacing a screen, subtrees that change, keyed repeated components, and mounting more than
one screen into a view. A view takes no more components once mounted (`Open_Scope` raises `Program_Error`).
Reusable components that know no model at all would be generic over a context instance; the ones here
(`Entry_Field`, `Command_Button`) take the bindings they need, in the instance of the screen.

## Tests

See TESTING.md ("Views"): `ui_slice_test`, `ui_ownership_test`, `ui_unchecked_test`, `ui_sync_test`,
`ui_reentry_test`, `ui_text_test`, `ui_list_test`, `todo_vm_test`, `todo_view_test` in `examples/tests`, and the
`ui-todo-*` goldens in `tests`.
