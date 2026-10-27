with Pomarine.Widgets.Buttons;

package body Todo is

   use all type Pomarine.Widgets.Buttons.Kind;
   use all type Todo_VM.Command;

   function Task_Entry (Parent : Todo_UI.Context'Class) return UI.Layout
   is (Parent.Text_Field
         (Task_Draft, Add_Task, Placeholder => "What needs doing? Press Return", Focus_Initially => True));

   function Task_Content (Parent : Todo_UI.Context'Class) return UI.Layout
   is (Parent.List (Task_Rows, Task_Choice, Reveal_After => Add_Task, Growth => Task_Count, Grow => 1.0));

   function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout
   is (UI.Row
         ([Parent.Label (Task_Summary, Grow => 1.0),
           Parent.Button ("Done", Toggle_Chosen, Width => 70.0),
           Parent.Button ("Delete", Remove_Chosen, Look => Danger, Width => 70.0),
           Parent.Button ("Clear done", Sweep_Done, Width => 100.0)],
          Gap => 8.0));

   function Task_Screen (Parent : Todo_UI.Context'Class) return UI.Layout
   is (UI.Column ([Task_Entry (Parent), Task_Content (Parent), Task_Actions (Parent)], Padding => 12.0, Gap => 8.0));

   procedure Build (Screen : in out UI.View; Model : not null access Todo_VM.Model) is
      Bound : constant Todo_UI.Context'Class := Todo_UI.Bind (Screen, Model);
      Whole : constant UI.Layout := Task_Screen (Bound);
   begin
      UI.Mount (Screen, Whole);
   end Build;

end Todo;
