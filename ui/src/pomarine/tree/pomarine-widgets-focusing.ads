--  Which widget has the focus and which the pointer is over, and the tab order they move in.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.
private package Pomarine.Widgets.Focusing is

   procedure Set_Focus (Item : in out Tree; To : Node_Index);

   function Is_Taker (Item : Tree; Slot : Node_Index) return Boolean;

   procedure Next_Focus (Item : in out Tree; Backwards : Boolean := False);

   function Within (Item : Tree; Slot, Inside : Node_Index) return Boolean;

   procedure Set_Hover (Item : in out Tree; To : Node_Index);

end Pomarine.Widgets.Focusing;
