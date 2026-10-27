with Greeter;
with Greeter_VM;
with Pomarine.Testing;
with Pomarine.Themes;
with Pomarine.Widgets;
with SDL3.Windows.Renderers.Images;

--  Capture the tutorial's actual view with SDL's offscreen renderer.

procedure Capture is
   package Widgets renames Pomarine.Widgets;
   package Renderers renames SDL3.Windows.Renderers;
   package Images renames SDL3.Windows.Renderers.Images;
   Tree   : aliased Widgets.Tree;
   Model  : aliased Greeter_VM.Model;
   Screen : Greeter.UI.View (Tree'Access);
   Window : Pomarine.Testing.Session;
   Target : Renderers.Renderer;
   Image  : Images.Image;

   procedure Save (Name : String) is
   begin
      Widgets.Layout (Tree, Target);
      Widgets.Paint (Tree, Target, Pomarine.Themes.Light);
      Images.Read (Image, Target);
      Images.Save_PNG (Image, "../docs/images/" & Name & ".png");
   end Save;
begin
   Greeter.Build (Screen, Model'Access);
   Pomarine.Testing.Open (Window, Tree, 320, 160);
   Renderers.Create_Offscreen (Target, 320, 160);
   pragma Assert (Pomarine.Testing.Shows (Window, "Hello, world!"));
   Save ("tutorial-hello");
   Pomarine.Testing.Click_On (Window, "Say hello");
   pragma Assert (Greeter_VM.Count (Model) = 1);
   pragma Assert (Pomarine.Testing.Shows (Window, "Hello again, x 1!"));
   Save ("tutorial-clicked");
end Capture;
