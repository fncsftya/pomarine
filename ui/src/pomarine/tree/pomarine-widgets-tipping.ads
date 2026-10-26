--  The tooltips of a tree: which widget the pointer has rested on, for how long, and when to show the box beside it.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.
private package Pomarine.Widgets.Tipping is

   procedure Step (Home : in out Tree; Now : Pomarine.Events.Milliseconds);
   --  At each update: show the tip if the pointer has rested long enough, let go of it if it has moved to another
   --  widget.

   function Wait (Home : Tree) return Integer;
   --  How many milliseconds until it is to be shown; -1 if it is not waiting to be.

   procedure Pressed (Home : in out Tree);
   --  A key, a press or a wheel turn: let go of the tip, and show none until the pointer is over another widget.

end Pomarine.Widgets.Tipping;
