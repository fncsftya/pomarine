with CoreText.Fonts;
with Yoga.Nodes;
with Pomarine.Widgets.Editors.Metrics;

package body Pomarine.Widgets.Editors.Choosers is

   use type Texts.Paragraph_Kind;

   use Pomarine.Widgets.Editors.Metrics;

   procedure Mark_Open (Item : in out Editor; Which : Choice; On : Boolean) is
   begin
      case Which is
         when Pick_Family =>
            Selects.Set_Open (Item.Family_Box, On);

         when Pick_Size   =>
            Selects.Set_Open (Item.Size_Box, On);

         when Pick_Style  =>
            Selects.Set_Open (Item.Style_Box, On);

         when Pick_Source =>
            Selects.Set_Open (Item.Link_Sources, On);

         when Nothing     =>
            null;
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
        (case Which is
           when Pick_Family => Font_Left,
           when Pick_Size   => Size_Left,
           when Pick_Source => Float (Item.Link_Left) / Pixels,
           when others      => Style_Left);
      Wide   : constant Float :=
        (case Which is
           when Pick_Family => Family_Wide,
           when Pick_Size   => Size_Wide,
           when Pick_Source => Link_Wide - 2.0 * Bubble_Pad,
           when others      => Style_Wide);
      Top    : Float := Toolbar_Top + Button_High + Tip_Gap;
      Rows   : Menus.Row_Vectors.Vector;
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
      case Which is
         when Pick_Family =>
            declare
               Names : constant CoreText.Fonts.Family_Vectors.Vector := CoreText.Fonts.Families;
            begin
               for Name of Names loop
                  Rows.Append (Menus.Describe_Row (Menus.Check, Name, Checked => Name = Family_Shown (Item)));
               end loop;
            end;

         when Pick_Size   =>
            for Points of Sizes loop
               Rows.Append
                 (Menus.Describe_Row
                    (Menus.Check, Size_Text (Float (Points)), Checked => Float (Points) = Size_Shown (Item)));
            end loop;

         when Pick_Source =>
            for Title of Item.Link_Titles loop
               Rows.Append (Menus.Describe_Row (Menus.Check, Ada.Strings.Unbounded.To_String (Title)));
            end loop;

         when others      =>
            for Kind in Texts.Paragraph_Kind range 0 .. 3 loop
               Rows.Append
                 (Menus.Describe_Row
                    (Menus.Check, Style_Name (Kind), Checked => Kind = Text_Areas.Paragraph_Style (Item.Text)));
            end loop;
      end case;
      Menus.Set_Rows (Item.Chooser, Rows);
      Menus.Set_Faced (Item.Chooser, Which = Pick_Family);
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

end Pomarine.Widgets.Editors.Choosers;
