with Pomarine.Text_Areas.Blocks;
with Pomarine.Text_Areas.Core;
with Pomarine.Text_Areas.Geometry;
with Texts.Documents;
with Typeset.Layouts;
package body Pomarine.Text_Areas.Keys is

   package Docs renames Texts.Documents;
   package Layouts renames Typeset.Layouts;

   use Blocks;
   use Core;
   use Geometry;
   use type Events.Key_Code;
   use type Texts.Position;

   procedure Handle_Key
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean)
   is
      Key     : constant Events.Key_Code := Event.Key;
      Command : constant Boolean := Event.Command;
      Option  : constant Boolean := Event.Option;
      Shift   : constant Boolean := Event.Shift;
      Control_Motion : constant Boolean :=
        Event.Control and then not Command and then not Option
        and then Key in Events.Key_A | Events.Key_E | Events.Key_B
                      | Events.Key_F | Events.Key_P | Events.Key_N;
      High    : constant Float := Layouts.Line_Height (Item.Laid);

      function Deleting return Deletion is
        (if Command then Line_Part elsif Option then Word else Character);
   begin
      Handled := True;
      if not Item.Keyboard_Navigation
        and then (Control_Motion or else Key in Events.Key_Left_Arrow | Events.Key_Right_Arrow
                      | Events.Key_Up_Arrow | Events.Key_Down_Arrow
                      | Events.Key_Home | Events.Key_End | Events.Key_Page_Up | Events.Key_Page_Down)
      then
         return;
      end if;
      if not Item.Focused then
         null;
      elsif Control_Motion then
         Move (Item,
               (case Key is
                   when Events.Key_A => Line_Start,
                   when Events.Key_E => Line_End,
                   when Events.Key_B => Previous_Character,
                   when Events.Key_F => Next_Character,
                   when Events.Key_P => Previous_Line,
                   when Events.Key_N => Next_Line,
                   when others => raise Program_Error),
               Extend => Shift);
         if Key = Events.Key_A and then Marker_Of (Item, Item.At_Caret.Paragraph).Length > 0
           and then Item.At_Caret < Mark_End (Item, Item.At_Caret.Paragraph)
         then
            Item.At_Caret := Mark_End (Item, Item.At_Caret.Paragraph);
            if not Shift then
               Item.At_Mark := Item.At_Caret;
            end if;
            Moved (Item);
         end if;
         return;
      elsif Command and then not Item.Single and then not Item.Read_Only
        and then (Key = Events.Key_B or else Key = Events.Key_I or else Key = Events.Key_U
                  or else (Shift and then Key = Events.Key_S))
      then
         Toggle_Format (Item, (if Key = Events.Key_B then Docs.Bold elsif Key = Events.Key_I then Docs.Italic
                              elsif Key = Events.Key_U then Docs.Underline else Docs.Strikethrough));
         return;
      elsif Command and then Key = Events.Key_A then
         Select_All (Item);
         return;
      elsif Command and then Key = Events.Key_C then
         Copy (Item, Board);
         return;
      elsif Command and then Key = Events.Key_X then
         Cut (Item, Board);
         return;
      elsif Command and then Key = Events.Key_V then
         Paste (Item, Board);
         return;
      elsif Command and then Key = Events.Key_Z then
         if Shift then
            Redo (Item);
         else
            Undo (Item);
         end if;
         return;
      elsif Key = Events.Key_Left_Arrow then
         Move (Item,
               (if Command then Line_Start
                elsif Option then Previous_Word
                else Previous_Character),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Right_Arrow then
         Move (Item,
               (if Command then Line_End
                elsif Option then Next_Word
                else Next_Character),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Up_Arrow then
         Move (Item,
               (if Command then Text_Start
                elsif Option then Paragraph_Start
                else Previous_Line),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Down_Arrow then
         Move (Item,
               (if Command then Text_End
                elsif Option then Paragraph_End
                else Next_Line),
               Extend => Shift);
         return;
      elsif Key = Events.Key_Backspace then
         Delete_Backward (Item, Deleting);
         return;
      elsif Key = Events.Key_Delete then
         Delete_Forward (Item, Deleting);
         return;
      elsif Key = Events.Key_Return then
         if Item.Single then
            Item.Returned := True;
         else
            Break_Line (Item, Continue => not Shift);
         end if;
         return;
      elsif Key = Events.Key_Escape then
         Set_Focus (Item, False);
         return;
      end if;

      --  Scrolling, focused or not
      if Key = Events.Key_Down_Arrow then
         Scroll (Item, High);
      elsif Key = Events.Key_Up_Arrow then
         Scroll (Item, -High);
      elsif Key = Events.Key_Page_Down then
         Scroll (Item, Page_Fraction * Extent (Item));
      elsif Key = Events.Key_Page_Up then
         Scroll (Item, -Page_Fraction * Extent (Item));
      elsif Key = Events.Key_Home then
         Scroll (Item, -Layouts.Total_Height (Item.Laid));
      elsif Key = Events.Key_End then
         Scroll (Item, Layouts.Total_Height (Item.Laid));
      else
         Handled := False;
      end if;
   end Handle_Key;

end Pomarine.Text_Areas.Keys;
