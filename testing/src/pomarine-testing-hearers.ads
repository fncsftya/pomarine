with Ada.Containers.Vectors;
with System;
with Pomarine.Widgets;

--  A listener that keeps what the widgets said, for a test to ask who said
--  what, as it asks the widgets themselves of their state.
package Pomarine.Testing.Hearers is

   type Hearer is limited new Pomarine.Widgets.Listener with private;

   overriding procedure Handle_Event
     (Self   : in out Hearer;
      Source : in out Pomarine.Widgets.Widget'Class;
      Event  : Pomarine.Widgets.Widget_Event);

   procedure Take
     (Self   : in out Hearer;
      Source : Pomarine.Widgets.Widget'Class;
      Kind   : Pomarine.Widgets.Event_Kind;
      Taken  : out Boolean);
   --  Whether Source has said Kind since this was last asked of it, and
   --  forget what it said.

   procedure Take
     (Self   : in out Hearer;
      Source : Pomarine.Widgets.Widget'Class;
      Kind   : Pomarine.Widgets.Event_Kind;
      Event  : out Pomarine.Widgets.Widget_Event;
      Taken  : out Boolean);
   --  The first of what Source said of Kind, if it did, and forget it.

   procedure Take_Row
     (Self   : in out Hearer;
      Source : Pomarine.Widgets.Widget'Class;
      Kind   : Pomarine.Widgets.Event_Kind;
      Row    : out Natural);
   --  The Row of the first of what Source said of Kind, 0 if none, and
   --  forget it.

   procedure Forget (Self : in out Hearer);

private

   type Heard is record
      From  : System.Address := System.Null_Address;
      Event : Pomarine.Widgets.Widget_Event;
   end record;

   package Heard_Vectors is new Ada.Containers.Vectors (Positive, Heard);

   type Hearer is limited new Pomarine.Widgets.Listener with record
      Log : Heard_Vectors.Vector;
   end record;

end Pomarine.Testing.Hearers;
