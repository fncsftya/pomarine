--  Handlers for what a widget says, each a procedure of the application's
--  own, called with the object it belongs to:
--
--     package Mixer_Callbacks is new Pomarine.Widgets.Callbacks (Mixer);
--     procedure Louder (Self : in out Mixer; Source : in out Widget'Class;
--                       Event : Widget_Event);
--     ...
--     Mixer_Callbacks.On (Volume, Change, Mixer'Access, Louder'Access);
--
--  A widget that has a handler for a kind of event does not say it to its
--  listener as well. Like the listener's, it is called after the event
--  that caused it, so that it may change the tree, the widget it is for
--  too. A widget keeps one for each kind of event.
--
--  Where the listener (see Pomarine.Widgets.Commands) says everything to
--  one place, this says each thing where it is wanted; use whichever is
--  the clearer.
generic
   type Context is limited private;
package Pomarine.Widgets.Callbacks is

   type Handler is access procedure
     (Self   : in out Context;
      Source : in out Widget'Class;
      Event  : Widget_Event);

   procedure On
     (Item    : in out Widget'Class;
      Kind    : Event_Kind;
      Self    : not null access Context;
      Do_This : not null Handler);
   --  When Item says Kind, call Do_This with Self. Self must be there as
   --  long as Item is in use. Replaces a handler for that kind.

   procedure Off (Item : in out Widget'Class; Kind : Event_Kind);
   --  Back to the listener for Kind.

end Pomarine.Widgets.Callbacks;
