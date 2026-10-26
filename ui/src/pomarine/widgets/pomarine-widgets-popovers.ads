with Pomarine.Anchoring;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;

--  A box that floats over the window beside something, or at a point, holding any widgets the application adds to
--  it: white, outlined, rounded and casting a shadow, in a column, as tall as what is in it. It is a Panel, so what it
--  holds is added and styled as to any box (Layouts.Add), and it is shown with the overlays of the tree (see
--  Pomarine.Widgets.Overlays): put by its anchor on the side that has room, kept in the window, and let go of by
--  Escape or a press outside it, when it says Dismiss.
--
--     Popovers.Add (Root, Info, Width => 260.0);
--     Layouts.Add (Info, Heading, (Height => 20.0, others => <>));
--     ...
--     Popovers.Show_Beside (Info, Help_Button);
package Pomarine.Widgets.Popovers is

   type Popover is new Panels.Panel with private;

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Popover;
      Width  : Layouts.Length := 240.0)
     with Pre => Is_Attached (Parent) and then not Is_Attached (Item) and then Child_Count (Item) = 0,
          Post => Is_Attached (Item) and then not Is_Visible (Item);
   --  Add Item to Parent, hidden, as wide as Width, in a column with 8 points of padding and 6 between what it holds.
   --  Parent is the root, or a box that covers the window, for the overlay to be put in the window.

   procedure Show_Beside
     (Item   : in out Popover;
      Anchor : Widget'Class;
      Where  : Pomarine.Anchoring.Placement := (others => <>);
      How    : Pomarine.Anchoring.Behavior := Pomarine.Anchoring.Light_Dismiss);
   --  Present it beside Anchor (see Overlays.Present_Beside).

   procedure Show_At
     (Item  : in out Popover;
      X, Y  : Float;
      Where : Pomarine.Anchoring.Placement := (Gap => 12.0, others => <>);
      How   : Pomarine.Anchoring.Behavior := Pomarine.Anchoring.Light_Dismiss);
   --  Present it at the point X, Y in points.

   procedure Hide (Item : in out Popover);
   --  Let go of it, saying nothing.

   function Is_Shown (Item : Popover) return Boolean;

private

   type Popover is new Panels.Panel with null record;

end Pomarine.Widgets.Popovers;
