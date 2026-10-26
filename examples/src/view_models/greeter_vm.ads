with Pomarine.View_Models;

--  The greeting and the command that changes it, independent of widgets.
package Greeter_VM is
   type Command is (Say_Hello);
   package Commands is new Pomarine.View_Models.Command_Models (Command);
   type Model is limited new Commands.Model with private;

   function Count (Self : Model) return Natural;
   function Message (Self : Model) return String;

   overriding function Version (Self : Model) return Pomarine.View_Models.Version_Number;
   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0)
     with Post => Count (Self) = Count (Self)'Old + 1;

private
   type Model is limited new Commands.Model with record
      Greetings : Natural := 0;
      Changed   : Pomarine.View_Models.Change_Counter;
   end record;
end Greeter_VM;
