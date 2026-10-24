with SDL3;
with Pomarine.Events;

package body Pomarine.Windows is

   overriding procedure Finalize (Item : in out Platform) is
   begin
      if Item.Started then
         SDL3.Shutdown;
         Item.Started := False;
      end if;
   end Finalize;

   procedure Open
     (Item   : in out Window;
      Tree   : in out Widgets.Tree;
      Title  : String;
      Width  : Positive;
      Height : Positive;
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
   end Open;

   function Is_Open (Item : Window) return Boolean is (SDL3.Windows.Is_Open (Item.Frame));

   procedure Run
     (Item   : in out Window;
      Tree   : in out Widgets.Tree;
      Colors : Pomarine.Themes.Theme := Pomarine.Themes.Light)
   is
      Event   : Events.Event;
      Handled : Boolean;
      Done    : Boolean := False;
      Resized : Boolean;
   begin
      while not Done loop
         --  Wait for an event, or for the time a widget wants to be told.
         if Events.Wait (Event, Timeout_MS => Widgets.Until_Update (Tree)) then
            loop
               case Event.Kind is
                  when Events.Quit   => Done := True;
                  when Events.Redraw => Widgets.Invalidate_All (Tree);
                  when others        => Widgets.Dispatch (Tree, Event, Handled);
               end case;
               exit when not Events.Poll (Event);
            end loop;
         end if;
         Widgets.Update (Tree, Events.Ticks);

         if Widgets.Needs_Paint (Tree) then
            Pomarine.Line_Texts.Begin_Frame (Item.Lines);
            SDL3.Windows.Renderers.Fit (Item.Target, Resized);
            Widgets.Paint
              (Tree, Item.Target, Colors, Retained => SDL3.Windows.Renderers.Keeps_Frame (Item.Target));
            SDL3.Windows.Renderers.Present (Item.Target);
         end if;
      end loop;
   end Run;

end Pomarine.Windows;
