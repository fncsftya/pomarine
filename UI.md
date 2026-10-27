# Views: a retained UI owned by a view

`Pomarine.UI` (in `ui/src/pomarine/views/`) is a way to make a screen of widgets, tied to a view-model, that the
application does not have to declare, place, hear or keep in step by hand. A **component** is a function: it
makes controls, each together with what ties it to the model, and returns a **layout**. The screen is those
functions, the layouts they return put together, and one `Mount`. The todo example
(`examples/src/todo.adb`, run by `todo_gui`) is the model of how it reads, and what the spelling below was
settled by.

```ada
function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout is
  (UI.Row ([Parent.Label (Task_Summary, Grow => 1.0),
            Parent.Button ("Done", Toggle_Chosen),
            Parent.Button ("Delete", Remove_Chosen, Look => Danger),
            Parent.Button ("Clear done", Sweep_Done, Width => 100.0)],
           Gap => 8.0));

function Task_Screen (Parent : Todo_UI.Context'Class) return UI.Layout is
  (UI.Column ([Task_Entry (Parent), Task_Content (Parent), Task_Actions (Parent)], Padding => 12.0, Gap => 8.0));

procedure Build (Screen : in out UI.View; Model : not null access Todo_VM.Model) is
   Bound : constant Todo_UI.Context'Class := Todo_UI.Bind (Screen, Model);
   Whole : constant UI.Layout := Task_Screen (Bound);
begin
   UI.Mount (Screen, Whole);
end Build;
```

and the model is bound by properties made of its own subprograms, one line each:

```ada
Task_Draft : constant Todo_UI.Text_Property := Todo_UI.Editing (Todo_VM.Draft'Access, Todo_VM.Set_Draft'Access);
```

and the program is `procedure Show is new Pomarine.UI.Run_Window (Todo_VM.Model, Todo.Build);` and
`Show (Model, "Tasks", 640, 480)`.

Nothing else is needed: no widget is a field of the application, there is no `Sync`, no command-routing callback
and no validator. `Todo_GUI` declares the model and runs `Pomarine.UI.Run_Window`, which makes the window, the tree
and the view in the order they must be.

Where this differs from the first sketch, and why:

* `Bind` returns `Context'Class`, and a component takes `Context'Class`. A component's scope is a `Component`,
  which *is* a `Context` (so `Bound.Label (...)` is the same call in both) and Ada does not let a function that
  returns a tagged type be inherited without being overridden. So there are no primitives that return a
  context but `Bind`, which is class-wide.
* A component makes its controls through the context it is given, so a component is an expression: no guard, no
  handles, no `Commit`. A component that must give up whole when it fails declares a guard (`Bound : aliased ...
  Component (Parent'Access)`) and ends with `return Bound.Finish (Layout)` (or `Commit`, then the return): a
  function cannot do something after its result, and the commit must be the last thing that can go right.
* A control made by a context with a layout result (`Bound.Button ("Done", Cmd, Grow => 1.0)`) is placed in the
  same call, with the `Grow`, `Shrink`, `Width`, `Height`, `Margin` and `Align` of `UI.Place`, and an optional
  `Tooltip` and `Name`: a control has no size fitted to its content yet, so it takes a fallback when the layout
  says nothing (a button is 80 x 32 points, a field 38 high, a label 24 high). Say a size only where the fallback
  is wrong, as for "Clear done" above; sizing by content, for long or translated text, is still to do. The handle-returning forms stay for a control wanted again
  (`Focus_Of`, `Reveal_Of`, `Widget_Of`), then `UI.Place (Handle, ...)`.
* The focus a field has at the start (`Focus_Initially => True`) and the scrolling of a list to a task just added
  (`Reveal_After`, `Growth`) are said of the control, so a component need not hand them up.
* The order the controls of an expression are made in is not defined and does not matter: the tab key goes by
  where they are placed.
* Row's `Align` is `Center` unless said (it was what the old footer said by hand); Column's is not set.

## What is owned, and until when

| Thing | Owner | Lives until |
| --- | --- | --- |
| Widgets the view makes, their documents, binding records, layout descriptions | the `View`, in the arena of the scope that made them | that scope is destroyed |
| Panels of the mounted screen, and the root | the `View`, in its mount arena | the mount fails, or the view goes |
| Widgets the application borrows (`Borrow_*`) | the application | they are not touched but to take them out of the tree |
| The model | **the caller** | it must outlive every use of the view |
| Properties (`Showing`, `Editing`, `Counting`, `Listing`, `Choosing`, `Doing`) | the program (constants of library-level subprograms); the view makes the adapter in the scope's arena | the scope |
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
* `Pomarine.UI.Contexts` is instantiated in a package. Instantiated in a subprogram, it is a compile error
  ("subpool access type has deeper accessibility level than pool"). The subprograms of a property are named with
  `'Access`, which the compiler allows only of library-level ones. So a binding keeps pointers to library-level
  subprograms and nothing nested, and no callback is a closure over locals.
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

