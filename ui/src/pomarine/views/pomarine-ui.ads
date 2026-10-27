with Ada.Containers.Ordered_Maps;
with Ada.Containers.Vectors;
with Ada.Finalization;
with System;
with System.Storage_Pools.Subpools;
with Pomarine.Boxes;
with Pomarine.Widgets.Grips;
with Pomarine.Themes;
with Pomarine.Widgets.Bindings;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Lists;
with Pomarine.Widgets.Progress_Bars;
with Pomarine.Widgets.Switches;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;

--  A retained UI whose widgets belong to a View, not to the application.
--
--     controls   made by a binding context, in the declarative part of a
--                component function, together with what ties each to the
--                view-model (see Pomarine.UI.Contexts);
--     functions  the components: a function makes controls and returns a
--                Layout;
--     layouts    expressions (Row, Column, Place) that describe where the
--                controls go, and change nothing until they are Mounted.
--
--  The todo example in pomarine/examples is the model of how it reads:
--
--     function Task_Actions (Parent : Todo_UI.Context'Class) return UI.Layout is
--       (UI.Row ([Parent.Label (Task_Summary, Grow => 1.0),
--                 Parent.Button ("Done", Toggle_Chosen, Width => 70.0)], Gap => 8.0));
--
--  ===== Ownership =====
--
--  A View owns, in arenas that grow and never move (Pomarine.UI.Arenas): the
--  widgets it makes, the documents they show, its binding records, and the
--  storage of layout descriptions. It finalizes them, in the order set out
--  under Teardown below. It owns nothing else.
--
--  The caller owns the model. A Context borrows the view and the model; a
--  binding keeps a pointer to the model for as long as its scope lives, and
--  Ada cannot check that a model declared in a caller is older than a scope
--  declared in the view (Bind takes an access parameter, which the caller
--  passes as Model'Access, and the pointer is kept as an unchecked one).
--  THE OBLIGATION: the model must outlive the view, or at least every use of
--  it. Declare the model before the view. Destroying a view never calls the
--  model; using a view after its model is gone does.
--
--  The adapters that say how to read and write a model are generics
--  instantiated in a package (library level). A persistent binding keeps a
--  pointer to such an instance, and nothing nested: an instantiation inside
--  a subprogram is refused by the compiler (its accessibility check), so a
--  binding can neither keep local package state nor call a nested callback.
--
--  Widgets that the application owns can be brought in by borrowing
--  (Contexts.Borrow_*): the view binds and places them like its own, but
--  never finalizes them. Destroying the view takes them out of the tree and
--  leaves them as the application's.
--
--  ===== View and Tree =====
--
--  A View is made for a Tree (an access discriminant, so the view cannot
--  outlive it: declare the tree first) and has the tree's validator, which
--  gives each command widget what its command is for. It is not otherwise
--  a listener of the tree: each widget it makes has handlers of its own, so
--  widgets of the application that are not borrowed are heard as before.
--  Mount makes the view's root widget the tree's root.
--
--  Teardown, when the view is finalized (or a scope is destroyed, for its part):
--     1. the view is forgotten by the registry, so every handle, scope and
--        layout it made is stale from here on;
--     2. the tree's validator is let go;
--     3. for each scope, newest first, children before parents: its bindings
--        are told to detach and are unregistered (commands, effects), then
--        the handlers, tags and places in the tree of its widgets are taken
--        away (borrowed ones stay in existence), its handles are made stale;
--     4. the mounted screen's panels are finalized (the root last);
--     5. the arenas are destroyed: everything the view owns is finalized,
--        newest first, and its storage returned.
--  Nothing is reclaimed that something still points to, and the model is
--  not touched.
--
--  ===== Scopes and handles =====
--
--  Every control and every binding belongs to a scope. The view's root scope
--  owns the screen; a Contexts.Component opens a nested scope for one
--  component. A component's success is a Commit, which makes its scope
--  a child of its parent: provisionally, until the enclosing construction
--  and the Mount succeed. A scope not committed when its guard is finalized
--  (an exception in a declaration, in the body, or the caller giving up)
--  is destroyed, and a parent that fails destroys the children that
--  succeeded with it.
--
--  A handle names a control by the view, the slot and which use of the slot
--  it is. It is a value to copy and lose: the control stays until its scope
--  is destroyed. Using a handle after that, or with another view, is
--  refused by an explicit test (not by an assertion), before the storage
--  is looked at.
--
--  ===== Layout and Mount =====
--
--  Controls are made where they are declared; Place, Row and Column only
--  describe. A Layout is a small value that points at its description
--  in the arena of the scope that was open when it was made; it can be
--  copied and used more than once, and is good while that scope is. Mount
--  checks the whole description (Check says what is wrong) before it changes the
--  tree, then makes the panels, attaches, and synchronizes the widgets
--  with the models once; if anything fails the tree is as it was, the
--  view unmounted, and the scopes and layouts are good for another Mount.
--  Only an unmounted view can be mounted (replacing a screen is deferred).
--
--  ===== Keeping in step =====
--
--  See Pomarine.UI.Syncing for the order of things; in short: widget edits go
--  to the model, then a command is checked and done, then the widgets show the
--  model, and the commands are checked again for the widgets.
package Pomarine.UI is

   package Layouts renames Pomarine.Widgets.Layouts;

   Unset : constant Layouts.Length := Layouts.Unset;
   --  A size, share or edge that is not said.

   subtype Align_Kind is Layouts.Align_Kind;
   subtype Spread_Kind is Layouts.Spread_Kind;

   Stale_Handle : exception;
   --  A handle, scope or layout was used after the scope that made it was destroyed
   --  (or the view was).

   Foreign_Handle : exception;
   --  A handle, scope or layout of another view was used.

   Mount_Refused : exception;
   --  The screen cannot be mounted: the message says why (Mount_Problem).

   --  Handles

   type Label_Handle is private;
   type Button_Handle is private;
   type Field_Handle is private;
   type List_Handle is private;
   type Check_Handle is private;
   type Switch_Handle is private;
   type Progress_Handle is private;
   type Widget_Handle is private;
   type Grip_Handle is private;
   --  A Grip_Handle is of a grip the view makes: a box that is clicked, holding what is declared in it (Hold).
   --  A handle made by default is of nothing and is never live.
   --  A Widget_Handle is of a widget the application owns, of any kind (Borrow_Widget): the view
   --  places it and shows or hides it, and leaves the rest of it to the application.

   type Control_Ref is private;
   --  Any of the handles, for what is true of every control (Contexts.Show_When).

   function Any (Item : Label_Handle) return Control_Ref;
   function Any (Item : Button_Handle) return Control_Ref;
   function Any (Item : Field_Handle) return Control_Ref;
   function Any (Item : List_Handle) return Control_Ref;
   function Any (Item : Check_Handle) return Control_Ref;
   function Any (Item : Switch_Handle) return Control_Ref;
   function Any (Item : Progress_Handle) return Control_Ref;
   function Any (Item : Widget_Handle) return Control_Ref;
   function Any (Item : Grip_Handle) return Control_Ref;

   type Scope_Ref is private;
   --  A construction scope: the view's own, or a component's.

   type Focus_Target is private;
   --  What a component hands up when its caller may want the focus there.
   type Reveal_Target is private;
   --  What a component hands up when its caller may want a row shown.

   function Focus_Of (Item : Field_Handle) return Focus_Target;
   function Focus_Of (Item : Button_Handle) return Focus_Target;
   function Reveal_Of (Item : List_Handle) return Reveal_Target;

   --  Layouts

   type Layout is private;
   --  A control placed, a container, or a component's result: all the same.

   Nothing : constant Layout;
   --  Takes no room; places nothing.

   type Layout_Array is array (Positive range <>) of Layout;

   function Place
     (Item   : Label_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout;

   function Place
     (Item   : Button_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout;

   function Place
     (Item   : Field_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout;

   function Place
     (Item   : List_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout;
   function Place
     (Item   : Check_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout;

   function Place
     (Item   : Switch_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout;

   function Place
     (Item   : Progress_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout;

   function Place
     (Item   : Widget_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout;

   --  Where a control goes in its container. A Place says nothing about
   --  size that a control has a default for: buttons are 80 x 32 points,
   --  fields 38 high, labels 24 high, checks and switches 24 high, a progress bar 8 high, a list
   --  as the container leaves it, and a borrowed widget as the application left it.

   type Container_Look is record
      Fill   : Pomarine.Themes.Slot := 0;
      Border : Pomarine.Themes.Slot := 0;
      Shadow : Pomarine.Themes.Slot := 0;
      Radius : Float := 0.0;
      Round  : Pomarine.Boxes.Corner_Flags := Pomarine.Boxes.All_Corners;
      Framed : Boolean := False;
      --  The corners rounded by Radius (see Panels.Set_Radius), and the outline drawn again over what is in it.
   end record;
   --  How a container is drawn: a slot of 0 is none (the box shows what is behind it).

   Plain : constant Container_Look := (others => <>);

   function Row
     (Items   : Layout_Array;
      Gap     : Layouts.Length := Unset;
      Padding : Layouts.Length := Unset;
      Align   : Align_Kind := Layouts.Center;
      Spread  : Spread_Kind := Layouts.As_Is;
      Grow    : Layouts.Weight := Layouts.Unchanged;
      Width   : Layouts.Length := Unset;
      Height  : Layouts.Length := Unset;
      Appearance : Container_Look := Plain) return Layout;

   function Column
     (Items   : Layout_Array;
      Gap     : Layouts.Length := Unset;
      Padding : Layouts.Length := Unset;
      Align   : Align_Kind := Layouts.As_Is;
      Spread  : Spread_Kind := Layouts.As_Is;
      Grow    : Layouts.Weight := Layouts.Unchanged;
      Width   : Layouts.Length := Unset;
      Height  : Layouts.Length := Unset;
      Appearance : Container_Look := Plain) return Layout;
   function Hold
     (Item    : Widget_Handle;
      Items   : Layout_Array;
      Flow    : Layouts.Flow_Kind := Layouts.Column;
      Gap     : Layouts.Length := Unset;
      Padding : Layouts.Length := Unset;
      Align   : Align_Kind := Layouts.As_Is;
      Spread  : Spread_Kind := Layouts.As_Is) return Layout;

   function Hold
     (Item    : Grip_Handle;
      Items   : Layout_Array;
      Flow    : Layouts.Flow_Kind := Layouts.Column;
      Gap     : Layouts.Length := Unset;
      Padding : Layouts.Length := Unset;
      Align   : Align_Kind := Layouts.As_Is;
      Spread  : Spread_Kind := Layouts.As_Is) return Layout;
   --  A widget that holds others (a borrowed panel, scroller or grip; a grip of the view's), placed, with Items
   --  put in it. The widget must have none yet. Its own box is said with Styled.

   type Grip_Look is record
      Fill, Border, Shadow, Hover_Fill, Hover_Outline : Pomarine.Themes.Slot := 0;
      Dashed   : Boolean := False;
      Radius   : Float := 0.0;
      Round    : Pomarine.Boxes.Corner_Flags := Pomarine.Boxes.All_Corners;
      Pointer  : Boolean := False;
      --  The pointer is a hand over it.
      Focusable : Boolean := False;
   end record;
   --  How a grip is drawn: a slot of 0 is none.

   function Styled (Item : Layout; Using : Layouts.Style) return Layout;
   --  Item with the box style Using, as it would be given to Pomarine.Widgets.Layouts.Add, in place of
   --  the one the Place, Row or Column that made it set (a container keeps its direction, if Using
   --  does not say another). For what the named parameters do not cover. It is exactly Using: the size
   --  that a button, a field or a label has when a Place says nothing of it is not added.

   function Scroll
     (Content : Layout;
      Across  : Boolean := False;
      Grow    : Layouts.Weight := Layouts.Unchanged;
      Width   : Layouts.Length := Unset;
      Height  : Layouts.Length := Unset) return Layout;
   --  Content, which is as long as it is, in a box that scrolls it down (or across).

   --  Items go across (Row) or down (Column), in order. Nothing is made of
   --  the tree: these are descriptions, which are kept in the arena of
   --  the scope that is open. Items made of other views are not refused here
   --  but at Mount (Check).

   --  The view

   type View (Tree : not null access Pomarine.Widgets.Tree) is
     limited new Ada.Finalization.Limited_Controlled with private;
   --  See the notes above. Declare it after its tree and the models it
   --  will bind, and before anything that holds a Layout of it.

   function Fragment (Item : View; Items : Layout_Array) return Layout;
   --  Siblings in their existing parent, without a panel or a box style of their own.

   function Is_Mounted (Item : View) return Boolean;

   function Put (Item : in out View; Existing : in out Pomarine.Widgets.Widget'Class) return Layout
     with Pre => not Is_Mounted (Item) or else Is_Embedded (Item);
   --  A widget of the application's, placed, with no model to bind to (Contexts.Borrow_Widget and Place). Put
   --  again, a widget is the same control: a screen that is put again (a bar that moves) is described again.

   function Put_In
     (Item     : in out View;
      Existing : in out Pomarine.Widgets.Widget'Class;
      Items    : Layout_Array;
      Flow     : Layouts.Flow_Kind := Layouts.Column;
      Gap      : Layouts.Length := Unset;
      Padding  : Layouts.Length := Unset;
      Align    : Align_Kind := Layouts.As_Is;
      Spread   : Spread_Kind := Layouts.As_Is) return Layout
     with Pre => not Is_Mounted (Item) or else Is_Embedded (Item);
   --  A widget of the application's that holds others (a panel, a scroller, a grip), placed, with Items in it
   --  (Hold, with no model). It must have no children yet.

   function Is_Embedded (Item : View) return Boolean;

   function Spacer (Item : View; Appearance : Container_Look := Plain) return Layout;
   --  A container with nothing in it, for a rule or a block of colour; its box is said with Styled.

   function Is_Live (Item : View; Handle : Label_Handle) return Boolean;
   function Is_Live (Item : View; Handle : Button_Handle) return Boolean;
   function Is_Live (Item : View; Handle : Field_Handle) return Boolean;
   function Is_Live (Item : View; Handle : List_Handle) return Boolean;
   function Is_Live (Item : View; Handle : Check_Handle) return Boolean;
   function Is_Live (Item : View; Handle : Switch_Handle) return Boolean;
   function Is_Live (Item : View; Handle : Progress_Handle) return Boolean;
   function Is_Live (Item : View; Handle : Widget_Handle) return Boolean;
   function Is_Live (Item : View; Handle : Grip_Handle) return Boolean;
   function Is_Live (Item : View; Screen : Layout) return Boolean;
   --  Whether it is of this view and its scope has not been destroyed.

   function Widget_Of (Item : View; Handle : Label_Handle) return not null access Pomarine.Widgets.Labels.Label;
   function Widget_Of (Item : View; Handle : Button_Handle) return not null access Pomarine.Widgets.Buttons.Button;
   function Widget_Of
     (Item : View; Handle : Field_Handle) return not null access Pomarine.Widgets.Text_Fields.Text_Field;
   function Widget_Of (Item : View; Handle : List_Handle) return not null access Pomarine.Widgets.Lists.List;
   function Widget_Of (Item : View; Handle : Check_Handle) return not null access Pomarine.Widgets.Checks.Check;
   function Widget_Of (Item : View; Handle : Switch_Handle) return not null access Pomarine.Widgets.Switches.Switch;
   function Widget_Of
     (Item : View; Handle : Progress_Handle) return not null access Pomarine.Widgets.Progress_Bars.Progress_Bar;
   function Widget_Of (Item : View; Handle : Widget_Handle) return not null access Pomarine.Widgets.Widget'Class;
   function Widget_Of (Item : View; Handle : Grip_Handle) return not null access Pomarine.Widgets.Grips.Grip;
   --  The widget behind a handle, for what a binding does not cover (and
   --  for tests). Raises Stale_Handle or Foreign_Handle, whatever the checks of the build.

   type Mount_Problem is
     (No_Problem,
      Already_Mounted,       --  the view has a screen
      No_Screen,             --  the layout places nothing
      Foreign_Layout,        --  a layout or control of another view
      Stale_Layout,          --  its scope has been destroyed
      Stale_Control,         --  a control's scope has been destroyed
      Duplicate_Placement,   --  a control is placed twice (a layout may be used twice; a control may not)
      Attachment_Conflict,   --  a control is in a tree already
      Tree_Has_Root);        --  the tree has a root widget already

   function Check (Item : in out View; Screen : Layout) return Mount_Problem;
   --  What Mount would refuse, or No_Problem. Changes nothing but the
   --  marks that tell a second placement.

   procedure Mount_Into
     (Item   : in out View;
      Parent : in out Pomarine.Widgets.Widget'Class;
      Screen : Layout)
     with Pre => Pomarine.Widgets.Is_Attached (Parent);

   procedure Mount_Before
     (Item   : in out View;
      Before : in out Pomarine.Widgets.Widget'Class;
      Screen : Layout)
     with Pre => Pomarine.Widgets.Is_Attached (Before);
   --  Late mounting: an embedded view that is mounted takes more components (a Component opened on its root
   --  context, committed), mounted again into Parent, in front of Before (a child of Parent) or last. For
   --  what is made as the model grows (a block for each section).
   --  As Mount, but the screen goes into Parent, a widget of the application's in the tree (which keeps its
   --  root, its validator and its listener), after what is there. The application then asks the view
   --  about the tags it owns (Owns_Tag, Command_State) from its own validator, and has it Synchronize
   --  in its own turn. Use Use_Tags_From first, so that the tags are clear of the application's.

   type Observer is limited interface;

   procedure Turned (Self : in out Observer) is abstract;
   --  A turn of synchronization changed what the widgets show (their state, not only their pixels): the
   --  application may lay out the tree again, as it does when it changes a widget itself.

   procedure Observe (Item : in out View; Watching : access Observer'Class);
   --  Tell Watching at the end of each such turn, from now on.

   procedure Use_Tags_From (Item : in out View; First : Positive)
     with Pre => not Is_Mounted (Item);
   --  The tags of the view's commands begin at First (to begin with, at 1). Call it before any is made.

   function Owns_Tag (Item : View; Tag : Integer) return Boolean;

   function Command_State (Item : View; Tag : Integer; Index : Natural) return Pomarine.Widgets.Command_State
     with Pre => Owns_Tag (Item, Tag);
   --  What the tree asks of a command of the view's.

   procedure Synchronize (Item : in out View)
     with Pre => Is_Mounted (Item);
   --  A turn with no event: what the models changed is shown. The tree does it for a view that is mounted
   --  as the tree's root; a view that is mounted into a widget is Synchronized by the application.

   function Panel_Of (Item : View; Part : Layout) return access Pomarine.Widgets.Widget'Class
     with Pre => Is_Mounted (Item);
   --  The panel a Row, Column or Scroll of a mounted screen made; null if Part is not one.

   function Screen_Panel (Item : View) return access Pomarine.Widgets.Widget'Class
     with Pre => Is_Mounted (Item);
   --  The widget a container screen made, for the application to show and hide; null if the screen is
   --  a control.

   procedure Mount (Item : in out View; Screen : Layout);
   --  Check the whole description, make the panels, attach everything, and
   --  show the models in the widgets once, before the screen can be
   --  used; then the screens' scopes are no longer provisional. Raises
   --  Mount_Refused (the message is the Mount_Problem) and changes nothing if Check says so; if
   --  anything else fails, the tree and the view are as they were
   --  (an unmounted view with every scope intact) and the exception goes on.

   --  Counting, for tests and for finding leaks

   function Live_Scopes (Item : View) return Natural;
   function Live_Controls (Item : View) return Natural;
   function Live_Bindings (Item : View) return Natural;
   function Control_Slots (Item : View) return Natural;
   --  How many places for controls the view has made, in use or not: a place whose scope was
   --  destroyed is used again (by a new control, with another generation), not added to.

   function Live_Views return Natural;
   --  All views, in all.

   function Queued_Events (Item : View) return Natural;
   --  Events held while a pass of synchronization was going on.

   Synchronization_Passes_Limit : constant := 8;
   --  A pass that changes what another pass reads is run again, up to this
   --  many times in a turn; the rest is done in the next turn. It bounds a
   --  model that never settles; nothing a person makes is capped by it.

   procedure Inject_Fault (Item : in out View; Placements : Natural);
   --  For tests: Mount raises Program_Error after attaching that many
   --  widgets (0 is before the first), once, to see that the tree is put back.

private

   package Docs renames Texts.Documents;
   package Subpools renames System.Storage_Pools.Subpools;

   type Handle_Data is record
      View       : Natural := 0;
      Slot       : Natural := 0;
      Generation : Natural := 0;
   end record;
   --  View 0 is of no view.

   type Label_Handle is new Handle_Data;
   type Button_Handle is new Handle_Data;
   type Field_Handle is new Handle_Data;
   type List_Handle is new Handle_Data;
   type Check_Handle is new Handle_Data;
   type Switch_Handle is new Handle_Data;
   type Progress_Handle is new Handle_Data;
   type Widget_Handle is new Handle_Data;
   type Grip_Handle is new Handle_Data;

   type Control_Ref is record
      Which : Handle_Data;
   end record;

   type Focus_Target is record
      Which : Handle_Data;
   end record;

   type Reveal_Target is record
      Which : Handle_Data;
   end record;

   type Scope_Ref is record
      View       : Natural := 0;
      Slot       : Natural := 0;
      Generation : Natural := 0;
   end record;

   No_Scope : constant Scope_Ref := (others => 0);

   --  Layout descriptions

   type Node_Kind is (Empty, Placed, Row_Of, Column_Of, Scroll_Of, Held, Siblings);

   type Layout_Node;
   type Node_Ref is access all Layout_Node;

   type Layout is record
      Scope : Scope_Ref;
      --  Where the description is kept.
      Node  : Node_Ref;
   end record;

   Nothing : constant Layout := (Scope => No_Scope, Node => null);

   type Layout_Node (Count : Natural) is record
      Kind    : Node_Kind := Empty;
      Box     : Layouts.Style;
      --  Of the control placed, or of the container, and how it sits in its parent.
      Control : Handle_Data;
      Made    : Pomarine.Widgets.Widget_Access;
      --  Of a container: the panel that the mount made for it.
      Exact   : Boolean := False;
      --  The box is as Styled said, with no default size of a control's added.
      Appearance : Container_Look := Plain;
      Across  : Boolean := False;
      --  A scroller's direction.
      Items   : Layout_Array (1 .. Count);
   end record;

   --  What a binding is to the view

   type Command_Key is record
      Model : System.Address := System.Null_Address;
      Which : Natural := 0;
   end record;
   --  Which command of which model: for effects that follow a command.

   type Binding is abstract tagged limited record
      Owner   : Natural := 0;
      --  The view's number.
      Scope   : Natural := 0;
      --  The slot of the scope it belongs to.
      Number  : Natural := 0;
      --  Its place in the view's table; 0 when unregistered.
      Tag     : Integer := Pomarine.Widgets.No_Tag;
      --  The tag of the widgets that trigger it, if it is a command.
      Next    : access Binding'Class;
      --  The next binding of the scope, newer first.
   end record;

   type Binding_Ref is access all Binding'Class;

   procedure Collect (Item : in out Binding; Within : in out View'Class) is null;
   --  What the person did to the widget, said to the model: through the setters.
   procedure Refresh (Item : in out Binding; Within : in out View'Class; Forced : Boolean) is null;
   --  What the model says, shown in the widget, if it has changed (or Forced).
   procedure Detach (Item : in out Binding; Within : in out View'Class) is null;
   --  The scope is going: let go of widgets, handlers and the tree.
   function Can_Execute (Item : Binding; Index : Natural) return Boolean is (False);
   procedure Execute (Item : in out Binding; Index : Natural) is null;
   function Key (Item : Binding) return Command_Key is (others => <>);
   --  Of a command binding: which command it is.
   procedure Before_Command (Item : in out Binding; Which : Command_Key) is null;
   procedure After_Command (Item : in out Binding; Which : Command_Key) is null;
   --  Offered to every binding around a command that is done (effects).

   function Is_Command (Item : Binding) return Boolean is (False);

   --  The tables

   type Control_Kind is
     (Free_Slot, Label_Control, Button_Control, Field_Control, List_Control, Check_Control, Switch_Control,
      Progress_Control, Custom_Control, Grip_Control);

   type Control_Record is record
      Kind       : Control_Kind := Free_Slot;
      Generation : Natural := 0;
      Scope      : Natural := 0;
      Widget     : Pomarine.Widgets.Widget_Access;
      Document   : Docs.Document_Access;
      Owned      : Boolean := True;
      Handled    : Pomarine.Widgets.Event_Kind := Pomarine.Widgets.Click;
      --  Which event the view's handler hears, for taking it away.
      Heard      : Boolean := False;
      --  Whether the view has a handler on the widget for Handled.
      Marked     : Natural := 0;
      --  The epoch of the last check that found it placed.
      Next       : Natural := 0;
      --  The next control of the scope, newer first; or of the free ones.
   end record;

   package Arena_Vectors is new Ada.Containers.Vectors (Positive, Subpools.Subpool_Handle, Subpools."=");

   package Control_Vectors is new Ada.Containers.Vectors (Positive, Control_Record);

   type Scope_State is (Free, Open, Committed, Mounted);

   type Scope_Record is record
      State       : Scope_State := Free;
      Generation  : Natural := 0;
      Parent      : Natural := 0;
      First_Child : Natural := 0;
      Next_Child  : Natural := 0;
      --  The scope's siblings, newer first; or the free scopes.
      First_Control : Natural := 0;
      First_Binding : Binding_Ref;
      Arena       : Subpools.Subpool_Handle;
   end record;

   package Scope_Vectors is new Ada.Containers.Vectors (Positive, Scope_Record);

   package Binding_Vectors is new Ada.Containers.Vectors (Positive, Binding_Ref);

   package Tag_Maps is new Ada.Containers.Ordered_Maps (Integer, Binding_Ref);

   package Event_Vectors is new Ada.Containers.Vectors (Positive, Pomarine.Widgets.Widget_Event, Pomarine.Widgets."=");

   type View_Ref is access all View'Class;

   type Observer_Ref is access all Observer'Class;

   type Hub is limited new Pomarine.Widgets.Validator and Pomarine.Widgets.Bindings.Syncable with record
      Owner : View_Ref;
   end record;
   --  What the tree asks about commands and tells to synchronize.

   overriding function Validate (Self : Hub; Tag : Integer; Index : Natural)
     return Pomarine.Widgets.Command_State;

   overriding procedure Sync (Self : in out Hub);

   type Root_Ref is access all Pomarine.Widgets.Bindings.Sync_Root;

   type View (Tree : not null access Pomarine.Widgets.Tree) is
     limited new Ada.Finalization.Limited_Controlled with record
      Number       : Natural := 0;
      Scopes       : Scope_Vectors.Vector;
      Free_Scope   : Natural := 0;
      Controls     : Control_Vectors.Vector;
      Free_Control : Natural := 0;
      Bindings     : Binding_Vectors.Vector;
      Commands     : Tag_Maps.Map;
      Next_Tag     : Positive := 1;
      Root_Scope   : Natural := 0;
      Top_Scope    : Natural := 0;
      --  The scope that is open for building: where layouts are described.
      Mounted      : Boolean := False;
      Mount_Arena  : Subpools.Subpool_Handle;
      Late_Arenas  : Arena_Vectors.Vector;
      --  Of the components mounted after the first mount (Mount_Into, Before).
      Root         : Root_Ref;
      Epoch        : Natural := 0;
      Judge        : aliased Hub;
      Syncing      : Boolean := False;
      Touched      : Boolean := False;
      --  A binding changed the model or a widget in this pass: the commands are asked again.
      Again        : Boolean := False;
      Pending      : Event_Vectors.Vector;
      First_Focus  : Handle_Data;
      Fault_After  : Integer := -1;
      Judging      : Boolean := False;
      --  Whether the tree is told to ask Judge.
      Tearing_Down : Boolean := False;
      Embedded     : Boolean := False;
      Watcher      : Observer_Ref;
      --  Mounted into a widget of the application's, not as the tree's root.
      Screen_Top   : Pomarine.Widgets.Widget_Access;
   end record;

   overriding procedure Initialize (Item : in out View);
   overriding procedure Finalize (Item : in out View);

   --  What Pomarine.UI.Contexts, Pomarine.UI.Sync and the tests are built on

   function Find_View (Number : Natural) return View_Ref;
   --  The live view with that number; null if there is none.

   function Number_Of (Item : View) return Natural;

   function Root_Scope (Item : View) return Scope_Ref;

   function Open_Scope (Item : in out View; Parent : Scope_Ref) return Scope_Ref;
   --  A scope for a component, under Parent, which is open; it is open for
   --  building until Commit_Scope or Abandon_Scope. Raises Stale_Handle
   --  or Foreign_Handle if Parent is not live and this view's, and
   --  Program_Error if the view is mounted.

   procedure Commit_Scope (Item : in out View; Scope : Scope_Ref);
   --  The component succeeded: its scope stays, under its parent, provisionally.

   procedure Abandon_Scope (Item : in out View; Scope : Scope_Ref);
   --  Destroy the scope and all in it (children first). Does nothing if it
   --  is gone already, so that a guard may always call it.

   function Is_Live (Item : View; Scope : Scope_Ref) return Boolean;

   procedure Require_Open (Item : View; Scope : Scope_Ref);
   --  Raises Stale_Handle, Foreign_Handle, or Program_Error if the scope is not open for building.

   function Arena_Of (Item : View; Scope : Scope_Ref) return Subpools.Subpool_Handle;
   --  Of a scope that is live (the others raise as Require_Open).

   procedure Add_Binding (Item : in out View; Scope : Scope_Ref; Made : not null Binding_Ref);
   --  Take over a binding made in the scope's arena: it is registered, and Detach
   --  and finalization are the scope's. If it is a command, give it Command_Tag first.

   function Command_Tag (Item : in out View) return Integer;
   --  A tag for a command, not given before in this view, and never again.

   function New_Label (Item : in out View; Scope : Scope_Ref) return Label_Handle;
   function New_Button
     (Item      : in out View;
      Scope     : Scope_Ref;
      Caption   : String;
      Kind      : Pomarine.Widgets.Buttons.Kind;
      Focusable : Boolean := False) return Button_Handle;
   function New_Button
     (Item  : in out View;
      Scope : Scope_Ref;
      Look  : Pomarine.Widgets.Buttons.Settings;
      Unheard : Boolean := False) return Button_Handle;
   --  Unheard: the view does not hear the button; the application hooks its Click (see Contexts.Plain_Button).
   function New_Field (Item : in out View; Scope : Scope_Ref; Placeholder : String) return Field_Handle;
   function New_List (Item : in out View; Scope : Scope_Ref) return List_Handle;
   function New_Check (Item : in out View; Scope : Scope_Ref; Caption : String; Form : Pomarine.Widgets.Checks.Kind)
     return Check_Handle;
   function New_Switch (Item : in out View; Scope : Scope_Ref; Caption : String) return Switch_Handle;
   function New_Progress (Item : in out View; Scope : Scope_Ref) return Progress_Handle;
   function New_Grip (Item : in out View; Scope : Scope_Ref; Look : Grip_Look; Unheard : Boolean := False)
     return Grip_Handle;
   function Borrow_Widget
     (Item : in out View; Scope : Scope_Ref; Existing : in out Pomarine.Widgets.Widget'Class) return Widget_Handle;

   function Borrow_Label
     (Item : in out View; Scope : Scope_Ref; Existing : in out Pomarine.Widgets.Labels.Label) return Label_Handle;
   function Borrow_Button
     (Item : in out View; Scope : Scope_Ref; Existing : in out Pomarine.Widgets.Buttons.Button) return Button_Handle;
   function Borrow_Field
     (Item     : in out View;
      Scope    : Scope_Ref;
      Existing : in out Pomarine.Widgets.Text_Fields.Text_Field;
      Backing  : aliased in out Docs.Document) return Field_Handle;
   function Borrow_List
     (Item : in out View; Scope : Scope_Ref; Existing : in out Pomarine.Widgets.Lists.List) return List_Handle;

   function Document_Of (Item : View; Handle : Field_Handle) return Docs.Document_Access;

   procedure Set_Focus_Initially (Item : in out View; Target : Focus_Target);
   --  The widget to give the focus when the screen is mounted.

   function Resolve (Item : View; Handle : Handle_Data; Kind : Control_Kind) return Pomarine.Widgets.Widget_Access;
   --  null if the handle is stale or another view's; use Check_Handle for the reason.

   procedure Require_Handle (Item : View; Handle : Handle_Data; Kind : Control_Kind);
   --  Raises Stale_Handle or Foreign_Handle.

   function Data_Of (Handle : Focus_Target) return Handle_Data is (Handle.Which);
   function Data_Of (Handle : Reveal_Target) return Handle_Data is (Handle.Which);
   function Data_Of (Handle : Control_Ref) return Handle_Data is (Handle.Which);

end Pomarine.UI;
