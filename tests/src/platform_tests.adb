with Ada.Strings.Fixed;
with System;
with Goldens;
with Pomarine.Application;
with Pomarine.Native_Menus;
with Pomarine.System_Settings;
with Pomarine.Widgets.Panels;
with SDL3.Windows.Renderers;

package body Platform_Tests is

   package Widgets renames Pomarine.Widgets;
   package App renames Pomarine.Application;

   function Image (Value : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (Value), Ada.Strings.Left));

   Ran : Natural := 0;
   Order : String (1 .. 8) := [others => '.'];

   procedure Count (Data : System.Address) is
      pragma Unreferenced (Data);
   begin
      Ran := Ran + 1;
   end Count;

   procedure Mark (Data : System.Address) is
      Which : Character with Import, Address => Data;
   begin
      Order (Ran + 1) := Which;
      Ran := Ran + 1;
   end Mark;

   procedure Failing (Data : System.Address) is
      pragma Unreferenced (Data);
   begin
      raise Constraint_Error with "this one fails";
   end Failing;

   procedure Posted_Work is
      First : aliased constant Character := 'a';
      Second : aliased constant Character := 'b';
      Third : aliased constant Character := 'c';
      Kept : Boolean;
   begin
      Ran := 0;
      Goldens.Check_Text ("application-none", "FALSE", App.Is_Waiting'Image);
      Kept := App.Post (Mark'Access, First'Address);
      Kept := App.Post (Mark'Access, Second'Address) and then Kept;
      Kept := App.Post (Mark'Access, Third'Address) and then Kept;
      Goldens.Check_Text ("application-waiting", "TRUE TRUE", Kept'Image & " " & App.Is_Waiting'Image);
      App.Run_Posted;
      Goldens.Check_Text ("application-in-order", "3 abc", Image (Ran) & " " & Order (1 .. 3));
      Goldens.Check_Text ("application-done", "FALSE", App.Is_Waiting'Image);

      --  One that fails does not keep the rest from being run.
      Ran := 0;
      Kept := App.Post (Failing'Access);
      Kept := App.Post (Count'Access) and then Kept;
      begin
         App.Run_Posted;
         Goldens.Check_Text ("application-failure-raised", "raised", "not");
      exception
         when Constraint_Error =>
            Goldens.Check_Text ("application-failure-raised", "raised", "raised");
      end;
      Goldens.Check_Text ("application-rest-run", "1", Image (Ran));

      --  No room: not kept, and counted.
      declare
         Before : constant Natural := App.Dropped;
         Room   : Natural := 0;
      begin
         while App.Post (Count'Access) loop
            Room := Room + 1;
         end loop;
         Goldens.Check_Text
           ("application-full", "64 1", Image (Room) & " " & Image (App.Dropped - Before));
         App.Run_Posted;
      end;
   end Posted_Work;

   type Ears is limited new Widgets.Listener with record
      Tags : String (1 .. 8) := [others => '.'];
      Count : Natural := 0;
   end record;

   overriding procedure Handle_Event
     (Self   : in out Ears;
      Source : in out Widgets.Widget'Class;
      Event  : Widgets.Widget_Event)
   is
      pragma Unreferenced (Source);
   begin
      Self.Count := Self.Count + 1;
      Self.Tags (Self.Count) := Character'Val (Character'Pos ('0') + Event.Tag);
   end Handle_Event;

   procedure Menu_Choices is
      Bar    : Pomarine.Native_Menus.Menu_Bar;
      Tree   : Widgets.Tree;
      Target : SDL3.Windows.Renderers.Renderer;
      Root   : aliased Widgets.Panels.Panel;
      Heard  : aliased Ears;
   begin
      SDL3.Windows.Renderers.Create_Offscreen (Target, 50, 50);
      Widgets.Set_Listener (Tree, Heard'Unchecked_Access);
      Widgets.Set_Root (Tree, Root);
      Pomarine.Native_Menus.Choose (Bar, 3);
      Pomarine.Native_Menus.Choose (Bar, 5);
      Goldens.Check_Text ("menus-waiting", "TRUE", Pomarine.Native_Menus.Is_Waiting (Bar)'Image);
      Pomarine.Native_Menus.Pump (Bar, Tree);
      Widgets.Deliver (Tree);
      Goldens.Check_Text ("menus-performed", "2 35", Image (Heard.Count) & " " & Heard.Tags (1 .. 2));
      Goldens.Check_Text ("menus-done", "FALSE", Pomarine.Native_Menus.Is_Waiting (Bar)'Image);

      --  A key that a widget took is also the menu item's key equivalent:
      --  what the system says was chosen is dropped, whichever came first.
      Heard.Count := 0;
      Pomarine.Native_Menus.Choose (Bar, 3);
      Pomarine.Native_Menus.Choose (Bar, 5);
      Pomarine.Native_Menus.Discard (Bar, 3);
      Pomarine.Native_Menus.Pump (Bar, Tree);
      Pomarine.Native_Menus.Discard (Bar, 4);
      Pomarine.Native_Menus.Choose (Bar, 4);
      Pomarine.Native_Menus.Choose (Bar, 4);
      Pomarine.Native_Menus.Pump (Bar, Tree);
      Widgets.Deliver (Tree);
      Goldens.Check_Text
        ("menus-discarded", "2 54", Image (Heard.Count) & " " & Heard.Tags (1 .. 2));

      --  Only the next Pump or the one after it: not a choice for ever.
      Heard.Count := 0;
      Pomarine.Native_Menus.Discard (Bar, 6);
      Pomarine.Native_Menus.Pump (Bar, Tree);
      Pomarine.Native_Menus.Pump (Bar, Tree);
      Pomarine.Native_Menus.Choose (Bar, 6);
      Pomarine.Native_Menus.Pump (Bar, Tree);
      Widgets.Deliver (Tree);
      Goldens.Check_Text ("menus-discard-expired", "1", Image (Heard.Count));
   end Menu_Choices;

   procedure System_Settings is
      Motion : constant Boolean := Pomarine.System_Settings.Reduce_Motion;
      Contrast : constant Boolean := Pomarine.System_Settings.Increase_Contrast;
      Clear : constant Boolean := Pomarine.System_Settings.Reduce_Transparency;
   begin
      --  Whatever they are, they can be asked, and are the same twice.
      Goldens.Check_Text
        ("settings-stable", "TRUE",
         Boolean'Image (Motion = Pomarine.System_Settings.Reduce_Motion
                        and then Contrast = Pomarine.System_Settings.Increase_Contrast
                        and then Clear = Pomarine.System_Settings.Reduce_Transparency));
   end System_Settings;

end Platform_Tests;
