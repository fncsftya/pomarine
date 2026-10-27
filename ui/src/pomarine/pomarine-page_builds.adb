with Ada.Unchecked_Deallocation;

package body Pomarine.Page_Builds is

   use type Pomarine.Pages.Page_Access;
   use type Pomarine.Pages.Size_Array_Access;

   type Job_States is (Free, Waiting, Running, Ready, Broken);

   type Job_Record is record
      State  : Job_States := Free;
      Order  : Natural := 0;
      Source : Pomarine.Pages.Source_Access;
      Index  : Positive := 1;
      Count  : Natural := 0;
      --  More than 0 if it is the sizes of that many pages, not a page.
   end record;

   type Job_Array is array (Ticket) of Job_Record;

   Contents : array (Ticket) of Pomarine.Pages.Page_Access;
   Founds   : array (Ticket) of Result_Access;
   Measured : array (Ticket) of Pomarine.Pages.Size_Array_Access;
   --  A job's page: written by its task while it is Running, and otherwise
   --  by no one but the caller, once it is Ready.

   procedure Free is new Ada.Unchecked_Deallocation (Pomarine.Words.Result, Result_Access);

   protected Board is
      procedure Add
        (Source : Pomarine.Pages.Source_Access;
         Index  : Positive;
         Count  : Natural;
         Job    : out Ticket;
         Wake   : out Boolean);
      --  Wake: the task was idle and is now to look for work.
      procedure Claim
        (Job : out Natural; Source : out Pomarine.Pages.Source_Access; Index : out Positive; Count : out Natural);
      --  The next job to make, or 0, when the task is idle.
      procedure Finish (Job : Ticket; Ok : Boolean);
      procedure Cancel (Job : Ticket; Release : out Boolean; Wait : out Boolean);
      --  Release: the caller is to let go of the page. Wait: the job is
      --  running, so is to be cancelled again when it is not.
      procedure Take (Job : Ticket);
      function Standing (Job : Ticket) return States;
      function Busy return Boolean;
   private
      Jobs    : Job_Array;
      Counter : Natural := 0;
      Idle    : Boolean := True;
   end Board;

   protected body Board is

      procedure Add
        (Source : Pomarine.Pages.Source_Access; Index : Positive; Count : Natural; Job : out Ticket; Wake : out Boolean)
      is
      begin
         Job := 1;
         while Jobs (Job).State /= Free loop
            if Job = Ticket'Last then
               raise Program_Error with "too many pages being made";
            end if;
            Job := Job + 1;
         end loop;
         Counter := Counter + 1;
         Jobs (Job) := (State => Waiting, Order => Counter, Source => Source, Index => Index, Count => Count);
         Wake := Idle;
         Idle := False;
      end Add;

      procedure Claim
        (Job : out Natural; Source : out Pomarine.Pages.Source_Access; Index : out Positive; Count : out Natural)
      is
         Best : Natural := 0;
      begin
         for Each in Ticket loop
            if Jobs (Each).State = Waiting and then (Best = 0 or else Jobs (Each).Order < Jobs (Best).Order) then
               Best := Each;
            end if;
         end loop;
         Job := Best;
         Source := null;
         Index := 1;
         Count := 0;
         if Best = 0 then
            Idle := True;
         else
            Jobs (Best).State := Running;
            Source := Jobs (Best).Source;
            Index := Jobs (Best).Index;
            Count := Jobs (Best).Count;
         end if;
      end Claim;

      procedure Finish (Job : Ticket; Ok : Boolean) is
      begin
         Jobs (Job).State := (if Ok then Ready else Broken);
      end Finish;

      procedure Cancel (Job : Ticket; Release : out Boolean; Wait : out Boolean) is
      begin
         Release := Jobs (Job).State = Ready;
         Wait := Jobs (Job).State = Running;
         if not Wait then
            Jobs (Job).State := Free;
         end if;
      end Cancel;

      procedure Take (Job : Ticket) is
      begin
         Jobs (Job).State := Free;
      end Take;

      function Standing (Job : Ticket) return States
      is (case Jobs (Job).State is
            when Ready  => Done,
            when Broken => Failed,
            when others => Working);

      function Busy return Boolean
      is (for some Each of Jobs => Each.State in Waiting | Running);

   end Board;

   task type Worker with Storage_Size => 8 * 1024 * 1024 is
      entry Run;
   end Worker;

   task body Worker is
      Job     : Natural;
      Source  : Pomarine.Pages.Source_Access;
      Index   : Positive;
      Count   : Natural;
      Ok      : Boolean;
      Content : Pomarine.Pages.Page_Access;
      Found   : Result_Access;
      Sizes   : Pomarine.Pages.Size_Array_Access;
   begin
      loop
         select
            accept Run;
         or
            terminate;
         end select;
         loop
            Board.Claim (Job, Source, Index, Count);
            exit when Job = 0;
            if Count > 0 then
               Sizes := null;
               begin
                  Source.Measure (Count, Sizes, Ok);
               exception
                  when others =>
                     Ok := False;
               end;
               Ok := Ok and then Sizes /= null;
               if Ok then
                  Measured (Job) := Sizes;
               else
                  Pomarine.Pages.Free (Sizes);
               end if;
            else
               Found := new Pomarine.Words.Result;
               Content := null;
               begin
                  Source.Build (Index, Content, Found.all, Ok);
               exception
                  when others =>
                     Ok := False;
               end;
               Ok := Ok and then Content /= null;
               if Ok then
                  Contents (Job) := Content;
                  Founds (Job) := Found;
               else
                  Pomarine.Pages.Free (Content);
                  Free (Found);
               end if;
            end if;
            Board.Finish (Job, Ok);
         end loop;
      end loop;
   end Worker;

   type Worker_Ref is access Worker;

   protected Latch is
      entry Take;
      procedure Give;
   private
      Held : Boolean := False;
   end Latch;

   protected body Latch is
      entry Take when not Held is
      begin
         Held := True;
      end Take;

      procedure Give is
      begin
         Held := False;
      end Give;
   end Latch;
   --  One at a time makes a task: a protected action may not.

   Engine : Worker_Ref;
   --  Made when first wanted, so that a program that builds no page has no task.

   function Started return Worker_Ref is
      Found : Worker_Ref;
   begin
      Latch.Take;
      begin
         if Engine = null then
            Engine := new Worker;
         end if;
         Found := Engine;
      exception
         when others =>
            Latch.Give;
            raise;
      end;
      Latch.Give;
      return Found;
   end Started;

   procedure Request (Source : Pomarine.Pages.Source_Access; Index : Positive; Job : out Ticket) is
      Wake : Boolean;
   begin
      Board.Add (Source, Index, 0, Job, Wake);
      if Wake then
         Started.Run;
      end if;
   end Request;

   procedure Request_Sizes (Source : Pomarine.Pages.Source_Access; Count : Positive; Job : out Ticket) is
      Wake : Boolean;
   begin
      Board.Add (Source, 1, Count, Job, Wake);
      if Wake then
         Started.Run;
      end if;
   end Request_Sizes;

   procedure Take_Sizes (Job : Ticket; Sizes : out Pomarine.Pages.Size_Array_Access) is
   begin
      Sizes := Measured (Job);
      Measured (Job) := null;
      Board.Take (Job);
   end Take_Sizes;

   function State (Job : Ticket) return States
   is (Board.Standing (Job));

   procedure Take (Job : Ticket; Content : out Pomarine.Pages.Page_Access; Found : out Result_Access) is
   begin
      Content := Contents (Job);
      Found := Founds (Job);
      Contents (Job) := null;
      Founds (Job) := null;
      Board.Take (Job);
   end Take;

   procedure Cancel (Job : Ticket) is
      Release, Wait : Boolean;
   begin
      loop
         Board.Cancel (Job, Release, Wait);
         if Release then
            Pomarine.Pages.Free (Contents (Job));
            Free (Founds (Job));
            Pomarine.Pages.Free (Measured (Job));
         end if;
         exit when not Wait;
         delay 0.001;
      end loop;
   end Cancel;

   procedure Wait_Until_Idle is
   begin
      while Board.Busy loop
         delay 0.001;
      end loop;
   end Wait_Until_Idle;

end Pomarine.Page_Builds;
