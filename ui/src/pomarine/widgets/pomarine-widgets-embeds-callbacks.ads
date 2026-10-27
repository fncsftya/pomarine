--  A handler for a key that the view kept for the application (see Pomarine.Widgets.Embeds), a procedure of its own,
--  called with the object it belongs to, after the turn that heard of it so that it may change the tree:
--
--     package Browser_Callbacks is new Pomarine.Widgets.Embeds.Callbacks (Browser);
--     procedure Asked (Self : in out Browser; Source : in out Embed'Class; Which : Positive);
--     ...
--     Browser_Callbacks.On_Shortcut (Page, Browser'Access, Asked'Access);

generic
   type Context is limited private;
package Pomarine.Widgets.Embeds.Callbacks is

   type Shortcut_Handler is access procedure (Self : in out Context; Source : in out Embed'Class; Which : Positive);

   procedure On_Shortcut
     (Item : in out Embed'Class; Self : not null access Context; Do_This : not null Shortcut_Handler);
   --  When the host says a shortcut was pressed in the view, call Do_This with its number. Self must be there as
   --  long as Item is in use.

   procedure Off_Shortcut (Item : in out Embed'Class);

end Pomarine.Widgets.Embeds.Callbacks;
