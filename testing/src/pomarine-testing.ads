with Ada.Containers.Vectors;
with Pomarine.Clipboards;
with Pomarine.Events;
with Pomarine.Semantics;
with Pomarine.Widgets;
with SDL3.Windows.Renderers;

--  A window to test, offscreen, as a person would use it: seen as an
--  assistive technology is told of it, clicked and typed in by what it is
--  called, not by where it is. No pixels, so no goldens, and no coordinates
--  to break when the layout moves.
--
--     Testing.Open (Window, Tree, Width => 640, Height => 480);
--     Testing.Click_On (Window, "Done");
--     Assert (Testing.Is_Disabled (Window, "Delete"));
--     Assert (Testing.Shows (Window, "1 of 2 left"));
--
--  A test of a view-model alone needs none of this (see
--  Pomarine.View_Models); this is for whether the view is tied to it.
package Pomarine.Testing is

   type Session is limited private;

   procedure Open
     (Item    : in out Session;
      Tree    : aliased in out Pomarine.Widgets.Tree;
      Width   : Positive;
      Height  : Positive;
      Density : Float := 1.0)
     with Pre => Pomarine.Widgets.Has_Root (Tree);
   --  Have Tree, whose root is set and whose widgets are built, drawn to an
   --  offscreen target of Width x Height points, and laid out, with a
   --  clipboard of its own, in memory. The tree must be there as long as
   --  Item is used.

   procedure Settle (Item : in out Session; Milliseconds : Natural := 16);
   --  Let that much time pass, for timers and models that changed, and place
   --  the widgets again. Every input below does so.

   --  An application that has its own way of taking events and letting time
   --  pass (it does more than hand them to the tree), to be tested through
   --  that way.

   type Application is limited interface;

   procedure Take (Self : in out Application; Event : Pomarine.Events.Event) is abstract;
   --  As if Event had come.

   procedure Settle (Self : in out Application; Milliseconds : Natural) is abstract;
   --  As if that much time had passed, and then lay out and draw what changed.

   procedure Attach
     (Item : in out Session;
      Tree : aliased in out Pomarine.Widgets.Tree;
      Uses : not null access Application'Class);
   --  Test Tree, which Uses has laid out already, through Uses: the events
   --  go to its Take, and time to its Settle, in place of what Open does.
   --  Both must be there as long as Item is used.

   --  Seeing: what the widgets say of themselves

   function Screen (Item : in out Session) return String;
   --  A line to each widget that is shown, in the order of the tree: its
   --  role, its name in quotes, its value after =, and, if so, disabled,
   --  its state (On, Off) and selected. "button 'Done' disabled".

   function Shows (Item : in out Session; Part : String) return Boolean;
   --  Whether Part is in Screen.

   function Exists
     (Item : in out Session;
      Name : String;
      Role : Pomarine.Semantics.Role := Pomarine.Semantics.Unknown;
      Nth  : Positive := 1) return Boolean;
   --  Whether a widget is shown that is called Name (and, if Role is not
   --  Unknown, has that role). Nth: the Nth of those called so, in the
   --  order of the tree, as of the cards that each have a "Delete".

   function Is_Disabled
     (Item : in out Session;
      Name : String;
      Role : Pomarine.Semantics.Role := Pomarine.Semantics.Unknown;
      Nth  : Positive := 1) return Boolean
     with Pre => Exists (Item, Name, Role, Nth);

   function Value_Of
     (Item : in out Session;
      Name : String;
      Role : Pomarine.Semantics.Role := Pomarine.Semantics.Unknown;
      Nth  : Positive := 1) return String
     with Pre => Exists (Item, Name, Role, Nth);
   --  What the first widget called Name holds: a field's text, a slider's reading.

   --  Doing: what a person does

   procedure Click_On
     (Item : in out Session;
      Name : String;
      Role : Pomarine.Semantics.Role := Pomarine.Semantics.Unknown;
      Nth  : Positive := 1)
     with Pre => Exists (Item, Name, Role, Nth);
   --  Move the pointer to the middle of the first widget called Name, press
   --  the left button and let it go. A disabled widget is clicked all the
   --  same: what it does about that is what is tested.

   procedure Click_At (Item : in out Session; X, Y : Float);
   --  The same at a point, in points from the window's top left, for what has
   --  no name.

   procedure Type_Text (Item : in out Session; Text : String);
   --  Type Text, as an input method would, into the widget with the focus.

   procedure Press
     (Item : in out Session; Key : Pomarine.Events.Key_Code; Command : Boolean := False; Shift : Boolean := False);
   --  A key goes down, to the widget with the focus, with Command and Shift held if they are asked.

private

   type Node is record
      Facts  : Pomarine.Semantics.Description;
      Bounds : Pomarine.Semantics.Rectangle;
   end record;

   package Node_Vectors is new Ada.Containers.Vectors (Positive, Node);

   type Collector is limited new Pomarine.Widgets.Semantic_Sink with record
      Nodes : Node_Vectors.Vector;
   end record;

   overriding procedure Begin_Update
     (Self : in out Collector; Root, Focused : Pomarine.Widgets.Node_Id; Whole : Boolean);

   overriding procedure Describe_Node
     (Self     : in out Collector;
      Id       : Pomarine.Widgets.Node_Id;
      Facts    : Pomarine.Semantics.Description;
      Bounds   : Pomarine.Semantics.Rectangle;
      Children : Pomarine.Widgets.Node_Id_Array);

   overriding procedure End_Update (Self : in out Collector) is null;

   type Tree_Access is access all Pomarine.Widgets.Tree;

   type Plain is limited new Application with record
      Tree   : Tree_Access;
      Target : SDL3.Windows.Renderers.Renderer;
      Clock  : Pomarine.Events.Milliseconds := 0;
      Board  : Pomarine.Clipboards.Memory_Clipboard;
   end record;
   --  What Open makes: events given to the tree, and time to its widgets.

   overriding procedure Take (Self : in out Plain; Event : Pomarine.Events.Event);

   overriding procedure Settle (Self : in out Plain; Milliseconds : Natural);

   type Session is limited record
      Tree  : Tree_Access;
      Own   : aliased Plain;
      Uses  : access Application'Class;
      Heard : Collector;
   end record;

end Pomarine.Testing;
