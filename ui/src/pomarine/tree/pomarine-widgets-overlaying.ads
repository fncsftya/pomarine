--  Overlays: what floats over the rest of the tree (a menu, a popover, a dialog) is placed by what it is anchored to,
--  kept inside the window, and let go of by Escape or a press outside it. The public face is Pomarine.Widgets.Overlays;
--  this is the part the tree's layout and input call.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.

private package Pomarine.Widgets.Overlaying is

   procedure Push (Content : in out Widget'Class; Using : Overlay)
   with Pre => Is_Attached (Content);
   --  Show Content over the rest and put it where Using says, at the next layout; with the focus in it if it is modal.

   function Index_Of (Home : Tree; Content : Node_Id) return Natural;
   --  Which of the overlays it is; 0 if it is none.

   procedure Remove (Home : in out Tree; Index : Positive; Told : Boolean)
   with Pre => Index <= Home.Overlay_Count;
   --  Let go of that overlay, and those over it: hide them, give back the focus and the scope a modal one took, and, if
   --  Told, have each say Dismiss.

   procedure Prune (Home : in out Tree);
   --  Forget the overlays whose content is no longer in the tree.

   function Slot_Of (Home : Tree; Id : Node_Id) return Node_Index;
   --  Where that widget is, or 0 if it is no longer there.

   function Is_Modal_Content (Home : Tree; Slot : Node_Index) return Boolean;
   --  Whether Slot is a modal overlay that is presented: what is painted before it is dimmed.

   function Position (Home : in out Tree; Wide, High : Float) return Boolean;
   --  Put each overlay where it goes, in the window of Wide x High pixels, by the sizes and places the last layout
   --  gave. Whether any was moved (and the layout is to be done again).

   procedure Take_Input (Home : in out Tree; Event : Pomarine.Events.Event; Over : Node_Index; Consumed : out Boolean);
   --  What an overlay does with an input event before the widgets below see it: Escape or a press outside lets it go,
   --  and a modal one takes what is outside it. Over is the widget under the pointer, for a pointer's event.

end Pomarine.Widgets.Overlaying;
