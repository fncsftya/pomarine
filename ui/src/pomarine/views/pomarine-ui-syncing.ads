with Pomarine.Widgets;

--  Keeping the widgets and the models in step: the order of things.
--
--  A turn of synchronization is made of passes. A pass is
--
--     1. Collect: every binding says what the person did to its widget to the
--        model, by the setters: text that was typed (not while an input method
--        is composing it), a row that was chosen. A widget that shows what the
--        model last said it showed is not an edit.
--     2. The command of the event that began the turn, if there is one:
--        the model is asked Can_Execute (of the model as step 1 left it),
--        and does Execute if it can. Every binding is told before and after
--        (effects: reveal a row that was added).
--     3. Refresh: each binding whose model version (its own watch) is not
--        what it last showed, or whose last refresh was put off, shows the
--        model in its widget, doing nothing to a widget that already shows it.
--     4. If anything changed, the tree asks the commands again
--        (Revalidate), for the buttons.
--
--  The first turn, at Mount, is a pass in which every binding refreshes
--  whether it changed or not. Then the screen is interactive.
--
--  A turn is begun by an event of a widget (Hear) or by the tree's Update
--  (Synchronize). A turn that is under way is completed first: events heard
--  meanwhile are kept (Queued_Events) and each is given a turn of its own,
--  in order, when the pass is done; a pass that changes what another reads is
--  run again, at most Synchronization_Passes_Limit times in all.
--
--  Programmatic changes to a widget (setting text, choosing a row) are
--  never heard as edits: the binding notes what it showed.
private package Pomarine.UI.Syncing is

   procedure Install
     (Within : in out View'Class; Item : in out Pomarine.Widgets.Widget'Class; Kind : Pomarine.Widgets.Event_Kind);
   --  Have Item's Kind of event heard by the view (Hear).

   procedure Uninstall (Item : in out Pomarine.Widgets.Widget'Class; Kind : Pomarine.Widgets.Event_Kind);

   procedure Synchronize (Within : in out View'Class);
   --  A turn with no event.

   procedure Hear (Within : in out View'Class; Event : Pomarine.Widgets.Widget_Event);
   --  A turn begun by an event.

   procedure Show_All (Within : in out View'Class);
   --  The first turn, at Mount.

   function Validate (Within : View'Class; Tag : Integer; Index : Natural) return Pomarine.Widgets.Command_State;

end Pomarine.UI.Syncing;
