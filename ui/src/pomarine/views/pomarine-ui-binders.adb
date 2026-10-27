package body Pomarine.UI.Binders is

   procedure Attach
     (Item : in out Context; Screen : in out Pomarine.UI.View; Data : System.Address; Hooks : not null Hooks_Ref) is
   begin
      Item.Number := Number_Of (Screen);
      Item.Data := Data;
      Item.Hooks := Hooks;
      Item.Scope := Root_Scope (Screen);
   end Attach;

   function Scope_Of (Item : Context) return Pomarine.UI.Scope_Ref
   is (Item.Scope);

   function View_Number (Self : Context'Class) return Natural
   is (Self.Number);

   function View_Of (Self : Context'Class) return not null View_Ref is
      Home : constant View_Ref := Find_View (Self.Number);
   begin
      if Home = null then
         raise Stale_Handle with "view is gone";
      end if;
      return Home;
   end View_Of;

   function Is_Open (Item : Context) return Boolean is
      Home : constant View_Ref := Find_View (Item.Number);
   begin
      if Home = null or else not Is_Live (Home.all, Item.Scope) then
         return False;
      end if;
      begin
         Require_Open (Home.all, Item.Scope);
         return True;
      exception
         when Program_Error =>
            return False;
      end;
   end Is_Open;

   function Arena (Self : Context'Class) return Subpools.Subpool_Handle
   is (Arena_Of (View_Of (Self).all, Self.Scope));

   procedure Open_Under (Item : in out Context; Parent : Context'Class) is
      Home : constant not null View_Ref := View_Of (Parent);
   begin
      Item.Number := Parent.Number;
      Item.Data := Parent.Data;
      Item.Hooks := Parent.Hooks;
      Item.Scope := Open_Scope (Home.all, Parent.Scope);
   end Open_Under;

   procedure Abandon (Item : Context'Class) is
      Home : constant View_Ref := Find_View (Item.Number);
   begin
      if Home /= null then
         Abandon_Scope (Home.all, Item.Scope);
      end if;
   end Abandon;

   procedure Commit_Scope_Of (Item : Context'Class) is
      Home : constant not null View_Ref := View_Of (Item);
   begin
      Commit_Scope (Home.all, Item.Scope);
   end Commit_Scope_Of;

   procedure Describe (Item : in out Widgets.Widget'Class; Tooltip : String; Name : String := "") is
   begin
      if Tooltip /= "" then
         Widgets.Set_Tooltip (Item, Tooltip);
      end if;
      if Name /= "" then
         Widgets.Set_Accessible_Name (Item, Name);
      end if;
   end Describe;

end Pomarine.UI.Binders;
