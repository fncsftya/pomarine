with Ada.Strings.Fixed;
with Pomarine.Text_Areas.Core;
with Texts.Documents;

package body Pomarine.Text_Areas.Blocks is

   package Docs renames Texts.Documents;

   use Core;
   use type Texts.Paragraph_Kind;
   use type Texts.Position;

   function Marker_Of (Item : Text_Area; Para : Positive) return Marker is
      Stop : constant Positive := Natural'Min (Docs.Byte_Length (Item.Doc.all, Para), 48) + 1;
      Text : constant String := Docs.Slice (Item.Doc.all, Para, 1, Stop);
      Lead : Natural := 0;
   begin
      while Lead < Text'Length and then Text (Text'First + Lead) = ' ' loop
         Lead := Lead + 1;
      end loop;
      declare
         Rest    : constant String := Text (Text'First + Lead .. Text'Last);
         Figures : Natural := 0;
      begin
         if Rest'Length >= Bullet_Mark'Length
           and then Rest (Rest'First .. Rest'First + Bullet_Mark'Length - 1) = Bullet_Mark
         then
            return (Lead, Bullet_Mark'Length, Bullets);
         end if;
         while Figures < Rest'Length and then Rest (Rest'First + Figures) in '0' .. '9' loop
            Figures := Figures + 1;
         end loop;
         if Figures > 0
           and then Rest'Length >= Figures + 2
           and then Rest (Rest'First + Figures .. Rest'First + Figures + 1) = ". "
         then
            return (Lead, Figures + 2, Numbers);
         end if;
         return (Lead, 0, Bullets);
      end;
   end Marker_Of;

   function Mark_End (Item : Text_Area; Para : Positive) return Position is
      Found : constant Marker := Marker_Of (Item, Para);
   begin
      return (Para, Found.Lead + Found.Length + 1);
   end Mark_End;

   procedure Paragraph_Range (Item : Text_Area; First, Last : out Positive) is
      From : constant Position := Selection_First (Item);
      To   : constant Position := Selection_Last (Item);
   begin
      First := From.Paragraph;
      Last := (if To.Paragraph > From.Paragraph and then To.Index = 1 then To.Paragraph - 1 else To.Paragraph);
   end Paragraph_Range;

   procedure Renumber_Run (Item : in out Text_Area; Para : Positive) is
      First : Positive := Para;
      Last  : Positive := Para;
      Lead  : Natural;

      function Joins (Other : Positive) return Boolean
      is (Marker_Of (Item, Other).Which = Numbers
          and then Marker_Of (Item, Other).Length > 0
          and then Marker_Of (Item, Other).Lead = Lead);
   begin
      if Marker_Of (Item, Para).Length = 0 or else Marker_Of (Item, Para).Which /= Numbers then
         return;
      end if;
      Lead := Marker_Of (Item, Para).Lead;
      while First > 1 and then Joins (First - 1) loop
         First := First - 1;
      end loop;
      while Last < Docs.Count (Item.Doc.all) and then Joins (Last + 1) loop
         Last := Last + 1;
      end loop;
      for Each in First .. Last loop
         declare
            Found  : constant Marker := Marker_Of (Item, Each);
            Wanted : constant String :=
              Ada.Strings.Fixed.Trim (Natural'Image (Each - First + 1), Ada.Strings.Left) & ". ";
            Old    : constant String := Docs.Slice (Item.Doc.all, Each, Found.Lead + 1, Found.Lead + Found.Length + 1);
         begin
            if Old /= Wanted then
               Replace_Range (Item, (Each, Found.Lead + 1), (Each, Found.Lead + Found.Length + 1), Wanted);
            end if;
         end;
      end loop;
   end Renumber_Run;

   procedure Renumber_Around (Item : in out Text_Area; First, Last : Integer) is
      From      : constant Position := Selection_First (Item);
      To        : constant Position := Selection_Last (Item);
      From_Tail : constant Natural := Docs.Byte_Length (Item.Doc.all, From.Paragraph) + 1 - From.Index;
      To_Tail   : constant Natural := Docs.Byte_Length (Item.Doc.all, To.Paragraph) + 1 - To.Index;
   begin
      for Para in Integer'Max (1, First) .. Integer'Min (Docs.Count (Item.Doc.all), Last) loop
         Renumber_Run (Item, Para);
      end loop;
      Select_Range
        (Item,
         (From.Paragraph, Docs.Byte_Length (Item.Doc.all, From.Paragraph) + 1 - From_Tail),
         (To.Paragraph, Docs.Byte_Length (Item.Doc.all, To.Paragraph) + 1 - To_Tail));
   end Renumber_Around;

   procedure Toggle (Item : in out Text_Area; Which : Block) is
      First, Last : Positive;
      Every       : Boolean := True;
      Number      : Natural := 0;
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      Paragraph_Range (Item, First, Last);
      if Which = Quote then
         Every := (for all Para in First .. Last => Docs.Inset (Item.Doc.all, Para).Quoted);
         Docs.Seal (Item.Doc.all);
         Docs.Begin_Step (Item.Doc.all);
         for Para in First .. Last loop
            Docs.Set_Inset (Item.Doc.all, Para, (Docs.Inset (Item.Doc.all, Para) with delta Quoted => not Every));
         end loop;
         Docs.End_Step (Item.Doc.all);
         Docs.Seal (Item.Doc.all);
         Catch_Up (Item);
         Reveal (Item);
         return;
      end if;
      for Para in First .. Last loop
         declare
            Found : constant Marker := Marker_Of (Item, Para);
         begin
            Every := Every and then Found.Length > 0 and then Found.Which = Which;
         end;
      end loop;
      Docs.Seal (Item.Doc.all);
      Docs.Begin_Step (Item.Doc.all);
      for Para in First .. Last loop
         declare
            Found : constant Marker := Marker_Of (Item, Para);
         begin
            Number := Number + 1;
            Docs.Replace
              (Item.Doc.all,
               (Para, Found.Lead + 1),
               (Para, Found.Lead + 1 + Found.Length),
               (if Every
                then ""
                else
                  (case Which is
                     when Bullets => Bullet_Mark,
                     when Quote   => raise Program_Error,
                     when Numbers => Ada.Strings.Fixed.Trim (Natural'Image (Number), Ada.Strings.Left) & ". ")));
         end;
      end loop;
      Docs.End_Step (Item.Doc.all);
      Docs.Seal (Item.Doc.all);
      Renumber_Around (Item, First - 1, Last + 1);
      Catch_Up (Item);
      Reveal (Item);
   end Toggle;

   procedure Split_Line (Item : in out Text_Area; Continue : Boolean) is
      Para  : constant Positive := Caret (Item).Paragraph;
      Found : constant Marker := Marker_Of (Item, Para);
      Empty : constant Boolean :=
        Found.Length > 0 and then Docs.Byte_Length (Item.Doc.all, Para) = Found.Lead + Found.Length;
   begin
      if Found.Length = 0 or else Has_Selection (Item) then
         Insert (Item, [ASCII.LF]);
      elsif Empty then
         Finish_Composition (Item);
         Replace_Range (Item, (Para, 1), (Para, Found.Lead + Found.Length + 1), "");
         if not Continue then
            Insert (Item, [ASCII.LF]);
         end if;
      elsif not Continue then
         Insert (Item, [ASCII.LF]);
      else
         declare
            Lead   : constant String := [1 .. Found.Lead => ' '];
            Prefix : constant String := Docs.Slice (Item.Doc.all, Para, Found.Lead + 1, Found.Lead + Found.Length + 1);
            Next   : constant String :=
              (if Found.Which = Bullets
               then Bullet_Mark
               else
                 Ada.Strings.Fixed.Trim
                   (Natural'Image (Natural'Value (Prefix (Prefix'First .. Prefix'Last - 2)) + 1), Ada.Strings.Left)
                 & ". ");
         begin
            Insert (Item, ASCII.LF & Lead & Next);
         end;
      end if;
   end Split_Line;

   procedure Break_Line (Item : in out Text_Area; Continue : Boolean) is
   begin
      Split_Line (Item, Continue);
      Renumber_Around (Item, Caret (Item).Paragraph - 1, Caret (Item).Paragraph + 1);
   end Break_Line;

   procedure Indent (Item : in out Text_Area; Outward : Boolean) is
      First, Last : Positive;
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      Paragraph_Range (Item, First, Last);
      Docs.Seal (Item.Doc.all);
      Docs.Begin_Step (Item.Doc.all);
      for Para in First .. Last loop
         declare
            Was : constant Texts.Paragraph_Inset := Docs.Inset (Item.Doc.all, Para);
         begin
            if not Outward then
               Docs.Set_Inset (Item.Doc.all, Para, (Was with delta Indent => Was.Indent + 1));
            elsif Was.Indent > 0 then
               Docs.Set_Inset (Item.Doc.all, Para, (Was with delta Indent => Was.Indent - 1));
            end if;
         end;
      end loop;
      Docs.End_Step (Item.Doc.all);
      Docs.Seal (Item.Doc.all);
      Catch_Up (Item);
      Reveal (Item);
   end Indent;

   procedure Style_Paragraphs (Item : in out Text_Area; To : Texts.Paragraph_Kind) is
      First, Last : Positive;
   begin
      if Item.Single or else Item.Read_Only then
         return;
      end if;
      Finish_Composition (Item);
      Paragraph_Range (Item, First, Last);
      Docs.Seal (Item.Doc.all);
      Docs.Begin_Step (Item.Doc.all);
      for Para in First .. Last loop
         if Docs.Kind (Item.Doc.all, Para) /= To then
            Docs.Set_Kind (Item.Doc.all, Para, To);
         end if;
      end loop;
      Docs.End_Step (Item.Doc.all);
      Docs.Seal (Item.Doc.all);
      Catch_Up (Item);
      Reveal (Item);
   end Style_Paragraphs;

   procedure Clear_Of_Mark (Item : in out Text_Area; Typed : String) is
      Where : constant Position := Item.At_Caret;
   begin
      if Has_Selection (Item)
        or else (Typed'Length > 0 and then Typed (Typed'First) = ASCII.LF)
        or else Marker_Of (Item, Where.Paragraph).Length = 0
        or else Where.Index > Mark_End (Item, Where.Paragraph).Index
      then
         return;
      end if;
      Select_Range (Item, Mark_End (Item, Where.Paragraph), Mark_End (Item, Where.Paragraph));
   end Clear_Of_Mark;

   procedure Renumber_Caret (Item : in out Text_Area) is
      Para : constant Positive := Caret (Item).Paragraph;
   begin
      --  Plain text is left alone so that runs of deleting still undo together.
      if (for some Near in Integer'Max (1, Para - 1) .. Integer'Min (Docs.Count (Item.Doc.all), Para + 1) =>
            Marker_Of (Item, Near).Length > 0)
      then
         Renumber_Around (Item, Para - 1, Para + 1);
      end if;
   end Renumber_Caret;

end Pomarine.Text_Areas.Blocks;
