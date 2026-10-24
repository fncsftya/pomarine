with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with SDL3.Windows.Renderers;
with Goldens;
with Hearers;
with Pomarine.Semantics;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Menus;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Sliders;
with Pomarine.Line_Texts;
with Yoga.Nodes;

package body Semantic_Tests is

   package Widgets renames Pomarine.Widgets;
   package Semantics renames Pomarine.Semantics;
   package Renderers renames SDL3.Windows.Renderers;
   package Nodes renames Yoga.Nodes;
   package Strings renames Ada.Strings.Unbounded;

   use Strings;
   use type Semantics.Toggle;
   use type Widgets.Node_Id;
   use type Widgets.Widget_Access;

   --  A sink that writes down what it is told, a line to a node.

   type Notes is limited new Widgets.Semantic_Sink with record
      Said    : Unbounded_String;
      Updates : Natural := 0;
      Nodes   : Natural := 0;
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
   begin
      Self.Said := Null_Unbounded_String;
      Self.Nodes := 0;
      Self.Updates := Self.Updates + 1;
      Append (Self.Said, (if Whole then "whole" else "changes")
              & " focus=" & Widgets.Image (Focused)
              & (if Focused = Root then " (root)" else "") & ASCII.LF);
   end Begin_Update;

   overriding procedure Describe_Node
     (Self     : in out Notes;
      Id       : Widgets.Node_Id;
      Facts    : Semantics.Description;
      Bounds   : Semantics.Rectangle;
      Children : Widgets.Node_Id_Array)
   is
      pragma Unreferenced (Bounds);
   begin
      Self.Nodes := Self.Nodes + 1;
      Append (Self.Said, Semantics.Image (Facts.Kind));
      if Semantics.Is_Named (Facts) then
         Append (Self.Said, " '" & Semantics.To_String (Facts.Name) & "'");
      end if;
      if Semantics.Length (Facts.Value) > 0 then
         Append (Self.Said, " =" & Semantics.To_String (Facts.Value));
      end if;
      if Facts.Disabled then
         Append (Self.Said, " disabled");
      end if;
      if Facts.Checked /= Semantics.Not_Toggled then
         Append (Self.Said, " " & Facts.Checked'Image);
      end if;
      Append (Self.Said, " children=" & Ada.Strings.Fixed.Trim (Children'Length'Image, Ada.Strings.Left));
      Append (Self.Said, " [" & Widgets.Image (Id) & "]" & ASCII.LF);
   end Describe_Node;

   overriding procedure End_Update (Self : in out Notes) is
   begin
      null;
   end End_Update;

   Density : constant Float := 1.0;

   type Fixture is limited record
      Tree   : Widgets.Tree;
      Ears   : aliased Hearers.Hearer;
      Target : Renderers.Renderer;
      Root   : aliased Widgets.Panels.Panel;
      Bar    : aliased Widgets.Panels.Panel;
      Title  : aliased Widgets.Labels.Label;
      Save   : aliased Widgets.Buttons.Button;
      Wrap   : aliased Widgets.Checks.Check;
      Volume : aliased Widgets.Sliders.Slider;
      Pop    : aliased Widgets.Menus.Menu;
   end record;

   procedure Open (Item : in out Fixture) is
   begin
      Renderers.Create_Offscreen (Item.Target, 300, 200);
      Widgets.Set_Density (Item.Tree, Density);
      Widgets.Set_Listener (Item.Tree, Item.Ears'Unchecked_Access);
      Widgets.Set_Root (Item.Tree, Item.Root);
      Widgets.Add (Item.Root, Item.Title, Item.Bar);
      Widgets.Add (Item.Bar, Item.Save, Item.Wrap, Item.Volume);
      Widgets.Add (Item.Root, Item.Pop);
      Widgets.Set_Title (Item.Tree, "Podcast");
      Widgets.Labels.Set_Text (Item.Title, "Episode one");
      Widgets.Labels.Set_Style (Item.Title, Pomarine.Line_Texts.Heading);
      Widgets.Buttons.Set_Label (Item.Save, "Save");
      Widgets.Checks.Set_Label (Item.Wrap, "Wrap");
      Widgets.Sliders.Set_Value (Item.Volume, 0.5);
      Widgets.Set_Accessible_Name (Item.Volume, "Volume");
      Widgets.Menus.Add (Item.Pop, Widgets.Menus.Heading, "File");
      Widgets.Menus.Add (Item.Pop, Widgets.Menus.Action, "Open");
      Widgets.Menus.Add (Item.Pop, Widgets.Menus.Check, "Autosave", Checked => True);
      Widgets.Set_Visible (Item.Pop, False);
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Root), Yoga.Column);
      Nodes.Set_Flex_Direction (Widgets.Node (Item.Bar), Yoga.Row);
      Nodes.Set_Height (Widgets.Node (Item.Bar), 32.0);
      Nodes.Set_Width (Widgets.Node (Item.Save), 80.0);
      Nodes.Set_Width (Widgets.Node (Item.Wrap), 80.0);
      Nodes.Set_Width (Widgets.Node (Item.Volume), 80.0);
      Widgets.Layout (Item.Tree, Item.Target);
   end Open;

   procedure Whole_Tree is
      Item  : Fixture;
      Heard : Notes;
   begin
      Open (Item);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Goldens.Check_Text
        ("semantics-whole",
         "whole focus=1.1 (root)" & ASCII.LF
         & "window 'Podcast' children=2 [1.1]" & ASCII.LF
         & "heading 'Episode one' children=0 [2.1]" & ASCII.LF
         & "group children=3 [3.1]" & ASCII.LF
         & "button 'Save' children=0 [4.1]" & ASCII.LF
         & "check box 'Wrap' OFF children=0 [5.1]" & ASCII.LF
         & "slider 'Volume' =50% children=0 [6.1]" & ASCII.LF,
         To_String (Heard.Said));
   end Whole_Tree;

   procedure Only_Changes is
      Item  : Fixture;
      Heard : Notes;
   begin
      Open (Item);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Goldens.Check_Text
        ("semantics-quiet", "changes focus=1.1 (root)" & ASCII.LF,
         To_String (Heard.Said));

      Widgets.Buttons.Set_Label (Item.Save, "Save all");
      Widgets.Checks.Set_Checked (Item.Wrap, True);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Goldens.Check_Text
        ("semantics-changed",
         "changes focus=1.1 (root)" & ASCII.LF
         & "button 'Save all' children=0 [4.1]" & ASCII.LF
         & "check box 'Wrap' ON children=0 [5.1]" & ASCII.LF,
         To_String (Heard.Said));
   end Only_Changes;

   procedure Hiding_And_Showing is
      Item  : Fixture;
      Heard : Notes;
   begin
      Open (Item);
      Widgets.Describe_Changes (Item.Tree, Heard);

      Widgets.Set_Visible (Item.Bar, False);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Goldens.Check_Text
        ("semantics-hidden",
         "changes focus=1.1 (root)" & ASCII.LF
         & "window 'Podcast' children=1 [1.1]" & ASCII.LF,
         To_String (Heard.Said));

      --  Shown again, what was in it is told again, though it did not change.
      Widgets.Set_Visible (Item.Bar, True);
      Widgets.Layout (Item.Tree, Item.Target);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Goldens.Check_Text
        ("semantics-shown",
         "changes focus=1.1 (root)" & ASCII.LF
         & "window 'Podcast' children=2 [1.1]" & ASCII.LF
         & "group children=3 [3.1]" & ASCII.LF
         & "button 'Save' children=0 [4.1]" & ASCII.LF
         & "check box 'Wrap' OFF children=0 [5.1]" & ASCII.LF
         & "slider 'Volume' =50% children=0 [6.1]" & ASCII.LF,
         To_String (Heard.Said));

      Widgets.Hide_From_Accessibility (Item.Title);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Goldens.Check_Text
        ("semantics-hidden-from",
         "changes focus=1.1 (root)" & ASCII.LF
         & "window 'Podcast' children=1 [1.1]" & ASCII.LF,
         To_String (Heard.Said));
   end Hiding_And_Showing;

   procedure Actions is
      Item    : Fixture;
      Heard   : Notes;
      Done    : Boolean;
      Clicked : Boolean;
   begin
      Open (Item);
      Widgets.Describe_Changes (Item.Tree, Heard);

      Widgets.Act (Item.Tree, Widgets.Id_Of (Item.Save), (Doing => Semantics.Click, others => <>), Done);
      Hearers.Take (Item.Ears, Item.Save, Widgets.Click, Clicked);
      Goldens.Check_Text ("semantics-click", "TRUE TRUE", Done'Image & " " & Clicked'Image);

      Widgets.Act (Item.Tree, Widgets.Id_Of (Item.Wrap), (Doing => Semantics.Click, others => <>), Done);
      Goldens.Check_Text ("semantics-toggled", "TRUE TRUE",
                          Done'Image & " " & Widgets.Checks.Is_Checked (Item.Wrap)'Image);

      Widgets.Act (Item.Tree, Widgets.Id_Of (Item.Volume),
                   (Doing => Semantics.Increment, others => <>), Done);
      Goldens.Check_Text
        ("semantics-increment", "TRUE 55",
         Done'Image & Integer'Image (Integer (Widgets.Sliders.Value (Item.Volume) * 100.0)));

      --  What cannot be done is not.
      Widgets.Act (Item.Tree, Widgets.Id_Of (Item.Title), (Doing => Semantics.Click, others => <>), Done);
      Goldens.Check_Text ("semantics-cannot", "FALSE", Done'Image);

      --  A button that is off is not clicked.
      Widgets.Buttons.Set_Enabled (Item.Save, False);
      Widgets.Act (Item.Tree, Widgets.Id_Of (Item.Save), (Doing => Semantics.Click, others => <>), Done);
      Goldens.Check_Text ("semantics-disabled", "FALSE", Done'Image);
   end Actions;

   procedure Stale_Ids is
      Item  : Fixture;
      Heard : Notes;
      Done  : Boolean;
      Old   : Widgets.Node_Id;
   begin
      Open (Item);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Old := Widgets.Id_Of (Item.Save);
      Widgets.Remove (Item.Save);
      Widgets.Act (Item.Tree, Old, (Doing => Semantics.Click, others => <>), Done);
      Goldens.Check_Text ("semantics-removed", "FALSE", Done'Image);

      --  Put back, it has an id of its own, not the old.
      Widgets.Add (Item.Bar, Item.Save);
      Goldens.Check_Text
        ("semantics-new-id", "TRUE",
         Boolean'Image (Widgets.Id_Of (Item.Save) /= Old
                        and then Widgets.Resolve (Item.Tree, Old) = null));

      --  A number for an id, and back.
      Goldens.Check_Text
        ("semantics-number", "TRUE",
         Boolean'Image
           (Widgets.From_Unsigned_64
              (Widgets.To_Unsigned_64 (Widgets.Id_Of (Item.Save)))
            = Widgets.Id_Of (Item.Save)));
   end Stale_Ids;

   procedure Menu_Parts is
      Item  : Fixture;
      Heard : Notes;
      Done  : Boolean;
      Chosen : Natural;
   begin
      Open (Item);
      Widgets.Set_Visible (Item.Pop, True);
      Widgets.Layout (Item.Tree, Item.Target);
      Widgets.Describe_Changes (Item.Tree, Heard);
      Goldens.Check_Text
        ("semantics-menu-parts", "TRUE",
         Boolean'Image
           (Ada.Strings.Fixed.Index (To_String (Heard.Said), "menu item 'Open'") > 0
            and then Ada.Strings.Fixed.Index
                       (To_String (Heard.Said), "menu item 'Autosave' ON") > 0
            and then Ada.Strings.Fixed.Index
                       (To_String (Heard.Said), "heading 'File'") > 0));

      Widgets.Act (Item.Tree, Widgets.Part_Id (Item.Pop, 2),
                   (Doing => Semantics.Click, others => <>), Done);
      Hearers.Take_Row (Item.Ears, Item.Pop, Widgets.Choose, Chosen);
      Goldens.Check_Text ("semantics-menu-choice", "TRUE 2",
                          Done'Image & Natural'Image (Chosen));
   end Menu_Parts;

end Semantic_Tests;
