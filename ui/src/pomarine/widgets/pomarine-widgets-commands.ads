--  The application's own commands, as an enumeration, for what widgets are
--  for.
--
--     type Command is (Save, Open_Settings, Rename_Card, ...);
--     package Commands is new Pomarine.Widgets.Commands (Command);
--
--     Commands.Bind (Save_Button, Save);
--     Commands.Bind (Card.Rename, Rename_Card, Index => K);
--
--  and in the listener, which hears of every widget:
--
--     case Commands.What (Event) is
--        when Save        => ...
--        when Rename_Card => ... Event.Index ...
--        when others      => null;
--     end case;
--
--  A widget that says more than one thing (a grip: Click, Double_Click, Drag)
--  has its Event.Kind to say which.
generic
   type Command is (<>);
package Pomarine.Widgets.Commands is

   procedure Bind (Item : in out Widget'Class; Is_For : Command; Index : Natural := 0);
   --  Say what the widget is for, and which of many it is: as Set_Tag does.

   function Is_Bound (Event : Widget_Event) return Boolean is
     (Event.Tag in 0 .. Command'Pos (Command'Last));
   --  Whether the widget that said it was given a command.

   function What (Event : Widget_Event) return Command
     with Pre => Is_Bound (Event);
   --  The command of the widget that said Event.

end Pomarine.Widgets.Commands;
