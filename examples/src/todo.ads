with Tasks;
with Pomarine.Widgets;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Lists;
with Pomarine.Widgets.Panels;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;

--  What the window of Todo_GUI shows: a field to type a task in, the tasks
--  in a list that reads them from a model, and a row of buttons.
package Todo is

   type Page is limited record
      Root    : aliased Pomarine.Widgets.Panels.Panel;
      Entry_Box : aliased Pomarine.Widgets.Text_Fields.Text_Field;
      List    : aliased Pomarine.Widgets.Lists.List;
      Footer  : aliased Pomarine.Widgets.Panels.Panel;
      Summary : aliased Pomarine.Widgets.Labels.Label;
      Toggle  : aliased Pomarine.Widgets.Buttons.Button;
      Remove  : aliased Pomarine.Widgets.Buttons.Button;
      Sweep   : aliased Pomarine.Widgets.Buttons.Button;
      Typed   : aliased Texts.Documents.Document;
      --  after Entry_Box's document is shown by it, so declared here, before use.
      Items   : aliased Tasks.Task_List;
   end record;
   --  The widgets and the tasks are the application's own.

   procedure Build (Item : aliased in out Page; Tree : in out Pomarine.Widgets.Tree);

end Todo;
