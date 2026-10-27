--  Handlers for what an editor says that no other widget does, each a
--  procedure of the application's own, called with the object it belongs
--  to, as Pomarine.Widgets.Callbacks does for what many widgets say:
--
--     package Page_Callbacks is new Pomarine.Widgets.Editors.Callbacks (Page);
--     procedure Tool_Used (Self : in out Page; Source : in out Editor'Class; Tool : Positive);
--     ...
--     Page_Callbacks.On_Tool (Text, Page'Access, Tool_Used'Access);
--
--  Like the others, they are called after the event that caused them, so
--  that they may change the tree.

generic
   type Context is limited private;
package Pomarine.Widgets.Editors.Callbacks is

   type Tool_Handler is access procedure (Self : in out Context; Source : in out Editor'Class; Tool : Positive);

   type Link_Handler is access procedure (Self : in out Context; Source : in out Editor'Class);

   procedure On_Tool (Item : in out Editor'Class; Self : not null access Context; Do_This : not null Tool_Handler);
   --  When one of the tools added with Add_Tool is used, call Do_This
   --  with its number, from 1. Self must be there as long as Item is in use.

   procedure On_Follow (Item : in out Editor'Class; Self : not null access Context; Do_This : not null Link_Handler);
   --  When a link is Command-clicked: the address is Followed.

   procedure On_Ask_Link (Item : in out Editor'Class; Self : not null access Context; Do_This : not null Link_Handler);
   --  When it has begun to ask for a link's address: the application may
   --  answer with Add_Link_Choice.

   procedure Off_Tool (Item : in out Editor'Class);

   procedure Off_Follow (Item : in out Editor'Class);

   procedure Off_Ask_Link (Item : in out Editor'Class);

end Pomarine.Widgets.Editors.Callbacks;
