with Pomarine.View_Models;

--  Ties the widgets of a view to the commands of a view-model: which widget
--  triggers which, and what the tree tells each widget about its command. An
--  instance for each command model:
--
--     package Binding is new Pomarine.Widgets.Bindings.For_Commands (Todo_VM.Commands);
--
--     Binding.Bind (Item.Toggle, Toggle_Chosen);      --  triggers it, and is turned on and off by it
--     Binding.Trigger (Item.Entry_Box, Add_Task);     --  only triggers it: a field stays typeable
--     Binding.Attach (Item.Judge, Tree, Item.Model);  --  the tree asks the model, not a package's variable
--
--  and in the view's listener:
--
--     if Binding.Perform (Item.Model.all, Event) then ... end if;
--
--  A tree has one validator, so a window with more than one set of commands has
--  one validator that asks each: each set has tags of its own, from Tag_Base
--  (Is_Mine says which), and Validate answers for them.
generic
   with package Models is new Pomarine.View_Models.Command_Models (<>);
   Tag_Base : Natural := 0;
   --  The tag of the model's first command; the rest follow in order.
package Pomarine.Widgets.Bindings.For_Commands is

   procedure Bind (Item : in out Widget'Class; Is_For : Models.Command; Index : Natural := 0);
   --  Say that the widget triggers the command, and is turned on, off, ticked
   --  or hidden as the model says it can be done (Can_Execute). Index is which
   --  of many it is, and goes to Execute.

   procedure Trigger (Item : in out Widget'Class; Is_For : Models.Command; Index : Natural := 0);
   --  As Bind, for a widget that only triggers it, and is not told.

   function Is_Mine (Tag : Integer) return Boolean is
     (Tag in Tag_Base .. Tag_Base + Models.Command'Pos (Models.Command'Last));
   --  Whether a tag is one of the model's commands.

   function Is_Bound (Event : Widget_Event) return Boolean is (Is_Mine (Event.Tag));
   --  Whether the widget that said it has one of the model's commands.

   function What (Event : Widget_Event) return Models.Command
     with Pre => Is_Bound (Event);

   type Judge is limited new Pomarine.Widgets.Validator with private;
   --  What the tree asks about a command: the model, which it keeps.

   procedure Attach
     (Item   : aliased in out Judge;
      Within : in out Pomarine.Widgets.Tree;
      Model  : not null access Models.Model'Class);
   --  Have Within ask Model, which must be there as long as it is used, what
   --  the commands are for (Set_Validator, Widgets.Revalidate). For a window
   --  with other commands too, see Observe.

   procedure Observe (Item : in out Judge; Model : not null access Models.Model'Class);
   --  As Attach, to be asked by a validator of the window's own, that gives
   --  the tags that Is_Mine to this Judge's Validate.

   overriding function Validate (Self : Judge; Tag : Integer; Index : Natural) return Command_State;
   --  Disabled if the command cannot be done now (with this Index: see Can_Execute); Not_Offered if Tag
   --  is no command of the model.

   function Perform (Model : in out Models.Model'Class; Event : Widget_Event) return Boolean;
   --  If Event is a Click or Submit of a widget that has a command, do the
   --  command if the model says it can be, and return True whether or not
   --  it was. Else return False. The model's Execute is given the Event's
   --  Index.

   function Changed (Seen : in out Pomarine.View_Models.Watch; Model : Models.Model'Class) return Boolean;
   --  Whether the model's Version is not what Seen last saw, and, if so, Seen
   --  is now:  if Changed (Item.Seen, Item.Model.all) then ... end if;

private

   type Model_Access is access all Models.Model'Class;

   type Judge is limited new Pomarine.Widgets.Validator with record
      Asked : Model_Access;
   end record;

end Pomarine.Widgets.Bindings.For_Commands;
