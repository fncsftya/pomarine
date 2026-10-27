with Pomarine.Text_Areas.Core;
with Pomarine.Text_Areas.Geometry;
with Texts.Documents;
with Typeset.Layouts;
package body Pomarine.Text_Areas.Moving is

   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;

   use Core;
   use Geometry;

   function Step
     (Item : in out Text_Area;
      From : Position;
      By   : Motion) return Position
   is
      Doc_Of   : Docs.Document renames Item.Doc.all;
      Para     : constant Positive := From.Paragraph;
      Byte     : constant Positive := From.Index;
      At_Start : constant Boolean := Byte = 1;
      At_End   : constant Boolean := Byte > Byte_Length (Item, Para);
   begin
      case By is
         when Previous_Character | Previous_Word =>
            if not At_Start then
               return
                 (Para,
                  (if By = Previous_Word
                   then Layouts.Previous_Word (Doc_Of, Para, Byte)
                   else Layouts.Previous_Character (Doc_Of, Para, Byte)));
            elsif Para > 1 then
               return Para_End (Item, Para - 1);
            end if;

         when Next_Character | Next_Word =>
            if not At_End then
               return
                 (Para,
                  (if By = Next_Word
                   then Layouts.Next_Word (Doc_Of, Para, Byte)
                   else Layouts.Next_Character (Doc_Of, Para, Byte)));
            elsif Para < Count (Item) then
               return (Para + 1, 1);
            end if;

         when Line_Start =>
            declare
               Number : constant Positive := Line_Of (Item, From);
            begin
               return
                 (Para,
                  Docs.Index_Of
                    (Doc_Of, Para,
                     Layouts.Line (Item.Laid, Para, Number).First));
            end;

         when Line_End =>
            declare
               Number : constant Positive := Line_Of (Item, From);
            begin
               if Layouts.Line (Item.Laid, Para, Number).Stop
                 < Docs.Length (Doc_Of, Para)
               then
                  --  Before the space the line breaks after.
                  return
                    (Para,
                     Docs.Index_Of
                       (Doc_Of, Para,
                        Layouts.Units_At_Offset
                          (Item.Laid, Doc_Of, Para, Number, Float'Last)));
               end if;
               return Para_End (Item, Para);
            end;

         when Paragraph_Start =>
            if not At_Start then
               return (Para, 1);
            elsif Para > 1 then
               return (Para - 1, 1);
            end if;

         when Paragraph_End =>
            if not At_End then
               return Para_End (Item, Para);
            elsif Para < Count (Item) then
               return Para_End (Item, Para + 1);
            end if;

         when Text_Start =>
            return (1, 1);

         when Text_End =>
            return Last_Position (Item);

         when Previous_Line | Next_Line =>
            raise Program_Error;
      end case;
      return From;
   end Step;

   function Line_Position
     (Item   : in out Text_Area;
      Para   : Positive;
      Number : Positive;
      X      : Float) return Position is
   begin
      return
        (Para,
         Docs.Index_Of
           (Item.Doc.all, Para,
            Layouts.Units_At_Offset
              (Item.Laid, Item.Doc.all, Para, Number, X)));
   end Line_Position;

   function Vertical_Step
     (Item : in out Text_Area;
      By   : Motion) return Position
   is
      Para   : constant Positive := Item.At_Caret.Paragraph;
      Number : constant Positive := Line_Of (Item, Item.At_Caret);
   begin
      if not Item.Has_Goal then
         Item.Goal := Layouts.Caret_Offset
           (Item.Laid, Item.Doc.all, Para, Number,
            Units (Item, Item.At_Caret));
         Item.Has_Goal := True;
      end if;

      if By = Previous_Line then
         if Number > 1 then
            return Line_Position (Item, Para, Number - 1, Item.Goal);
         elsif Para > 1 then
            Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para - 1);
            return Line_Position
              (Item, Para - 1, Layouts.Line_Count (Item.Laid, Para - 1),
               Item.Goal);
         end if;
         return (1, 1);
      end if;

      Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para, Number + 1);
      if Number < Layouts.Line_Count (Item.Laid, Para) then
         return Line_Position (Item, Para, Number + 1, Item.Goal);
      elsif Para < Count (Item) then
         Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para + 1, 1);
         return Line_Position (Item, Para + 1, 1, Item.Goal);
      end if;
      return Last_Position (Item);
   end Vertical_Step;

   function Point_At (Item : in out Text_Area; X, Y : Float)
      return Position
   is
      Depth : constant Float :=
        View_Top (Item) + (Y - Text_Top (Item)) / Scale (Item);
      Para  : constant Positive := Layouts.Paragraph_At (Item.Laid, Depth);
      High : constant Float := Layouts.Line_Height (Item.Laid, Para);
      Within : constant Float :=
        Float'Max (0.0, Depth - Layouts.Top (Item.Laid, Para)) / High;
      Wanted : constant Positive :=
        (if Within >= Float (Most_Lines) then Most_Lines
         else Natural (Float'Floor (Within)) + 1);
   begin
      Layouts.Lay_Out (Item.Laid, Item.Doc.all, Para, Wanted);
      return Line_Position
        (Item, Para,
         Positive'Min (Wanted, Layouts.Line_Count (Item.Laid, Para)),
         (X - Column_Left (Item)) / Scale (Item));
   end Point_At;

end Pomarine.Text_Areas.Moving;
