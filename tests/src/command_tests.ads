--  Tests of how widgets are told what to do and what they say: handlers
--  of their own, commands that say what is possible, keys bound to them,
--  and the widgets they are offered to. See Goldens.
package Command_Tests is

   procedure Own_Handlers;
   procedure Losing_Focus;
   procedure Validated;
   procedure Keys;
   procedure Responders;
   procedure Event_Payloads;

end Command_Tests;
