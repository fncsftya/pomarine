with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with System;
with Texts;
with Yoga.Nodes;
package body Pomarine.Widgets.Editors is

   function Document (Item : Editor) return not null access constant Texts.Documents.Document is
     (Text_Areas.Document (Item.Text));

   function Highlight_Count (Item : Editor) return Natural is
     (Text_Areas.Highlight_Count (Item.Text));

   use type Semantics.Role;
   use type SDL3.Events.Event_Kind;
   use type SDL3.Events.Key_Code;

   package Docs renames Texts.Documents;

   Icon_Size : constant Float := 12.0;
   Icon_Room : constant Float := 18.0;
   --  In points: of the icon before a single line, and the room it is in.

   use type Docs.Version;
   use type Texts.Position;
   use type System.Address;

   procedure Update_Toolbar (Item : in out Editor);
   --  Show the toolbar's buttons if it is to have them, and hide them if not.

   function Tool_For_Key (Item : Editor; Key : SDL3.Events.Key_Code) return Natural;
   --  The number of the tool whose key it is; 0 if none.

   procedure Refresh_Tip (Item : in out Editor);
   --  Show the tooltip of the tool button the pointer is over, if any.

   procedure Refresh_Assist (Item : in out Editor);
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
   end Configure;

   function Is_Configured (Item : Editor) return Boolean is
     (Text_Areas.Is_Configured (Item.Text));

   procedure Set_Shared
     (Item   : in out Editor;
      Shared : not null Shared_Access) is
   begin
      Text_Areas.Set_Shared (Item.Text, Shared);
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
   Tools_Left    : constant Float :=
     Toolbar_Left + 4.0 * Button_Wide + 3.0 * Button_Gap + Divider_Gap + 1.0 + Divider_Gap;
   --  In points: the divider is Divider_Gap after the style buttons, and
   --  the tool buttons Divider_Gap after it.

   function Tool_Left (Tool : Tool_Number) return Float is
     (Tools_Left + Float (Tool - 1) * (Tool_Wide + Button_Gap));

   function Tools_End (Item : Editor) return Float is
     (if Item.Tool_Total = 0 then Toolbar_Left + 4.0 * Button_Wide + 3.0 * Button_Gap
      else Tool_Left (Item.Tool_Total) + Tool_Wide);

   Assist_Wide  : constant Float := 96.0;
   Assist_Right : constant Float := 12.0;
   --  In points: of the assist button, and from it to the right edge.

   Tip_Gap       : constant Float := 4.0;
   --  In points, between a tool button and its tooltip.

   function Tip_Text (Item : Editor; Tool : Tool_Number) return String is
     (Buttons.Label (Item.Tools (Tool))
      & (if Item.Keys (Tool) = ASCII.NUL then ""
         else "  " & Command_Mark & Ada.Characters.Handling.To_Upper (Item.Keys (Tool))));

   function Tool_Count (Item : Editor) return Natural is (Item.Tool_Total);

   function Tool_For_Key (Item : Editor; Key : SDL3.Events.Key_Code) return Natural is
   begin
      for Tool in 1 .. Item.Tool_Total loop
         if Item.Keys (Tool) /= ASCII.NUL
           and then Key = SDL3.Events.Key_Code (Character'Pos (Item.Keys (Tool)))
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
                            when Docs.Faded => "F", when Docs.Versioned => "V"));
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
                            when Docs.Faded => "Faded", when Docs.Versioned => "Versions"));
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
         --  The tools, with the assist button after them, if there is room for both; if not,
         --  the assist button has it.
         declare
            Reserved : constant Float :=
              (if Item.Assist_Length > 0 then 8.0 + Assist_Wide + Assist_Right else Toolbar_Left);
            Fits     : constant Boolean := Width_Of (Item) >= (Tools_End (Item) + Reserved) * Density (Item);
         begin
            for Tool in 1 .. Item.Tool_Total loop
               Buttons.Set_Enabled
                 (Item.Tools (Tool), not Item.Selective (Tool) or else Text_Areas.Has_Selection (Item.Text));
               if Is_Visible (Item.Tools (Tool)) /= Fits then
                  Set_Visible (Item.Tools (Tool), Fits);
               end if;
            end loop;
         end;
      end if;
      Refresh_Assist (Item);
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

   Assist_Room  : constant Float :=
     Toolbar_Left + 4.0 * Button_Wide + 3.0 * Button_Gap + 8.0 + Assist_Wide + Assist_Right;
   --  In points: how wide the text area is to be, for the button to have
   --  room beside the style buttons.

   function Has_Words (Doc : Docs.Document) return Boolean is
   begin
      for Para in 1 .. Docs.Count (Doc) loop
         if (for some C of Docs.Text (Doc, Para) => C > ' ') then
            return True;
         end if;
      end loop;
      return False;
   end Has_Words;

   procedure Refresh_Assist (Item : in out Editor) is
   begin
      if Item.Assist_Length = 0 or else not Has_Document (Item) then
         if Is_Attached (Item.Assist) and then Is_Visible (Item.Assist) then
            Set_Visible (Item.Assist, False);
         end if;
         return;
      end if;
      declare
         Doc    : constant not null access constant Docs.Document := Document (Item);
         Wanted : constant Boolean :=
           Item.Toolbar_Shown and then Width_Of (Item) >= Assist_Room * Density (Item);
         Filled : Boolean;
      begin
         if Docs.Current (Doc.all) /= Item.Assist_Version or else Docs.Serial (Doc.all) /= Item.Assist_Serial then
            Item.Assist_Version := Docs.Current (Doc.all);
            Item.Assist_Serial := Docs.Serial (Doc.all);
            Item.Assist_Filled := Has_Words (Doc.all);
         end if;
         Filled := Item.Assist_Filled;
         if Wanted and then not Is_Attached (Item.Assist) then
            declare
               Pixels : constant Float := Density (Item);
               Label  : constant String := Item.Assist_Text (1 .. Item.Assist_Length);
            begin
               Buttons.Set_Kind (Item.Assist, Buttons.AI);
               Buttons.Set_Label (Item.Assist, Label);
               Set_Accessible_Name (Item.Assist, Label);
               Set_Listener (Item.Assist, Item'Unchecked_Access);
               Add (Item, Item.Assist);
               Yoga.Nodes.Set_Position_Type (Node (Item.Assist), Yoga.Absolute);
               Yoga.Nodes.Set_Position (Node (Item.Assist), Yoga.Right, Assist_Right * Pixels);
               Yoga.Nodes.Set_Position (Node (Item.Assist), Yoga.Top, Toolbar_Top * Pixels);
               Yoga.Nodes.Set_Width (Node (Item.Assist), Assist_Wide * Pixels);
               Yoga.Nodes.Set_Height (Node (Item.Assist), Button_High * Pixels);
               Request_Layout (Item);
            end;
         end if;
         if Is_Attached (Item.Assist) then
            if Is_Visible (Item.Assist) /= Wanted then
               Set_Visible (Item.Assist, Wanted);
            end if;
            if Buttons.Is_Enabled (Item.Assist) /= (Item.Assist_Allowed and then Filled) then
               Buttons.Set_Enabled (Item.Assist, Item.Assist_Allowed and then Filled);
            end if;
         end if;
      end;
   end Refresh_Assist;

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

   procedure Set_Assist (Item : in out Editor; Label : String) is
   begin
      Item.Assist_Length := Label'Length;
      Item.Assist_Text (1 .. Label'Length) := Label;
      if Is_Attached (Item.Assist) then
         Buttons.Set_Label (Item.Assist, Label);
         Set_Accessible_Name (Item.Assist, Label);
      end if;
      Refresh_Assist (Item);
   end Set_Assist;

   function Assist_Label (Item : Editor) return String is (Item.Assist_Text (1 .. Item.Assist_Length));

   procedure Set_Assist_Allowed (Item : in out Editor; To : Boolean) is
   begin
      Item.Assist_Allowed := To;
      Refresh_Assist (Item);
   end Set_Assist_Allowed;

   function Assist_Is_Allowed (Item : Editor) return Boolean is (Item.Assist_Allowed);

   procedure Assist_Center (Item : Editor; Shown : out Boolean; X, Y : out Float) is
   begin
      Shown := Is_Attached (Item.Assist) and then Is_Visible (Item.Assist);
      X := (if Shown then Left_Of (Item.Assist) + Width_Of (Item.Assist) / 2.0 else 0.0);
      Y := (if Shown then Top_Of (Item.Assist) + Height_Of (Item.Assist) / 2.0 else 0.0);
   end Assist_Center;

   function Assist_Is_Enabled (Item : Editor) return Boolean is
     (Item.Assist_Allowed and then Item.Assist_Filled and then Item.Assist_Length > 0);

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

   procedure Build_Bubbles (Item : in out Editor) is
      Pixels : constant Float := Density (Item);

      procedure Shape (Bubble : in out Panels.Panel; Wide : Float) is
      begin
         Panels.Set_Fill (Bubble, Themes.Page);
         Panels.Set_Border (Bubble, Themes.Border);
         Panels.Set_Radius (Bubble, 6.0);
         Add (Item, Bubble);
         Yoga.Nodes.Set_Position_Type (Node (Bubble), Yoga.Absolute);
         Yoga.Nodes.Set_Width (Node (Bubble), Wide * Pixels);
         Yoga.Nodes.Set_Height (Node (Bubble), Bubble_High * Pixels);
         Set_Visible (Bubble, False);
      end Shape;

      procedure Put
        (Bubble : in out Panels.Panel; Part : in out Buttons.Button; Left, Wide : Float; Label, Name : String) is
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
      end Put;
   begin
      if Is_Attached (Item.Confirm) then
         return;
      end if;
      Shape (Item.Confirm, Confirm_Wide);
      Put (Item.Confirm, Item.Accept_Button, Bubble_Pad, Button_Wide, "OK", "Accept");
      Buttons.Set_Kind (Item.Accept_Button, Buttons.Primary);
      Buttons.Set_Icon (Item.Accept_Button, Pomarine.Icons.Check);
      Put (Item.Confirm, Item.Cancel_Button, 2.0 * Bubble_Pad + Button_Wide, Button_Wide, "X", "Cancel");
      Buttons.Set_Icon (Item.Cancel_Button, Pomarine.Icons.Close);
      Shape (Item.Cycle, Cycle_Wide);
      Put (Item.Cycle, Item.Back_Button, Bubble_Pad, Button_Wide, "<", "Previous version");
      Add (Item.Cycle, Item.Cycle_Count);
      Labels.Set_Centered (Item.Cycle_Count, True);
      Yoga.Nodes.Set_Position_Type (Node (Item.Cycle_Count), Yoga.Absolute);
      Yoga.Nodes.Set_Position (Node (Item.Cycle_Count), Yoga.Left, (2.0 * Bubble_Pad + Button_Wide) * Pixels);
      Yoga.Nodes.Set_Position (Node (Item.Cycle_Count), Yoga.Top, (Bubble_High - Button_High) / 2.0 * Pixels);
      Yoga.Nodes.Set_Width (Node (Item.Cycle_Count), Count_Wide * Pixels);
      Yoga.Nodes.Set_Height (Node (Item.Cycle_Count), Button_High * Pixels);
      Put (Item.Cycle, Item.Next_Button, 3.0 * Bubble_Pad + Button_Wide + Count_Wide, Button_Wide, ">",
           "Next version");
      Request_Layout (Item);
   end Build_Bubbles;

   procedure Place_Bubble
     (Item : in out Editor; Bubble : in out Panels.Panel; Wide : Float; X, Top, Bottom : Float;
      Left_Kept, Top_Kept : in out Integer)
   is
      --  Under the caret, or over it if there is no room under it in the window.
      Pixels : constant Float := Density (Item);
      Edge   : constant Float := 4.0 * Pixels;
      Left   : constant Float :=
        Float'Max (Edge, Float'Min (X - Left_Of (Item), Width_Of (Item) - Wide * Pixels - Edge));
      Below  : constant Float := Bottom + Bubble_Gap * Pixels;
      Upper  : constant Boolean := Below + Bubble_High * Pixels > Window_Height (Item);
      Put_Top : constant Float :=
        (if Upper then Top - Bubble_Gap * Pixels - Bubble_High * Pixels else Below) - Top_Of (Item);
   begin
      if Integer (Left) /= Left_Kept or else Integer (Put_Top) /= Top_Kept then
         Left_Kept := Integer (Left);
         Top_Kept := Integer (Put_Top);
         Yoga.Nodes.Set_Position (Node (Bubble), Yoga.Left, Float'Rounding (Left));
         Yoga.Nodes.Set_Position (Node (Bubble), Yoga.Top, Float'Rounding (Put_Top));
         Request_Layout (Item);
      end if;
   end Place_Bubble;

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

   procedure Track_Pointer (Item : in out Editor; Event : SDL3.Events.Event) is
      Pixels : constant Float := Density (Item);
      Run    : Natural;
   begin
      if Item.Writing then
         Item.Hovering := False;
      elsif Event.Kind in SDL3.Events.Mouse_Move | SDL3.Events.Mouse_Down | SDL3.Events.Mouse_Up then
         Run := (if Item.Pointer_In_Text then Pointer_Version (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels)
                 else 0);
         Item.Hovering := Run /= 0;
         if Run /= 0 then
            Item.Hover_From := Docs.Run (Text_Areas.Document (Item.Text).all, Run).From;
         end if;
         if Event.Kind = SDL3.Events.Mouse_Down and then Event.Button = 1 then
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

   overriding procedure Handle_Event
     (Self   : in out Editor;
      Source : in out Widget'Class;
      Event  : Widget_Event) is
   begin
      case Event.Kind is
         when Click =>
            if Is_Attached (Self.Confirm) and then Source'Address = Self.Accept_Button'Address then
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
            elsif Is_Attached (Self.Assist) and then Source'Address = Self.Assist'Address then
               if Buttons.Is_Enabled (Self.Assist) then
                  Notify (Self, Assist);
               end if;
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
      Event   : SDL3.Events.Event;
      Handled : out Boolean) is
   begin
      Handled := False;
      if Has_Document (Item) and then Item.Enabled then
         if Event.Kind in SDL3.Events.Mouse_Move | SDL3.Events.Mouse_Down
           | SDL3.Events.Mouse_Up | SDL3.Events.Mouse_Wheel
         then
            Item.Pointer_In_Text :=
              not Item.Toolbar_Shown
              or else Event.Mouse_Y * Density (Item)
                      >= Top_Of (Item) + Text_Areas.Toolbar_Points * Density (Item);
         end if;
         if Item.Writing and then Event.Kind = SDL3.Events.Key_Down
           and then Event.Key in SDL3.Events.Key_Return | SDL3.Events.Key_Escape
         then
            Finish_Version (Item, Event.Key = SDL3.Events.Key_Return);
            Handled := True;
         elsif Item.Cycle_Open and then Event.Kind = SDL3.Events.Key_Down
           and then Event.Key = SDL3.Events.Key_Escape
         then
            Close_Cycle (Item);
            Handled := True;
         elsif Event.Kind = SDL3.Events.Key_Down and then not Event.Command and then not Event.Option
           and then not Event.Shift
           and then Event.Key in SDL3.Events.Key_Left_Arrow | SDL3.Events.Key_Right_Arrow
           and then Cycling_From (Item, Item.Cycle_Target)
         then
            Cycle_Version (Item, Item.Cycle_Target, (if Event.Key = SDL3.Events.Key_Right_Arrow then 1 else -1));
            Handled := True;
         elsif Item.Toolbar_On and then Has_Focus (Item)
           and then Event.Kind = SDL3.Events.Key_Down
           and then Event.Command and then not Event.Option and then not Event.Shift
           and then Event.Key in SDL3.Events.Key_B | SDL3.Events.Key_U | SDL3.Events.Key_I
         then
            Text_Areas.Toggle_Format
              (Item.Text,
               (if Event.Key = SDL3.Events.Key_B then Docs.Bold
                elsif Event.Key = SDL3.Events.Key_U then Docs.Underline
                else Docs.Italic));
            Handled := True;
         elsif Item.Toolbar_On and then Has_Focus (Item)
           and then Event.Kind = SDL3.Events.Key_Down
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
           and then SDL3.Events."=" (Event.Kind, SDL3.Events.Mouse_Down)
         then
            Notify (Item, Click);
         end if;
         if Text_Areas.Return_Pending (Item.Text)
           and then Event.Kind in SDL3.Events.Key_Down
           and then Event.Key in SDL3.Events.Key_Return
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
     (Item : in out Editor; Now : SDL3.Events.Milliseconds)
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
      then (if Item.Hovering and then not Item.Writing then SDL3.Cursors.Pointer else SDL3.Cursors.Text)
      else SDL3.Cursors.Default);
   --  A text with versions is clicked, to go through them.

   overriding procedure Hover_Changed
     (Item : in out Editor; Hovered : Boolean) is
   begin
      if Has_Document (Item) then
         Text_Areas.Set_Hovered (Item.Text, Hovered);
         if not Hovered then
            Item.Hovering := False;
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
