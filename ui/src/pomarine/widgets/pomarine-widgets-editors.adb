with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with System;
with CoreText.Fonts;
with Texts;
with Yoga.Nodes;
package body Pomarine.Widgets.Editors is

   function Document (Item : Editor) return not null access constant Texts.Documents.Document is
     (Text_Areas.Document (Item.Text));

   function Highlight_Count (Item : Editor) return Natural is
     (Text_Areas.Highlight_Count (Item.Text));

   use type Semantics.Role;
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;

   package Docs renames Texts.Documents;

   Icon_Size : constant Float := 12.0;
   Icon_Room : constant Float := 18.0;
   --  In points: of the icon before a single line, and the room it is in.

   use type Docs.Version;
   use type Texts.Position;
   use type Texts.Paragraph_Kind;
   use type System.Address;
   use type Text_Areas.Shared_Access;

   procedure Update_Toolbar (Item : in out Editor);
   --  Show the toolbar's buttons if it is to have them, and hide them if not.

   function Tool_For_Key (Item : Editor; Key : Pomarine.Events.Key_Code) return Natural;
   --  The number of the tool whose key it is; 0 if none.

   procedure Refresh_Tip (Item : in out Editor);
   --  Show the tooltip of the tool button the pointer is over, if any.

   procedure Close_Chooser (Item : in out Editor);
   --  Hide the menu of a font control, if one is open.

   --  Show the assist button if it is wanted and there is room, and whether
   --  it is on.

   procedure Configure
     (Item    : in out Editor;
      Family  : String;
      Size    : Float;
      Measure : Float;
      Spacing : Float := 0.0) is
   begin
      Text_Areas.Configure (Item.Text, Family, Size, Measure, Spacing);
      Item.Face_Length := Natural'Min (Family'Length, Family_Capacity);
      Item.Face (1 .. Item.Face_Length) := Family (Family'First .. Family'First + Item.Face_Length - 1);
      Item.Points := Size;
      Item.Column := Measure;
      Item.Between := Spacing;
   end Configure;

   procedure Set_Edit_Icon (Item : in out Editor; Action : Edit_Action; To : Pomarine.Icons.Icon) is
   begin
      Buttons.Set_Icon (Item.Editing (Action), To);
   end Set_Edit_Icon;

   function Font_Family (Item : Editor) return String is (Item.Face (1 .. Item.Face_Length));

   function Font_Size (Item : Editor) return Float is (Item.Points);

   procedure Set_Font (Item : in out Editor; Family : String; Size : Float) is
   begin
      if Family = Font_Family (Item) and then Size = Item.Points then
         return;
      end if;
      Text_Areas.Configure (Item.Text, Family, Size, Item.Column, Item.Between);
      Item.Face_Length := Family'Length;
      Item.Face (1 .. Family'Length) := Family;
      Item.Points := Size;
      if Is_Placed (Item) then
         Placed (Item, Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
      end if;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Font;

   function Is_Configured (Item : Editor) return Boolean is
     (Text_Areas.Is_Configured (Item.Text));

   procedure Set_Shared
     (Item   : in out Editor;
      Shared : not null Shared_Access) is
   begin
      Text_Areas.Set_Shared (Item.Text, Shared);
      Item.Shared := Shared;
   end Set_Shared;

   procedure Attach
     (Item : in out Editor; Doc : not null Texts.Documents.Document_Access) is
   begin
      Text_Areas.Attach (Item.Text, Doc);
      Update_Toolbar (Item);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Attach;

   function Has_Document (Item : Editor) return Boolean is
     (Text_Areas.Is_Attached (Item.Text));

   function Zoom (Item : Editor) return Float is (Item.Zoomed);

   procedure Set_Zoom (Item : in out Editor; To : Float) is
   begin
      if To /= Item.Zoomed then
         Item.Zoomed := To;
         if Is_Placed (Item) then
            --  Now, not at the next layout, which may be after an event
            --  for the text.
            Placed (Item, Left_Of (Item), Top_Of (Item), Width_Of (Item),
                    Height_Of (Item));
            Invalidate (Item);
         end if;
      end if;
   end Set_Zoom;

   procedure Set_Invalid (Item : in out Editor; To : Boolean) is
   begin
      if To /= Item.Invalid then
         Item.Invalid := To;
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Set_Invalid;

   function Is_Invalid (Item : Editor) return Boolean is (Item.Invalid);

   procedure Set_Enabled (Item : in out Editor; To : Boolean) is
   begin
      if To /= Item.Enabled then
         Item.Enabled := To;
         if Is_Attached (Item) then
            if not To and then Has_Focus (Item) then
               Release_Focus (Item);
            end if;
            Invalidate (Item);
         end if;
      end if;
   end Set_Enabled;

   function Is_Enabled (Item : Editor) return Boolean is (Item.Enabled);

   procedure Set_Placeholder (Item : in out Editor; Text : String) is
   begin
      Item.Hint_Length := Text'Length;
      Item.Hint (1 .. Text'Length) := Text;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Placeholder;

   procedure Set_Icon (Item : in out Editor; To : Pomarine.Icons.Icon) is
   begin
      Item.Iconed := True;
      Item.Which := To;
      Text_Areas.Set_Lead (Item.Text, Icon_Room);
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Icon;

   procedure Clear_Icon (Item : in out Editor) is
   begin
      if Item.Iconed then
         Item.Iconed := False;
         Text_Areas.Set_Lead (Item.Text, 0.0);
         if Is_Attached (Item) then
            Invalidate (Item);
         end if;
      end if;
   end Clear_Icon;

   function Is_Focused (Item : Editor) return Boolean is
     (Text_Areas.Is_Focused (Item.Text));

   procedure Caret_Box
     (Item : in out Editor;
      X, Y, Width, Height : out Float) is
   begin
      Text_Areas.Caret_Box (Item.Text, X, Y, Width, Height);
   end Caret_Box;

   function Search_Count (Item : Editor) return Natural is (Text_Areas.Search_Count (Item.Text));
   function Search_Current (Item : Editor) return Natural is (Text_Areas.Search_Current (Item.Text));

   function Area (Item : in out Editor)
      return not null access Pomarine.Text_Areas.Text_Area is
     (Item.Text'Unchecked_Access);

   Toolbar_Left  : constant Float := 12.0;
   Toolbar_Top   : constant Float := 7.0;
   Button_Wide   : constant Float := 28.0;
   Button_High   : constant Float := 28.0;
   Button_Gap    : constant Float := 6.0;
   --  In points, in the toolbar's band at the top of the text area.

   Command_Mark  : constant String :=
     [Character'Val (16#E2#), Character'Val (16#8C#), Character'Val (16#98#)];
   --  The command key's symbol, U+2318, in UTF-8.

   Divider_Gap   : constant Float := 8.0;
   Tool_Wide     : constant Float := 64.0;
   Edit_Left     : constant Float :=
     Toolbar_Left + 4.0 * Button_Wide + 3.0 * Button_Gap + Divider_Gap + 1.0 + Divider_Gap;
   Lists_End     : constant Float := Edit_Left + 5.0 * Button_Wide + 4.0 * Button_Gap;
   Edit_End      : constant Float := Edit_Left + 6.0 * Button_Wide + 5.0 * Button_Gap;
   --  The editing buttons but the last, Link, which is left out first when it is narrow.
   Family_Wide   : constant Float := 112.0;
   Family_Menu_Wide : constant Float := 240.0;
   --  The menu of families is wider than the select, to show more of their names.
   Size_Wide     : constant Float := 68.0;
   Style_Wide    : constant Float := 106.0;
   Font_Left     : constant Float := Edit_End + Divider_Gap + 1.0 + Divider_Gap;
   Size_Left     : constant Float := Font_Left + Family_Wide + Button_Gap;
   Style_Left    : constant Float := Size_Left + Size_Wide + Button_Gap;
   Font_End      : constant Float := Style_Left + Style_Wide;
   Tools_Left    : constant Float := Font_End + Divider_Gap + 1.0 + Divider_Gap;
   --  In points: each section is Divider_Gap after the one before, divider
   --  between: the style buttons, the editing buttons, the font controls
   --  and the tool buttons.

   Menu_Rows_High : constant Float := 240.0;
   --  The most the menu of a font control is high, in points.

   Sizes : constant array (1 .. 12) of Positive := [8, 9, 10, 11, 12, 14, 16, 18, 20, 24, 32, 48];
   --  The sizes, in points, the menu has.

   function Style_Name (Kind : Texts.Paragraph_Kind) return String is
     (case Kind is
         when Texts.Heading_1 => "Heading 1", when Texts.Heading_2 => "Heading 2",
         when Texts.Heading_3 => "Heading 3", when others => "Normal");

   function Size_Text (Points : Float) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Integer (Points)), Ada.Strings.Left) & " pt");

   function Tool_Left (Tool : Tool_Number) return Float is
     (Tools_Left + Float (Tool - 1) * (Tool_Wide + Button_Gap));

   function Tools_End (Item : Editor) return Float is
     (if Item.Tool_Total = 0 then Font_End
      else Tool_Left (Item.Tool_Total) + Tool_Wide);

   Tip_Gap       : constant Float := 4.0;
   --  In points, between a tool button and its tooltip.

   function Tip_Text (Item : Editor; Tool : Tool_Number) return String is
     (Buttons.Label (Item.Tools (Tool))
      & (if Item.Keys (Tool) = ASCII.NUL then ""
         else "  " & Command_Mark & Ada.Characters.Handling.To_Upper (Item.Keys (Tool))));

   function Tool_Count (Item : Editor) return Natural is (Item.Tool_Total);

   function Tool_For_Key (Item : Editor; Key : Pomarine.Events.Key_Code) return Natural is
   begin
      for Tool in 1 .. Item.Tool_Total loop
         if Item.Keys (Tool) /= ASCII.NUL
           and then Key = Pomarine.Events.Key_Code (Character'Pos (Item.Keys (Tool)))
         then
            return Tool;
         end if;
      end loop;
      return 0;
   end Tool_For_Key;

   procedure Refresh_Tip (Item : in out Editor) is
      Found : Boolean := False;
      Which : Tool_Number := 1;
   begin
      if Item.Toolbar_Shown then
         for Tool in 1 .. Item.Tool_Total loop
            if Is_Attached (Item.Tools (Tool)) and then Is_Hovered (Item.Tools (Tool)) then
               Found := True;
               Which := Tool;
            end if;
         end loop;
      end if;
      if Found then
         if not Item.Tip_Shown or else Item.Tip_For /= Which then
            declare
               Pixels : constant Float := Density (Item);
            begin
               Tooltips.Set_Text (Item.Tip, Tip_Text (Item, Which));
               if not Is_Attached (Item.Tip) then
                  Add (Item, Item.Tip);
                  Yoga.Nodes.Set_Position_Type (Node (Item.Tip), Yoga.Absolute);
               end if;
               Yoga.Nodes.Set_Position (Node (Item.Tip), Yoga.Left, Tool_Left (Which) * Pixels);
               Yoga.Nodes.Set_Position
                 (Node (Item.Tip), Yoga.Top, (Toolbar_Top + Button_High + Tip_Gap) * Pixels);
               Yoga.Nodes.Set_Width
                 (Node (Item.Tip), Float'Rounding (Tooltips.Natural_Width (Item.Tip) * Pixels));
               Yoga.Nodes.Set_Height (Node (Item.Tip), Tooltips.Height * Pixels);
               Set_Visible (Item.Tip, True);
               Item.Tip_Shown := True;
               Item.Tip_For := Which;
               Request_Layout (Item);
            end;
         end if;
      elsif Item.Tip_Shown then
         Item.Tip_Shown := False;
         Set_Visible (Item.Tip, False);
      end if;
   end Refresh_Tip;

   Toolbar_Order : constant array (0 .. 3) of Docs.Format :=
     [Docs.Bold, Docs.Italic, Docs.Underline, Docs.Strikethrough];

   function Toolbar_Wanted (Item : Editor) return Boolean is
     (Has_Document (Item) and then Is_Attached (Item) and then Item.Enabled
      and then Text_Areas.Has_Toolbar (Item.Text));

   Bullet_Label : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A2#)];
   Quote_Label  : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#9C#)];
   Arrow_Left   : constant String := [Character'Val (16#E2#), Character'Val (16#86#), Character'Val (16#90#)];
   Arrow_Right  : constant String := [Character'Val (16#E2#), Character'Val (16#86#), Character'Val (16#92#)];
   Arrow_Out    : constant String := [Character'Val (16#E2#), Character'Val (16#86#), Character'Val (16#97#)];
   --  U+2022, U+201C, U+2190, U+2192 and U+2197 in UTF-8.

   function Family_Shown (Item : Editor) return String is
     (if Text_Areas.Family_Here (Item.Text) /= "" then Text_Areas.Family_Here (Item.Text) else Font_Family (Item));
   --  Of the text at the caret, or the selection's start.

   function Size_Shown (Item : Editor) return Float is
     (if Text_Areas.Size_Here (Item.Text) > 0 then Float (Text_Areas.Size_Here (Item.Text)) else Item.Points);

   procedure Place_Select
     (Item : in out Editor; Part : in out Selects.Select_Field; Name : String; Left, Wide : Float)
   is
      Pixels : constant Float := Density (Item);
   begin
      if not Is_Attached (Part) then
         Set_Accessible_Name (Part, Name);
         Set_Listener (Part, Item'Unchecked_Access);
         Add (Item, Part);
      end if;
      Yoga.Nodes.Set_Position_Type (Node (Part), Yoga.Absolute);
      Yoga.Nodes.Set_Position (Node (Part), Yoga.Left, Left * Pixels);
      Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, Toolbar_Top * Pixels);
      Yoga.Nodes.Set_Width (Node (Part), Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Part), Button_High * Pixels);
   end Place_Select;

   procedure Build_Toolbar (Item : in out Editor) is
      use type Docs.Format;
      Pixels : constant Float := Density (Item);
   begin
      for Place in Toolbar_Order'Range loop
         declare
            Style : constant Docs.Format := Toolbar_Order (Place);
            Part  : Buttons.Button renames Item.Toolbar (Style);
         begin
            if not Is_Attached (Part) then
               Buttons.Set_Label
                 (Part, (case Style is
                            when Docs.Bold => "B", when Docs.Italic => "I",
                            when Docs.Underline => "U", when Docs.Strikethrough => "S",
                            when Docs.Faded => "F", when Docs.Sized => "Z", when Docs.Faced => "Y",
                            when Docs.Linked => "L", when Docs.Versioned => "V"));
               Buttons.Set_Label_Style
                 (Part, (case Style is
                            when Docs.Bold => Line_Texts.Serif_Bold,
                            when Docs.Italic => Line_Texts.Serif_Italic,
                            when others => Line_Texts.Serif_Label),
                  Underlined => Style = Docs.Underline, Struck => Style = Docs.Strikethrough);
               Set_Accessible_Name
                 (Part, (case Style is
                            when Docs.Bold => "Bold", when Docs.Italic => "Italic",
                            when Docs.Underline => "Underline",
                            when Docs.Strikethrough => "Strikethrough",
                            when Docs.Faded => "Faded", when Docs.Sized => "Size", when Docs.Faced => "Family",
                            when Docs.Linked => "Link", when Docs.Versioned => "Versions"));
               Buttons.Set_Enabled (Part, True);
               Set_Listener (Part, Item'Unchecked_Access);
               Add (Item, Part);
            end if;
            Yoga.Nodes.Set_Position_Type (Node (Part), Yoga.Absolute);
            Yoga.Nodes.Set_Position
              (Node (Part), Yoga.Left,
               (Toolbar_Left + Float (Place) * (Button_Wide + Button_Gap)) * Pixels);
            Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, Toolbar_Top * Pixels);
            Yoga.Nodes.Set_Width (Node (Part), Button_Wide * Pixels);
            Yoga.Nodes.Set_Height (Node (Part), Button_High * Pixels);
         end;
      end loop;
      for Action in Edit_Action loop
         declare
            Part : Buttons.Button renames Item.Editing (Action);
         begin
            if not Is_Attached (Part) then
               Buttons.Set_Label
                 (Part, (case Action is
                            when Bulleted => Bullet_Label, when Numbered => "1.", when Quoted => Quote_Label,
                            when Outdent => Arrow_Left, when Indent => Arrow_Right, when Link => Arrow_Out));
               Set_Accessible_Name
                 (Part, (case Action is
                            when Bulleted => "Bulleted list", when Numbered => "Numbered list",
                            when Quoted => "Quotation", when Outdent => "Decrease indent",
                            when Indent => "Increase indent", when Link => "Link"));
               Buttons.Set_Enabled (Part, True);
               Set_Listener (Part, Item'Unchecked_Access);
               Add (Item, Part);
            end if;
            Yoga.Nodes.Set_Position_Type (Node (Part), Yoga.Absolute);
            Yoga.Nodes.Set_Position
              (Node (Part), Yoga.Left,
               (Edit_Left + Float (Edit_Action'Pos (Action)) * (Button_Wide + Button_Gap)) * Pixels);
            Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, Toolbar_Top * Pixels);
            Yoga.Nodes.Set_Width (Node (Part), Button_Wide * Pixels);
            Yoga.Nodes.Set_Height (Node (Part), Button_High * Pixels);
         end;
      end loop;
      Place_Select (Item, Item.Family_Box, "Font family", Font_Left, Family_Wide);
      Selects.Set_Faced (Item.Family_Box, True);
      Place_Select (Item, Item.Size_Box, "Font size", Size_Left, Size_Wide);
      Place_Select (Item, Item.Style_Box, "Paragraph style", Style_Left, Style_Wide);
      for Tool in 1 .. Item.Tool_Total loop
         declare
            Part : Buttons.Button renames Item.Tools (Tool);
         begin
            if not Is_Attached (Part) then
               Set_Accessible_Name (Part, Buttons.Label (Part));
               Buttons.Set_Enabled (Part, True);
               Set_Listener (Part, Item'Unchecked_Access);
               Add (Item, Part);
            end if;
            Yoga.Nodes.Set_Position_Type (Node (Part), Yoga.Absolute);
            Yoga.Nodes.Set_Position (Node (Part), Yoga.Left, Tool_Left (Tool) * Pixels);
            Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, Toolbar_Top * Pixels);
            Yoga.Nodes.Set_Width (Node (Part), Tool_Wide * Pixels);
            Yoga.Nodes.Set_Height (Node (Part), Button_High * Pixels);
         end;
      end loop;
      Request_Layout (Item);
   end Build_Toolbar;

   procedure Refresh_Toolbar (Item : in out Editor) is
   begin
      if Item.Toolbar_Shown then
         for Style of Toolbar_Order loop
            Buttons.Set_Selected (Item.Toolbar (Style), Text_Areas.Format_Active (Item.Text, Style));
         end loop;
         declare
            Reserved : constant Float := Toolbar_Left;
            Fits     : constant Boolean := Width_Of (Item) >= (Tools_End (Item) + Reserved) * Density (Item);
            Edits_Fit : constant Boolean := Width_Of (Item) >= (Lists_End + Reserved) * Density (Item);
            Link_Fits : constant Boolean := Width_Of (Item) >= (Edit_End + Reserved) * Density (Item);
            Fonts_Fit : constant Boolean := Width_Of (Item) >= (Font_End + Reserved) * Density (Item);

            procedure Show (Part : in out Widget'Class; To : Boolean) is
            begin
               if Is_Visible (Part) /= To then
                  Set_Visible (Part, To);
               end if;
            end Show;

            procedure Say (Part : in out Selects.Select_Field; Text : String) is
            begin
               if Selects.Value (Part) /= Text then
                  Selects.Set_Value (Part, Text);
               end if;
            end Say;
         begin
            for Action in Edit_Action loop
               Show (Item.Editing (Action), (if Action = Link then Link_Fits else Edits_Fit));
            end loop;
            if Has_Document (Item) then
               for Action in Bulleted .. Quoted loop
                  Buttons.Set_Selected
                    (Item.Editing (Action),
                     Text_Areas.Block_Active
                       (Item.Text, (case Action is when Bulleted => Text_Areas.Bullets,
                                                   when Numbered => Text_Areas.Numbers,
                                                   when others => Text_Areas.Quote)));
               end loop;
               Say (Item.Style_Box, Style_Name (Text_Areas.Paragraph_Style (Item.Text)));
               Buttons.Set_Enabled
                 (Item.Editing (Link),
                  Text_Areas.Has_Selection (Item.Text) and then not Text_Areas.Is_Read_Only (Item.Text));
               Buttons.Set_Selected (Item.Editing (Link), Text_Areas.Link_Here (Item.Text) /= "");
            end if;
            Show (Item.Family_Box, Fonts_Fit);
            Show (Item.Size_Box, Fonts_Fit);
            Show (Item.Style_Box, Fonts_Fit);
            if not Fonts_Fit or else not Edits_Fit then
               Close_Chooser (Item);
            end if;
            if Has_Document (Item) then
               Say (Item.Family_Box, Family_Shown (Item));
               Say (Item.Size_Box, Size_Text (Size_Shown (Item)));
            end if;
            for Tool in 1 .. Item.Tool_Total loop
               Buttons.Set_Enabled
                 (Item.Tools (Tool), not Item.Selective (Tool) or else Text_Areas.Has_Selection (Item.Text));
               if Is_Visible (Item.Tools (Tool)) /= Fits then
                  Set_Visible (Item.Tools (Tool), Fits);
               end if;
            end loop;
         end;
      end if;
   end Refresh_Toolbar;

   procedure Add_Tool
     (Item            : in out Editor;
      Label           : String;
      Key             : Character := ASCII.NUL;
      Needs_Selection : Boolean := False)
   is
      Tool : constant Tool_Number := Item.Tool_Total + 1;
   begin
      Item.Tool_Total := Tool;
      Buttons.Set_Label (Item.Tools (Tool), Label);
      Item.Keys (Tool) := Key;
      Item.Selective (Tool) := Needs_Selection;
      if Item.Toolbar_Shown then
         Build_Toolbar (Item);
         Set_Visible (Item.Tools (Tool), True);
         Refresh_Toolbar (Item);
      end if;
   end Add_Tool;

   procedure Update_Toolbar (Item : in out Editor) is
      Wanted : constant Boolean := Item.Toolbar_On and then Toolbar_Wanted (Item);
   begin
      if Wanted and then not Item.Toolbar_Shown then
         Build_Toolbar (Item);
         Item.Toolbar_Shown := True;
         for Style of Toolbar_Order loop
            Set_Visible (Item.Toolbar (Style), True);
         end loop;
         for Tool in 1 .. Item.Tool_Total loop
            Set_Visible (Item.Tools (Tool), True);
         end loop;
         Refresh_Toolbar (Item);
      elsif not Wanted and then Item.Toolbar_Shown then
         Item.Toolbar_Shown := False;
         if Is_Attached (Item) then
            Close_Chooser (Item);
            for Action in Edit_Action loop
               Set_Visible (Item.Editing (Action), False);
            end loop;
            Set_Visible (Item.Family_Box, False);
            Set_Visible (Item.Size_Box, False);
            Set_Visible (Item.Style_Box, False);
            Refresh_Tip (Item);
            for Style of Toolbar_Order loop
               Set_Visible (Item.Toolbar (Style), False);
            end loop;
            for Tool in 1 .. Item.Tool_Total loop
               Set_Visible (Item.Tools (Tool), False);
            end loop;
         end if;
      end if;
   end Update_Toolbar;

   procedure Set_Toolbar (Item : in out Editor; To : Boolean := True) is
   begin
      Item.Toolbar_On := To;
      Text_Areas.Set_Toolbar (Item.Text, To);
      Update_Toolbar (Item);
      if Is_Attached (Item) then
         Request_Layout (Item);
         Invalidate (Item);
      end if;
   end Set_Toolbar;

   function Has_Toolbar (Item : Editor) return Boolean is (Item.Toolbar_On);

   procedure Set_Indent (Item : in out Editor; Points : Float) is
   begin
      Text_Areas.Set_Indent (Item.Text, Points);
      if Is_Attached (Item) then
         Request_Layout (Item);
         Invalidate (Item);
      end if;
   end Set_Indent;

   --  Versions

   Bubble_High  : constant Float := 40.0;
   Bubble_Pad   : constant Float := 6.0;
   Bubble_Gap   : constant Float := 6.0;  --  between a bubble and the caret
   Count_Wide   : constant Float := 56.0;
   Confirm_Wide : constant Float := 2.0 * Button_Wide + 3.0 * Bubble_Pad;
   Cycle_Wide   : constant Float := 2.0 * Button_Wide + Count_Wide + 4.0 * Bubble_Pad;
   --  In points.

   function Window_Height (Item : Widget'Class) return Float is
      Above : Widget_Access := Parent_Of (Item);
      Last  : Float := Height_Of (Item);
   begin
      while Above /= null loop
         Last := Height_Of (Above.all);
         Above := Parent_Of (Above.all);
      end loop;
      return Last;
   end Window_Height;

   procedure Shape_Bubble (Item : in out Editor; Bubble : in out Panels.Panel; Wide : Float) is
      Pixels : constant Float := Density (Item);
   begin
      Panels.Set_Fill (Bubble, Themes.Page);
      Panels.Set_Border (Bubble, Themes.Border);
      Panels.Set_Radius (Bubble, 6.0);
      Add (Item, Bubble);
      Yoga.Nodes.Set_Position_Type (Node (Bubble), Yoga.Absolute);
      Yoga.Nodes.Set_Width (Node (Bubble), Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Bubble), Bubble_High * Pixels);
      Set_Visible (Bubble, False);
   end Shape_Bubble;

   procedure Put_Button
     (Item : in out Editor; Bubble : in out Panels.Panel; Part : in out Buttons.Button;
      Left, Wide : Float; Label, Name : String)
   is
      Pixels : constant Float := Density (Item);
   begin
      Buttons.Set_Label (Part, Label);
      Set_Accessible_Name (Part, Name);
      Buttons.Set_Enabled (Part, True);
      Set_Listener (Part, Item'Unchecked_Access);
      Add (Bubble, Part);
      Yoga.Nodes.Set_Position_Type (Node (Part), Yoga.Absolute);
      Yoga.Nodes.Set_Position (Node (Part), Yoga.Left, Left * Pixels);
      Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, (Bubble_High - Button_High) / 2.0 * Pixels);
      Yoga.Nodes.Set_Width (Node (Part), Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Part), Button_High * Pixels);
   end Put_Button;

   procedure Build_Bubbles (Item : in out Editor) is
      Pixels : constant Float := Density (Item);
   begin
      if Is_Attached (Item.Confirm) then
         return;
      end if;
      Shape_Bubble (Item, Item.Confirm, Confirm_Wide);
      Put_Button (Item, Item.Confirm, Item.Accept_Button, Bubble_Pad, Button_Wide, "OK", "Accept");
      Buttons.Set_Kind (Item.Accept_Button, Buttons.Primary);
      Buttons.Set_Icon (Item.Accept_Button, Pomarine.Icons.Check);
      Put_Button (Item, Item.Confirm, Item.Cancel_Button, 2.0 * Bubble_Pad + Button_Wide, Button_Wide, "X", "Cancel");
      Buttons.Set_Icon (Item.Cancel_Button, Pomarine.Icons.Close);
      Shape_Bubble (Item, Item.Cycle, Cycle_Wide);
      Put_Button (Item, Item.Cycle, Item.Back_Button, Bubble_Pad, Button_Wide, "<", "Previous version");
      Add (Item.Cycle, Item.Cycle_Count);
      Labels.Set_Centered (Item.Cycle_Count, True);
      Yoga.Nodes.Set_Position_Type (Node (Item.Cycle_Count), Yoga.Absolute);
      Yoga.Nodes.Set_Position (Node (Item.Cycle_Count), Yoga.Left, (2.0 * Bubble_Pad + Button_Wide) * Pixels);
      Yoga.Nodes.Set_Position (Node (Item.Cycle_Count), Yoga.Top, (Bubble_High - Button_High) / 2.0 * Pixels);
      Yoga.Nodes.Set_Width (Node (Item.Cycle_Count), Count_Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Item.Cycle_Count), Button_High * Pixels);
      Put_Button (Item, Item.Cycle, Item.Next_Button, 3.0 * Bubble_Pad + Button_Wide + Count_Wide, Button_Wide, ">",
           "Next version");
      Request_Layout (Item);
   end Build_Bubbles;

   procedure Place_Bubble
     (Item : in out Editor; Bubble : in out Panels.Panel; Wide : Float; X, Top, Bottom : Float;
      Left_Kept, Top_Kept : in out Integer; High : Float := Bubble_High)
   is
      --  Under the caret, or over it if there is no room under it in the window.
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := 4.0 * Pixels;
      Left   : constant Float :=
        Float'Max (Edge, Float'Min (X - Left_Of (Item), Width_Of (Item) - Wide * Pixels - Edge));
      Below  : constant Float := Bottom + Bubble_Gap * Pixels;
      Upper  : constant Boolean := Below + High * Pixels > Window_Height (Item);
      Put_Top : constant Float :=
        (if Upper then Top - Bubble_Gap * Pixels - High * Pixels else Below) - Top_Of (Item);
   begin
      if Integer (Left) /= Left_Kept or else Integer (Put_Top) /= Top_Kept then
         Left_Kept := Integer (Left);
         Top_Kept := Integer (Put_Top);
         Yoga.Nodes.Set_Position (Node (Bubble), Yoga.Left, Float'Rounding (Left));
         Yoga.Nodes.Set_Position (Node (Bubble), Yoga.Top, Float'Rounding (Put_Top));
         Request_Layout (Item);
      end if;
   end Place_Bubble;

   --  The bubble that asks for the address of a link

   Link_Field_Wide : constant Float := 200.0;
   Link_Wide       : constant Float := Link_Field_Wide + 2.0 * Button_Wide + 4.0 * Bubble_Pad;
   Link_Longest    : constant Float := 100_000.0;
   --  Layout units: wider than any address is typed.
   Link_Text_Size  : constant Float := 13.0;
   Link_Select_Top : constant Float := Bubble_High - 4.0;
   Link_Tall_High  : constant Float := Link_Select_Top + Button_High + Bubble_Pad;
   --  With the list of what may be chosen, a select of its own under the field.

   function Trimmed (Words : String) return String is (Ada.Strings.Fixed.Trim (Words, Ada.Strings.Both));

   function Address_Of (Words : String) return String is
      --  What Words says to link to: itself if it is an address, https:// and it if it is a bare domain.
      Said : constant String := Trimmed (Words);
   begin
      if Text_Areas.Is_Address (Said) then
         return Said;
      elsif Said'Length > 0 and then Said'Length + 8 <= Docs.Link_Capacity
        and then (for some C of Said => C = '.') and then (for all C of Said => C /= ':')
        and then Text_Areas.Is_Address ("https://" & Said)
      then
         return "https://" & Said;
      end if;
      return "";
   end Address_Of;

   function Link_Address (Item : Editor) return String is
     (if Item.Link_Parts = null then "" else Docs.Whole (Item.Link_Parts.Doc));

   function Link_Acceptable (Item : Editor) return Boolean is
     (Address_Of (Link_Address (Item)) /= "" or else (Item.Link_Had and then Trimmed (Link_Address (Item)) = ""));

   procedure Build_Link (Item : in out Editor) is
      Pixels : constant Float := Density (Item);
   begin
      if Is_Attached (Item.Link_Box) then
         return;
      end if;
      Item.Link_Parts := new Link_Input;
      declare
         Field : Editor renames Item.Link_Parts.Field;
      begin
         Field.Link_Owner := Item'Unchecked_Access;
         if Item.Shared /= null then
            Set_Shared (Field, Item.Shared);
         end if;
         Configure (Field, Line_Texts.Interface_Font, Link_Text_Size, Measure => Link_Longest);
         Text_Areas.Set_Single_Line (Field.Text);
         Attach (Field, Item.Link_Parts.Doc'Access);
         Set_Placeholder (Field, "Address");
         Set_Accessible_Name (Field, "Link address");
         Set_Listener (Field, Item'Unchecked_Access);
         Shape_Bubble (Item, Item.Link_Box, Link_Wide);
         Add (Item.Link_Box, Field);
         Yoga.Nodes.Set_Position_Type (Node (Field), Yoga.Absolute);
         Yoga.Nodes.Set_Position (Node (Field), Yoga.Left, Bubble_Pad * Pixels);
         Yoga.Nodes.Set_Position (Node (Field), Yoga.Top, (Bubble_High - Button_High) / 2.0 * Pixels);
         Yoga.Nodes.Set_Width (Node (Field), Link_Field_Wide * Pixels);
         Yoga.Nodes.Set_Height (Node (Field), Button_High * Pixels);
      end;
      Put_Button (Item, Item.Link_Box, Item.Link_Accept, Link_Field_Wide + 2.0 * Bubble_Pad, Button_Wide,
                  "OK", "Accept");
      Buttons.Set_Kind (Item.Link_Accept, Buttons.Primary);
      Buttons.Set_Icon (Item.Link_Accept, Pomarine.Icons.Check);
      Put_Button (Item, Item.Link_Box, Item.Link_Cancel, Link_Field_Wide + 3.0 * Bubble_Pad + Button_Wide,
                  Button_Wide, "X", "Cancel");
      Buttons.Set_Icon (Item.Link_Cancel, Pomarine.Icons.Close);
      Request_Layout (Item);
   end Build_Link;

   procedure Show_Link_Sources (Item : in out Editor; Tall : Boolean) is
      --  Make the bubble tall enough for the list of what may be chosen, with its select, or not.
      Pixels : constant Float := Density (Item);
   begin
      if Tall and then not Is_Attached (Item.Link_Sources) then
         Set_Accessible_Name (Item.Link_Sources, "Link to a source");
         Set_Listener (Item.Link_Sources, Item'Unchecked_Access);
         Selects.Set_Value (Item.Link_Sources, "Link to a source");
         Add (Item.Link_Box, Item.Link_Sources);
         Yoga.Nodes.Set_Position_Type (Node (Item.Link_Sources), Yoga.Absolute);
         Yoga.Nodes.Set_Position (Node (Item.Link_Sources), Yoga.Left, Bubble_Pad * Pixels);
         Yoga.Nodes.Set_Position (Node (Item.Link_Sources), Yoga.Top, Link_Select_Top * Pixels);
         Yoga.Nodes.Set_Width (Node (Item.Link_Sources), (Link_Wide - 2.0 * Bubble_Pad) * Pixels);
         Yoga.Nodes.Set_Height (Node (Item.Link_Sources), Button_High * Pixels);
      end if;
      Item.Link_Tall := Tall;
      Yoga.Nodes.Set_Height (Node (Item.Link_Box), (if Tall then Link_Tall_High else Bubble_High) * Pixels);
      if Is_Attached (Item.Link_Sources) then
         Set_Visible (Item.Link_Sources, Tall);
      end if;
      if not Tall then
         Close_Chooser (Item);
      end if;
      Request_Layout (Item);
   end Show_Link_Sources;

   procedure Refresh_Link (Item : in out Editor) is
   begin
      if not Is_Attached (Item.Link_Box) then
         return;
      end if;
      if Item.Linking then
         declare
            X, Y, Wide, High : Float;
            Fine : constant Boolean := Link_Acceptable (Item);
            Tall : constant Boolean := not Item.Link_Addresses.Is_Empty;
         begin
            if Tall /= Item.Link_Tall then
               Show_Link_Sources (Item, Tall);
            end if;
            Text_Areas.Caret_Box (Item.Text, X, Y, Wide, High);
            Place_Bubble (Item, Item.Link_Box, Link_Wide, X, Y, Y + High, Item.Link_Left, Item.Link_Top,
                          High => (if Tall then Link_Tall_High else Bubble_High));
            if Buttons.Is_Enabled (Item.Link_Accept) /= Fine then
               Buttons.Set_Enabled (Item.Link_Accept, Fine);
            end if;
         end;
      end if;
      if Is_Visible (Item.Link_Box) /= Item.Linking then
         Set_Visible (Item.Link_Box, Item.Linking);
      end if;
   end Refresh_Link;

   function Pointer_Version (Item : in out Editor; X, Y : Float) return Natural is
      Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
   begin
      for I in 1 .. Docs.Run_Count (Doc.all) loop
         declare
            R : constant Docs.Format_Run := Docs.Run (Doc.all, I);
         begin
            if Docs."=" (R.Style, Docs.Versioned) and then R.From < R.To
              and then Text_Areas.Is_Over_Range (Item.Text, R.From, R.To, X, Y)
            then
               return I;
            end if;
         end;
      end loop;
      return 0;
   end Pointer_Version;

   function Followed (Item : Editor) return String is (Ada.Strings.Unbounded.To_String (Item.Followed_To));

   function Pointer_Link (Item : in out Editor; X, Y : Float) return String is
      Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
   begin
      for I in 1 .. Docs.Run_Count (Doc.all) loop
         declare
            R : constant Docs.Format_Run := Docs.Run (Doc.all, I);
         begin
            if Docs."=" (R.Style, Docs.Linked) and then R.From < R.To
              and then Text_Areas.Is_Over_Range (Item.Text, R.From, R.To, X, Y)
            then
               return Ada.Strings.Unbounded.To_String (R.Name);
            end if;
         end;
      end loop;
      return "";
   end Pointer_Link;

   function Link_Under (Item : in out Editor; Event : Pomarine.Events.Event) return String is
      Pixels : constant Float := Density (Item);
      Where_X : constant Float := Event.Mouse_X * Pixels;
      Where_Y : constant Float := Event.Mouse_Y * Pixels;
   begin
      return Pointer_Link (Item, Where_X, Where_Y);
   end Link_Under;

   procedure Close_Cycle (Item : in out Editor) is
   begin
      Item.Cycle_Open := False;
   end Close_Cycle;

   procedure Open_Cycle (Item : in out Editor; Run : Positive) is
      X, Y, Wide, High : Float;
   begin
      Build_Bubbles (Item);
      Item.Cycle_Open := True;
      Item.Cycle_From := Docs.Run (Text_Areas.Document (Item.Text).all, Run).From;
      Text_Areas.Caret_Box (Item.Text, X, Y, Wide, High);
      Place_Bubble (Item, Item.Cycle, Cycle_Wide, X, Y, Y + High, Item.Cycle_Left, Item.Cycle_Top);
   end Open_Cycle;

   procedure Cycle_Version (Item : in out Editor; From : Texts.Position; By : Integer) is
      Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
      Run : constant Natural := Docs.Version_At (Doc.all, From);
   begin
      if Run = 0 then
         return;
      end if;
      declare
         Count : constant Positive := Natural (Docs.Run (Doc.all, Run).Versions.Length);
         Next  : constant Positive := (Docs.Run (Doc.all, Run).Choice - 1 + By + Count) mod Count + 1;
      begin
         Text_Areas.Choose_Version (Item.Text, Run, Next);
      end;
      Invalidate (Item);
   end Cycle_Version;

   procedure Track_Writing (Item : in out Editor) is
      Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
   begin
      --  Where what is typed starts stays where it is, if it is typed at; where it ends goes on.
      while Item.Writing and then Item.Writing_Seen < Docs.Current (Doc.all) loop
         declare
            Done : constant Docs.Change := Docs.Change_After (Doc.all, Item.Writing_Seen);
         begin
            Item.Writing_Seen := Item.Writing_Seen + 1;
            if not (Done.From = Item.Typed_From and then Done.To = Done.From) then
               Item.Typed_From := Docs.Map (Done, Item.Typed_From);
            end if;
            Item.Typed_To := Docs.Map (Done, Item.Typed_To);
         end;
      end loop;
   end Track_Writing;

   procedure Refresh_Bubbles (Item : in out Editor) is
      Doc : Docs.Document_Access;
   begin
      if not Is_Attached (Item) or else not Has_Document (Item) then
         return;
      end if;
      Doc := Text_Areas.Document (Item.Text);
      Refresh_Link (Item);
      if Item.Cycle_Open and then (Item.Writing or else Docs.Version_At (Doc.all, Item.Cycle_From) = 0) then
         Close_Cycle (Item);
      end if;
      if not (Item.Writing or else Item.Cycle_Open) and then not Is_Attached (Item.Confirm) then
         return;
      end if;
      Build_Bubbles (Item);
      if Item.Writing then
         declare
            X, Y, Wide, High : Float;
         begin
            Text_Areas.Caret_Box (Item.Text, X, Y, Wide, High);
            Place_Bubble (Item, Item.Confirm, Confirm_Wide, X, Y, Y + High, Item.Confirm_Left, Item.Confirm_Top);
         end;
      end if;
      if Is_Visible (Item.Confirm) /= Item.Writing then
         Set_Visible (Item.Confirm, Item.Writing);
      end if;
      if Item.Cycle_Open then
         declare
            R     : constant Docs.Format_Run := Docs.Run (Doc.all, Docs.Version_At (Doc.all, Item.Cycle_From));
            Shown : constant String :=
              Ada.Strings.Fixed.Trim (R.Choice'Image, Ada.Strings.Both) & " / "
              & Ada.Strings.Fixed.Trim (Natural (R.Versions.Length)'Image, Ada.Strings.Both);
         begin
            if Labels.Text (Item.Cycle_Count) /= Shown then
               Labels.Set_Text (Item.Cycle_Count, Shown);
            end if;
         end;
      end if;
      if Is_Visible (Item.Cycle) /= Item.Cycle_Open then
         Set_Visible (Item.Cycle, Item.Cycle_Open);
      end if;
   end Refresh_Bubbles;

   function Is_Writing_Version (Item : Editor) return Boolean is (Item.Writing);

   function Is_Linking (Item : Editor) return Boolean is (Item.Linking);

   procedure Set_Link_Address (Item : in out Editor; To : String) is
   begin
      Text_Areas.Select_All (Item.Link_Parts.Field.Text);
      Text_Areas.Insert (Item.Link_Parts.Field.Text, To);
      Text_Areas.Select_All (Item.Link_Parts.Field.Text);
      Invalidate (Item.Link_Parts.Field);
      Refresh_Link (Item);
   end Set_Link_Address;

   procedure Begin_Link (Item : in out Editor) is
      First : Texts.Position := Text_Areas.Caret (Item.Text);
      Last  : Texts.Position := Text_Areas.Mark (Item.Text);
   begin
      if Item.Linking or else Item.Writing or else not Is_Attached (Item)
        or else not Text_Areas.Has_Selection (Item.Text) or else Text_Areas.Is_Read_Only (Item.Text)
        or else Text_Areas.Is_Single_Line (Item.Text) or else Text_Areas.Is_Composing (Item.Text)
      then
         return;
      end if;
      if Last < First then
         First := Last;
         Last := Text_Areas.Caret (Item.Text);
      end if;
      Close_Cycle (Item);
      Close_Chooser (Item);
      Item.Link_From := First;
      Item.Link_To := Last;
      Item.Link_Had := Text_Areas.Link_Here (Item.Text) /= "";
      Build_Link (Item);
      Item.Link_Titles.Clear;
      Item.Link_Addresses.Clear;
      Item.Linking := True;
      Set_Link_Address (Item, Text_Areas.Link_Here (Item.Text));
      Refresh_Link (Item);
      Focus (Item.Link_Parts.Field);
      Notify (Item, Ask_Link);
      Invalidate (Item);
   end Begin_Link;

   procedure Clear_Link_Choices (Item : in out Editor) is
   begin
      Item.Link_Titles.Clear;
      Item.Link_Addresses.Clear;
   end Clear_Link_Choices;

   procedure Add_Link_Choice (Item : in out Editor; Title, Address : String) is
   begin
      Item.Link_Titles.Append
        (Ada.Strings.Unbounded.To_Unbounded_String (if Trimmed (Title) = "" then Address else Title));
      Item.Link_Addresses.Append (Ada.Strings.Unbounded.To_Unbounded_String (Address));
      if Item.Linking then
         Refresh_Link (Item);
      end if;
   end Add_Link_Choice;

   function Link_Choice_Count (Item : Editor) return Natural is (Natural (Item.Link_Addresses.Length));

   procedure Choose_Link (Item : in out Editor; Which : Positive) is
   begin
      Set_Link_Address (Item, Ada.Strings.Unbounded.To_String (Item.Link_Addresses (Which)));
      Finish_Link (Item, True);
   end Choose_Link;

   procedure Finish_Link (Item : in out Editor; Keep : Boolean) is
      Wanted : constant String := Address_Of (Link_Address (Item));
      Fine   : constant Boolean := Link_Acceptable (Item);
      Doc    : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
   begin
      Close_Chooser (Item);
      Item.Linking := False;
      if Keep and then Fine
        and then Docs.Is_Position (Doc.all, Item.Link_From) and then Docs.Is_Position (Doc.all, Item.Link_To)
      then
         Text_Areas.Select_Range (Item.Text, Item.Link_From, Item.Link_To);
         Text_Areas.Set_Link (Item.Text, Wanted);
      end if;
      Refresh_Link (Item);
      if Accepts_Focus (Item) then
         Focus (Item);
      end if;
      Update_Toolbar (Item);
      Refresh_Toolbar (Item);
      Invalidate (Item);
   end Finish_Link;

   procedure Begin_Version (Item : in out Editor) is
      Doc   : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
      First : Texts.Position := Text_Areas.Caret (Item.Text);
      Last  : Texts.Position := Text_Areas.Mark (Item.Text);
      Run   : Natural;
   begin
      if Item.Writing or else not Text_Areas.Has_Selection (Item.Text)
        or else Text_Areas.Is_Read_Only (Item.Text) or else Text_Areas.Is_Composing (Item.Text)
      then
         return;
      end if;
      if Last < First then
         First := Last;
         Last := Text_Areas.Caret (Item.Text);
      end if;
      if First.Paragraph /= Last.Paragraph then
         return;
      end if;
      Run := Docs.Version_Overlapping (Doc.all, First, Last);
      if Run /= 0 then
         First := Docs.Run (Doc.all, Run).From;
         Last := Docs.Run (Doc.all, Run).To;
      end if;
      Docs.Seal (Doc.all);
      Item.Writing_State := Docs.State (Doc.all);
      Item.Target_From := First;
      Item.Target_To := Last;
      Text_Areas.Replace_Range (Item.Text, First, Last, "");
      Item.Typed_From := First;
      Item.Typed_To := First;
      Item.Writing_Seen := Docs.Current (Doc.all);
      Item.Writing := True;
      Item.Cycle_Open := False;
      Refresh_Bubbles (Item);
      Invalidate (Item);
   end Begin_Version;

   procedure Finish_Version (Item : in out Editor; Keep : Boolean) is
      Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
   begin
      Track_Writing (Item);
      declare
         Plain : constant String :=
           (if Item.Typed_From < Item.Typed_To then Docs.Between (Doc.all, Item.Typed_From, Item.Typed_To) else "");
         --  What was typed as markup, to keep its styles; if it is more than a paragraph, as text.
         Typed : constant String :=
           (if Item.Typed_From < Item.Typed_To and then Item.Typed_From.Paragraph = Item.Typed_To.Paragraph
            then Docs.Fragment (Doc.all, Item.Typed_From, Item.Typed_To) else Docs.Escaped (Plain));
         Seen  : Natural;
      begin
         Item.Writing := False;
         --  Back to the text as it was before it went, and not to be redone.
         while Docs.Can_Undo (Doc.all) and then Docs.State (Doc.all) > Item.Writing_State loop
            Seen := Docs.State (Doc.all);
            Text_Areas.Undo (Item.Text);
            exit when Docs.State (Doc.all) = Seen;
         end loop;
         Docs.Discard_Redo (Doc.all);
         if Keep and then (for some C of Plain => C not in ' ' | ASCII.LF) then
            Text_Areas.Add_Version (Item.Text, Item.Target_From, Item.Target_To, Typed);
         end if;
      end;
      Refresh_Bubbles (Item);
      Invalidate (Item);
   end Finish_Version;

   procedure Track_Pointer (Item : in out Editor; Event : Pomarine.Events.Event) is
      Pixels : constant Float := Density (Item);
      Run    : Natural;
   begin
      --  A link is followed with Command held: Cursor shows it, while it is.
      if Event.Kind in Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up then
         Item.Over_Link := Item.Pointer_In_Text and then not Item.Writing
           and then Pointer_Link (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels) /= "";
      end if;
      if Item.Writing then
         Item.Hovering := False;
      elsif Event.Kind in Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up then
         Run := (if Item.Pointer_In_Text then Pointer_Version (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
                 else 0);
         Item.Hovering := Run /= 0;
         if Run /= 0 then
            Item.Hover_From := Docs.Run (Text_Areas.Document (Item.Text).all, Run).From;
         end if;
         if Event.Kind = Pomarine.Events.Mouse_Down and then Event.Button = 1 then
            if Run /= 0 then
               Open_Cycle (Item, Run);
            else
               Close_Cycle (Item);
            end if;
         end if;
      end if;
   end Track_Pointer;

   function Cycling_From (Item : Editor; From : out Texts.Position) return Boolean is
      Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
   begin
      if Item.Writing then
         return False;
      elsif Item.Hovering and then Docs.Version_At (Doc.all, Item.Hover_From) /= 0 then
         From := Item.Hover_From;
         return True;
      elsif Item.Cycle_Open and then Docs.Version_At (Doc.all, Item.Cycle_From) /= 0 then
         From := Item.Cycle_From;
         return True;
      end if;
      From := (1, 1);
      return False;
   end Cycling_From;

   --  The font controls' menus

   procedure Mark_Open (Item : in out Editor; Which : Choice; On : Boolean) is
   begin
      case Which is
         when Pick_Family  => Selects.Set_Open (Item.Family_Box, On);
         when Pick_Size    => Selects.Set_Open (Item.Size_Box, On);
         when Pick_Style   => Selects.Set_Open (Item.Style_Box, On);
         when Pick_Source  => Selects.Set_Open (Item.Link_Sources, On);
         when Nothing => null;
      end case;
   end Mark_Open;

   procedure Close_Chooser (Item : in out Editor) is
   begin
      if Item.Choosing /= Nothing then
         Mark_Open (Item, Item.Choosing, False);
         Item.Choosing := Nothing;
         if Is_Attached (Item.Chooser) then
            Set_Visible (Item.Chooser, False);
         end if;
         Invalidate (Item);
      end if;
   end Close_Chooser;

   procedure Open_Chooser (Item : in out Editor; Which : Choice) is
      Pixels : constant Float := Density (Item);
      Left   : constant Float :=
        (case Which is when Pick_Family => Font_Left, when Pick_Size => Size_Left,
                       when Pick_Source => Float (Item.Link_Left) / Pixels, when others => Style_Left);
      Wide   : constant Float :=
        (case Which is when Pick_Family => Family_Wide, when Pick_Size => Size_Wide,
                       when Pick_Source => Link_Wide - 2.0 * Bubble_Pad, when others => Style_Wide);
      Top    : Float := Toolbar_Top + Button_High + Tip_Gap;
   begin
      if Item.Choosing = Which then
         Close_Chooser (Item);
         return;
      end if;
      Close_Chooser (Item);
      if not Is_Attached (Item.Chooser) then
         Set_Listener (Item.Chooser, Item'Unchecked_Access);
         Add (Item, Item.Chooser);
         Yoga.Nodes.Set_Position_Type (Node (Item.Chooser), Yoga.Absolute);
      end if;
      Menus.Clear (Item.Chooser);
      Menus.Set_Faced (Item.Chooser, Which = Pick_Family);
      case Which is
         when Pick_Family =>
            declare
               Names : constant CoreText.Fonts.Family_Vectors.Vector := CoreText.Fonts.Families;
            begin
               for Name of Names loop
                  Menus.Add (Item.Chooser, Menus.Check, Name, Checked => Name = Family_Shown (Item));
               end loop;
            end;
         when Pick_Size =>
            for Points of Sizes loop
               Menus.Add (Item.Chooser, Menus.Check, Size_Text (Float (Points)),
                          Checked => Float (Points) = Size_Shown (Item));
            end loop;
         when Pick_Source =>
            for Title of Item.Link_Titles loop
               Menus.Add (Item.Chooser, Menus.Check, Ada.Strings.Unbounded.To_String (Title), Checked => False);
            end loop;
         when others =>
            for Kind in Texts.Paragraph_Kind range 0 .. 3 loop
               Menus.Add (Item.Chooser, Menus.Check, Style_Name (Kind),
                          Checked => Kind = Text_Areas.Paragraph_Style (Item.Text));
            end loop;
      end case;
      Menus.Set_Max_Height (Item.Chooser, Menu_Rows_High);
      for Row in 1 .. Menus.Row_Count (Item.Chooser) loop
         if Menus.Is_Checked (Item.Chooser, Row) then
            Menus.Reveal (Item.Chooser, Row);
         end if;
      end loop;
      Yoga.Nodes.Set_Position (Node (Item.Chooser), Yoga.Left, Left * Pixels);
      if Which = Pick_Source then
         --  Under the bubble, or over its select if the window has not the room.
         Top := Float (Item.Link_Top) / Pixels + Link_Tall_High + Tip_Gap;
         if Top_Of (Item) + (Top + Menus.Shown_Height (Item.Chooser)) * Pixels > Window_Height (Item) then
            Top := Float (Item.Link_Top) / Pixels + Link_Select_Top - Tip_Gap - Menus.Shown_Height (Item.Chooser);
         end if;
      end if;
      Yoga.Nodes.Set_Position (Node (Item.Chooser), Yoga.Top, Top * Pixels);
      Yoga.Nodes.Set_Width
        (Node (Item.Chooser), Float'Max (Wide, (if Which = Pick_Family then Family_Menu_Wide else 120.0)) * Pixels);
      Yoga.Nodes.Set_Height (Node (Item.Chooser), Menus.Shown_Height (Item.Chooser) * Pixels);
      Set_Visible (Item.Chooser, True);
      Raise_To_Front (Item.Chooser);
      Mark_Open (Item, Which, True);
      Item.Choosing := Which;
      Request_Layout (Item);
      Invalidate (Item);
   end Open_Chooser;

   procedure Choose_Row (Item : in out Editor; Row : Positive) is
      Which : constant Choice := Item.Choosing;
   begin
      Close_Chooser (Item);
      case Which is
         when Pick_Family =>
            declare
               Names : constant CoreText.Fonts.Family_Vectors.Vector := CoreText.Fonts.Families;
            begin
               if Row <= Natural (Names.Length) and then Has_Document (Item) then
                  Text_Areas.Set_Family (Item.Text, Names (Row));
               end if;
            end;
         when Pick_Size =>
            if Row <= Sizes'Last and then Has_Document (Item) then
               Text_Areas.Set_Size (Item.Text, Sizes (Row));
            end if;
         when Pick_Style =>
            if Row <= 4 then
               Text_Areas.Set_Style (Item.Text, Texts.Paragraph_Kind (Row - 1));
            end if;
         when Pick_Source =>
            if Row <= Link_Choice_Count (Item) and then Item.Linking then
               Choose_Link (Item, Row);
            end if;
         when Nothing =>
            null;
      end case;
      Refresh_Toolbar (Item);
      Invalidate (Item);
   end Choose_Row;

   overriding procedure Handle_Event
     (Self   : in out Editor;
      Source : in out Widget'Class;
      Event  : Widget_Event) is
   begin
      case Event.Kind is
         when Choose =>
            if Is_Attached (Self.Chooser) and then Source'Address = Self.Chooser'Address then
               Choose_Row (Self, Event.Row);
            end if;
         when Click =>
            if Is_Attached (Self.Family_Box) and then Source'Address = Self.Family_Box'Address then
               Open_Chooser (Self, Pick_Family);
            elsif Is_Attached (Self.Size_Box) and then Source'Address = Self.Size_Box'Address then
               Open_Chooser (Self, Pick_Size);
            elsif Is_Attached (Self.Link_Sources) and then Source'Address = Self.Link_Sources'Address then
               if Self.Linking then
                  Open_Chooser (Self, Pick_Source);
               end if;
            elsif Is_Attached (Self.Style_Box) and then Source'Address = Self.Style_Box'Address then
               Open_Chooser (Self, Pick_Style);
            elsif (for some Action in Edit_Action => Is_Attached (Self.Editing (Action))
                   and then Source'Address = Self.Editing (Action)'Address)
            then
               for Action in Edit_Action loop
                  if Source'Address = Self.Editing (Action)'Address and then Has_Document (Self) then
                     case Action is
                        when Bulleted => Text_Areas.Toggle_Block (Self.Text, Text_Areas.Bullets);
                        when Numbered => Text_Areas.Toggle_Block (Self.Text, Text_Areas.Numbers);
                        when Quoted   => Text_Areas.Toggle_Block (Self.Text, Text_Areas.Quote);
                        when Outdent  => Text_Areas.Shift_Indent (Self.Text, Outward => True);
                        when Indent   => Text_Areas.Shift_Indent (Self.Text, Outward => False);
                        when Link     => Begin_Link (Self);
                     end case;
                  end if;
               end loop;
               Refresh_Toolbar (Self);
               Invalidate (Self);
            elsif Is_Attached (Self.Link_Box) and then Source'Address = Self.Link_Accept'Address then
               if Self.Linking and then Link_Acceptable (Self) then
                  Finish_Link (Self, True);
               end if;
            elsif Is_Attached (Self.Link_Box) and then Source'Address = Self.Link_Cancel'Address then
               if Self.Linking then
                  Finish_Link (Self, False);
               end if;
            elsif Is_Attached (Self.Confirm) and then Source'Address = Self.Accept_Button'Address then
               if Self.Writing then
                  Finish_Version (Self, True);
               end if;
            elsif Is_Attached (Self.Confirm) and then Source'Address = Self.Cancel_Button'Address then
               if Self.Writing then
                  Finish_Version (Self, False);
               end if;
            elsif Is_Attached (Self.Confirm) and then Source'Address = Self.Back_Button'Address then
               Cycle_Version (Self, Self.Cycle_From, -1);
               Refresh_Bubbles (Self);
            elsif Is_Attached (Self.Confirm) and then Source'Address = Self.Next_Button'Address then
               Cycle_Version (Self, Self.Cycle_From, 1);
               Refresh_Bubbles (Self);
            elsif (for some Tool in 1 .. Self.Tool_Total => Source'Address = Self.Tools (Tool)'Address) then
               for Tool in 1 .. Self.Tool_Total loop
                  if Source'Address = Self.Tools (Tool)'Address and then Buttons.Is_Enabled (Self.Tools (Tool)) then
                     Notify (Self, Use_Tool, Row => Tool);
                  end if;
               end loop;
            elsif Has_Document (Self) then
               for Style of Toolbar_Order loop
                  if Source'Address = Self.Toolbar (Style)'Address then
                     Text_Areas.Toggle_Format (Self.Text, Style);
                     Refresh_Toolbar (Self);
                     Invalidate (Self);
                     exit;
                  end if;
               end loop;
            end if;
         when Submit =>
            if Self.Linking and then Self.Link_Parts /= null
              and then Source'Address = Self.Link_Parts.Field'Address and then Link_Acceptable (Self)
            then
               Finish_Link (Self, True);
            end if;
         when others =>
            null;
      end case;
   end Handle_Event;

   overriding procedure Placed
     (Item : in out Editor; Left, Top, Width, Height : Float) is
   begin
      pragma Assert
        (Is_Configured (Item), "an editor must be configured to be placed");
      --  Hidden, it has no room: it keeps where it was, rather than be
      --  wrapped to nothing and then wrapped again.
      if Width > 0.0 and then Height > 0.0 then
         Text_Areas.Place
           (Item.Text, Left, Top, Width, Height,
            Density => Density (Item), Zoom => Item.Zoomed);
      end if;
   end Placed;

   procedure Set_Paper (Item : in out Editor; To : Themes.Slot) is
   begin
      Item.Has_Paper := True;
      Item.Paper := To;
      Invalidate (Item);
   end Set_Paper;

   procedure Set_Borderless (Item : in out Editor; To : Boolean) is
   begin
      if To /= Item.Borderless then
         Item.Borderless := To;
         Invalidate (Item);
      end if;
   end Set_Borderless;

   overriding procedure Draw
     (Item   : in out Editor;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is
   begin
      if Has_Document (Item) then
         --  Of the lines, only those the part to draw touches.
         declare
            Part  : constant Pixel_Box := Painting_Part (Item);
            Paper : constant Themes.Color :=
              (if not Item.Enabled then Colors (Themes.Tint)
               elsif Item.Has_Paper then Themes.Resolve (Colors, Item.Paper)
               else Colors (Themes.Page));
            Shown : constant Themes.Theme :=
              Themes.With_Slot
                (Themes.With_Slot
                   (Themes.With_Slot
                      (Themes.With_Slot
                         (Colors, Themes.Background, Paper),
                       Themes.Selection,
                       Themes.Mix (Paper, Colors (Themes.Accent), 0.4)),
                    Themes.Foreground,
                    (if Item.Enabled then Colors (Themes.Foreground)
                     else Colors (Themes.Muted))),
                 Themes.Border,
                 (if Item.Invalid then Colors (Themes.Danger)
                  elsif Item.Borderless then Paper
                  else Colors (Themes.Border)));
            Faint : constant Themes.Color :=
              Themes.Mix (Colors (Themes.Foreground), Paper, 0.55);
            Pixels : constant Float := Density (Item);
         begin
            Text_Areas.Draw
              (Item.Text, Target, Shown, Is_Settled (Item),
               Rows_From => Float (Part.Top),
               Rows_To   => Float (Part.Top + Part.Height));
            if Item.Toolbar_Shown and then Is_Attached (Item.Editing (Bulleted)) then
               --  The dividers before the editing buttons and the font controls.
               declare
                  Origin : constant Float := Left_Of (Item.Toolbar (Docs.Bold)) - Toolbar_Left * Pixels;
                  Top    : constant Float := Top_Of (Item.Toolbar (Docs.Bold)) + 3.0 * Pixels;
                  High   : constant Float := Height_Of (Item.Toolbar (Docs.Bold)) - 6.0 * Pixels;
               begin
                  if Is_Visible (Item.Editing (Bulleted)) then
                     SDL3.Painters.Fill_Rect
                       (Target, Colors (Themes.Border), Origin + (Edit_Left - Divider_Gap - 1.0) * Pixels, Top,
                        Pixels, High);
                  end if;
                  if Is_Visible (Item.Family_Box) then
                     SDL3.Painters.Fill_Rect
                       (Target, Colors (Themes.Border), Origin + (Font_Left - Divider_Gap - 1.0) * Pixels, Top,
                        Pixels, High);
                  end if;
               end;
            end if;
            if Item.Toolbar_Shown and then Item.Tool_Total > 0 and then Is_Attached (Item.Tools (1))
              and then Is_Visible (Item.Tools (1))
            then
               --  The divider between the style buttons and the tools.
               SDL3.Painters.Fill_Rect
                 (Target, Colors (Themes.Border),
                  Left_Of (Item.Tools (1)) - (Divider_Gap + 1.0) * Pixels,
                  Top_Of (Item.Tools (1)) + 3.0 * Pixels,
                  Pixels, Height_Of (Item.Tools (1)) - 6.0 * Pixels);
            end if;
            if Item.Hint_Length > 0 and then Text_Lines (Item) /= null
              and then Docs.Count (Text_Areas.Document (Item.Text).all) = 1
              and then Docs.Length (Text_Areas.Document (Item.Text).all, 1)
                       = 0
            then
               Pomarine.Line_Texts.Draw
                 (Text_Lines (Item).all, Target, Faint,
                  Item.Hint (1 .. Item.Hint_Length),
                  Text_Areas.Line_Left (Item.Text),
                  Text_Areas.Line_Middle (Item.Text),
                  Pixels * Item.Zoomed);
            end if;
            if Item.Iconed and then Icon_Library (Item) /= null then
               declare
                  Size  : constant Positive :=
                    Positive (Float'Rounding (Icon_Size * Pixels));
                  Drawn : Boolean;
               begin
                  Pomarine.Icons.Draw
                    (Icon_Library (Item).all, Target, Item.Which, Faint,
                     Float'Rounding
                       (Text_Areas.Lead_Left (Item.Text)
                        + (Icon_Room - Icon_Size) / 2.0 * Pixels),
                     Float'Rounding
                       (Text_Areas.Line_Middle (Item.Text)
                        - Float (Size) / 2.0),
                     Size, Drawn);
               end;
            end if;
         end;
         Item.Shown := Docs.Current (Text_Areas.Document (Item.Text).all);
         Item.Shown_Serial :=
           Docs.Serial (Text_Areas.Document (Item.Text).all);
      end if;
   end Draw;

   overriding procedure Handle
     (Item    : in out Editor;
      Event   : Pomarine.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Has_Document (Item) and then Item.Enabled then
         if Event.Kind in Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Down
           | Pomarine.Events.Mouse_Up | Pomarine.Events.Mouse_Wheel
         then
            Item.Pointer_In_Text :=
              not Item.Toolbar_Shown
              or else Event.Mouse_Y * Density (Item)
                      >= Top_Of (Item) + Text_Areas.Toolbar_Points * Density (Item);
         end if;
         if Item.Choosing /= Nothing and then Event.Kind = Pomarine.Events.Mouse_Down
           and then not Is_Hovered (Item.Chooser) and then not Is_Hovered (Item.Family_Box)
           and then not Is_Hovered (Item.Size_Box) and then not Is_Hovered (Item.Style_Box)
           and then not Is_Hovered (Item.Link_Sources)
         then
            Close_Chooser (Item);
         end if;
         if Item.Linking and then Event.Kind = Pomarine.Events.Mouse_Down
           and then not Is_Hovered (Item.Link_Box) and then not Is_Hovered (Item.Link_Parts.Field)
           and then not Is_Hovered (Item.Link_Accept) and then not Is_Hovered (Item.Link_Cancel)
           and then not Is_Hovered (Item.Link_Sources) and then not Is_Hovered (Item.Chooser)
         then
            Finish_Link (Item, False);
         end if;
         if Item.Link_Owner /= null and then Item.Link_Owner.Linking and then Event.Kind = Pomarine.Events.Key_Down
           and then Event.Key = Pomarine.Events.Key_Escape
         then
            Finish_Link (Item.Link_Owner.all, False);
            Handled := True;
         elsif Item.Link_Owner = null and then Event.Kind = Pomarine.Events.Key_Down and then Event.Command
           and then not Event.Option and then not Event.Shift and then Event.Key = Pomarine.Events.Key_K
           and then Has_Focus (Item) and then not Text_Areas.Is_Single_Line (Item.Text)
           and then not Text_Areas.Is_Read_Only (Item.Text)
         then
            Begin_Link (Item);
            Handled := True;
         elsif Item.Writing and then Event.Kind = Pomarine.Events.Key_Down
           and then Event.Key in Pomarine.Events.Key_Return | Pomarine.Events.Key_Escape
         then
            Finish_Version (Item, Event.Key = Pomarine.Events.Key_Return);
            Handled := True;
         elsif Item.Cycle_Open and then Event.Kind = Pomarine.Events.Key_Down
           and then Event.Key = Pomarine.Events.Key_Escape
         then
            Close_Cycle (Item);
            Handled := True;
         elsif Event.Kind = Pomarine.Events.Mouse_Down and then Event.Button = 1 and then Event.Command
           and then Item.Pointer_In_Text and then not Item.Writing
           and then Link_Under (Item, Event) /= ""
         then
            Item.Followed_To := Ada.Strings.Unbounded.To_Unbounded_String (Link_Under (Item, Event));
            Notify (Item, Follow);
            Handled := True;
         elsif Event.Kind = Pomarine.Events.Key_Down and then not Event.Command and then not Event.Option
           and then not Event.Shift
           and then Event.Key in Pomarine.Events.Key_Left_Arrow | Pomarine.Events.Key_Right_Arrow
           and then Cycling_From (Item, Item.Cycle_Target)
         then
            Cycle_Version (Item, Item.Cycle_Target, (if Event.Key = Pomarine.Events.Key_Right_Arrow then 1 else -1));
            Handled := True;
         elsif Item.Toolbar_On and then Has_Focus (Item)
           and then Event.Kind = Pomarine.Events.Key_Down
           and then Event.Command and then not Event.Option and then not Event.Shift
           and then Event.Key in Pomarine.Events.Key_B | Pomarine.Events.Key_U | Pomarine.Events.Key_I
         then
            Text_Areas.Toggle_Format
              (Item.Text,
               (if Event.Key = Pomarine.Events.Key_B then Docs.Bold
                elsif Event.Key = Pomarine.Events.Key_U then Docs.Underline
                else Docs.Italic));
            Handled := True;
         elsif Item.Toolbar_On and then Has_Focus (Item)
           and then Event.Kind = Pomarine.Events.Key_Down
           and then Event.Command and then not Event.Option and then not Event.Shift
           and then Tool_For_Key (Item, Event.Key) /= 0
         then
            declare
               Tool : constant Tool_Number := Tool_For_Key (Item, Event.Key);
            begin
               if not Item.Selective (Tool) or else Text_Areas.Has_Selection (Item.Text) then
                  Notify (Item, Use_Tool, Row => Tool);
               end if;
            end;
            Handled := True;
         else
            Text_Areas.Handle (Item.Text, Event, Clipboard (Item).all, Handled);
         end if;
         --  A field that takes no changes says when it is pressed: for the
         --  application to offer what it is for (a file's name, to choose
         --  another).
         if Handled and then Text_Areas.Is_Read_Only (Item.Text)
           and then Pomarine.Events."=" (Event.Kind, Pomarine.Events.Mouse_Down)
         then
            Notify (Item, Click);
         end if;
         if Text_Areas.Return_Pending (Item.Text)
           and then Event.Kind in Pomarine.Events.Key_Down
           and then Event.Key in Pomarine.Events.Key_Return
         then
            Notify (Item, Submit);
         end if;
         declare
            Changed : Boolean;
         begin
            Text_Areas.Take_Bar_Change (Item.Text, Changed);
            if Handled or else Changed then
               Invalidate (Item);
            end if;
         end;
         --  Escape, for one, leaves it unfocused.
         if Has_Focus (Item) and then not Is_Focused (Item) then
            Release_Focus (Item);
         end if;
         Update_Toolbar (Item);
         Refresh_Toolbar (Item);
         Refresh_Tip (Item);
         Track_Writing (Item);
         Track_Pointer (Item, Event);
         Refresh_Bubbles (Item);
      end if;
   end Handle;

   overriding procedure Update
     (Item : in out Editor; Now : Pomarine.Events.Milliseconds)
   is
      Blinked : Boolean;
   begin
      if not Has_Document (Item) then
         return;
      end if;
      Text_Areas.Tick (Item.Text, Now, Blinked);
      Update_Toolbar (Item);
      Refresh_Toolbar (Item);
      if Blinked then
         --  Only the caret changes.
         declare
            X, Y, Wide, High : Float;
         begin
            Text_Areas.Caret_Box (Item.Text, X, Y, Wide, High);
            Invalidate
              (Item,
               (Left   => Integer (Float'Floor (X)) - 1,
                Top    => Integer (Float'Floor (Y)) - 1,
                Width  => Integer (Float'Ceiling (Wide)) + 3,
                Height => Integer (Float'Ceiling (High)) + 3));
         end;
      end if;
      --  Where the caret and the selection are is part of what an
      --  assistive technology is told.
      if Text_Areas.Caret (Item.Text) /= Item.Told_Caret
        or else Text_Areas.Mark (Item.Text) /= Item.Told_Mark
      then
         Item.Told_Caret := Text_Areas.Caret (Item.Text);
         Item.Told_Mark := Text_Areas.Mark (Item.Text);
         Mark_Dirty (Item, Semantics_Dirty);
      end if;
      --  The document may have been changed from elsewhere.
      declare
         Doc : constant Docs.Document_Access :=
           Text_Areas.Document (Item.Text);
      begin
         if Docs.Current (Doc.all) /= Item.Shown
           or else Docs.Serial (Doc.all) /= Item.Shown_Serial
         then
            Invalidate (Item);
         end if;
      end;
   end Update;

   overriding function Until_Update (Item : Editor) return Integer is
     (if Has_Document (Item) and then Is_Focused (Item)
      then Integer (Text_Areas.Until_Blink (Item.Text)) else -1);

   overriding function Accepts_Focus (Item : Editor) return Boolean is
     (Has_Document (Item) and then Item.Enabled);

   overriding function Cursor (Item : Editor) return SDL3.Cursors.Kind is
     (if Item.Enabled and then (not Item.Toolbar_Shown or else Item.Pointer_In_Text)
      then (if not Item.Writing and then (Item.Hovering or else (Item.Over_Link and then Pomarine.Events.Command_Held))
           then SDL3.Cursors.Pointer else SDL3.Cursors.Text)
      else SDL3.Cursors.Default);
   --  A text with versions is clicked, to go through them.

   overriding procedure Hover_Changed
     (Item : in out Editor; Hovered : Boolean) is
   begin
      if Has_Document (Item) then
         Text_Areas.Set_Hovered (Item.Text, Hovered);
         if not Hovered then
            Item.Hovering := False;
            Item.Over_Link := False;
         end if;
         Refresh_Tip (Item);
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding procedure Focus_Changed
     (Item : in out Editor; Focused : Boolean) is
   begin
      if Has_Document (Item) then
         Text_Areas.Set_Focus (Item.Text, Focused);
         if not Focused then
            Close_Chooser (Item);
            Close_Cycle (Item);
            Refresh_Bubbles (Item);
         end if;
         Update_Toolbar (Item);
         Invalidate (Item);
      end if;
   end Focus_Changed;

   Paragraphs_Told : constant := 24;
   --  How many paragraphs each side of the caret an assistive technology
   --  is told of, of a long text: the rest it asks for by moving.

   function First_Told (Item : Editor) return Positive;
   function Last_Told (Item : Editor) return Positive;
   --  The paragraphs told of: those near the caret.

   function First_Told (Item : Editor) return Positive is
     (if not Has_Document (Item) then 1
      else Positive'Max
             (1, Text_Areas.Caret (Item.Text).Paragraph - Paragraphs_Told));

   function Last_Told (Item : Editor) return Positive is
     (if not Has_Document (Item) then 1
      else Positive'Min
             (Docs.Count (Text_Areas.Document (Item.Text).all),
              Text_Areas.Caret (Item.Text).Paragraph + Paragraphs_Told));

   function Characters_Before
     (Doc : Docs.Document; Para : Positive; Index : Positive) return Natural;
   --  How many characters of the paragraph are before byte Index.

   function Characters_Before
     (Doc : Docs.Document; Para : Positive; Index : Positive) return Natural
   is
      Count : Natural := 0;
   begin
      if Index = 1 then
         return 0;
      end if;
      for C of Docs.Slice (Doc, Para, 1, Index) loop
         if not Texts.Is_Continuation (C) then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Characters_Before;

   function Byte_After
     (Doc : Docs.Document; Para : Positive; Characters : Natural) return Positive;
   --  The byte index that many characters into the paragraph, or its end.

   function Byte_After
     (Doc : Docs.Document; Para : Positive; Characters : Natural) return Positive
   is
      Text  : constant String := Docs.Text (Doc, Para);
      Seen  : Natural := 0;
   begin
      for Index in Text'Range loop
         if not Texts.Is_Continuation (Text (Index)) then
            if Seen = Characters then
               return Index;
            end if;
            Seen := Seen + 1;
         end if;
      end loop;
      return Text'Last + 1;
   end Byte_After;

   overriding procedure Describe
     (Item  : Editor;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind :=
           (if Has_Document (Item) and then Text_Areas.Is_Single_Line (Item.Text)
            then Semantics.Text_Input else Semantics.Multiline_Text_Input);
      end if;
      Facts.Disabled := not Item.Enabled;
      Facts.Invalid := Item.Invalid;
      Facts.Focusable := Item.Enabled and then Has_Document (Item);
      if Item.Hint_Length > 0 then
         Semantics.Help_As (Facts, Item.Hint (1 .. Item.Hint_Length));
      end if;
      if not Has_Document (Item) then
         return;
      end if;
      declare
         Doc    : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
         Anchor : constant Texts.Position := Text_Areas.Mark (Item.Text);
         Caret  : constant Texts.Position := Text_Areas.Caret (Item.Text);
         First  : constant Positive := First_Told (Item);
         Last   : constant Positive := Last_Told (Item);

         function Place_Of (At_Point : Texts.Position) return Semantics.Text_Place is
            Para : constant Positive :=
              Positive'Max (First, Positive'Min (Last, At_Point.Paragraph));
            Byte : constant Positive :=
              (if Para = At_Point.Paragraph then At_Point.Index
               elsif Para < At_Point.Paragraph
               then Docs.Byte_Length (Doc.all, Para) + 1 else 1);
         begin
            return (Part => Positive (Docs.Id (Doc.all, Para)),
                    Characters => Characters_Before (Doc.all, Para, Byte));
         end Place_Of;
      begin
         if Docs.Count (Doc.all) = 1 then
            Semantics.Value_As (Facts, Docs.Text (Doc.all, 1));
         end if;
         Facts.Has_Selection := True;
         Facts.Anchor := Place_Of (Anchor);
         Facts.Caret := Place_Of (Caret);
      end;
      Facts.Actions (Semantics.Focus) := Item.Enabled;
      Facts.Actions (Semantics.Replace_Selected_Text) := Item.Enabled;
      Facts.Actions (Semantics.Set_Value) := Item.Enabled;
      Facts.Actions (Semantics.Set_Text_Selection) := True;
   end Describe;

   overriding function Part_Count (Item : Editor) return Natural is
     (if Has_Document (Item) then Last_Told (Item) - First_Told (Item) + 1 else 0);

   overriding function Part_Number (Item : Editor; Index : Positive) return Positive is
     (Positive (Docs.Id (Text_Areas.Document (Item.Text).all, First_Told (Item) + Index - 1)));

   overriding procedure Describe_Part
     (Item   : Editor;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle)
   is
      Doc  : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
      Para : constant Natural := Docs.Find (Doc.all, Texts.Paragraph_Id (Part));
   begin
      Facts.Kind := Semantics.Text_Run;
      if Para > 0 then
         Semantics.Value_As (Facts, Docs.Text (Doc.all, Para));
      end if;
      --  Where each line is drawn is the text area's; the whole is told.
      Bounds := (Left => Left_Of (Item), Top => Top_Of (Item),
                 Right => Left_Of (Item) + Width_Of (Item),
                 Bottom => Top_Of (Item) + Height_Of (Item));
   end Describe_Part;

   overriding procedure Perform
     (Item    : in out Editor;
      Request : Semantics.Request;
      Done    : out Boolean) is
   begin
      Done := False;
      if not Has_Document (Item) or else not Item.Enabled then
         return;
      end if;
      declare
         Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
      begin
         case Request.Doing is
            when Semantics.Replace_Selected_Text =>
               Text_Areas.Insert (Item.Text, Semantics.To_String (Request.Contents));
               Invalidate (Item);
               Done := True;
            when Semantics.Set_Value =>
               Text_Areas.Select_All (Item.Text);
               Text_Areas.Insert (Item.Text, Semantics.To_String (Request.Contents));
               Invalidate (Item);
               Done := True;
            when Semantics.Set_Text_Selection =>
               declare
                  function At_Place (Part, Characters : Natural) return Texts.Position is
                     Para : constant Natural :=
                       Docs.Find (Doc.all, Texts.Paragraph_Id (Positive'Max (1, Part)));
                  begin
                     if Para = 0 then
                        return Text_Areas.Caret (Item.Text);
                     end if;
                     return (Paragraph => Para,
                             Index => Byte_After (Doc.all, Para, Characters));
                  end At_Place;
               begin
                  Text_Areas.Select_Range
                    (Item.Text,
                     At_Place (Request.Anchor_Part, Request.Anchor),
                     At_Place (Request.Focus_Part, Request.Focus));
                  Invalidate (Item);
                  Done := True;
               end;
            when others =>
               null;
         end case;
      end;
   end Perform;

   overriding procedure Command_State_Changed
     (Item : in out Editor; State : Command_State) is
   begin
      Set_Enabled (Item, State in Enabled | Ticked);
   end Command_State_Changed;

   overriding procedure Handle_Command
     (Item : in out Editor; Tag : Integer; Done : out Boolean) is
   begin
      Done := False;
      if not Has_Document (Item) or else not Item.Enabled then
         return;
      end if;
      Done := True;
      if Item.Writing and then (Tag = Edit_Undo or else Tag = Edit_Redo) then
         null;  --  the history is what the text goes back to
      elsif Tag = Edit_Undo then
         Text_Areas.Undo (Item.Text);
      elsif Tag = Edit_Redo then
         Text_Areas.Redo (Item.Text);
      elsif Tag = Edit_Cut then
         Text_Areas.Cut (Item.Text, Clipboard (Item).all);
      elsif Tag = Edit_Copy then
         Text_Areas.Copy (Item.Text, Clipboard (Item).all);
      elsif Tag = Edit_Paste then
         Text_Areas.Paste (Item.Text, Clipboard (Item).all);
      elsif Tag = Edit_Select_All then
         Text_Areas.Select_All (Item.Text);
      else
         Done := False;
      end if;
      if Done then
         Invalidate (Item);
      end if;
   end Handle_Command;

end Pomarine.Widgets.Editors;
