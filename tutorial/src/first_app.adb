with Greeter;
with Greeter_VM;
with Pomarine.UI.Run_Window;

--  A greeting and a command button, declared with their model bindings in Greeter.

procedure First_App is
   procedure Show is new Pomarine.UI.Run_Window (Greeter_VM.Model, Greeter.Build);
   Model : aliased Greeter_VM.Model;
begin
   Show (Model, "My first app", 320, 160);
end First_App;
