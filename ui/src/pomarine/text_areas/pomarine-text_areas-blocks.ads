with Texts;

--  Paragraphs marked as a list, and set in, as one step.

private package Pomarine.Text_Areas.Blocks is

   Bullet_Mark : constant String :=
     [Standard.Character'Val (16#E2#), Standard.Character'Val (16#80#), Standard.Character'Val (16#A2#), ' '];

   type Marker is record
      Lead   : Natural := 0;  --  spaces before it
      Length : Natural := 0;  --  bytes of the mark; 0 if there is none
      Which  : Block := Bullets;
   end record;

   function Marker_Of (Item : Text_Area; Para : Positive) return Marker;
   --  The mark that begins paragraph Para, if any.

   function Mark_End (Item : Text_Area; Para : Positive) return Position;
   --  Where the text of list item Para starts, after its lead and mark.

   procedure Paragraph_Range (Item : Text_Area; First, Last : out Positive);

   procedure Renumber_Around (Item : in out Text_Area; First, Last : Integer);
   --  Numbers again the runs that touch paragraphs First .. Last (clipped to the document) and keeps
   --  the selection where it was in its paragraphs, whatever the new marks take.

   procedure Renumber_Caret (Item : in out Text_Area);
   --  Numbers again the runs around the caret after text was removed.

   procedure Toggle (Item : in out Text_Area; Which : Block);

   procedure Split_Line (Item : in out Text_Area; Continue : Boolean);
   --  Return in a list item starts the next one, or ends the list on an empty item; Continue is False
   --  (Shift+Return) for a new plain paragraph after the item.

   procedure Break_Line (Item : in out Text_Area; Continue : Boolean);

   procedure Indent (Item : in out Text_Area; Outward : Boolean);

   procedure Style_Paragraphs (Item : in out Text_Area; To : Texts.Paragraph_Kind);

   procedure Clear_Of_Mark (Item : in out Text_Area; Typed : String);
   --  Text typed or pasted into the lead or mark of a list item goes after the mark: the mark stays first.

end Pomarine.Text_Areas.Blocks;
