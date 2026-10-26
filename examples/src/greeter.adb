with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;

package body Greeter is
   function Greeting_Screen (Screen : in out UI.View; Parent : Controls.Context'Class) return UI.Layout is
      Bound   : aliased Controls.Component (Parent'Access);
      Message : constant UI.Label_Handle := Bound.Label (Greeting_Text.Property);
      Greet   : constant UI.Button_Handle :=
        Bound.Button ("Say hello", Greeter_VM.Say_Hello, Look => Pomarine.Widgets.Buttons.Primary,
                      Focusable => True);
      Result  : constant UI.Layout :=
        UI.Column ([UI.Place (Message, Width => 200.0, Height => 24.0),
                    UI.Place (Greet, Width => 120.0, Height => 32.0)],
                   Align => UI.Layouts.Center, Spread => UI.Layouts.Center, Padding => 16.0, Gap => 12.0,
                   Grow => 1.0);
   begin
      Pomarine.Widgets.Labels.Set_Centered (UI.Widget_Of (Screen, Message).all, True);
      Bound.Commit;
      return Result;
   end Greeting_Screen;

   procedure Build (Screen : in out UI.View; Model : not null access Greeter_VM.Model) is
      Bound : constant Controls.Context'Class := Controls.Bind (Screen, Model);
      Whole : constant UI.Layout := Greeting_Screen (Screen, Bound);
   begin
      UI.Mount (Screen, Whole);
   end Build;
end Greeter;
