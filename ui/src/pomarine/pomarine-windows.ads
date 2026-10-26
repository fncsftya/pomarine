private with Ada.Finalization;
private with Pomarine.Clipboards;
private with Pomarine.Line_Texts;
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
--  An application with a loop of its own does not Run: it asks for one turn at
--  a time (Step), or has Run call it when there is nothing to do (an Idle
--  procedure). The window follows the system's light or dark appearance, unless
--  the application says which (Set_Theme).
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
   --  its pixels to cut, copy and paste with the system's clipboard, and to draw
   --  labels, buttons and rows in the system's interface font.

   function Is_Open (Item : Window) return Boolean;

   procedure Set_Title (Item : in out Window; Title : String)
     with Pre => Is_Open (Item);
   --  What the window's title bar says.

   procedure Set_Size (Item : in out Window; Width : Positive; Height : Positive)
     with Pre => Is_Open (Item);
   --  Ask for the window to be Width x Height points. The tree is laid out
   --  again as the window is drawn.

   procedure Close (Item : in out Window)
     with Pre => Is_Open (Item), Post => Is_Closing (Item);
   --  End the loop (Run, or Step saying Closed), as the window's close button
   --  does, after the turn it is called in. From a handler, or from a procedure
   --  posted with Pomarine.Application.

   function Is_Closing (Item : Window) return Boolean;
   --  Whether the window's loop has been told to end, by Close or by the person.

   procedure Set_Theme (Item : in out Window; Colors : Pomarine.Themes.Theme)
     with Pre => Is_Open (Item);
   --  Draw with Colors, and not as the system's appearance changes.

   procedure Follow_System (Item : in out Window)
     with Pre => Is_Open (Item);
   --  Draw in Pomarine.Themes.Light or Dark as the system's appearance is, and
   --  as it changes (Theme_Changed). What a window does when it is opened.

   procedure Step
     (Item       : in out Window;
      Tree       : in out Widgets.Tree;
      Wait_For   : Integer := -1;
      Closed     : out Boolean)
     with Pre => Is_Open (Item) and then Widgets.Has_Root (Tree),
          Post => Closed = Is_Closing (Item);
   --  One turn of the loop: wait for an event, or for the time a widget wants
   --  to be told, or for Wait_For milliseconds (not at all if it is 0; as long
   --  as it takes if it is negative), whichever is first; give the widgets
   --  what came, and the time; lay out and draw what has changed. Closed if
   --  the loop is to end.

   type Idle_Procedure is access procedure;

   procedure Run
     (Item        : in out Window;
      Tree        : in out Widgets.Tree;
      Idle        : Idle_Procedure := null;
      Idle_Period : Positive := 100)
     with Pre => Is_Open (Item) and then Widgets.Has_Root (Tree);
   --  Step until the window is closed. With Idle, wait no longer than
   --  Idle_Period milliseconds for an event, and call it after each turn: for
   --  an application that has work of its own to interleave.

private

   type Platform is limited new Ada.Finalization.Limited_Controlled with record
      Started : Boolean := False;
   end record;
   --  First in the window, so that the system is let go of after the rest.

   overriding procedure Finalize (Item : in out Platform);

   type Window is limited record
      System : Platform;
      Active : Pomarine.Themes.Theme := Pomarine.Themes.Light;
      Following : Boolean := True;
      Restyle   : Boolean := True;
      --  The colours changed since the tree was drawn.
      Stopping  : Boolean := False;
      Frame  : SDL3.Windows.Window;
      Target : SDL3.Windows.Renderers.Renderer;
      Board  : Pomarine.Clipboards.System_Clipboard;
      Lines  : aliased Pomarine.Line_Texts.Drawer;
      --  after Target, which it draws to
   end record;

end Pomarine.Windows;
