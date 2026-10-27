with Pomarine.Semantics;
with SDL3.Painters;

--  A place in the window for a view of the system's own, such as a web page, which is drawn by the system over the
--  window's content and not by the tree: it cannot be drawn into, and it is above whatever the tree draws there.
--  The widget stands for it. It keeps the view where the widget is, and hides it while what the tree draws is to be
--  seen over it (a menu, a dialog: any overlay presented, or the widget hidden), and has the keyboard go where the
--  person has pointed: the view takes it when pressed (the tree never hears of that press), and the tree takes it
--  back when another widget is given the focus.
--
--  The view is the application's: it says what a Host does (see Pomarine.Widgets.Embeds, Host), and the tree knows
--  nothing of the system's view. The host must be there as long as the widget is in use.
--
--  A key that the view takes, as Command with L, is not heard by the tree: the host says, with Shortcut, which of
--  the few the application asked it to keep for the tree has been pressed (Callbacks.On_Shortcut), and the keyboard
--  goes to the tree.

package Pomarine.Widgets.Embeds is

   type Host is limited interface;

   procedure Place (Self : in out Host; Left, Top, Wide, High : Float; Showing : Boolean) is abstract;
   --  Put the view at Left, Top (points, from the window's top left), Wide x High, and show it or hide it. Called
   --  when any of these changes, and so not for each frame.

   procedure Give_Keyboard (Self : in out Host; To_View : Boolean) is abstract;
   --  The keyboard is to be the view's (True), or the tree's.

   function Has_Keyboard (Self : Host) return Boolean is abstract;
   --  Whether the view has the keyboard, as it does when a press in it has given it.

   function Shortcut (Self : in out Host) return Natural is abstract;
   --  A shortcut of the application's that was pressed in the view, since this was last asked: its number, which
   --  is the application's; 0 if none.

   type Host_Access is access all Host'Class;

   type Embed is new Widget with private;

   procedure Set_Host (Item : in out Embed; To : Host_Access);
   --  Null for none: the widget is an empty place.

   function Has_Host (Item : Embed) return Boolean;

   function Is_Showing_View (Item : Embed) return Boolean;
   --  Whether the view was last asked to be shown: the widget is showing, and nothing is presented over the tree.

   overriding
   procedure Placed (Item : in out Embed; Left, Top, Width, Height : Float);

   overriding
   procedure Draw (Item : in out Embed; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme);

   overriding
   procedure Hidden (Item : in out Embed);

   overriding
   procedure Update (Item : in out Embed; Now : Pomarine.Events.Milliseconds);

   overriding
   function Until_Update (Item : Embed) return Integer;

   overriding
   function Is_Focusable (Item : Embed) return Boolean;

   overriding
   procedure Focus_Changed (Item : in out Embed; Focused : Boolean);

   overriding
   procedure Describe (Item : Embed; Facts : in out Semantics.Description);

private

   Poll_Period : constant := 50;
   --  Milliseconds between looks at whether the view has the keyboard: it takes it without the tree being told.

   type Embed is new Widget with record
      View          : Host_Access;
      Left          : Float := 0.0;
      Top           : Float := 0.0;
      Wide          : Float := 0.0;
      High          : Float := 0.0;
      --  Where the tree put it, in pixels.
      Showing       : Boolean := False;
      Told          : Boolean := False;
      --  Whether the host has been told where it is, and what it was told, in points.
      Told_Left     : Float := 0.0;
      Told_Top      : Float := 0.0;
      Told_Wide     : Float := 0.0;
      Told_High     : Float := 0.0;
      Told_Showing  : Boolean := False;
      Shortcut_Hook : Posted_Hook;
   end record;

end Pomarine.Widgets.Embeds;
