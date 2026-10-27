with Pomarine.Widgets.Callbacks;

--  Handlers for what a window says (see Pomarine.Widgets.Callbacks):
--
--     Click-like: Close, Minimize and Restore, Double_Click for its title
--     pressed twice (when it can be edited), Move and Resize with the
--     Across and Down it is dragged, and Submit for Return in the title's
--     field. Blur is of the title's field, that lost the focus.

generic
   type Context is limited private;
package Pomarine.Widgets.Frames.Handlers is

   package Plain is new Pomarine.Widgets.Callbacks (Context);

   subtype Handler is Plain.Handler;

   procedure On (Item : in out Frame; Kind : Event_Kind; Self : not null access Context; Do_This : not null Handler);
   --  When Item says Kind, call Do_This with Self. Self must be there as
   --  long as Item is in use. Replaces a handler for that kind.

   procedure Off (Item : in out Frame; Kind : Event_Kind);

end Pomarine.Widgets.Frames.Handlers;
