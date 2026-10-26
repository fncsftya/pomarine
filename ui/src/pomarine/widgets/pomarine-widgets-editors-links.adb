with Yoga.Nodes;
with Pomarine.Icons;
with Pomarine.Widgets.Editors.Metrics;
with Pomarine.Widgets.Editors.Choosers;
with Pomarine.Widgets.Editors.Toolbars;
package body Pomarine.Widgets.Editors.Links is

   package Docs renames Texts.Documents;

   use type Texts.Position;
   use type Text_Areas.Shared_Access;

   use Pomarine.Widgets.Editors.Metrics;
   use Pomarine.Widgets.Editors.Choosers;
   use Pomarine.Widgets.Editors.Toolbars;

   function Address_Of (Words : String) return String is
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

   function Field_Address (Item : Editor) return String is
     (if Item.Link_Parts = null then "" else Docs.Whole (Item.Link_Parts.Doc));

   function Link_Acceptable (Item : Editor) return Boolean is
     (Address_Of (Field_Address (Item)) /= "" or else (Item.Link_Had and then Trimmed (Field_Address (Item)) = ""));

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

   procedure Set_Address (Item : in out Editor; To : String) is
   begin
      Text_Areas.Select_All (Item.Link_Parts.Field.Text);
      Text_Areas.Insert (Item.Link_Parts.Field.Text, To);
      Text_Areas.Select_All (Item.Link_Parts.Field.Text);
      Invalidate (Item.Link_Parts.Field);
      Refresh_Link (Item);
   end Set_Address;

   procedure Ask (Item : in out Editor) is
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
      Item.Cycle_Open := False;
      Close_Chooser (Item);
      Item.Link_From := First;
      Item.Link_To := Last;
      Item.Link_Had := Text_Areas.Link_Here (Item.Text) /= "";
      Build_Link (Item);
      Item.Link_Titles.Clear;
      Item.Link_Addresses.Clear;
      Item.Linking := True;
      Set_Address (Item, Text_Areas.Link_Here (Item.Text));
      Refresh_Link (Item);
      Focus (Item.Link_Parts.Field);
      Post (Item, Item.Link_Hook);
      Invalidate (Item);
   end Ask;

   procedure Choose (Item : in out Editor; Which : Positive) is
   begin
      Set_Address (Item, Ada.Strings.Unbounded.To_String (Item.Link_Addresses (Which)));
      Finish (Item, True);
   end Choose;

   procedure Finish (Item : in out Editor; Keep : Boolean) is
      Wanted : constant String := Address_Of (Field_Address (Item));
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
   end Finish;

end Pomarine.Widgets.Editors.Links;
