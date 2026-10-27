--  Things that open over the window by themselves or by a click: a select with its own menu, a context menu that lets
--  go of itself when a row is chosen, a popover with what is put in it. As a person uses them (Pomarine.Testing).
--  See Goldens.

package Popup_Tests is

   procedure Select_Menu;
   procedure Context_Menu;
   procedure Popover_Box;
   procedure Tooltip_Rests;
   --  A tooltip that shows itself when the pointer has rested, and goes when it moves, a key comes, or a press.
   procedure Menu_Keys;
   --  A menu worked by the arrow keys, Home, End, Return and Space, in a select and as a context menu.
   procedure Wrapped_Message;
   --  A dialog's message wrapped at its width, at each LF, and cut short with an ellipsis.
   procedure Questions;
   --  Pomarine.Dialogs: Alert, Confirm and Choose_From, answered by click, Return and Escape.

end Popup_Tests;
