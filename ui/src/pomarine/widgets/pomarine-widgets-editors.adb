with System;
with CoreText.Fonts;
with Texts;
with Pomarine.Widgets.Editors.Accessibility;
with Pomarine.Widgets.Editors.Choosers;
with Pomarine.Widgets.Editors.Links;
with Pomarine.Widgets.Editors.Metrics;
with Pomarine.Widgets.Editors.Toolbars;
with Pomarine.Widgets.Editors.Versions;
package body Pomarine.Widgets.Editors is

   function Document (Item : Editor) return not null access constant Texts.Documents.Document is
     (Text_Areas.Document (Item.Text));

   function Highlight_Count (Item : Editor) return Natural is
     (Text_Areas.Highlight_Count (Item.Text));

   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;

   package Docs renames Texts.Documents;

   Icon_Size : constant Float := 12.0;
   Icon_Room : constant Float := 18.0;
   --  In points: of the icon before a single line, and the room it is in.

   use type Docs.Version;
   use type Texts.Position;
   use type System.Address;

   use Pomarine.Widgets.Editors.Choosers;
   use Pomarine.Widgets.Editors.Links;
   use Pomarine.Widgets.Editors.Metrics;
   use Pomarine.Widgets.Editors.Toolbars;
   use Pomarine.Widgets.Editors.Versions;

   procedure Begin_Link (Item : in out Editor) renames Links.Ask;
   procedure Finish_Link (Item : in out Editor; Keep : Boolean) renames Links.Finish;
   procedure Choose_Link (Item : in out Editor; Which : Positive) renames Links.Choose;
   procedure Set_Link_Address (Item : in out Editor; To : String) renames Links.Set_Address;
   function Link_Address (Item : Editor) return String renames Links.Field_Address;
   procedure Begin_Version (Item : in out Editor) renames Versions.Begin_Writing;
   procedure Finish_Version (Item : in out Editor; Keep : Boolean) renames Versions.Finish_Writing;

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

   function Can_Edit (Item : Editor) return Boolean is
     (Has_Document (Item) and then not Text_Areas.Is_Read_Only (Item.Text)
      and then not Text_Areas.Is_Composing (Item.Text));

   function Area (Item : in out Editor)
      return not null access Pomarine.Text_Areas.Text_Area is
     (Item.Text'Unchecked_Access);

   function Tool_Count (Item : Editor) return Natural is (Item.Tool_Total);

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

   function Followed (Item : Editor) return String is (Ada.Strings.Unbounded.To_String (Item.Followed_To));

   function Is_Writing_Version (Item : Editor) return Boolean is (Item.Writing);

   function Is_Linking (Item : Editor) return Boolean is (Item.Linking);

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
               if Self.Linking and then Links.Link_Acceptable (Self) then
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
                     Post (Self, Self.Tool_Hook, Value => Tool);
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
              and then Source'Address = Self.Link_Parts.Field'Address and then Links.Link_Acceptable (Self)
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
            Post (Item, Item.Follow_Hook);
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
                  Post (Item, Item.Tool_Hook, Value => Tool);
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
            Text_Areas.Clear_Return (Item.Text);
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

   overriding function Is_Focusable (Item : Editor) return Boolean is
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

   overriding procedure Describe
     (Item  : Editor;
      Facts : in out Semantics.Description) is
   begin
      Accessibility.Describe_Editor (Item, Facts);
   end Describe;

   overriding function Part_Count (Item : Editor) return Natural is (Accessibility.Count_Parts (Item));

   overriding function Part_Number (Item : Editor; Index : Positive) return Positive is
     (Accessibility.Number_Of_Part (Item, Index));

   overriding procedure Describe_Part
     (Item   : Editor;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle) is
   begin
      Accessibility.Describe_Piece (Item, Part, Facts, Bounds);
   end Describe_Part;

   overriding procedure Perform
     (Item    : in out Editor;
      Request : Semantics.Request;
      Done    : out Boolean) is
   begin
      Accessibility.Perform_Request (Item, Request, Done);
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
