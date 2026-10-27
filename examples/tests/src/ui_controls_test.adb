with Pomarine.Widgets.Canvases;
with Pomarine.Widgets.Editors;
with Texts.Documents;
with Pomarine.Widgets.Lists;
with Pomarine.Models;
with Pomarine.Widgets.Sliders;
with Pomarine.Events;
with Pomarine.View_Models;
with Pomarine.Widgets.Buttons;
with Pomarine.UI.Menus;
with Pomarine.Widgets.Menus;
with Pomarine.Themes;
with Pomarine.Testing;
with Pomarine.UI;
with Pomarine.UI.Hosts;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Switches;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Grips;
with Pomarine.Widgets;
with Options_UI;
with Options_VM;

--  Check, switch, progress bar, shown-when, a styled container, a scroller and a borrowed widget of any kind,
--  all through a view.

procedure UI_Controls_Test is
   package UI renames Pomarine.UI;
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   package Checks renames Pomarine.Widgets.Checks;
   package Options renames Options_UI.Options;
   use Options_VM;
   use type Widgets.Widget_Access;

   type Parts is record
      Light, Dark : UI.Check_Handle;
      Sync        : UI.Switch_Handle;
      Start, Stop : UI.Button_Handle;
      Bar         : UI.Progress_Handle;
      Extra       : UI.Widget_Handle;
      Layout      : UI.Layout;
   end record;

   function Build (Bound : Options.Context'Class; Borrowed : in out Widgets.Labels.Label) return Parts is
      Result : Parts;
   begin
      Result.Light := Bound.Check ("Light", Options_UI.Light, Pick_Light, Form => Checks.Radio);
      Result.Dark := Bound.Check ("Dark", Options_UI.Dark, Pick_Dark, Form => Checks.Radio);
      Result.Sync := Bound.Switch ("Sync", Options_UI.Sync, Toggle_Sync);
      Result.Start := Bound.Button ("Start", Start);
      Result.Stop := Bound.Button ("Finish", Finish);
      Result.Bar := Bound.Progress (Options_UI.Fraction);
      Result.Extra := Bound.Borrow_Widget (Borrowed);
      Bound.Show_When (UI.Any (Result.Bar), Options_UI.Running);
      Bound.Show_When (UI.Any (Result.Stop), Options_UI.Running);
      Bound.Show_When (UI.Any (Result.Start), Options_UI.Idle);
      Result.Layout :=
        UI.Column
          ([UI.Column
              ([UI.Place (Result.Light), UI.Place (Result.Dark)],
               Gap        => 8.0,
               Appearance => (Fill => Pomarine.Themes.Page, Border => Pomarine.Themes.Border, others => <>)),
            UI.Place (Result.Sync),
            UI.Scroll
              (UI.Column
                 ([UI.Place (Result.Start),
                   UI.Place (Result.Stop),
                   UI.Place (Result.Bar, Width => 200.0),
                   UI.Place (Result.Extra)]),
               Height => 120.0)],
           Padding => 8.0,
           Gap     => 6.0);
      return Result;
   end Build;

   procedure Typed_Event_Bindings_Check_Identity is
      Tree      : aliased Widgets.Tree;
      Model     : aliased Options_VM.Model;
      Screen    : UI.View (Tree'Access);
      Other     : UI.View (Tree'Access);
      Bound     : aliased Options.Context'Class := Options.Bind (Screen, Model'Access);
      Foreign   : constant Options.Context'Class := Options.Bind (Other, Model'Access);
      Label     : constant UI.Label_Handle := Bound.Label ("Choose dark");
      Elsewhere : constant UI.Label_Handle := Foreign.Label ("Other view");
      Stale     : UI.Label_Handle;
      Rejected  : Boolean := False;
   begin
      Bound.On_Event (UI.Any (Label), Widgets.Double_Click, Pick_Dark);
      begin
         Bound.On_Event (UI.Any (Label), Widgets.Double_Click, Pick_Light);
      exception
         when Program_Error =>
            Rejected := True;
      end;
      pragma Assert (Rejected);
      Rejected := False;
      begin
         Bound.On_Event (UI.Any (Elsewhere), Widgets.Double_Click, Pick_Dark);
      exception
         when UI.Foreign_Handle =>
            Rejected := True;
      end;
      pragma Assert (Rejected);
      declare
         Part : aliased Options.Component (Bound'Access);
      begin
         Stale := Part.Label ("Uncommitted");
      end;
      Rejected := False;
      begin
         Bound.On_Event (UI.Any (Stale), Widgets.Double_Click, Pick_Dark);
      exception
         when UI.Stale_Handle =>
            Rejected := True;
      end;
      pragma Assert (Rejected);
      UI.Mount (Screen, UI.Place (Label));
      Widgets.Notify (UI.Widget_Of (Screen, Label).all, Widgets.Double_Click);
      Widgets.Update (Tree, 0);
      pragma Assert (Options_VM.Dark (Model));
   end Typed_Event_Bindings_Check_Identity;

   procedure List_Events_Route_Rows_And_Actions is
      use type Pomarine.View_Models.Version_Number;
      Tree     : aliased Widgets.Tree;
      Model    : aliased Options_VM.Model;
      Rows     : aliased Pomarine.Models.Text_List (2);
      List     : Widgets.Lists.List;
      Root     : Widgets.Panels.Panel;
      Window   : Testing.Session;
      Seen     : Pomarine.View_Models.Version_Number;
      Rejected : Boolean := False;
      Ignored  : constant array (1 .. 4) of Natural := [0, 2, 3, 100];
   begin
      Pomarine.Models.Append (Rows, "First");
      Pomarine.Models.Append (Rows, "Second");
      Widgets.Lists.Set_Model (List, Rows'Unchecked_Access);
      Options_VM.Set_Cards (Model, 2);
      declare
         Screen  : UI.View (Tree'Access);
         Bound   : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
         Choices : constant UI.Widget_Handle := Bound.Borrow_Widget (List);
         Wrong   : constant UI.Widget_Handle := Bound.Borrow_Widget (Root);
      begin
         begin
            Bound.On_List_Actions (Wrong, [Open_Card]);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         pragma Assert (Rejected);
         Bound.On_Event (Choices, Widgets.Click, Open_Card, Index_From_Event => True);
         Bound.On_Event (Choices, Widgets.Submit, Open_Card, Index_From_Event => True);
         Bound.On_List_Actions (Choices, [Open_Card, Pick_Dark]);
         Rejected := False;
         begin
            Bound.On_List_Actions (Choices, [Open_Card]);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         pragma Assert (Rejected);
         UI.Mount (Screen, UI.Place (Choices, Width => 200.0, Height => 100.0));
         Testing.Open (Window, Tree, 320, 200);
         Seen := Options_VM.Version (Model);
         Widgets.Notify (List, Widgets.Submit);
         Testing.Settle (Window);
         pragma Assert (Options_VM.Version (Model) = Seen);
         Widgets.Lists.Select_Row (List, 2);
         Widgets.Notify (List, Widgets.Click);
         Testing.Settle (Window);
         pragma Assert (Options_VM.Opened (Model) = 2);
         Widgets.Lists.Select_Row (List, 1);
         Widgets.Notify (List, Widgets.Submit);
         Testing.Settle (Window);
         pragma Assert (Options_VM.Opened (Model) = 1);
         --  Actions use their own row, independent of selection.
         Widgets.Notify (List, Widgets.Act, Row => 2, Action => 1);
         Testing.Settle (Window);
         pragma Assert (Options_VM.Opened (Model) = 2);
         Seen := Options_VM.Version (Model);
         for Action of Ignored loop
            Widgets.Notify (List, Widgets.Act, Row => 1, Action => Action);
            Testing.Settle (Window);
         end loop;
         Widgets.Notify (List, Widgets.Act, Row => 0, Action => 1);
         Widgets.Notify (List, Widgets.Act, Row => 3, Action => 1);
         Testing.Settle (Window);
         pragma Assert (Options_VM.Version (Model) = Seen and then not Options_VM.Dark (Model));
      end;
      --  Teardown must detach every event, including all commands in the action map.
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, List);
      Widgets.Notify (List, Widgets.Submit);
      Widgets.Notify (List, Widgets.Act, Row => 1, Action => 1);
      Widgets.Update (Tree, 0);
      pragma Assert (Options_VM.Version (Model) = Seen);
   end List_Events_Route_Rows_And_Actions;

   procedure Editor_Hooks_Route_Tools_And_Links is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Options_VM.Model;
      Notes    : Widgets.Editors.Editor;
      Doc      : aliased Texts.Documents.Document;
      Root     : Widgets.Panels.Panel;
      Window   : Testing.Session;
      Rejected : Boolean := False;
   begin
      Options_VM.Set_Cards (Model, 3);
      pragma Assert (Options.Editor_Of (Options.Tool_Index (3, 2)) = 3);
      pragma Assert (Options.Tool_Of (Options.Tool_Index (3, 2)) = 2);
      Widgets.Set_Accessible_Name (Notes, "Notes");
      Widgets.Editors.Configure (Notes, "Georgia", Size => 18.0, Measure => 200.0);
      Widgets.Editors.Attach (Notes, Doc'Unchecked_Access);
      Widgets.Editors.Set_Toolbar (Notes);
      Widgets.Editors.Add_Tool (Notes, "Mark", 'm');
      Widgets.Editors.Add_Tool (Notes, "Cite", 'p');
      declare
         Screen : UI.View (Tree'Access);
         Bound  : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
         Editor : constant UI.Widget_Handle := Bound.Borrow_Widget (Notes);
         Wrong  : constant UI.Widget_Handle := Bound.Borrow_Widget (Root);
      begin
         begin
            Bound.On_Editor_Event (Wrong, Options.Tool_Used, Open_Card, Index_From_Event => True);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         pragma Assert (Rejected);
         Bound.On_Editor_Event (Editor, Options.Tool_Used, Open_Card, Index_From_Event => True);
         Bound.On_Editor_Event (Editor, Options.Link_Followed, Pick_Dark);
         Bound.On_Editor_Event (Editor, Options.Link_Asked, Pick_Light);
         Rejected := False;
         begin
            Bound.On_Editor_Event (Editor, Options.Tool_Used, Pick_Dark);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         pragma Assert (Rejected);
         UI.Mount (Screen, UI.Place (Editor, Width => 200.0, Height => 100.0));
         Testing.Open (Window, Tree, 320, 200);
         Testing.Click_On (Window, "Notes");
         Testing.Press (Window, Pomarine.Events.Key_P, Command => True);
         Testing.Settle (Window);
         pragma Assert (Options_VM.Opened (Model) = 2);
         Testing.Press (Window, Pomarine.Events.Key_Code (Character'Pos ('m')), Command => True);
         Testing.Settle (Window);
         pragma Assert (Options_VM.Opened (Model) = 1);
      end;
   end Editor_Hooks_Route_Tools_And_Links;

   procedure Canvas_Hooks_Are_Bound_Once_To_A_Canvas is
      Tree         : aliased Widgets.Tree;
      Model        : aliased Options_VM.Model;
      Board        : Widgets.Canvases.Canvas;
      Root         : Widgets.Panels.Panel;
      Wrong, Twice : Boolean := False;
   begin
      declare
         Screen : UI.View (Tree'Access);
         Bound  : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
         Canvas : constant UI.Widget_Handle := Bound.Borrow_Widget (Board);
         Panel  : constant UI.Widget_Handle := Bound.Borrow_Widget (Root);
      begin
         begin
            Bound.On_Canvas_Event (Panel, Options.Line_Selected, Open_Card, Index_From_Event => True);
         exception
            when Program_Error =>
               Wrong := True;
         end;
         Bound.On_Canvas_Event (Canvas, Options.Line_Selected, Open_Card, Index_From_Event => True);
         Bound.On_Canvas_Event (Canvas, Options.Line_Deleted, Pick_Dark);
         begin
            Bound.On_Canvas_Event (Canvas, Options.Line_Deleted, Pick_Light);
         exception
            when Program_Error =>
               Twice := True;
         end;
         UI.Mount (Screen, UI.Place (Canvas, Width => 100.0, Height => 100.0));
      end;
      pragma Assert (Wrong and then Twice);
   end Canvas_Hooks_Are_Bound_Once_To_A_Canvas;

   procedure Sliders_And_Menu_Events_Follow_The_Model is
      use type Pomarine.View_Models.Version_Number;
      Tree   : aliased Widgets.Tree;
      Root   : Widgets.Panels.Panel;
      Model  : aliased Options_VM.Model;
      Slider : Widgets.Sliders.Slider;
      Menu   : Widgets.Menus.Menu;
      Window : Testing.Session;
      Before : Pomarine.View_Models.Version_Number;
   begin
      Options_VM.Advance (Model, 0.25);
      Options_VM.Set_Cards (Model, 2);
      Widgets.Set_Accessible_Name (Slider, "Amount");
      Widgets.Sliders.Set_Focusable (Slider, True);
      UI.Menus.Set_Content
        (Menu, [UI.Menus.Row (Widgets.Menus.Action, "First card"), UI.Menus.Row (Widgets.Menus.Action, "Second card")]);
      Widgets.Set_Tag (Menu, 9876, 99);
      --  Tag 1 belongs to the menu command below. Slider edits must never dispatch it.
      Widgets.Set_Tag (Slider, 1, 2);
      declare
         Screen   : UI.View (Tree'Access);
         Bound    : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
         Knob     : constant UI.Widget_Handle := Bound.Borrow_Slider (Slider, Options_UI.Editable_Fraction);
         Choices  : constant UI.Widget_Handle := Bound.Borrow_Widget (Menu);
         Rejected : Boolean := False;
      begin
         Bound.On_Event (Choices, Widgets.Choose, Open_Card, Index_From_Event => True);
         begin
            Bound.On_Event (Choices, Widgets.Choose, Open_Card, Index_From_Event => True);
         exception
            when Program_Error =>
               Rejected := True;
         end;
         pragma Assert (Rejected);
         UI.Mount
           (Screen,
            UI.Column
              ([UI.Place (Knob, Width => 200.0, Height => 30.0), UI.Place (Choices, Width => 220.0, Height => 80.0)]));
         pragma Assert (Widgets.Sliders.Value (Slider) = 0.25);
         Before := Options_VM.Version (Model);
         UI.Synchronize (Screen);
         pragma Assert (Options_VM.Version (Model) = Before);
         Testing.Open (Window, Tree, 320, 250);
         Testing.Click_On (Window, "Amount");
         Testing.Press (Window, Pomarine.Events.Key_Right_Arrow);
         pragma Assert (Options_VM.Fraction (Model) = Widgets.Sliders.Value (Slider));
         pragma Assert (Options_VM.Fraction (Model) > 0.25 and then Options_VM.Opened (Model) = 0);
         Testing.Feed
           (Window, (Kind => Pomarine.Events.Mouse_Down, Button => 1, Mouse_X => 50.0, Mouse_Y => 15.0, others => <>));
         Testing.Settle (Window);
         pragma Assert (Widgets.Sliders.Is_Dragging (Slider));
         declare
            Held : constant Float := Widgets.Sliders.Value (Slider);
         begin
            Options_VM.Advance (Model, 0.9);
            UI.Synchronize (Screen);
            pragma Assert (Widgets.Sliders.Value (Slider) = Held and then Options_VM.Fraction (Model) = 0.9);
         end;
         Testing.Feed
           (Window, (Kind => Pomarine.Events.Mouse_Up, Button => 1, Mouse_X => 50.0, Mouse_Y => 15.0, others => <>));
         Testing.Settle (Window);
         pragma Assert (not Widgets.Sliders.Is_Dragging (Slider) and then Widgets.Sliders.Value (Slider) = 0.9);
         Options_VM.Advance (Model, 0.75);
         UI.Synchronize (Screen);
         pragma Assert (Widgets.Sliders.Value (Slider) = 0.75);
         Widgets.Set_Visible (Menu, True);
         Testing.Settle (Window);
         Testing.Click_On (Window, "Second card");
         pragma Assert (Options_VM.Opened (Model) = 2);
         --  An out-of-range row is rejected by the model even if a widget event asks for it.
         Options_VM.Set_Cards (Model, 1);
         Widgets.Notify (Menu, Widgets.Choose, Row => 2);
         Testing.Settle (Window);
         pragma Assert (Options_VM.Opened (Model) = 2);
      end;
      --  Borrowed widgets survive teardown.
      pragma Assert (not Widgets.Is_Attached (Menu) and then not Widgets.Is_Attached (Slider));
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Menu);
      Widgets.Add (Root, Slider);
      Widgets.Notify (Menu, Widgets.Choose, Row => 1);
      Widgets.Sliders.Set_Value (Slider, 0.1);
      Widgets.Notify (Slider, Widgets.Change);
      Widgets.Update (Tree, 0);
      pragma Assert (Options_VM.Opened (Model) = 2 and then Options_VM.Fraction (Model) = 0.75);

   end Sliders_And_Menu_Events_Follow_The_Model;

   procedure Borrowed_Buttons_Follow_Flags is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Options_VM.Model;
      Borrowed : Widgets.Buttons.Button;
      Screen   : UI.View (Tree'Access);
      Window   : Testing.Session;
      Bound    : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
      Button   : constant UI.Button_Handle := Bound.Borrow_Button (Borrowed, Pick_Dark, Reflect => False);
   begin
      Widgets.Buttons.Configure (Borrowed, Widgets.Buttons.Looks ("Choose dark"));
      Bound.Selected_When (Button, Options_UI.Dark);
      Bound.Enabled_When (Button, Options_UI.Light);
      UI.Mount (Screen, UI.Column ([UI.Place (Button)]));
      Testing.Open (Window, Tree, 320, 200);
      pragma Assert (not Widgets.Buttons.Is_Selected (Borrowed));
      pragma Assert (not Testing.Is_Disabled (Window, "Choose dark"));
      Testing.Click_On (Window, "Choose dark");
      pragma Assert (Options_VM.Dark (Model));
      pragma Assert (Widgets.Buttons.Is_Selected (Borrowed));
      pragma Assert (Testing.Is_Disabled (Window, "Choose dark"));
      Options_VM.Execute (Model, Pick_Light);
      UI.Synchronize (Screen);
      pragma Assert (not Widgets.Buttons.Is_Selected (Borrowed));
      pragma Assert (not Testing.Is_Disabled (Window, "Choose dark"));
   end Borrowed_Buttons_Follow_Flags;

   procedure Borrowed_Placed_Forms_Wire_And_Place is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Options_VM.Model;
      Borrowed : Widgets.Buttons.Button;
      Card     : Widgets.Grips.Grip;
      Screen   : UI.View (Tree'Access);
      Window   : Testing.Session;
      Bound    : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
   begin
      Widgets.Buttons.Configure (Borrowed, Widgets.Buttons.Looks ("Choose dark"));
      UI.Mount
        (Screen,
         UI.Column
           ([Bound.Borrow_Button (Borrowed, Pick_Dark, Reflect => False, Tooltip => "Dark", Height => 40.0),
             UI.Styled
               (Bound.Borrow_Holding (Card, [Bound.Label ("Choose light")], Click => Pick_Light),
                (Height => 40.0, others => <>))]));
      Testing.Open (Window, Tree, 320, 200);
      pragma Assert (not Options_VM.Dark (Model));
      Testing.Click_On (Window, "Choose dark");
      pragma Assert (Options_VM.Dark (Model));
      Testing.Click_On (Window, "Choose light");
      pragma Assert (not Options_VM.Dark (Model));
   end Borrowed_Placed_Forms_Wire_And_Place;

   procedure Button_Captions_Follow_Text is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Options_VM.Model;
      Borrowed : Widgets.Buttons.Button;
   begin
      declare
         Screen    : UI.View (Tree'Access);
         Other     : UI.View (Tree'Access);
         Bound     : aliased Options.Context'Class := Options.Bind (Screen, Model'Access);
         Foreign   : constant Options.Context'Class := Options.Bind (Other, Model'Access);
         Window    : Testing.Session;
         Kept      : constant UI.Button_Handle := Bound.Borrow_Button (Borrowed, Pick_Dark);
         Owned     : constant UI.Button_Handle := Bound.Button ("Old caption", Pick_Light);
         Indexed   : constant UI.Button_Handle := Bound.Button ("Old indexed caption", Toggle_Sync);
         Elsewhere : constant UI.Button_Handle := Foreign.Button ("Other view", Pick_Dark);
         Words     : constant UI.Label_Handle := Bound.Label (Options_UI.Caption);
         Stale     : UI.Button_Handle;
         Rejected  : Boolean := False;
      begin
         Widgets.Buttons.Configure (Borrowed, Widgets.Buttons.Looks ("Old borrowed caption"));
         Bound.Caption_From (Kept, Options_UI.Caption);
         Bound.Caption_From (Owned, Options_UI.Caption);
         Bound.Caption_From (Indexed, Options_UI.Title, Index => 2);
         begin
            Bound.Caption_From (Elsewhere, Options_UI.Caption);
         exception
            when UI.Foreign_Handle =>
               Rejected := True;
         end;
         pragma Assert (Rejected);
         declare
            Part : Options.Component (Bound'Access);
         begin
            Stale := Part.Button ("Rolled back", Pick_Dark);
            Part.Caption_From (Stale, Options_UI.Caption);
         end;
         Rejected := False;
         begin
            Bound.Caption_From (Stale, Options_UI.Caption);
         exception
            when UI.Stale_Handle =>
               Rejected := True;
         end;
         pragma Assert (Rejected);
         UI.Mount (Screen, UI.Column ([UI.Place (Kept), UI.Place (Owned), UI.Place (Indexed), UI.Place (Words)]));
         Testing.Open (Window, Tree, 320, 240);
         pragma Assert (Widgets.Buttons.Label (Borrowed) = "Light command");
         pragma Assert (Testing.Exists (Window, "Card 2"));
         Testing.Click_On (Window, "Light command", Nth => 1);
         pragma Assert (Options_VM.Dark (Model));
         pragma Assert (Widgets.Buttons.Label (Borrowed) = "Dark command");
         pragma Assert (Testing.Exists (Window, "Dark command", Nth => 3));
         Testing.Click_On (Window, "Dark command", Nth => 2);
         pragma Assert (Options_VM.Light (Model));
         pragma Assert (Widgets.Buttons.Label (Borrowed) = "Light command");
      end;
      pragma Assert (not Widgets.Is_Attached (Borrowed));
   end Button_Captions_Follow_Text;

   procedure Menu_Descriptions_Are_Snapshots_And_Grow is
      package Menus renames Pomarine.Widgets.Menus;
      package Rows renames Pomarine.UI.Menus;
      Menu       : Menus.Menu;
      Content    : Rows.Content :=
        [Rows.Row (Menus.Heading, "Actions"),
         Rows.Row (Menus.Check, "Chosen", Checked => True),
         Rows.Row (Menus.Separator),
         Rows.Row (Menus.Action, "Unavailable", Allowed => False)];
      Long_Title : constant String (1 .. 700) := [others => 'x'];
   begin
      Rows.Set_Content (Menu, Content);
      pragma Assert (Menus.Row_Count (Menu) = 4);
      pragma Assert (Menus.Is_Checked (Menu, 2));
      pragma Assert (not Menus.Is_Enabled (Menu, 4));
      Content.Clear;
      pragma Assert (Menus.Text_Of (Menu, 2) = "Chosen");
      for Index in 1 .. 2_048 loop
         Content.Append (Rows.Row (Menus.Action, Long_Title & Index'Image));
      end loop;
      Rows.Set_Content (Menu, Content);
      pragma Assert (Menus.Row_Count (Menu) = 2_048);
      pragma Assert (Menus.Text_Of (Menu, 2_048) = Long_Title & " 2048");
      Rows.Set_Content (Menu, []);
      pragma Assert (Menus.Row_Count (Menu) = 0);
   end Menu_Descriptions_Are_Snapshots_And_Grow;

   procedure Replacing_Menu_Content_Cancels_A_Press is
      package Menus renames Pomarine.Widgets.Menus;
      package Rows renames Pomarine.UI.Menus;
      Tree    : aliased Widgets.Tree;
      Model   : aliased Options_VM.Model;
      Menu    : Menus.Menu;
      Screen  : UI.View (Tree'Access);
      Bound   : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
      Choices : constant UI.Widget_Handle := Bound.Borrow_Widget (Menu);
      Window  : Testing.Session;
   begin
      Options_VM.Set_Cards (Model, 2);
      Rows.Set_Content (Menu, [Rows.Row (Menus.Action, "First"), Rows.Row (Menus.Action, "Second")]);
      Bound.On_Event (Choices, Widgets.Choose, Open_Card, Index_From_Event => True);
      UI.Mount (Screen, UI.Column ([UI.Place (Choices, Width => 220.0, Height => 80.0)]));
      Testing.Open (Window, Tree, 320, 250);
      Testing.Feed (Window, (Kind => Pomarine.Events.Mouse_Move, Mouse_X => 30.0, Mouse_Y => 17.0, others => <>));
      Testing.Feed
        (Window, (Kind => Pomarine.Events.Mouse_Down, Button => 1, Mouse_X => 30.0, Mouse_Y => 17.0, others => <>));
      Testing.Settle (Window);
      pragma Assert (Menus.Hovered_Row (Menu) = 1);
      Rows.Set_Content (Menu, [Rows.Row (Menus.Action, "Replacement")]);
      pragma Assert (Menus.Row_Count (Menu) = 1 and then Menus.Hovered_Row (Menu) = 0);
      Testing.Feed
        (Window, (Kind => Pomarine.Events.Mouse_Up, Button => 1, Mouse_X => 30.0, Mouse_Y => 17.0, others => <>));
      Testing.Settle (Window);
      pragma Assert (Options_VM.Opened (Model) = 0);
      Testing.Click_On (Window, "Replacement");
      pragma Assert (Options_VM.Opened (Model) = 1);
      Rows.Set_Content (Menu, []);
      pragma Assert (Menus.Row_Count (Menu) = 0 and then Menus.Part_Count (Menu) = 0);
   end Replacing_Menu_Content_Cancels_A_Press;

   procedure Fragments_Keep_Siblings_And_Roll_Back is
      Tree                         : aliased Widgets.Tree;
      Root                         : Widgets.Panels.Panel;
      Anchor                       : Widgets.Labels.Label;
      First, Second, Nested, Later : Widgets.Labels.Label;
      Box                          : Widgets.Panels.Panel;
      Hosted                       : UI.Hosts.Host;
   begin
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Anchor);
      Hosted.Open (Root);
      declare
         Screen : UI.View renames Hosted.Screen.all;
         One    : constant UI.Layout := UI.Put (Screen, First);
         Two    : constant UI.Layout := UI.Put (Screen, Second);
         Child  : constant UI.Layout := UI.Put (Screen, Nested);
         Held   : constant UI.Layout := UI.Put_In (Screen, Box, [Child]);
         Whole  : constant UI.Layout := UI.Fragment (Screen, [One, Held, Two]);
      begin
         --  No wrapper: the three roots will be siblings of the original anchor.
         for Fail_After in 0 .. 3 loop
            UI.Inject_Fault (Screen, Fail_After);
            begin
               UI.Mount_Before (Screen, Anchor, Whole);
               raise Constraint_Error with "mount should fail";
            exception
               when Program_Error =>
                  null;
            end;
            pragma Assert (Widgets.Child_Count (Root) = 1);
            pragma Assert (not Widgets.Is_Attached (First) and then not Widgets.Is_Attached (Second));
            pragma Assert (not Widgets.Is_Attached (Box) and then not Widgets.Is_Attached (Nested));
         end loop;
         UI.Mount_Before (Screen, Anchor, Whole);
         pragma Assert (Widgets.Child_Count (Root) = 4);
         pragma Assert (Widgets.Parent_Of (First) = Root'Unrestricted_Access);
         pragma Assert (Widgets.Parent_Of (Nested) = Box'Unrestricted_Access);
         declare
            Part : constant UI.Layout := UI.Put (Screen, Later);
         begin
            UI.Inject_Fault (Screen, 1);
            begin
               UI.Mount_Before (Screen, Anchor, UI.Fragment (Screen, [Part, UI.Spacer (Screen)]));
               raise Constraint_Error with "late mount should fail";
            exception
               when Program_Error =>
                  null;
            end;
            pragma Assert (Widgets.Child_Count (Root) = 4 and then not Widgets.Is_Attached (Later));
            UI.Mount_Before (Screen, Anchor, Part);
            pragma Assert (Widgets.Child_Count (Root) = 5);
            Widgets.Remove (Later);
         end;
      end;
   end Fragments_Keep_Siblings_And_Roll_Back;

   procedure A_Radio_Pair_And_A_Switch_Follow_The_Model is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Options_VM.Model;
      Screen   : UI.View (Tree'Access);
      Window   : Testing.Session;
      Borrowed : Widgets.Labels.Label;
   begin
      declare
         Bound : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
         Part  : constant Parts := Build (Bound, Borrowed);
      begin
         UI.Mount (Screen, Part.Layout);
         pragma Assert (Checks.Is_Checked (UI.Widget_Of (Screen, Part.Light).all));
         pragma Assert (not Checks.Is_Checked (UI.Widget_Of (Screen, Part.Dark).all));
         pragma Assert (not Pomarine.Widgets.Switches.Is_On (UI.Widget_Of (Screen, Part.Sync).all));
         --  Only what is not running is shown at first.
         pragma Assert (Widgets.Is_Visible (UI.Widget_Of (Screen, Part.Start).all));
         pragma Assert (not Widgets.Is_Visible (UI.Widget_Of (Screen, Part.Bar).all));
         pragma Assert (not Widgets.Is_Visible (UI.Widget_Of (Screen, Part.Stop).all));
         pragma Assert (Widgets.Is_Attached (UI.Widget_Of (Screen, Part.Extra).all));
      end;

      Testing.Open (Window, Tree, 320, 300);
      Testing.Click_On (Window, "Dark");
      pragma Assert (Options_VM.Dark (Model));
      Testing.Settle (Window);
      Testing.Click_On (Window, "Sync");
      pragma Assert (Options_VM.Sync (Model));

      --  The model cannot take a click: the box is put back to what the model says.
      Options_VM.Lock_Sync (Model);
      Testing.Settle (Window);
      Testing.Click_On (Window, "Sync");
      Testing.Settle (Window);
      pragma Assert (Options_VM.Sync (Model));

      --  A job goes on: what is shown only then appears, the bar follows, and then goes.
      Testing.Click_On (Window, "Start");
      Testing.Settle (Window);
      pragma Assert (Options_VM.Running (Model));
      Options_VM.Advance (Model, 0.5);
      Testing.Settle (Window);
      Testing.Click_On (Window, "Finish");
      Testing.Settle (Window);
      pragma Assert (not Options_VM.Running (Model));
   end A_Radio_Pair_And_A_Switch_Follow_The_Model;

   procedure Handles_Stale_After_The_View is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Options_VM.Model;
      Borrowed : Widgets.Labels.Label;
      Saved    : Parts;
   begin
      declare
         Screen : UI.View (Tree'Access);
         Bound  : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
      begin
         Saved := Build (Bound, Borrowed);
         UI.Mount (Screen, Saved.Layout);
         pragma
           Assert
             (UI.Is_Live (Screen, Saved.Dark)
                and then UI.Is_Live (Screen, Saved.Sync)
                and then UI.Is_Live (Screen, Saved.Bar)
                and then UI.Is_Live (Screen, Saved.Extra));
         pragma Assert (UI.Live_Controls (Screen) = 7);
      end;
      --  The borrowed label is still the application's, and out of the tree.
      pragma Assert (not Widgets.Is_Attached (Borrowed));
   end Handles_Stale_After_The_View;

   --  A view mounted into a panel of the application's, which keeps the root and the validator.

   type Host_Judge is limited new Widgets.Validator with record
      Screen : access UI.View;
   end record;

   overriding
   function Validate (Self : Host_Judge; Tag : Integer; Index : Natural) return Widgets.Command_State
   is (if UI.Owns_Tag (Self.Screen.all, Tag) then UI.Command_State (Self.Screen.all, Tag, Index) else Widgets.Enabled);

   procedure A_View_Can_Live_In_A_Panel_Of_The_Application is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Options_VM.Model;
      Borrowed : Widgets.Labels.Label;
      Root     : Widgets.Panels.Panel;
      Window   : Testing.Session;
      Judge    : aliased Host_Judge;
   begin
      Widgets.Set_Root (Tree, Root);
      declare
         Screen : aliased UI.View (Tree'Access);
      begin
         Judge.Screen := Screen'Unchecked_Access;
         Widgets.Set_Validator (Tree, Judge'Unchecked_Access);
         UI.Use_Tags_From (Screen, 1000);
         declare
            Bound : aliased constant Options.Context'Class := Options.Bind (Screen, Model'Access);
            Part  : constant Parts := Build (Bound, Borrowed);
         begin
            UI.Mount_Into (Screen, Root, Part.Layout);
            pragma Assert (UI.Is_Mounted (Screen));
            pragma Assert (UI.Screen_Panel (Screen) /= null);
            pragma Assert (Widgets.Parent_Of (UI.Screen_Panel (Screen).all) /= null);
            --  A component made after the screen is mounted goes in front of it.
            declare
               Later : aliased Options.Component (Bound'Access);
               Words : constant UI.Label_Handle := Later.Label (Options_UI.Title, 1);
            begin
               Later.Commit;
               UI.Mount_Before (Screen, UI.Screen_Panel (Screen).all, UI.Place (Words));
            end;
            pragma Assert (Widgets.Child_Count (Root) = 2);
            Testing.Open (Window, Tree, 320, 300);
            pragma Assert (Testing.Shows (Window, "Card 1"));
            pragma Assert (Testing.Is_Disabled (Window, "Light"));
            Testing.Click_On (Window, "Dark");
            pragma Assert (Options_VM.Dark (Model));
            --  The model changes by itself, and the application has the view shown it.
            Options_VM.Lock_Sync (Model);
            UI.Synchronize (Screen);
            Widgets.Set_Visible (UI.Screen_Panel (Screen).all, False);
            Testing.Settle (Window);
            pragma Assert (not Testing.Exists (Window, "Dark"));
         end;
         Widgets.Set_Validator (Tree, Widgets.Command_Validator'(null));
      end;
      --  The root is the application's still, with nothing left in it.
      pragma Assert (Widgets.Child_Count (Root) = 0);
   end A_View_Can_Live_In_A_Panel_Of_The_Application;

   procedure Cards_Are_Repeated_Components_Of_One_Model is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Options_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
      Cards  : UI.Layout_Array (1 .. 3);
   begin
      Options_VM.Set_Cards (Model, 2);
      declare
         Bound : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
      begin
         for Row in Cards'Range loop
            declare
               Grip  : constant UI.Grip_Handle :=
                 Bound.Grip
                   ((Fill => Pomarine.Themes.Tint, Pointer => True, others => <>),
                    Open_Card,
                    Row,
                    Name => "Open" & Row'Image);
               Words : constant UI.Label_Handle := Bound.Label (Options_UI.Title, Row);
               Card  : constant UI.Layout :=
                 UI.Styled (UI.Hold (Grip, [UI.Place (Words)]), (Height => 40.0, Width => 200.0, others => <>));
            begin
               Bound.Show_When (Card, Options_UI.Has_Card, Row);
               Cards (Row) := Card;
            end;
         end loop;
         UI.Mount (Screen, UI.Column (Cards));
      end;
      Testing.Open (Window, Tree, 320, 300);
      pragma Assert (Testing.Exists (Window, "Open 1") and then Testing.Exists (Window, "Open 2"));
      pragma Assert (not Testing.Exists (Window, "Open 3"));
      pragma Assert (Testing.Shows (Window, "Card 2"));
      Testing.Click_On (Window, "Open 2");
      pragma Assert (Options_VM.Opened (Model) = 2);
      --  The model grows by itself: the third card is there.
      Options_VM.Set_Cards (Model, 3);
      Testing.Settle (Window);
      pragma Assert (Testing.Exists (Window, "Open 3"));
      Testing.Click_On (Window, "Open 3");
      pragma Assert (Options_VM.Opened (Model) = 3);
   end Cards_Are_Repeated_Components_Of_One_Model;

   type Counter is limited new UI.Observer with record
      Turns : Natural := 0;
   end record;

   overriding
   procedure Turned (Self : in out Counter) is
   begin
      Self.Turns := Self.Turns + 1;
   end Turned;

   --  A turn that changed what the widgets show is told to the application; a bar that moves is taken out with
   --  what is in it and put again; a control that is given the focus when its flag turns true.
   procedure A_Turn_Is_Told_And_A_Bar_Can_Move is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Options_VM.Model;
      Root   : Widgets.Panels.Panel;
      Other  : Widgets.Panels.Panel;
      Bar    : Widgets.Panels.Panel;
      Words  : Widgets.Labels.Label;
      Window : Testing.Session;
      Watch  : aliased Counter;
   begin
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Other);
      declare
         Screen : aliased UI.View (Tree'Access);
         Bound  : constant Options.Context'Class := Options.Bind (Screen, Model'Access);
         Light  : constant UI.Check_Handle := Bound.Check ("Light", Options_UI.Light, Pick_Light, Form => Checks.Radio);
         Dark   : constant UI.Check_Handle := Bound.Check ("Dark", Options_UI.Dark, Pick_Dark, Form => Checks.Radio);
         Where  : constant UI.Layout := UI.Column ([UI.Place (Light), UI.Place (Dark)]);
      begin
         UI.Observe (Screen, Watch'Access);
         UI.Mount_Into (Screen, Root, Where);
         Testing.Open (Window, Tree, 320, 300);
         declare
            Before : constant Natural := Watch.Turns;
         begin
            Testing.Click_On (Window, "Dark");
            pragma Assert (Watch.Turns > Before);
         end;

         --  The same widgets, put in a bar, then taken out and put in the other panel.
         declare
            First : constant UI.Layout :=
              UI.Put_In (Screen, Bar, [UI.Put (Screen, Words)], Flow => Pomarine.UI.Layouts.Row);
         begin
            UI.Mount_Into (Screen, Root, First);
            pragma Assert (Widgets.Is_Attached (Bar) and then Widgets.Is_Attached (Words));
            Widgets.Remove (Bar);
            pragma Assert (not Widgets.Is_Attached (Words));
            UI.Mount_Into
              (Screen, Other, UI.Put_In (Screen, Bar, [UI.Put (Screen, Words)], Flow => Pomarine.UI.Layouts.Row));
            pragma Assert (Widgets.Is_Attached (Words) and then Widgets.Parent_Of (Words) /= null);
         end;
      end;
   end A_Turn_Is_Told_And_A_Bar_Can_Move;

begin
   Typed_Event_Bindings_Check_Identity;
   List_Events_Route_Rows_And_Actions;
   Editor_Hooks_Route_Tools_And_Links;
   Canvas_Hooks_Are_Bound_Once_To_A_Canvas;
   Sliders_And_Menu_Events_Follow_The_Model;
   Borrowed_Buttons_Follow_Flags;
   Borrowed_Placed_Forms_Wire_And_Place;
   Button_Captions_Follow_Text;
   Menu_Descriptions_Are_Snapshots_And_Grow;
   Replacing_Menu_Content_Cancels_A_Press;
   Fragments_Keep_Siblings_And_Roll_Back;
   A_Turn_Is_Told_And_A_Bar_Can_Move;
   Cards_Are_Repeated_Components_Of_One_Model;
   A_View_Can_Live_In_A_Panel_Of_The_Application;
   A_Radio_Pair_And_A_Switch_Follow_The_Model;
   Handles_Stale_After_The_View;
end UI_Controls_Test;
