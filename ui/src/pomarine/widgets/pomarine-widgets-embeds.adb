package body Pomarine.Widgets.Embeds is

   use type Semantics.Role;
   use type Overlays.Area;

   function Union (A, B : Overlays.Area) return Overlays.Area;
   --  The smallest area that holds both; the other if one is empty.

   procedure Tell_Host (Item : in out Embed; Hole : Overlays.Area := (others => <>));
   --  Say where the view is, whether it shows and where it has a hole, if that is not what the host was last told.

   function Union (A, B : Overlays.Area) return Overlays.Area is
      Left   : Float;
      Top    : Float;
      Right  : Float;
      Bottom : Float;
   begin
      if A.Wide <= 0.0 or else A.High <= 0.0 then
         return B;
      elsif B.Wide <= 0.0 or else B.High <= 0.0 then
         return A;
      end if;
      Left := Float'Min (A.Left, B.Left);
      Top := Float'Min (A.Top, B.Top);
      Right := Float'Max (A.Left + A.Wide, B.Left + B.Wide);
      Bottom := Float'Max (A.Top + A.High, B.Top + B.High);
      return (Left => Left, Top => Top, Wide => Right - Left, High => Bottom - Top);
   end Union;

   procedure Set_Host (Item : in out Embed; To : Host_Access) is
   begin
      Item.View := To;
      Item.Told := False;
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Set_Host;

   function Has_Host (Item : Embed) return Boolean
   is (Item.View /= null);

   procedure Set_Covered (Item : in out Embed; To : Boolean) is
   begin
      Item.Covered := To;
   end Set_Covered;

   function Is_Covered (Item : Embed) return Boolean
   is (Item.Covered);

   procedure Set_Cut_Out (Item : in out Embed; Over : Widget'Class) is
   begin
      Item.Cut_Id := Id_Of (Over);
   end Set_Cut_Out;

   procedure Clear_Cut_Out (Item : in out Embed) is
   begin
      Item.Cut_Id := No_Node;
   end Clear_Cut_Out;

   function Is_Showing_View (Item : Embed) return Boolean
   is (Item.Showing);

   procedure Tell_Host (Item : in out Embed; Hole : Overlays.Area := (others => <>)) is
      Scale : constant Float := Density (Item);
      Left  : constant Float := Item.Left / Scale;
      Top   : constant Float := Item.Top / Scale;
      Wide  : constant Float := Item.Wide / Scale;
      High  : constant Float := Item.High / Scale;
      Cut   : constant Overlays.Area :=
        (Left => Hole.Left / Scale, Top => Hole.Top / Scale, Wide => Hole.Wide / Scale, High => Hole.High / Scale);
      Moved : Boolean := False;
   begin
      if Item.View = null then
         return;
      end if;
      if not Item.Told
        or else Left /= Item.Told_Left
        or else Top /= Item.Told_Top
        or else Wide /= Item.Told_Wide
        or else High /= Item.Told_High
        or else Item.Showing /= Item.Told_Showing
      then
         Item.View.Place (Left, Top, Wide, High, Item.Showing);
         Item.Told := True;
         Item.Told_Left := Left;
         Item.Told_Top := Top;
         Item.Told_Wide := Wide;
         Item.Told_High := High;
         Item.Told_Showing := Item.Showing;
         Moved := True;
      end if;
      --  The hole is kept by where the view is, so it is told again when the view is moved.
      if Cut /= Item.Told_Cut or else (Moved and then Cut.Wide > 0.0) then
         Item.View.Cut_Out (Cut.Left, Cut.Top, Cut.Wide, Cut.High);
         Item.Told_Cut := Cut;
      end if;
   end Tell_Host;

   overriding
   procedure Placed (Item : in out Embed; Left, Top, Width, Height : Float) is
   begin
      Item.Left := Left;
      Item.Top := Top;
      Item.Wide := Width;
      Item.High := Height;
      Tell_Host (Item);
   end Placed;

   overriding
   procedure Draw (Item : in out Embed; Target : SDL3.Painters.Painter'Class; Colors : Themes.Theme) is
   begin
      --  What shows while the view does not (an overlay is over it): the page's place.
      SDL3.Painters.Fill_Rect
        (Target, Colors (Themes.Page), Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item));
   end Draw;

   overriding
   procedure Hidden (Item : in out Embed) is
   begin
      Item.Showing := False;
      if Item.View /= null then
         Item.View.Give_Keyboard (False);
      end if;
      Tell_Host (Item);
   end Hidden;

   overriding
   procedure Update (Item : in out Embed; Now : Pomarine.Events.Milliseconds) is
      pragma Unreferenced (Now);
      Show  : Boolean;
      Hole  : Overlays.Area;
      Modal : Boolean;
   begin
      if Item.View = null or else not Is_Attached (Item) then
         return;
      end if;
      Overlays.Overlap
        (Tree_Of (Item).all, (Left => Item.Left, Top => Item.Top, Wide => Item.Wide, High => Item.High), Hole, Modal);
      if Is_Live (Tree_Of (Item).all, Item.Cut_Id) then
         declare
            Box : Spot renames Tree_Of (Item).Nodes.Spot (Item.Cut_Id.Slot);
         begin
            if Box.Visible and then Box.Wide > 0.0 and then Box.High > 0.0 then
               Hole := Union (Hole, (Left => Box.Left, Top => Box.Top, Wide => Box.Wide, High => Box.High));
            end if;
         end;
      end if;
      Show := Is_Showing (Item) and then not Item.Covered and then not Modal;
      if Show /= Item.Showing then
         Item.Showing := Show;
         if not Show and then Has_Focus (Item) then
            Release_Focus (Item);
         end if;
      end if;
      Tell_Host (Item, (if Show then Hole else (others => <>)));
      if Show then
         if Item.View.Has_Keyboard then
            if not Has_Focus (Item) then
               Focus (Item);
            end if;
         end if;
         declare
            Which : constant Natural := Item.View.Shortcut;
         begin
            if Which /= 0 then
               Item.View.Give_Keyboard (False);
               Post (Item, Item.Shortcut_Hook, Which, 0);
            end if;
         end;
      end if;
   end Update;

   overriding
   function Until_Update (Item : Embed) return Integer
   is (if Item.View /= null and then Is_Attached (Item) then Poll_Period else -1);

   overriding
   function Is_Focusable (Item : Embed) return Boolean
   is (Item.View /= null);

   overriding
   procedure Focus_Changed (Item : in out Embed; Focused : Boolean) is
   begin
      if Item.View /= null then
         Item.View.Give_Keyboard (Focused and then Item.Showing);
      end if;
   end Focus_Changed;

   overriding
   procedure Describe (Item : Embed; Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Group;
      end if;
   end Describe;

end Pomarine.Widgets.Embeds;
