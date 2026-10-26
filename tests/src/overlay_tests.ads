--  What floats over the tree (Pomarine.Widgets.Overlays): where it is put by what it is anchored to, on which side,
--  clamped to the window and as wide as the anchor if asked; let go of by Escape or a press outside it and not by one
--  inside, with what the press then does to what is under it; a modal one taking the input and the Tab key, and giving
--  them back. See Goldens.
package Overlay_Tests is

   procedure Placing;
   procedure Placing_At_Edges;
   procedure Letting_Go;
   procedure Modality;
   procedure Stacking;
   procedure Dimming;
   --  A modal overlay has what is under it drawn dimmed, and a light one does not; both give it back.

end Overlay_Tests;
