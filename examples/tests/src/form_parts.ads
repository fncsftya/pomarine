with Pomarine.UI;
with Form_UI;

--  Components of the tests of Pomarine.UI, made of Form_VM.
package Form_Parts is

   package UI renames Pomarine.UI;
   package Forms renames Form_UI.Forms;

   Runs : Natural := 0;
   --  How many times a component function has run: a model that changes must not run them again.

   function Form_Part (Parent : Forms.Context'Class; Title : String := "") return UI.Layout;
   --  A field called "Name <Title>", buttons "Save <Title>" and "Reset <Title>", and the status below.
   --  The field submits.

   type Field_Part is record
      Layout : UI.Layout;
      Field  : UI.Field_Handle;
      Save   : UI.Button_Handle;
   end record;
   --  What a component that keeps its handles in the test says. (A real one keeps them private.)

   function Handles_Part (Parent : Forms.Context'Class; Title : String := "") return Field_Part;

   function Failing_Part (Parent : Forms.Context'Class) return UI.Layout;
   --  Makes controls, then fails in its declarative part (Constraint_Error).

   function Abandoned_Part (Parent : Forms.Context'Class) return UI.Layout;
   --  Makes controls and returns without Commit.

   function Group_Part (Parent : Forms.Context'Class; Fail_After_Children : Boolean := False) return UI.Layout;
   --  Two form parts in a scope of its own; fails after them if asked.

   function Failing_Child_Group (Parent : Forms.Context'Class) return UI.Layout;
   --  A form part that succeeds, then one that fails, in one scope.

   function Forgiving_Group (Parent : Forms.Context'Class) return UI.Layout;
   --  A part that fails is caught here and the group goes on without it.

end Form_Parts;
