with System;

--  Work from other threads for the thread that runs the window: a
--  download that has finished, a transcription that has a word. The window
--  is one thread's, and nothing it shows is changed from another; what
--  another thread does is to Post a procedure, which the window's thread
--  runs, between its events, when it next turns (Run_Posted).
--
--  Posting wakes the loop (Pomarine.Events.Wake), so a window that waits for
--  events is not left waiting.
package Pomarine.Application is

   type Handler is access procedure (Data : System.Address);

   Capacity : constant := 64;
   --  How many are kept before the window's thread runs them.

   function Post (Run : not null Handler; Data : System.Address := System.Null_Address)
      return Boolean;
   --  Have the window's thread call Run (Data). From any thread. False if
   --  there is no room (Capacity are waiting): nothing is kept; try again
   --  later, or do without. Data must be there when it is run.

   procedure Run_Posted;
   --  From the window's thread: call what has been posted, in the order
   --  it was, and what is posted as they are run too. An exception from
   --  one is not kept from the rest: they are all run, and the first is
   --  raised after.

   function Is_Waiting return Boolean;
   --  Whether anything is posted that has not been run.

   function Dropped return Natural;
   --  How many Posts had no room, since the start.

end Pomarine.Application;
