with Ada.Strings.Unbounded;
with Pomarine.View_Models;

--  A model with a text, for the tests of Pomarine.UI: it can normalize what it is given, be changed from
--  elsewhere, and keeps a journal of what was done to it and in what order.
package Form_VM is

   type Command is (Save, Reset);
   package Commands is new Pomarine.View_Models.Command_Models (Command);

   type Model is limited new Commands.Model with private;

   overriding function Version (Self : Model) return Pomarine.View_Models.Version_Number;
   overriding function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean;
   overriding procedure Execute (Self : in out Model; What : Command; Index : Natural := 0);

   type Hook is access procedure;

   Inside_Save : Hook := null;
   --  Called by Execute (Save) after the save is noted and before the name is cleared: for tests of what a
   --  view does when something happens to it while it is doing.

   Inside_Set : Hook := null;
   --  Called by Set_Name, before it keeps the name.

   function Name (Self : Model) return String;
   procedure Set_Name (Self : in out Model; Value : String);
   --  What the person typed. With Shouting, the model keeps it in capitals and without
   --  leading spaces (normalization), so what it says may not be what it was told.

   function Name_Version (Self : Model) return Pomarine.View_Models.Version_Number;
   --  Of the name alone.

   procedure Shouting (Self : in out Model; To : Boolean := True);

   function Saved_Version (Self : Model) return Pomarine.View_Models.Version_Number;
   --  Of what Execute changes, not of the name.

   procedure Touch (Self : in out Model);
   --  A change of the model's version that changes nothing it shows: a view must refresh and find it so.

   function Saved_Count (Self : Model) return Natural;
   function Last_Saved (Self : Model) return String;
   function Status (Self : Model) return String;
   --  "n saved".

   function Journal (Self : Model) return String;
   --  What happened, in order: set(..), save(..), reset.
   procedure Forget_Journal (Self : in out Model);

   procedure Change_From_Elsewhere (Self : in out Model; Value : String);
   --  As a thread or a timer would: the name changes, and no widget was asked.

private

   type Model is limited new Commands.Model with record
      Text    : Pomarine.View_Models.Text_Property;
      Changed : Pomarine.View_Models.Change_Counter;
      Loud    : Boolean := False;
      Saved   : Natural := 0;
      Last    : Ada.Strings.Unbounded.Unbounded_String;
      Log     : Ada.Strings.Unbounded.Unbounded_String;
   end record;

end Form_VM;
