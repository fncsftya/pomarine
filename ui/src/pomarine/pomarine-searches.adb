with Ada.Wide_Wide_Characters.Handling;
with Ada.Strings.Unbounded;
with Ada.Strings.Wide_Wide_Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
with SDL3.Windows.Renderers;

package body Pomarine.Searches is
   procedure Clear (Item : in out Results) is
   begin
      Item.Matches.Clear;
      Item.Boxes.Clear;
      Item.Current := 0;
   end Clear;

   procedure Find (Item : in out Results; Text, Term : String; Page : Positive := 1) is
      package UTF renames Ada.Strings.UTF_Encoding.Wide_Wide_Strings;
      Lower : constant Wide_Wide_String := Ada.Wide_Wide_Characters.Handling.To_Lower (UTF.Decode (Text));
      Query : constant Wide_Wide_String := Ada.Wide_Wide_Characters.Handling.To_Lower (UTF.Decode (Term));
      package Offsets is new Ada.Containers.Vectors (Positive, Positive);
      Bytes : Offsets.Vector;
      Byte : Positive := Text'First;
      Start : Positive := Lower'First;
      Hit : Natural;
   begin
      if Query'Length = 0 then
         return;
      end if;
      --  Keep byte boundaries of the original UTF-8, even when lowercasing changes its encoded length.
      while Byte <= Text'Last loop
         Bytes.Append (Byte);
         Byte := Byte + 1;
         while Byte <= Text'Last and then Character'Pos (Text (Byte)) in 16#80# .. 16#BF# loop
            Byte := Byte + 1;
         end loop;
      end loop;
      Bytes.Append (Byte);
      while Start <= Lower'Last loop
         Hit := Ada.Strings.Wide_Wide_Fixed.Index (Lower, Query, Start);
         exit when Hit = 0;
         Item.Matches.Append (Match'(Bytes (Hit), Bytes (Hit + Query'Length) - 1, Page));
         Start := Hit + Query'Length;
      end loop;
   end Find;

   procedure Find_Words
     (Item : in out Results; Found : Words.Result; Term : String; Page : Positive := 1)
   is
      use Ada.Strings.Unbounded;
      Before : constant Natural := Natural (Item.Matches.Length);
      First_Word : Positive := 1;
      Text : Unbounded_String;
      Ranges : Match_Lists.Vector;
   begin
      if Found.Count = 0 or else Term = "" then
         return;
      end if;
      --  OCR and page builders store word bytes without separators. Search their reading order,
      --  joining words with a space so that phrases also span wrapped lines.
      for Index in 1 .. Found.Count loop
         if Index > 1 then
            Append (Text, ' ');
         end if;
         declare
            Start : constant Positive := Length (Text) + 1;
         begin
            Append (Text, Words.Image (Found.Words (Index), Found));
            Ranges.Append (Match'(Start, Length (Text), Page));
         end;
      end loop;
      Find (Item, To_String (Text), Term, Page);
      for Hit in Before + 1 .. Natural (Item.Matches.Length) loop
         while First_Word <= Found.Count and then Ranges (First_Word).Last < Item.Matches (Hit).First loop
            First_Word := @ + 1;
         end loop;
         for Index in First_Word .. Found.Count loop
            declare
               W : Words.Word renames Found.Words (Index);
               M : constant Match := Item.Matches (Hit);
            begin
               exit when Ranges (Index).First > M.Last;
               if Ranges (Index).Last >= M.First then
                  Item.Boxes.Append (Box'(Hit, Page, W.Left, W.Top, W.Width, W.Height));
               end if;
            end;
         end loop;
      end loop;
   end Find_Words;

   procedure Step (Item : in out Results; Backwards : Boolean := False) is
      Total : constant Natural := Natural (Item.Matches.Length);
   begin
      if Total = 0 then
         Item.Current := 0;
      elsif Backwards then
         Item.Current := (if Item.Current <= 1 then Total else Item.Current - 1);
      else
         Item.Current := (if Item.Current >= Total then 1 else Item.Current + 1);
      end if;
   end Step;

   procedure Draw
     (Item : Results; Target : SDL3.Painters.Painter'Class;
      Page : Positive; Left, Top, Width, Height : Float)
   is
      use SDL3.Windows.Renderers;
   begin
      for B of Item.Boxes loop
         if B.Page = Page then
            SDL3.Painters.Fill_Rect
              (Target, (if B.Hit = Item.Current then Color'(40, 120, 255, 130)
                        else Color'(60, 170, 255, 65)),
               Left + B.Left * Width, Top + B.Top * Height, B.Width * Width, B.Height * Height);
            SDL3.Painters.Fill_Rect
              (Target, Color'(30, 110, 240, 230), Left + B.Left * Width,
               Top + (B.Top + B.Height) * Height - 1.0, B.Width * Width, 1.0);
         end if;
      end loop;
   end Draw;
end Pomarine.Searches;
