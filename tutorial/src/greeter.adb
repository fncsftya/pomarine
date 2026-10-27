with Pomarine.Widgets.Buttons;

package body Greeter is
   procedure Build (Screen : in out UI.View; Model : not null access Greeter_VM.Model) is
      Bound : constant Controls.Context'Class := Controls.Bind (Screen, Model);
      Whole : constant UI.Layout :=
        UI.Column
          ([Bound.Label (Greeting, Centered => True, Width => 200.0),
            Bound.Button
              ("Say hello",
               Greeter_VM.Say_Hello,
               Look      => Pomarine.Widgets.Buttons.Primary,
               Focusable => True,
               Width     => 120.0)],
           Align   => UI.Layouts.Center,
           Spread  => UI.Layouts.Center,
           Padding => 16.0,
           Gap     => 12.0,
           Grow    => 1.0);
   begin
      UI.Mount (Screen, Whole);
   end Build;
end Greeter;
