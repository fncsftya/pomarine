with Pomarine.Widgets.Callbacks;
with Pomarine.Widgets.Layouts;

package body Greeter is
   package Widgets renames Pomarine.Widgets;
   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Layouts renames Pomarine.Widgets.Layouts;

   package Handlers is new Widgets.Callbacks (Greeting);

   procedure Say_Hello (Self : in out Greeting; Source : in out Widgets.Widget'Class; Event : Widgets.Widget_Event) is
      pragma Unreferenced (Source, Event);
   begin
      Self.Count := Self.Count + 1;
      Labels.Set_Text (Self.Text, "Hello again, x" & Self.Count'Image & "!");
   end Say_Hello;

   procedure Build (Item : aliased in out Greeting; Tree : in out Widgets.Tree) is
   begin
      Widgets.Set_Root (Tree, Item.Page);
      Widgets.Add (Item.Page, Item.Text, Item.Greet);

      Layouts.Set_Layout
        (Item.Page, Flow => Layouts.Column, Align => Layouts.Center, Spread => Layouts.Center,
         Padding => (others => 16.0), Gap => 12.0);
      Layouts.Set_Layout (Item.Text, Width => 200.0, Height => 24.0);
      Layouts.Set_Layout (Item.Greet, Width => 120.0, Height => 32.0);

      Labels.Set_Text (Item.Text, "Hello, world!");
      Labels.Set_Centered (Item.Text, True);
      Buttons.Set_Label (Item.Greet, "Say hello");
      Buttons.Set_Kind (Item.Greet, Buttons.Primary);
      Handlers.On (Item.Greet, Widgets.Click, Item'Access, Say_Hello'Access);
   end Build;

end Greeter;
