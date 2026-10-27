--  A place for a view of the system's own (Pomarine.Widgets.Embeds), with a host that records what it is told:
--  where the view is put, in points; that it is hidden while an overlay is presented and shown again after; that
--  the keyboard goes to the view when it takes it, and back when another widget is given the focus; and that a
--  shortcut the view kept is heard by the application, with the keyboard back in the tree. See Goldens.

package Embed_Tests is

   procedure Placing;
   procedure Hiding_Under_Overlays;
   procedure Keyboard;
   procedure Shortcuts;

end Embed_Tests;
