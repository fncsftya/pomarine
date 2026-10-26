with Ada.Strings.Unbounded;
with SDL3;

package body Pomarine.Testing is

   package Unbounded renames Ada.Strings.Unbounded;

   use type Pomarine.Events.Milliseconds;
   use type Semantics.Role;
   use type Semantics.Toggle;

   overriding procedure Begin_Update
     (Self : in out Collector; Root, Focused : Widgets.Node_Id; Whole : Boolean)
   is
      pragma Unreferenced (Root, Focused, Whole);
   begin
      Self.Nodes.Clear;
   end Begin_Update;

   overriding procedure Describe_Node
     (Self     : in out Collector;
      Id       : Widgets.Node_Id;
      Facts    : Semantics.Description;
      Bounds   : Semantics.Rectangle;
      Children : Widgets.Node_Id_Array)
   is
      pragma Unreferenced (Id, Children);
   begin
      Self.Nodes.Append (Node'(Facts => Facts, Bounds => Bounds));
   end Describe_Node;

   overriding procedure Take (Self : in out Plain; Event : Pomarine.Events.Event) is
      Handled : Boolean;
   begin
      Widgets.Dispatch (Self.Tree.all, Event, Handled);
   end Take;

   overriding procedure Settle (Self : in out Plain; Milliseconds : Natural) is
   begin
      Self.Clock := Self.Clock + Pomarine.Events.Milliseconds (Milliseconds);
      Widgets.Update (Self.Tree.all, Self.Clock);
      Widgets.Layout (Self.Tree.all, Self.Target);
   end Settle;

   procedure Open
     (Item    : in out Session;
      Tree    : aliased in out Widgets.Tree;
      Width   : Positive;
      Height  : Positive;
      Density : Float := 1.0) is
   begin
      SDL3.Initialize;
      SDL3.Windows.Renderers.Create_Offscreen
        (Item.Own.Target, Positive (Float (Width) * Density), Positive (Float (Height) * Density));
      Item.Tree := Tree'Unchecked_Access;
      Item.Own.Tree := Item.Tree;
      Item.Uses := Item.Own'Unchecked_Access;
      Widgets.Set_Density (Tree, Density);
      Widgets.Set_Clipboard (Tree, Item.Own.Board);
      Widgets.Layout (Tree, Item.Own.Target);
      Settle (Item, 0);
   end Open;

   procedure Attach
     (Item : in out Session;
      Tree : aliased in out Widgets.Tree;
      Uses : not null access Application'Class) is
   begin
      Item.Tree := Tree'Unchecked_Access;
      Item.Uses := Uses.all'Unrestricted_Access;
   end Attach;

   procedure Settle (Item : in out Session; Milliseconds : Natural := 16) is
   begin
      Settle (Item.Uses.all, Milliseconds);
   end Settle;

   --  The widgets as they are now, in Item.Heard.

   procedure Look (Item : in out Session) is
   begin
      Widgets.Describe_Changes (Item.Tree.all, Item.Heard, Whole => True);
   end Look;

   function Line (Facts : Semantics.Description) return String is
      Said : Unbounded.Unbounded_String := Unbounded.To_Unbounded_String (Semantics.Image (Facts.Kind));
   begin
      if Semantics.Is_Named (Facts) then
         Unbounded.Append (Said, " '" & Semantics.To_String (Facts.Name) & "'");
      end if;
      if Semantics.Length (Facts.Value) > 0 then
         Unbounded.Append (Said, " =" & Semantics.To_String (Facts.Value));
      end if;
      if Facts.Disabled then
         Unbounded.Append (Said, " disabled");
      end if;
      if Facts.Checked /= Semantics.Not_Toggled then
         Unbounded.Append (Said, " " & Facts.Checked'Image);
      end if;
      if Facts.Selected then
         Unbounded.Append (Said, " selected");
      end if;
      return Unbounded.To_String (Said);
   end Line;

   function Screen (Item : in out Session) return String is
      Said : Unbounded.Unbounded_String;
   begin
      Look (Item);
      for Each of Item.Heard.Nodes loop
         Unbounded.Append (Said, Line (Each.Facts) & ASCII.LF);
      end loop;
      return Unbounded.To_String (Said);
   end Screen;

   function Shows (Item : in out Session; Part : String) return Boolean is
     (Unbounded.Index (Unbounded.To_Unbounded_String (Screen (Item)), Part) > 0);

   --  The first of what was just looked at that is called Name.

   function Find
     (Item : Session; Name : String; Role : Semantics.Role; Nth : Positive) return Node_Vectors.Extended_Index is
      Seen : Natural := 0;
   begin
      for Each in 1 .. Item.Heard.Nodes.Last_Index loop
         declare
            Facts : Semantics.Description renames Item.Heard.Nodes (Each).Facts;
         begin
            if (Role = Semantics.Unknown or else Facts.Kind = Role)
              and then Semantics.Is_Named (Facts)
              and then Semantics.To_String (Facts.Name) = Name
            then
               Seen := Seen + 1;
               if Seen = Nth then
                  return Each;
               end if;
            end if;
         end;
      end loop;
      return Node_Vectors.No_Index;
   end Find;

   function Exists
     (Item : in out Session; Name : String; Role : Semantics.Role := Semantics.Unknown; Nth : Positive := 1)
      return Boolean is
   begin
      Look (Item);
      return Find (Item, Name, Role, Nth) /= Node_Vectors.No_Index;
   end Exists;

   function Is_Disabled
     (Item : in out Session; Name : String; Role : Semantics.Role := Semantics.Unknown; Nth : Positive := 1)
      return Boolean is
   begin
      Look (Item);
      return Item.Heard.Nodes (Find (Item, Name, Role, Nth)).Facts.Disabled;
   end Is_Disabled;

   function Value_Of
     (Item : in out Session; Name : String; Role : Semantics.Role := Semantics.Unknown; Nth : Positive := 1)
      return String is
   begin
      Look (Item);
      return Semantics.To_String (Item.Heard.Nodes (Find (Item, Name, Role, Nth)).Facts.Value);
   end Value_Of;

   procedure Click_At (Item : in out Session; X, Y : Float) is
   begin
      Take (Item.Uses.all, (Kind => Pomarine.Events.Mouse_Move, Mouse_X => X, Mouse_Y => Y, others => <>));
      Take (Item.Uses.all,
            (Kind => Pomarine.Events.Mouse_Down, Mouse_X => X, Mouse_Y => Y, Button => 1, Clicks => 1,
             others => <>));
      Take (Item.Uses.all,
            (Kind => Pomarine.Events.Mouse_Up, Mouse_X => X, Mouse_Y => Y, Button => 1, others => <>));
      Settle (Item);
   end Click_At;

   procedure Click_On
     (Item : in out Session; Name : String; Role : Semantics.Role := Semantics.Unknown; Nth : Positive := 1) is
   begin
      Look (Item);
      declare
         Bounds : constant Semantics.Rectangle := Item.Heard.Nodes (Find (Item, Name, Role, Nth)).Bounds;
      begin
         Click_At (Item, (Bounds.Left + Bounds.Right) / 2.0, (Bounds.Top + Bounds.Bottom) / 2.0);
      end;
   end Click_On;

   procedure Type_Text (Item : in out Session; Text : String) is
      First : Positive := Text'First;
   begin
      --  A character at a time, which is a code point of one to four bytes.
      while First <= Text'Last loop
         declare
            Last : Positive := First;
         begin
            while Last < Text'Last and then Character'Pos (Text (Last + 1)) in 16#80# .. 16#BF# loop
               Last := Last + 1;
            end loop;
            Take (Item.Uses.all, Pomarine.Events.Text_Event (Text (First .. Last)));
            First := Last + 1;
         end;
      end loop;
      Settle (Item);
   end Type_Text;

   procedure Feed (Item : in out Session; Event : Pomarine.Events.Event) is
   begin
      Take (Item.Uses.all, Event);
   end Feed;

   procedure Compose (Item : in out Session; Text : String; Cursor : Natural := Natural'Last) is
   begin
      Take (Item.Uses.all, Pomarine.Events.Editing_Event (Text, Cursor));
      Settle (Item);
   end Compose;

   procedure Press
     (Item : in out Session; Key : Pomarine.Events.Key_Code; Command : Boolean := False; Shift : Boolean := False) is
   begin
      Take (Item.Uses.all,
            (Kind => Pomarine.Events.Key_Down, Key => Key, Command => Command, Shift => Shift, others => <>));
      Settle (Item);
   end Press;

end Pomarine.Testing;
