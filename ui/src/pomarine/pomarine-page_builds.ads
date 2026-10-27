with Pomarine.Pages;
with Pomarine.Words;

--  Pages of a document, and how big they are, made in the background, by a task of its own, while
--  the caller goes on drawing. A page is asked for (Request) with a ticket;
--  the caller polls it (State) and, when it is Done, takes it (Take), or
--  gives it up (Cancel). Pages are made one at a time, in the order asked
--  (what makes them, as PDFium, may not be used from two threads at once
--  anyway).
--
--  Only one thread, the caller's, may use the subprograms here.

package Pomarine.Page_Builds is

   use type Pomarine.Pages.Source_Access;

   Max_Builds : constant := 64;
   --  Asked for and not yet taken or given up.

   subtype Ticket is Positive range 1 .. Max_Builds;

   type States is (Working, Done, Failed);
   --  Working: waiting or being made. Done: the page is there to Take.
   --  Failed: it could not be made; Cancel the ticket.

   type Result_Access is access Pomarine.Words.Result;

   procedure Request_Sizes (Source : Pomarine.Pages.Source_Access; Count : Positive; Job : out Ticket)
   with Pre => Source /= null;
   --  Begin to measure the first Count pages of what Source reads (see
   --  Pomarine.Pages.Measure), in the order of the pages asked for.

   procedure Request (Source : Pomarine.Pages.Source_Access; Index : Positive; Job : out Ticket)
   with Pre => Source /= null;
   --  Begin to make page Index of what Source reads. Raises Program_Error
   --  if there are Max_Builds outstanding. Source is used until the ticket
   --  is taken or cancelled, so is not to change before then.

   function State (Job : Ticket) return States;

   procedure Take (Job : Ticket; Content : out Pomarine.Pages.Page_Access; Found : out Result_Access)
   with Pre => State (Job) = Done;
   --  The page and its words, which the caller is to free. The ticket is
   --  used up.

   procedure Take_Sizes (Job : Ticket; Sizes : out Pomarine.Pages.Size_Array_Access)
   with Pre => State (Job) = Done;
   --  The sizes, which the caller is to free. The ticket is used up.

   procedure Cancel (Job : Ticket);
   --  Forget the job, whatever its state; if the page is being made, wait
   --  for that to end. The ticket is used up.

   procedure Wait_Until_Idle;
   --  Wait for every page asked for to be made (or to fail): for tests,
   --  that draw a page the moment it is ready, not when it is.

end Pomarine.Page_Builds;
