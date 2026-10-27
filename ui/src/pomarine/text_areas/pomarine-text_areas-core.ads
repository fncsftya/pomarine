with Texts.Documents;

private package Pomarine.Text_Areas.Core is

   procedure Restart_Blink (Item : in out Text_Area);
   --  Show the caret, for a period from now.

   procedure Catch_Up (Item : in out Text_Area);
   --  Bring the caret, the selection and what is shown along with the
   --  document's changes since they were last seen, and lay it out.

   function Line_Of (Item : in out Text_Area; At_Point : Position) return Positive;
   --  The line At_Point is on, of its paragraph, laid out.

   function Updated (Item : Text_Area; At_Point : Position) return Position;
   --  Where At_Point, as the text area last saw the document, is now:
   --  another view may have changed it since.

   function Selection_First (Item : Text_Area) return Position;
   function Selection_Last (Item : Text_Area) return Position;

   procedure Scroll_By (Item : in out Text_Area; By : Float);

   procedure Reveal (Item : in out Text_Area);
   --  Scroll as little as brings the caret's line into view, and, for one
   --  line, across to it.

   procedure Moved (Item : in out Text_Area);
   --  The caret or the text changed: show the caret, and bring it into
   --  view.

   procedure Measure_Caret (Item : in out Text_Area; X, Y, Width, Height : out Float);
   --  Where the caret is drawn, in pixels.

   procedure Change
     (Item     : in out Text_Area;
      From, To : Position;
      By       : String;
      Undo_As  : Texts.Documents.Edit_Kind := Texts.Documents.Other;
      Recorded : Boolean := True)
   with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then not (To < From);
   --  Replace the text from From to To with By, and put the caret after
   --  it, with nothing selected.

   procedure Edit (Item : in out Text_Area; From, To : Position; By : String; Undo_As : Texts.Documents.Edit_Kind)
   with Pre => Is_Position (Item, From) and then Is_Position (Item, To) and then not (To < From);
   --  Replace the text from From to To with By, to undo, with the caret
   --  after it, and bring it into view.

   function Without_Returns (Raw : String) return String;
   --  Raw without carriage returns, as from CR LF line ends.

   function Fitted (Item : Text_Area; Raw : String) return String;
   --  What of Raw to put in the text: without carriage returns, and for
   --  one line, with spaces for line feeds.

   procedure Drop_Composition (Item : in out Text_Area);
   --  Take the input method's text away, leaving the caret where it was.

   procedure Finish_Composition (Item : in out Text_Area);
   --  Keep the input method's text as if it were typed: before anything
   --  else is done.

end Pomarine.Text_Areas.Core;
