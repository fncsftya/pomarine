with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with SDL3.Events;
with SDL3.Windows.Renderers;
with Goldens;
with Pomarine.Icons;
with Pomarine.Models;
with Pomarine.Scrollbars;
with Pomarine.Semantics;
with Pomarine.Themes;
with Pomarine.Widgets.Lists;
with Pomarine.Widgets.Panels;
with Yoga.Nodes;

package body List_Tests is

   package Widgets renames Pomarine.Widgets;
   package Lists renames Pomarine.Widgets.Lists;
   package Models renames Pomarine.Models;
   package Semantics renames Pomarine.Semantics;
   package Events renames SDL3.Events;
   package Renderers renames SDL3.Windows.Renderers;
   package Images renames Goldens.Images;
   package Nodes renames Yoga.Nodes;

   use Ada.Strings.Unbounded;

   Density : constant Float := 1.0;
   Row_High : constant Float := 20.0;
   --  In points: of the rows of the lists here, and the box is 100 high, so
   --  five show.

   function Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   --  A model of as many rows as it is told, that makes them up when asked
   --  and counts how often it is.

   Asked : Natural := 0;
   --  How many times a row was asked for.

   type Made_Up (Rows : Natural) is limited new Models.List_Model with null record;

   overriding function Count (Self : Made_Up) return Natural is (Self.Rows);
   overriding function Version (Self : Made_Up) return Natural is (0);
   overriding function Row_Id (Self : Made_Up; Row : Positive) return Positive is (Row);
   overriding procedure Describe_Row
     (Self : Made_Up; Row : Positive; Content : out Models.Row_Content);

   overriding procedure Describe_Row
     (Self : Made_Up; Row : Positive; Content : out Models.Row_Content)
   is
      pragma Unreferenced (Self);
   begin
      Asked := Asked + 1;
      Content := (others => <>);
      Models.Set_Text (Content, "Row " & Image (Row));
      Models.Set_Detail (Content, Image (Row * 10));
   end Describe_Row;

   type Fixture (Rows : Natural) is limited record
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Model  : aliased Made_Up (Rows);
      Root   : aliased Widgets.Panels.Panel;
      Rows_Box : aliased Lists.List;
   end record;

   procedure Open (Item : in out Fixture; Wide : Float := 200.0) is
   begin
      Renderers.Create_Offscreen (Item.Target, Positive (Wide), 100);
      Widgets.Set_Density (Item.Tree, Density);
      Widgets.Set_Reduced_Motion (Item.Tree, True);
      --  So that what is chosen is in view at once, not as it moves there.
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Rows_Box);
      Lists.Set_Model (Item.Rows_Box, Item.Model'Unchecked_Access);
      Lists.Set_Row_Height (Item.Rows_Box, Row_High);
      Nodes.Set_Flex_Grow (Widgets.Node (Item.Rows_Box), 1.0);
      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   procedure Wheel (Item : in out Fixture; Notches : Float) is
      Handled : Boolean;
   begin
      Widgets.Dispatch
        (Item.Tree,
         (Kind => Events.Mouse_Wheel, Mouse_X => 50.0, Mouse_Y => 50.0, Wheel_Y => Notches, others => <>),
         Handled);
   end Wheel;

   procedure Click_Row (Item : in out Fixture; Y : Float; Clicks : Natural := 1) is
      Handled : Boolean;
   begin
      Widgets.Dispatch
        (Item.Tree, (Kind => Events.Mouse_Move, Mouse_X => 50.0, Mouse_Y => Y, others => <>), Handled);
      Widgets.Dispatch
        (Item.Tree,
         (Kind => Events.Mouse_Down, Mouse_X => 50.0, Mouse_Y => Y, Button => 1, Clicks => Clicks,
          others => <>), Handled);
      Widgets.Dispatch
        (Item.Tree,
         (Kind => Events.Mouse_Up, Mouse_X => 50.0, Mouse_Y => Y, Button => 1, others => <>), Handled);
   end Click_Row;

   procedure Press (Item : in out Fixture; Key : Events.Key_Code) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Item.Tree, (Kind => Events.Key_Down, Key => Key, others => <>), Handled);
   end Press;

   procedure Few_Rows_Asked is
      Item : Fixture (100_000);
   begin
      Asked := 0;
      Open (Item);
      Goldens.Check_Text
        ("lists-shown", "1 5",
         Image (Lists.First_Shown (Item.Rows_Box)) & " " & Image (Lists.Last_Shown (Item.Rows_Box)));

      Widgets.Paint (Item.Tree, Item.Target, Pomarine.Themes.Light);
      Goldens.Check_Text ("lists-asked", "TRUE", Boolean'Image (Asked in 5 .. 7));

      --  A hundred thousand rows, and a screenful scrolled to.
      Wheel (Item, -100.0);
      Widgets.Paint (Item.Tree, Item.Target, Pomarine.Themes.Light);
      Goldens.Check_Text
        ("lists-scrolled", "TRUE", Boolean'Image (Lists.First_Shown (Item.Rows_Box) > 100
                                                  and then Lists.Last_Shown (Item.Rows_Box)
                                                           - Lists.First_Shown (Item.Rows_Box) <= 5));
   end Few_Rows_Asked;

   procedure Choosing is
      Item : Fixture (50);
      Seen : Natural := 0;
   begin
      Open (Item);
      Click_Row (Item, 50.0);  --  the third
      Goldens.Check_Text ("lists-clicked", "3", Image (Lists.Selected (Item.Rows_Box)));

      --  Scrolled, a click is on another row.
      Wheel (Item, -2.0);
      Click_Row (Item, 10.0);
      Goldens.Check_Text
        ("lists-clicked-scrolled", "TRUE",
         Boolean'Image (Lists.Selected (Item.Rows_Box) = Lists.First_Shown (Item.Rows_Box)));

      --  The application chooses one: it comes into view.
      Lists.Select_Row (Item.Rows_Box, 40);
      Goldens.Check_Text
        ("lists-revealed", "TRUE",
         Boolean'Image (Lists.Last_Shown (Item.Rows_Box) >= 40
                        and then Lists.First_Shown (Item.Rows_Box) <= 40));
      pragma Unreferenced (Seen);
   end Choosing;

   procedure Keys is
      Item : Fixture (50);
   begin
      Open (Item);
      Widgets.Focus (Item.Rows_Box);
      Press (Item, Events.Key_Down_Arrow);
      Press (Item, Events.Key_Down_Arrow);
      Goldens.Check_Text ("lists-down", "2", Image (Lists.Selected (Item.Rows_Box)));
      Press (Item, Events.Key_Up_Arrow);
      Goldens.Check_Text ("lists-up", "1", Image (Lists.Selected (Item.Rows_Box)));
      Press (Item, Events.Key_Up_Arrow);
      Goldens.Check_Text ("lists-top", "1", Image (Lists.Selected (Item.Rows_Box)));
      Press (Item, Events.Key_End);
      Goldens.Check_Text ("lists-end", "50 46", Image (Lists.Selected (Item.Rows_Box)) & " "
                          & Image (Lists.First_Shown (Item.Rows_Box)));
      Press (Item, Events.Key_Home);
      Goldens.Check_Text ("lists-home", "1 1", Image (Lists.Selected (Item.Rows_Box)) & " "
                          & Image (Lists.First_Shown (Item.Rows_Box)));
      Press (Item, Events.Key_Page_Down);
      Goldens.Check_Text ("lists-page", "5", Image (Lists.Selected (Item.Rows_Box)));
   end Keys;

   procedure Rows_Come_And_Go is
      Rows   : aliased Models.Text_List (10);
      Tree   : Widgets.Tree;
      Target : Renderers.Renderer;
      Root   : aliased Widgets.Panels.Panel;
      Shown  : aliased Lists.List;
   begin
      Renderers.Create_Offscreen (Target, 200, 100);
      Widgets.Set_Reduced_Motion (Tree, True);
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Shown);
      Models.Append (Rows, "Ash");
      Models.Append (Rows, "Birch");
      Models.Append (Rows, "Cedar");
      Lists.Set_Model (Shown, Rows'Unchecked_Access);
      Nodes.Set_Flex_Grow (Widgets.Node (Shown), 1.0);
      Widgets.Layout (Tree, Target);

      Lists.Select_Row (Shown, 2);
      --  A row before it goes: it is still the chosen, now first of the two.
      Models.Delete (Rows, 1);
      Widgets.Update (Tree, 0);
      Goldens.Check_Text ("lists-follows-row", "1", Image (Lists.Selected (Shown)));

      --  The chosen goes: none is.
      Models.Delete (Rows, 1);
      Widgets.Update (Tree, 0);
      Goldens.Check_Text ("lists-chosen-gone", "0", Image (Lists.Selected (Shown)));
   end Rows_Come_And_Go;

   type Notes is limited new Widgets.Semantic_Sink with record
      Said : Unbounded_String;
   end record;

   overriding procedure Begin_Update
     (Self : in out Notes; Root, Focused : Widgets.Node_Id; Whole : Boolean);
   overriding procedure Describe_Node
     (Self     : in out Notes;
      Id       : Widgets.Node_Id;
      Facts    : Semantics.Description;
      Bounds   : Semantics.Rectangle;
      Children : Widgets.Node_Id_Array);
   overriding procedure End_Update (Self : in out Notes);

   overriding procedure Begin_Update
     (Self : in out Notes; Root, Focused : Widgets.Node_Id; Whole : Boolean) is
      pragma Unreferenced (Root, Focused, Whole);
   begin
      Self.Said := Null_Unbounded_String;
   end Begin_Update;

   overriding procedure Describe_Node
     (Self     : in out Notes;
      Id       : Widgets.Node_Id;
      Facts    : Semantics.Description;
      Bounds   : Semantics.Rectangle;
      Children : Widgets.Node_Id_Array)
   is
      pragma Unreferenced (Id, Bounds);
   begin
      if Facts.Kind in Semantics.List | Semantics.List_Item | Semantics.Button then
         Append (Self.Said, Semantics.Image (Facts.Kind) & " '" & Semantics.To_String (Facts.Name)
                 & "' " & Image (Facts.Position) & "/" & Image (Facts.Set_Size)
                 & (if Facts.Selected then " selected" else "")
                 & " children=" & Image (Children'Length) & ASCII.LF);
      end if;
   end Describe_Node;

   overriding procedure End_Update (Self : in out Notes) is
   begin
      null;
   end End_Update;

   procedure Described is
      Item  : Fixture (100_000);
      Heard : Notes;
      Done  : Boolean;
   begin
      Open (Item);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Goldens.Check_Text
        ("lists-described",
         "list '' 0/100000 children=5" & ASCII.LF
         & "list item 'Row 1' 1/100000 children=0" & ASCII.LF
         & "list item 'Row 2' 2/100000 children=0" & ASCII.LF
         & "list item 'Row 3' 3/100000 children=0" & ASCII.LF
         & "list item 'Row 4' 4/100000 children=0" & ASCII.LF
         & "list item 'Row 5' 5/100000 children=0" & ASCII.LF,
         To_String (Heard.Said));

      --  Pressed, the row is chosen.
      Widgets.Act (Item.Tree, Widgets.Part_Id (Item.Rows_Box, 3),
                   (Doing => Semantics.Click, others => <>), Done);
      Goldens.Check_Text ("lists-pressed", "TRUE3", Done'Image & Image (Lists.Selected (Item.Rows_Box)));

      --  Brought into view, a row far down is.
      Widgets.Act (Item.Tree, Widgets.Part_Id (Item.Rows_Box, 400),
                   (Doing => Semantics.Scroll_Into_View, others => <>), Done);
      Goldens.Check_Text
        ("lists-scrolled-into-view", "TRUE TRUE", Done'Image & " "
         & Boolean'Image (Lists.First_Shown (Item.Rows_Box) <= 400
                          and then Lists.Last_Shown (Item.Rows_Box) >= 400));
   end Described;

   procedure Drawn is
      Item : Fixture (30);
      Picture : Images.Image;
   begin
      Open (Item);
      Lists.Select_Row (Item.Rows_Box, 2);
      Widgets.Focus (Item.Rows_Box);
      Widgets.Paint (Item.Tree, Item.Target, Pomarine.Themes.Light);
      Images.Read (Picture, Item.Target);
      Goldens.Check ("lists-picture", Picture);
   end Drawn;

   --  Rows with buttons at their ends

   type With_Buttons is limited new Models.List_Model with null record;

   overriding function Count (Self : With_Buttons) return Natural is (4);
   overriding function Version (Self : With_Buttons) return Natural is (0);
   overriding function Row_Id (Self : With_Buttons; Row : Positive) return Positive is (Row);
   overriding procedure Describe_Row
     (Self : With_Buttons; Row : Positive; Content : out Models.Row_Content);

   overriding procedure Describe_Row
     (Self : With_Buttons; Row : Positive; Content : out Models.Row_Content)
   is
      pragma Unreferenced (Self);
   begin
      Content := (others => <>);
      Models.Set_Text (Content, "Row " & Image (Row));
      Content.Dimmed := Row = 2;
      Models.Set_Action (Content, 1, Pomarine.Icons.Check, "Hide");
      if Row /= 3 then
         Models.Set_Action (Content, 2, Pomarine.Icons.Close, "Remove", Danger => True);
      end if;
   end Describe_Row;

   type Heard_Acts is limited new Widgets.Listener with record
      Count  : Natural := 0;
      Row    : Natural := 0;
      Action : Natural := 0;
   end record;

   overriding procedure Handle_Event
     (Self   : in out Heard_Acts;
      Source : in out Widgets.Widget'Class;
      Event  : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
      use type Widgets.Event_Kind;
   begin
      if Event.Kind = Widgets.Act then
         Self.Count := Self.Count + 1;
         Self.Row := Event.Row;
         Self.Action := Event.Action;
      end if;
   end Handle_Event;

   procedure Row_Buttons is
      Tree    : Widgets.Tree;
      Target  : Renderers.Renderer;
      Root    : aliased Widgets.Panels.Panel;
      Shown   : aliased Lists.List;
      Model   : aliased With_Buttons;
      Hearer  : aliased Heard_Acts;
      Heard   : Notes;
      Handled : Boolean;
      Done    : Boolean;
      Right   : constant Float := 200.0 - Pomarine.Scrollbars.Thickness;
      --  Where the buttons end, and each is a row high (20) square.

      procedure Click_At (X, Y : Float) is
      begin
         Widgets.Dispatch
           (Tree, (Kind => Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, others => <>), Handled);
         Widgets.Dispatch
           (Tree, (Kind => Events.Mouse_Down, Mouse_X => X, Mouse_Y => Y, Button => 1, Clicks => 1,
                   others => <>), Handled);
         Widgets.Dispatch
           (Tree, (Kind => Events.Mouse_Up, Mouse_X => X, Mouse_Y => Y, Button => 1, others => <>),
            Handled);
      end Click_At;
   begin
      Renderers.Create_Offscreen (Target, 200, 100);
      Widgets.Set_Density (Tree, Density);
      Widgets.Set_Reduced_Motion (Tree, True);
      Widgets.Set_Listener (Tree, Hearer'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Widgets.Add (Root, Shown);
      Lists.Set_Model (Shown, Model'Unchecked_Access);
      Lists.Set_Row_Height (Shown, Row_High);
      Nodes.Set_Flex_Grow (Widgets.Node (Shown), 1.0);
      Widgets.Layout (Tree, Target);

      --  The second button of the second row (two buttons: the last).
      Click_At (Right - 10.0, 30.0);
      Goldens.Check_Text
        ("lists-button", "1 2 2 0",
         Image (Hearer.Count) & " " & Image (Hearer.Row) & " " & Image (Hearer.Action) & " "
         & Image (Lists.Selected (Shown)));

      --  The third row has one button, at the end: the first.
      Click_At (Right - 10.0, 50.0);
      Goldens.Check_Text
        ("lists-button-alone", "2 3 1", Image (Hearer.Count) & " " & Image (Hearer.Row) & " "
         & Image (Hearer.Action));

      --  Beside the buttons, the row is chosen as always, and no button says.
      Click_At (50.0, 30.0);
      Goldens.Check_Text
        ("lists-beside-buttons", "2 2", Image (Hearer.Count) & " " & Image (Lists.Selected (Shown)));

      --  To an assistive technology: four rows, and seven buttons, each one.
      Widgets.Describe_Changes (Tree, Heard);
      Goldens.Check_Text
        ("lists-button-parts", "TRUE",
         Boolean'Image (Ada.Strings.Fixed.Count (To_String (Heard.Said), "button 'Hide'") = 4
                        and then Ada.Strings.Fixed.Count (To_String (Heard.Said), "button 'Remove'") = 3));
      Widgets.Act (Tree, Widgets.Part_Id (Shown, Lists.Button_Part (2, 1)),
                   (Doing => Semantics.Click, others => <>), Done);
      Goldens.Check_Text ("lists-button-pressed", "TRUE 3", Done'Image & " " & Image (Hearer.Count));
      --  By keys: Space does the first button of the row chosen, and Delete
      --  the one that cannot be undone, if it has one.
      Lists.Select_Row (Shown, 2);
      Widgets.Focus (Shown);
      Widgets.Dispatch (Tree, (Kind => Events.Key_Down, Key => Events.Key_Space, others => <>), Handled);
      Goldens.Check_Text
        ("lists-key-first-button", "4 2 1", Image (Hearer.Count) & " " & Image (Hearer.Row) & " "
         & Image (Hearer.Action));
      Widgets.Dispatch (Tree, (Kind => Events.Key_Down, Key => Events.Key_Delete, others => <>), Handled);
      Goldens.Check_Text
        ("lists-key-danger-button", "5 2 2", Image (Hearer.Count) & " " & Image (Hearer.Row) & " "
         & Image (Hearer.Action));
      Lists.Select_Row (Shown, 3);
      Widgets.Dispatch (Tree, (Kind => Events.Key_Down, Key => Events.Key_Delete, others => <>), Handled);
      Goldens.Check_Text
        ("lists-key-none-to-do", "5 FALSE", Image (Hearer.Count) & " " & Handled'Image);
      Widgets.Paint (Tree, Target, Pomarine.Themes.Light);
   end Row_Buttons;

end List_Tests;
