with Pomarine.UI;
with Pomarine.UI.Contexts;
with Todo_VM;

--  What the window of Todo_GUI shows: a field to type a task in, the tasks in a list that reads them
--  from a model, and a row of buttons. The screen is three components, each a function that makes its
--  controls, with what ties them to the view-model, and returns where they go.
--
--  The model is the caller's (Todo_GUI declares it before the view and the tree it is shown in); the
--  view owns every widget, binding and document, and finalizes them.
package Todo is

   package UI renames Pomarine.UI;

   --  How the model is read and written: the model's own subprograms, one line each.

   package Todo_UI is new UI.Contexts (Todo_VM.Commands, Todo_VM.Model);

   Task_Summary : constant Todo_UI.Text_Property := Todo_UI.Showing (Todo_VM.Summary'Access);
   Task_Draft   : constant Todo_UI.Text_Property :=
     Todo_UI.Editing (Todo_VM.Draft'Access, Todo_VM.Set_Draft'Access);
   Task_Count   : constant Todo_UI.Count_Property := Todo_UI.Counting (Todo_VM.Count'Access);
   Task_Rows    : constant Todo_UI.Rows_Property := Todo_UI.Listing (Todo_VM.Row_Model'Access);
   Task_Choice  : constant Todo_UI.Choice_Property :=
     Todo_UI.Choosing (Todo_VM.Selected_Task'Access, Todo_VM.Select_Task'Access);

   --  The screen's components. Each makes its controls through the context it is given and returns the
   --  layout of them: the focus the field has at the start, and the list scrolled to a task just added,
   --  are said of the controls.

   function Task_Entry (Parent : Todo_UI.Context'Class) return UI.Layout;
   function Task_Content (Parent : Todo_UI.Context'Class) return UI.Layout;
   function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout;
   function Task_Screen (Parent : Todo_UI.Context'Class) return UI.Layout;

   procedure Build (Screen : in out UI.View; Model : not null access Todo_VM.Model);
   --  Make the screen of Model in Screen and mount it. Model must be there as long as Screen is used.

   --  Todo_GUI.Show is Pomarine.UI.Run_Window of the model and this procedure.

end Todo;
