with Ada.Finalization;
with Interfaces;
with System;
with SDL3.Windows;
with SDL3.Windows.Renderers;
with SDL3.Painters;
with SDL3.Cursors;
with SDL3.Events;
with Pomarine.Clipboards;
with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.Semantics;
with Pomarine.Themes;
with Yoga.Nodes;

--  A tree of widgets: the parts of a window, each in a box that Yoga's
--  flexbox layout gives it, which draw themselves, take events and keep
--  their own state.
--
--  The application owns the widgets, as it owns the documents they show:
--  they are declared where it declares them, and added to a tree, which
--  holds links to them but allocates nothing. They must be there as long
--  as the tree is used, and the tree after the renderer they draw to.
--  Building goes from the top down: set the root, then add each widget to
--  one that is already in the tree. A widget can be taken out again
--  (Remove) and put elsewhere, or hidden (Set_Visible) so that it takes
--  no room and shows nothing, and be shown again.
--
--  How a widget's box is set is Yoga's: a widget has a node, with
--  Node, to style. The tree lays them out in pixels. Widgets are drawn in
--  order, parents first, and are clipped to their boxes and their
--  parents'. Events go to the widget under the pointer, or to the one
--  with the focus, and then to its parents.
--
--  What has to be drawn again is kept as damage: a box that grows as
--  widgets say they have changed (Invalidate), or are moved or resized by
--  a layout. Setting something to what it was damages nothing, so a
--  frame with no damage needs no drawing. Data flows down, from the
--  application's models to widgets' setters, and what widgets have to say
--  comes back as events: to a Listener the application gives the tree (or
--  a widget), or as plain values, taken with a procedure (as a Button's
--  Take_Click), as the application likes. See Event_Kind.
--
--  A loop looks like this:
--
--     Dispatch (Tree, Event, Handled);   --  for each event
--     Update (Tree, Ticks);              --  timers, and models that changed
--     if Needs_Paint (Tree) then
--        Paint (Tree, Target, Colors, Retained => ...);
--        Present (Target);
--     end if;
--     wait no longer than Until_Update (Tree)
package Pomarine.Widgets is

   --  What widgets say

   type Event_Kind is
     (Click,         --  a button, a grip, a select field, a toast's action, a list's row
      Double_Click,  --  a grip
      Change,        --  a check, a switch or a slider has a new value
      Submit,        --  Return in a field
      Choose,        --  a row of a menu (Row)
      Drag,          --  a grip moved (Across, Down), in points
      Move,          --  a frame to be moved (Across, Down), in points
      Resize,        --  a frame to be sized (Across, Down), in points
      Close,         --  a frame, a chip
      Minimize,
      Restore,
      Press,         --  a pin
      Release,       --  a pin, or a grip, let go (before its Click, if it says one)
      Select_Tag,    --  a canvas's line selected (Row, its Tag; 0 for none)
      Delete,        --  Backspace or Delete with a line selected on a canvas
      Act,           --  a button at the end of a list's row (Row, Action)
      Blur,          --  the widget has lost the focus (only said if it has a handler)
      Assist,        --  an editor's toolbar button for what the application does of its text
      Use_Tool,      --  one of an editor's tools added by the application (Row, its number)
      Follow,        --  Command-click on a link in an editor (see Followed there)
      Ask_Link);     --  an editor has begun to ask for a link's address (see Add_Link_Choice there)

   No_Tag : constant Integer := -1;

   type Widget_Event (Kind : Event_Kind := Click) is record
      Tag    : Integer := No_Tag;
      --  What the application said the widget is for (see Set_Tag).
      Index  : Natural := 0;
      --  Which of many like it, as the application said.
      case Kind is
         when Choose | Select_Tag | Act | Use_Tool =>
            Row : Natural := 0;
            --  Of a menu's or a list's rows, the tag of a canvas's line, or an editor's tool.
            case Kind is
               when Act =>
                  Action : Natural := 0;
                  --  Which of the row's buttons.
               when others =>
                  null;
            end case;
         when Drag | Move | Resize =>
            Across : Float := 0.0;
            Down   : Float := 0.0;
            --  In points.
         when others =>
            null;
      end case;
   end record;
   --  What a widget says. Only what a kind of event has to say is in it:
   --  a Row is of a Choose and a Select_Tag, an Across and a Down of a
   --  Drag, a Move and a Resize.

   type Widget_Event_Array is array (Positive range <>) of Widget_Event;

   type Tree is tagged limited private;
   --  The widgets of one window, and what they share: the density of its
   --  pixels, the clipboard, which has the focus, what is damaged.

   type Widget is abstract tagged limited private;
   --  The part of every widget that is in the tree. A kind of widget
   --  derives from it, and overrides what it needs of the operations
   --  below.

   type Widget_Access is access all Widget'Class;
   pragma No_Strict_Aliasing (Widget_Access);
   --  Made from a node's context, which is its address.

   type Node_Id is private;
   --  Names a widget in a tree for as long as it is there: a place in
   --  the tree's table of nodes, and which use of the place it is, so
   --  that the id of a widget that was taken out is not the id of another
   --  that took its place. It is a plain value to keep, compare and send
   --  (as to an assistive technology, see To_Unsigned_64), where a pointer
   --  would dangle.

   No_Node : constant Node_Id;

   Node_Capacity : constant := 2 ** 21 - 1;
   --  The most widgets a tree can hold, in all: what a widget's number
   --  (Node_Id) keeps of its place. The table of nodes is made for all of
   --  them at once, but only the part that is used is ever touched, so it
   --  takes the memory of the widgets there are.

   type Listener is limited interface;
   --  What the application gives a tree to hear its widgets by. Events are
   --  not delivered as they happen, but after the event or the time that
   --  caused them has been given to every widget (see Dispatch, Update),
   --  so that what is done about one may change the tree: show, hide,
   --  add, or remove widgets, the one it came from too.

   procedure Handle_Event
     (Self   : in out Listener;
      Source : in out Widget'Class;
      Event  : Widget_Event) is abstract;
   --  Source said Event.

   type Listener_Access is access all Listener'Class;

   type Pixel_Box is record
      Left, Top, Width, Height : Integer := 0;
   end record;
   --  In pixels from the top left of the target. Empty if it has no
   --  width or no height.

   function Is_Empty (Item : Pixel_Box) return Boolean is
     (Item.Width <= 0 or else Item.Height <= 0);

   --  What a widget does: the operations for a kind of widget to override

   procedure Placed
     (Item : in out Widget; Left, Top, Width, Height : Float) is null;
   --  The tree has put it Left, Top (from the top left of the target)
   --  and made it Width x Height, in pixels: called when those change,
   --  and when the density does.

   procedure Draw
     (Item   : in out Widget;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is null;
   --  Draw it, in its box, which is the clip: whatever it draws outside
   --  is not seen. What it draws over is not cleared for it, so a widget
   --  that is not opaque shows what is behind it, and one that is must
   --  fill its box. Often only a part of it is to be drawn: see
   --  Painting_Part.

   procedure Draw_Over
     (Item   : in out Widget;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme) is null;
   --  Draw what goes over its children, in its box, as Draw does: a
   --  scroll bar, say, which they must not hide.

   procedure Handle
     (Item    : in out Widget;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);
   --  Take Event if it is for it, and say so. A widget that has changed
   --  how it looks says so with Invalidate. By default it takes none.
   --
   --  Mouse events come to the widget under the pointer, and then to its
   --  parents until one takes it; and, once one has taken a press, to
   --  that widget alone until the button is let go. Keys and typing come
   --  to the widget with the focus and its parents; keys that none of
   --  them take come to every widget in turn, as shortcuts.

   procedure Update
     (Item : in out Widget; Now : SDL3.Events.Milliseconds) is null;
   --  Say the time is Now, as SDL3.Events.Ticks, and that the models it
   --  shows may have changed: to blink a caret, to notice the document
   --  has changed. It says with Invalidate if it has to be drawn again.

   function Until_Update (Item : Widget) return Integer is (-1);
   --  How many milliseconds after the time last said it needs to be told
   --  the time to change: negative if it does not.

   function Cursor (Item : Widget) return SDL3.Cursors.Kind is
     (SDL3.Cursors.Default);
   --  The shape the pointer should have over it, or while it holds a
   --  press. Default leaves it to the widgets it is in.

   function Accepts_Focus (Item : Widget) return Boolean is (False);
   --  Whether the focus may be given to it: by Tab, or by a click on it or
   --  on a widget inside it that does not (see Focus_On_Click).

   function Focus_On_Click (Item : Widget) return Boolean is (Accepts_Focus (Widget'Class (Item)));
   --  Whether a click on it gives it the focus. A button says it does not,
   --  though Tab reaches it: to click it is not to leave the field that
   --  is being typed in.

   procedure Focus_Changed (Item : in out Widget; Focused : Boolean) is null;
   --  It has the focus now, or has lost it.

   procedure Hover_Changed (Item : in out Widget; Hovered : Boolean) is null;
   --  The pointer has come over it or something in it, or left.

   procedure Describe
     (Item  : Widget;
      Facts : in out Semantics.Description);
   --  Say what it is to someone who cannot see it: its role, its name and
   --  value, its state, and which Actions it takes. Facts is as the
   --  application has said so far (see Set_Accessible_Name); fill in what
   --  it knows. By default, a Group.

   procedure Perform
     (Item    : in out Widget;
      Request : Semantics.Request;
      Done    : out Boolean);
   --  Do what an assistive technology asks, as it would do the click or
   --  the key: Done says whether it could. Every Action the widget says it
   --  takes in Describe must be done here. By default none is.

   procedure Measure
     (Item      : in out Widget;
      Room_Wide : Float;
      Wide_Mode : Yoga.Nodes.Measure_Mode;
      Room_High : Float;
      High_Mode : Yoga.Nodes.Measure_Mode;
      Result    : out Yoga.Nodes.Measured_Size);
   --  How big it wants to be, in pixels, where its style does not say, in
   --  the room the layout offers (see Yoga.Nodes.Measure_Mode): a label's
   --  is that of its text. Called by the layout for a widget that has been
   --  made to measure (Set_Measured), and only when what it holds has
   --  changed (Content_Changed) or the room has.

   function Part_Count (Item : Widget) return Natural is (0);
   --  How many things there are in it that are not widgets of their own,
   --  that an assistive technology is to be told of: the rows of a menu,
   --  the lines of a text.

   function Part_Number (Item : Widget; Index : Positive) return Positive is
     (Index);
   --  The number the Indexth part goes by, which does not change while it
   --  lasts, whatever comes and goes before it: for a part that is a
   --  paragraph, the paragraph's id; for the row of a menu, its place.

   procedure Describe_Part
     (Item   : Widget;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle);
   --  Say what the part numbered Part is, and where, in pixels from the top left of the
   --  target as Left_Of is. By default, a Group in no place.

   procedure Perform_Part
     (Item    : in out Widget;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean);
   --  Do what is asked of Part. By default none can be.

   --  Hearing: events go to the widget's own listener if it has one, and
   --  otherwise to the tree's; to none, if neither has. A widget's polled
   --  values (as Take_Click) are kept whichever.

   procedure Set_Listener (Item : in out Tree; To : not null access Listener'Class);
   --  Say where the events of the tree's widgets go. It must be there as
   --  long as the tree is used.

   procedure Set_Listener (Item : in out Widget'Class; To : access Listener'Class);
   --  Where this widget's events go, rather than to the tree's; null for
   --  the tree's again.

   procedure Set_Tag (Item : in out Widget'Class; Tag : Integer; Index : Natural := 0);
   --  Say what the widget is for, and which of many it is: as it comes
   --  back in each event it says. Tag is the application's own number, as
   --  of a kind of command (see Pomarine.Widgets.Commands).

   function Tag_Of (Item : Widget'Class) return Integer;
   function Index_Of (Item : Widget'Class) return Natural;

   --  What the widget is to an assistive technology

   procedure Set_Accessible_Name (Item : in out Widget'Class; Text : String);
   --  What it is called, when its own label will not do, or it has none
   --  (a button of a picture only). Said, it is used whatever the widget
   --  would have said.

   procedure Set_Accessible_Help (Item : in out Widget'Class; Text : String);
   --  More than its name: what it is for.

   procedure Set_Accessible_Role
     (Item : in out Widget'Class; Role : Semantics.Role);
   --  What it is, when the widget's own idea of it will not do: a Panel
   --  that is a Dialog, a Label that is a Heading. Unknown for the
   --  widget's own.

   procedure Hide_From_Accessibility (Item : in out Widget'Class; To : Boolean := True);
   --  Leave it, and all in it, out of what an assistive technology is
   --  told: for what only decorates.

   function Accessible_Name (Item : Widget'Class) return String;
   --  The name the application gave it; "" if none.

   procedure Notify
     (Item   : in out Widget'Class;
      Kind   : Event_Kind;
      Row    : Natural := 0;
      Across : Float := 0.0;
      Down   : Float := 0.0;
      Action : Natural := 0);
   --  For a kind of widget to say that it has been clicked, and so on. It
   --  is kept, to be delivered, if the widget is in a tree that has
   --  somewhere to deliver it.

   procedure Deliver (Item : in out Tree);
   --  Give the listeners the events kept, as Dispatch and Update do when
   --  they have done. Events that come in as this is done are given in
   --  the same go.

   --  Commands: what the application can be asked to do, by a key, a menu or
   --  an assistive technology, as well as a button. A widget is given a
   --  command with Set_Tag (see Pomarine.Widgets.Commands). A command is
   --  offered to the widget with the focus and then the widgets it is in
   --  (Handle_Command), as an edit command is to the field being typed in,
   --  and last to the tree's listener as a Click with the command's tag.

   Edit_Undo       : constant Integer := -101;
   Edit_Redo       : constant Integer := -102;
   Edit_Cut        : constant Integer := -103;
   Edit_Copy       : constant Integer := -104;
   Edit_Paste      : constant Integer := -105;
   Edit_Select_All : constant Integer := -106;
   --  The commands of every text field, from the menu as from the keys:
   --  the application's own tags are not negative (see
   --  Pomarine.Widgets.Commands). A field takes them, when it has the
   --  focus.

   type Command_State is (Not_Offered, Disabled, Enabled, Ticked);
   --  What a command is for now: not offered at all, offered but not
   --  possible, possible, or possible and in force (a ticked row).

   type Command_Validator is access function (Tag : Integer) return Command_State;

   procedure Set_Validator (Item : in out Tree; To : Command_Validator);
   --  Have the tree say to every widget that has a command what the
   --  command is for (see Command_State_Changed), whenever Revalidate is
   --  called, and when it is time (Update). Without one, widgets are as
   --  the application sets them.

   procedure Revalidate (Item : in out Tree);
   --  Ask the validator about each widget's command, and tell those whose
   --  answer is not what it was.

   procedure Command_State_Changed
     (Item : in out Widget; State : Command_State) is null;
   --  What the command it has is for now: turn on, off, tick, hide.

   procedure Handle_Command
     (Item : in out Widget; Tag : Integer; Done : out Boolean);
   --  Do the command Tag if it is for it. By default none is.

   procedure Perform_Command
     (Item : in out Tree; Tag : Integer; Done : out Boolean);
   --  Offer the command to the widget with the focus and the widgets it
   --  is in, and then to the listener: Done says whether any took it.

   procedure Bind_Key
     (Item    : in out Tree;
      Key     : SDL3.Events.Key_Code;
      Command : Boolean := False;
      Shift   : Boolean := False;
      Tag     : Integer)
     with Pre => Tag /= No_Tag;
   --  Make Key (with Command, with Shift) perform the command Tag, when no
   --  widget takes it for its own. Bound again, it is replaced.

   Key_Binding_Capacity : constant := 64;

   --  Building

   procedure Set_Root (Item : in out Tree; Root : in out Widget'Class)
     with Pre  => not Has_Root (Item) and then not Is_Attached (Root),
          Post => Is_Attached (Root);
   --  Make Root the whole of Item: its node is Yoga's root.

   function Has_Root (Item : Tree) return Boolean;

   procedure Add (Parent : in out Widget'Class; Child : in out Widget'Class)
     with Pre  => Is_Attached (Parent) and then not Is_Attached (Child)
                  and then Child_Count (Child) = 0,
          Post => Is_Attached (Child) and then Parent_Of (Child) /= null;
   --  Put Child after Parent's other children, and so above them.

   procedure Add
     (Parent : in out Widget'Class; First, Second : in out Widget'Class)
     with Pre  => Is_Attached (Parent)
                  and then not Is_Attached (First) and then Child_Count (First) = 0
                  and then not Is_Attached (Second) and then Child_Count (Second) = 0,
          Post => Is_Attached (First) and then Is_Attached (Second);

   procedure Add
     (Parent : in out Widget'Class; First, Second, Third : in out Widget'Class)
     with Pre  => Is_Attached (Parent)
                  and then not Is_Attached (First) and then Child_Count (First) = 0
                  and then not Is_Attached (Second) and then Child_Count (Second) = 0
                  and then not Is_Attached (Third) and then Child_Count (Third) = 0,
          Post => Is_Attached (First) and then Is_Attached (Second)
                  and then Is_Attached (Third);

   procedure Add
     (Parent : in out Widget'Class;
      First, Second, Third, Fourth : in out Widget'Class)
     with Pre  => Is_Attached (Parent)
                  and then not Is_Attached (First) and then Child_Count (First) = 0
                  and then not Is_Attached (Second) and then Child_Count (Second) = 0
                  and then not Is_Attached (Third) and then Child_Count (Third) = 0
                  and then not Is_Attached (Fourth) and then Child_Count (Fourth) = 0,
          Post => Is_Attached (First) and then Is_Attached (Second)
                  and then Is_Attached (Third) and then Is_Attached (Fourth);

   procedure Add
     (Parent : in out Widget'Class;
      First, Second, Third, Fourth, Fifth : in out Widget'Class)
     with Pre  => Is_Attached (Parent)
                  and then not Is_Attached (First) and then Child_Count (First) = 0
                  and then not Is_Attached (Second) and then Child_Count (Second) = 0
                  and then not Is_Attached (Third) and then Child_Count (Third) = 0
                  and then not Is_Attached (Fourth) and then Child_Count (Fourth) = 0
                  and then not Is_Attached (Fifth) and then Child_Count (Fifth) = 0,
          Post => Is_Attached (First) and then Is_Attached (Second)
                  and then Is_Attached (Third) and then Is_Attached (Fourth)
                  and then Is_Attached (Fifth);
   --  Put each after the others in order, as Add does one: for a parent
   --  built in a line, as Add (Side, Logo, New_Button, Room, Settings).

   procedure Add_Before
     (Parent : in out Widget'Class;
      Child  : in out Widget'Class;
      Before : Widget'Class)
     with Pre  => Is_Attached (Parent) and then not Is_Attached (Child)
                  and then Child_Count (Child) = 0
                  and then Parent_Of (Before) /= null,
          Post => Is_Attached (Child) and then Parent_Of (Child) /= null;
   --  Put Child among Parent's children just before Before, one of them,
   --  and so below it: for a parent whose content is added by more than
   --  one hand, in the order of the layout.

   function Is_Attached (Item : Widget'Class) return Boolean;
   --  Whether it is in a tree.

   function Id_Of (Item : Widget'Class) return Node_Id;
   --  Its id; No_Node if it is not in a tree.

   function Part_Id (Item : Widget'Class; Part : Positive) return Node_Id;
   --  The id of one of its parts (see Part_Count); No_Node if it is not in
   --  a tree.

   function Resolve (Item : Tree; Id : Node_Id) return Widget_Access;
   --  The widget Id names, if it is still in the tree; null if Id is
   --  No_Node, or the widget was taken out.

   function Is_Live (Item : Tree; Id : Node_Id) return Boolean;
   --  Whether Id names a widget that is in the tree.

   function Part_Of (Id : Node_Id; Part : Natural) return Node_Id;
   --  The id of the part numbered Part of the widget Id names (see
   --  Part_Number); Id itself if Part is 0.

   function Part_Number_Of (Id : Node_Id) return Natural;
   --  Which part of a widget Id names; 0 if the widget itself.

   function Root_Id (Item : Tree) return Node_Id;
   function Parent_Id (Item : Tree; Id : Node_Id) return Node_Id
     with Pre => Is_Live (Item, Id);
   function First_Child_Id (Item : Tree; Id : Node_Id) return Node_Id
     with Pre => Is_Live (Item, Id);
   function Next_Sibling_Id (Item : Tree; Id : Node_Id) return Node_Id
     with Pre => Is_Live (Item, Id);
   --  Walking the tree by ids; No_Node where there is nothing.

   function To_Unsigned_64 (Id : Node_Id) return Interfaces.Unsigned_64;
   function From_Unsigned_64 (Value : Interfaces.Unsigned_64) return Node_Id;
   --  An id as a number, for a place that has numbers for nodes: a
   --  number that is not an id's is not live in any tree.

   function Image (Id : Node_Id) return String;

   type Dirty_Kind is (Layout_Dirty, Paint_Dirty, Semantics_Dirty);
   --  What of a widget has changed since it was last looked at:
   --  where it is and how big (Layout_Dirty), how it looks
   --  (Paint_Dirty), or what it is to an assistive technology
   --  (Semantics_Dirty). Each is looked at by its own pass over the tree,
   --  which clears it, so that a change to one costs only that pass.

   procedure Mark_Dirty (Item : in out Widget'Class; What : Dirty_Kind)
     with Pre => Is_Attached (Item);

   function Is_Dirty (Item : Widget'Class; What : Dirty_Kind) return Boolean;
   --  False if it is not in a tree.

   function Node (Item : Widget'Class) return Yoga.Nodes.Node
     with Pre => Is_Attached (Item);
   --  Its node, to style. Changing the style of a widget's node is
   --  changing its layout: say so with Request_Layout.

   function Parent_Of (Item : Widget'Class) return Widget_Access;
   --  null for the root.

   procedure Remove (Item : in out Widget'Class)
     with Pre  => Is_Attached (Item) and then Parent_Of (Item) /= null,
          Post => not Is_Attached (Item) and then Child_Count (Item) = 0;
   --  Take Item out of the tree, with everything in it: they and their
   --  nodes are gone from it, and its parent's other children take up
   --  the room, at the next layout. If any of them had the focus, or
   --  the pointer, they do not now. Each is as it was before it was
   --  added, so that one can be added again, with its children, as
   --  below it was built, and styled again.

   procedure Raise_To_Front (Item : in out Widget'Class)
     with Pre => Is_Attached (Item) and then Parent_Of (Item) /= null;
   --  Make it the last of its parent's children: the one drawn over the
   --  others, and found first where they overlap. Only that order
   --  changes, not the layout, so it is for widgets placed by their
   --  edges (Yoga.Absolute).

   procedure Set_Visible (Item : in out Widget'Class; To : Boolean)
     with Pre => Is_Attached (Item);
   --  Show it, or hide it, with all of its children: hidden, it takes no
   --  room in its parent, is not drawn, and nothing is taken by it, nor
   --  can it have the focus or the pointer over it. It is still in the
   --  tree, with its place in the order, and keeps its state and its
   --  style.

   procedure Set_Measured (Item : in out Widget'Class; To : Boolean := True);
   --  Have the layout ask the widget how big it is (Measure) where its style
   --  does not say. Off to begin with, so that a widget is as the style
   --  makes it, however empty. Can be done before it is in a tree.

   procedure Content_Changed (Item : in out Widget'Class);
   --  What it holds, that its size is of, has changed: it is measured again
   --  at the next layout. Nothing is done if it is not measured.

   function Is_Visible (Item : Widget'Class) return Boolean;
   --  Whether it has not been hidden. Its children are not shown if it
   --  is not: see Is_Shown.

   function Is_Shown (Item : Widget'Class) return Boolean;
   --  Whether it and every widget it is in is visible.

   function Child_Count (Item : Widget'Class) return Natural;

   function Child_At (Item : Widget'Class; Index : Positive)
      return Widget_Access
     with Pre => Index <= Child_Count (Item);

   --  What a tree shares

   procedure Set_Density (Item : in out Tree; To : Float)
     with Pre => To >= 1.0;
   --  Pixels to a point of the window, which events are in. Layout is in
   --  pixels: the application styles nodes in them.

   function Density (Item : Tree) return Float;

   procedure Set_Settled (Item : in out Tree; To : Boolean);
   --  Say whether what is shown has stopped changing (as a zoom has), so
   --  that widgets which draw quickly while it does can draw their best.
   --  Changing it damages the root.

   function Is_Settled (Item : Tree) return Boolean;

   procedure Set_Clipboard
     (Item : in out Tree; Board : in out Clipboards.Clipboard'Class);
   --  The clipboard for widgets to cut, copy and paste with. It must be
   --  there as long as the tree is used.

   type Clipboard_Access is access all Clipboards.Clipboard'Class;

   procedure Set_Line_Texts
     (Item : in out Tree; Lines : aliased in out Line_Texts.Drawer);
   --  The system font for widgets' single lines of text, labels and
   --  buttons', drawn from Lines, which must be there as long as the
   --  tree is used, and after the renderer. Without it they use the
   --  debug font of SDL3.Windows.Renderers.

   type Line_Texts_Access is access all Line_Texts.Drawer;

   procedure Set_Icons
     (Item : in out Tree; Library : aliased in out Icons.Library);
   --  The icons for widgets to draw, as buttons', from Library, which
   --  must be there as long as the tree is used, and after the renderer.

   type Icons_Access is access all Icons.Library;

   function Icon_Library (Item : Widget'Class) return Icons_Access
     with Pre => Is_Attached (Item);
   --  null if the tree has none.

   function Text_Lines (Item : Widget'Class) return Line_Texts_Access
     with Pre => Is_Attached (Item);
   --  null if the tree has none.

   --  Animation: a number moving from one value to another over a little
   --  time, that a widget shows (a scroll's offset, a bar's length). The
   --  tree runs them: each turn of Update they are given the time, the
   --  widget is told the number, and the tree says (Until_Update) that it
   --  wants to be woken for the next frame, while any is running. Nothing
   --  is made as one runs, and when the person has asked the system for
   --  less movement they are not run: the widget is given where it was
   --  going at once.

   type Easing is (Linear, Ease_Out, Ease_In_Out);
   --  How the number goes: at a steady rate, quickly at first and then
   --  slower, or slowly at the ends.

   type Animation_Setter is access procedure (Item : in out Widget'Class; Value : Float);

   Frame_Milliseconds : constant := 16;
   --  How long between the frames of animation: about sixty a second.

   Animation_Capacity : constant := 32;
   --  How many run at once in a tree.

   procedure Animate
     (Item         : in out Widget'Class;
      From, To     : Float;
      Milliseconds : Natural;
      How          : Easing := Ease_Out;
      Apply        : not null Animation_Setter)
     with Pre => Is_Attached (Item);
   --  Have Apply called with the numbers from From to To, over
   --  Milliseconds, ending with To exactly. One already running for Item
   --  with the same Apply is replaced, from where it is (From, then).

   procedure Stop_Animations (Item : in out Widget'Class);
   --  Stop what is running for Item, where it is.

   function Is_Animating (Item : Tree) return Boolean;

   procedure Set_Reduced_Motion (Item : in out Tree; To : Boolean);
   --  Whether movement is to be left out (see Pomarine.System_Settings):
   --  Animate then gives the last number at once. Off to begin with.

   function Reduced_Motion (Item : Tree) return Boolean;

   --  Layout, damage and drawing

   procedure Layout
     (Item   : in out Tree;
      Target : SDL3.Painters.Painter'Class)
     with Pre => Has_Root (Item);
   --  Fit the widgets to the size of Target, in pixels, and place any that
   --  have moved or been resized (see Placed), damaging where they were
   --  and where they are. Paint does so too: it is for when the layout is
   --  needed sooner.

   procedure Layout
     (Item   : in out Tree;
      Target : SDL3.Windows.Renderers.Renderer)
     with Pre => Has_Root (Item);
   --  As above, for a renderer.

   procedure Request_Layout (Item : in out Widget'Class)
     with Pre => Is_Attached (Item);
   --  Say that its style, or its content that sizes it, has changed, so
   --  that Needs_Paint is true until the layout has been looked at again.

   procedure Move_To
     (Item         : in out Widget'Class;
      Left, Top    : Float;
      Was_Left, Was_Top : in out Float;
      Changed      : in out Boolean)
     with Pre => Is_Attached (Item);
   --  Put the widget, which is placed by its edges, Left and Top pixels
   --  from its parent, unless Was_Left and Was_Top, where the caller last
   --  put it, say it is: then they are made so, Changed is set, and a
   --  layout is requested.

   procedure Invalidate (Item : in out Widget'Class)
     with Pre => Is_Attached (Item);
   --  Say that all of it must be drawn again.

   procedure Invalidate (Item : in out Widget'Class; Part : Pixel_Box)
     with Pre => Is_Attached (Item);
   --  Say that Part must be drawn again, in pixels from the top left of
   --  the target, as of a caret; only what is in the widget counts.

   procedure Invalidate_All (Item : in out Tree);
   --  Say that what the target shows is lost, as when a window is
   --  exposed or an offscreen target resized: the next Paint draws it
   --  all.

   function Needs_Paint (Item : Tree) return Boolean;
   --  Whether there is anything to draw: damage, a layout to look at, or
   --  a target to draw to afresh.

   function Damage (Item : Tree) return Pixel_Box;
   --  What widgets have said, since the last Paint, to draw again, as of
   --  the last layout; Is_Empty if nothing. Not what Invalidate_All says.

   procedure Paint
     (Item     : in out Tree;
      Target   : SDL3.Painters.Painter'Class;
      Colors   : Themes.Theme;
      Retained : Boolean := False)
     with Pre => Has_Root (Item);
   --  Lay out, and draw the widgets that are in the damage over
   --  Colors (Themes.Background), then say there is none. It does not present
   --  Target.
   --
   --  Retained says Target still has what was last drawn on it, so that
   --  only the damage need be drawn again: true of an offscreen target,
   --  not of a window, whose frames are swapped (draw it all). When the
   --  target has changed size, or is new, or has been said to be lost, it
   --  is drawn all.

   procedure Paint
     (Item     : in out Tree;
      Target   : SDL3.Windows.Renderers.Renderer;
      Colors   : Themes.Theme;
      Retained : Boolean := False)
     with Pre => Has_Root (Item);
   --  As above, for a renderer: what is drawn is drawn at once.

   --  Events and time

   procedure Dispatch
     (Item    : in out Tree;
      Event   : SDL3.Events.Event;
      Handled : out Boolean);
   --  Give Event to the widgets, as Handle says. A click gives the focus
   --  to the widget it is on, or the one inside which it is, that
   --  accepts it; a click on none, that nothing takes, takes the focus
   --  away (and is taken). The pointer's moving keeps which widget it is
   --  over for Hover_Changed. Events other than the mouse's, keys' and
   --  typing are left to the application.

   procedure Update (Item : in out Tree; Now : SDL3.Events.Milliseconds);
   --  Tell every widget the time.

   function Until_Update (Item : Tree) return Integer;
   --  The fewest milliseconds any widget says it must wait after the time
   --  last said; negative if none needs the time. As a timeout to wait
   --  for events for.

   function Wanted_Cursor (Item : Tree) return SDL3.Cursors.Kind;
   --  The cursor to show: the one of the widget holding a press, or of the
   --  deepest one under the pointer that wants any but the default, going
   --  out through the widgets it is in.

   function Hit (Item : Tree; X, Y : Float) return Widget_Access;
   --  The widget at pixel X, Y: the last of the deepest. null if none.

   --  Focus: at most one widget has it, and takes keys and typing.

   procedure Focus (Item : in out Widget'Class)
     with Pre  => Is_Attached (Item) and then Accepts_Focus (Item),
          Post => Has_Focus (Item);
   --  Give it the focus, taking it from the widget that had it.

   procedure Release_Focus (Item : in out Widget'Class)
     with Pre => Is_Attached (Item);
   --  Take the focus from it, if it has it.

   procedure Clear_Focus (Item : in out Tree);

   procedure Focus_Next (Item : in out Tree; Backwards : Boolean := False);
   --  Give the focus to the next widget that takes it, in the order they
   --  are in the tree (as they are laid out, for the usual tree), going
   --  round: the first if none has it, or after the last. Backwards, the
   --  one before. Nothing is done if none takes it.

   procedure Set_Focus_Scope (Item : in out Tree; To : in out Widget'Class)
     with Pre => Is_Attached (To);
   --  Have Tab go round only the widgets in To (a dialog's), and not the
   --  rest of the tree, until Clear_Focus_Scope: as for a dialog that is
   --  over the rest. If the focus is outside it, Tab goes to its first. It
   --  is let go of if To is removed.

   procedure Clear_Focus_Scope (Item : in out Tree);

   procedure Set_Tab_Navigation (Item : in out Tree; To : Boolean);
   --  Have Tab (and Shift-Tab, backwards) move the focus (Focus_Next) when
   --  no widget takes the key. Off to begin with.

   function Has_Focus (Item : Widget'Class) return Boolean;

   function Is_Focus_Visible (Item : Widget'Class) return Boolean;
   --  Whether a focus ring is to be drawn on it: it has the focus, and the
   --  last thing done was by the keyboard, not the pointer (as when a
   --  button is clicked, and the person has no need of a ring).

   function Focus_Of (Item : Tree) return Widget_Access;
   --  null if none.

   --  Telling an assistive technology

   type Semantic_Sink is limited interface;
   --  What takes the description of the tree: an adapter to the system's
   --  accessibility, or a test.

   type Node_Id_Array is array (Positive range <>) of Node_Id;

   procedure Begin_Update
     (Self : in out Semantic_Sink;
      Root : Node_Id;
      Focused : Node_Id;
      Whole : Boolean) is abstract;
   --  An update of the tree begins: Whole, it is all of it. Focused is the
   --  node that has the focus, or Root if none.

   procedure Describe_Node
     (Self     : in out Semantic_Sink;
      Id       : Node_Id;
      Facts    : Semantics.Description;
      Bounds   : Semantics.Rectangle;
      Children : Node_Id_Array) is abstract;
   --  A node that is new or has changed, with its children in order,
   --  those that are shown. Bounds are in points from the top left of the
   --  window.

   procedure End_Update (Self : in out Semantic_Sink) is abstract;

   procedure Set_Title (Item : in out Tree; Text : String);
   --  The name of the window, which the root of the tree is to an
   --  assistive technology.

   procedure Describe_Changes
     (Item : in out Tree;
      Into : in out Semantic_Sink'Class;
      Whole : Boolean := False)
     with Pre => Has_Root (Item);
   --  Tell Into what has changed of what the widgets are, since the last
   --  time: nodes that are new, whose widget has said it changed, was
   --  moved or sized, or whose children changed. With Whole, all of
   --  them, as when an assistive technology first asks. Does a pass over
   --  the tree: call it when one is listening, not before.

   procedure Act
     (Item    : in out Tree;
      Id      : Node_Id;
      Request : Semantics.Request;
      Done    : out Boolean);
   --  An assistive technology asks of the node Id what Request says. It
   --  does what a person could do by hand: Focus gives it the focus,
   --  Blur takes it away, and the rest are for the widget (see Perform).
   --  Done is False if the node is not there, or cannot.

   --  A widget's place and surroundings

   function Left_Of (Item : Widget'Class) return Float;
   function Top_Of (Item : Widget'Class) return Float;
   function Width_Of (Item : Widget'Class) return Float;
   function Height_Of (Item : Widget'Class) return Float;
   --  Its box in pixels from the top left of the target, as of the last
   --  layout; zeroes before.

   function Is_Placed (Item : Widget'Class) return Boolean;
   --  Whether it has had a layout.

   function Contains (Item : Widget'Class; X, Y : Float) return Boolean;
   --  Whether pixel X, Y is in its box.

   function Painting_Part (Item : Widget'Class) return Pixel_Box;
   --  While it is drawn: the part of its box that is to be, which is all
   --  that it is clipped to. A widget that has a lot to draw can leave
   --  what is outside it, as when only a caret is to be drawn again.

   function Is_Hovered (Item : Widget'Class) return Boolean;
   --  Whether the pointer is over it, or something in it.

   function Density (Item : Widget'Class) return Float
     with Pre => Is_Attached (Item);

   function Is_Settled (Item : Widget'Class) return Boolean
     with Pre => Is_Attached (Item);

   function Clipboard (Item : Widget'Class) return Clipboard_Access
     with Pre => Is_Attached (Item);
   --  null if the tree has none.

private

   type Tree_Access is access all Tree;

   subtype Node_Index is Natural range 0 .. Node_Capacity;
   --  Where a node is in the table; 0 for none.

   type Node_Id is record
      Slot : Node_Index := 0;
      Use_Number : Natural := 0;
      --  Which use of the slot it names.
      Part : Natural := 0;
      --  0 for the widget; otherwise which of the parts it describes
      --  that are not widgets (see Part_Count).
   end record;

   No_Node : constant Node_Id := (0, 0, 0);

   --  What the application has had a widget do when it speaks, in place of
   --  the listener: see Pomarine.Widgets.Callbacks, which makes them. A
   --  hook is run with whatever it was given, which only the package that
   --  made it knows how to use.

   Hook_Capacity : constant := 12;
   --  How many kinds of event one widget has its own handlers for.

   type Hook_Runner is access procedure
     (Self, Proc : System.Address;
      Source     : in out Widget'Class;
      Event      : Widget_Event);

   type Hook is record
      Used : Boolean := False;
      Kind : Event_Kind := Click;
      Run  : Hook_Runner;
      Self : System.Address := System.Null_Address;
      Proc : System.Address := System.Null_Address;
   end record;

   type Hook_Array is array (1 .. Hook_Capacity) of Hook;

   --  A widget keeps what is its own, and what the application may say
   --  before it is in a tree; the tree's table keeps the rest.

   type Widget is abstract new Ada.Finalization.Limited_Controlled with record
      Owner : Tree_Access;
      Slot  : Node_Index := 0;
      Tag   : Integer := No_Tag;
      Index : Natural := 0;
      Own   : Listener_Access;
      Cold : Natural := 0;
      --  Where its seldom-used parts are kept (what the application has
      --  called it, its handlers): a place in a pool the library keeps, so
      --  that the widgets are small, and so are lined up in the tree's walk.
      --  0 until it has any.
      Said_Role : Semantics.Role := Semantics.Unknown;
      Hidden_From_AT : Boolean := False;
      Hid_By_Command : Boolean := False;
      Measured : Boolean := False;
   end record;

   procedure Set_Hook
     (Item : in out Widget'Class;
      Kind : Event_Kind;
      Run  : not null Hook_Runner;
      Self, Proc : System.Address);
   --  Run Run with Self and Proc when Item says Kind, in place of its
   --  listener. Replaces one for the same kind.

   procedure Clear_Hook (Item : in out Widget'Class; Kind : Event_Kind);

   overriding procedure Finalize (Item : in out Widget);
   --  Out of the tree, if it is in one, as Remove, and everything in it.

   Queue_Capacity : constant := 32;

   type Queued_Event is record
      Source : Node_Id;
      Target : Listener_Access;
      Event  : Widget_Event;
   end record;

   type Event_Queue is array (1 .. Queue_Capacity) of Queued_Event;

   --  The nodes, by what is kept of each, so that a pass over the tree
   --  that wants one thing reads that and no more. Made once, when the
   --  tree is given its root.

   subtype Slots is Positive range 1 .. Node_Capacity;

   type Widget_Array is array (Slots) of Widget_Access;
   type Index_Array is array (Slots) of Node_Index;
   type Count_Array is array (Slots) of Natural;
   type Flag_Array is array (Slots) of Boolean;

   type Spot is record
      Left, Top, Wide, High : Float;
      --  In pixels from the top left of the target: where the last layout
      --  put it.
      Placed  : Boolean;
      Visible : Boolean;
   end record;
   --  What a hit and a paint ask of a node together, kept together.

   type Spot_Array is array (Slots) of Spot;
   type Yoga_Array is array (Slots) of Yoga.Nodes.Node;
   type Box_Array is array (Slots) of Pixel_Box;

   type Node_Table is record
      Object     : Widget_Array;
      --  The widget in each slot used (up to Fresh); to call its operations.
      Use_Number : Count_Array;
      Parent, First, Last, Next : Index_Array;
      Children   : Count_Array;
      Yoga_Node  : Yoga_Array;
      Spot       : Spot_Array;
      Paint_Box  : Box_Array;
      --  Of its box, what is being drawn.
      Hovered, Focused : Flag_Array;
      Known      : Flag_Array;
      --  Whether an assistive technology has been told of it.
      Kids       : Node_Id_Array (Slots);
      --  The children being told of, while a node is.
      Layout_Dirty, Paint_Dirty, Semantics_Dirty : Flag_Array;
      Free       : Node_Index;
      --  The slots given back, linked by Next.
      Fresh      : Natural;
      --  How many slots have ever been used: those after are unused.
      Used       : Natural;
   end record;
   pragma Suppress_Initialization (Node_Table);
   --  So that the table, made for every widget there could be, is not touched
   --  but for the part that is used (see Set_Root, which makes it).

   type Table_Access is access Node_Table;

   type Animation is record
      Active   : Boolean := False;
      Who      : Node_Id;
      From, To : Float := 0.0;
      Start    : SDL3.Events.Milliseconds := 0;
      Length   : Natural := 0;
      How      : Easing := Linear;
      Apply    : Animation_Setter;
   end record;

   type Animation_Array is array (1 .. Animation_Capacity) of Animation;

   type Told_State_Array is array (Slots) of Command_State;
   --  What each widget was last told its command was for.

   type Key_Binding is record
      Key     : SDL3.Events.Key_Code := 0;
      Command : Boolean := False;
      Shift   : Boolean := False;
      Tag     : Integer := No_Tag;
   end record;

   type Key_Table is array (1 .. Key_Binding_Capacity) of Key_Binding;

   type Tree is new Ada.Finalization.Limited_Controlled with record
      Yoga_Tree : Yoga.Nodes.Tree;
      Hearer    : Listener_Access;
      Queue     : Event_Queue;
      Queued    : Natural := 0;
      --  How many are kept, from Queue_First, round.
      Queue_First : Positive := 1;
      Delivering  : Boolean := False;
      Nodes     : Table_Access;
      Root      : Node_Index := 0;
      Title     : Semantics.Text;
      Tab_Moves : Boolean := False;
      Keyboard_Focus : Boolean := False;
      Scope : Node_Id := No_Node;
      --  Tab is only for what is in it, if it is there: see Set_Focus_Scope.
      --  Whether the last input was a key: see Is_Focus_Visible.
      Clock     : SDL3.Events.Milliseconds := 0;
      --  The time at the last Update.
      Reduce_Motion : Boolean := False;
      Moving    : Animation_Array;
      Running   : Natural := 0;
      Validator : Command_Validator;
      Told_States : Told_State_Array;
      Keys      : Key_Table;
      Keys_Bound : Natural := 0;
      Whole_Next : Boolean := True;
      Density   : Float := 1.0;
      Settled   : Boolean := True;
      Board     : Clipboard_Access;
      Lines     : Line_Texts_Access;
      Pictures  : Icons_Access;

      Focus     : Node_Index := 0;
      Hover     : Node_Index := 0;
      --  The deepest widget the pointer was last over.
      Capture   : Node_Index := 0;
      Capture_Button : Natural := 0;
      --  The widget that took a press, and which button, until it is
      --  let go.
      Wheel_Taker : Node_Index := 0;
      Wheel_Time  : SDL3.Events.Milliseconds := 0;
      --  The widget that took the last wheel turn, and when. A turn soon
      --  after goes to it first, so a pan or a scroll under way is not
      --  taken over by what the pointer drifts across.

      Replace_All    : Boolean := False;
      --  Every widget is to be placed again at the next layout.
      Layout_Pending : Boolean := False;
      Lost           : Boolean := True;
      --  What the target shows is not what was drawn, or nothing was.
      Painted_Width, Painted_Height : Natural := 0;
      Damaged        : Pixel_Box;
   end record;

   overriding procedure Finalize (Item : in out Tree);
   --  Lets go of the widgets in it: they are as they were before they
   --  were added.

end Pomarine.Widgets;
