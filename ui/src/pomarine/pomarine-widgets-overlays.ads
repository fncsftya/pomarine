with Pomarine.Anchoring;

--  What floats over the rest of a window: a menu, a popover, a context menu, a dialog. The application makes the
--  content (any widget, with its own size, in the tree, a child of the root or of a box that covers the window), and
--  presents it:
--
--     Overlays.Present_Beside (Menu, Field, (Side => Below, Match_Width => True));   --  a select's choices
--     Overlays.Present_At (Menu, Event.Mouse_X, Event.Mouse_Y);                       --  a context menu
--     Overlays.Present_Centered (Dialog);                                             --  over everything, modal
--
--  It is shown, brought to the front, put by what it is anchored to (on the side that has room, inside the window,
--  and again if the anchor moves or the window is sized), and let go of by Escape or a press outside it, as the
--  Behavior says: it is hidden, and says Dismiss (hear it with Callbacks.On (Content, Dismiss, ...) or the listener)
--  after the event that caused it. Dismiss the content yourself when what it was for is done (Overlays.Dismiss), which
--  says nothing. A modal overlay has Tab go round only what is in it, with the focus in it first, and has the focus
--  back where it was when it goes.
--
--  The tree presents at most Overlay_Capacity (see Pomarine.Widgets) at once: a dialog, the menu over it, the menu of
--  that. Presented content that is taken out of the tree is forgotten.
package Pomarine.Widgets.Overlays is

   Pointer_Placement : constant Anchoring.Placement := (Gap => 12.0, others => <>);
   --  Under the pointer, clear of it.

   --  Match_Width sets the content's width (to the anchor's), and what sets it again is the application's.

   procedure Present_Beside
     (Content : in out Widget'Class;
      Anchor  : Widget'Class;
      Where   : Anchoring.Placement := (others => <>);
      How     : Anchoring.Behavior := Anchoring.Light_Dismiss)
     with Pre  => Is_Attached (Content) and then Parent_Of (Content) /= null and then Is_Attached (Anchor)
                  and then Id_Of (Content) /= Id_Of (Anchor) and then not Is_Presented (Content),
          Post => Is_Presented (Content);
   --  Content, beside Anchor on Where's side, until it is let go of.

   procedure Present_At
     (Content : in out Widget'Class;
      X, Y    : Float;
      Where   : Anchoring.Placement := Pointer_Placement;
      How     : Anchoring.Behavior := Anchoring.Light_Dismiss)
     with Pre  => Is_Attached (Content) and then Parent_Of (Content) /= null and then not Is_Presented (Content),
          Post => Is_Presented (Content);
   --  Content, at the point X, Y, in points from the window's top left (an event's Mouse_X, Mouse_Y).

   procedure Present_Centered
     (Content : in out Widget'Class;
      How     : Anchoring.Behavior := Anchoring.Dialog)
     with Pre  => Is_Attached (Content) and then Parent_Of (Content) /= null and then not Is_Presented (Content),
          Post => Is_Presented (Content);
   --  Content, in the middle of the window, a little above its centre.

   procedure Dismiss (Content : in out Widget'Class)
     with Pre => Is_Attached (Content), Post => not Is_Presented (Content);
   --  Hide Content and what was presented over it, give back the focus a modal one took. Says nothing; nothing is
   --  done if it was not presented.

   procedure Dismiss_All (Home : in out Tree)
     with Post => Presented_Count (Home) = 0;

   function Is_Presented (Content : Widget'Class) return Boolean;
   --  Whether it is one of those the tree is presenting.

   function Presented_Count (Home : Tree) return Natural;

end Pomarine.Widgets.Overlays;
