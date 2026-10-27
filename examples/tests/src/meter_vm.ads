with Pomarine.View_Models;

--  A model for the tests of the properties made of a model's own subprograms (Showing, Editing, Doing, and the rest),
--  and of Observed_Model, which counts its changes for it.

package Meter_VM is
   type Command is (Raise_Level);
   package Commands is new Pomarine.View_Models.Command_Models (Command);
   type Model is limited new Commands.Observed_Model with private;

   overriding
   function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding
   procedure Perform (Self : in out Model; What : Command; Index : Natural := 0);

   function Level (Self : Model) return Float;
   procedure Set_Level (Self : in out Model; To : Float);
   function Row_Text (Self : Model; Index : Positive) return String;
   function Armed (Self : Model) return Boolean;
   procedure Set_Armed (Self : in out Model; To : Boolean);
   function Is_Row_Odd (Self : Model; Index : Positive) return Boolean;
   function Can_Zero (Self : Model) return Boolean;
   procedure Zero (Self : in out Model);
   function Zeroed (Self : Model) return Natural;
   --  How many times Zero was done.

private
   type Model is limited new Commands.Observed_Model with record
      Height : Float := 0.0;
      Ready  : Boolean := False;
      Zeros  : Natural := 0;
   end record;
end Meter_VM;
