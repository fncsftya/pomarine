--  Tests of what widgets say to a listener, and of the layout helpers that
--  build them. See Goldens.
package Listener_Tests is

   procedure Click;
   --  A button's click, and its tag and index, said after the event that
   --  caused it, and still there to take.

   procedure Command_Tags;
   --  An enumeration for the tags.

   procedure Own_Listener;
   --  A widget's own listener, rather than the tree's.

   procedure Deferred;
   --  What is done about an event may remove the widget it came from.

   procedure Controls;
   --  Checks, grips and fields.

   procedure Layout_Helpers;
   --  Styling in points, hairlines, shadows and the order of adding.

end Listener_Tests;
