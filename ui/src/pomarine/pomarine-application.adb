with Ada.Exceptions;
with Pomarine.Events;

package body Pomarine.Application is

   type Entry_Type is record
      Run  : Handler;
      Data : System.Address;
   end record;

   type Entry_Array is array (1 .. Capacity) of Entry_Type;

   protected Queue is
      procedure Put (Run : Handler; Data : System.Address; Kept : out Boolean);
      procedure Take (Run : out Handler; Data : out System.Address; Found : out Boolean);
      function Waiting return Boolean;
      function Lost return Natural;
   private
      Items  : Entry_Array;
      First  : Positive := 1;
      Count  : Natural := 0;
      Missed : Natural := 0;
   end Queue;

   protected body Queue is

      procedure Put (Run : Handler; Data : System.Address; Kept : out Boolean) is
      begin
         Kept := Count < Capacity;
         if Kept then
            Items ((First + Count - 1) mod Capacity + 1) := (Run, Data);
            Count := Count + 1;
         else
            Missed := Missed + 1;
         end if;
      end Put;

      procedure Take (Run : out Handler; Data : out System.Address; Found : out Boolean) is
      begin
         Found := Count > 0;
         if Found then
            Run := Items (First).Run;
            Data := Items (First).Data;
            First := First mod Capacity + 1;
            Count := Count - 1;
         else
            Run := null;
            Data := System.Null_Address;
         end if;
      end Take;

      function Waiting return Boolean
      is (Count > 0);

      function Lost return Natural
      is (Missed);

   end Queue;

   function Post (Run : not null Handler; Data : System.Address := System.Null_Address) return Boolean is
      Kept : Boolean;
   begin
      Queue.Put (Run, Data, Kept);
      if Kept then
         Pomarine.Events.Wake;
      end if;
      return Kept;
   end Post;

   procedure Run_Posted is
      Run    : Handler;
      Data   : System.Address;
      Found  : Boolean;
      Failed : Ada.Exceptions.Exception_Occurrence;
      Raised : Boolean := False;
   begin
      loop
         Queue.Take (Run, Data, Found);
         exit when not Found;
         begin
            Run (Data);
         exception
            when Problem : others =>
               if not Raised then
                  Ada.Exceptions.Save_Occurrence (Failed, Problem);
                  Raised := True;
               end if;
         end;
      end loop;
      if Raised then
         Ada.Exceptions.Reraise_Occurrence (Failed);
      end if;
   end Run_Posted;

   function Is_Waiting return Boolean
   is (Queue.Waiting);

   function Dropped return Natural
   is (Queue.Lost);

end Pomarine.Application;
