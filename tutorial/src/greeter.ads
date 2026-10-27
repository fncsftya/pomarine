with Greeter_VM;
with Pomarine.UI;
with Pomarine.UI.Contexts;

--  A greeting and a command button, owned and synchronized by the view.

package Greeter is
   package UI renames Pomarine.UI;
   package Controls is new UI.Contexts (Greeter_VM.Commands, Greeter_VM.Model);

   Greeting : constant Controls.Text_Property := Controls.Showing (Greeter_VM.Message'Access);

   procedure Build (Screen : in out UI.View; Model : not null access Greeter_VM.Model);
   --  Model must outlive Screen.
end Greeter;
