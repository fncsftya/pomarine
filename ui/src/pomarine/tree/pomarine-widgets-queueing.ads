--  The events a widget says: queued in the tree, delivered to its handler or its listener, in the order they were said.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.

private package Pomarine.Widgets.Queueing is

   function Run_Hooks (Item : in out Widget'Class; Event : Widget_Event) return Boolean;

   procedure Deliver_All (Item : in out Tree);

   function Made_Event
     (Kind : Event_Kind; Tag : Integer; Index : Natural; Row : Natural; Across, Down : Float; Action : Natural)
      return Widget_Event;

   procedure Enqueue
     (Item   : in out Widget'Class;
      Kind   : Event_Kind;
      Row    : Natural := 0;
      Across : Float := 0.0;
      Down   : Float := 0.0;
      Action : Natural := 0);

   procedure Enqueue_Posted
     (Item : in out Widget'Class; Using : Posted_Hook; Code : Natural := 0; Value : Natural := 0);

end Pomarine.Widgets.Queueing;
