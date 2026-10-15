# Pomarine

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
Widgets.Add (Root, Bar, Page);                    --  in order
Widgets.Add (Bar, Save_Button, Quit_Button);

Layouts.Set_Layout (Root, Flow => Column);        --  in points; the tree knows the density
                                                  --  (Unit => Device_Pixels for pixels)
Layouts.Set_Layout (Bar, Flow => Row, Height => 32.0, Padding => (others => 4.0), Gap => 4.0);
Layouts.Set_Layout (Page, Grow => 1.0);

Buttons.Set_Label (Save_Button, "Save");
Buttons.Set_Kind (Save_Button, Buttons.Primary);
Commands.Bind (Save_Button, Save);

--  Running:
Widgets.Dispatch (Tree, Event, Handled);          --  for each event; listeners hear it after
Widgets.Update (Tree, Ticks);                     --  timers, and models that changed
if Widgets.Needs_Paint (Tree) then
   Widgets.Paint (Tree, Target, Themes.Light, Retained => ...);
   Renderers.Present (Target);
end if;
```

See the comment at the top of `Pomarine.Widgets` for the whole loop.

## What is where

| | |
| --- | --- |
| `Pomarine.Widgets` | The tree, the events, damage and drawing; the base of every widget. |
| `Pomarine.Widgets.Layouts` | `Set_Layout`: a box's style, in points, one call. |
| `Pomarine.Widgets.Commands` | The application's own enumeration, for what widgets are for. |
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

The same things can be asked for, instead, with a widget's `Take_...`
(`Buttons.Take_Click` and the like): for gestures that are better looked at
as they go on than said when they end, as a drag.

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

The room for text, icons, menu rows and the application's colours is fixed, to
allocate nothing while it runs. Each is a configuration variable of the
`pomarine_ui` crate (see `ui/alire.toml`): `Label_Capacity`, `Button_Label`,
`Icon_Capacity`, `Menu_Rows`, `Custom_Colors`; set them in the application's
`alire.toml` under `[configuration.values]`.

## Testing and measuring

See `TESTING.md`. `bench/` has the measures of what a frame costs
(`widget_bench`, `text_area_bench`, `bench`) and of what many small widgets
cost (`ui_bench`).
