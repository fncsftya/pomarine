with Pomarine.Line_Texts;
with Pomarine.UI.Arenas;
with Pomarine.UI.Syncing;
with Pomarine.Widgets.Panels;

package body Pomarine.UI is

   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Lists renames Pomarine.Widgets.Lists;
   package Panels renames Pomarine.Widgets.Panels;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;

   use type Widgets.Widget_Access;

   --  What is allocated in an arena. Pool-specific, at library level: the
   --  compiler sees to it that nothing allocates in an arena that outlives it.

   type Label_Store is access Labels.Label;
   for Label_Store'Storage_Pool use Arenas.Pool;
   type Button_Store is access Buttons.Button;
   for Button_Store'Storage_Pool use Arenas.Pool;
   type Field_Store is access Text_Fields.Text_Field;
   for Field_Store'Storage_Pool use Arenas.Pool;
   type List_Store is access Lists.List;
   for List_Store'Storage_Pool use Arenas.Pool;
   type Panel_Store is access Panels.Panel;
   for Panel_Store'Storage_Pool use Arenas.Pool;
   type Root_Store is access Widgets.Bindings.Sync_Root;
   for Root_Store'Storage_Pool use Arenas.Pool;
   type Document_Store is access Docs.Document;
   for Document_Store'Storage_Pool use Arenas.Pool;
   type Node_Store is access Layout_Node;
   for Node_Store'Storage_Pool use Arenas.Pool;

   --  The views that live, by number. A number is never used twice, so a
   --  handle of a view that is gone cannot meet another view.

   package Ref_Vectors is new Ada.Containers.Vectors (Positive, View_Ref);

   protected Registry is
      procedure Add (Ref : View_Ref; Number : out Natural);
      procedure Remove (Number : Natural);
      function Find (Number : Natural) return View_Ref;
      function Live return Natural;
   private
      Items : Ref_Vectors.Vector;
      Alive : Natural := 0;
   end Registry;

   protected body Registry is

      procedure Add (Ref : View_Ref; Number : out Natural) is
      begin
         Items.Append (Ref);
         Alive := Alive + 1;
         Number := Natural (Items.Length);
      end Add;

      procedure Remove (Number : Natural) is
      begin
         if Number in 1 .. Natural (Items.Length) and then Items (Number) /= null then
            Items (Number) := null;
            Alive := Alive - 1;
         end if;
      end Remove;

      function Find (Number : Natural) return View_Ref is
        (if Number in 1 .. Natural (Items.Length) then Items (Number) else null);

      function Live return Natural is (Alive);

   end Registry;

   function Find_View (Number : Natural) return View_Ref is (Registry.Find (Number));

   function Live_Views return Natural is (Registry.Live);

   function Number_Of (Item : View) return Natural is (Item.Number);

   function Is_Mounted (Item : View) return Boolean is (Item.Mounted);

   --  Scopes

   function Scope_Count (Item : View'Class) return Natural is (Natural (Item.Scopes.Length));

   function Ref_Of (Item : View'Class; Slot : Positive) return Scope_Ref is
     ((View => Item.Number, Slot => Slot, Generation => Item.Scopes (Slot).Generation));

   function Is_Live (Item : View; Scope : Scope_Ref) return Boolean is
     (Scope.View = Item.Number and then Item.Number /= 0
      and then Scope.Slot in 1 .. Scope_Count (Item)
      and then Item.Scopes (Scope.Slot).State /= Free
      and then Item.Scopes (Scope.Slot).Generation = Scope.Generation);

   procedure Require_Live (Item : View'Class; Scope : Scope_Ref) is
   begin
      if Is_Live (Item, Scope) then
         return;
      elsif Scope.View /= 0 and then Scope.View /= Item.Number then
         raise Foreign_Handle with "scope of another view";
      else
         raise Stale_Handle with "scope destroyed";
      end if;
   end Require_Live;

   procedure Require_Open (Item : View; Scope : Scope_Ref) is
   begin
      Require_Live (Item, Scope);
      if Item.Scopes (Scope.Slot).State /= Open then
         raise Program_Error with "scope is no longer open for construction";
      end if;
   end Require_Open;

   function Arena_Of (Item : View; Scope : Scope_Ref) return Subpools.Subpool_Handle is
   begin
      Require_Live (Item, Scope);
      return Item.Scopes (Scope.Slot).Arena;
   end Arena_Of;

   function Root_Scope (Item : View) return Scope_Ref is (Ref_Of (Item, Item.Root_Scope));

   function New_Scope (Item : in out View'Class; Parent : Natural; State : Scope_State) return Positive is
      Slot : Natural := Item.Free_Scope;
      Made : Subpools.Subpool_Handle;
   begin
      Made := Arenas.Make;
      if Slot /= 0 then
         Item.Free_Scope := Item.Scopes (Slot).Next_Child;
      else
         Item.Scopes.Append (Scope_Record'(others => <>));
         Slot := Natural (Item.Scopes.Length);
      end if;
      declare
         Scope : Scope_Record renames Item.Scopes (Slot);
      begin
         Scope.State := State;
         Scope.Generation := Scope.Generation + 1;
         Scope.Parent := Parent;
         Scope.First_Child := 0;
         Scope.First_Control := 0;
         Scope.First_Binding := null;
         Scope.Arena := Made;
         Scope.Next_Child := 0;
      end;
      if Parent /= 0 then
         Item.Scopes (Slot).Next_Child := Item.Scopes (Parent).First_Child;
         Item.Scopes (Parent).First_Child := Slot;
      end if;
      return Slot;
   exception
      when others =>
         Arenas.Destroy (Made);
         raise;
   end New_Scope;

   function Open_Scope (Item : in out View; Parent : Scope_Ref) return Scope_Ref is
   begin
      Require_Open (Item, Parent);
      if Item.Mounted then
         raise Program_Error with "a mounted view takes no more components";
      end if;
      declare
         Slot : constant Positive := New_Scope (Item, Parent.Slot, Open);
      begin
         Item.Top_Scope := Slot;
         return Ref_Of (Item, Slot);
      end;
   end Open_Scope;

   procedure Commit_Scope (Item : in out View; Scope : Scope_Ref) is
   begin
      Require_Open (Item, Scope);
      Item.Scopes (Scope.Slot).State := Committed;
      Item.Top_Scope := Item.Scopes (Scope.Slot).Parent;
   end Commit_Scope;

   --  Taking a scope down. Its children go first (newest first), then its
   --  bindings, then what the tree and the widgets keep of its controls, and
   --  last its arena, which finalizes what it owned.

   procedure Detach_Control (Item : in out View'Class; Slot : Positive) is
      Control : Control_Record renames Item.Controls (Slot);
      Widget  : constant Widgets.Widget_Access := Control.Widget;
   begin
      if Widget /= null then
         begin
            if Control.Heard then
               Syncing.Uninstall (Widget.all, Control.Handled);
            end if;
            Widgets.Set_Tag (Widget.all, Widgets.No_Tag);
            if Widgets.Is_Attached (Widget.all) and then Widgets.Parent_Of (Widget.all) /= null then
               Widgets.Remove (Widget.all);
            end if;
         exception
            when others =>
               null;
               --  A widget that cannot be told is going anyway.
         end;
      end if;
      Control.Kind := Free_Slot;
      Control.Widget := null;
      Control.Document := null;
      Control.Generation := Control.Generation + 1;
      Control.Next := Item.Free_Control;
      Item.Free_Control := Slot;
   end Detach_Control;

   procedure Cancel_Pending (Item : in out View'Class; Tag : Integer) is
      --  Work that was waiting for a command that is gone is not done.
      Number : Natural := Natural (Item.Pending.Length);
   begin
      while Number > 0 loop
         if Item.Pending (Number).Tag = Tag then
            Item.Pending.Delete (Number);
         end if;
         Number := Number - 1;
      end loop;
   end Cancel_Pending;

   procedure Destroy_Scope (Item : in out View'Class; Slot : Positive) is
   begin
      --  Children, newest first.
      while Item.Scopes (Slot).First_Child /= 0 loop
         Destroy_Scope (Item, Item.Scopes (Slot).First_Child);
      end loop;

      --  Bindings: told to detach, and no longer found by tag or by turn.
      declare
         Next : Binding_Ref := Item.Scopes (Slot).First_Binding;
      begin
         while Next /= null loop
            declare
               Current : constant Binding_Ref := Next;
            begin
               Next := Binding_Ref (Current.Next);
               begin
                  Detach (Current.all, Item);
               exception
                  when others =>
                     null;
               end;
               if Current.Number in 1 .. Natural (Item.Bindings.Length) then
                  Item.Bindings (Current.Number) := null;
               end if;
               if Current.Tag /= Widgets.No_Tag then
                  Item.Commands.Exclude (Current.Tag);
                  Cancel_Pending (Item, Current.Tag);
               end if;
            end;
         end loop;
         Item.Scopes (Slot).First_Binding := null;
      end;

      --  Controls: handlers, tags, places in the tree; handles made stale.
      declare
         Next : Natural := Item.Scopes (Slot).First_Control;
      begin
         while Next /= 0 loop
            declare
               Current : constant Positive := Next;
            begin
               Next := Item.Controls (Current).Next;
               Detach_Control (Item, Current);
            end;
         end loop;
         Item.Scopes (Slot).First_Control := 0;
      end;

      --  The arena finalizes the widgets, documents and records it holds.
      Arenas.Destroy (Item.Scopes (Slot).Arena);

      --  Out of the parent's list.
      declare
         Parent : constant Natural := Item.Scopes (Slot).Parent;
      begin
         if Parent /= 0 then
            if Item.Scopes (Parent).First_Child = Slot then
               Item.Scopes (Parent).First_Child := Item.Scopes (Slot).Next_Child;
            else
               declare
                  Before : Natural := Item.Scopes (Parent).First_Child;
               begin
                  while Before /= 0 and then Item.Scopes (Before).Next_Child /= Slot loop
                     Before := Item.Scopes (Before).Next_Child;
                  end loop;
                  if Before /= 0 then
                     Item.Scopes (Before).Next_Child := Item.Scopes (Slot).Next_Child;
                  end if;
               end;
            end if;
            if Item.Top_Scope = Slot then
               Item.Top_Scope := Parent;
            end if;
         end if;
      end;
      Item.Scopes (Slot).State := Free;
      Item.Scopes (Slot).Generation := Item.Scopes (Slot).Generation + 1;
      Item.Scopes (Slot).Parent := 0;
      Item.Scopes (Slot).Next_Child := Item.Free_Scope;
      Item.Free_Scope := Slot;
   end Destroy_Scope;

   procedure Abandon_Scope (Item : in out View; Scope : Scope_Ref) is
   begin
      if Is_Live (Item, Scope) and then Scope.Slot /= Item.Root_Scope then
         Destroy_Scope (Item, Scope.Slot);
      end if;
   end Abandon_Scope;

   function Live_Scopes (Item : View) return Natural is
      Count : Natural := 0;
   begin
      for Scope of Item.Scopes loop
         if Scope.State /= Free then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Live_Scopes;

   --  Controls

   function Register
     (Item   : in out View'Class;
      Scope  : Scope_Ref;
      Kind   : Control_Kind;
      Widget : Widgets.Widget_Access;
      Doc    : Docs.Document_Access;
      Owned  : Boolean;
      Event  : Widgets.Event_Kind;
      Heard  : Boolean) return Handle_Data
   is
      Slot : Natural := Item.Free_Control;
   begin
      if Slot /= 0 then
         Item.Free_Control := Item.Controls (Slot).Next;
      else
         Item.Controls.Append (Control_Record'(others => <>));
         Slot := Natural (Item.Controls.Length);
      end if;
      declare
         Control : Control_Record renames Item.Controls (Slot);
      begin
         Control.Kind := Kind;
         Control.Scope := Scope.Slot;
         Control.Widget := Widget;
         Control.Document := Doc;
         Control.Owned := Owned;
         Control.Handled := Event;
         Control.Heard := Heard;
         Control.Marked := 0;
         Control.Next := Item.Scopes (Scope.Slot).First_Control;
         Item.Scopes (Scope.Slot).First_Control := Slot;
         return (View => Item.Number, Slot => Slot, Generation => Control.Generation);
      end;
   end Register;

   function New_Label (Item : in out View; Scope : Scope_Ref) return Label_Handle is
   begin
      Require_Open (Item, Scope);
      declare
         Made   : constant Label_Store := new (Item.Scopes (Scope.Slot).Arena) Labels.Label;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
      begin
         return Label_Handle (Register (Item, Scope, Label_Control, Widget, null, True, Widgets.Click, False));
      end;
   end New_Label;

   function New_Button
     (Item : in out View; Scope : Scope_Ref; Caption : String; Kind : Buttons.Kind) return Button_Handle is
   begin
      Require_Open (Item, Scope);
      declare
         Made   : constant Button_Store := new (Item.Scopes (Scope.Slot).Arena) Buttons.Button;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
         Handle : constant Handle_Data :=
           Register (Item, Scope, Button_Control, Widget, null, True, Widgets.Click, True);
      begin
         Buttons.Configure (Made.all, Buttons.Looks (Caption, Kind));
         Syncing.Install (Item, Made.all, Widgets.Click);
         return Button_Handle (Handle);
      end;
   end New_Button;

   function New_Field (Item : in out View; Scope : Scope_Ref; Placeholder : String) return Field_Handle is
   begin
      Require_Open (Item, Scope);
      declare
         Home   : constant Subpools.Subpool_Handle := Item.Scopes (Scope.Slot).Arena;
         Doc    : constant Document_Store := new (Home) Docs.Document;
         Made   : constant Field_Store := new (Home) Text_Fields.Text_Field;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
         Handle : constant Handle_Data :=
           Register (Item, Scope, Field_Control, Widget, Doc.all'Unchecked_Access, True, Widgets.Submit, True);
      begin
         Text_Fields.Configure (Made.all, Pomarine.Line_Texts.Interface_Font, 15.0);
         Text_Fields.Attach (Made.all, Doc.all'Unchecked_Access);
         if Placeholder /= "" then
            Text_Fields.Set_Placeholder (Made.all, Placeholder);
         end if;
         Syncing.Install (Item, Made.all, Widgets.Submit);
         return Field_Handle (Handle);
      end;
   end New_Field;

   function New_List (Item : in out View; Scope : Scope_Ref) return List_Handle is
   begin
      Require_Open (Item, Scope);
      declare
         Made   : constant List_Store := new (Item.Scopes (Scope.Slot).Arena) Lists.List;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
         Handle : constant Handle_Data :=
           Register (Item, Scope, List_Control, Widget, null, True, Widgets.Choose, True);
      begin
         Syncing.Install (Item, Made.all, Widgets.Choose);
         return List_Handle (Handle);
      end;
   end New_List;

   procedure Refuse_Second_Borrow (Item : View'Class; Widget : Widgets.Widget_Access) is
   begin
      for Control of Item.Controls loop
         if Control.Kind /= Free_Slot and then Control.Widget = Widget then
            raise Program_Error with "widget is already in this view";
         end if;
      end loop;
   end Refuse_Second_Borrow;

   function Borrow_Label
     (Item : in out View; Scope : Scope_Ref; Existing : in out Labels.Label) return Label_Handle is
   begin
      Require_Open (Item, Scope);
      Refuse_Second_Borrow (Item, Existing'Unchecked_Access);
      return Label_Handle
        (Register (Item, Scope, Label_Control, Existing'Unchecked_Access, null, False, Widgets.Click, False));
   end Borrow_Label;

   function Borrow_Button
     (Item : in out View; Scope : Scope_Ref; Existing : in out Buttons.Button) return Button_Handle is
   begin
      Require_Open (Item, Scope);
      Refuse_Second_Borrow (Item, Existing'Unchecked_Access);
      declare
         Handle : constant Handle_Data :=
           Register (Item, Scope, Button_Control, Existing'Unchecked_Access, null, False, Widgets.Click, True);
      begin
         Syncing.Install (Item, Existing, Widgets.Click);
         return Button_Handle (Handle);
      end;
   end Borrow_Button;

   function Borrow_Field
     (Item     : in out View;
      Scope    : Scope_Ref;
      Existing : in out Text_Fields.Text_Field;
      Backing  : aliased in out Docs.Document) return Field_Handle is
   begin
      Require_Open (Item, Scope);
      Refuse_Second_Borrow (Item, Existing'Unchecked_Access);
      declare
         Handle : constant Handle_Data :=
           Register (Item, Scope, Field_Control, Existing'Unchecked_Access, Backing'Unchecked_Access, False,
                     Widgets.Submit, True);
      begin
         Syncing.Install (Item, Existing, Widgets.Submit);
         return Field_Handle (Handle);
      end;
   end Borrow_Field;

   function Borrow_List
     (Item : in out View; Scope : Scope_Ref; Existing : in out Lists.List) return List_Handle is
   begin
      Require_Open (Item, Scope);
      Refuse_Second_Borrow (Item, Existing'Unchecked_Access);
      declare
         Handle : constant Handle_Data :=
           Register (Item, Scope, List_Control, Existing'Unchecked_Access, null, False, Widgets.Choose, True);
      begin
         Syncing.Install (Item, Existing, Widgets.Choose);
         return List_Handle (Handle);
      end;
   end Borrow_List;

   --  Handles

   function Resolve (Item : View; Handle : Handle_Data; Kind : Control_Kind) return Widgets.Widget_Access is
   begin
      if Handle.View /= Item.Number or else Item.Number = 0
        or else Handle.Slot not in 1 .. Natural (Item.Controls.Length)
      then
         return null;
      end if;
      declare
         Control : Control_Record renames Item.Controls (Handle.Slot);
      begin
         if Control.Kind /= Kind or else Control.Generation /= Handle.Generation then
            return null;
         end if;
         return Control.Widget;
      end;
   end Resolve;

   procedure Check_Handle (Item : View; Handle : Handle_Data; Kind : Control_Kind) is
   begin
      if Resolve (Item, Handle, Kind) = null then
         if Handle.View /= 0 and then Handle.View /= Item.Number then
            raise Foreign_Handle with "handle of another view";
         else
            raise Stale_Handle with "handle outlived its scope";
         end if;
      end if;
   end Check_Handle;

   function Is_Live (Item : View; Handle : Label_Handle) return Boolean is
     (Resolve (Item, Handle_Data (Handle), Label_Control) /= null);
   function Is_Live (Item : View; Handle : Button_Handle) return Boolean is
     (Resolve (Item, Handle_Data (Handle), Button_Control) /= null);
   function Is_Live (Item : View; Handle : Field_Handle) return Boolean is
     (Resolve (Item, Handle_Data (Handle), Field_Control) /= null);
   function Is_Live (Item : View; Handle : List_Handle) return Boolean is
     (Resolve (Item, Handle_Data (Handle), List_Control) /= null);
   function Is_Live (Item : View; Screen : Layout) return Boolean is
     (Screen.Node = null or else Is_Live (Item, Screen.Scope));

   function Widget_Of (Item : View; Handle : Label_Handle) return not null access Labels.Label is
   begin
      Check_Handle (Item, Handle_Data (Handle), Label_Control);
      return Labels.Label (Resolve (Item, Handle_Data (Handle), Label_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : Button_Handle) return not null access Buttons.Button is
   begin
      Check_Handle (Item, Handle_Data (Handle), Button_Control);
      return Buttons.Button (Resolve (Item, Handle_Data (Handle), Button_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : Field_Handle) return not null access Text_Fields.Text_Field is
   begin
      Check_Handle (Item, Handle_Data (Handle), Field_Control);
      return Text_Fields.Text_Field (Resolve (Item, Handle_Data (Handle), Field_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : List_Handle) return not null access Lists.List is
   begin
      Check_Handle (Item, Handle_Data (Handle), List_Control);
      return Lists.List (Resolve (Item, Handle_Data (Handle), List_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Document_Of (Item : View; Handle : Field_Handle) return Docs.Document_Access is
   begin
      Check_Handle (Item, Handle_Data (Handle), Field_Control);
      return Item.Controls (Handle.Slot).Document;
   end Document_Of;

   function Focus_Of (Item : Field_Handle) return Focus_Target is ((Which => Handle_Data (Item)));
   function Focus_Of (Item : Button_Handle) return Focus_Target is ((Which => Handle_Data (Item)));
   function Reveal_Of (Item : List_Handle) return Reveal_Target is ((Which => Handle_Data (Item)));

   procedure Set_Focus_Initially (Item : in out View; Target : Focus_Target) is
   begin
      if Resolve (Item, Target.Which, Field_Control) = null
        and then Resolve (Item, Target.Which, Button_Control) = null
      then
         Check_Handle (Item, Target.Which, Field_Control);
      end if;
      Item.First_Focus := Target.Which;
   end Set_Focus_Initially;

   --  Bindings

   procedure Add_Binding (Item : in out View; Scope : Scope_Ref; Made : not null Binding_Ref) is
   begin
      Require_Open (Item, Scope);
      Made.Owner := Item.Number;
      Made.Scope := Scope.Slot;
      Item.Bindings.Append (Made);
      Made.Number := Natural (Item.Bindings.Length);
      Made.Next := Item.Scopes (Scope.Slot).First_Binding;
      Item.Scopes (Scope.Slot).First_Binding := Made;
      if Made.Tag /= Widgets.No_Tag then
         Item.Commands.Include (Made.Tag, Made);
      end if;
   end Add_Binding;

   function Command_Tag (Item : in out View) return Integer is
      Made : constant Positive := Item.Next_Tag;
   begin
      Item.Next_Tag := Item.Next_Tag + 1;
      return Made;
   end Command_Tag;

   function Live_Controls (Item : View) return Natural is
      Count : Natural := 0;
   begin
      for Control of Item.Controls loop
         if Control.Kind /= Free_Slot then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Live_Controls;

   function Live_Bindings (Item : View) return Natural is
      Count : Natural := 0;
   begin
      for Made of Item.Bindings loop
         if Made /= null then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Live_Bindings;

   function Control_Slots (Item : View) return Natural is (Natural (Item.Controls.Length));

   function Queued_Events (Item : View) return Natural is (Natural (Item.Pending.Length));

   --  Layouts

   function Sides_Of (Edge : Float) return Layouts.Sides is ((others => Edge));

   function Described
     (Kind    : Node_Kind;
      Box     : Layouts.Style;
      Control : Handle_Data;
      Items   : Layout_Array;
      Owner   : Natural) return Layout
   is
      Home : constant View_Ref := Find_View (Owner);
   begin
      if Home = null then
         raise Stale_Handle with "view is gone";
      end if;
      if Home.Top_Scope = 0 or else Home.Scopes (Home.Top_Scope).State = Free then
         raise Program_Error with "no scope is open for describing a layout";
      end if;
      declare
         Where : constant Scope_Ref := Ref_Of (Home.all, Home.Top_Scope);
         Made  : constant Node_Store :=
           new (Home.Scopes (Home.Top_Scope).Arena)
             Layout_Node'(Count => Items'Length, Kind => Kind, Box => Box, Control => Control,
                          Items => Items);
      begin
         return (Scope => Where, Node => Made.all'Unchecked_Access);
      end;
   end Described;

   function Placed_Layout (Handle : Handle_Data; Box : Layouts.Style) return Layout is
     (Described (Placed, Box, Handle, [1 .. 0 => Nothing], Handle.View));

   function Box_Of
     (Grow, Shrink, Width, Height, Margin : Float; Align : Align_Kind) return Layouts.Style is
     ((Grow => Grow, Shrink => Shrink, Width => Width, Height => Height, Margin => Sides_Of (Margin),
       Align_Self => Align, others => <>));

   function Place
     (Item   : Label_Handle;
      Grow   : Float := Unset;
      Shrink : Float := Unset;
      Width  : Float := Unset;
      Height : Float := Unset;
      Margin : Float := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout is
     (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align)));

   function Place
     (Item   : Button_Handle;
      Grow   : Float := Unset;
      Shrink : Float := Unset;
      Width  : Float := Unset;
      Height : Float := Unset;
      Margin : Float := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout is
     (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align)));

   function Place
     (Item   : Field_Handle;
      Grow   : Float := Unset;
      Shrink : Float := Unset;
      Width  : Float := Unset;
      Height : Float := Unset;
      Margin : Float := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout is
     (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align)));

   function Place
     (Item   : List_Handle;
      Grow   : Float := Unset;
      Shrink : Float := Unset;
      Width  : Float := Unset;
      Height : Float := Unset;
      Margin : Float := Unset;
      Align  : Align_Kind := Layouts.As_Is) return Layout is
     (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align)));

   function Container
     (Kind    : Node_Kind;
      Items   : Layout_Array;
      Flow    : Layouts.Flow_Kind;
      Gap, Padding : Float;
      Align   : Align_Kind;
      Spread  : Spread_Kind;
      Grow, Width, Height : Float) return Layout
   is
      Owner : Natural := 0;
   begin
      for Part of Items loop
         if Part.Node /= null then
            Owner := Part.Scope.View;
            exit;
         end if;
      end loop;
      if Owner = 0 then
         return Nothing;
      end if;
      return Described
        (Kind, (Flow => Flow, Gap => Gap, Padding => Sides_Of (Padding), Align => Align, Spread => Spread,
                Grow => Grow, Width => Width, Height => Height, others => <>),
         (others => <>), Items, Owner);
   end Container;

   function Row
     (Items   : Layout_Array;
      Gap     : Float := Unset;
      Padding : Float := Unset;
      Align   : Align_Kind := Layouts.Center;
      Spread  : Spread_Kind := Layouts.As_Is;
      Grow    : Float := Unset;
      Width   : Float := Unset;
      Height  : Float := Unset) return Layout is
     (Container (Row_Of, Items, Layouts.Row, Gap, Padding, Align, Spread, Grow, Width, Height));

   function Column
     (Items   : Layout_Array;
      Gap     : Float := Unset;
      Padding : Float := Unset;
      Align   : Align_Kind := Layouts.As_Is;
      Spread  : Spread_Kind := Layouts.As_Is;
      Grow    : Float := Unset;
      Width   : Float := Unset;
      Height  : Float := Unset) return Layout is
     (Container (Column_Of, Items, Layouts.Column, Gap, Padding, Align, Spread, Grow, Width, Height));

   --  Checking a screen. Marks tell a control placed twice from a layout
   --  used twice.

   function Check_Node (Item : in out View'Class; Part : Layout) return Mount_Problem is
   begin
      if Part.Node = null then
         return No_Problem;
      elsif Part.Scope.View /= Item.Number then
         return Foreign_Layout;
      elsif not Is_Live (Item, Part.Scope) then
         return Stale_Layout;
      end if;
      case Part.Node.Kind is
         when Empty =>
            return No_Problem;
         when Placed =>
            declare
               Handle : Handle_Data renames Part.Node.Control;
            begin
               if Handle.View /= Item.Number then
                  return Foreign_Layout;
               elsif Handle.Slot not in 1 .. Natural (Item.Controls.Length)
                 or else Item.Controls (Handle.Slot).Kind = Free_Slot
                 or else Item.Controls (Handle.Slot).Generation /= Handle.Generation
               then
                  return Stale_Control;
               end if;
               declare
                  Control : Control_Record renames Item.Controls (Handle.Slot);
               begin
                  if Control.Marked = Item.Epoch then
                     return Duplicate_Placement;
                  end if;
                  Control.Marked := Item.Epoch;
                  if Widgets.Is_Attached (Control.Widget.all) then
                     return Attachment_Conflict;
                  end if;
               end;
               return No_Problem;
            end;
         when Row_Of | Column_Of =>
            for Child of Part.Node.Items loop
               declare
                  Problem : constant Mount_Problem := Check_Node (Item, Child);
               begin
                  if Problem /= No_Problem then
                     return Problem;
                  end if;
               end;
            end loop;
            return No_Problem;
      end case;
   end Check_Node;

   function Check (Item : in out View; Screen : Layout) return Mount_Problem is
   begin
      if Item.Mounted then
         return Already_Mounted;
      elsif Widgets.Has_Root (Item.Tree.all) then
         return Tree_Has_Root;
      elsif Screen.Node = null or else Screen.Node.Kind = Empty then
         return No_Screen;
      end if;
      Item.Epoch := Item.Epoch + 1;
      return Check_Node (Item, Screen);
   end Check;

   --  Mounting

   procedure Count_Panels (Part : Layout; Count : in out Natural) is
   begin
      if Part.Node /= null and then Part.Node.Kind in Row_Of | Column_Of then
         Count := Count + 1;
         for Child of Part.Node.Items loop
            Count_Panels (Child, Count);
         end loop;
      end if;
   end Count_Panels;

   function Styled (Control : Control_Record; Box : Layouts.Style) return Layouts.Style is
      Result : Layouts.Style := Box;
   begin
      case Control.Kind is
         when Button_Control =>
            if Result.Width = Unset then
               Result.Width := 80.0;
            end if;
            if Result.Height = Unset then
               Result.Height := 32.0;
            end if;
         when Field_Control =>
            if Result.Height = Unset then
               Result.Height := 38.0;
            end if;
         when Label_Control =>
            if Result.Height = Unset then
               Result.Height := 24.0;
            end if;
         when others =>
            null;
      end case;
      return Result;
   end Styled;

   procedure Fault_Check (Item : in out View'Class; Count : in out Natural) is
   begin
      if Item.Fault_After >= 0 and then Count = Item.Fault_After then
         Item.Fault_After := -1;
         raise Program_Error with "injected fault";
      end if;
      Count := Count + 1;
   end Fault_Check;

   type Panel_Array is array (Positive range <>) of Widgets.Widget_Access;

   procedure Attach_Node
     (Item   : in out View;
      Parent : in out Widgets.Widget'Class;
      Part   : Layout;
      Wrapped : Panel_Array;
      Next   : in out Natural;
      Attached : in out Natural) is
   begin
      if Part.Node = null then
         return;
      end if;
      case Part.Node.Kind is
         when Empty =>
            null;
         when Placed =>
            declare
               Control : Control_Record renames Item.Controls (Part.Node.Control.Slot);
            begin
               Fault_Check (Item, Attached);
               Layouts.Add (Parent, Control.Widget.all, Styled (Control, Part.Node.Box));
            end;
         when Row_Of | Column_Of =>
            Next := Next + 1;
            declare
               Made : constant Widgets.Widget_Access := Wrapped (Next);
            begin
               Fault_Check (Item, Attached);
               Layouts.Add (Parent, Made.all, Part.Node.Box);
               for Child of Part.Node.Items loop
                  Attach_Node (Item, Made.all, Child, Wrapped, Next, Attached);
               end loop;
            end;
      end case;
   end Attach_Node;

   procedure Make_All_Mounted (Item : in out View'Class; Slot : Positive) is
      Child : Natural := Item.Scopes (Slot).First_Child;
   begin
      Item.Scopes (Slot).State := Mounted;
      while Child /= 0 loop
         Make_All_Mounted (Item, Child);
         Child := Item.Scopes (Child).Next_Child;
      end loop;
   end Make_All_Mounted;

   procedure Release_Mounted (Item : in out View'Class) is
   begin
      --  Out of the tree first, so that nothing is told of widgets going.
      if Item.Judging then
         Widgets.Set_Validator (Item.Tree.all, Widgets.Command_Validator'(null));
         Item.Judging := False;
      end if;
      Item.Root := null;
      Arenas.Destroy (Item.Mount_Arena);
   end Release_Mounted;

   procedure Mount (Item : in out View; Screen : Layout) is
      Problem : constant Mount_Problem := Check (Item, Screen);
   begin
      if Problem /= No_Problem then
         raise Mount_Refused with Problem'Image;
      end if;

      --  Prepare: everything that can fail for want of storage, before the
      --  tree is touched.
      declare
         Needed : Natural := 0;
         Attached : Natural := 0;
         Next   : Natural := 0;
      begin
         Count_Panels (Screen, Needed);
         Item.Mount_Arena := Arenas.Make;
         declare
            Home   : constant Subpools.Subpool_Handle := Item.Mount_Arena;
            Root   : constant Root_Store := new (Home) Widgets.Bindings.Sync_Root;
            Wrapped : Panel_Array (1 .. Natural'Max (Needed, 1));
            Top    : constant Boolean := Screen.Node.Kind in Row_Of | Column_Of;
         begin
            Item.Root := Root.all'Unchecked_Access;
            for Number in 1 .. Needed loop
               declare
                  Made : constant Panel_Store := new (Home) Panels.Panel;
               begin
                  Wrapped (Number) := Made.all'Unchecked_Access;
               end;
            end loop;

            --  Apply. The root takes the screen's own box when the screen is a container
            --  (its panel is the root's).
            Widgets.Bindings.Set_Owner (Item.Root.all, Item.Judge'Unchecked_Access);
            Widgets.Set_Root (Item.Tree.all, Item.Root.all);
            Widgets.Set_Validator (Item.Tree.all, Item.Judge'Unchecked_Access);
            Item.Judging := True;
            if Top then
               Layouts.Set_Layout (Item.Root.all, Screen.Node.Box);
               Next := 1;
               for Child of Screen.Node.Items loop
                  Attach_Node (Item, Item.Root.all, Child, Wrapped, Next, Attached);
               end loop;
            else
               Layouts.Set_Layout (Item.Root.all, (Flow => Layouts.Column, others => <>));
               Attach_Node (Item, Item.Root.all, Screen, Wrapped, Next, Attached);
            end if;

            Item.Mounted := True;
            Syncing.Show_All (Item);
            if Item.First_Focus.View /= 0 then
               declare
                  Target : Widgets.Widget_Access := Resolve (Item, Item.First_Focus, Field_Control);
               begin
                  if Target = null then
                     Target := Resolve (Item, Item.First_Focus, Button_Control);
                  end if;
                  if Target /= null then
                     Widgets.Focus (Target.all);
                  end if;
               end;
            end if;
         end;
      exception
         when others =>
            Item.Mounted := False;
            Release_Mounted (Item);
            raise;
      end;
      Make_All_Mounted (Item, Item.Root_Scope);
   end Mount;

   procedure Inject_Fault (Item : in out View; Placements : Natural) is
   begin
      Item.Fault_After := Placements;
   end Inject_Fault;

   --  The view's life

   overriding procedure Initialize (Item : in out View) is
   begin
      Item.Judge.Owner := Item'Unchecked_Access;
      Registry.Add (Item'Unchecked_Access, Item.Number);
      Item.Root_Scope := New_Scope (Item, 0, Open);
      Item.Top_Scope := Item.Root_Scope;
   end Initialize;

   overriding procedure Finalize (Item : in out View) is
   begin
      if Item.Number = 0 then
         return;
      end if;
      Item.Tearing_Down := True;
      Registry.Remove (Item.Number);
      begin
         Item.Mounted := False;
         if Item.Judging then
            Widgets.Set_Validator (Item.Tree.all, Widgets.Command_Validator'(null));
            Item.Judging := False;
         end if;
         if Item.Root_Scope /= 0 and then Item.Scopes (Item.Root_Scope).State /= Free then
            Destroy_Scope (Item, Item.Root_Scope);
         end if;
         Item.Root := null;
         Arenas.Destroy (Item.Mount_Arena);
      exception
         when others =>
            null;
            --  A finalizer that raises is worse than a leak.
      end;
      Item.Number := 0;
   end Finalize;

   overriding function Validate (Self : Hub; Tag : Integer; Index : Natural) return Widgets.Command_State is
     (if Self.Owner = null then Widgets.Not_Offered else Syncing.Validate (Self.Owner.all, Tag, Index));

   overriding procedure Sync (Self : in out Hub) is
   begin
      if Self.Owner /= null then
         Syncing.Synchronize (Self.Owner.all);
      end if;
   end Sync;

end Pomarine.UI;
