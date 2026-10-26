with Pomarine.Widgets;

package body Clock_View is
   package UI renames Pomarine.UI;

   procedure Build (Screen : in out UI.View; Face : in out Clock_Faces.Face) is
      Whole : constant UI.Layout :=
        UI.Column ([UI.Styled (UI.Put (Screen, Face), (Grow => 1.0, others => <>))],
                   Padding => 12.0, Grow => 1.0);
   begin
      Pomarine.Widgets.Set_Accessible_Name (Face, "Analogue clock");
      UI.Mount (Screen, Whole);
   end Build;
end Clock_View;
