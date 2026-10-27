with Ada.Strings.Unbounded;

--  The parts of a view-model, which is what a screen means: what it shows
--  (properties), what it can be asked to do (commands) and whether any of
--  that has changed (a version). It names no widget, tree or window, so it
--  is tested with none: see Pomarine.Widgets.Bindings for the view that
--  shows it.
--
--  A view-model says that it changed by a Version that it exposes, and the
--  view asks (it polls, once a turn and after each event), as a list asks
--  its Pomarine.Models.List_Model. Nothing is observed, so nothing is
--  allocated and no lifetime is shared. A view-model of several parts adds
--  their versions: each change adds one to its own part's, so adds one to
--  the sum.

package Pomarine.View_Models is

   type Version_Number is mod 2**32;
   --  Modular, so that counting changes never overflows: a number that is
   --  not what a view saw says something changed.

   --  Counting changes

   type Change_Counter is private;

   function Value (Self : Change_Counter) return Version_Number;

   procedure Bump (Self : in out Change_Counter)
   with Post => Value (Self) = Value (Self)'Old + 1;
   --  Something changed.

   function Starting_At (Number : Version_Number) return Change_Counter
   with Post => Value (Starting_At'Result) = Number;
   --  For a test that counts past the end.

   --  Seeing changes

   type Watch is private;
   --  What a view last saw of a version. A new one has seen nothing, so
   --  the first Changed is True.

   function Changed (Self : in out Watch; Now : Version_Number) return Boolean;
   --  Whether Now is not what was last seen, and if so remember it. It
   --  has that effect on Self, so ask it once a turn:
   --
   --     if Changed (Seen, Version (Model)) then ... show ... end if;

   procedure See (Self : in out Watch; Now : Version_Number);
   --  Take Now as seen without asking: for a view that has just shown it all.

   --  Properties

   generic
      type Element is private;
      with function "=" (Left, Right : Element) return Boolean is <>;
   package Properties is

      type Property is limited private;

      function Get (Self : Property) return Element;

      function Version (Self : Property) return Version_Number;

      procedure Set (Self : in out Property; To : Element)
      with
        Post => Version (Self) = Version (Self)'Old + (if Get (Self)'Old = To then 0 else 1) and then Get (Self) = To;
      --  Put To there: a change only if it is not what was. So the view may
      --  set it from a widget every turn without every turn being a change.

      procedure Initialize (Self : out Property; To : Element)
      with Post => Get (Self) = To and then Version (Self) = 0;
      --  To begin with: a change of nothing.

   private

      type Property is limited record
         Current : Element;
         Count   : Change_Counter;
      end record;

   end Properties;

   --  Text has no fixed length, so no cap, and has a property of its own.

   type Text_Property is limited private;

   function Get (Self : Text_Property) return String;

   function Version (Self : Text_Property) return Version_Number;

   procedure Set (Self : in out Text_Property; To : String)
   with Post => Version (Self) = Version (Self)'Old + (if Get (Self)'Old = To then 0 else 1) and then Get (Self) = To;

   --  Commands

   generic
      type Command is (<>);
   package Command_Models is

      type Model is limited interface;
      --  What a view-model offers a view that has commands. Which command
      --  a widget triggers is the view's to say (Bindings); whether it is
      --  possible, and what it does, is this.

      function Version (Self : Model) return Version_Number is abstract;
      --  Different whenever anything the model shows is.

      function Can_Execute (Self : Model; What : Command; Index : Natural := 0) return Boolean is abstract;
      --  Whether What is possible now: it feeds the tree's validator, which
      --  turns the widgets that trigger it on and off. Index is which of many, as for Execute, so that
      --  one row's button can be on and another's off; 0 asks whether it is for some (or for none).

      procedure Execute (Self : in out Model; What : Command; Index : Natural := 0) is abstract
      with Pre'Class => Can_Execute (Self, What, Index);
      --  Do it. Index is which of many, as the widget said (Event.Index): a
      --  row to open, a choice to take. 0 if it is not one of many.

      type Observed_Model is abstract limited new Model with private;
      --  A model that counts its own changes, so that it need not write Version and bump a counter: derive
      --  from it, say how a command is done (Perform), and call Mark_Changed when something changed that no
      --  command did (a property set by a widget). Execute is Perform and a Mark_Changed.

      overriding
      function Version (Self : Observed_Model) return Version_Number;
      --  The changes counted, and Parts_Version.

      overriding
      function Can_Execute (Self : Observed_Model; What : Command; Index : Natural := 0) return Boolean
      is (False);
      --  Nothing is possible until the model says what is: override it.

      function Parts_Version (Self : Observed_Model) return Version_Number
      is (0);
      --  The versions of the parts that count themselves (a Text_Property, a list model): override it to
      --  add them. Anything a part changes, changes the model.

      procedure Mark_Changed (Self : in out Observed_Model);
      --  Something changed.

      procedure Perform (Self : in out Observed_Model; What : Command; Index : Natural := 0) is abstract;
      --  Do What, as Execute says.

      overriding
      procedure Execute (Self : in out Observed_Model; What : Command; Index : Natural := 0);
      --  Perform it, then Mark_Changed.

   private

      type Observed_Model is abstract limited new Model with record
         Changes : Version_Number := 0;
      end record;

   end Command_Models;

private

   type Change_Counter is record
      Count : Version_Number := 0;
   end record;

   type Watch is record
      Seen  : Version_Number := 0;
      Begun : Boolean := False;
   end record;

   function Value (Self : Change_Counter) return Version_Number
   is (Self.Count);

   function Starting_At (Number : Version_Number) return Change_Counter
   is (Count => Number);

   type Text_Property is limited record
      Current : Ada.Strings.Unbounded.Unbounded_String;
      Count   : Change_Counter;
   end record;

end Pomarine.View_Models;
