with Ada.Finalization;
with Pomarine.Models;
with Pomarine.View_Models;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Lists;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;

--  Controls declared together with what ties them to a view-model.
--
--  An instance is for one kind of model, and must be instantiated in a
--  package (a library-level one): it allocates in the arenas, which the
--  compiler allows only from there.
--
--     package Todo_UI is new Pomarine.UI.Contexts (Todo_VM.Commands, Todo_VM.Model);
--
--  The adapters say how to read and write the model. Each is a generic
--  instantiated in a package too, so that what a binding keeps is a
--  pointer to something that is there as long as the program is, and
--  neither a local package nor a nested subprogram can be kept:
--
--     package Summary_Adapter is new Todo_UI.Read_Text (Get => Todo_VM.Summary);
--     Task_Summary : constant Todo_UI.Text_Property := Summary_Adapter.Property;
--
--  A Context is the view, the model and the scope that controls are made in.
--  Bind gives the context of the view's root scope; a component declares a Component,
--  which is a Context of a scope of its own, that stays if the component
--  succeeds (Commit) and is thrown away, with every control and binding in it,
--  if it does not:
--
--     function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout is
--        Bound   : aliased Todo_UI.Component (Parent'Access);
--        Done    : constant UI.Button_Handle := Bound.Button ("Done", Command => Toggle_Chosen);
--        Result  : constant UI.Layout := UI.Row ([UI.Place (Done)]);
--     begin
--        Bound.Commit;
--        return Result;
--     end Task_Actions;
--
--  A context is limited and borrows (a pointer to the model, the view by
--  number): it cannot be kept in anything but a limited object, and what it
--  makes does not need it once made. If the view is gone, using it raises
--  Stale_Handle; if the model is gone, nothing helps (see Pomarine.UI).
--
--  The accessibility rules of Ada could not carry this further: a context with
--  access discriminants cannot be made for a nested component (the discriminant
--  of one object cannot give the discriminant of another), so a context holds
--  named access values of library-level types, made once, in Bind.
generic
   with package Commands is new Pomarine.View_Models.Command_Models (<>);
   type Model is limited new Commands.Model with private;
package Pomarine.UI.Contexts is

   package VM renames Pomarine.View_Models;
   package Buttons renames Pomarine.Widgets.Buttons;

   function Whole_Version (Item : Model) return VM.Version_Number is
     (Commands.Version (Commands.Model'Class (Item)));
   --  What an adapter watches unless it is given a version of its own.

   --  Properties: how the model is read and written

   type Text_Adapter is limited interface;
   function Current (Self : Text_Adapter; Item : Model) return String is abstract;
   procedure Assign (Self : Text_Adapter; Item : in out Model; Value : String) is abstract;
   function Stamp (Self : Text_Adapter; Item : Model) return VM.Version_Number is abstract;
   function Can_Assign (Self : Text_Adapter) return Boolean is abstract;
   type Text_Adapter_Ref is access constant Text_Adapter'Class;
   --  Implemented by Read_Text and Edit_Text.

   type Text_Property is private;

   generic
      with function Get (Item : Model) return String;
      with function Changes (Item : Model) return VM.Version_Number is Whole_Version;
   package Read_Text is
      function Property return Text_Property;
      --  A text to show, never written.
   private
      type Adapter is new Text_Adapter with null record;
      overriding function Current (Self : Adapter; Item : Model) return String is (Get (Item));
      overriding procedure Assign (Self : Adapter; Item : in out Model; Value : String) is null;
      overriding function Stamp (Self : Adapter; Item : Model) return VM.Version_Number is (Changes (Item));
      overriding function Can_Assign (Self : Adapter) return Boolean is (False);
      Instance : aliased constant Adapter := (null record);
   end Read_Text;

   generic
      with function Get (Item : Model) return String;
      with procedure Set (Item : in out Model; Value : String);
      with function Changes (Item : Model) return VM.Version_Number is Whole_Version;
   package Edit_Text is
      function Property return Text_Property;
      --  A text to show and to be written by what the person types. Set may
      --  keep another text than it is given (normalize); what the model then
      --  says is shown.
   private
      type Adapter is new Text_Adapter with null record;
      overriding function Current (Self : Adapter; Item : Model) return String is (Get (Item));
      overriding procedure Assign (Self : Adapter; Item : in out Model; Value : String);
      overriding function Stamp (Self : Adapter; Item : Model) return VM.Version_Number is (Changes (Item));
      overriding function Can_Assign (Self : Adapter) return Boolean is (True);
      Instance : aliased constant Adapter := (null record);
   end Edit_Text;

   type Count_Adapter is limited interface;
   function Current (Self : Count_Adapter; Item : Model) return Natural is abstract;
   type Count_Adapter_Ref is access constant Count_Adapter'Class;

   type Count_Property is private;

   generic
      with function Get (Item : Model) return Natural;
   package Counter is
      function Property return Count_Property;
      --  A number, to see whether it grew.
   private
      type Adapter is new Count_Adapter with null record;
      overriding function Current (Self : Adapter; Item : Model) return Natural is (Get (Item));
      Instance : aliased constant Adapter := (null record);
   end Counter;

   type Rows_Adapter is limited interface;
   function Rows_Of (Self : Rows_Adapter; Item : in out Model) return Pomarine.Models.Model_Access is abstract;
   type Rows_Adapter_Ref is access constant Rows_Adapter'Class;

   type Rows_Property is private;

   generic
      type Rows_Model is limited new Pomarine.Models.List_Model with private;
      with function Get (Item : in out Model) return not null access Rows_Model;
   package Row_Source is
      function Property return Rows_Property;
      --  The rows a list shows (see Pomarine.Models): borrowed from the model.
   private
      type Adapter is new Rows_Adapter with null record;
      overriding function Rows_Of (Self : Adapter; Item : in out Model) return Pomarine.Models.Model_Access is
        (Get (Item).all'Unrestricted_Access);
      Instance : aliased constant Adapter := (null record);
   end Row_Source;

   type Choice_Adapter is limited interface;
   function Chosen (Self : Choice_Adapter; Item : Model) return Natural is abstract;
   procedure Choose (Self : Choice_Adapter; Item : in out Model; Id : Natural) is abstract;
   function Stamp (Self : Choice_Adapter; Item : Model) return VM.Version_Number is abstract;
   type Choice_Adapter_Ref is access constant Choice_Adapter'Class;

   type Choice_Property is private;

   generic
      with function Get (Item : Model) return Natural;
      with procedure Set (Item : in out Model; Id : Natural);
      with function Changes (Item : Model) return VM.Version_Number is Whole_Version;
   package Choice is
      function Property return Choice_Property;
      --  Which item is chosen, by its id (Pomarine.Models.List_Model.Row_Id; 0 for none), not
      --  by its place: the choice follows the item when others are removed or the rows are
      --  reordered, and is not given to whatever takes its place.
   private
      type Adapter is new Choice_Adapter with null record;
      overriding function Chosen (Self : Adapter; Item : Model) return Natural is (Get (Item));
      overriding procedure Choose (Self : Adapter; Item : in out Model; Id : Natural);
      overriding function Stamp (Self : Adapter; Item : Model) return VM.Version_Number is (Changes (Item));
      Instance : aliased constant Adapter := (null record);
   end Choice;

   --  Commands that are not an enumeration's: what can be done, and doing it

   type Action_Adapter is limited interface;
   function Allowed (Self : Action_Adapter; Item : Model) return Boolean is abstract;
   procedure Perform (Self : Action_Adapter; Item : in out Model) is abstract;
   type Action_Adapter_Ref is access constant Action_Adapter'Class;

   type Action_Property is private;

   generic
      with function Allowed (Item : Model) return Boolean;
      with procedure Perform (Item : in out Model);
   package Command_Action is
      function Property return Action_Property;
      --  A command of the model that is a pair of subprograms: whether it can be done now (it
      --  turns the buttons that do it on and off), and doing it. Those of Commands, an enumeration's
      --  (Can_Execute, Execute), are used by naming the literal; this is for what is not one.
   private
      type Adapter is new Action_Adapter with null record;
      overriding function Allowed (Self : Adapter; Item : Model) return Boolean is (Allowed (Item));
      overriding procedure Perform (Self : Adapter; Item : in out Model);
      Instance : aliased constant Adapter := (null record);
   end Command_Action;

   --  Contexts

   type Context is new Ada.Finalization.Limited_Controlled with private;

   function Bind
     (Screen : in out Pomarine.UI.View; Data : not null access Model) return Context'Class;
   --  The context of the view's own scope (class-wide, since a component is a
   --  context too). The model must be there as long as the view is used (see
   --  Pomarine.UI).

   function Scope_Of (Item : Context) return Pomarine.UI.Scope_Ref;

   function Is_Open (Item : Context) return Boolean;
   --  Whether its scope still takes controls.

   type Replacement is (Caret_At_End, Caret_At_Start, Caret_Kept);
   --  Where the caret goes when the model gives a field a text other than the field's: the whole
   --  text is replaced (the undo history with it), and the caret is put at the end, at the start,
   --  or, if it can be, where it was.

   function Is_Writable (Item : Text_Property) return Boolean;

   function Label (Self : Context; Text : Text_Property) return Pomarine.UI.Label_Handle;

   function Button
     (Self    : Context;
      Caption : String;
      Command : Commands.Command;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0) return Pomarine.UI.Button_Handle;
   --  A button that does Command when it is clicked, if the model can, and is turned
   --  on and off as the model says.

   function Button
     (Self    : Context;
      Caption : String;
      Action  : Action_Property;
      Look    : Pomarine.Widgets.Buttons.Kind := Pomarine.Widgets.Buttons.Normal;
      Index   : Natural := 0) return Pomarine.UI.Button_Handle;
   --  As above, for a command that is no enumeration's (Action).

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
     with Pre => Is_Writable (Text);

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Commands.Command;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
     with Pre => Is_Writable (Text);

   function Text_Field
     (Self        : Context;
      Text        : Text_Property;
      Submit      : Action_Property;
      Placeholder : String := "";
      Name        : String := "";
      Replacing   : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
     with Pre => Is_Writable (Text);
   --  A field that shows the model's text and gives it what is typed, and, with Submit,
   --  does the command when Return is pressed (the field stays typeable when it cannot).
   --  Name is what an assistive technology (and a test) calls it; none, if not said.

   function List
     (Self      : Context;
      Rows      : Rows_Property;
      Selection : Choice_Property;
      Name      : String := "") return Pomarine.UI.List_Handle;
   --  A list of the model's rows (the existing model-backed rows) and the choice of one of them.

   --  Effects of the view

   procedure Focus_Initially (Self : Context; Target : Pomarine.UI.Focus_Target);
   --  Give the focus to the control when the screen is mounted.

   procedure Reveal_After
     (Self    : Context;
      Command : Commands.Command;
      Target  : Pomarine.UI.Reveal_Target;
      Count   : Count_Property);
   --  After Command is done, if Count has grown, scroll the list to its last row.
   --  The view's, not the model's: the model knows nothing of scrolling.

   --  Controls the application already owns (migration). The view binds and places them
   --  as its own and never finalizes them; when the view goes they are taken out of the
   --  tree and are the application's again. The handler of the event the view hears (Click of a
   --  button, Submit of a field, Choose of a list) is the view's from here.

   function Borrow_Label
     (Self : Context; Existing : in out Pomarine.Widgets.Labels.Label; Text : Text_Property)
      return Pomarine.UI.Label_Handle;

   function Borrow_Button
     (Self     : Context;
      Existing : in out Pomarine.Widgets.Buttons.Button;
      Command  : Commands.Command;
      Index    : Natural := 0) return Pomarine.UI.Button_Handle;

   function Borrow_Field
     (Self      : Context;
      Existing  : in out Pomarine.Widgets.Text_Fields.Text_Field;
      Backing   : aliased in out Texts.Documents.Document;
      Text      : Text_Property;
      Replacing : Replacement := Caret_At_End) return Pomarine.UI.Field_Handle
     with Pre => Is_Writable (Text);
   --  Backing is the document the field shows (the application attached it).

   function Borrow_List
     (Self      : Context;
      Existing  : in out Pomarine.Widgets.Lists.List;
      Rows      : Rows_Property;
      Selection : Choice_Property) return Pomarine.UI.List_Handle;

   --  Components

   type Component (Parent : not null access constant Context'Class) is limited new Context with private;
   --  A context of a scope of its own, under that of Parent. Declare it first in the
   --  component's declarative part; whatever raises after that, the scope and all in it go.

   procedure Commit (Item : in out Component);
   --  The component succeeded: its scope joins the parent's, and stays provisionally until
   --  the screen is mounted. Controls can no longer be made through Item.

private

   type Model_Ref is access all Model;

   type Text_Property is record
      Adapter : Text_Adapter_Ref;
   end record;

   type Count_Property is record
      Adapter : Count_Adapter_Ref;
   end record;

   type Rows_Property is record
      Adapter : Rows_Adapter_Ref;
   end record;

   type Choice_Property is record
      Adapter : Choice_Adapter_Ref;
   end record;

   type Action_Property is record
      Adapter : Action_Adapter_Ref;
   end record;

   function Is_Writable (Item : Text_Property) return Boolean is
     (Item.Adapter /= null and then Item.Adapter.Can_Assign);

   type Context is new Ada.Finalization.Limited_Controlled with record
      Number : Natural := 0;
      Data   : Model_Ref;
      Scope  : Pomarine.UI.Scope_Ref;
   end record;

   type Component (Parent : not null access constant Context'Class) is limited new Context with record
      Committed : Boolean := False;
   end record;

   overriding procedure Initialize (Item : in out Component);
   overriding procedure Finalize (Item : in out Component);

end Pomarine.UI.Contexts;
