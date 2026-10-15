--  Words found in a picture, and where each is in it: what Picture
--  widgets show as selectable text. Whatever finds them (Vision, on
--  macOS) fills a Result, and the widget is told of it.

package Pomarine.Words is

   Max_Words : constant := 4_096;
   --  Of one picture: more are left out (Result.Truncated).

   Text_Capacity : constant := 48_000;
   --  Bytes of all the words together.

   type Word is record
      Line   : Natural := 0;
      --  Which run of text it was found in, from 1, in reading order:
      --  words of one line are joined with a space, lines with a break.
      First, Last : Natural := 0;
      --  Where its UTF-8 is in Result.Text.
      Left, Top, Width, Height : Float := 0.0;
      --  Its box, as fractions of the picture's width and height, from
      --  its top left: 0.0 .. 1.0, so they do not change with the size
      --  the picture is shown at.
   end record
     with Convention => C;

   type Word_Array is array (1 .. Max_Words) of Word
     with Convention => C;

   type Result is record
      Count     : Natural := 0;
      --  Words (1 .. Count), in reading order.
      Length    : Natural := 0;
      --  Text (1 .. Length) is what is used.
      Truncated : Boolean := False;
      Words     : Word_Array;
      Text      : String (1 .. Text_Capacity) := [others => ' '];
   end record
     with Dynamic_Predicate =>
       Result.Count <= Max_Words and then Result.Length <= Text_Capacity;

   type Result_Access is access constant Result;

   function Image (Of_Word : Word; In_Result : Result) return String
     is (In_Result.Text (Of_Word.First .. Of_Word.Last))
     with Pre => Of_Word.Last in Of_Word.First - 1 .. In_Result.Length;
   --  The word's text.

end Pomarine.Words;