A handle is not handed up. A component that must give its caller something the controls cannot say of themselves
returns it in its result, a layout and a `Focus_Target` or `Reveal_Target`, which can be used for those and for
nothing else; the todo example needs none, as `Focus_Initially` and `Reveal_After` are said of the controls.

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

* **Watches.** Each binding has its own `Version` (a property says which: a text's own, as `Changes`, or the model's whole by
  default), so a change of one is not a refresh of the others. A setter given what the model has is no change (the
  view-models' `Set` says so), and a widget given what it shows does nothing.
* **Button captions.** `Bound.Caption_From (Button, Text_Property, Index => ...)` makes an owned or borrowed
  button's label follow a versioned text property, including its accessible name when no explicit name was set.
  It retains the button's command and validates the handle's view and lifetime.
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
  that is no literal, an action made by `Doing` (`Allowed` and `Perform`, which the buttons that do it follow).
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

A list shows the existing model-backed rows (`Pomarine.Models`): a `Listing` property hands the list the model's
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

Each `Borrow_*` also has a placed form, as the owned controls do: it takes `Tooltip`, `Name` and the `Place`
parameters (`Grow`, `Shrink`, `Width`, `Height`, `Margin`, `Align`, `Exact`) and returns the `Layout`, so
`Bound.Borrow_Button (Part, Save, Width => 80.0, Exact => True)` is the whole of it. `Borrow_Widget` with `Click`
(and `Index`) binds a click; `Borrow_Holding (Part, Items, Click => ...)` is a borrowed grip or panel with what it
holds and an optional click (`Hold` and `On_Event` in one). Keep the handle forms for what needs the handle
afterwards (`Selected_When`, `Enabled_When`, `Show_When` on the control, more than one event).

## What building it found

* **Prototype first.** Four mechanics were tried in a small program before the API was spelled: subpool arenas
  that finalize their contents; adapters as library-level generics with `'Access` of a constant (since replaced by `'Access` of the model's own subprograms), and that a nested
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

## More controls (2026-10-26, for moving bonxie over)

* `Check` (a box or a radio) and `Switch` are bound to a `Read_Flag` (what the model says is ticked or on) and to
  the command a click does. Both say `Change`, not `Click`, so the view hears that kind for them and
  runs the command of a `Change` as it does of a `Click`. A flag is compared with the widget at every turn
  (it is cheap), so a click that the model did not take is put back.
* `Progress` is bound to a `Read_Fraction`.
* `Edit_Fraction (Get, Set)` and `Borrow_Slider (Widget, Property)` bind an app-owned slider's value.
  Edits are collected before commands; programmatic refreshes do not call the setter. Fractions are clamped
  to 0.0 .. 1.0 for display. Refresh preserves an active drag; after release it shows the latest model value.
  Slider events synchronize edits without dispatching the borrowed widget's existing command tag.
* `On_Event (Widget_Handle, Kind, Command, Index)` binds a borrowed widget event beside its declaration,
  without changing its tag. `On_Event (UI.Any (Typed_Handle), ...)` also binds events on typed controls,
  such as a field's blur, without borrowing the widget again. `Index_From_Event => True` uses the chosen row for
  `Choose` and `Act`, the selected row for a list's `Click` and `Submit` (ignoring no selection), and the
  event index otherwise. Commands use the usual edit-before-command ordering and `Can_Execute` check.
  The control and event binding must belong to the same construction scope. Duplicate bindings for one
  widget/event pair are rejected; teardown removes the handler before reclaiming its binding record.
* `On_List_Actions (Widget_Handle, [First_Command, Second_Command])` binds a borrowed list's numbered row
  actions. Each command receives the event's row, independent of selection. Unmapped action numbers are ignored;
  the model rejects unavailable rows or commands. Binding twice is refused, and teardown detaches the handler.
* `On_Frame_Event (Frame, Kind, Command)` binds discrete frame actions (title double-click, submit, blur,
  minimize, restore and close). The app-owned frame must outlive the binding. Move and resize remain
  view gestures; they are rejected by this command API. Both event APIs exclusively own their event handler
  while the binding lives; do not replace that handler from application code.
* `On_Editor_Event (Widget_Handle, Tool_Used | Link_Followed | Link_Asked, Command, Index, Index_From_Event)`
  binds what an editor says that no other widget does (the `Editors.Callbacks` hooks) to a command. With
  `Index_From_Event` a used tool's command index says the tool as well as the editor's `Index`: build it with
  `Tool_Index (Index, Tool)`, take it apart with `Editor_Of` and `Tool_Of`. Each hook of an editor is bound once;
  the binding clears the hook when its scope goes. What the command does with the editor (a tool of the text,
  a link opened, link choices offered) is the application's effect, not the model's.
* `On_Canvas_Event (Widget_Handle, Line_Selected | Line_Deleted, Command, Index, Index_From_Event)` does the
  same for a canvas's lines (`Canvases.Callbacks`): with `Index_From_Event`, `Line_Selected`'s command index is the
  tag of the line, 0 for none.

* `Show_When (UI.Any (Handle), Flag)` puts a control in or out of its layout (`Set_Visible`) as a flag says.
* `Borrow_Widget` places a widget of the application's of any kind (`Widget_Handle`): the view lays it out and
  may hide it, the rest is the application's. It is the way a canvas, a picture is put in a declared
  screen before it has a declarative form of its own.
* `Row` and `Column` take an `Appearance` (`Container_Look`: fill, border, shadow, radius); `Scroll (Content,
  Across)` is a scroller around one layout.
* Checks and switches take the focus from the keyboard (they are made focusable).

* `Styled (Layout, Layouts.Style)` gives any placed control or container a raw box style; `Show_When (Layout, Flag)`
  shows or hides a container's panel; `Label (Caption)` is a label of constant text; `Button` can be `Focusable`.
* **Embedded views** (for an application that has one tree, one validator and one listener already):
  `Mount_Into (View, Parent, Layout)` puts the screen in a widget of the application's, which keeps the root,
  validator and listener. The application gives the view tags clear of its own (`Use_Tags_From`), asks it about
  them from its validator (`Owns_Tag`, `Command_State`), and has it `Synchronize` in its own turn. bonxie's
  settings form is one (`View.Build.Settings_Form`, `View.Menus.Validate`, `View.Settings_View.Draw`).

* `Edit_Flag` (a box the person ticks, given to the model by a setter), `Button (Settings, ..., Reflect => False)`
  (a button that does a command but is not turned on and off by it), `Plain_Button` (placed, not heard: the
  application hooks its `Click`), `Spacer` (an empty container, for a rule or a block of colour), `Panel_Of`
  (the panel a container made, to show, hide, scope the focus to), and `Container_Look` rounds corners.
  `Styled` is exact: no default size of a control is added to it.
* `Selected_When (Button, Flag)` binds a button's selected appearance; `Enabled_When (Button, Flag)` binds
  its availability. Both read flags without sending widget state back through a setter. `Borrow_Button`
  accepts `Reflect => False` too: the binding still checks `Can_Execute` before executing, while an embedded
  host may bind availability explicitly when the application's validator does not route that host's tags.
* Several contexts (of different models) may bind one view: bonxie's list dialog binds `Nav_VM` and `Item_List_VM`.
* A model that the world must follow gives a view-model-side `Effects` interface (`Settings_VM.Effects`,
  `Confirm_VM.Effects`, `Nav_VM.Effects`): what must happen around a command that a button of the view
  does is done there, not by the button's handler.

Tests: `ui_controls_test` (with `Options_VM`, `Options_UI`), which includes a view in a panel of the application's.

## Cards, app-owned containers and late mounting

`Context.Grip (Look, Command, Index, Name)` makes a clickable card container. `Grip_Look` controls its
fill, border, shadow, hover colours, corners, hand pointer and keyboard focusability. `Plain_Grip` leaves
click handling to the application. `Hold (Grip, Items)` places the grip and its declared children together;
`Hold` also accepts a borrowed `Widget_Handle`. The container must start without children. Give its outer
box with `Styled`; `Hold` describes the children's flow, gap, padding and alignment.

`UI.Put (Screen, Existing)` places an app-owned widget without a model context.
`UI.Put_In (Screen, Existing, Items)` nests layouts inside an app-owned container, with the same child
layout options as `Hold`. These widgets remain owned by the application. Editors, pictures and canvases
can keep their configuration and gesture handlers while their placement becomes declarative. Calling
`Put` again for the same widget reuses its control identity.

A radio group needs no predicate or constant per option: instantiate `Choosing_Among (Enumeration, Getter)` once per
enumeration and say `Theme_Is.Is_Value (Dark)` where the option is declared (a `Flag_Property` that is true while the
getter returns that value).

Repeated cards pass their row through `Index` on the controls and bindings. `Showing` of a getter with a positive row argument (`Text_Each_Getter`, `Flag_Each_Getter`) reads one row's text or flag; commands receive the control's index too.
For example, `Bound.Label (Titles, Row)` and `Bound.Grip (Look, Open_Card, Row)` refer to the same row.
Such properties map an omitted index (0) to row 1, so pass an explicit positive index for repeated controls.
An index is a position, not a stable item identity: the model must still reject stale identities when rows
can outlive their items. Keyed repeated components remain deferred.

An embedded view can open and commit more components after its first mount. `Mount_Into` appends a layout
to an attached parent; `Mount_Before` inserts it before an attached sibling. This supports sections and
cards created as the model grows. The application continues to own the tree, validator and synchronization.
A bar can also move: remove its widget from the tree, describe it again with `Put_In` and `Put`, then
`Mount_Into` its new attached parent. This reuses its widgets and bindings.

`Context.Focus_When (Target, Raised, Index)` gives focus when a flag turns true; a field's text is selected.
Declare it after the binding that shows the control, so the target is visible before focus is given.
Unlike `Focus_Initially`, it can respond to later model changes, such as entering rename mode.

An application implements `UI.Observer.Turned` and registers it with `UI.Observe` to hear when a
synchronization turn changed the state shown by the widgets. This is where an embedded host can request
another layout. The notification describes widget state, rather than a paint callback. Keep the observer
alive while registered; `Observe (Screen, null)` removes it.

## Frame content, fragments and hosts

`Fragment (Screen, Items)` describes siblings without adding a panel or applying a style to their parent.
It is useful at an existing widget's insertion point: `Mount_Before` keeps their order before that sibling.
Validation covers the entire fragment before attachment. A failed embedded mount removes the fragment's
partial attachments and leaves previously mounted siblings in place; the same description can be retried.
Use `Row` or `Column` when the group needs its own box, appearance or visibility binding.

`Pomarine.UI.Hosts.Host` owns a view whose tree becomes known at build time. `Host.Open (Attached_Widget)`
borrows that widget's tree, and `Host.Screen` returns the view. Declare the host after the widgets and models
it borrows, so finalization detaches bindings and widgets before their owners disappear. The tree must outlive
it. Bonxie's item windows and readers use this pattern. `Widgets.Tree_Of` returns the borrowed tree of an
attached widget; it does not transfer ownership.

`Widgets.Frames` composes its chrome through an embedded view. Content mounts before `Content_End`, title
controls before `Title_End`, and status controls before `Status_End`. Overlays mount into `Surface` or
`Status_Surface`. These insertion points replace the frame's old `Add_*` procedures. The frame still owns
its dragging, resizing, title editing and geometry; its content's view owns the content descriptions.

## Menu row descriptions

`Pomarine.UI.Menus` composes menu content as values, including icons, swatches, ticks and availability:

```ada
Content : constant UI.Menus.Content :=
  [UI.Menus.Row (Menus.Heading, "Actions"),
   UI.Menus.Row (Menus.Check, "Chosen", Checked => True),
   UI.Menus.Row (Menus.Separator),
   UI.Menus.Row (Menus.Action, "Remove", Menus.Danger)];
```

`UI.Menus.Set_Content (Menu, Content)` prepares the rows before replacing the widget's snapshot. A failed
allocation leaves the existing menu unchanged. Dynamic components build a local `Content` vector and append
row descriptions before setting the snapshot once; storage and text grow with the content. Changing or
destroying the description afterward leaves the menu's snapshot intact. Replacing content resets scrolling,
hover and pressed rows. Rows are changed through a complete snapshot; incremental row mutation is removed.
Menu placement and `Choose` event routing remain
the host's responsibility; row descriptions do not yet bind commands or model versions.

## Deferred

Conditional component creation and removal driven by bindings, replacing a screen, keyed repeated components,
and mounting more than one standalone screen into a view. A standalone view takes no more components once mounted (`Open_Scope` raises `Program_Error`);
embedded views accept late components as described above.
Reusable components that know no model at all would be generic over a context instance; a component takes the
bindings it needs, in the instance of the screen.

## Tests

See TESTING.md ("Views"): `ui_slice_test`, `ui_ownership_test`, `ui_unchecked_test`, `ui_sync_test`,
`ui_reentry_test`, `ui_text_test`, `ui_list_test`, `todo_vm_test`, `todo_view_test` in `examples/tests`, and the
`ui-todo-*` goldens in `tests`.
