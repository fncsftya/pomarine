# Pomarine

**Status: alpha.** The API will still change, with breaks, as it becomes a general library: it began as the
toolkit of [Bonxie](https://github.com/fncsftya/bonxie), which keeps it as a submodule and is still its main
user. `examples/` is the place to start, and the gallery (below) is what the library's own tests keep honest.

Known gaps, for now: macOS only; no tab, radio-group, dialog, popover or context-menu widgets (a menu or a
select is shown by the application); no tree, table, splitter, number or date field; one window to a tree;
no key-up events, drag and drop, or right-to-left text.

A MacOS-only GUI library for Ada: a tree of widgets, laid out by Yoga's
flexbox, drawn with SDL3, with text from CoreText. It is built to be fast
(only what changed is drawn, nothing is allocated while it runs) and to be
read: an application says what its screens are, and what its buttons are for.

## A window, in brief

```ada
type Command is (Save, Quit);
package Commands is new Pomarine.Widgets.Commands (Command);

--  What the widgets say comes here, after the event that caused it.
type App is limited new Widgets.Listener with record ... end record;

overriding procedure Handle_Event
  (Self : in out App; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
begin
   case Commands.What (Event) is
      when Save => ...
      when Quit => ...
   end case;
end Handle_Event;

--  Building: the widgets are the application's own, in a tree that links them.
Widgets.Set_Density (Tree, Pixels_Per_Point);
Widgets.Set_Listener (Tree, Me'Access);
Widgets.Set_Root (Tree, Root);
Layouts.Set_Layout (Root, Flow => Column);        --  in points; the tree knows the density
                                                  --  (Unit => Device_Pixels for pixels)
Layouts.Add (Root, Bar, (Flow => Row, Height => 32.0, Padding => (others => 4.0), Gap => 4.0, others => <>));
Layouts.Add (Root, Page, (Grow => 1.0, others => <>));    --  added, in order, and styled

--  A button is added, looks as said and sits as said, in one line:
Buttons.Add (Bar, Save_Button, Buttons.Looks ("Save", Buttons.Primary), (Width => 70.0, others => <>));
Buttons.Add (Bar, Quit_Button, Buttons.Looks ("Quit"));
Commands.Bind (Save_Button, Save);

--  Running:
Widgets.Dispatch (Tree, Event, Handled);          --  for each event; listeners hear it after
Widgets.Update (Tree, Ticks);                     --  timers, and models that changed
if Widgets.Needs_Paint (Tree) then
   Widgets.Paint (Tree, Target, Themes.Light, Retained => ...);
   Renderers.Present (Target);
end if;
```

See the comment at the top of `Pomarine.Widgets` for the whole loop, and
`examples/` for complete programs (`cd examples && alr build`). `hello_gui` declares its greeting and command
button through `Pomarine.UI`, with `Greeter_VM` holding the count and command rule. `todo_gui` composes a task
screen from bound components. `gallery_gui` puts every kind of widget on one window, which the golden and view
tests (`gallery-*`, `gallery_view_test`) draw, click and describe, so a change to any widget, the layout or the
theme shows up there first. `clock_gui` mounts an app-owned custom clock face with `UI.Put`; its painting and
periodic time updates stay in the widget. Each program declares the tree and model or borrowed face before the
view, so they outlive its bindings. `Pomarine.Windows` opens the window and runs the loop.

## What is where

| | |
| --- | --- |
| `Pomarine.Widgets` | The tree, the events, damage and drawing; the base of every widget. |
| `Pomarine.Widgets.Layouts` | `Set_Layout`: a box's style, in points, one call. |
| `Pomarine.Widgets.Commands` | The application's own enumeration, for what widgets are for. |
| `Pomarine.Widgets.Callbacks` | A procedure of the application's own for what one widget says. |
| `Pomarine.View_Models` (`vm/`, crate `pomarine_vm`) | The parts of a view-model, with no widget in them: a `Version` for change, properties, and the commands a screen can be asked (`Command_Models`). |
| `Pomarine.Widgets.Bindings` | Synchronization machinery used by `Pomarine.UI`: the root update hook and text edit tracking. |
| `Pomarine.UI` (`ui/src/pomarine/views/`) | A screen as functions and layouts: a `View` that owns its widgets, bindings and documents in arenas, `Contexts` that make controls together with their view-model bindings, `Row`/`Column`/`Place`, and `Mount`. See `UI.md`. |
| `Pomarine.Testing` (`testing/`, crate `pomarine_testing`) | A window to test offscreen as a person uses it: seen as an assistive technology is told, clicked and typed in by name; `Hearers` keep what widgets said. |
| `Pomarine.Widgets.Lists`, `Pomarine.Models` | A list of rows read from a model: a screenful asked for, drawn and described. |
| `Pomarine.Semantics` | What a widget is to someone who cannot see it: role, name, value, actions. |
| `Pomarine.Accessibility` (`native/`) | The adapter that tells the system's accessibility (AccessKit, VoiceOver). |
| `Pomarine.Native_Menus` (`native/`) | The menu bar, and the keys that choose from it. |
| `Pomarine.System_Settings` (`native/`) | Less motion, more contrast: what the person asked of every application. |
| `Pomarine.Application` | Work from other threads, run by the window's. |
| `Pomarine.Windows` | A window for a tree, and the loop that runs it: an application need not touch SDL. |
| `Pomarine.Events` | The events (keys, mouse, text) widgets are given, and the clock; the only form of SDL's events an application sees. |
| `SDL3.Painters` | What widgets draw with: a renderer's painter, and a recorder that keeps and replays. |
| `Pomarine.Widgets.*` | Buttons, labels, panels, grips, checks, switches, sliders, fields, menus, scrollers, frames and the rest. |
| `Pomarine.Themes` | Colours: a palette made into a theme; the application's own slots. |
| `Pomarine.Icons` | Icons from SVG files in the application's own folder. |
| `Pomarine.Text_Areas` | The text of an editor: layout, selection, undo, input methods. |

## Hearing the widgets

A widget says what happened (a click, a change, Return, a menu row, a drag) to
a `Pomarine.Widgets.Listener`: the tree's, or its own. Events are kept while
the event or the time that caused them is given to the widgets, and are heard
after, so a handler may show, hide, add or remove widgets, the one it came
from too. Give a widget a command with `Commands.Bind (Widget, What, Index)`
and take it back with `Commands.What (Event)`; `Event.Index` says which of
many it was.

There is one way to hear a widget: a handler, below, or the listener when it
has none. A widget does not keep what it said to be asked for later.

### What a widget is, and what it is now

`Buttons.Looks (...)` says what a button is (label, kind, icon, caption,
shape, focusable) and `Configure` or `Add` gives it all of it: what is not
named goes back to what a new button has. What it is at the moment
(`Set_Selected`, `Set_Enabled`, `Set_Badge`) is set on its own. A button's
`Shape` (`Plain`, `Dropdown`, `Split_Dropdown`) is one choice, so a split
button without a caret cannot be asked for. `Layouts.Style` is the same
for the box: `Set_Layout (Item, Style)` and `Layouts.Add (Parent, Child, Style)`
take it as a value, and the call with named parameters is the same thing.

### Handlers of a widget's own

A widget can have a procedure of the application's own for each kind of event
it says, called with an object of the application's (one for each kind):

```ada
package Mixer_Callbacks is new Pomarine.Widgets.Callbacks (Mixer);
Mixer_Callbacks.On (Volume, Change, Mixer'Access, Louder'Access);
```

When the handler needs nothing but the widget (and its `Tag` and `Index`, which
the event has), a library-level procedure does, with no package to make:

```ada
Widgets.On_Click (Quit, Quit_Clicked'Access);
Widgets.Set_Handler (Volume, Widgets.Change, Volume_Changed'Access);
Widgets.Clear_Handler (Volume, Widgets.Change);
```

A widget that has a handler for a kind of event does not say it to the listener
as well. An event carries only what its kind has to say: a `Row` of a `Choose`,
an `Across` and a `Down` of a `Drag`, a `Row` and an `Action` of an `Act`.
Besides the clicks and changes, a handler can have `Press` and `Release` (a pin
or a grip: the end of a drag, said before its click), `Submit` (Return in a
field) and `Blur` (the widget lost the focus, said only to a handler of its own).
A frame says what its parts do with `Frames.Handlers`, and a `Blur` is of its
title's field.

What only one kind of widget says is not in `Event_Kind`, which would grow with
every new widget, but is heard with a `Callbacks` of that widget's package, whose
handlers are given what the event says as parameters:

```ada
package Board_Callbacks is new Pomarine.Widgets.Canvases.Callbacks (Board);
Board_Callbacks.On_Select (View, Board'Access, Line_Selected'Access);  --  Tag
Board_Callbacks.On_Delete (View, Board'Access, Line_Deleted'Access);

package Page_Callbacks is new Pomarine.Widgets.Editors.Callbacks (Page);
Page_Callbacks.On_Tool (Text, Page'Access, Tool_Used'Access);          --  its number
Page_Callbacks.On_Follow (Text, Page'Access, Link_Followed'Access);
Page_Callbacks.On_Ask_Link (Text, Page'Access, Link_Asked'Access);
```

A new kind of widget does the same with `Posted_Hook` and `Post`: it keeps the
handler the application gave it, and says what it has to through the same queue
as the other events, so it is heard after the event that caused it too.

### Commands, keys and menus

A command is what the application can be asked to do, by a button, a key, a
menu or an assistive technology, and it is the same thing whichever asks. Give
the tree a validator (`Set_Validator`: a function, or an object that implements
`Widgets.Validator`, as a view-model does) and every widget that has a command is
told what it is for now: offered, possible, in force. A widget has two roles in a
command: it triggers it (`Set_Tag`, `Commands.Bind`) and it reflects it (the validator
turns it off, ticks or hides it). `Commands.Trigger`, or `Set_Tag (..., Reflects => False)`,
is for one that only triggers, as a field that says Submit and must stay typeable while
there is nothing to submit. `Revalidate (Widget)` asks again from a handler that holds
no pointer to the tree. The validator is asked with the widget's `Index` too (`Validate (Tag, Index)`, and the
model's `Can_Execute (What, Index)`), so that the buttons of a row can be on while another's are off. The setters that bindings call (`Set_Text`, `Set_Enabled`,
`Set_Checked`, `Set_On`, `Set_Value`, `Select_Row`, `Set_Visible`) do nothing, and ask for no
drawing, when given what the widget already has (tests `setters-*`). Bind keys with
`Bind_Key`; the command goes to the widget with the focus and the widgets it is
in (`Handle_Command`, as the edit commands do to a field), and last to the
listener. With `Pomarine.Native_Menus` the same commands are in the system's
menu bar, and the validator dims and ticks its items.

## View-models

For a form or a list, keep what the screen means apart from how it looks (Model-View-ViewModel). The
view-model (`Pomarine.View_Models`, a crate of the standard library only) has properties, commands that say
when they can be done (`Can_Execute`) and what they do (`Execute (What, Index)`, `Index` being which of many),
and a `Version` that goes up when anything it shows changes. With `Pomarine.UI`, controls are declared with
bindings in component functions, the hierarchy is a layout expression, and the view owns the widgets and keeps
them in step with the model (edits, command, refresh). Commands check `Can_Execute` before running. A view-model
is tested alone, and its view with `Pomarine.Testing`, which clicks by what a widget is called. Continuous canvas
and editor gestures stay in the view. See `UI.md` and the todo example.

## Nodes

The tree keeps its widgets in a table of nodes, which hot passes (hit-testing,
layout, painting) read a field at a time, so it is cheap to walk. A node is
named by a `Node_Id`: a place and which use of the place it is, so that the id
of a widget that was taken out is never the id of another. It is a number to
keep and send (`To_Unsigned_64`). Each node has three dirty marks, for its
layout, its looks and what it is to an assistive technology; each pass clears
its own. Setting something to what it was damages nothing.

## Painting

Widgets draw with a `SDL3.Painters.Painter`: a few primitives (boxes, lines,
discs, clips, text and images). A `Renderer_Painter` draws at once; a `Recorder`
keeps the commands to replay into any painter, as a test does to see what was
drawn without its pixels.

## Lists and models

A `Pomarine.Widgets.Lists.List` reads its rows from a model
(`Pomarine.Models.List_Model`: how many, a number for each row that lasts, what
each shows). Only the rows that show are asked for, drawn and described to an
assistive technology (each as a list item that says which it is of how many),
so a hundred thousand rows cost what a screenful does. A row can have up to
three buttons at its end (`Row_Content.Set_Action`: an icon and a name), and be
`Dimmed`: a click on a button says `Act` with the `Row` and the `Action`
and does not choose the row; Space does a chosen row's first, and Delete its
first that cannot be undone. Each is a button of its own to an assistive
technology (`Lists.Button_Part`). A click on the row says `Click` as well as
`Choose`, so that what a click does is not done for each arrow key.

## Accessibility

Every widget describes itself (`Describe`: a role, a name, a value, its state
and the actions it takes) and does what an assistive technology asks
(`Perform`) as it would do the click or the key. Widgets that have things in
them that are not widgets (the rows of a menu, the paragraphs of a text) say so
as parts. `Describe_Changes` tells a `Semantic_Sink` only what changed since
last time; with `Pomarine.Accessibility`, in the `native/` crate, that sink is
AccessKit, and nothing is done until VoiceOver (or another) asks. The window's
own widgets are named and hidden by the application where its own idea of them
will not do (`Set_Accessible_Name`, `Hide_From_Accessibility`). Checks,
switches, sliders, buttons and grips can be made Tab stops and be worked from
the keyboard (`Set_Focusable`), and `Set_Tab_Navigation` has Tab go round them
in the order of the tree. A click on a button, a check or a switch does not
take the focus from a field being typed in (`Focus_On_Click`). A dialog over the
rest has Tab go round only itself with `Set_Focus_Scope`, until
`Clear_Focus_Scope`. A focus ring is drawn only after a key
(`Is_Focus_Visible`), not for the focus a click gives.

## Layout

Layout is Yoga's, and only what it changed is placed again. A label can be
sized to its text (`Labels.Set_Intrinsic`), measured when its text, style or the
density changes and not otherwise.

## Animation

`Widgets.Animate` runs a number from one value to another over a little time
for a widget to show, run by `Update`, with `Until_Update` saying when the next
frame is wanted. With `Set_Reduced_Motion` (from
`Pomarine.System_Settings.Reduce_Motion`) the widget is given where it was
going at once.

## Other threads and the system

Work from another thread is `Pomarine.Application.Post`ed and run by the
window's thread between its events (`Run_Posted`); posting wakes the loop. (A
task that finishes something posts, if only to wake the loop to look: see
`Vision.Jobs` in bonxie.) The
`native/` crate reaches what the system gives only to Rust and Objective-C
(AccessKit, the menu bar, settings) through a small Rust static library built by
`cargo` the first time; it needs `cargo`.

