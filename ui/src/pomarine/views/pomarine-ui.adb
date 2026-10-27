with Pomarine.Icons;
with Pomarine.Line_Texts;
with Pomarine.UI.Arenas;
with Pomarine.UI.Syncing;
with Pomarine.Widgets.Panels;
with SDL3.Cursors;
with Pomarine.Widgets.Scrollers;

package body Pomarine.UI is

   package Buttons renames Pomarine.Widgets.Buttons;
   package Labels renames Pomarine.Widgets.Labels;
   package Lists renames Pomarine.Widgets.Lists;
   package Panels renames Pomarine.Widgets.Panels;
   package Checks renames Pomarine.Widgets.Checks;
   package Grips renames Pomarine.Widgets.Grips;
   package Progress_Bars renames Pomarine.Widgets.Progress_Bars;
   package Scrollers renames Pomarine.Widgets.Scrollers;
   package Switches renames Pomarine.Widgets.Switches;
   package Text_Fields renames Pomarine.Widgets.Text_Fields;

   use type Widgets.Widget_Access;
   use type Pomarine.Themes.Slot;

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
   type Check_Store is access Checks.Check;
   for Check_Store'Storage_Pool use Arenas.Pool;
   type Switch_Store is access Switches.Switch;
   for Switch_Store'Storage_Pool use Arenas.Pool;
   type Progress_Store is access Progress_Bars.Progress_Bar;
   for Progress_Store'Storage_Pool use Arenas.Pool;
   type Panel_Store is access Panels.Panel;
   for Panel_Store'Storage_Pool use Arenas.Pool;
   type Scroller_Store is access Scrollers.Scroller;
   for Scroller_Store'Storage_Pool use Arenas.Pool;
   type Root_Store is access Widgets.Bindings.Sync_Root;
   for Root_Store'Storage_Pool use Arenas.Pool;
   type Document_Store is access Docs.Document;
   for Document_Store'Storage_Pool use Arenas.Pool;
   type Node_Store is access Layout_Node;
   for Node_Store'Storage_Pool use Arenas.Pool;
   type Name_Store is access String;
   for Name_Store'Storage_Pool use Arenas.Pool;

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

      function Find (Number : Natural) return View_Ref
      is (if Number in 1 .. Natural (Items.Length) then Items (Number) else null);

      function Live return Natural
      is (Alive);

   end Registry;

   function Find_View (Number : Natural) return View_Ref
   is (Registry.Find (Number));

   function Live_Views return Natural
   is (Registry.Live);

   function Number_Of (Item : View) return Natural
   is (Item.Number);

   function Is_Mounted (Item : View) return Boolean
   is (Item.Mounted);

   --  Scopes

   function Scope_Count (Item : View'Class) return Natural
   is (Natural (Item.Scopes.Length));

   function Ref_Of (Item : View'Class; Slot : Positive) return Scope_Ref
   is ((View => Item.Number, Slot => Slot, Generation => Item.Scopes (Slot).Generation));

   function Is_Live (Item : View; Scope : Scope_Ref) return Boolean
   is (Scope.View = Item.Number
       and then Item.Number /= 0
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

   function Root_Scope (Item : View) return Scope_Ref
   is (Ref_Of (Item, Item.Root_Scope));

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
      if Item.Mounted and then not Item.Embedded then
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
     (Item : in out View; Scope : Scope_Ref; Caption : String; Kind : Buttons.Kind; Focusable : Boolean := False)
      return Button_Handle
   is (New_Button (Item, Scope, Buttons.Looks (Caption, Kind, Focusable => Focusable)));

   function New_Button
     (Item : in out View; Scope : Scope_Ref; Look : Buttons.Settings; Unheard : Boolean := False) return Button_Handle
   is
   begin
      Require_Open (Item, Scope);
      declare
         Made   : constant Button_Store := new (Item.Scopes (Scope.Slot).Arena) Buttons.Button;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
         Handle : constant Handle_Data :=
           Register (Item, Scope, Button_Control, Widget, null, True, Widgets.Click, not Unheard);
      begin
         Buttons.Configure (Made.all, Look);
         if not Unheard then
            Syncing.Install (Item, Made.all, Widgets.Click);
         end if;
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

   function Borrow_Label (Item : in out View; Scope : Scope_Ref; Existing : in out Labels.Label) return Label_Handle is
   begin
      Require_Open (Item, Scope);
      Refuse_Second_Borrow (Item, Existing'Unchecked_Access);
      return
        Label_Handle
          (Register (Item, Scope, Label_Control, Existing'Unchecked_Access, null, False, Widgets.Click, False));
   end Borrow_Label;

   function Borrow_Button (Item : in out View; Scope : Scope_Ref; Existing : in out Buttons.Button) return Button_Handle
   is
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
           Register
             (Item,
              Scope,
              Field_Control,
              Existing'Unchecked_Access,
              Backing'Unchecked_Access,
              False,
              Widgets.Submit,
              True);
      begin
         Syncing.Install (Item, Existing, Widgets.Submit);
         return Field_Handle (Handle);
      end;
   end Borrow_Field;

   function Borrow_List (Item : in out View; Scope : Scope_Ref; Existing : in out Lists.List) return List_Handle is
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

   function New_Check (Item : in out View; Scope : Scope_Ref; Caption : String; Form : Checks.Kind) return Check_Handle
   is
   begin
      Require_Open (Item, Scope);
      declare
         Made   : constant Check_Store := new (Item.Scopes (Scope.Slot).Arena) Checks.Check;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
         Handle : constant Handle_Data :=
           Register (Item, Scope, Check_Control, Widget, null, True, Widgets.Change, True);
      begin
         Checks.Set_Kind (Made.all, Form);
         Checks.Set_Label (Made.all, Caption);
         Checks.Set_Focusable (Made.all, True);
         Syncing.Install (Item, Made.all, Widgets.Change);
         return Check_Handle (Handle);
      end;
   end New_Check;

   function New_Switch (Item : in out View; Scope : Scope_Ref; Caption : String) return Switch_Handle is
   begin
      Require_Open (Item, Scope);
      declare
         Made   : constant Switch_Store := new (Item.Scopes (Scope.Slot).Arena) Switches.Switch;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
         Handle : constant Handle_Data :=
           Register (Item, Scope, Switch_Control, Widget, null, True, Widgets.Change, True);
      begin
         Switches.Set_Label (Made.all, Caption);
         Switches.Set_Focusable (Made.all, True);
         Syncing.Install (Item, Made.all, Widgets.Change);
         return Switch_Handle (Handle);
      end;
   end New_Switch;

   type Grip_Store is access Grips.Grip;
   for Grip_Store'Storage_Pool use Arenas.Pool;

   function New_Grip
     (Item : in out View; Scope : Scope_Ref; Look : Grip_Look; Unheard : Boolean := False) return Grip_Handle is
   begin
      Require_Open (Item, Scope);
      declare
         Made   : constant Grip_Store := new (Item.Scopes (Scope.Slot).Arena) Grips.Grip;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
         Handle : constant Handle_Data :=
           Register (Item, Scope, Grip_Control, Widget, null, True, Widgets.Click, not Unheard);
      begin
         if Look.Fill /= 0 then
            Grips.Set_Fill (Made.all, Look.Fill);
         end if;
         if Look.Border /= 0 then
            Grips.Set_Border (Made.all, Look.Border, Look.Dashed);
         end if;
         if Look.Shadow /= 0 then
            Grips.Set_Shadow (Made.all, Look.Shadow);
         end if;
         if Look.Hover_Fill /= 0 then
            Grips.Set_Hover_Fill (Made.all, Look.Hover_Fill);
         end if;
         if Look.Hover_Outline /= 0 then
            Grips.Set_Hover_Outline (Made.all, Look.Hover_Outline);
         end if;
         if Look.Radius > 0.0 then
            Grips.Set_Radius (Made.all, Look.Radius, Look.Round);
         end if;
         if Look.Pointer then
            Grips.Set_Wanted_Cursor (Made.all, SDL3.Cursors.Pointer);
         end if;
         if Look.Focusable then
            Grips.Set_Focusable (Made.all, True);
         end if;
         if not Unheard then
            Syncing.Install (Item, Made.all, Widgets.Click);
         end if;
         return Grip_Handle (Handle);
      end;
   end New_Grip;

   function New_Progress (Item : in out View; Scope : Scope_Ref) return Progress_Handle is
   begin
      Require_Open (Item, Scope);
      declare
         Made   : constant Progress_Store := new (Item.Scopes (Scope.Slot).Arena) Progress_Bars.Progress_Bar;
         Widget : constant Widgets.Widget_Access := Made.all'Unchecked_Access;
      begin
         return Progress_Handle (Register (Item, Scope, Progress_Control, Widget, null, True, Widgets.Click, False));
      end;
   end New_Progress;

   function Borrow_Widget
     (Item : in out View; Scope : Scope_Ref; Existing : in out Widgets.Widget'Class) return Widget_Handle is
   begin
      Require_Open (Item, Scope);
      Refuse_Second_Borrow (Item, Existing'Unchecked_Access);
      return
        Widget_Handle
          (Register (Item, Scope, Custom_Control, Existing'Unchecked_Access, null, False, Widgets.Click, False));
   end Borrow_Widget;

   --  Handles

   function Resolve (Item : View; Handle : Handle_Data; Kind : Control_Kind) return Widgets.Widget_Access is
   begin
      if Handle.View /= Item.Number
        or else Item.Number = 0
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

   procedure Require_Handle (Item : View; Handle : Handle_Data; Kind : Control_Kind) is
   begin
      if Resolve (Item, Handle, Kind) = null then
         if Handle.View /= 0 and then Handle.View /= Item.Number then
            raise Foreign_Handle with "handle of another view";
         else
            raise Stale_Handle with "handle outlived its scope";
         end if;
      end if;
   end Require_Handle;

   function Is_Live (Item : View; Handle : Label_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), Label_Control) /= null);
   function Is_Live (Item : View; Handle : Button_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), Button_Control) /= null);
   function Is_Live (Item : View; Handle : Field_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), Field_Control) /= null);
   function Is_Live (Item : View; Handle : List_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), List_Control) /= null);
   function Is_Live (Item : View; Handle : Check_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), Check_Control) /= null);
   function Is_Live (Item : View; Handle : Switch_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), Switch_Control) /= null);
   function Is_Live (Item : View; Handle : Progress_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), Progress_Control) /= null);
   function Is_Live (Item : View; Handle : Widget_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), Custom_Control) /= null);
   function Is_Live (Item : View; Handle : Grip_Handle) return Boolean
   is (Resolve (Item, Handle_Data (Handle), Grip_Control) /= null);
   function Is_Live (Item : View; Screen : Layout) return Boolean
   is (Screen.Node = null or else Is_Live (Item, Screen.Scope));

   function Widget_Of (Item : View; Handle : Label_Handle) return not null access Labels.Label is
   begin
      Require_Handle (Item, Handle_Data (Handle), Label_Control);
      return Labels.Label (Resolve (Item, Handle_Data (Handle), Label_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : Button_Handle) return not null access Buttons.Button is
   begin
      Require_Handle (Item, Handle_Data (Handle), Button_Control);
      return Buttons.Button (Resolve (Item, Handle_Data (Handle), Button_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : Field_Handle) return not null access Text_Fields.Text_Field is
   begin
      Require_Handle (Item, Handle_Data (Handle), Field_Control);
      return Text_Fields.Text_Field (Resolve (Item, Handle_Data (Handle), Field_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : List_Handle) return not null access Lists.List is
   begin
      Require_Handle (Item, Handle_Data (Handle), List_Control);
      return Lists.List (Resolve (Item, Handle_Data (Handle), List_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : Check_Handle) return not null access Checks.Check is
   begin
      Require_Handle (Item, Handle_Data (Handle), Check_Control);
      return Checks.Check (Resolve (Item, Handle_Data (Handle), Check_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : Switch_Handle) return not null access Switches.Switch is
   begin
      Require_Handle (Item, Handle_Data (Handle), Switch_Control);
      return Switches.Switch (Resolve (Item, Handle_Data (Handle), Switch_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : Progress_Handle) return not null access Progress_Bars.Progress_Bar is
   begin
      Require_Handle (Item, Handle_Data (Handle), Progress_Control);
      return Progress_Bars.Progress_Bar (Resolve (Item, Handle_Data (Handle), Progress_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Widget_Of (Item : View; Handle : Widget_Handle) return not null access Widgets.Widget'Class is
   begin
      Require_Handle (Item, Handle_Data (Handle), Custom_Control);
      return Resolve (Item, Handle_Data (Handle), Custom_Control);
   end Widget_Of;

   function Any (Item : Label_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));
   function Any (Item : Button_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));
   function Any (Item : Field_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));
   function Any (Item : List_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));
   function Any (Item : Check_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));
   function Any (Item : Switch_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));
   function Any (Item : Progress_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));
   function Any (Item : Widget_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));
   function Any (Item : Grip_Handle) return Control_Ref
   is ((Which => Handle_Data (Item)));

   function Widget_Of (Item : View; Handle : Grip_Handle) return not null access Grips.Grip is
   begin
      Require_Handle (Item, Handle_Data (Handle), Grip_Control);
      return Grips.Grip (Resolve (Item, Handle_Data (Handle), Grip_Control).all)'Unchecked_Access;
   end Widget_Of;

   function Document_Of (Item : View; Handle : Field_Handle) return Docs.Document_Access is
   begin
      Require_Handle (Item, Handle_Data (Handle), Field_Control);
      return Item.Controls (Handle.Slot).Document;
   end Document_Of;

   function Focus_Of (Item : Field_Handle) return Focus_Target
   is ((Which => Handle_Data (Item)));
   function Focus_Of (Item : Button_Handle) return Focus_Target
   is ((Which => Handle_Data (Item)));
   function Reveal_Of (Item : List_Handle) return Reveal_Target
   is ((Which => Handle_Data (Item)));

   procedure Set_Focus_Initially (Item : in out View; Target : Focus_Target) is
   begin
      if Resolve (Item, Target.Which, Field_Control) = null and then Resolve (Item, Target.Which, Button_Control) = null
      then
         Require_Handle (Item, Target.Which, Field_Control);
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

   function Control_Slots (Item : View) return Natural
   is (Natural (Item.Controls.Length));

   function Queued_Events (Item : View) return Natural
   is (Natural (Item.Pending.Length));

   --  Layouts

   function Sides_Of (Edge : Layouts.Length) return Layouts.Sides
   is ((others => Edge));

   function Described
     (Kind       : Node_Kind;
      Box        : Layouts.Style;
      Control    : Handle_Data;
      Items      : Layout_Array;
      Owner      : Natural;
      Appearance : Container_Look := Plain;
      Across     : Boolean := False) return Layout
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
           new (Home.Scopes (Home.Top_Scope).Arena) Layout_Node'
             (Count      => Items'Length,
              Kind       => Kind,
              Box        => Box,
              Control    => Control,
              Made       => null,
              Exact      => False,
              Appearance => Appearance,
              Across     => Across,
              Name       => null,
              Items      => Items);
      begin
         return (Scope => Where, Node => Made.all'Unchecked_Access);
      end;
   end Described;

   function Placed_Layout (Handle : Handle_Data; Box : Layouts.Style; Exact : Boolean := False) return Layout
   is (if Exact
       then Styled (Described (Placed, Box, Handle, [1 .. 0 => Nothing], Handle.View), Box)
       else Described (Placed, Box, Handle, [1 .. 0 => Nothing], Handle.View));

   function Box_Of
     (Grow, Shrink : Layouts.Weight; Width, Height, Margin : Layouts.Length; Align : Align_Kind) return Layouts.Style
   is ((Grow       => Grow,
        Shrink     => Shrink,
        Width      => Width,
        Height     => Height,
        Margin     => Sides_Of (Margin),
        Align_Self => Align,
        others     => <>));

   function Place
     (Item   : Label_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is;
      Exact  : Boolean := False) return Layout
   is (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align), Exact));

   function Place
     (Item   : Button_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is;
      Exact  : Boolean := False) return Layout
   is (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align), Exact));

   function Place
     (Item   : Field_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is;
      Exact  : Boolean := False) return Layout
   is (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align), Exact));

   function Place
     (Item   : List_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is;
      Exact  : Boolean := False) return Layout
   is (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align), Exact));

   function Place
     (Item   : Check_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is;
      Exact  : Boolean := False) return Layout
   is (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align), Exact));

   function Place
     (Item   : Switch_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is;
      Exact  : Boolean := False) return Layout
   is (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align), Exact));

   function Place
     (Item   : Progress_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is;
      Exact  : Boolean := False) return Layout
   is (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align), Exact));

   function Place
     (Item   : Widget_Handle;
      Grow   : Layouts.Weight := Layouts.Unchanged;
      Shrink : Layouts.Weight := Layouts.Unchanged;
      Width  : Layouts.Length := Unset;
      Height : Layouts.Length := Unset;
      Margin : Layouts.Length := Unset;
      Align  : Align_Kind := Layouts.As_Is;
      Exact  : Boolean := False) return Layout
   is (Placed_Layout (Handle_Data (Item), Box_Of (Grow, Shrink, Width, Height, Margin, Align), Exact));

   function Held_Layout
     (Handle       : Handle_Data;
      Items        : Layout_Array;
      Flow         : Layouts.Flow_Kind;
      Gap, Padding : Layouts.Length;
      Align        : Align_Kind;
      Spread       : Spread_Kind) return Layout
   is (Described
         (Held,
          (Flow => Flow, Gap => Gap, Padding => Sides_Of (Padding), Align => Align, Spread => Spread, others => <>),
          Handle,
          Items,
          Handle.View));

   function Hold
     (Item    : Widget_Handle;
      Items   : Layout_Array;
      Flow    : Layouts.Flow_Kind := Layouts.Column;
      Gap     : Layouts.Length := Unset;
      Padding : Layouts.Length := Unset;
      Align   : Align_Kind := Layouts.As_Is;
      Spread  : Spread_Kind := Layouts.As_Is) return Layout
   is (Held_Layout (Handle_Data (Item), Items, Flow, Gap, Padding, Align, Spread));

   function Hold
     (Item    : Grip_Handle;
      Items   : Layout_Array;
      Flow    : Layouts.Flow_Kind := Layouts.Column;
      Gap     : Layouts.Length := Unset;
      Padding : Layouts.Length := Unset;
      Align   : Align_Kind := Layouts.As_Is;
      Spread  : Spread_Kind := Layouts.As_Is) return Layout
   is (Held_Layout (Handle_Data (Item), Items, Flow, Gap, Padding, Align, Spread));

   function Called (Item : Layout; Name : String) return Layout is
   begin
      if Item.Node = null then
         raise Program_Error with "nothing to call " & Name;
      end if;
      declare
         Home : constant View_Ref := Find_View (Item.Scope.View);
      begin
         if Home = null or else not Is_Live (Home.all, Item.Scope) then
            raise Stale_Handle with "layout outlived its scope";
         end if;
         declare
            Arena : constant Subpools.Subpool_Handle := Home.Scopes (Item.Scope.Slot).Arena;
            Made  : constant Node_Store := new (Arena) Layout_Node'(Item.Node.all);
            Kept  : constant Name_Store := new (Arena) String'(Name);
         begin
            Made.Name := Kept.all'Unchecked_Access;
            return (Scope => Item.Scope, Node => Made.all'Unchecked_Access);
         end;
      end;
   end Called;

   function Styled (Item : Layout; Using : Layouts.Style) return Layout is
   begin
      if Item.Node = null then
         return Item;
      end if;
      declare
         Home : constant View_Ref := Find_View (Item.Scope.View);
      begin
         if Home = null or else not Is_Live (Home.all, Item.Scope) then
            raise Stale_Handle with "layout outlived its scope";
         end if;
         declare
            Box  : Layouts.Style := Using;
            Made : constant Node_Store := new (Home.Scopes (Item.Scope.Slot).Arena) Layout_Node'(Item.Node.all);
         begin
            if Item.Node.Kind in Row_Of | Column_Of | Scroll_Of | Held and then Layouts."=" (Box.Flow, Layouts.As_Is)
            then
               Box.Flow := Item.Node.Box.Flow;
            end if;
            Made.Box := Box;
            Made.Exact := True;
            return (Scope => Item.Scope, Node => Made.all'Unchecked_Access);
         end;
      end;
   end Styled;

   function Is_Embedded (Item : View) return Boolean
   is (Item.Embedded);

   function Borrowed_Before (Item : View; Existing : Widgets.Widget'Class) return Widget_Handle is
   begin
      for Slot in 1 .. Natural (Item.Controls.Length) loop
         if Item.Controls (Slot).Kind = Custom_Control
           and then Item.Controls (Slot).Widget = Existing'Unrestricted_Access
         then
            return Widget_Handle'(View => Item.Number, Slot => Slot, Generation => Item.Controls (Slot).Generation);
         end if;
      end loop;
      return Widget_Handle'(others => <>);
   end Borrowed_Before;

   function Handle_Of (Item : in out View; Existing : in out Widgets.Widget'Class) return Widget_Handle is
      Before : constant Widget_Handle := Borrowed_Before (Item, Existing);
   begin
      return
        (if Before /= Widget_Handle'(others => <>)
         then Before
         else Widget_Handle'(Borrow_Widget (Item, Root_Scope (Item), Existing)));
   end Handle_Of;

   function Put (Item : in out View; Existing : in out Widgets.Widget'Class) return Layout
   is (Place (Handle_Of (Item, Existing), Layouts.Unchanged, Layouts.Unchanged, Unset, Unset, Unset, Layouts.As_Is));

   function Put_In
     (Item     : in out View;
      Existing : in out Widgets.Widget'Class;
      Items    : Layout_Array;
      Flow     : Layouts.Flow_Kind := Layouts.Column;
      Gap      : Layouts.Length := Unset;
      Padding  : Layouts.Length := Unset;
      Align    : Align_Kind := Layouts.As_Is;
      Spread   : Spread_Kind := Layouts.As_Is) return Layout
   is (Hold (Handle_Of (Item, Existing), Items, Flow, Gap, Padding, Align, Spread));

   function Fragment (Item : View; Items : Layout_Array) return Layout
   is (Described (Siblings, (others => <>), (others => <>), Items, Item.Number));

   function Spacer (Item : View; Appearance : Container_Look := Plain) return Layout
   is (Described
         (Column_Of,
          (Flow => Layouts.Column, others => <>),
          (others => <>),
          [1 .. 0 => Nothing],
          Item.Number,
          Appearance));

   function Container
     (Kind          : Node_Kind;
      Items         : Layout_Array;
      Flow          : Layouts.Flow_Kind;
      Gap, Padding  : Layouts.Length;
      Align         : Align_Kind;
      Spread        : Spread_Kind;
      Grow          : Layouts.Weight;
      Width, Height : Layouts.Length;
      Appearance    : Container_Look := Plain;
      Across        : Boolean := False) return Layout
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
      return
        Described
          (Kind,
           (Flow    => Flow,
            Gap     => Gap,
            Padding => Sides_Of (Padding),
            Align   => Align,
            Spread  => Spread,
            Grow    => Grow,
            Width   => Width,
            Height  => Height,
            others  => <>),
           (others => <>),
           Items,
           Owner,
           Appearance,
           Across);
   end Container;

   function Row
     (Items      : Layout_Array;
      Gap        : Layouts.Length := Unset;
      Padding    : Layouts.Length := Unset;
      Align      : Align_Kind := Layouts.Center;
      Spread     : Spread_Kind := Layouts.As_Is;
      Grow       : Layouts.Weight := Layouts.Unchanged;
      Width      : Layouts.Length := Unset;
      Height     : Layouts.Length := Unset;
      Appearance : Container_Look := Plain) return Layout
   is (Container (Row_Of, Items, Layouts.Row, Gap, Padding, Align, Spread, Grow, Width, Height, Appearance));

   function Column
     (Items      : Layout_Array;
      Gap        : Layouts.Length := Unset;
      Padding    : Layouts.Length := Unset;
      Align      : Align_Kind := Layouts.As_Is;
      Spread     : Spread_Kind := Layouts.As_Is;
      Grow       : Layouts.Weight := Layouts.Unchanged;
      Width      : Layouts.Length := Unset;
      Height     : Layouts.Length := Unset;
      Appearance : Container_Look := Plain) return Layout
   is (Container (Column_Of, Items, Layouts.Column, Gap, Padding, Align, Spread, Grow, Width, Height, Appearance));

   Dialog_Bar_Height : constant Layouts.Length := 30.0;
   Dialog_Bar_Pad    : constant Layouts.Length := 8.0;
   Dialog_Close_Size : constant Layouts.Length := 18.0;
   Dialog_Close_Icon : constant Float := 11.0;

   function Close_Look return Buttons.Settings
   is (Buttons.Looks
         ("Close",
          Icon        => Pomarine.Icons.Shown (Pomarine.Icons.Close),
          Icon_Points => Dialog_Close_Icon,
          Focusable   => True));

   function Dialog
     (Title        : Label_Handle;
      Close        : Button_Handle;
      Content      : Layout_Array;
      Size         : Dialog_Size;
      Overlay_Name : String;
      Border_Name  : String) return Layout
   is
      Bar : constant Layout :=
        Styled
          (Row
             ([Place (Title, Grow => 1.0, Width => 0.0, Height => Dialog_Bar_Height, Exact => True),
               Place (Close, Width => Dialog_Close_Size, Height => Dialog_Close_Size, Shrink => 0.0, Exact => True)],
              Appearance => (Fill => Pomarine.Themes.Bar, others => <>)),
           (Flow    => Layouts.Row,
            Align   => Layouts.Center,
            Height  => Dialog_Bar_Height,
            Shrink  => 0.0,
            Padding => (Left | Right => Dialog_Bar_Pad, others => <>),
            others  => <>));

      Border : constant Layout :=
        Called
          (Styled
             (Column
                (Layout_Array'[Bar] & Content,
                 Appearance =>
                   (Fill => Pomarine.Themes.Border, Radius => Pomarine.Themes.Large_Radius, Framed => True,
                    others => <>)),
              (Flow     => Layouts.Column,
               Outlined => Layouts.On,
               Width    => Size.Width,
               Height   => Size.Height,
               others   => <>)),
           Border_Name);
   begin
      return
        Called
          (Styled
             (Column ([Border], Appearance => (Fill => Pomarine.Themes.Scrim, others => <>)),
              (Place    => Layouts.Absolute,
               Position => (others => 0.0),
               Flow     => Layouts.Column,
               Spread   => Layouts.Center,
               Align    => Layouts.Center,
               others   => <>)),
           Overlay_Name);
   end Dialog;

   function Scroll
     (Content : Layout;
      Across  : Boolean := False;
      Grow    : Layouts.Weight := Layouts.Unchanged;
      Width   : Layouts.Length := Unset;
      Height  : Layouts.Length := Unset) return Layout
   is (Container
         (Scroll_Of,
          [Content],
          Layouts.Column,
          Unset,
          Unset,
          Layouts.As_Is,
          Layouts.As_Is,
          Grow,
          Width,
          Height,
          Plain,
          Across));

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
         when Empty                                     =>
            return No_Problem;

         when Placed                                    =>
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

         when Held                                      =>
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
                  if Widgets.Is_Attached (Control.Widget.all) or else Widgets.Child_Count (Control.Widget.all) /= 0 then
                     return Attachment_Conflict;
                  end if;
               end;
            end;
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

         when Row_Of | Column_Of | Scroll_Of | Siblings =>
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

   function Check_Screen (Item : in out View; Screen : Layout; Embedded : Boolean) return Mount_Problem is
   begin
      if Item.Mounted and then not (Embedded and then Item.Embedded) then
         return Already_Mounted;
      elsif not Embedded and then Widgets.Has_Root (Item.Tree.all) then
         return Tree_Has_Root;
      elsif Screen.Node = null or else Screen.Node.Kind = Empty then
         return No_Screen;
      end if;
      Item.Epoch := Item.Epoch + 1;
      return Check_Node (Item, Screen);
   end Check_Screen;

   function Check (Item : in out View; Screen : Layout) return Mount_Problem
   is (Check_Screen (Item, Screen, Embedded => False));

   --  Mounting

   procedure Count_Panels (Part : Layout; Count : in out Natural) is
   begin
      if Part.Node /= null and then Part.Node.Kind in Row_Of | Column_Of | Scroll_Of | Held | Siblings then
         if Part.Node.Kind not in Held | Siblings then
            Count := Count + 1;
         end if;
         for Child of Part.Node.Items loop
            Count_Panels (Child, Count);
         end loop;
      end if;
   end Count_Panels;

   type Container_Info is record
      Kind   : Node_Kind := Empty;
      Across : Boolean := False;
   end record;

   type Kind_Array is array (Positive range <>) of Container_Info;

   procedure Note_Kinds (Part : Layout; Kinds : in out Kind_Array; Next : in out Natural) is
      --  The kinds of the containers, in the order Attach_Node meets them.
   begin
      if Part.Node /= null and then Part.Node.Kind in Row_Of | Column_Of | Scroll_Of | Held | Siblings then
         if Part.Node.Kind not in Held | Siblings then
            Next := Next + 1;
            Kinds (Next) := (Kind => Part.Node.Kind, Across => Part.Node.Across);
         end if;
         for Child of Part.Node.Items loop
            Note_Kinds (Child, Kinds, Next);
         end loop;
      end if;
   end Note_Kinds;

   procedure Dress (Made : in out Widgets.Widget'Class; Appearance : Container_Look) is
   begin
      if Made in Panels.Panel'Class then
         declare
            Box : Panels.Panel renames Panels.Panel (Made);
         begin
            if Appearance.Fill /= 0 then
               Panels.Set_Fill (Box, Appearance.Fill);
            end if;
            if Appearance.Border /= 0 then
               Panels.Set_Border (Box, Appearance.Border);
            end if;
            if Appearance.Shadow /= 0 then
               Panels.Set_Shadow (Box, Appearance.Shadow);
            end if;
            if Appearance.Radius > 0.0 then
               Panels.Set_Radius (Box, Appearance.Radius, Appearance.Round, Appearance.Framed);
            end if;
         end;
      end if;
   end Dress;

   function Styled (Control : Control_Record; Box : Layouts.Style) return Layouts.Style is
      Result : Layouts.Style := Box;
   begin
      case Control.Kind is
         when Button_Control                                 =>
            if not Layouts.Is_Set (Result.Width) then
               Result.Width := 80.0;
            end if;
            if not Layouts.Is_Set (Result.Height) then
               Result.Height := 32.0;
            end if;

         when Field_Control                                  =>
            if not Layouts.Is_Set (Result.Height) then
               Result.Height := 38.0;
            end if;

         when Label_Control | Check_Control | Switch_Control =>
            if not Layouts.Is_Set (Result.Height) then
               Result.Height := 24.0;
            end if;

         when Progress_Control                               =>
            if not Layouts.Is_Set (Result.Height) then
               Result.Height := 8.0;
            end if;

         when others                                         =>
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
     (Item     : in out View;
      Parent   : in out Widgets.Widget'Class;
      Part     : Layout;
      Wrapped  : Panel_Array;
      Next     : in out Natural;
      Attached : in out Natural;
      Before   : Widgets.Widget_Access := null)
   is

      procedure Put (Child : in out Widgets.Widget'Class; Box : Layouts.Style) is
      begin
         if Before = null then
            Layouts.Add (Parent, Child, Box);
         else
            Layouts.Add_Before (Parent, Child, Before.all, Box);
         end if;
      end Put;
   begin
      if Part.Node = null then
         return;
      end if;
      case Part.Node.Kind is
         when Empty                          =>
            null;

         when Placed                         =>
            declare
               Control : Control_Record renames Item.Controls (Part.Node.Control.Slot);
            begin
               Fault_Check (Item, Attached);
               Put (Control.Widget.all, (if Part.Node.Exact then Part.Node.Box else Styled (Control, Part.Node.Box)));
            end;

         when Held                           =>
            declare
               Control : Control_Record renames Item.Controls (Part.Node.Control.Slot);
            begin
               Fault_Check (Item, Attached);
               Put (Control.Widget.all, Part.Node.Box);
               Part.Node.Made := Control.Widget;
               for Child of Part.Node.Items loop
                  Attach_Node (Item, Control.Widget.all, Child, Wrapped, Next, Attached);
               end loop;
            end;

         when Siblings                       =>
            for Child of Part.Node.Items loop
               Attach_Node (Item, Parent, Child, Wrapped, Next, Attached, Before);
            end loop;

         when Row_Of | Column_Of | Scroll_Of =>
            Next := Next + 1;
            declare
               Made : constant Widgets.Widget_Access := Wrapped (Next);
            begin
               Fault_Check (Item, Attached);
               Put (Made.all, Part.Node.Box);
               Part.Node.Made := Made;
               Dress (Made.all, Part.Node.Appearance);
               for Child of Part.Node.Items loop
                  Attach_Node (Item, Made.all, Child, Wrapped, Next, Attached);
               end loop;
            end;
      end case;
      if Part.Node.Name /= null and then Part.Node.Kind in Placed | Held | Row_Of | Column_Of | Scroll_Of then
         declare
            Made : constant Widgets.Widget_Access :=
              (if Part.Node.Kind = Placed then Item.Controls (Part.Node.Control.Slot).Widget else Part.Node.Made);
         begin
            if Item.Names.Contains (Part.Node.Name.all) then
               raise Program_Error with "name used twice in a view: " & Part.Node.Name.all;
            end if;
            Item.Names.Insert (Part.Node.Name.all, Made);
         end;
      end if;
   end Attach_Node;

   procedure Make_All_Mounted (Item : in out View'Class; Slot : Positive) is
      Child : Natural := Item.Scopes (Slot).First_Child;
   begin
      if Slot /= Item.Root_Scope or else not Item.Embedded then
         Item.Scopes (Slot).State := Mounted;
      end if;
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
      Item.Names.Clear;
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
         Needed   : Natural := 0;
         Attached : Natural := 0;
         Next     : Natural := 0;
      begin
         Count_Panels (Screen, Needed);
         Item.Mount_Arena := Arenas.Make;
         declare
            Home    : constant Subpools.Subpool_Handle := Item.Mount_Arena;
            Root    : constant Root_Store := new (Home) Widgets.Bindings.Sync_Root;
            Wrapped : Panel_Array (1 .. Natural'Max (Needed, 1));
            Kinds   : Kind_Array (1 .. Natural'Max (Needed, 1));
            Filled  : Natural := 0;
            Top     : constant Boolean := Screen.Node.Kind in Row_Of | Column_Of;
         begin
            Item.Root := Root.all'Unchecked_Access;
            Note_Kinds (Screen, Kinds, Filled);
            for Number in 1 .. Needed loop
               if Kinds (Number).Kind = Scroll_Of then
                  declare
                     Made : constant Scroller_Store := new (Home) Scrollers.Scroller;
                  begin
                     Scrollers.Set_Across (Made.all, Kinds (Number).Across);
                     Wrapped (Number) := Made.all'Unchecked_Access;
                  end;
               else
                  declare
                     Made : constant Panel_Store := new (Home) Panels.Panel;
                  begin
                     Wrapped (Number) := Made.all'Unchecked_Access;
                  end;
               end if;
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

   procedure Undo_Attachments (Part : Layout; Item : in out View) is
      --  Validation established that these controls were detached before this mount. Remove only
      --  this description's attachments; previously mounted siblings stay in their parent.
   begin
      if Part.Node = null then
         return;
      end if;
      for Child of Part.Node.Items loop
         Undo_Attachments (Child, Item);
      end loop;
      if Part.Node.Kind in Placed | Held then
         declare
            Control : Control_Record renames Item.Controls (Part.Node.Control.Slot);
         begin
            if Widgets.Is_Attached (Control.Widget.all) then
               Widgets.Remove (Control.Widget.all);
            end if;
         end;
      elsif Part.Node.Kind in Row_Of | Column_Of | Scroll_Of then
         if Part.Node.Made /= null and then Widgets.Is_Attached (Part.Node.Made.all) then
            Widgets.Remove (Part.Node.Made.all);
         end if;
      end if;
      if Part.Node.Name /= null and then Item.Names.Contains (Part.Node.Name.all) then
         declare
            Mine : constant Widgets.Widget_Access :=
              (if Part.Node.Kind = Placed then Item.Controls (Part.Node.Control.Slot).Widget else Part.Node.Made);
         begin
            if Item.Names (Part.Node.Name.all) = Mine then
               Item.Names.Delete (Part.Node.Name.all);
            end if;
         end;
      end if;
      Part.Node.Made := null;
   end Undo_Attachments;

   procedure Mount_Late
     (Item : in out View; Parent : in out Widgets.Widget'Class; Screen : Layout; Before : Widgets.Widget_Access);

   procedure Mount_Into (Item : in out View; Parent : in out Widgets.Widget'Class; Screen : Layout) is
   begin
      Mount_Late (Item, Parent, Screen, null);
   end Mount_Into;

   procedure Mount_Before (Item : in out View; Before : in out Widgets.Widget'Class; Screen : Layout) is
   begin
      Mount_Late (Item, Widgets.Parent_Of (Before).all, Screen, Before'Unchecked_Access);
   end Mount_Before;

   procedure Mount_Late
     (Item : in out View; Parent : in out Widgets.Widget'Class; Screen : Layout; Before : Widgets.Widget_Access)
   is
      Problem : constant Mount_Problem := Check_Screen (Item, Screen, Embedded => True);
      Late    : constant Boolean := Item.Mounted;
      Home    : Subpools.Subpool_Handle;
   begin
      if Problem /= No_Problem then
         raise Mount_Refused with Problem'Image;
      end if;
      declare
         Needed   : Natural := 0;
         Attached : Natural := 0;
         Next     : Natural := 0;
      begin
         Count_Panels (Screen, Needed);
         Home := Arenas.Make;
         if Late then
            Item.Late_Arenas.Append (Home);
         else
            Item.Mount_Arena := Home;
         end if;
         declare
            Wrapped : Panel_Array (1 .. Natural'Max (Needed, 1));
            Kinds   : Kind_Array (1 .. Natural'Max (Needed, 1));
            Filled  : Natural := 0;
         begin
            Note_Kinds (Screen, Kinds, Filled);
            for Number in 1 .. Needed loop
               if Kinds (Number).Kind = Scroll_Of then
                  declare
                     Made : constant Scroller_Store := new (Home) Scrollers.Scroller;
                  begin
                     Scrollers.Set_Across (Made.all, Kinds (Number).Across);
                     Wrapped (Number) := Made.all'Unchecked_Access;
                  end;
               else
                  declare
                     Made : constant Panel_Store := new (Home) Panels.Panel;
                  begin
                     Wrapped (Number) := Made.all'Unchecked_Access;
                  end;
               end if;
            end loop;
            Item.Embedded := True;
            Attach_Node (Item, Parent, Screen, Wrapped, Next, Attached, Before);
            if not Late and then Screen.Node.Kind in Row_Of | Column_Of | Scroll_Of then
               Item.Screen_Top := Wrapped (1);
            end if;
            Item.Mounted := True;
            Syncing.Show_All (Item);
            if not Late and then Item.First_Focus.View /= 0 then
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
            Undo_Attachments (Screen, Item);
            if Late then
               Item.Late_Arenas.Delete_Last;
               Arenas.Destroy (Home);
            else
               Item.Mounted := False;
               Item.Embedded := False;
               Item.Screen_Top := null;
               Release_Mounted (Item);
            end if;
            raise;
      end;
      Make_All_Mounted (Item, Item.Root_Scope);
   end Mount_Late;

   procedure Observe (Item : in out View; Watching : access Observer'Class) is
   begin
      Item.Watcher := (if Watching = null then null else Watching.all'Unrestricted_Access);
   end Observe;

   procedure Use_Tags_From (Item : in out View; First : Positive) is
   begin
      Item.Next_Tag := First;
   end Use_Tags_From;

   function Owns_Tag (Item : View; Tag : Integer) return Boolean
   is (Item.Commands.Contains (Tag));

   function Command_State (Item : View; Tag : Integer; Index : Natural) return Widgets.Command_State
   is (Syncing.Validate (Item, Tag, Index));

   procedure Synchronize (Item : in out View) is
   begin
      Syncing.Synchronize (Item);
   end Synchronize;

   function Screen_Panel (Item : View) return access Widgets.Widget'Class
   is (Item.Screen_Top);

   function Has_Named (Item : View; Name : String) return Boolean
   is (Item.Names.Contains (Name));

   function Named (Item : View; Name : String) return not null access Widgets.Widget'Class
   is (Item.Names (Name));

   function Panel_Of (Item : View; Part : Layout) return access Widgets.Widget'Class
   is (if Part.Node = null or else not Is_Live (Item, Part.Scope) then null else Part.Node.Made);

   procedure Inject_Fault (Item : in out View; Placements : Natural) is
   begin
      Item.Fault_After := Placements;
   end Inject_Fault;

   --  The view's life

   overriding
   procedure Initialize (Item : in out View) is
   begin
      Item.Judge.Owner := Item'Unchecked_Access;
      Registry.Add (Item'Unchecked_Access, Item.Number);
      Item.Root_Scope := New_Scope (Item, 0, Open);
      Item.Top_Scope := Item.Root_Scope;
   end Initialize;

   overriding
   procedure Finalize (Item : in out View) is
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
         for Each of reverse Item.Late_Arenas loop
            Arenas.Destroy (Each);
         end loop;
         Item.Late_Arenas.Clear;
         Arenas.Destroy (Item.Mount_Arena);
      exception
         when others =>
            null;
            --  A finalizer that raises is worse than a leak.
      end;
      Item.Number := 0;
   end Finalize;

   overriding
   function Validate (Self : Hub; Tag : Integer; Index : Natural) return Widgets.Command_State
   is (if Self.Owner = null then Widgets.Not_Offered else Syncing.Validate (Self.Owner.all, Tag, Index));

   overriding
   procedure Sync (Self : in out Hub) is
   begin
      if Self.Owner /= null then
         Syncing.Synchronize (Self.Owner.all);
      end if;
   end Sync;

end Pomarine.UI;
