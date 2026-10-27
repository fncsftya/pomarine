private package Pomarine.Text_Areas.Finding is

   function Search_Position (Item : Text_Area; Offset : Positive) return Position;
   --  Where byte Offset of the whole text is.

   procedure Refresh (Item : in out Text_Area; Term : String);
   --  Find Term again, in the document as it is.

end Pomarine.Text_Areas.Finding;
