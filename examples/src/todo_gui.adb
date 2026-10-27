with Pomarine.UI.Run_Window;
with Todo;
with Todo_VM;

--  A list of tasks: type one and press Return; choose one and mark it done or
--  delete it, or clear all that are done. The list
--  reads its rows from a model, so it would cost the same of a hundred
--  thousand. Close the window to end it.
procedure Todo_GUI is
   procedure Show is new Pomarine.UI.Run_Window (Todo_VM.Model, Todo.Build);
   Model : aliased Todo_VM.Model;
begin
   Todo_VM.Seed (Model);
   Show (Model, "Tasks", 640, 480);
end Todo_GUI;
