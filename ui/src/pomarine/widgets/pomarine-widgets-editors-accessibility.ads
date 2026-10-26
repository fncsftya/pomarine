with Pomarine.Semantics;

--  What an editor tells an assistive technology, and what it is asked to do.
private package Pomarine.Widgets.Editors.Accessibility is

   procedure Describe_Editor (Item : Editor; Facts : in out Pomarine.Semantics.Description);

   function Count_Parts (Item : Editor) return Natural;

   function Number_Of_Part (Item : Editor; Index : Positive) return Positive;

   procedure Describe_Piece
     (Item   : Editor;
      Part   : Positive;
      Facts  : in out Pomarine.Semantics.Description;
      Bounds : out Pomarine.Semantics.Rectangle);

   procedure Perform_Request
     (Item    : in out Editor;
      Request : Pomarine.Semantics.Request;
      Done    : out Boolean);

end Pomarine.Widgets.Editors.Accessibility;
