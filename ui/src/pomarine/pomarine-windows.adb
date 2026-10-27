with SDL3;
with Pomarine.Events;

package body Pomarine.Windows is

   overriding
   procedure Finalize (Item : in out Platform) is
   begin
      if Item.Started then
         SDL3.Shutdown;
         Item.Started := False;
      end if;
   end Finalize;

   procedure Open
     (Item      : in out Window;
      Tree      : in out Widgets.Tree;
      Title     : String;
      Width     : Positive;
      Height    : Positive;
      Resizable : Boolean := True) is
   begin
      SDL3.Initialize;
      Item.System.Started := True;
      SDL3.Windows.Create (Item.Frame, Title, Width, Height, Resizable => Resizable, High_Density => True);
      SDL3.Windows.Renderers.Create (Item.Target, Item.Frame);
      SDL3.Windows.Start_Text_Input (Item.Frame);  --  for fields; typing comes as text
      Widgets.Set_Density (Tree, SDL3.Windows.Pixel_Density (Item.Frame));
      Widgets.Set_Clipboard (Tree, Item.Board);
      Widgets.Set_Line_Texts (Tree, Item.Lines);
      Follow_System (Item);
   end Open;

   function Is_Open (Item : Window) return Boolean
   is (SDL3.Windows.Is_Open (Item.Frame));

   procedure Set_Title (Item : in out Window; Title : String) is
   begin
      SDL3.Windows.Set_Title (Item.Frame, Title);
   end Set_Title;

   procedure Set_Size (Item : in out Window; Width : Positive; Height : Positive) is
   begin
      SDL3.Windows.Set_Size (Item.Frame, Width, Height);
      Item.Restyle := True;
   end Set_Size;

   procedure Close (Item : in out Window) is
   begin
      Item.Stopping := True;
      Events.Wake;
   end Close;

   function Is_Closing (Item : Window) return Boolean
   is (Item.Stopping);

   function System_Theme return Pomarine.Themes.Theme
   is (if Events.System_Is_Dark then Pomarine.Themes.Dark else Pomarine.Themes.Light);

   procedure Set_Theme (Item : in out Window; Colors : Pomarine.Themes.Theme) is
   begin
      Item.Following := False;
      Item.Active := Colors;
      Item.Restyle := True;
   end Set_Theme;

   procedure Follow_System (Item : in out Window) is
   begin
      Item.Following := True;
      Item.Active := System_Theme;
      Item.Restyle := True;
   end Follow_System;

   procedure Step (Item : in out Window; Tree : in out Widgets.Tree; Wait_For : Integer := -1; Closed : out Boolean) is
      Event   : Events.Event;
      Handled : Boolean;
      Resized : Boolean;

      function Shorter (Widgets_Want, Caller_Wants : Integer) return Integer
      is (if Widgets_Want < 0
          then Caller_Wants
          elsif Caller_Wants < 0
          then Widgets_Want
          else Integer'Min (Widgets_Want, Caller_Wants));
   begin
      if not Item.Stopping then
         if Events.Wait (Event, Timeout_MS => Shorter (Widgets.Until_Update (Tree), Wait_For)) then
            loop
               case Event.Kind is
                  when Events.Quit          =>
                     Item.Stopping := True;

                  when Events.Redraw        =>
                     Widgets.Invalidate_All (Tree);

                  when Events.Theme_Changed =>
                     if Item.Following then
                        Item.Active := System_Theme;
                        Item.Restyle := True;
                     end if;
                     Widgets.Dispatch (Tree, Event, Handled);

                  when others               =>
                     Widgets.Dispatch (Tree, Event, Handled);
               end case;
               exit when not Events.Poll (Event);
            end loop;
         end if;
         Widgets.Update (Tree, Events.Ticks);

         if Item.Restyle then
            Widgets.Invalidate_All (Tree);
            Item.Restyle := False;
         end if;
         if Widgets.Needs_Paint (Tree) then
            Pomarine.Line_Texts.Begin_Frame (Item.Lines);
            SDL3.Windows.Renderers.Fit (Item.Target, Resized);
            Widgets.Paint
              (Tree, Item.Target, Item.Active, Retained => SDL3.Windows.Renderers.Keeps_Frame (Item.Target));
            SDL3.Windows.Renderers.Present (Item.Target);
         end if;
      end if;
      Closed := Item.Stopping;
   end Step;

   procedure Run
     (Item : in out Window; Tree : in out Widgets.Tree; Idle : Idle_Procedure := null; Idle_Period : Positive := 100)
   is
      Closed : Boolean;
   begin
      loop
         Step (Item, Tree, Wait_For => (if Idle = null then -1 else Idle_Period), Closed => Closed);
         exit when Closed;
         if Idle /= null then
            Idle.all;
         end if;
      end loop;
   end Run;

end Pomarine.Windows;
