--  What an assistive technology is told of the tree: which widgets changed, in what order, and what it asks a
--  widget to do.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.

private package Pomarine.Widgets.Accessibility is

   function Is_Told (Home : Tree; Slot : Node_Index) return Boolean;

   procedure Forget (Home : in out Tree; Slot : Node_Index);

   procedure Tell (Home : in out Tree; Slot : Node_Index; Into : in out Semantic_Sink'Class; Whole : Boolean);

   function Is_Reachable (Home : Tree; Slot : Node_Index) return Boolean;

   procedure Tell_Changes (Item : in out Tree; Into : in out Semantic_Sink'Class; Whole : Boolean := False);

   procedure Perform_On (Item : in out Tree; Id : Node_Id; Request : Semantics.Request; Done : out Boolean);

end Pomarine.Widgets.Accessibility;
