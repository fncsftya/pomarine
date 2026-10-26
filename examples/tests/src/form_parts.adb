with Form_VM;

package body Form_Parts is

   use all type Form_VM.Command;

   function Called (Title, Word : String) return String is (if Title = "" then Word else Word & " " & Title);

   function Handles_Part (Parent : Forms.Context'Class; Title : String := "") return Field_Part is
      Bound  : aliased Forms.Component (Parent'Access);
      Name   : constant UI.Field_Handle := Bound.Text_Field
        (Form_UI.Name, Submit => Save, Placeholder => "Name", Name => Called (Title, "Name"));
      Shown  : constant UI.Label_Handle := Bound.Label (Form_UI.Status);
      Saves  : constant UI.Button_Handle := Bound.Button (Called (Title, "Save"), Save);
      Clear  : constant UI.Button_Handle := Bound.Button (Called (Title, "Reset"), Reset);
      Result : constant UI.Layout := UI.Column
        ([UI.Place (Name), UI.Place (Shown), UI.Row ([UI.Place (Saves), UI.Place (Clear)], Gap => 8.0)],
         Gap => 8.0);
   begin
      Runs := Runs + 1;
      Bound.Focus_Initially (UI.Focus_Of (Name));
      Bound.Commit;
      return (Layout => Result, Field => Name, Save => Saves);
   end Handles_Part;

   function Form_Part (Parent : Forms.Context'Class; Title : String := "") return UI.Layout is
     (Handles_Part (Parent, Title).Layout);

   function Boom return Integer is (Integer'Value ("not a number"));

   function Failing_Part (Parent : Forms.Context'Class) return UI.Layout is
      Bound : aliased Forms.Component (Parent'Access);
      Name  : constant UI.Field_Handle := Bound.Text_Field (Form_UI.Name, Name => "Doomed");
      Shown : constant UI.Label_Handle := Bound.Label (Form_UI.Status);
      Bad   : constant Integer := Boom;
      pragma Unreferenced (Bad);
      Result : constant UI.Layout := UI.Column ([UI.Place (Name), UI.Place (Shown)]);
   begin
      Bound.Commit;
      return Result;
   end Failing_Part;

   function Abandoned_Part (Parent : Forms.Context'Class) return UI.Layout is
      Bound : aliased Forms.Component (Parent'Access);
      Name  : constant UI.Field_Handle := Bound.Text_Field (Form_UI.Name, Name => "Abandoned");
   begin
      return UI.Place (Name);
   end Abandoned_Part;

   function Group_Part (Parent : Forms.Context'Class; Fail_After_Children : Boolean := False) return UI.Layout is
      Bound  : aliased Forms.Component (Parent'Access);
      First  : constant UI.Layout := Form_Part (Bound, "A");
      Second : constant UI.Layout := Form_Part (Bound, "B");
      Extra  : constant Integer := (if Fail_After_Children then Boom else 0);
      pragma Unreferenced (Extra);
      Result : constant UI.Layout := UI.Column ([First, Second], Gap => 8.0);
   begin
      Bound.Commit;
      return Result;
   end Group_Part;

   function Failing_Child_Group (Parent : Forms.Context'Class) return UI.Layout is
      Bound  : aliased Forms.Component (Parent'Access);
      First  : constant UI.Layout := Form_Part (Bound, "A");
      Second : constant UI.Layout := Failing_Part (Bound);
      Result : constant UI.Layout := UI.Column ([First, Second]);
   begin
      Bound.Commit;
      return Result;
   end Failing_Child_Group;

   function Forgiving_Group (Parent : Forms.Context'Class) return UI.Layout is
      Bound  : aliased Forms.Component (Parent'Access);
      First  : constant UI.Layout := Form_Part (Bound, "A");
      Second : UI.Layout := UI.Nothing;
   begin
      begin
         Second := Failing_Part (Bound);
      exception
         when Constraint_Error =>
            null;
      end;
      declare
         Result : constant UI.Layout := UI.Column ([First, Second]);
      begin
         Bound.Commit;
         return Result;
      end;
   end Forgiving_Group;

end Form_Parts;
