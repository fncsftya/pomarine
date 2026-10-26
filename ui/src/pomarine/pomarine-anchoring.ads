--  Where something that floats over a window goes, and how it is let go of: what the overlays of a tree
--  (Pomarine.Widgets.Overlays) are told, as a value.
package Pomarine.Anchoring is

   type Side_Kind is (Below, Above, After, Before);
   --  Which side of what it is placed by it goes: under it, over it, after it (to its right) or before it (to its
   --  left).

   type Along_Kind is (Start, Middle, Finish);
   --  Which of its edges is lined up with the edge of what it is placed by, along that side: its left (for Below
   --  or Above) or top (for After or Before), its middle, or its right or bottom.

   type Placement is record
      Side   : Side_Kind := Below;
      Along  : Along_Kind := Start;
      Gap    : Float := 4.0;
      --  In points, between it and what it is placed by.
      Flip   : Boolean := True;
      --  Go to the other side if it does not fit on this one and does on that.
      Margin : Float := 8.0;
      --  In points: the nearest it comes to the edge of the window.
      Match_Width : Boolean := False;
      --  Be as wide as what it is placed by, as the menu of a select is.
   end record;

   type Behavior is record
      Outside_Click : Boolean := True;
      --  A press anywhere but on it lets it go.
      Escape : Boolean := True;
      --  Escape lets it go.
      Modal : Boolean := False;
      --  What is under it takes no press, wheel turn or pointer, and Tab goes round only what is in it, until it
      --  is let go.
      Pass_Through : Boolean := False;
      --  The press that lets it go (Outside_Click) is then also given to what is under it. A press on what it is
      --  placed by only lets it go, so that clicking a select again closes its menu and does not open it anew.
   end record;

   Light_Dismiss : constant Behavior := (Outside_Click => True, Escape => True, Modal => False, Pass_Through => False);
   --  A menu, a popover: let go by a press elsewhere, or Escape.

   Dialog : constant Behavior := (Outside_Click => False, Escape => True, Modal => True, Pass_Through => False);
   --  Over everything, taking all of the input until it is answered or Escape lets it go.

   Passive : constant Behavior := (Outside_Click => False, Escape => False, Modal => False, Pass_Through => True);
   --  A tooltip: it takes and lets go of nothing; the application takes it away.

end Pomarine.Anchoring;
