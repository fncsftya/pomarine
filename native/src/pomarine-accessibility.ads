with Ada.Finalization;
with System;
with SDL3.Windows;
with Pomarine.Semantics;
with Pomarine.Widgets;

--  Widgets for assistive technology, through AccessKit: what a window's
--  widgets are (see Pomarine.Semantics) told to the system's own
--  accessibility, which is how VoiceOver reads a window and presses its
--  buttons.
--
--  An application makes one Adapter for a window, attaches it to the
--  window once it is open, and calls Update once a turn of its loop, after
--  the tree has been given its events and its time. Nothing is done until
--  an assistive technology asks: the cost to a window no one is listening
--  to is a test of a flag. What the technology asks the widgets to do
--  (press a button, set a slider, type in a field) is done by Update, as
--  it would be done by hand, and the widgets say so to their listeners as
--  they do for the pointer and the keys.
--
--  Everything is on the one thread that runs the window, but a request
--  from the technology may wake it: Is_Waiting is for a loop that blocks.

package Pomarine.Accessibility is

   type Adapter is limited new Ada.Finalization.Limited_Controlled and Widgets.Semantic_Sink with private;

   procedure Attach (Item : in out Adapter; Window : SDL3.Windows.Window)
   with Pre => SDL3.Windows.Is_Open (Window) and then not Is_Attached (Item), Post => Is_Attached (Item);
   --  Make the window's accessibility, which stays quiet until asked. Do it
   --  before the window is shown, and keep the adapter as long as the
   --  window. Item must not be moved or copied while attached (it is
   --  limited, so cannot be).

   function Is_Attached (Item : Adapter) return Boolean;

   procedure Detach (Item : in out Adapter)
   with Post => not Is_Attached (Item);

   function Is_Active (Item : Adapter) return Boolean;
   --  Whether an assistive technology has asked.

   function Is_Waiting (Item : Adapter) return Boolean;
   --  Whether there is something for Update to do: the technology has just
   --  asked for the tree, or for something to be done. Set from the thread
   --  of the system's request; the loop is woken (Pomarine.Events.Wake).

   procedure Update (Item : in out Adapter; Tree : in out Widgets.Tree)
   with Pre => Is_Attached (Item) and then Widgets.Has_Root (Tree);
   --  Do what the technology has asked of the widgets; and, if it is
   --  listening, tell it what has changed of them.

   procedure Window_Focus_Changed (Item : in out Adapter; Focused : Boolean)
   with Pre => Is_Attached (Item);
   --  The window has gained or lost the focus of the system.

   Request_Capacity : constant := 32;
   --  How many requests are kept between turns; more are dropped.

   function Requests_Dropped (Item : Adapter) return Natural;

private

   type Request_Entry is record
      Node    : Widgets.Node_Id;
      Request : Semantics.Request;
   end record;

   type Request_Array is array (1 .. Request_Capacity) of Request_Entry;

   protected type Mailbox is
      procedure Activated;
      procedure Put (Node : Widgets.Node_Id; Request : Semantics.Request);
      procedure Take (Node : out Widgets.Node_Id; Request : out Semantics.Request; Found : out Boolean);
      procedure Take_Activation (Was : out Boolean);
      function Waiting return Boolean;
      function Dropped return Natural;
   private
      Queue : Request_Array;
      First : Positive := 1;
      Count : Natural := 0;
      Asked : Boolean := False;
      Lost  : Natural := 0;
   end Mailbox;

   type Adapter is limited new Ada.Finalization.Limited_Controlled and Widgets.Semantic_Sink with record
      Handle  : System.Address := System.Null_Address;
      --  AccessKit's adapter.
      Pending : System.Address := System.Null_Address;
      --  The update being made.
      Mail    : Mailbox;
      Whole   : Boolean := True;
      --  The next update is all the tree.
   end record;

   overriding
   procedure Finalize (Item : in out Adapter);

   overriding
   procedure Begin_Update (Self : in out Adapter; Root : Widgets.Node_Id; Focused : Widgets.Node_Id; Whole : Boolean);

   overriding
   procedure Describe_Node
     (Self     : in out Adapter;
      Id       : Widgets.Node_Id;
      Facts    : Semantics.Description;
      Bounds   : Semantics.Rectangle;
      Children : Widgets.Node_Id_Array);

   overriding
   procedure End_Update (Self : in out Adapter);

end Pomarine.Accessibility;
