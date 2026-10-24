private with Ada.Finalization;
private with SDL3.Windows;
private with SDL3.Windows.Renderers;
with Pomarine.Themes;
with Pomarine.Widgets;

--  A window for a tree of widgets, and the loop that runs them, for an
--  application that has no need of the system's windowing beyond that:
--
--     Windows.Open (Win, Tree, "Hello", 320, 160);   --  sets the tree's density
--     Widgets.Set_Root (Tree, Root);                 --  and build it, with handlers
--     Windows.Run (Win, Tree);                       --  until the window is closed
--
--  The window is declared before the tree, which must go before it. What
--  the widgets say is heard by the handlers they were given (see
--  Pomarine.Widgets.Callbacks) or by the tree's listener, from Run.
package Pomarine.Windows is

   type Window is limited private;
   --  Closed when it goes out of scope, and the system is let go with it.

   procedure Open
     (Item   : in out Window;
      Tree   : in out Widgets.Tree;
      Title  : String;
      Width  : Positive;
      Height : Positive;
      Resizable : Boolean := True)
     with Pre => not Is_Open (Item), Post => Is_Open (Item);
   --  Make the window, Width x Height points, and tell Tree the density of
   --  its pixels.

   function Is_Open (Item : Window) return Boolean;

   procedure Run
     (Item   : in out Window;
      Tree   : in out Widgets.Tree;
      Colors : Pomarine.Themes.Theme := Pomarine.Themes.Light)
     with Pre => Is_Open (Item) and then Widgets.Has_Root (Tree);
   --  Give the widgets what is done to the window, lay out and draw what
   --  has changed, and wait for more, until the window is closed.

private

   type Platform is limited new Ada.Finalization.Limited_Controlled with record
      Started : Boolean := False;
   end record;
   --  First in the window, so that the system is let go of after the rest.

   overriding procedure Finalize (Item : in out Platform);

   type Window is limited record
      System : Platform;
      Frame  : SDL3.Windows.Window;
      Target : SDL3.Windows.Renderers.Renderer;
   end record;

end Pomarine.Windows;
