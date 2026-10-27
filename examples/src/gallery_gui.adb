with Gallery;
with Gallery_VM;
with Pomarine.UI.Run_Window;

--  The general-purpose controls on one window: the buttons, fields, checks, radios, switch, slider, a select that
--  opens its own menu, tabs, a stepper, a disclosure, list, menu, badge, chip, toast and tooltips (rest the pointer on
--  the slider). The Popover and Dialog buttons open what floats over the window. Click, type and tab about to see how
--  each answers. Close the window to end it.

procedure Gallery_GUI is
   type Sheet is limited record
      Model : aliased Gallery_VM.Model;
      Parts : Gallery.Specimens;  --  the application's own widgets, as long as the view that places them
   end record;

   procedure Build (Screen : in out Gallery.UI.View; Data : not null access Sheet) is
   begin
      Gallery.Build (Screen, Data.Model'Access, Data.Parts);
   end Build;

   procedure Show is new Pomarine.UI.Run_Window (Sheet, Build);
   Content : aliased Sheet;
begin
   Gallery_VM.Seed (Content.Model);
   Show (Content, "Pomarine gallery", Gallery.Width, Gallery.Initial_Height);
end Gallery_GUI;
