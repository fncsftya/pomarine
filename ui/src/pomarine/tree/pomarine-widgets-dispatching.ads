--  Input events going to widgets: which widget is under the pointer, who takes a press, a key or a wheel turn, and the
--  shape of the pointer.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.
private package Pomarine.Widgets.Dispatching is

   function Hit_Slot (Item : Tree; X, Y : Float) return Node_Index;

   procedure Bubble
     (Home    : Tree;
      From    : Node_Index;
      Event   : Pomarine.Events.Event;
      Taker   : out Node_Index);

   function Accepting (Home : Tree; From : Node_Index) return Node_Index;

   procedure Dispatch_Press
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Over    : Node_Index;
      Handled : out Boolean);

   procedure Set_Input_Source (Item : in out Tree; Keyboard : Boolean);

   procedure Dispatch_Keys
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   procedure Dispatch_Event
     (Item    : in out Tree;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean);

   function Cursor_Wanted (Item : Tree) return SDL3.Cursors.Kind;

end Pomarine.Widgets.Dispatching;
