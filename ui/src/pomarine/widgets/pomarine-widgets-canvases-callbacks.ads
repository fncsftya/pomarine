--  Handlers for what a canvas says of its lines, each a procedure of the
--  application's own, called with the object it belongs to, as
--  Pomarine.Widgets.Callbacks does for what many widgets say:
--
--     package Board_Callbacks is new Pomarine.Widgets.Canvases.Callbacks (Board);
--     procedure Line_Selected (Self : in out Board; Source : in out Canvas'Class; Tag : Natural);
--     ...
--     Board_Callbacks.On_Select (Canvas, Board'Access, Line_Selected'Access);
--
--  Like the others, they are called after the event that caused them, so
--  that they may change the tree.
generic
   type Context is limited private;
package Pomarine.Widgets.Canvases.Callbacks is

   type Select_Handler is access procedure
     (Self   : in out Context;
      Source : in out Canvas'Class;
      Tag    : Natural);

   type Delete_Handler is access procedure
     (Self   : in out Context;
      Source : in out Canvas'Class);

   procedure On_Select
     (Item    : in out Canvas'Class;
      Self    : not null access Context;
      Do_This : not null Select_Handler);
   --  When a press on a line, or on the canvas where there is none, or
   --  Escape changes which line is selected, call Do_This with its Tag, 0
   --  for none. Self must be there as long as Item is in use.

   procedure On_Delete
     (Item    : in out Canvas'Class;
      Self    : not null access Context;
      Do_This : not null Delete_Handler);
   --  When Backspace or Delete is pressed while a line is selected.

   procedure Off_Select (Item : in out Canvas'Class);

   procedure Off_Delete (Item : in out Canvas'Class);

end Pomarine.Widgets.Canvases.Callbacks;
