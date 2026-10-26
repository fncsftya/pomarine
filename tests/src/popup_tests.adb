with Ada.Strings.Fixed;
with Goldens;
with Hearers;
with Pomarine.Anchoring;
with Pomarine.Dialogs;
with Pomarine.Events;
with Pomarine.Testing;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Dialogs;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Overlays;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Popovers;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Tooltips;

package body Popup_Tests is

   package Widgets renames Pomarine.Widgets;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Overlays renames Pomarine.Widgets.Overlays;
   package Menus renames Pomarine.Widgets.Menus;
   package Selects renames Pomarine.Widgets.Selects;
   package Testing renames Pomarine.Testing;

   function Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   function Said
     (Ears : in out Hearers.Hearer; Source : Widgets.Widget'Class; Kind : Widgets.Event_Kind) return String
   is
      Taken : Boolean;
   begin
      Hearers.Take (Ears, Source, Kind, Taken);
      return (if Taken then "yes" else "no");
   end Said;

   function Row_Said
     (Ears : in out Hearers.Hearer; Source : Widgets.Widget'Class; Kind : Widgets.Event_Kind) return Natural
   is
      Row : Natural;
   begin
      Hearers.Take_Row (Ears, Source, Kind, Row);
      return Row;
   end Row_Said;

   procedure Select_Menu is
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Field   : aliased Selects.Select_Field;
      Other   : aliased Widgets.Buttons.Button;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Column (Root, Padding => (others => 20.0), Gap => 10.0);
      Layouts.Add (Root, Field, (Width => 160.0, Height => 32.0, others => <>));
      Layouts.Add (Root, Other, (Width => 80.0, Height => 30.0, Margin => (Top => 150.0, others => <>), others => <>));
      Widgets.Buttons.Set_Label (Other, "Elsewhere");
      Selects.Add_Choice (Field, "Georgia");
      Selects.Add_Choice (Field, "Menlo");
      Selects.Add_Choice (Field, "Avenir");
      Selects.Set_Value (Field, "Menlo");
      Testing.Open (Session, Tree, 300, 300);

      Goldens.Check_Text ("select-choices", "3 2",
                          Image (Selects.Choice_Count (Field)) & " " & Image (Selects.Chosen (Field)));
      Goldens.Check_Text ("select-closed", "FALSE", Overlays.Is_Presented (Field)'Image);

      --  A click opens its menu, as wide as it, and it is shown open.
      Testing.Click_At (Session, 60.0, 36.0);
      Goldens.Check_Text ("select-opens", "TRUE,TRUE",
                          Selects.Is_Open (Field)'Image & "," & Testing.Exists (Session, "Avenir")'Image);
      Goldens.Check_Text ("select-click-not-heard", "no", Said (Ears, Field, Widgets.Click));

      --  A row is the value, said as a change, and the menu is gone.
      Testing.Click_On (Session, "Avenir");
      Goldens.Check_Text ("select-chose", "Avenir", Selects.Value (Field));
      Goldens.Check_Text ("select-chose-said", "yes", Said (Ears, Field, Widgets.Change));
      Goldens.Check_Text ("select-closes", "FALSE,FALSE",
                          Selects.Is_Open (Field)'Image & "," & Testing.Exists (Session, "Menlo")'Image);

      --  Escape closes it, and the value is as it was.
      Testing.Click_At (Session, 60.0, 36.0);
      Testing.Press (Session, Pomarine.Events.Key_Escape);
      Goldens.Check_Text ("select-escape", "FALSE,Avenir", Selects.Is_Open (Field)'Image & "," & Selects.Value (Field));
      Goldens.Check_Text ("select-escape-quiet", "no", Said (Ears, Field, Widgets.Change));

      --  Another click on it closes it, and does not open it again.
      Testing.Click_At (Session, 60.0, 36.0);
      Testing.Click_At (Session, 60.0, 36.0);
      Goldens.Check_Text ("select-toggles", "FALSE", Selects.Is_Open (Field)'Image);

      --  A press elsewhere closes it, and is not taken by what is there.
      Testing.Click_At (Session, 60.0, 36.0);
      Testing.Click_On (Session, "Elsewhere");
      Goldens.Check_Text ("select-outside", "FALSE,no",
                          Selects.Is_Open (Field)'Image & "," & Said (Ears, Other, Widgets.Click));

      --  Chosen again by the same, it is not a change.
      Testing.Click_At (Session, 60.0, 36.0);
      Testing.Click_On (Session, "Avenir");
      Goldens.Check_Text ("select-same-quiet", "no", Said (Ears, Field, Widgets.Change));
   end Select_Menu;

   procedure Context_Menu is
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Menu    : aliased Menus.Menu;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;
      Rows    : Menus.Row_Vectors.Vector;
      Row     : Natural;
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Add (Root, Menu, (Place => Layouts.Absolute, Width => 140.0, others => <>));
      Rows.Append (Menus.Describe_Row (Menus.Action, "Cut"));
      Rows.Append (Menus.Describe_Row (Menus.Action, "Copy"));
      Menus.Set_Rows (Menu, Rows);
      Menus.Set_Closes_On_Choose (Menu, True);
      Widgets.Set_Visible (Menu, False);
      Testing.Open (Session, Tree, 300, 300);

      Overlays.Present_At (Menu, 100.0, 100.0);
      Testing.Settle (Session);
      Goldens.Check_Text ("context-shown", "TRUE,112", Overlays.Is_Presented (Menu)'Image & ","
                          & Image (Integer (Widgets.Top_Of (Menu))));
      Testing.Click_On (Session, "Copy");
      Hearers.Take_Row (Ears, Menu, Widgets.Choose, Row);
      Goldens.Check_Text ("context-chose", "2", Image (Row));
      Goldens.Check_Text ("context-closed", "FALSE", Overlays.Is_Presented (Menu)'Image);
      Goldens.Check_Text ("context-hidden", "FALSE", Widgets.Is_Showing (Menu)'Image);
   end Context_Menu;

   procedure Popover_Box is
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Help    : aliased Widgets.Buttons.Button;
      Info    : aliased Widgets.Popovers.Popover;
      Note    : aliased Widgets.Labels.Label;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Add (Root, Help, (Place => Layouts.Absolute, Width => 60.0, Height => 30.0,
                                Position => (Left => 20.0, Top => 20.0, others => <>), others => <>));
      Widgets.Buttons.Set_Label (Help, "Help");
      Widgets.Popovers.Add (Root, Info, Width => 200.0);
      Layouts.Add (Info, Note, (Height => 24.0, others => <>));
      Widgets.Labels.Set_Text (Note, "Press Escape to close");
      Testing.Open (Session, Tree, 300, 300);
      Goldens.Check_Text ("popover-hidden", "FALSE,FALSE",
                          Widgets.Is_Visible (Info)'Image & "," & Testing.Exists (Session,
                                                                                  "Press Escape to close")'Image);

      Widgets.Popovers.Show_Beside (Info, Help, (Side => Pomarine.Anchoring.After, others => <>));
      Testing.Settle (Session);
      Goldens.Check_Text ("popover-shown", "TRUE,TRUE", Widgets.Popovers.Is_Shown (Info)'Image & ","
                          & Testing.Exists (Session, "Press Escape to close")'Image);
      Goldens.Check_Text ("popover-placed", "84,20",
                          Image (Integer (Widgets.Left_Of (Info))) & "," & Image (Integer (Widgets.Top_Of (Info))));
      Goldens.Check_Text ("popover-as-tall-as-its-content", "45", Image (Integer (Widgets.Height_Of (Info))));

      Testing.Press (Session, Pomarine.Events.Key_Escape);
      Goldens.Check_Text ("popover-escape", "FALSE,yes",
                          Widgets.Popovers.Is_Shown (Info)'Image & "," & Said (Ears, Info, Widgets.Dismiss));
      Widgets.Popovers.Show_At (Info, 150.0, 150.0);
      Widgets.Popovers.Hide (Info);
      Goldens.Check_Text ("popover-hidden-quietly", "FALSE,no",
                          Widgets.Popovers.Is_Shown (Info)'Image & "," & Said (Ears, Info, Widgets.Dismiss));
   end Popover_Box;

   procedure Tooltip_Rests is
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Save    : aliased Widgets.Buttons.Button;
      Quit    : aliased Widgets.Buttons.Button;
      Plain   : aliased Widgets.Buttons.Button;
      Tip     : aliased Widgets.Tooltips.Tooltip;
      Session : Testing.Session;

      procedure Move_To (X, Y : Float) is
      begin
         Testing.Feed (Session, (Kind => Pomarine.Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, others => <>));
         Testing.Settle (Session, 16);
         --  The tree sees where the pointer is at its next update, and counts the rest from there.
      end Move_To;

      function Shown return Boolean is (Testing.Exists (Session, "Saves the file"));
   begin
      Widgets.Set_Root (Tree, Root);
      Layouts.Add (Root, Save, (Place => Layouts.Absolute, Width => 80.0, Height => 30.0,
                                Position => (Left => 20.0, Top => 20.0, others => <>), others => <>));
      Layouts.Add (Root, Quit, (Place => Layouts.Absolute, Width => 80.0, Height => 30.0,
                                Position => (Left => 120.0, Top => 20.0, others => <>), others => <>));
      Layouts.Add (Root, Plain, (Place => Layouts.Absolute, Width => 80.0, Height => 30.0,
                                 Position => (Left => 220.0, Top => 20.0, others => <>), others => <>));
      Widgets.Buttons.Set_Label (Save, "Save");
      Widgets.Buttons.Set_Label (Quit, "Quit");
      Widgets.Buttons.Set_Label (Plain, "Plain");
      Widgets.Set_Tooltip (Save, "Saves the file");
      Widgets.Set_Tooltip (Quit, "Ends the program");
      Widgets.Tooltips.Install (Tree, Tip, Delay_MS => 600);
      Testing.Open (Session, Tree, 400, 200);
      Goldens.Check_Text ("tooltip-none-yet", "FALSE", Shown'Image);

      --  The pointer rests: nothing at first, then the box, beside the widget.
      Move_To (60.0, 35.0);
      Testing.Settle (Session, 300);
      Goldens.Check_Text ("tooltip-waits", "FALSE", Shown'Image);
      Testing.Settle (Session, 400);
      Goldens.Check_Text ("tooltip-shown", "TRUE", Shown'Image);
      Goldens.Check_Text ("tooltip-below", "20,56", Image (Integer (Widgets.Left_Of (Tip))) & ","
                          & Image (Integer (Widgets.Top_Of (Tip))));

      --  Moving about the same widget keeps it; moving to one with no tooltip takes it away.
      Move_To (70.0, 40.0);
      Testing.Settle (Session, 100);
      Goldens.Check_Text ("tooltip-stays", "TRUE", Shown'Image);
      Move_To (260.0, 35.0);
      Testing.Settle (Session, 50);
      Goldens.Check_Text ("tooltip-goes", "FALSE", Shown'Image);
      Testing.Settle (Session, 900);
      Goldens.Check_Text ("tooltip-none-for-plain", "FALSE", Shown'Image);

      --  Another widget, its own words, after the wait again.
      Move_To (160.0, 35.0);
      Testing.Settle (Session, 700);
      Goldens.Check_Text ("tooltip-other", "TRUE,FALSE", Testing.Exists (Session, "Ends the program")'Image & ","
                          & Shown'Image);

      --  A press takes it, and it does not come back over the same widget.
      Testing.Feed (Session, (Kind => Pomarine.Events.Mouse_Down, Button => 1, Clicks => 1, Mouse_X => 160.0,
                              Mouse_Y => 35.0, others => <>));
      Testing.Feed (Session, (Kind => Pomarine.Events.Mouse_Up, Button => 1, Mouse_X => 160.0, Mouse_Y => 35.0,
                              others => <>));
      Testing.Settle (Session, 50);
      Goldens.Check_Text ("tooltip-press-takes-it", "FALSE", Testing.Exists (Session, "Ends the program")'Image);
      Testing.Settle (Session, 900);
      Goldens.Check_Text ("tooltip-stays-quiet", "FALSE", Testing.Exists (Session, "Ends the program")'Image);
      Move_To (60.0, 35.0);
      Testing.Settle (Session, 700);
      Goldens.Check_Text ("tooltip-back-over-another", "TRUE", Shown'Image);
   end Tooltip_Rests;

   procedure Menu_Keys is
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Field   : aliased Selects.Select_Field;
      Menu    : aliased Menus.Menu;
      Other   : aliased Widgets.Buttons.Button;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;
      Rows    : Menus.Row_Vectors.Vector;

      function Over return String is (Image (Menus.Hovered_Row (Menu)));
      procedure Key (Code : Pomarine.Events.Key_Code) is
      begin
         Testing.Press (Session, Code);
      end Key;
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Column (Root, Padding => (others => 20.0), Gap => 10.0);
      Layouts.Add (Root, Field, (Width => 160.0, Height => 32.0, others => <>));
      Layouts.Add (Root, Other, (Place => Layouts.Absolute, Width => 80.0, Height => 30.0,
                                 Position => (Left => 10.0, Top => 250.0, others => <>), others => <>));
      Widgets.Buttons.Set_Label (Other, "Other");
      Widgets.Buttons.Set_Focusable (Other, True);
      Layouts.Add (Root, Menu, (Place => Layouts.Absolute, Width => 140.0, others => <>));
      Selects.Add_Choice (Field, "Georgia");
      Selects.Add_Choice (Field, "Menlo");
      Selects.Add_Choice (Field, "Avenir");
      Selects.Set_Value (Field, "Menlo");
      Rows.Append (Menus.Describe_Row (Menus.Action, "Cut"));
      Rows.Append (Menus.Describe_Row (Menus.Separator));
      Rows.Append (Menus.Describe_Row (Menus.Action, "Copy", Allowed => False));
      Rows.Append (Menus.Describe_Row (Menus.Action, "Paste"));
      Menus.Set_Rows (Menu, Rows);
      Menus.Set_Keyboard (Menu, True);
      Menus.Set_Closes_On_Choose (Menu, True);
      Widgets.Set_Visible (Menu, False);
      Testing.Open (Session, Tree, 300, 300);

      --  A menu has the focus while it is presented, and shades what the keys come to, skipping what cannot be
      --  chosen, and going round.
      Widgets.Focus (Other);
      Overlays.Present_At (Menu, 100.0, 100.0);
      Testing.Settle (Session);
      Goldens.Check_Text ("keys-menu-has-focus", "TRUE,0", Boolean'Image (Widgets.Has_Focus (Menu)) & "," & Over);
      Key (Pomarine.Events.Key_Down_Arrow);
      Goldens.Check_Text ("keys-first", "1", Over);
      Key (Pomarine.Events.Key_Down_Arrow);
      Goldens.Check_Text ("keys-skips-off-and-rule", "4", Over);
      Key (Pomarine.Events.Key_Down_Arrow);
      Goldens.Check_Text ("keys-wraps", "1", Over);
      Key (Pomarine.Events.Key_Up_Arrow);
      Goldens.Check_Text ("keys-up-wraps", "4", Over);
      Key (Pomarine.Events.Key_Home);
      Goldens.Check_Text ("keys-home", "1", Over);
      Key (Pomarine.Events.Key_End);
      Goldens.Check_Text ("keys-end", "4", Over);

      --  Return chooses it, says so, and the menu lets go of itself; the focus goes back.
      Key (Pomarine.Events.Key_Return);
      Goldens.Check_Text ("keys-return-chose", "4", Image (Row_Said (Ears, Menu, Widgets.Choose)));
      Goldens.Check_Text ("keys-closed-focus-back", "FALSE,TRUE", Overlays.Is_Presented (Menu)'Image & ","
                          & Boolean'Image (Widgets.Has_Focus (Other)));

      --  Return with nothing shaded chooses nothing.
      Overlays.Present_At (Menu, 100.0, 100.0);
      Testing.Settle (Session);
      Key (Pomarine.Events.Key_Space);
      Goldens.Check_Text ("keys-nothing-shaded", "0,TRUE", Image (Row_Said (Ears, Menu, Widgets.Choose)) & ","
                          & Overlays.Is_Presented (Menu)'Image);
      Overlays.Dismiss (Menu);

      --  A select: its menu has the chosen row shaded, the keys move it, Return chooses and says Change.
      Testing.Click_At (Session, 60.0, 36.0);
      Goldens.Check_Text ("keys-select-opens", "TRUE", Selects.Is_Open (Field)'Image);
      Key (Pomarine.Events.Key_Down_Arrow);
      Key (Pomarine.Events.Key_Return);
      Goldens.Check_Text ("keys-select-chose", "Avenir,FALSE",
                          Selects.Value (Field) & "," & Selects.Is_Open (Field)'Image);
      Goldens.Check_Text ("keys-select-said", "yes", Said (Ears, Field, Widgets.Change));

      --  Escape still shuts it, and the value stays.
      Testing.Click_At (Session, 60.0, 36.0);
      Key (Pomarine.Events.Key_Up_Arrow);
      Key (Pomarine.Events.Key_Escape);
      Goldens.Check_Text ("keys-select-escape", "Avenir,FALSE",
                          Selects.Value (Field) & "," & Selects.Is_Open (Field)'Image);
   end Menu_Keys;

   procedure Wrapped_Message is
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Ask     : aliased Widgets.Dialogs.Dialog;
      Session : Testing.Session;

      function Lines return Natural is
         --  How many lines of the message are shown: those that are 'text' in what the window says, less the title.
         Screen : constant String := Testing.Screen (Session);
         Count  : Natural := 0;
      begin
         for Index in Screen'First .. Screen'Last - 5 loop
            if Screen (Index .. Index + 4) = ASCII.LF & "text"
              and then Screen (Index + 5) in ' ' | ASCII.LF
            then
               Count := Count + 1;
            end if;
         end loop;
         return Count - 1;
         --  Less the title.
      end Lines;
   begin
      Widgets.Set_Root (Tree, Root);
      Widgets.Dialogs.Add (Root, Ask, Width => 200.0);
      Testing.Open (Session, Tree, 400, 400);

      --  One line is one line, a LF is a new one.
      Pomarine.Dialogs.Alert (Ask, "T", "Short");
      Testing.Settle (Session);
      Goldens.Check_Text ("wrap-one", "1", Image (Lines));
      Widgets.Dialogs.Hide (Ask);
      Pomarine.Dialogs.Alert (Ask, "T", "First" & ASCII.LF & ASCII.LF & "Third");
      Testing.Settle (Session);
      Goldens.Check_Text ("wrap-lf", "3", Image (Lines));
      Widgets.Dialogs.Hide (Ask);

      --  A long one is cut at the spaces to fit: more than a line, none of it lost, in order.
      Pomarine.Dialogs.Alert
        (Ask, "T", "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma");
      Testing.Settle (Session);
      Goldens.Check_Text ("wrap-long", "TRUE", Boolean'Image (Lines > 2));
      Goldens.Check_Text ("wrap-keeps-words", "TRUE,TRUE", Testing.Shows (Session, "alpha")'Image & ","
                          & Testing.Shows (Session, "sigma'")'Image);
      Goldens.Check_Text ("wrap-fits", "TRUE", Boolean'Image (Lines <= Widgets.Dialogs.Max_Lines));
      Widgets.Dialogs.Hide (Ask);

      --  Too many lines end in an ellipsis.
      declare
         Long : String (1 .. 1200);
      begin
         for Index in Long'Range loop
            Long (Index) := (if Index mod 8 = 0 then ' ' else 'w');
         end loop;
         Pomarine.Dialogs.Alert (Ask, "T", Long);
         Testing.Settle (Session);
         Goldens.Check_Text ("wrap-cut-at-most", Image (Widgets.Dialogs.Max_Lines), Image (Lines));
         Goldens.Check_Text ("wrap-ellipsis", "TRUE", Testing.Shows (Session, "...'")'Image);
      end;
   end Wrapped_Message;

   procedure Questions is
      use Pomarine.Dialogs;
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Behind  : aliased Widgets.Buttons.Button;
      Ask     : aliased Widgets.Dialogs.Dialog;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;

      function Chose return Natural is
         Row : Natural;
      begin
         Hearers.Take_Row (Ears, Ask, Widgets.Choose, Row);
         return Row;
      end Chose;
      --  The button said (0 if none did).

      function Dismissed return Boolean is
         Taken : Boolean;
      begin
         Hearers.Take (Ears, Ask, Widgets.Dismiss, Taken);
         return Taken;
      end Dismissed;

      function As_Said (Row : Natural) return Widgets.Widget_Event is
        (Kind => Widgets.Choose, Row => Row, others => <>);
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Add (Root, Behind, (Place => Layouts.Absolute, Width => 80.0, Height => 30.0,
                                  Position => (Left => 10.0, Top => 250.0, others => <>), others => <>));
      Widgets.Buttons.Set_Label (Behind, "Behind");
      Widgets.Dialogs.Add (Root, Ask, Width => 300.0);
      Testing.Open (Session, Tree, 400, 300);
      Goldens.Check_Text ("dialog-hidden", "FALSE", Testing.Exists (Session, "Sure?")'Image);

      --  An alert: shown over everything, in the middle, answered by its one button.
      Alert (Ask, "Sure?", "It was saved." & ASCII.LF & "Twice.");
      Testing.Settle (Session);
      Goldens.Check_Text ("dialog-alert-shown", "TRUE,TRUE,TRUE",
                          Testing.Exists (Session, "Sure?")'Image & "," & Testing.Shows (Session, "Twice.")'Image
                          & "," & Widgets.Dialogs.Is_Shown (Ask)'Image);
      Goldens.Check_Text ("dialog-centred", "50", Image (Integer (Widgets.Left_Of (Ask))));
      Testing.Click_On (Session, "Behind");
      Goldens.Check_Text ("dialog-modal", "no", Said (Ears, Behind, Widgets.Click));
      Testing.Click_On (Session, "OK");
      Goldens.Check_Text ("dialog-alert-ok", "1", Image (Chose));
      Goldens.Check_Text ("dialog-alert-gone", "FALSE", Widgets.Dialogs.Is_Shown (Ask)'Image);
      Testing.Click_On (Session, "Behind");
      Goldens.Check_Text ("dialog-gone-clicks", "yes", Said (Ears, Behind, Widgets.Click));

      --  A confirmation: Return does what the focused button does, and that is Yes.
      Confirm (Ask, "Delete?", Yes => "Delete");
      Testing.Press (Session, Pomarine.Events.Key_Return);
      Goldens.Check_Text ("dialog-confirm-return", "TRUE", Confirmed (As_Said (Chose))'Image);
      Confirm (Ask, "Delete?", Yes => "Delete");
      Testing.Settle (Session);
      Testing.Click_On (Session, "Cancel");
      Goldens.Check_Text ("dialog-confirm-no", "FALSE", Confirmed (As_Said (Chose))'Image);

      --  Dangerous, the focus is on the safe one.
      Confirm (Ask, "Delete?", Yes => "Delete", Dangerous => True);
      Testing.Press (Session, Pomarine.Events.Key_Return);
      Goldens.Check_Text ("dialog-dangerous-default-is-no", "1", Image (Chose));

      --  Escape cancels, and says Dismiss.
      Confirm (Ask, "Delete?");
      Testing.Press (Session, Pomarine.Events.Key_Escape);
      Goldens.Check_Text ("dialog-escape", "TRUE,0,FALSE",
                          Dismissed'Image & "," & Image (Chose) & "," & Widgets.Dialogs.Is_Shown (Ask)'Image);

      --  A choice of three.
      Choose_From (Ask, "Save first?", "", [+"Save", +"Don't save", +"Cancel"], Default => 2);
      Goldens.Check_Text ("dialog-choices", "3", Image (Widgets.Dialogs.Button_Count (Ask)));
      Testing.Settle (Session);
      Testing.Click_On (Session, "Cancel");
      Goldens.Check_Text ("dialog-chose-third", "3", Image (Chosen (As_Said (Chose))));
   end Questions;

end Popup_Tests;
