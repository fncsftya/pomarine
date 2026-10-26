with Ada.Finalization;
with Ada.Unchecked_Deallocation;
with Ada.Text_IO;
with Pomarine.Testing;
with Pomarine.UI.Arenas;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Text_Fields;
with Pomarine.Line_Texts;
with Texts.Documents;
with Form_Parts;
with Form_UI;
with Form_VM;

--  Who owns what in a view, how long handles and scopes last, and what a failure leaves behind.
procedure UI_Ownership_Test is
   package UI renames Pomarine.UI;
   package Arenas renames Pomarine.UI.Arenas;
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Panels renames Pomarine.Widgets.Panels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;
   package Forms renames Form_UI.Forms;
   use type UI.Mount_Problem;
   use type Widgets.Widget_Access;
   use all type Form_VM.Command;

   Baseline_Arenas : constant Natural := Arenas.Live_Arenas;
   Baseline_Views  : constant Natural := UI.Live_Views;

   --  The application's own widgets, which the view only borrows.

   Finalized_Detached : Boolean := False;
   Finalized_Untagged : Boolean := False;

   type Application_Widgets is limited new Ada.Finalization.Limited_Controlled with record
      Save   : Buttons.Button;
      Shown  : Labels.Label;
      Typed  : Text_Fields.Text_Field;
      Words  : aliased Texts.Documents.Document;
   end record;

   overriding procedure Finalize (Item : in out Application_Widgets) is
   begin
      --  The view is gone already (it was declared after this): it has taken them out of the tree and
      --  let go of their handlers and tags, and has not finalized them (this is the first time).
      Finalized_Detached := not Widgets.Is_Attached (Item.Save) and then not Widgets.Is_Attached (Item.Typed)
        and then not Widgets.Is_Attached (Item.Shown);
      Finalized_Untagged :=
        Widgets.Tag_Of (Item.Save) = Widgets.No_Tag and then Widgets.Tag_Of (Item.Typed) = Widgets.No_Tag;
   end Finalize;

   procedure Borrowing_Is_Not_Owning is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Mine   : Application_Widgets;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
   begin
      Buttons.Configure (Mine.Save, Buttons.Looks ("Keep"));
      Text_Fields.Configure (Mine.Typed, Pomarine.Line_Texts.Interface_Font, 15.0);
      Text_Fields.Attach (Mine.Typed, Mine.Words'Unchecked_Access);
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Keep  : constant UI.Button_Handle := Bound.Borrow_Button (Mine.Save, Save);
         Shown : constant UI.Label_Handle := Bound.Borrow_Label (Mine.Shown, Form_UI.Status);
         Typed : constant UI.Field_Handle := Bound.Borrow_Field (Mine.Typed, Mine.Words, Form_UI.Name);
         Whole : constant UI.Layout :=
           UI.Column ([UI.Place (Typed, Height => 38.0), UI.Place (Shown), UI.Place (Keep)], Padding => 8.0);
      begin
         Widgets.Set_Accessible_Name (Mine.Typed, "Borrowed field");
         UI.Mount (Screen, Whole);
         pragma Assert (Widgets.Is_Attached (Mine.Save));
         pragma Assert (UI.Live_Controls (Screen) = 3);
         Testing.Open (Window, Tree, 300, 200);
         pragma Assert (Testing.Is_Disabled (Window, "Keep"));
         Testing.Click_On (Window, "Borrowed field");
         Testing.Type_Text (Window, "kept");
         pragma Assert (Form_VM.Name (Model) = "kept");
         Testing.Click_On (Window, "Keep");
         pragma Assert (Form_VM.Saved_Count (Model) = 1);
         pragma Assert (Labels.Text (Mine.Shown) = "1 saved");
      end;
   end Borrowing_Is_Not_Owning;

   procedure Teardown_Reclaims_What_It_Owns is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Whole : constant UI.Layout := Form_Parts.Form_Part (Bound);
      begin
         pragma Assert (Arenas.Live_Arenas > Baseline_Arenas);
         UI.Mount (Screen, Whole);
         pragma Assert (UI.Live_Controls (Screen) = 4);
         pragma Assert (UI.Live_Bindings (Screen) = 5);   --  the field, its Submit, the label, two buttons: four + one
         pragma Assert (Widgets.Has_Root (Tree));
      end;
   end Teardown_Reclaims_What_It_Owns;

   procedure Views_Are_Counted is
   begin
      declare
         Tree   : aliased Widgets.Tree;
         Screen : UI.View (Tree'Access);
      begin
         pragma Assert (UI.Live_Views = Baseline_Views + 1);
         pragma Assert (UI.Live_Scopes (Screen) = 1);
         pragma Assert (not UI.Is_Mounted (Screen));
      end;
      pragma Assert (UI.Live_Views = Baseline_Views);
      pragma Assert (Arenas.Live_Arenas = Baseline_Arenas);
   end Views_Are_Counted;

   Leaked : UI.Field_Handle;

   function Remember (Item : UI.Field_Handle) return Integer is
   begin
      Leaked := Item;
      return 0;
   end Remember;

   function Boom return Integer is (Integer'Value ("not a number"));

   function Leaking_Part (Parent : Forms.Context'Class) return UI.Layout is
      Bound : aliased Forms.Component (Parent'Access);
      Name  : constant UI.Field_Handle := Bound.Text_Field (Form_UI.Name, Name => "Leaky");
      Noted : constant Integer := Remember (Name);
      Bad   : constant Integer := Boom;
      pragma Unreferenced (Noted, Bad);
   begin
      Bound.Commit;
      return UI.Place (Name);
   end Leaking_Part;

   procedure Raises_Stale (Screen : UI.View; Handle : UI.Field_Handle; Seen : out Boolean) is
   begin
      Seen := False;
      declare
         Widget : constant access Text_Fields.Text_Field := UI.Widget_Of (Screen, Handle);
         pragma Unreferenced (Widget);
      begin
         null;
      end;
   exception
      when UI.Stale_Handle =>
         Seen := True;
   end Raises_Stale;

   procedure Handles_Go_Stale_With_The_Scope is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Seen   : Boolean;
   begin
      declare
         Bound  : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Failed : Boolean := False;
      begin
         begin
            declare
               Dropped : constant UI.Layout := Leaking_Part (Bound);
               pragma Unreferenced (Dropped);
            begin
               null;
            end;
         exception
            when Constraint_Error =>
               Failed := True;
         end;
         pragma Assert (Failed);
         pragma Assert (not UI.Is_Live (Screen, Leaked));
         pragma Assert (UI.Live_Controls (Screen) = 0);
         pragma Assert (UI.Live_Bindings (Screen) = 0);
         pragma Assert (UI.Live_Scopes (Screen) = 1);
         Raises_Stale (Screen, Leaked, Seen);
         pragma Assert (Seen);

         --  The place is used again, by a control with another generation: the old handle stays stale.
         declare
            Slots : constant Natural := UI.Control_Slots (Screen);
            Fresh : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
         begin
            --  Four controls made, and the one place free was one of them.
            pragma Assert (UI.Control_Slots (Screen) = Slots + 3);
            pragma Assert (UI.Is_Live (Screen, Fresh.Field));
            pragma Assert (not UI.Is_Live (Screen, Leaked));
            Raises_Stale (Screen, Leaked, Seen);
            pragma Assert (Seen);
            --  Described, it is not mounted: Mount says the control is stale.
            declare
               Old : constant UI.Layout := UI.Place (Leaked);
            begin
               pragma Assert (UI.Check (Screen, Old) = UI.Stale_Control);
               pragma Assert (UI.Check (Screen, UI.Column ([Fresh.Layout, Old])) = UI.Stale_Control);
               pragma Assert (UI.Check (Screen, Fresh.Layout) = UI.No_Problem);
            end;
         end;
      end;
   end Handles_Go_Stale_With_The_Scope;

   procedure Views_Do_Not_Mix is
      Tree_1  : aliased Widgets.Tree;
      Tree_2  : aliased Widgets.Tree;
      Model_1 : aliased Form_VM.Model;
      Model_2 : aliased Form_VM.Model;
      First   : UI.View (Tree_1'Access);
      Second  : UI.View (Tree_2'Access);
      Seen    : Boolean := False;
   begin
      declare
         Bound_1 : constant Forms.Context'Class := Forms.Bind (First, Model_1'Access);
         Bound_2 : constant Forms.Context'Class := Forms.Bind (Second, Model_2'Access);
         Mine    : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound_1);
         Yours   : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound_2);
         Mixed   : constant UI.Layout := UI.Column ([Yours.Layout, UI.Place (Mine.Field)]);
      begin
         pragma Assert (UI.Is_Live (First, Mine.Field));
         pragma Assert (not UI.Is_Live (Second, Mine.Field));
         begin
            declare
               Widget : constant access Text_Fields.Text_Field := UI.Widget_Of (Second, Mine.Field);
               pragma Unreferenced (Widget);
            begin
               null;
            end;
         exception
            when UI.Foreign_Handle =>
               Seen := True;
         end;
         pragma Assert (Seen);
         pragma Assert (UI.Check (First, Mine.Layout) = UI.No_Problem);
         pragma Assert (UI.Check (First, Yours.Layout) = UI.Foreign_Layout);
         pragma Assert (UI.Check (Second, Mixed) = UI.Foreign_Layout);
         Seen := False;
         begin
            UI.Mount (First, Yours.Layout);
         exception
            when UI.Mount_Refused =>
               Seen := True;
         end;
         pragma Assert (Seen);
         pragma Assert (not Widgets.Has_Root (Tree_1) and then not UI.Is_Mounted (First));
         --  The refusals changed nothing: each view mounts its own.
         UI.Mount (First, Mine.Layout);
         UI.Mount (Second, Yours.Layout);
         pragma Assert (Widgets.Has_Root (Tree_1) and then Widgets.Has_Root (Tree_2));
      end;
   end Views_Do_Not_Mix;

   procedure A_Context_Outlives_Its_View is
      Tree  : aliased Widgets.Tree;
      Model : aliased Form_VM.Model;
      type View_Access is access UI.View;
      procedure Free is new Ada.Unchecked_Deallocation (UI.View, View_Access);
      Held  : View_Access := new UI.View (Tree'Access);
      Seen  : Boolean := False;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Held.all, Model'Access);
      begin
         pragma Assert (Bound.Is_Open);
         Free (Held);
         pragma Assert (not Bound.Is_Open);
         begin
            declare
               Made : constant UI.Label_Handle := Bound.Label (Form_UI.Status);
               pragma Unreferenced (Made);
            begin
               null;
            end;
         exception
            when UI.Stale_Handle =>
               Seen := True;
         end;
         pragma Assert (Seen);
      end;
   end A_Context_Outlives_Its_View;

   procedure A_Control_Is_Placed_Once is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Refused : Boolean := False;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
         Twice : constant UI.Layout := UI.Row ([Part.Layout, Part.Layout]);
         Again : constant UI.Layout := UI.Column ([Part.Layout, UI.Place (Part.Save)]);
         Other : constant UI.Layout := UI.Row ([UI.Place (Part.Field), UI.Place (Part.Field, Grow => 1.0)]);
      begin
         pragma Assert (UI.Check (Screen, Part.Layout) = UI.No_Problem);
         --  A layout is a description: it may be used again, but a control cannot be in two places.
         pragma Assert (UI.Check (Screen, Part.Layout) = UI.No_Problem);
         pragma Assert (UI.Check (Screen, Twice) = UI.Duplicate_Placement);
         pragma Assert (UI.Check (Screen, Again) = UI.Duplicate_Placement);
         pragma Assert (UI.Check (Screen, Other) = UI.Duplicate_Placement);
         begin
            UI.Mount (Screen, Twice);
         exception
            when UI.Mount_Refused =>
               Refused := True;
         end;
         pragma Assert (Refused);
         pragma Assert (not Widgets.Has_Root (Tree));
         pragma Assert (not Widgets.Is_Attached (UI.Widget_Of (Screen, Part.Field).all));
         pragma Assert (Arenas.Live_Arenas = Baseline_Arenas + UI.Live_Scopes (Screen) + 0);
         --  Mounting does not consume the layout.
         UI.Mount (Screen, Part.Layout);
         pragma Assert (UI.Check (Screen, Part.Layout) = UI.Already_Mounted);
      end;
   end A_Control_Is_Placed_Once;

   procedure A_Control_In_A_Tree_Is_Refused is
      Tree_1  : aliased Widgets.Tree;
      Tree_2  : aliased Widgets.Tree;
      Model   : aliased Form_VM.Model;
      Mine    : Application_Widgets;
      Root    : aliased Panels.Panel;
      Screen  : UI.View (Tree_2'Access);
      Seen    : Boolean := False;
   begin
      Buttons.Configure (Mine.Save, Buttons.Looks ("Elsewhere"));
      Widgets.Set_Root (Tree_1, Root);
      Widgets.Add (Root, Mine.Save);
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Keep  : constant UI.Button_Handle := Bound.Borrow_Button (Mine.Save, Save);
         Whole : constant UI.Layout := UI.Place (Keep);
      begin
         pragma Assert (UI.Check (Screen, Whole) = UI.Attachment_Conflict);
         begin
            UI.Mount (Screen, Whole);
         exception
            when UI.Mount_Refused =>
               Seen := True;
         end;
         pragma Assert (Seen);
         pragma Assert (not Widgets.Has_Root (Tree_2));
         pragma Assert (Widgets.Parent_Of (Mine.Save) = Widgets.Widget_Access'(Root'Unchecked_Access));
      end;
   end A_Control_In_A_Tree_Is_Refused;

   procedure A_Failed_Mount_Changes_Nothing is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Window : Testing.Session;
      Failed : Boolean := False;
   begin
      declare
         Bound  : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part   : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound, "X");
         Arenas_Before : constant Natural := Arenas.Live_Arenas;
         Scopes_Before : constant Natural := UI.Live_Scopes (Screen);
         Controls_Before : constant Natural := UI.Live_Controls (Screen);
      begin
         --  Five widgets are attached (two controls, a row, two buttons): a fault before each, in turn.
         for Placements in 0 .. 4 loop
            Failed := False;
            UI.Inject_Fault (Screen, Placements);
            begin
               UI.Mount (Screen, Part.Layout);
            exception
               when Program_Error =>
                  Failed := True;
            end;
            pragma Assert (Failed);
            pragma Assert (not Widgets.Has_Root (Tree));
            pragma Assert (not UI.Is_Mounted (Screen));
            pragma Assert (not Widgets.Is_Attached (UI.Widget_Of (Screen, Part.Field).all));
            pragma Assert (not Widgets.Is_Attached (UI.Widget_Of (Screen, Part.Save).all));
            pragma Assert (Arenas.Live_Arenas = Arenas_Before);
            pragma Assert (UI.Live_Scopes (Screen) = Scopes_Before);
            pragma Assert (UI.Live_Controls (Screen) = Controls_Before);
         end loop;

         --  Recoverable: the same description mounts, and works.
         UI.Mount (Screen, Part.Layout);
         pragma Assert (UI.Is_Mounted (Screen));
         Testing.Open (Window, Tree, 300, 200);
         pragma Assert (Testing.Is_Disabled (Window, "Save X"));
         Testing.Click_On (Window, "Name X");
         Testing.Type_Text (Window, "again");
         Testing.Click_On (Window, "Save X");
         pragma Assert (Form_VM.Saved_Count (Model) = 1);
      end;
   end A_Failed_Mount_Changes_Nothing;

   procedure A_Tree_With_A_Root_Is_Refused is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Root   : Panels.Panel;
      Screen : UI.View (Tree'Access);
   begin
      Widgets.Set_Root (Tree, Root);
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
         Part  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound);
      begin
         pragma Assert (UI.Check (Screen, Part.Layout) = UI.Tree_Has_Root);
         pragma Assert (UI.Check (Screen, UI.Nothing) = UI.Tree_Has_Root);
      end;
   end A_Tree_With_A_Root_Is_Refused;

   procedure Nothing_To_Mount is
      Tree   : aliased Widgets.Tree;
      Screen : UI.View (Tree'Access);
   begin
      pragma Assert (UI.Check (Screen, UI.Nothing) = UI.No_Screen);
      pragma Assert (UI.Check (Screen, UI.Row ([UI.Nothing, UI.Nothing])) = UI.No_Screen);
   end Nothing_To_Mount;

   procedure Failures_Release_What_Was_Made is
      Tree   : aliased Widgets.Tree;
      Model  : aliased Form_VM.Model;
      Screen : UI.View (Tree'Access);
      Arenas_Before : Natural;
      Caught : Boolean;

      procedure Nothing_Is_Left (Because : String) is
      begin
         pragma Assert (UI.Live_Scopes (Screen) = 1, Because);
         pragma Assert (UI.Live_Controls (Screen) = 0, Because);
         pragma Assert (UI.Live_Bindings (Screen) = 0, Because);
         pragma Assert (Arenas.Live_Arenas = Arenas_Before, Because);
      end Nothing_Is_Left;
   begin
      declare
         Bound : constant Forms.Context'Class := Forms.Bind (Screen, Model'Access);
      begin
         Arenas_Before := Arenas.Live_Arenas;

         --  A failure in the declarative part of a component.
         Caught := False;
         begin
            declare
               Dropped : constant UI.Layout := Form_Parts.Failing_Part (Bound);
               pragma Unreferenced (Dropped);
            begin
               null;
            end;
         exception
            when Constraint_Error =>
               Caught := True;
         end;
         pragma Assert (Caught);
         Nothing_Is_Left ("failed declaration");

         --  A component that is not committed.
         declare
            Dropped : constant UI.Layout := Form_Parts.Abandoned_Part (Bound);
            pragma Unreferenced (Dropped);
         begin
            null;
         end;
         Nothing_Is_Left ("abandoned component");

         --  A child fails after another succeeded: the one that succeeded goes too.
         Caught := False;
         begin
            declare
               Dropped : constant UI.Layout := Form_Parts.Failing_Child_Group (Bound);
               pragma Unreferenced (Dropped);
            begin
               null;
            end;
         exception
            when Constraint_Error =>
               Caught := True;
         end;
         pragma Assert (Caught);
         Nothing_Is_Left ("child failed");

         --  The children succeed, and the parent fails afterwards: committed, but provisionally.
         Caught := False;
         begin
            declare
               Dropped : constant UI.Layout := Form_Parts.Group_Part (Bound, Fail_After_Children => True);
               pragma Unreferenced (Dropped);
            begin
               null;
            end;
         exception
            when Constraint_Error =>
               Caught := True;
         end;
         pragma Assert (Caught);
         Nothing_Is_Left ("parent failed");

         --  A parent that forgives a child: only the child is gone.
         declare
            Group : constant UI.Layout := Form_Parts.Forgiving_Group (Bound);
         begin
            pragma Assert (UI.Live_Scopes (Screen) = 3);   --  the root, the group, the part that succeeded
            pragma Assert (UI.Live_Controls (Screen) = 4);
            pragma Assert (UI.Check (Screen, Group) = UI.No_Problem);
         end;

         --  A group that succeeds stays until the view goes, mounted or not.
         declare
            Group : constant UI.Layout := Form_Parts.Group_Part (Bound);
         begin
            pragma Assert (UI.Live_Controls (Screen) = 12);
            UI.Mount (Screen, Group);
            pragma Assert (UI.Live_Controls (Screen) = 12);
         end;
      end;
   end Failures_Release_What_Was_Made;

begin
   Ada.Text_IO.Put_Line ("Views_Are_Counted");
   Views_Are_Counted;
   Ada.Text_IO.Put_Line ("Borrowing_Is_Not_Owning");
   Borrowing_Is_Not_Owning;
   pragma Assert (Finalized_Detached);
   pragma Assert (Finalized_Untagged);
   Ada.Text_IO.Put_Line ("Teardown_Reclaims_What_It_Owns");
   Teardown_Reclaims_What_It_Owns;
   Ada.Text_IO.Put_Line ("Handles_Go_Stale_With_The_Scope");
   Handles_Go_Stale_With_The_Scope;
   Ada.Text_IO.Put_Line ("Views_Do_Not_Mix");
   Views_Do_Not_Mix;
   Ada.Text_IO.Put_Line ("A_Context_Outlives_Its_View");
   A_Context_Outlives_Its_View;
   Ada.Text_IO.Put_Line ("A_Control_Is_Placed_Once");
   A_Control_Is_Placed_Once;
   Ada.Text_IO.Put_Line ("A_Control_In_A_Tree_Is_Refused");
   A_Control_In_A_Tree_Is_Refused;
   Ada.Text_IO.Put_Line ("A_Failed_Mount_Changes_Nothing");
   A_Failed_Mount_Changes_Nothing;
   Ada.Text_IO.Put_Line ("A_Tree_With_A_Root_Is_Refused");
   A_Tree_With_A_Root_Is_Refused;
   Ada.Text_IO.Put_Line ("Nothing_To_Mount");
   Nothing_To_Mount;
   Ada.Text_IO.Put_Line ("Failures_Release_What_Was_Made");
   Failures_Release_What_Was_Made;
   pragma Assert (UI.Live_Views = Baseline_Views);
   pragma Assert (Arenas.Live_Arenas = Baseline_Arenas);
   Ada.Text_IO.Put_Line ("ok");
end UI_Ownership_Test;
