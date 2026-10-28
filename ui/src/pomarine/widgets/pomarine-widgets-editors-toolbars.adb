with Ada.Characters.Handling;
with Yoga.Nodes;
with Pomarine.Widgets.Editors.Metrics;
with Pomarine.Widgets.Editors.Choosers;

package body Pomarine.Widgets.Editors.Toolbars is

   package Docs renames Texts.Documents;

   use type Pomarine.Events.Key_Code;

   use Pomarine.Widgets.Editors.Metrics;
   use Pomarine.Widgets.Editors.Choosers;

   function Tip_Text (Item : Editor; Tool : Tool_Number) return String
   is (Buttons.Label (Item.Tools (Tool))
       & (if Item.Keys (Tool) = ASCII.NUL
          then ""
          else "  " & Command_Mark & Ada.Characters.Handling.To_Upper (Item.Keys (Tool))));

   function Tool_For_Key (Item : Editor; Key : Pomarine.Events.Key_Code) return Natural is
   begin
      for Tool in 1 .. Item.Tool_Total loop
         if Item.Keys (Tool) /= ASCII.NUL and then Key = Pomarine.Events.Key_Code (Character'Pos (Item.Keys (Tool)))
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
               Yoga.Nodes.Set_Position (Node (Item.Tip), Yoga.Left, Item.Tool_Left_At (Which) * Pixels);
               Yoga.Nodes.Set_Position
                 (Node (Item.Tip), Yoga.Top, (Item.Tool_Top_At (Which) + Button_High + Tip_Gap) * Pixels);
               Yoga.Nodes.Set_Width (Node (Item.Tip), Float'Rounding (Tooltips.Natural_Width (Item.Tip) * Pixels));
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

   function Toolbar_Wanted (Item : Editor) return Boolean
   is (Has_Document (Item)
       and then Is_Attached (Item)
       and then Item.Enabled
       and then Text_Areas.Has_Toolbar (Item.Text));

   Bullet_Label : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A2#)];
   Quote_Label  : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#9C#)];
   Arrow_Left   : constant String := [Character'Val (16#E2#), Character'Val (16#86#), Character'Val (16#90#)];
   Arrow_Right  : constant String := [Character'Val (16#E2#), Character'Val (16#86#), Character'Val (16#92#)];
   More_Label   : constant String := [Character'Val (16#E2#), Character'Val (16#80#), Character'Val (16#A6#)];
   Arrow_Out    : constant String := [Character'Val (16#E2#), Character'Val (16#86#), Character'Val (16#97#)];
   --  U+2022, U+201C, U+2190, U+2192 and U+2197 in UTF-8; and U+2026, the ellipsis, for the button of the rest.

   procedure Place_Select
     (Item : in out Editor; Which : Choice; Part : in out Selects.Select_Field; Name : String; Left, Wide : Float)
   is
      Pixels : constant Float := Density (Item);
   begin
      if not Is_Attached (Part) then
         Set_Accessible_Name (Part, Name);
         Set_Listener (Part, Item'Unchecked_Access);
         Add (Item, Part);
      end if;
      Item.Select_Left (Which) := Left;
      Item.Select_Top (Which) := Toolbar_Top;
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
                 (Part,
                  (case Style is
                     when Docs.Bold          => "B",
                     when Docs.Italic        => "I",
                     when Docs.Underline     => "U",
                     when Docs.Strikethrough => "S",
                     when Docs.Faded         => "F",
                     when Docs.Sized         => "Z",
                     when Docs.Faced         => "Y",
                     when Docs.Linked        => "L",
                     when Docs.Versioned     => "V"));
               Buttons.Set_Label_Style
                 (Part,
                  (case Style is
                     when Docs.Bold   => Line_Texts.Serif_Bold,
                     when Docs.Italic => Line_Texts.Serif_Italic,
                     when others      => Line_Texts.Serif_Label),
                  Underlined => Style = Docs.Underline,
                  Struck     => Style = Docs.Strikethrough);
               Set_Accessible_Name
                 (Part,
                  (case Style is
                     when Docs.Bold          => "Bold",
                     when Docs.Italic        => "Italic",
                     when Docs.Underline     => "Underline",
                     when Docs.Strikethrough => "Strikethrough",
                     when Docs.Faded         => "Faded",
                     when Docs.Sized         => "Size",
                     when Docs.Faced         => "Family",
                     when Docs.Linked        => "Link",
                     when Docs.Versioned     => "Versions"));
               Buttons.Set_Enabled (Part, True);
               Set_Listener (Part, Item'Unchecked_Access);
               Add (Item, Part);
            end if;
            Yoga.Nodes.Set_Position_Type (Node (Part), Yoga.Absolute);
            Yoga.Nodes.Set_Position
              (Node (Part), Yoga.Left, (Toolbar_Left + Float (Place) * (Button_Wide + Button_Gap)) * Pixels);
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
                 (Part,
                  (case Action is
                     when Bulleted => Bullet_Label,
                     when Numbered => "1.",
                     when Quoted   => Quote_Label,
                     when Outdent  => Arrow_Left,
                     when Indent   => Arrow_Right,
                     when Link     => Arrow_Out));
               Set_Accessible_Name
                 (Part,
                  (case Action is
                     when Bulleted => "Bulleted list",
                     when Numbered => "Numbered list",
                     when Quoted   => "Quotation",
                     when Outdent  => "Decrease indent",
                     when Indent   => "Increase indent",
                     when Link     => "Link"));
               Buttons.Set_Enabled (Part, True);
               Set_Listener (Part, Item'Unchecked_Access);
               Add (Item, Part);
            end if;
            Yoga.Nodes.Set_Position_Type (Node (Part), Yoga.Absolute);
            Yoga.Nodes.Set_Position
              (Node (Part),
               Yoga.Left,
               (Edit_Left + Float (Edit_Action'Pos (Action)) * (Button_Wide + Button_Gap)) * Pixels);
            Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, Toolbar_Top * Pixels);
            Yoga.Nodes.Set_Width (Node (Part), Button_Wide * Pixels);
            Yoga.Nodes.Set_Height (Node (Part), Button_High * Pixels);
         end;
      end loop;
      Place_Select (Item, Pick_Family, Item.Family_Box, "Font family", Font_Left, Family_Wide);
      Selects.Set_Faced (Item.Family_Box, True);
      Place_Select (Item, Pick_Size, Item.Size_Box, "Font size", Size_Left, Size_Wide);
      Place_Select (Item, Pick_Style, Item.Style_Box, "Paragraph style", Style_Left, Style_Wide);
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
            Item.Tool_Left_At (Tool) := Tool_Left (Tool);
            Item.Tool_Top_At (Tool) := Toolbar_Top;
            Yoga.Nodes.Set_Position (Node (Part), Yoga.Left, Tool_Left (Tool) * Pixels);
            Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, Toolbar_Top * Pixels);
            Yoga.Nodes.Set_Width (Node (Part), Tool_Wide * Pixels);
            Yoga.Nodes.Set_Height (Node (Part), Button_High * Pixels);
         end;
      end loop;
      if not Is_Attached (Item.More_Button) then
         Buttons.Set_Label (Item.More_Button, More_Label);
         Set_Accessible_Name (Item.More_Button, "More formatting");
         Buttons.Set_Enabled (Item.More_Button, True);
         Set_Listener (Item.More_Button, Item'Unchecked_Access);
         Add (Item, Item.More_Button);
         Set_Visible (Item.More_Button, False);
         Yoga.Nodes.Set_Position_Type (Node (Item.More_Button), Yoga.Absolute);
         Yoga.Nodes.Set_Position (Node (Item.More_Button), Yoga.Top, Toolbar_Top * Pixels);
         Yoga.Nodes.Set_Width (Node (Item.More_Button), Button_Wide * Pixels);
         Yoga.Nodes.Set_Height (Node (Item.More_Button), Button_High * Pixels);
      end if;
      Request_Layout (Item);
   end Build_Toolbar;

   procedure Layout_More (Item : in out Editor; Edits_In, Fonts_In, Tools_In : Boolean; Wide : Float) is
      --  Put what the toolbar has not the width for in rows of the popover, under the button of the rest, at its right.
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := 4.0;

      Edits_Row    : constant Float := 6.0 * Button_Wide + 5.0 * Button_Gap;
      Fonts_Row    : constant Float := Family_Wide + Size_Wide + Style_Wide + 2.0 * Button_Gap;
      Tools_Row    : constant Float := Float (Item.Tool_Total) * (Tool_Wide + Button_Gap) - Button_Gap;
      Natural_Wide : constant Float :=
        Float'Max
          ((if Edits_In then 0.0 else Edits_Row),
           Float'Max ((if Fonts_In then 0.0 else Fonts_Row), (if Tools_In then 0.0 else Tools_Row)))
        + 2.0 * Bubble_Pad;
      Panel_Wide   : constant Float := Float'Max (Button_Wide, Float'Min (Natural_Wide, Wide - 2.0 * Edge));
      Panel_Left   : constant Float := Float'Max (Edge, Wide - Panel_Wide - Edge);
      Panel_Top    : constant Float := Toolbar_Top + Button_High + Tip_Gap;

      X : Float := Bubble_Pad;
      Y : Float := Bubble_Pad;

      procedure Next_Row is
      begin
         X := Bubble_Pad;
         Y := Y + Button_High + Bubble_Pad;
      end Next_Row;

      procedure Put_Spot (Part : in out Widget'Class; Part_Wide : Float; Left, Top : out Float) is
      begin
         if X > Bubble_Pad and then X + Part_Wide > Panel_Wide - Bubble_Pad then
            Next_Row;
         end if;
         Left := Panel_Left + X;
         Top := Panel_Top + Y;
         Yoga.Nodes.Set_Position (Node (Part), Yoga.Left, Left * Pixels);
         Yoga.Nodes.Set_Position (Node (Part), Yoga.Top, Top * Pixels);
         X := X + Part_Wide + Button_Gap;
         Raise_To_Front (Part);
      end Put_Spot;

      Left, Top : Float;
   begin
      if not Is_Attached (Item.More_Panel) then
         Shape_Bubble (Item, Item.More_Panel, Panel_Wide);
      end if;
      Raise_To_Front (Item.More_Panel);
      if not Edits_In then
         for Action in Edit_Action loop
            Put_Spot (Item.Editing (Action), Button_Wide, Left, Top);
         end loop;
         Next_Row;
      end if;
      if not Fonts_In then
         Put_Spot (Item.Family_Box, Family_Wide, Item.Select_Left (Pick_Family), Item.Select_Top (Pick_Family));
         Put_Spot (Item.Size_Box, Size_Wide, Item.Select_Left (Pick_Size), Item.Select_Top (Pick_Size));
         Put_Spot (Item.Style_Box, Style_Wide, Item.Select_Left (Pick_Style), Item.Select_Top (Pick_Style));
         Next_Row;
      end if;
      if not Tools_In then
         for Tool in 1 .. Item.Tool_Total loop
            Put_Spot (Item.Tools (Tool), Tool_Wide, Item.Tool_Left_At (Tool), Item.Tool_Top_At (Tool));
         end loop;
         Next_Row;
      end if;
      Yoga.Nodes.Set_Position (Node (Item.More_Panel), Yoga.Left, Panel_Left * Pixels);
      Yoga.Nodes.Set_Position (Node (Item.More_Panel), Yoga.Top, Panel_Top * Pixels);
      Yoga.Nodes.Set_Width (Node (Item.More_Panel), Panel_Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Item.More_Panel), Y * Pixels);
      Yoga.Nodes.Set_Position
        (Node (Item.More_Button),
         Yoga.Left,
         Float'Max
           (Toolbar_Left + Float (Toolbar_Order'Length) * (Button_Wide + Button_Gap), Wide - Toolbar_Left - Button_Wide)
         * Pixels);
   end Layout_More;

   procedure Refresh_Toolbar (Item : in out Editor) is
   begin
      if Item.Toolbar_Shown then
         for Style of Toolbar_Order loop
            Buttons.Set_Selected (Item.Toolbar (Style), Text_Areas.Format_Active (Item.Text, Style));
         end loop;
         declare
            Wide     : constant Float := Width_Of (Item) / Density (Item);
            All_Fit  : constant Boolean := Wide >= Tools_End (Item) + Toolbar_Left;
            Limit    : constant Float := Wide - Toolbar_Left - Button_Wide - Divider_Gap;
            --  What is left of the toolbar once the button of the rest has its place.
            Edits_In : constant Boolean := All_Fit or else Edit_End <= Limit;
            Fonts_In : constant Boolean := All_Fit or else Font_End <= Limit;
            Tools_In : constant Boolean := Item.Tool_Total = 0 or else All_Fit or else Tools_End (Item) <= Limit;
            Spilled  : constant Boolean := not (Edits_In and Fonts_In and Tools_In);
            Opened   : constant Boolean := Item.More_Open and then Spilled;
            Key      : constant Integer :=
              (if Spilled then Integer (Wide) else 0)
              * 16
              + (if Edits_In then 1 else 0)
              + (if Fonts_In then 2 else 0)
              + (if Tools_In then 4 else 0)
              + (if Opened then 8 else 0);

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
            if Item.More_Open /= Opened then
               Item.More_Open := Opened;
               Close_Chooser (Item);
            end if;
            if Key /= Item.More_Key then
               Item.More_Key := Key;
               Build_Toolbar (Item);
               if Spilled then
                  Layout_More (Item, Edits_In, Fonts_In, Tools_In, Wide);
               end if;
            end if;
            Show (Item.More_Button, Spilled);
            Buttons.Set_Selected (Item.More_Button, Opened);
            if Is_Attached (Item.More_Panel) then
               Show (Item.More_Panel, Opened);
            end if;
            for Action in Edit_Action loop
               Show (Item.Editing (Action), Edits_In or else Opened);
            end loop;
            if Has_Document (Item) then
               for Action in Bulleted .. Quoted loop
                  Buttons.Set_Selected
                    (Item.Editing (Action),
                     Text_Areas.Block_Active
                       (Item.Text,
                        (case Action is
                           when Bulleted => Text_Areas.Bullets,
                           when Numbered => Text_Areas.Numbers,
                           when others   => Text_Areas.Quote)));
               end loop;
               Say (Item.Style_Box, Style_Name (Text_Areas.Paragraph_Style (Item.Text)));
               Buttons.Set_Enabled
                 (Item.Editing (Link),
                  Text_Areas.Has_Selection (Item.Text) and then not Text_Areas.Is_Read_Only (Item.Text));
               Buttons.Set_Selected (Item.Editing (Link), Text_Areas.Link_Here (Item.Text) /= "");
            end if;
            Show (Item.Family_Box, Fonts_In or else Opened);
            Show (Item.Size_Box, Fonts_In or else Opened);
            Show (Item.Style_Box, Fonts_In or else Opened);
            if Item.Choosing in Pick_Family .. Pick_Style and then not Is_Visible (Item.Family_Box) then
               Close_Chooser (Item);
            end if;
            if Has_Document (Item) then
               Say (Item.Family_Box, Family_Shown (Item));
               Say (Item.Size_Box, Size_Text (Size_Shown (Item)));
            end if;
            for Tool in 1 .. Item.Tool_Total loop
               Buttons.Set_Enabled
                 (Item.Tools (Tool), not Item.Selective (Tool) or else Text_Areas.Has_Selection (Item.Text));
               Show (Item.Tools (Tool), Tools_In or else Opened);
            end loop;
         end;
      end if;
   end Refresh_Toolbar;

   procedure Toggle_More (Item : in out Editor) is
   begin
      Item.More_Open := not Item.More_Open;
      Item.More_Key := -1;
      Close_Chooser (Item);
      Refresh_Toolbar (Item);
      Invalidate (Item);
   end Toggle_More;

   procedure Close_More (Item : in out Editor) is
   begin
      if Item.More_Open then
         Item.More_Open := False;
         Item.More_Key := -1;
         Close_Chooser (Item);
         Refresh_Toolbar (Item);
         Invalidate (Item);
      end if;
   end Close_More;

   function Over_More (Item : Editor) return Boolean
   is (Item.More_Open
       and then (Is_Hovered (Item.More_Button)
                 or else Is_Hovered (Item.More_Panel)
                 or else Is_Hovered (Item.Chooser)
                 or else (for some Action in Edit_Action => Is_Hovered (Item.Editing (Action)))
                 or else Is_Hovered (Item.Family_Box)
                 or else Is_Hovered (Item.Size_Box)
                 or else Is_Hovered (Item.Style_Box)
                 or else (for some Tool in 1 .. Item.Tool_Total => Is_Hovered (Item.Tools (Tool)))));

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
            Item.More_Open := False;
            Item.More_Key := -1;
            Set_Visible (Item.More_Button, False);
            if Is_Attached (Item.More_Panel) then
               Set_Visible (Item.More_Panel, False);
            end if;
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

end Pomarine.Widgets.Editors.Toolbars;
