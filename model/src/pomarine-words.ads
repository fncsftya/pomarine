with Ada.Finalization;

--  Words found in a picture, and where each is in it: what Picture
--  widgets show as selectable text. Whatever finds them (Vision, on
--  macOS) fills a Result, and the widget is told of it.

package Pomarine.Words is

   type Word is record
      Line                     : Natural := 0;
      --  Which run of text it was found in, from 1, in reading order:
      --  words of one line are joined with a space, lines with a break.
      First, Last              : Natural := 0;
      --  Where its UTF-8 is in Result.Text.
      Left, Top, Width, Height : Float := 0.0;
      --  Its box, as fractions of the picture's width and height, from
      --  its top left: 0.0 .. 1.0, so they do not change with the size
      --  the picture is shown at.
   end record
   with Convention => C;

   type Word_Array is array (Positive range <>) of Word with Convention => C;

   type Word_Array_Access is access Word_Array;
   type Text_Access is access String;

   type Result is new Ada.Finalization.Controlled with record
      Count     : Natural := 0;
      --  Words (1 .. Count), in reading order.
      Length    : Natural := 0;
      --  Text (1 .. Length) is what is used.
      Truncated : Boolean := False;
      --  Whether the finder left words out (it was asked for no more).
      Words     : Word_Array_Access;
      Text      : Text_Access;
      --  With room for at least Count words and Length bytes: see Reserve.
   end record;
   --  As many words as the picture has: the room grows to hold them.

   procedure Reserve (Item : in out Result; Words_Wanted : Natural; Bytes : Natural)
   with
     Post =>
       Item.Words /= null
       and then Item.Text /= null
       and then Item.Words'Length >= Words_Wanted
       and then Item.Text'Length >= Bytes;
   --  Have room for this many words and bytes, and keep those there are.

   procedure Clear (Item : in out Result)
   with Post => Item.Count = 0 and then Item.Length = 0 and then not Item.Truncated;
   --  Hold no words; the room is kept.

   type Result_Access is access constant Result;

   function Image (Of_Word : Word; In_Result : Result) return String
   is (In_Result.Text (Of_Word.First .. Of_Word.Last))
   with Pre => Of_Word.Last in Of_Word.First - 1 .. In_Result.Length;
   --  The word's text.

   overriding
   procedure Adjust (Item : in out Result);
   overriding
   procedure Finalize (Item : in out Result);

end Pomarine.Words;
