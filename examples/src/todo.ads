with Pomarine.UI;
with Pomarine.UI.Contexts;
with Pomarine.Widgets.Buttons;
with Tasks;
with Todo_VM;

--  What the window of Todo_GUI shows: a field to type a task in, the tasks in a list that reads them
--  from a model, and a row of buttons. The screen is three components, each a function that makes its
--  controls with what ties them to the view-model and returns where they go.
--
--  The model is the caller's (Todo_GUI declares it before the view and the tree it is shown in); the
--  view owns every widget, binding and document, and finalizes them.
package Todo is

   package UI renames Pomarine.UI;

   --  How the model is read and written: instantiated here, in a package, as the adapters must be.

   package Todo_UI is new UI.Contexts (Todo_VM.Commands, Todo_VM.Model);

   package Summary_Adapter is new Todo_UI.Read_Text (Todo_VM.Summary);
   package Draft_Adapter is new Todo_UI.Edit_Text (Todo_VM.Draft, Todo_VM.Set_Draft);
   package Count_Adapter is new Todo_UI.Counter (Todo_VM.Count);
   package Rows_Adapter is new Todo_UI.Row_Source (Tasks.Task_List, Todo_VM.Rows);
   package Choice_Adapter is new Todo_UI.Choice (Todo_VM.Selected_Task, Todo_VM.Select_Task);

   Task_Summary : constant Todo_UI.Text_Property := Summary_Adapter.Property;
   Task_Draft   : constant Todo_UI.Text_Property := Draft_Adapter.Property;
   Task_Count   : constant Todo_UI.Count_Property := Count_Adapter.Property;
   Task_Rows    : constant Todo_UI.Rows_Property := Rows_Adapter.Property;
   Task_Choice  : constant Todo_UI.Choice_Property := Choice_Adapter.Property;

   --  A component that has something to hand up besides where its controls go says so in its result.

   type Entry_Part is record
      Layout : UI.Layout;
      Focus  : UI.Focus_Target;
   end record;

   type Content_Part is record
      Layout : UI.Layout;
      Reveal : UI.Reveal_Target;
   end record;

   --  Reusable components: they take the bindings they need and nothing of the screen. Entry_Field is a
   --  field that shows a text and does a command on Return; Command_Button a button for a command.

   function Entry_Field
     (Parent  : Todo_UI.Context'Class;
      Text    : Todo_UI.Text_Property;
      Submit  : Todo_VM.Command;
      Prompt  : String) return Entry_Part;

   function Command_Button
     (Parent  : Todo_UI.Context'Class;
      Caption : String;
      Command : Todo_VM.Command;
      Width   : UI.Layouts.Length;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal) return UI.Layout;

   --  The screen's own components, which know the model.

   function Task_Entry (Parent : Todo_UI.Context'Class) return Entry_Part;
   function Task_Content (Parent : Todo_UI.Context'Class) return Content_Part;
   function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout;
   function Task_Screen (Bound : Todo_UI.Context'Class) return UI.Layout;

   procedure Build (Screen : in out UI.View; Model : not null access Todo_VM.Model);
   --  Make the screen of Model in Screen and mount it. Model must be there as long as Screen is used.

end Todo;
