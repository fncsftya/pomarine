with Ada.Finalization;
with Pomarine.Models;
with Pomarine.View_Models;
with Pomarine.Widgets;
with System;
with System.Storage_Pools.Subpools;

--  What Pomarine.UI.Contexts does that does not depend on the type of the model, once, so that each instance of
--  Contexts is only the model's own subprograms and the typed calls into this.
--
--  The model is its address here, and the commands their numbers: an instance says how to read and write the model
--  (the adapters) and how to do a command (the hooks), and this makes the bindings, in the arena of the scope, and
--  keeps them up to date. The application does not use this package; see Pomarine.UI.Contexts.

package Pomarine.UI.Binders is

   package VM renames Pomarine.View_Models;

   --  How a binding reads and writes the model: the adapter of a property, made in the arena of its scope.

   type Text_Adapter is limited interface;
   function Current (Self : Text_Adapter; Item : System.Address; Index : Natural) return String is abstract;
   procedure Assign (Self : Text_Adapter; Item : System.Address; Value : String; Index : Natural) is abstract;
   function Stamp (Self : Text_Adapter; Item : System.Address; Index : Natural) return VM.Version_Number is abstract;
   function Can_Assign (Self : Text_Adapter) return Boolean is abstract;
   type Text_Adapter_Ref is access constant Text_Adapter'Class;

   type Count_Adapter is limited interface;
   function Current (Self : Count_Adapter; Item : System.Address) return Natural is abstract;
   type Count_Adapter_Ref is access constant Count_Adapter'Class;

   type Rows_Adapter is limited interface;
   function Rows_Of (Self : Rows_Adapter; Item : System.Address) return Pomarine.Models.Model_Access is abstract;
   type Rows_Adapter_Ref is access constant Rows_Adapter'Class;

   type Choice_Adapter is limited interface;
   function Chosen (Self : Choice_Adapter; Item : System.Address) return Natural is abstract;
   procedure Choose (Self : Choice_Adapter; Item : System.Address; Id : Natural) is abstract;
   function Stamp (Self : Choice_Adapter; Item : System.Address) return VM.Version_Number is abstract;
   type Choice_Adapter_Ref is access constant Choice_Adapter'Class;

   type Flag_Adapter is limited interface;
   function Current (Self : Flag_Adapter; Item : System.Address; Index : Natural) return Boolean is abstract;
   procedure Assign (Self : Flag_Adapter; Item : System.Address; Value : Boolean; Index : Natural) is abstract;
   function Can_Assign (Self : Flag_Adapter) return Boolean is abstract;
   type Flag_Adapter_Ref is access constant Flag_Adapter'Class;

   type Fraction_Adapter is limited interface;
   function Current (Self : Fraction_Adapter; Item : System.Address) return Float is abstract;
   procedure Assign (Self : Fraction_Adapter; Item : System.Address; Value : Float) is null;
   function Can_Assign (Self : Fraction_Adapter) return Boolean is abstract;
   type Fraction_Adapter_Ref is access constant Fraction_Adapter'Class;

   type Action_Adapter is limited interface;
   function May_Perform (Self : Action_Adapter; Item : System.Address) return Boolean is abstract;
   procedure Run_Action (Self : Action_Adapter; Item : System.Address) is abstract;
   type Action_Adapter_Ref is access constant Action_Adapter'Class;

   --  How the model's commands are asked and done: the model's Can_Execute and Execute, of the command numbered Which.

   type Model_Hooks is limited interface;
   function Can_Execute (Self : Model_Hooks; Item : System.Address; Which : Natural; Index : Natural) return Boolean
   is abstract;
   procedure Execute (Self : Model_Hooks; Item : System.Address; Which : Natural; Index : Natural) is abstract;
   type Hooks_Ref is access constant Model_Hooks'Class;

   type Replacement is (Caret_At_End, Caret_At_Start, Caret_Kept);
   type Editor_Hook is (Tool_Used, Link_Followed, Link_Asked);
   type Canvas_Hook is (Line_Selected, Line_Deleted);

   type Which_Array is array (Positive range <>) of Natural;

   --  Contexts

   type Context is new Ada.Finalization.Limited_Controlled with private;

   procedure Attach
     (Item : in out Context; Screen : in out Pomarine.UI.View; Data : System.Address; Hooks : not null Hooks_Ref);
   --  Make Item the context of the view's own scope, of the model at Data.

   procedure Open_Under (Item : in out Context; Parent : Context'Class);
   --  Make Item the context of a scope of its own, under that of Parent (the start of a component).

   procedure Abandon (Item : Context'Class);
   --  Throw away the scope of Item and all in it, if the view is still there.

   procedure Commit_Scope_Of (Item : Context'Class);
   --  Join the scope of Item to its parent's.

   function Scope_Of (Item : Context) return Pomarine.UI.Scope_Ref;

   function Is_Open (Item : Context) return Boolean;

   function Arena (Self : Context'Class) return System.Storage_Pools.Subpools.Subpool_Handle;
   --  Where the adapters of the properties of Self's scope are made.

   procedure Describe (Item : in out Pomarine.Widgets.Widget'Class; Tooltip : String; Name : String := "");

   function View_Number (Self : Context'Class) return Natural;
   --  The number of the view, to find it (Pomarine.UI.Find_View).

private

   function View_Of (Self : Context'Class) return not null View_Ref;
   --  For what is in Controls: not Pomarine.UI.Contexts, which has its own.

   type Context is new Ada.Finalization.Limited_Controlled with record
      Number : Natural := 0;
      Data   : System.Address := System.Null_Address;
      Hooks  : Hooks_Ref;
      Scope  : Pomarine.UI.Scope_Ref;
   end record;

end Pomarine.UI.Binders;
