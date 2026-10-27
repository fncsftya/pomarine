with Ada.Text_IO;
with Pomarine.UI;
with Pomarine.Widgets.Text_Fields;
with Pomarine.Widgets;
with Form_Parts;
with Form_UI;
with Form_VM;

--  What is refused when nothing is asked of the compiler: no assertion, contract or check of range is relied
--  on, and this test does not use one either (Expect), so it can be built with assertions ignored and all
--  checks off (see docs/testing.md). A handle that has outlived its scope, one of another view, a control placed
--  twice and a layout of a scope that is gone are each refused by a test the program makes itself, before
--  any storage is looked at.

procedure UI_Unchecked_Test is
   package UI renames Pomarine.UI;
   package Widgets renames Pomarine.Widgets;
   package Forms renames Form_UI.Forms;
   use type UI.Mount_Problem;

   procedure Expect (Condition : Boolean; Message : String) is
   begin
      if not Condition then
         raise Program_Error with Message;
      end if;
   end Expect;

   Leaked : UI.Field_Handle;

   function Remember (Item : UI.Field_Handle) return Integer is
   begin
      Leaked := Item;
      return 0;
   end Remember;

   function Boom return Integer
   is (Integer'Value ("not a number"));

   function Leaking_Part (Parent : Forms.Context'Class) return UI.Layout is
      Bound : aliased Forms.Component (Parent'Access);
      Name  : constant UI.Field_Handle := Bound.Text_Field (Form_UI.Name, Name => "Leaky");
      Noted : constant Integer := Remember (Name);
      Bad   : constant Integer := Boom;
   begin
      pragma Unreferenced (Noted, Bad);
      Bound.Commit;
      return UI.Place (Name);
   end Leaking_Part;

   Tree_1  : aliased Widgets.Tree;
   Tree_2  : aliased Widgets.Tree;
   Model_1 : aliased Form_VM.Model;
   Model_2 : aliased Form_VM.Model;
   First   : UI.View (Tree_1'Access);
   Second  : UI.View (Tree_2'Access);

   Stale   : Boolean := False;
   Foreign : Boolean := False;
begin
   declare
      Bound_1 : constant Forms.Context'Class := Forms.Bind (First, Model_1'Access);
      Bound_2 : constant Forms.Context'Class := Forms.Bind (Second, Model_2'Access);
   begin
      --  A scope that failed took its controls with it.
      begin
         declare
            Dropped : constant UI.Layout := Leaking_Part (Bound_1);
            pragma Unreferenced (Dropped);
         begin
            null;
         end;
      exception
         when Constraint_Error =>
            null;
      end;
      Expect (not UI.Is_Live (First, Leaked), "a handle of a scope that failed is live");
      begin
         declare
            Field : constant access Widgets.Text_Fields.Text_Field'Class := UI.Widget_Of (First, Leaked);
            pragma Unreferenced (Field);
         begin
            null;
         end;
      exception
         when UI.Stale_Handle =>
            Stale := True;
      end;
      Expect (Stale, "a stale handle was dereferenced");
      Expect (UI.Check (First, UI.Place (Leaked)) = UI.Stale_Control, "a stale control would be mounted");

      --  The places are used again, and the old handle is still stale.
      declare
         Mine  : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound_1);
         Yours : constant Form_Parts.Field_Part := Form_Parts.Handles_Part (Bound_2);
      begin
         Expect (UI.Is_Live (First, Mine.Field), "a new handle is not live");
         Expect (not UI.Is_Live (First, Leaked), "slot reuse made a stale handle live");

         --  Another view's.
         Expect (not UI.Is_Live (Second, Mine.Field), "a handle is live in another view");
         begin
            declare
               Field : constant access Widgets.Text_Fields.Text_Field'Class := UI.Widget_Of (Second, Mine.Field);
               pragma Unreferenced (Field);
            begin
               null;
            end;
         exception
            when UI.Foreign_Handle =>
               Foreign := True;
         end;
         Expect (Foreign, "a handle of another view was dereferenced");
         Expect (UI.Check (First, Yours.Layout) = UI.Foreign_Layout, "a layout of another view would be mounted");

         --  Twice, and a tree that is unchanged by the refusal.
         Expect
           (UI.Check (First, UI.Row ([Mine.Layout, UI.Place (Mine.Save)])) = UI.Duplicate_Placement,
            "a control would be placed twice");
         begin
            UI.Mount (First, UI.Row ([Mine.Layout, Mine.Layout]));
            Expect (False, "a screen with a control twice was mounted");
         exception
            when UI.Mount_Refused =>
               null;
         end;
         Expect (not Widgets.Has_Root (Tree_1) and then not UI.Is_Mounted (First), "a refused mount changed the tree");
         UI.Mount (First, Mine.Layout);
         Expect (Widgets.Has_Root (Tree_1), "a mount was not done");
      end;
   end;
   Ada.Text_IO.Put_Line ("ok");
end UI_Unchecked_Test;
