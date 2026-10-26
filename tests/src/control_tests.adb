with Ada.Strings.Fixed;
with Goldens;
with Hearers;
with Pomarine.Events;
with Pomarine.Semantics;
with Pomarine.Testing;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Choice_Groups;
with Pomarine.Widgets.Disclosures;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Splitters;
with Pomarine.Widgets.Steppers;

package body Control_Tests is

   package Widgets renames Pomarine.Widgets;
   package Events renames Pomarine.Events;
   package Layouts renames Pomarine.Widgets.Layouts;
   package Groups renames Pomarine.Widgets.Choice_Groups;
   package Testing renames Pomarine.Testing;
   use all type Pomarine.Semantics.Role;

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

   procedure Choice_Groups is
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Views   : aliased Groups.Choice_Group;
      Sizes   : aliased Groups.Choice_Group;
      Sides   : aliased Groups.Choice_Group;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;

      procedure Fill (Item : in out Groups.Choice_Group) is
      begin
         Groups.Add_Choice (Item, "Write");
         Groups.Add_Choice (Item, "Outline");
         Groups.Add_Choice (Item, "Canvas");
      end Fill;
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Column (Root, Padding => (others => 10.0), Gap => 10.0);
      Groups.Add (Root, Views, Groups.Tabs);
      Groups.Add (Root, Sizes, Groups.Radios);
      Groups.Add (Root, Sides, Groups.Segments);
      Fill (Views);
      Fill (Sides);
      Groups.Add_Choice (Sizes, "Small");
      Groups.Add_Choice (Sizes, "Medium");
      Groups.Add_Choice (Sizes, "Large");
      Groups.Fit (Sizes);
      Testing.Open (Session, Tree, 300, 300);

      --  Exactly one: the first, to begin with.
      Goldens.Check_Text ("choices-first-chosen", "1,3", Image (Groups.Selected (Views)) & ","
                          & Image (Groups.Choice_Count (Views)));
      Goldens.Check_Text ("choices-radios-fit", "72", Image (Integer (Widgets.Height_Of (Sizes))));
      Goldens.Check_Text ("choices-described", "TRUE,TRUE",
                          Testing.Exists (Session, "Outline", Radio_Button, Nth => 1)'Image & ","
                          & Testing.Exists (Session, "Large", Radio_Button)'Image);

      --  A click chooses, and says so, with the number; the same again says nothing.
      Testing.Click_On (Session, "Outline", Radio_Button, Nth => 1);
      Goldens.Check_Text ("choices-click", "2,2",
                          Image (Groups.Selected (Views)) & "," & Image (Row_Said (Ears, Views, Widgets.Choose)));
      Testing.Click_On (Session, "Outline", Radio_Button, Nth => 1);
      Goldens.Check_Text ("choices-same-quiet", "no", Said (Ears, Views, Widgets.Choose));
      Goldens.Check_Text ("choices-others-untouched", "1,1",
                          Image (Groups.Selected (Sizes)) & "," & Image (Groups.Selected (Sides)));

      --  The application's choice says nothing.
      Groups.Select_Choice (Views, 3);
      Goldens.Check_Text ("choices-set-quiet", "3,no",
                          Image (Groups.Selected (Views)) & "," & Said (Ears, Views, Widgets.Choose));

      --  One that is turned off takes no click, and the keys skip it.
      Groups.Set_Choice_Enabled (Sizes, 2, False);
      Testing.Settle (Session);
      Testing.Click_On (Session, "Medium", Radio_Button);
      Goldens.Check_Text ("choices-off-no-click", "1,no",
                          Image (Groups.Selected (Sizes)) & "," & Said (Ears, Sizes, Widgets.Choose));
      Goldens.Check_Text ("choices-off-described", "TRUE", Testing.Is_Disabled (Session, "Medium", Radio_Button)'Image);
      Groups.Set_Focusable (Sizes, True);
      Widgets.Focus (Sizes);
      Testing.Press (Session, Events.Key_Down_Arrow);
      Goldens.Check_Text ("choices-key-skips-off", "3", Image (Groups.Selected (Sizes)));
      Goldens.Check_Text ("choices-key-said", "3", Image (Row_Said (Ears, Sizes, Widgets.Choose)));
      Testing.Press (Session, Events.Key_Down_Arrow);
      Goldens.Check_Text ("choices-key-stops-at-end", "3,no",
                          Image (Groups.Selected (Sizes)) & "," & Said (Ears, Sizes, Widgets.Choose));
      Testing.Press (Session, Events.Key_Home);
      Goldens.Check_Text ("choices-home", "1", Image (Groups.Selected (Sizes)));
      Testing.Press (Session, Events.Key_End);
      Goldens.Check_Text ("choices-end", "3", Image (Groups.Selected (Sizes)));
      Testing.Press (Session, Events.Key_Up_Arrow);
      Goldens.Check_Text ("choices-up-skips-off", "1", Image (Groups.Selected (Sizes)));

      --  Turned off altogether, nothing.
      Groups.Set_Enabled (Sizes, False);
      Testing.Press (Session, Events.Key_Down_Arrow);
      Goldens.Check_Text ("choices-group-off", "1", Image (Groups.Selected (Sizes)));

      --  None, then one: the first is chosen as it comes.
      Groups.Clear_Choices (Sides);
      Goldens.Check_Text ("choices-cleared", "0", Image (Groups.Selected (Sides)));
      Groups.Add_Choice (Sides, "Only");
      Goldens.Check_Text ("choices-first-again", "1", Image (Groups.Selected (Sides)));
   end Choice_Groups;

   procedure Steppers is
      package Steps renames Widgets.Steppers;
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Copies  : aliased Steps.Stepper;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;

      --  The middle of its plus and of its minus, in points, at density 1.
      function Plus_X return Float is (Widgets.Left_Of (Copies) + Widgets.Width_Of (Copies) - 1.0 - 15.0);
      function Minus_X return Float is (Plus_X - 30.0);
      function Middle_Y return Float is (Widgets.Top_Of (Copies) + Widgets.Height_Of (Copies) / 2.0);
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Column (Root, Padding => (others => 10.0));
      Steps.Add (Root, Copies, Min => 1, Max => 5, Start => 3);
      Steps.Set_Suffix (Copies, " pt");
      Testing.Open (Session, Tree, 300, 200);
      Goldens.Check_Text ("stepper-starts", "TRUE", Testing.Shows (Session, "=3 pt")'Image);

      Testing.Click_At (Session, Plus_X, Middle_Y);
      Goldens.Check_Text ("stepper-plus", "4,yes",
                          Image (Steps.Value (Copies)) & "," & Said (Ears, Copies, Widgets.Change));
      Testing.Click_At (Session, Minus_X, Middle_Y);
      Testing.Click_At (Session, Minus_X, Middle_Y);
      Goldens.Check_Text ("stepper-minus", "2", Image (Steps.Value (Copies)));

      --  By its step, and held at its ends.
      Steps.Set_Step (Copies, 2);
      Testing.Click_At (Session, Plus_X, Middle_Y);
      Testing.Click_At (Session, Plus_X, Middle_Y);
      Goldens.Check_Text ("stepper-step-and-max", "5", Image (Steps.Value (Copies)));
      Goldens.Check_Text ("stepper-say-drained", "yes", Said (Ears, Copies, Widgets.Change));
      Testing.Click_At (Session, Plus_X, Middle_Y);
      Goldens.Check_Text ("stepper-at-max-quiet", "5,no",
                          Image (Steps.Value (Copies)) & "," & Said (Ears, Copies, Widgets.Change));

      --  Keys, with the focus: Up and Down, ten steps by Page.
      Steps.Set_Step (Copies, 1);
      Steps.Set_Range (Copies, 0, 100);
      Steps.Set_Focusable (Copies, True);
      Widgets.Focus (Copies);
      Testing.Press (Session, Events.Key_Up_Arrow);
      Testing.Press (Session, Events.Key_Page_Up);
      Goldens.Check_Text ("stepper-keys", "16", Image (Steps.Value (Copies)));
      Testing.Press (Session, Events.Key_Page_Down);
      Testing.Press (Session, Events.Key_Page_Down);
      Goldens.Check_Text ("stepper-keys-stop-at-min", "0", Image (Steps.Value (Copies)));

      --  Set by the application, quiet, and the range brings it in.
      Goldens.Check_Text ("stepper-keys-said", "yes", Said (Ears, Copies, Widgets.Change));
      Steps.Set_Value (Copies, 40);
      Goldens.Check_Text ("stepper-set-quiet", "40,no",
                          Image (Steps.Value (Copies)) & "," & Said (Ears, Copies, Widgets.Change));
      Steps.Set_Range (Copies, 0, 10);
      Goldens.Check_Text ("stepper-range-pulls-in", "10", Image (Steps.Value (Copies)));

      --  Turned off, it takes nothing; the system can still step it when it is on.
      Steps.Set_Enabled (Copies, False);
      Testing.Press (Session, Events.Key_Down_Arrow);
      Goldens.Check_Text ("stepper-off", "10", Image (Steps.Value (Copies)));
   end Steppers;

   procedure Disclosures is
      package Parts renames Widgets.Disclosures;
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Advanced : aliased Parts.Disclosure;
      Inside  : aliased Widgets.Buttons.Button;
      Beside  : aliased Widgets.Buttons.Button;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;
      Open_High : Integer;

      procedure On_Heading is
      begin
         Testing.Click_At (Session, Widgets.Left_Of (Advanced) + 60.0, Widgets.Top_Of (Advanced) + 10.0);
      end On_Heading;
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Column (Root, Padding => (others => 10.0), Gap => 4.0);
      Parts.Add (Root, Advanced, "Advanced");
      Layouts.Add (Advanced, Inside, (Height => 30.0, Width => 100.0, others => <>));
      Layouts.Add (Advanced, Beside, (Height => 30.0, Width => 100.0, others => <>));
      Widgets.Buttons.Set_Label (Inside, "Inside");
      Widgets.Buttons.Set_Label (Beside, "Beside");
      Testing.Open (Session, Tree, 300, 300);
      Open_High := Integer (Widgets.Height_Of (Advanced));
      Goldens.Check_Text ("disclosure-open", "TRUE,TRUE,TRUE",
                          Parts.Is_Open (Advanced)'Image & "," & Testing.Exists (Session, "Inside")'Image & ","
                          & Boolean'Image (Open_High > 60));

      --  Its heading closes it: what is under takes no room, and it says so.
      On_Heading;
      Goldens.Check_Text ("disclosure-closed", "FALSE,FALSE,yes",
                          Parts.Is_Open (Advanced)'Image & "," & Testing.Exists (Session, "Inside")'Image & ","
                          & Said (Ears, Advanced, Widgets.Change));
      Goldens.Check_Text ("disclosure-heading-only", "30", Image (Integer (Widgets.Height_Of (Advanced))));
      On_Heading;
      Goldens.Check_Text ("disclosure-reopened", "TRUE,TRUE", Parts.Is_Open (Advanced)'Image & ","
                          & Testing.Exists (Session, "Beside")'Image);
      Goldens.Check_Text ("disclosure-same-height", Image (Open_High), Image (Integer (Widgets.Height_Of (Advanced))));

      --  The application's choice says nothing; the keys, with the focus, do as a click.
      Parts.Set_Open (Advanced, False);
      Goldens.Check_Text ("disclosure-set-quiet", "FALSE,yes,no", Parts.Is_Open (Advanced)'Image & ","
                          & Said (Ears, Advanced, Widgets.Change) & "," & Said (Ears, Advanced, Widgets.Change));
      Parts.Set_Focusable (Advanced, True);
      Widgets.Focus (Advanced);
      Testing.Press (Session, Events.Key_Space);
      Goldens.Check_Text ("disclosure-key", "TRUE", Parts.Is_Open (Advanced)'Image);
   end Disclosures;

   procedure Splitters is
      package Bars renames Widgets.Splitters;
      Tree    : aliased Widgets.Tree;
      Root    : aliased Widgets.Panels.Panel;
      Side    : aliased Widgets.Panels.Panel;
      Divider : aliased Bars.Splitter;
      Page    : aliased Widgets.Panels.Panel;
      Ears    : aliased Hearers.Hearer;
      Session : Testing.Session;

      procedure Drag (From, To : Float) is
         Y : constant Float := 50.0;
      begin
         Testing.Feed (Session, (Kind => Events.Mouse_Down, Button => 1, Clicks => 1, Mouse_X => From,
                                 Mouse_Y => Y, others => <>));
         Testing.Feed (Session, (Kind => Events.Mouse_Move, Left_Held => True, Mouse_X => To, Mouse_Y => Y,
                                 others => <>));
         Testing.Feed (Session, (Kind => Events.Mouse_Up, Button => 1, Mouse_X => To, Mouse_Y => Y, others => <>));
         Testing.Settle (Session);
      end Drag;
   begin
      Widgets.Set_Listener (Tree, Ears'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Layouts.Row (Root);
      Layouts.Add (Root, Side, (Width => 100.0, Shrink => 0.0, others => <>));
      Bars.Add (Root, Divider);
      Layouts.Add (Root, Page, (Grow => 1.0, others => <>));
      Testing.Open (Session, Tree, 400, 100);
      Goldens.Check_Text ("splitter-starts", "100,6,294", Image (Integer (Widgets.Width_Of (Side))) & ","
                          & Image (Integer (Widgets.Width_Of (Divider))) & ","
                          & Image (Integer (Widgets.Width_Of (Page))));
      Goldens.Check_Text ("splitter-position", "100", Image (Integer (Bars.Position (Divider))));

      --  Dragged by the bar, the box before it is as wide as the pointer, less where the bar was taken; the rest goes
      --  to the one after.
      Drag (103.0, 153.0);
      Goldens.Check_Text ("splitter-drag", "150,244,yes", Image (Integer (Widgets.Width_Of (Side))) & ","
                          & Image (Integer (Widgets.Width_Of (Page))) & "," & Said (Ears, Divider, Widgets.Change));

      --  Within its limits.
      Drag (153.0, 5.0);
      Goldens.Check_Text ("splitter-least", "80", Image (Integer (Widgets.Width_Of (Side))));
      Bars.Set_Limits (Divider, 80.0, 200.0);
      Drag (83.0, 390.0);
      Goldens.Check_Text ("splitter-most", "200", Image (Integer (Widgets.Width_Of (Side))));

      --  Keys, with the focus; the application's own, quiet.
      Bars.Set_Focusable (Divider, True);
      Widgets.Focus (Divider);
      Testing.Press (Session, Events.Key_Left_Arrow);
      Goldens.Check_Text ("splitter-key", "184", Image (Integer (Widgets.Width_Of (Side))));
      Goldens.Check_Text ("splitter-key-said", "yes", Said (Ears, Divider, Widgets.Change));
      Bars.Set_Position (Divider, 120.0);
      Testing.Settle (Session);
      Goldens.Check_Text ("splitter-set-quiet", "120,no", Image (Integer (Widgets.Width_Of (Side))) & ","
                          & Said (Ears, Divider, Widgets.Change));
   end Splitters;

end Control_Tests;