## Themes

A theme is a colour for each `Slot`. Build one from a `Palette` with
`Themes.Make`: the states of a control (resting, under the pointer, pressed,
turned off) in each of its tones are worked out once, so drawing only looks
them up. The application has slots of its own, `Themes.Custom (0)` and on, for
what only it draws, set with `Themes.Set_Custom`. A control is a face, an
outline and a bevel (light along its top and left, shade along its foot and
right, turned over when held down), with an optional solid shadow; a palette
with `Bevelled => False` gives a flat look instead.

## Icons

It has no pictures of its own: an application names its icons with an
enumeration and `Pomarine.Icons.Sets`, which gives each a file (`edit.svg`) in
a folder of its own. The few the widgets draw themselves (`Check`, `Close`,
`Minimize`, `Chevron_Down`, `Chevron_Up`) are looked for as `check.svg` and so
on, unless given other files.

## Sizes

What a person types or makes has no limit: the text of a label, a button or a
menu row, the widgets in a tree, the rows of a menu and the application's own
colours (`Themes.Custom`) all grow as they are given. A widget has one handler
for each kind of event, so there is no number of them to run out of. What
remains is fixed because something outside bounds it, and is a configuration
variable of the `pomarine_ui` crate (see `ui/alire.toml`), set in the
application's `alire.toml` under `[configuration.values]`: `Icon_Capacity`
(icons a library holds), `Semantic_Text` and `Semantic_Value` (characters of a
name and of a value an assistive technology is told).

## Testing and measuring

See `TESTING.md`. `bench/` has the measures of what a frame costs
(`widget_bench`, `text_area_bench`, `bench`) and of what many small widgets
cost (`ui_bench`).
