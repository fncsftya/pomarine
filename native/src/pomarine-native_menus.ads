with System;
with Pomarine.Widgets;

--  The application's menu bar, the system's own: the menus a Mac
--  application has across the top of the screen, and the keys they are
--  chosen with. Each item says a command, as a button does (a tag, see
--  Pomarine.Widgets.Commands): what is chosen is performed with the
--  window's widgets (Perform_Command), so that a command is the same
--  whether a button, a key or a menu says it, and a widget that takes
--  edit commands takes them from the menu as from the keyboard.
--
--  What each item is for now (offered, possible, in force) is the tree's
--  command validator's (Widgets.Set_Validator): Update_States asks it.
--
--  The system's own application menu (About, Hide, Quit) stays first; the
--  menus here follow it. Everything is on the window's thread, and a
--  menu has to be made before it is shown.

package Pomarine.Native_Menus is

   type Menu_Bar is limited private;

   type Menu is private;
   --  A menu in the bar.

   Capacity : constant := 128;
   --  Items the bar keeps of its own, to know what each is for.

   procedure Install (Item : in out Menu_Bar)
   with Post => Is_Installed (Item);
   --  Make ready to add menus and hear what is chosen. Item must not be
   --  moved or copied while installed (it is limited, so cannot be).

   function Is_Installed (Item : Menu_Bar) return Boolean;

   procedure Add_Menu (Item : in out Menu_Bar; Title : String; Result : out Menu)
   with Pre => Is_Installed (Item);
   --  A menu after those there are, in the bar.

   procedure Add_Item
     (Item    : in out Menu_Bar;
      To      : Menu;
      Title   : String;
      Tag     : Integer;
      Key     : String := "";
      Command : Boolean := True;
      Shift   : Boolean := False;
      Option  : Boolean := False;
      Control : Boolean := False)
   with Pre => Is_Installed (Item) and then Tag /= Widgets.No_Tag;
   --  An item that says Tag when chosen. Key is its key equivalent (a
   --  character, in lower case for a letter) with the keys held that are
   --  true: Command to begin with, as Command-S.

   procedure Add_Separator (Item : in out Menu_Bar; To : Menu)
   with Pre => Is_Installed (Item);

   procedure Update_States (Item : in out Menu_Bar; Validator : Widgets.Command_Validator)
   with Pre => Is_Installed (Item);
   --  Make each item as the validator says its command is: left out,
   --  dimmed, ticked, or as usual.

   procedure Update_States (Item : in out Menu_Bar; Tree : Widgets.Tree)
   with Pre => Is_Installed (Item);
   --  As above, as the tree's own validator says (Widgets.Command_State_Of).

   function Is_Waiting (Item : Menu_Bar) return Boolean;
   --  Whether something has been chosen that Pump has not done.

   procedure Pump (Item : in out Menu_Bar; Tree : in out Widgets.Tree);
   --  Perform what has been chosen, in order, with the tree.

   procedure Choose (Item : in out Menu_Bar; Tag : Integer);
   --  As if the item that says Tag had been chosen: for a test.

   procedure Discard (Item : in out Menu_Bar; Tag : Integer);
   --  The command Tag was done already, by the key it is chosen with
   --  reaching a widget: a key equivalent is both the menu's, which says
   --  Tag, and a key event, which the widget took. Drop the choice of Tag
   --  that is waiting, or, if it has not come yet, the next one (so that
   --  Pump does not do it twice), if it comes as soon as the next Pump.

private

   type Menu is record
      Handle : System.Address := System.Null_Address;
   end record;

   type Tag_Array is array (1 .. Capacity) of Integer;

   Chosen_Capacity : constant := 16;
   type Chosen_Array is array (1 .. Chosen_Capacity) of Integer;

   protected type Mailbox is
      procedure Put (Tag : Integer);
      procedure Take (Tag : out Integer; Found : out Boolean);
      function Waiting return Boolean;
      procedure Discard (Tag : Integer);
      procedure Tick;
      --  Discard drops a waiting Tag, else the next one Put, until the
      --  second Tick after it.
   private
      Items   : Chosen_Array;
      First   : Positive := 1;
      Count   : Natural := 0;
      Skip    : Integer := Widgets.No_Tag;
      Skip_At : Natural := 0;
   end Mailbox;

   type Menu_Bar is limited record
      Installed : Boolean := False;
      Tags      : Tag_Array;
      Tag_Count : Natural := 0;
      Mail      : Mailbox;
   end record;

end Pomarine.Native_Menus;
