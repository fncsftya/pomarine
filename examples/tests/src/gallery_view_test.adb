with Gallery;
with Gallery_VM;
with Pomarine.Events;
with Pomarine.Semantics;
with Pomarine.Testing;
with Pomarine.Widgets;
with Pomarine.Widgets.Choice_Groups;
with Pomarine.Widgets.Dialogs;
with Pomarine.Widgets.Popovers;
with Pomarine.Widgets.Selects;
with Pomarine.Widgets.Splitters;
with Pomarine.Widgets.Disclosures;
with Pomarine.Widgets.Steppers;
with Pomarine.Widgets.Number_Fields;
with Pomarine.Widgets.Overlays;
with Texts.Documents;

--  The gallery as a person uses it, by what each control is called: no pixels, so no coordinates to break
--  when the layout moves (the goldens of tests/ draw it).

procedure Gallery_View_Test is
   package Testing renames Pomarine.Testing;
   package Widgets renames Pomarine.Widgets;
   use all type Pomarine.Semantics.Role;
   Tree   : aliased Pomarine.Widgets.Tree;
   Model  : aliased Gallery_VM.Model;
   Parts  : Gallery.Specimens;
   Screen : Gallery.UI.View (Tree'Access);
   Window : Testing.Session;
begin
   Gallery_VM.Seed (Model);
   Gallery.Build (Screen, Model'Access, Parts);
   Testing.Open (Window, Tree, Gallery.Width, Gallery.Height);

   --  What is there to begin with: the commands that cannot be done are off.
   pragma Assert (Testing.Shows (Window, "Clicked 0 times"));
   pragma Assert (Testing.Shows (Window, "Hello, stranger!"));
   pragma Assert (not Testing.Is_Disabled (Window, "Click me"));
   pragma Assert (Testing.Is_Disabled (Window, "Reset"));
   pragma Assert (Testing.Is_Disabled (Window, "Remove"));
   pragma Assert (Gallery_VM.Size (Model) = 2);

   --  A button, and what it makes of the screen.
   Testing.Click_On (Window, "Click me");
   pragma Assert (Testing.Shows (Window, "Clicked once"));
   Testing.Click_On (Window, "Click me");
   Testing.Click_On (Window, "Click me");
   pragma Assert (Testing.Shows (Window, "Clicked 3 times"));
   pragma Assert (not Testing.Is_Disabled (Window, "Reset"));
   Testing.Click_On (Window, "Reset");
   pragma Assert (Gallery_VM.Clicks (Model) = 0);
   pragma Assert (Testing.Is_Disabled (Window, "Reset"));

   --  A field.
   Testing.Click_On (Window, "Your name");
   Testing.Type_Text (Window, "Ada");
   pragma Assert (Gallery_VM.Name (Model) = "Ada");
   pragma Assert (Testing.Shows (Window, "Hello, Ada!"));

   --  A box, a radio of three, and a switch.
   Testing.Click_On (Window, "Notify me");
   pragma Assert (Gallery_VM.Notify (Model));
   Testing.Click_On (Window, "Large");
   pragma Assert (Gallery_VM.Size (Model) = 3);
   pragma Assert (Testing.Shows (Window, "radio button 'Large' ON"));
   pragma Assert (Testing.Shows (Window, "radio button 'Medium' OFF"));
   Testing.Click_On (Window, "Compact");
   pragma Assert (Gallery_VM.Compact (Model));

   --  A list: choosing a row turns Remove on, and removing one takes it out.
   pragma Assert (Testing.Exists (Window, "Bananas"));
   Testing.Click_On (Window, "Bananas");
   pragma Assert (not Testing.Is_Disabled (Window, "Remove"));
   Testing.Click_On (Window, "Remove");
   pragma Assert (Gallery_VM.Count (Model) = 3);
   pragma Assert (not Testing.Exists (Window, "Bananas"));
   pragma Assert (Testing.Is_Disabled (Window, "Remove"));

   --  Tabs: exactly one chosen, by a click.
   pragma Assert (Widgets.Choice_Groups.Selected (Parts.Views) = 1);
   Testing.Click_On (Window, "Outline", Radio_Button);
   pragma Assert (Widgets.Choice_Groups.Selected (Parts.Views) = 2);

   --  A select that opens its own menu, and shuts it when one is chosen.
   Testing.Click_On (Window, "Font");
   pragma Assert (Widgets.Selects.Is_Open (Parts.Choice) and then Testing.Exists (Window, "Menlo"));
   Testing.Click_On (Window, "Menlo");
   pragma Assert (Widgets.Selects.Value (Parts.Choice) = "Menlo");
   pragma Assert (not Widgets.Selects.Is_Open (Parts.Choice));

   Testing.Click_On (Window, "Center", Radio_Button);
   Testing.Click_On (Window, "Final", Radio_Button);
   pragma Assert (Widgets.Choice_Groups.Selected (Parts.Alignment) = 2);
   pragma Assert (Widgets.Choice_Groups.Selected (Parts.Mode) = 2);
   pragma Assert (Testing.Act_On (Window, "Copies", Pomarine.Semantics.Increment));
   pragma Assert (Widgets.Steppers.Value (Parts.Copies) = 3);
   pragma Assert (Testing.Act_On (Window, "Advanced", Pomarine.Semantics.Collapse));
   pragma Assert (not Widgets.Disclosures.Is_Open (Parts.Advanced));
   pragma Assert (not Testing.Exists (Window, "A disclosure hides what is under its heading."));
   pragma Assert (Testing.Act_On (Window, "Advanced", Pomarine.Semantics.Expand));
   Testing.Click_On (Window, "Quantity");
   Testing.Press (Window, Pomarine.Events.Key_A, Command => True);
   Testing.Type_Text (Window, "25");
   Testing.Press (Window, Pomarine.Events.Key_Return);
   pragma Assert (Widgets.Number_Fields.Value (Parts.Quantity) = 25);
   Testing.Click_On (Window, "Rich text", Multiline_Text_Input);
   Testing.Press (Window, Pomarine.Events.Key_A, Command => True);
   Testing.Type_Text (Window, "A gallery editor");
   pragma Assert (Texts.Documents.Whole (Parts.Sample_Doc) = "A gallery editor");

   --  A splitter: the keys give one side more room.
   pragma Assert (Widgets.Splitters.Position (Parts.Divider) = 160.0);
   pragma Assert (Testing.Act_On (Window, "Pane divider", Pomarine.Semantics.Focus));
   Testing.Press (Window, Pomarine.Events.Key_Right_Arrow);
   pragma Assert (Widgets.Splitters.Position (Parts.Divider) = 176.0);

   --  What opens over the window: a popover that Escape lets go of, a dialog that a button answers.
   Testing.Click_On (Window, "Popover");
   pragma Assert (Widgets.Popovers.Is_Shown (Parts.Info));
   Testing.Press (Window, Pomarine.Events.Key_Escape);
   pragma Assert (not Widgets.Popovers.Is_Shown (Parts.Info));
   Testing.Click_On (Window, "Dialog");
   pragma Assert (Widgets.Dialogs.Is_Shown (Parts.Ask));
   Testing.Click_On (Window, "Click me");
   pragma Assert (Gallery_VM.Clicks (Model) = 0, "a dialog takes what is under it");
   Testing.Click_On (Window, "Cancel");
   pragma Assert (not Widgets.Dialogs.Is_Shown (Parts.Ask));

   Testing.Click_On (Window, "Context menu");
   pragma Assert (Widgets.Overlays.Is_Presented (Parts.Context_Menu));
   Testing.Press (Window, Pomarine.Events.Key_End);
   Testing.Press (Window, Pomarine.Events.Key_Return);
   pragma Assert (not Widgets.Overlays.Is_Presented (Parts.Context_Menu));

   --  Semantic actions report refusal without silently changing a disabled control.
   Widgets.Steppers.Set_Enabled (Parts.Copies, False);
   pragma Assert (not Testing.Act_On (Window, "Copies", Pomarine.Semantics.Increment));
   pragma Assert (Widgets.Steppers.Value (Parts.Copies) = 3);
   Widgets.Steppers.Set_Enabled (Parts.Copies, True);

   --  The keyboard: Return in a field does nothing the model cannot, and Tab leaves the screen standing.
   Testing.Press (Window, Pomarine.Events.Key_Tab);
   pragma Assert (Testing.Exists (Window, "Click me"));
   --  In a shorter window the whole control sheet scrolls, while overlays remain in window coordinates.
   declare
      Small_Tree   : aliased Widgets.Tree;
      Small_Model  : aliased Gallery_VM.Model;
      Small_Parts  : Gallery.Specimens;
      Small_Screen : Gallery.UI.View (Small_Tree'Access);
      Small_Window : Testing.Session;
   begin
      Gallery_VM.Seed (Small_Model);
      Widgets.Set_Reduced_Motion (Small_Tree, True);
      Gallery.Build (Small_Screen, Small_Model'Access, Small_Parts);
      Testing.Open (Small_Window, Small_Tree, Gallery.Width, 360);
      Testing.Feed
        (Small_Window,
         (Kind => Pomarine.Events.Mouse_Wheel, Wheel_Y => -100.0, Mouse_X => 710.0, Mouse_Y => 300.0, others => <>));
      Testing.Settle (Small_Window);
      pragma Assert (Widgets.Top_Of (Small_Parts.Context_Button) < 360.0);
      Testing.Click_On (Small_Window, "Context menu");
      pragma Assert (Widgets.Overlays.Is_Presented (Small_Parts.Context_Menu));
      pragma Assert (Widgets.Top_Of (Small_Parts.Context_Menu) >= 0.0);
      pragma Assert (Widgets.Top_Of (Small_Parts.Context_Menu) + Widgets.Height_Of (Small_Parts.Context_Menu) <= 360.0);
      Testing.Press (Small_Window, Pomarine.Events.Key_Escape);
      pragma Assert (not Widgets.Overlays.Is_Presented (Small_Parts.Context_Menu));
   end;
end Gallery_View_Test;
