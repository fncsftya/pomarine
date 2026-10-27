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
               Yoga.Nodes.Set_Position (Node (Item.Tip), Yoga.Left, Tool_Left (Which) * Pixels);
               Yoga.Nodes.Set_Position (Node (Item.Tip), Yoga.Top, (Toolbar_Top + Button_High + Tip_Gap) * Pixels);
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
   Arrow_Out    : constant String := [Character'Val (16#E2#), Character'Val (16#86#), Character'Val (16#97#)];
   --  U+2022, U+201C, U+2190, U+2192 and U+2197 in UTF-8.

   procedure Place_Select (Item : in out Editor; Part : in out Selects.Select_Field; Name : String; Left, Wide : Float)
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
            Reserved  : constant Float := Toolbar_Left;
            Fits      : constant Boolean := Width_Of (Item) >= (Tools_End (Item) + Reserved) * Density (Item);
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

end Pomarine.Widgets.Editors.Toolbars;
