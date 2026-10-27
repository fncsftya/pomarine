with Greeter;
with Greeter_VM;
with Pomarine.UI.Run_Window;

--  A greeting and a command button, declared with their model bindings in Greeter.
procedure Hello_GUI is
   procedure Show is new Pomarine.UI.Run_Window (Greeter_VM.Model, Greeter.Build);
   Model : aliased Greeter_VM.Model;
begin
   Show (Model, "Hello", 320, 160);
end Hello_GUI;
