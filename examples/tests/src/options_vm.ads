with Pomarine.View_Models;

--  A model of choices, for the tests of the controls of Pomarine.UI: a radio pair, a switch, a job that
--  goes on, and what is shown only while it does.
package Options_VM is

   type Command is (Pick_Light, Pick_Dark, Toggle_Sync, Start, Finish, Open_Card);
   --  Open_Card: Index is the card.
   package Commands is new Pomarine.View_Models.Command_Models (Command);

   type Model is limited new Commands.Model with private;

   overriding function Version (Self : Model) return Pomarine.View_Models.Version_Number;
   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0);

   function Caption (Self : Model) return String;
   function Dark (Self : Model) return Boolean;
   function Light (Self : Model) return Boolean;
   function Sync (Self : Model) return Boolean;
   function Running (Self : Model) return Boolean;
   function Idle (Self : Model) return Boolean;
   function Fraction (Self : Model) return Float;

   procedure Advance (Self : in out Model; To : Float);
   --  As a thread would: the job is that far on.

   function Card_Count (Self : Model) return Natural;
   function Card_Title (Self : Model; Row : Positive) return String;
   function Has_Card (Self : Model; Row : Positive) return Boolean;
   function Opened (Self : Model) return Natural;
   --  The last card opened, 0 if none.

   procedure Set_Cards (Self : in out Model; To : Natural);

   procedure Lock_Sync (Self : in out Model);
   --  Toggle_Sync can no longer be done.

private

   type Model is limited new Commands.Model with record
      Changes : Pomarine.View_Models.Change_Counter;
      Is_Dark : Boolean := False;
      Synced  : Boolean := False;
      Locked  : Boolean := False;
      Busy    : Boolean := False;
      Done    : Float := 0.0;
      Cards   : Natural := 0;
      Last    : Natural := 0;
   end record;

end Options_VM;
