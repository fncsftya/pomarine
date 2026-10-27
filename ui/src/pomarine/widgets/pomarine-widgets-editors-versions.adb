with Ada.Strings.Fixed;
with Yoga.Nodes;
with Pomarine.Icons;
with Pomarine.Widgets.Editors.Metrics;
with Pomarine.Widgets.Editors.Links;

package body Pomarine.Widgets.Editors.Versions is

   package Docs renames Texts.Documents;

   use type Docs.Version;
   use type Texts.Position;
   use type Pomarine.Events.Event_Kind;

   use Pomarine.Widgets.Editors.Metrics;
   use Pomarine.Widgets.Editors.Links;

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
      Put_Button
        (Item,
         Item.Cycle,
         Item.Next_Button,
         3.0 * Bubble_Pad + Button_Wide + Count_Wide,
         Button_Wide,
         ">",
         "Next version");
      Request_Layout (Item);
   end Build_Bubbles;

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

   function Pointer_Version (Item : in out Editor; X, Y : Float) return Natural is
      Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
   begin
      for I in 1 .. Docs.Run_Count (Doc.all) loop
         declare
            R : constant Docs.Format_Run := Docs.Run (Doc.all, I);
         begin
            if Docs."=" (R.Style, Docs.Versioned)
              and then R.From < R.To
              and then Text_Areas.Is_Over_Range (Item.Text, R.From, R.To, X, Y)
            then
               return I;
            end if;
         end;
      end loop;
      return 0;
   end Pointer_Version;

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
              Ada.Strings.Fixed.Trim (R.Choice'Image, Ada.Strings.Both)
              & " / "
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

   procedure Begin_Writing (Item : in out Editor) is
      Doc   : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
      First : Texts.Position := Text_Areas.Caret (Item.Text);
      Last  : Texts.Position := Text_Areas.Mark (Item.Text);
      Run   : Natural;
   begin
      if Item.Writing
        or else not Text_Areas.Has_Selection (Item.Text)
        or else Text_Areas.Is_Read_Only (Item.Text)
        or else Text_Areas.Is_Composing (Item.Text)
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
   end Begin_Writing;

   procedure Finish_Writing (Item : in out Editor; Keep : Boolean) is
      Doc : constant Docs.Document_Access := Text_Areas.Document (Item.Text);
   begin
      Track_Writing (Item);
      declare
         Plain : constant String :=
           (if Item.Typed_From < Item.Typed_To then Docs.Between (Doc.all, Item.Typed_From, Item.Typed_To) else "");
         --  What was typed as markup, to keep its styles; if it is more than a paragraph, as text.
         Typed : constant String :=
           (if Item.Typed_From < Item.Typed_To and then Item.Typed_From.Paragraph = Item.Typed_To.Paragraph
            then Docs.Fragment (Doc.all, Item.Typed_From, Item.Typed_To)
            else Docs.Escaped (Plain));
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
   end Finish_Writing;

   procedure Track_Pointer (Item : in out Editor; Event : Pomarine.Events.Event) is
      Pixels : constant Float := Density (Item);
      Run    : Natural;
   begin
      --  A link is followed with Command held: Cursor shows it, while it is.
      if Event.Kind in Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up then
         Item.Over_Link :=
           Item.Pointer_In_Text
           and then not Item.Writing
           and then Pointer_Link (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels) /= "";
      end if;
      if Item.Writing then
         Item.Hovering := False;
      elsif Event.Kind in Pomarine.Events.Mouse_Move | Pomarine.Events.Mouse_Down | Pomarine.Events.Mouse_Up then
         Run :=
           (if Item.Pointer_In_Text then Pointer_Version (Item, Event.Mouse_X * Pixels, Event.Mouse_Y * Pixels) else 0);
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

end Pomarine.Widgets.Editors.Versions;
