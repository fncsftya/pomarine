with Ada.Text_IO;
with Pomarine.Events;
with Pomarine.Testing;
with Pomarine.Text_Areas;
with Pomarine.UI;
with Pomarine.Widgets.Editors;
with Pomarine.Widgets;
with Texts.Documents;
with Texts;
with Form_UI;
with Form_VM;

--  What a bound text field keeps of the person's editing when the model shows it again, how the model's own
--  text replaces it, and what an input method's composition does to either.
procedure UI_Text_Test is
   package UI renames Pomarine.UI;
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   package Editors renames Pomarine.Widgets.Editors;
   package Areas renames Pomarine.Text_Areas;
   package Forms renames Form_UI.Forms;
   package Docs renames Texts.Documents;
   use all type Form_VM.Command;
   use type Texts.Position;
   use type Forms.Replacement;

   Field_Handle : UI.Field_Handle;
   --  The field of the screen last built, which a real component would not hand out.

   function Text_Part
     (Parent : Forms.Context'Class; Source : Forms.Text_Property; Replacing : Forms.Replacement) return UI.Layout
   is
      Bound : aliased Forms.Component (Parent'Access);
      Typed : constant UI.Field_Handle := Bound.Text_Field
        (Source, Submit => Save, Name => "Text", Replacing => Replacing);
      Saves : constant UI.Button_Handle := Bound.Button ("Save", Save);
      Result : constant UI.Layout := UI.Column ([UI.Place (Typed), UI.Place (Saves)], Gap => 8.0);
   begin
      Field_Handle := Typed;
      Bound.Focus_Initially (UI.Focus_Of (Typed));
      Bound.Commit;
      return Result;
   end Text_Part;

   --  A screen of one field, and what to look at it with.

   function Area (Screen : UI.View) return not null access Areas.Text_Area is
     (Editors.Area (Editors.Editor (UI.Widget_Of (Screen, Field_Handle).all)));

   function Document (Screen : UI.View) return not null access constant Docs.Document is
     (Editors.Document (Editors.Editor (UI.Widget_Of (Screen, Field_Handle).all)));

   procedure Show
     (Tree      : aliased in out Widgets.Tree;
      Model     : aliased in out Form_VM.Model;
      Screen    : in out UI.View;
      Window    : in out Testing.Session;
      Source    : Forms.Text_Property;
      Replacing : Forms.Replacement := Forms.Caret_At_End) is
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Whole : constant UI.Layout := Text_Part (Bound, Source, Replacing);
      begin
         UI.Mount (Screen, Whole);
      end;
      Testing.Open (Window, Tree, 300, 120);
   end Show;

   procedure Editing_Survives_A_Refresh_Of_The_Same_Text is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
      Reads  : Natural;
   begin
      Show (Tree, Model, Screen, Window, Form_UI.Counted);
      Testing.Type_Text (Window, "hello world");
      Areas.Select_Range (Area (Screen).all, (Paragraph => 1, Index => 7), (Paragraph => 1, Index => 12));
      Testing.Settle (Window);
      declare
         Caret   : constant Texts.Position := Areas.Caret (Area (Screen).all);
         Mark    : constant Texts.Position := Areas.Mark (Area (Screen).all);
         State   : constant Natural := Docs.State (Document (Screen).all);
         Journal : constant String := Form_VM.Journal (Model);
      begin
         pragma Assert (Areas.Selected_Text (Area (Screen).all) = "world");
         pragma Assert (Docs.Can_Undo (Document (Screen).all));
         Reads := Form_UI.Name_Reads;

         --  The model changes in a way that is not the text: the field is asked, and finds it shows it.
         Form_VM.Touch (Model);
         Testing.Settle (Window);
         pragma Assert (Form_UI.Name_Reads > Reads);
         pragma Assert (Areas.Caret (Area (Screen).all) = Caret and then Areas.Mark (Area (Screen).all) = Mark);
         pragma Assert (Areas.Selected_Text (Area (Screen).all) = "world");
         pragma Assert (Docs.State (Document (Screen).all) = State);
         pragma Assert (Docs.Can_Undo (Document (Screen).all));
         pragma Assert (Form_VM.Journal (Model) = Journal);

         --  And what was typed is still undone by undo, whose result the model hears.
         Testing.Press (Window, Pomarine.Events.Key_Z, Command => True);
         pragma Assert (Form_VM.Name (Model) = "");
         pragma Assert (Testing.Value_Of (Window, "Text") = "");
      end;
   end Editing_Survives_A_Refresh_Of_The_Same_Text;

   procedure A_Different_Text_Replaces_The_Document is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Show (Tree, Model, Screen, Window, Form_UI.Counted);
      Testing.Type_Text (Window, "hello");
      Areas.Select_Range (Area (Screen).all, (Paragraph => 1, Index => 2), (Paragraph => 1, Index => 4));
      pragma Assert (Docs.Can_Undo (Document (Screen).all));
      Form_VM.Change_From_Elsewhere (Model, "something else");
      Testing.Settle (Window);
      pragma Assert (Testing.Value_Of (Window, "Text") = "something else");
      --  The rule for now: the history goes with the text it was of, and the caret is at the end.
      pragma Assert (not Docs.Can_Undo (Document (Screen).all));
      pragma Assert (not Areas.Has_Selection (Area (Screen).all));
      pragma Assert (Areas.Caret (Area (Screen).all) = Docs.Text_End (Document (Screen).all));
      --  What the model told is not heard back as what the person typed.
      pragma Assert (Form_VM.Journal (Model) = "set(hello)");
   end A_Different_Text_Replaces_The_Document;

   procedure The_Caret_Goes_Where_The_Policy_Says is
      Start_Tree : aliased Widgets.Tree;
      Start_Model : aliased Form_VM.Model;
      Start_Screen : UI.View (Start_Tree'Access);
      Start_Window : Testing.Session;
      Kept_Tree : aliased Widgets.Tree;
      Kept_Model : aliased Form_VM.Model;
      Kept_Screen : UI.View (Kept_Tree'Access);
      Kept_Window : Testing.Session;
   begin
      Show (Start_Tree, Start_Model, Start_Screen, Start_Window, Form_UI.Counted, Forms.Caret_At_Start);
      Testing.Type_Text (Start_Window, "abcdef");
      Form_VM.Change_From_Elsewhere (Start_Model, "uvwxyz");
      Testing.Settle (Start_Window);
      pragma Assert (Areas.Caret (Area (Start_Screen).all) = (Paragraph => 1, Index => 1));

      Show (Kept_Tree, Kept_Model, Kept_Screen, Kept_Window, Form_UI.Counted, Forms.Caret_Kept);
      Testing.Type_Text (Kept_Window, "abcdef");
      Areas.Select_Range (Area (Kept_Screen).all, (Paragraph => 1, Index => 3), (Paragraph => 1, Index => 3));
      Form_VM.Change_From_Elsewhere (Kept_Model, "uvwxyz");
      Testing.Settle (Kept_Window);
      pragma Assert (Testing.Value_Of (Kept_Window, "Text") = "uvwxyz");
      pragma Assert (Areas.Caret (Area (Kept_Screen).all) = (Paragraph => 1, Index => 3));
      --  Where it was is not in the new text: the end.
      Areas.Select_Range (Area (Kept_Screen).all, (Paragraph => 1, Index => 7), (Paragraph => 1, Index => 7));
      Testing.Settle (Kept_Window);
      Form_VM.Change_From_Elsewhere (Kept_Model, "ab");
      Testing.Settle (Kept_Window);
      pragma Assert (Areas.Caret (Area (Kept_Screen).all) = Docs.Text_End (Document (Kept_Screen).all));
   end The_Caret_Goes_Where_The_Policy_Says;

   procedure The_Model_May_Say_It_Another_Way is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Form_VM.Shouting (Model);
      Show (Tree, Model, Screen, Window, Form_UI.Name);
      Testing.Type_Text (Window, "  abc");
      pragma Assert (Form_VM.Journal (Model) = "set(  abc)");
      pragma Assert (Form_VM.Name (Model) = "ABC");
      pragma Assert (Testing.Value_Of (Window, "Text") = "ABC");
      pragma Assert (Areas.Caret (Area (Screen).all) = Docs.Text_End (Document (Screen).all));
      --  Typing goes on from where the caret was put.
      Testing.Type_Text (Window, "d");
      pragma Assert (Testing.Value_Of (Window, "Text") = "ABCD");
      pragma Assert (Form_VM.Journal (Model) = "set(  abc) set(ABCd)");
   end The_Model_May_Say_It_Another_Way;

   procedure A_Composition_Is_Not_The_Persons_Word_Yet is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Show (Tree, Model, Screen, Window, Form_UI.Name);
      Testing.Compose (Window, "ni");
      pragma Assert (Areas.Is_Composing (Area (Screen).all));
      pragma Assert (Testing.Value_Of (Window, "Text") = "ni");
      pragma Assert (Form_VM.Name (Model) = "" and then Form_VM.Journal (Model) = "");

      --  Return while composing is the input method's, not a submission.
      Testing.Press (Window, Pomarine.Events.Key_Return);
      pragma Assert (Form_VM.Journal (Model) = "");

      --  The model changes meanwhile: the composition is not disturbed.
      Form_VM.Change_From_Elsewhere (Model, "ext");
      Testing.Settle (Window);
      pragma Assert (Areas.Is_Composing (Area (Screen).all));
      pragma Assert (Testing.Value_Of (Window, "Text") = "ni");
      pragma Assert (Form_VM.Journal (Model) = "");

      --  It is cancelled: now the model's text is shown, and the cancelled composition was no edit.
      Testing.Compose (Window, "");
      Testing.Settle (Window);
      pragma Assert (not Areas.Is_Composing (Area (Screen).all));
      pragma Assert (Testing.Value_Of (Window, "Text") = "ext");
      pragma Assert (Form_VM.Name (Model) = "ext");
      pragma Assert (Form_VM.Journal (Model) = "");
   end A_Composition_Is_Not_The_Persons_Word_Yet;

   procedure A_Committed_Composition_Is_The_Persons_Word is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Show (Tree, Model, Screen, Window, Form_UI.Name);
      Testing.Compose (Window, "ni");
      Form_VM.Change_From_Elsewhere (Model, "ext");
      Testing.Settle (Window);
      pragma Assert (Testing.Value_Of (Window, "Text") = "ni");
      --  Committed, it is what was typed; the model's text that was put off yields to it.
      Testing.Type_Text (Window, "ni");
      pragma Assert (Form_VM.Name (Model) = "ni");
      pragma Assert (Testing.Value_Of (Window, "Text") = "ni");
      pragma Assert (Form_VM.Journal (Model) = "set(ni)");
      pragma Assert (not Areas.Is_Composing (Area (Screen).all));
   end A_Committed_Composition_Is_The_Persons_Word;

   procedure Return_After_A_Commit_Submits_What_Was_Committed is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Form_VM.Shouting (Model);
      Show (Tree, Model, Screen, Window, Form_UI.Name);
      Testing.Compose (Window, "ab");
      --  The method commits and Return follows, in one turn.
      Testing.Feed (Window, Pomarine.Events.Text_Event ("ab"));
      Testing.Feed (Window, (Kind => Pomarine.Events.Key_Down, Key => Pomarine.Events.Key_Return, others => <>));
      pragma Assert (Form_VM.Journal (Model) = "set(ab) save(AB)");
      Testing.Settle (Window);
      pragma Assert (Form_VM.Last_Saved (Model) = "AB");
      pragma Assert (Testing.Value_Of (Window, "Text") = "");
   end Return_After_A_Commit_Submits_What_Was_Committed;

begin
   Ada.Text_IO.Put_Line ("Editing_Survives_A_Refresh_Of_The_Same_Text");
   Editing_Survives_A_Refresh_Of_The_Same_Text;
   Ada.Text_IO.Put_Line ("A_Different_Text_Replaces_The_Document");
   A_Different_Text_Replaces_The_Document;
   Ada.Text_IO.Put_Line ("The_Caret_Goes_Where_The_Policy_Says");
   The_Caret_Goes_Where_The_Policy_Says;
   Ada.Text_IO.Put_Line ("The_Model_May_Say_It_Another_Way");
   The_Model_May_Say_It_Another_Way;
   Ada.Text_IO.Put_Line ("A_Composition_Is_Not_The_Persons_Word_Yet");
   A_Composition_Is_Not_The_Persons_Word_Yet;
   Ada.Text_IO.Put_Line ("A_Committed_Composition_Is_The_Persons_Word");
   A_Committed_Composition_Is_The_Persons_Word;
   Ada.Text_IO.Put_Line ("Return_After_A_Commit_Submits_What_Was_Committed");
   Return_After_A_Commit_Submits_What_Was_Committed;
   Ada.Text_IO.Put_Line ("ok");
end UI_Text_Test;
