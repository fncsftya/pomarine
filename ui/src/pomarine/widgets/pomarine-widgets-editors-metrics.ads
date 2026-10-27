with Ada.Strings.Fixed;

--  The measures of an editor's toolbar and bubbles, and what they share.

private package Pomarine.Widgets.Editors.Metrics is

   Toolbar_Left : constant Float := 12.0;
   Toolbar_Top  : constant Float := 7.0;
   Button_Wide  : constant Float := 28.0;
   Button_High  : constant Float := 28.0;
   Button_Gap   : constant Float := 6.0;
   --  In points, in the toolbar's band at the top of the text area.

   Command_Mark : constant String := [Character'Val (16#E2#), Character'Val (16#8C#), Character'Val (16#98#)];
   --  The command key's symbol, U+2318, in UTF-8.

   Divider_Gap      : constant Float := 8.0;
   Tool_Wide        : constant Float := 64.0;
   Edit_Left        : constant Float :=
     Toolbar_Left + 4.0 * Button_Wide + 3.0 * Button_Gap + Divider_Gap + 1.0 + Divider_Gap;
   Lists_End        : constant Float := Edit_Left + 5.0 * Button_Wide + 4.0 * Button_Gap;
   Edit_End         : constant Float := Edit_Left + 6.0 * Button_Wide + 5.0 * Button_Gap;
   --  The editing buttons but the last, Link, which is left out first when it is narrow.
   Family_Wide      : constant Float := 112.0;
   Family_Menu_Wide : constant Float := 240.0;
   --  The menu of families is wider than the select, to show more of their names.
   Size_Wide        : constant Float := 68.0;
   Style_Wide       : constant Float := 106.0;
   Font_Left        : constant Float := Edit_End + Divider_Gap + 1.0 + Divider_Gap;
   Size_Left        : constant Float := Font_Left + Family_Wide + Button_Gap;
   Style_Left       : constant Float := Size_Left + Size_Wide + Button_Gap;
   Font_End         : constant Float := Style_Left + Style_Wide;
   Tools_Left       : constant Float := Font_End + Divider_Gap + 1.0 + Divider_Gap;
   --  In points: each section is Divider_Gap after the one before, divider
   --  between: the style buttons, the editing buttons, the font controls
   --  and the tool buttons.

   Menu_Rows_High : constant Float := 240.0;
   --  The most the menu of a font control is high, in points.

   Sizes : constant array (1 .. 12) of Positive := [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 32, 48];
   --  The sizes, in points, the menu has.

   function Style_Name (Kind : Texts.Paragraph_Kind) return String
   is (case Kind is
         when Texts.Heading_1 => "Heading 1",
         when Texts.Heading_2 => "Heading 2",
         when Texts.Heading_3 => "Heading 3",
         when others          => "Normal");

   function Size_Text (Points : Float) return String
   is (Ada.Strings.Fixed.Trim (Integer'Image (Integer (Points)), Ada.Strings.Left) & " pt");

   function Tool_Left (Tool : Tool_Number) return Float
   is (Tools_Left + Float (Tool - 1) * (Tool_Wide + Button_Gap));

   function Tools_End (Item : Editor) return Float
   is (if Item.Tool_Total = 0 then Font_End else Tool_Left (Item.Tool_Total) + Tool_Wide);

   Tip_Gap : constant Float := 4.0;
   --  In points, between a tool button and its tooltip.

   Toolbar_Order : constant array (0 .. 3) of Texts.Documents.Format :=
     [Texts.Documents.Bold, Texts.Documents.Italic, Texts.Documents.Underline, Texts.Documents.Strikethrough];

   Bubble_High  : constant Float := 40.0;
   Bubble_Pad   : constant Float := 6.0;
   Bubble_Gap   : constant Float := 6.0;  --  between a bubble and the caret
   Count_Wide   : constant Float := 56.0;
   Confirm_Wide : constant Float := 2.0 * Button_Wide + 3.0 * Bubble_Pad;
   Cycle_Wide   : constant Float := 2.0 * Button_Wide + Count_Wide + 4.0 * Bubble_Pad;
   --  In points.

   Link_Field_Wide : constant Float := 200.0;
   Link_Wide       : constant Float := Link_Field_Wide + 2.0 * Button_Wide + 4.0 * Bubble_Pad;
   Link_Longest    : constant Float := 100_000.0;
   --  Layout units: wider than any address is typed.
   Link_Text_Size  : constant Float := 13.0;
   Link_Select_Top : constant Float := Bubble_High - 4.0;
   Link_Tall_High  : constant Float := Link_Select_Top + Button_High + Bubble_Pad;
   --  With the list of what may be chosen, a select of its own under the field.

   function Trimmed (Words : String) return String
   is (Ada.Strings.Fixed.Trim (Words, Ada.Strings.Both));

   function Family_Shown (Item : Editor) return String;
   --  Of the text at the caret, or the selection's start.

   function Size_Shown (Item : Editor) return Float;

   function Window_Height (Item : Widget'Class) return Float;

   procedure Shape_Bubble (Item : in out Editor; Bubble : in out Panels.Panel; Wide : Float);

   procedure Put_Button
     (Item        : in out Editor;
      Bubble      : in out Panels.Panel;
      Part        : in out Buttons.Button;
      Left, Wide  : Float;
      Label, Name : String);

   procedure Place_Bubble
     (Item                : in out Editor;
      Bubble              : in out Panels.Panel;
      Wide                : Float;
      X, Top, Bottom      : Float;
      Left_Kept, Top_Kept : in out Integer;
      High                : Float := Bubble_High);
   --  Under the caret, or over it if there is no room under it in the window.

end Pomarine.Widgets.Editors.Metrics;
