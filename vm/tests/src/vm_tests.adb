with Ada.Assertions;
with Ada.Text_IO;
with Pomarine.View_Models;

--  The view-model parts with no window, display or event: what a count of
--  changes does, and the contracts of a command. Each check says what it
--  expects; a failure raises.

procedure VM_Tests is
   package VM renames Pomarine.View_Models;
   use type VM.Version_Number;

   Checks : Natural := 0;

   procedure Check (Condition : Boolean; What : String) is
   begin
      Checks := Checks + 1;
      if not Condition then
         raise Program_Error with What;
      end if;
   end Check;

   procedure Counting is
      Count : VM.Change_Counter;
   begin
      Check (VM.Value (Count) = 0, "a counter starts at 0");
      VM.Bump (Count);
      VM.Bump (Count);
      Check (VM.Value (Count) = 2, "each bump is one");

      --  Past the end it goes round, and is still a change.
      Count := VM.Starting_At (VM.Version_Number'Last);
      VM.Bump (Count);
      Check (VM.Value (Count) = 0, "it wraps, it does not overflow");
   end Counting;

   procedure Watching is
      Eyes : VM.Watch;
   begin
      Check (VM.Changed (Eyes, 0), "the first look is a change, even of 0");
      Check (not VM.Changed (Eyes, 0), "the same is not");
      Check (VM.Changed (Eyes, 1), "another number is");
      Check (not VM.Changed (Eyes, 1), "and seen once");
      Check (VM.Changed (Eyes, 0), "going back is a change too");
      VM.See (Eyes, 5);
      Check (not VM.Changed (Eyes, 5), "what was seen without asking is not a change");
      Check (VM.Changed (Eyes, 6), "and the next is");
   end Watching;

   package Numbers is new VM.Properties (Integer);

   procedure Properties is
      Count : Numbers.Property;
      Name  : VM.Text_Property;
   begin
      Numbers.Initialize (Count, 7);
      Check (Numbers.Get (Count) = 7 and then Numbers.Version (Count) = 0, "initialised is not changed");
      Numbers.Set (Count, 7);
      Check (Numbers.Version (Count) = 0, "setting what it is is not a change");
      Numbers.Set (Count, 8);
      Check (Numbers.Get (Count) = 8 and then Numbers.Version (Count) = 1, "setting another is");
      Numbers.Set (Count, 8);
      Check (Numbers.Version (Count) = 1, "and again is not");

      Check (VM.Get (Name) = "" and then VM.Version (Name) = 0, "text begins empty");
      VM.Set (Name, "");
      Check (VM.Version (Name) = 0, "empty to empty is not a change");
      VM.Set (Name, "Great skua");
      Check (VM.Get (Name) = "Great skua" and then VM.Version (Name) = 1, "text changed");
      VM.Set (Name, "Great skua");
      Check (VM.Version (Name) = 1, "the same text is not");
      VM.Set (Name, [1 .. 100_000 => 'x']);
      Check (VM.Get (Name)'Length = 100_000, "text has no cap");
   end Properties;

   --  A command model, to check the contract it is given.

   type Verb is (Open, Close);
   package Verbs is new VM.Command_Models (Verb);

   type Door is limited new Verbs.Model with record
      Is_Open : Boolean := False;
      Count   : VM.Change_Counter;
      Index   : Natural := 0;
   end record;

   overriding
   function Version (Self : Door) return VM.Version_Number
   is (VM.Value (Self.Count));

   overriding
   function Can_Execute (Self : Door; What : Verb; Index : Natural := 0) return Boolean
   is (Index < 10
       and then (case What is
                   when Open  => not Self.Is_Open,
                   when Close => Self.Is_Open));

   overriding
   procedure Execute (Self : in out Door; What : Verb; Index : Natural := 0);

   overriding
   procedure Execute (Self : in out Door; What : Verb; Index : Natural := 0) is
   begin
      Self.Is_Open := What = Open;
      Self.Index := Index;
      VM.Bump (Self.Count);
   end Execute;

   procedure Commands is
      Gate   : Door;
      Model  : Verbs.Model'Class renames Verbs.Model'Class (Gate);
      Raised : Boolean := False;
   begin
      Check (Model.Can_Execute (Open) and then not Model.Can_Execute (Close), "a shut door can be opened");
      Verbs.Execute (Model, Open, Index => 3);
      Check (Gate.Is_Open and then Gate.Index = 3 and then Model.Version = 1, "opened, with its index");
      Check (not Model.Can_Execute (Open) and then Model.Can_Execute (Close), "now it can be shut");

      --  Which of many is part of whether: there are ten doors.
      Check (Model.Can_Execute (Close, 9) and then not Model.Can_Execute (Close, 10), "the index is asked too");

      --  Doing what is not possible is a mistake of the caller's.
      begin
         Verbs.Execute (Model, Open);
      exception
         when Ada.Assertions.Assertion_Error =>
            Raised := True;
      end;
      Check (Raised, "what cannot be done is refused by its precondition");
      Check (Model.Version = 1, "and changes nothing");
   end Commands;

begin
   Counting;
   Watching;
   Properties;
   Commands;
   Ada.Text_IO.Put_Line ("view-model parts ok," & Checks'Image & " checks");
end VM_Tests;
