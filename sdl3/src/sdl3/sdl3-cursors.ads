--  The pointer's shape, from the system's own.
package SDL3.Cursors is

   type Kind is (Default, Move, Pointer, Resize, Crosshair, Resize_Across,
                 Grab, Grabbing, Text);
   --  Default: the arrow. Move: four arrows, for what is being dragged or
   --  panned. Pointer: a hand, for what can be clicked. Resize: two arrows
   --  across a diagonal, for what is sized by a corner. Crosshair: for what
   --  is drawn on. Resize_Across: two arrows left and right, for what is
   --  sized by an edge. Grab: an open hand, for what can be taken hold of
   --  and dragged; Grabbing: a closed one, for while it is. Text: the I-beam,
   --  for text that can be edited.

   procedure Set (Which : Kind);
   --  Show the cursor for the window the pointer is over. Made the first
   --  time, and kept. SDL must be initialized.

end SDL3.Cursors;
