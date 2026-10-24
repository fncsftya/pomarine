with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;

--  What the window of Hello_GUI shows: a greeting and a button that changes it.
package Greeter is

   type Greeting is limited record
      Page  : aliased Pomarine.Widgets.Panels.Panel;
      Text  : aliased Pomarine.Widgets.Labels.Label;
      Greet : aliased Pomarine.Widgets.Buttons.Button;
      Count : Natural := 0;
   end record;
   --  The widgets are the application's own, here beside what it knows.

   procedure Build (Item : aliased in out Greeting; Tree : in out Pomarine.Widgets.Tree);
   --  Make Tree of Item's widgets, each button given the procedure to call.

end Greeter;
