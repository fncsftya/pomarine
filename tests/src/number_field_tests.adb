with Ada.Assertions;
with Goldens;
with Pomarine.Line_Texts;
with Pomarine.Themes;
with SDL3.Windows.Renderers;
with Hearers;
with Pomarine.Events;
with Pomarine.Testing;
with Pomarine.Widgets.Number_Fields;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Layouts;

package body Number_Field_Tests is
   package Fields renames Pomarine.Widgets.Number_Fields;
   package W renames Pomarine.Widgets;
   package E renames Pomarine.Events;
   package T renames Pomarine.Testing;

   procedure Rules is
      function Valid (Text : String) return Boolean is (Fields.Valid (Text, Integer'First, Integer'Last));
   begin
      pragma Assert (Valid ("0") and then Valid ("-0") and then Valid ("+42"));
      pragma Assert (Valid (Integer'Image (Integer'First)));
      --  'Image has a leading space for a positive integer; typed syntax deliberately does not.
      declare
         Max : constant String := Integer'Image (Integer'Last);
         Zeros : constant String (1 .. 10_000) := [others => '0'];
      begin
         pragma Assert (Valid (Max (2 .. Max'Last)));
         pragma Assert (not Valid (Max (2 .. Max'Last) & "0"));
         pragma Assert (not Valid (Integer'Image (Integer'First) & "0"));
         pragma Assert (Fields.Valid (Zeros & "12", 1, 20));
      end;
      pragma Assert (not Valid ("") and then not Valid ("-") and then not Valid ("+"));
      pragma Assert (not Valid (" 1") and then not Valid ("1 ") and then not Valid ("1.2"));
      pragma Assert (not Valid ([Integer'Last => '-']));
      pragma Assert (not Valid ("16#FF#") and then not Valid ("1e2") and then not Valid ("1_000"));
      pragma Assert (not Fields.Valid ("21", 1, 20) and then not Fields.Valid ("-1", 1, 20));
   end Rules;

   procedure States is
      package Renderers renames SDL3.Windows.Renderers;
      Target : Renderers.Renderer;
      Lines : aliased Pomarine.Line_Texts.Drawer;
      Tree : aliased W.Tree;
      Root : aliased W.Panels.Panel;
      Good, Bad, Off, Focused : aliased Fields.Number_Field;
      Session : T.Session;
      Drawn : Goldens.Images.Image;
   begin
      W.Set_Root (Tree, Root);
      W.Layouts.Column (Root, Padding => (others => 12.0), Gap => 8.0);
      W.Layouts.Add (Root, Good, (Width => 180.0, Height => 36.0, others => <>));
      W.Layouts.Add (Root, Bad, (Width => 180.0, Height => 36.0, others => <>));
      W.Layouts.Add (Root, Off, (Width => 180.0, Height => 36.0, others => <>));
      W.Layouts.Add (Root, Focused, (Width => 180.0, Height => 36.0, others => <>));
      Fields.Configure (Good, "Georgia", 14.0, Min => 1, Max => 100, Start => 12);
      Fields.Configure (Bad, "Georgia", 14.0, Min => 1, Max => 100, Start => 12);
      Fields.Configure (Off, "Georgia", 14.0, Min => 1, Max => 100, Start => 12);
      Fields.Configure (Focused, "Georgia", 14.0, Min => 1, Max => 100, Start => 12);
      Fields.Set_Enabled (Off, False);
      W.Set_Accessible_Name (Bad, "Invalid quantity");
      W.Set_Accessible_Name (Focused, "Focused quantity");
      T.Open (Session, Tree, 220, 200);
      T.Click_On (Session, "Invalid quantity");
      T.Press (Session, E.Key_A, Command => True);
      T.Type_Text (Session, "101");
      T.Press (Session, E.Key_Return);
      T.Click_On (Session, "Focused quantity");
      Renderers.Create_Offscreen (Target, 220, 200);
      W.Set_Line_Texts (Tree, Lines);
      W.Layout (Tree, Target);
      W.Paint (Tree, Target, Pomarine.Themes.Light);
      Goldens.Images.Read (Drawn, Target);
      Goldens.Check ("number-field-states", Drawn);
   end States;

   procedure Editing is
      Tree : aliased W.Tree;
      Root : aliased W.Panels.Panel;
      Field : aliased Fields.Number_Field;
      Other : aliased Fields.Number_Field;
      Ears : aliased Hearers.Hearer;
      Session : T.Session;
      Said : Boolean;

      procedure Replace (Text : String) is
      begin
         T.Click_On (Session, "Quantity");
         T.Press (Session, E.Key_A, Command => True);
         T.Type_Text (Session, Text);
      end Replace;
   begin
      W.Set_Root (Tree, Root);
      W.Set_Listener (Tree, Ears'Unchecked_Access);
      W.Layouts.Column (Root, Gap => 8.0);
      W.Layouts.Add (Root, Field, (Width => 180.0, Height => 36.0, others => <>));
      W.Layouts.Add (Root, Other, (Width => 180.0, Height => 36.0, others => <>));
      Fields.Configure (Field, "Georgia", 14.0, Min => -20, Max => 100, Start => 12);
      Fields.Configure (Other, "Georgia", 14.0);
      W.Set_Accessible_Name (Field, "Quantity");
      W.Set_Accessible_Name (Other, "Other");
      T.Open (Session, Tree, 300, 160);
      pragma Assert (T.Value_Of (Session, "Quantity") = "12");
      Replace ("-8");
      pragma Assert (Fields.Value (Field) = 12 and then Fields.Can_Commit (Field));
      T.Press (Session, E.Key_Return);
      pragma Assert (Fields.Value (Field) = -8);
      Hearers.Take (Ears, Field, W.Change, Said);
      pragma Assert (Said);
      Hearers.Take (Ears, Field, W.Submit, Said);
      pragma Assert (Said);
      T.Press (Session, E.Key_Return);
      Hearers.Take (Ears, Field, W.Change, Said);
      pragma Assert (not Said); -- unchanged commit is quiet
      Replace ("101");
      T.Press (Session, E.Key_Return);
      pragma Assert (Fields.Value (Field) = -8 and then Fields.Is_Invalid (Field));
      pragma Assert (T.Value_Of (Session, "Quantity") = "101");
      T.Click_On (Session, "Other");
      pragma Assert (Fields.Value (Field) = -8 and then Fields.Draft (Field) = "101");
      T.Click_On (Session, "Quantity");
      T.Press (Session, E.Key_Escape);
      pragma Assert (Fields.Draft (Field) = "-8" and then not Fields.Is_Invalid (Field));
      Replace ("23");
      T.Click_On (Session, "Other");
      pragma Assert (Fields.Value (Field) = 23); -- focus-loss commit
      Replace ("-");
      begin
         Fields.Commit (Field);
         raise Program_Error with "invalid draft accepted";
      exception
         when Ada.Assertions.Assertion_Error => null;
      end;
      Fields.Set_Value (Field, 23);
      pragma Assert (Fields.Draft (Field) = "23");
      Fields.Set_Range (Field, 1, 10);
      pragma Assert (Fields.Value (Field) = 10 and then Fields.Draft (Field) = "10");
      Fields.Set_Enabled (Field, False);
      T.Settle (Session);
      pragma Assert (T.Is_Disabled (Session, "Quantity"));
      Fields.Set_Value (Field, 5); -- setters also work when disabled
      pragma Assert (Fields.Value (Field) = 5);
      Fields.Set_Enabled (Field, True);
      Replace ("7");
      T.Compose (Session, "8");
      T.Press (Session, E.Key_Return);
      pragma Assert (Fields.Value (Field) = 5); -- composition is not a submission
      T.Compose (Session, "");
      T.Press (Session, E.Key_Return);
      pragma Assert (Fields.Value (Field) = 7);
      Replace ([1 .. 5_000 => '9']);
      pragma Assert (Fields.Draft (Field)'Length = 5_000 and then not Fields.Can_Commit (Field));
   end Editing;
end Number_Field_Tests;
