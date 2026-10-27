with Ada.Assertions;
with Clock_Faces;
with Clock_View;
with Greeter;
with Greeter_VM;
with Pomarine.Events;
with Pomarine.Testing;
with Pomarine.UI;
with Pomarine.View_Models;
with Pomarine.Widgets;

procedure Example_Views_Test is
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   use type Pomarine.View_Models.Version_Number;

   procedure Hello_Bindings is
      Tree     : aliased Widgets.Tree;
      Model    : aliased Greeter_VM.Model;
      Screen   : Greeter.UI.View (Tree'Access);
      Window   : Testing.Session;
      Before   : constant Pomarine.View_Models.Version_Number := Greeter_VM.Version (Model);
      Rejected : Boolean := False;
   begin
      pragma Assert (Greeter_VM.Count (Model) = 0);
      pragma Assert (Greeter_VM.Can_Execute (Model, Greeter_VM.Say_Hello));
      pragma Assert (not Greeter_VM.Can_Execute (Model, Greeter_VM.Say_Hello, 1));
      begin
         Greeter_VM.Execute (Model, Greeter_VM.Say_Hello, 1);
      exception
         when Ada.Assertions.Assertion_Error =>
            Rejected := True;
      end;
      pragma Assert (Rejected and then Greeter_VM.Count (Model) = 0);
      pragma Assert (Greeter_VM.Version (Model) = Before);
      Greeter.Build (Screen, Model'Access);
      Widgets.Set_Tab_Navigation (Tree, True);
      Testing.Open (Window, Tree, 320, 160);
      pragma Assert (Testing.Shows (Window, "text 'Hello, world!'"));
      Testing.Click_On (Window, "Say hello");
      pragma Assert (Greeter_VM.Count (Model) = 1 and then Greeter_VM.Version (Model) /= Before);
      pragma Assert (Testing.Shows (Window, "text 'Hello again, x 1!'"));
      Testing.Press (Window, Pomarine.Events.Key_Tab);
      Testing.Press (Window, Pomarine.Events.Key_Return);
      pragma Assert (Greeter_VM.Count (Model) = 2);
      pragma Assert (Testing.Shows (Window, "text 'Hello again, x 2!'"));
      Greeter_VM.Execute (Model, Greeter_VM.Say_Hello);
      Testing.Settle (Window);
      pragma Assert (Testing.Shows (Window, "text 'Hello again, x 3!'"));
   end Hello_Bindings;

   procedure Clock_Layout_And_Ownership is
      Tree : aliased Widgets.Tree;
      Face : Clock_Faces.Face;

      procedure Check_Size (Width, Height : Positive; Density : Float) is
         Window : Testing.Session;
      begin
         Testing.Open (Window, Tree, Width, Height, Density);
         pragma Assert (Widgets.Left_Of (Face) = 12.0 * Density);
         pragma Assert (Widgets.Top_Of (Face) = 12.0 * Density);
         pragma Assert (Widgets.Width_Of (Face) = Float (Width - 24) * Density);
         pragma Assert (Widgets.Height_Of (Face) = Float (Height - 24) * Density);
         pragma Assert (Testing.Exists (Window, "Analogue clock"));
         Clock_Faces.Set_Time (Face, 3, 15, 30);
         pragma Assert (Testing.Value_Of (Window, "Analogue clock") = "03:15:30");
      end Check_Size;
   begin
      declare
         Screen : Pomarine.UI.View (Tree'Access);
      begin
         Clock_View.Build (Screen, Face);
         Check_Size (360, 360, 1.0);
         Check_Size (480, 320, 2.0);
      end;
      pragma Assert (not Widgets.Is_Attached (Face));
      pragma Assert (not Widgets.Has_Root (Tree));
      Clock_Faces.Set_Time (Face, 9, 45, 10);
      pragma
        Assert
          (Clock_Faces.Hours (Face) = 9
             and then Clock_Faces.Minutes (Face) = 45
             and then Clock_Faces.Seconds (Face) = 10);
   end Clock_Layout_And_Ownership;
begin
   Hello_Bindings;
   Clock_Layout_And_Ownership;
end Example_Views_Test;
