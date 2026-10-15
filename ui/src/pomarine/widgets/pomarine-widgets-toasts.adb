with Pomarine.Boxes;
package body Pomarine.Widgets.Toasts is

   use type Semantics.Action;
   use type Semantics.Role;

   use type SDL3.Events.Event_Kind;
   use all type SDL3.Painters.Painter;

   --  In points
   Bar_Width    : constant Float := 4.0;
   Pad          : constant Float := 12.0;
   Button_High  : constant Float := 22.0;
   Button_Pad   : constant Float := 10.0;  --  at each side of its label
   Button_Inset : constant Float := 6.0;   --  from the face's right

   procedure Changed_Look (Item : in out Toast);

   procedure Changed_Look (Item : in out Toast) is
   begin
      if Is_Attached (Item) then
         Invalidate (Item);
      end if;
   end Changed_Look;

   procedure Set_Message (Item : in out Toast; Text : String) is
   begin
      if Text /= Message (Item) then
         Item.Length := Text'Length;
         Item.Text (1 .. Item.Length) := Text;
         Changed_Look (Item);
      end if;
   end Set_Message;

   function Message (Item : Toast) return String is
     (Item.Text (1 .. Item.Length));

   procedure Set_Action (Item : in out Toast; Label : String) is
   begin
      if Label /= Action (Item) then
         Item.Label_Length := Label'Length;
         Item.Label (1 .. Label'Length) := Label;
         Changed_Look (Item);
      end if;
   end Set_Action;

   function Action (Item : Toast) return String is
     (Item.Label (1 .. Item.Label_Length));

   procedure Take_Action (Item : in out Toast; Clicked : out Boolean) is
   begin
      Clicked := Item.Clicked;
      Item.Clicked := False;
   end Take_Action;

   function Face_Width (Item : Toast) return Float is
     (Width_Of (Item) - Pomarine.Boxes.Offset (Density (Item)));

   function Face_Height (Item : Toast) return Float is
     (Height_Of (Item) - Pomarine.Boxes.Offset (Density (Item)));

   procedure Button_Box (Item : Toast; Left, Top, Wide, High : out Float);
   --  Where the button is, with its shadow, in pixels: none if it has no
   --  label.

   procedure Button_Box (Item : Toast; Left, Top, Wide, High : out Float) is
      Pixels : constant Float := Density (Item);
   begin
      Wide := 0.0;
      High := Float'Rounding (Button_High * Pixels);
      if Item.Label_Length > 0 and then Text_Lines (Item) /= null then
         Wide := Float'Rounding
           (Pomarine.Line_Texts.Width
              (Text_Lines (Item).all, Action (Item), Pixels,
               Pomarine.Line_Texts.Strong)
            + (2.0 * Button_Pad + Themes.Raise_Offset) * Pixels);
      end if;
      Left := Float'Rounding
        (Left_Of (Item) + Face_Width (Item) - Button_Inset * Pixels - Wide);
      Top := Float'Rounding
        (Top_Of (Item) + (Face_Height (Item) - High) / 2.0);
   end Button_Box;

   function On_Button (Item : Toast; X, Y : Float) return Boolean is
      Left, Top, Wide, High : Float;
   begin
      Button_Box (Item, Left, Top, Wide, High);
      return Wide > 0.0
        and then X in Left .. Left + Wide and then Y in Top .. Top + High;
   end On_Button;

   overriding procedure Handle
     (Item    : in out Toast;
      Event   : SDL3.Events.Event;
      Handled : out Boolean)
   is
      Over : constant Boolean :=
        On_Button (Item, Event.Mouse_X * Density (Item),
                   Event.Mouse_Y * Density (Item));
   begin
      Handled := False;
      case Event.Kind is
         when SDL3.Events.Mouse_Move =>
            if Over /= Item.Over then
               Item.Over := Over;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Down =>
            if Event.Button = 1 and then Over then
               Item.Down := True;
               Handled := True;
               Invalidate (Item);
            end if;
         when SDL3.Events.Mouse_Up =>
            if Event.Button = 1 and then Item.Down then
               Item.Down := False;
               Item.Clicked := Over;
               if Over then
                  Notify (Item, Click);
               end if;
               Handled := True;
               Invalidate (Item);
            end if;
         when others =>
            null;
      end case;
   end Handle;

   overriding procedure Hover_Changed
     (Item : in out Toast; Hovered : Boolean) is
   begin
      if not Hovered and then Item.Over then
         Item.Over := False;
         Invalidate (Item);
      end if;
   end Hover_Changed;

   overriding procedure Draw
     (Item   : in out Toast;
      Target : SDL3.Painters.Painter'Class;
      Colors : Themes.Theme)
   is
      Pixels : constant Float := Density (Item);
      Middle : constant Float := Top_Of (Item) + Face_Height (Item) / 2.0;
      Left, Top, Wide, High : Float;
   begin
      Pomarine.Boxes.Draw
        (Target,
         (Filled   => True,
          Fill     => Themes.White,
          Bordered => True,
          Border   => Colors (Themes.Border),
          Dashed   => False,
          Shadowed => True,
          Shadow   => Colors (Themes.Drop_Shadow)),
         Left_Of (Item), Top_Of (Item), Width_Of (Item), Height_Of (Item),
         Pixels);
      Fill_Rect
        (Target, Colors (Themes.Primary), Left_Of (Item), Top_Of (Item),
         Float'Rounding (Bar_Width * Pixels), Face_Height (Item));
      if Item.Length > 0 and then Text_Lines (Item) /= null then
         Pomarine.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Colors (Themes.Foreground), Message (Item),
            Left_Of (Item) + (Bar_Width + Pad) * Pixels, Middle, Pixels);
      end if;
      Button_Box (Item, Left, Top, Wide, High);
      if Wide > 0.0 then
         declare
            Face : constant Themes.Color :=
              Colors.Face_For (Hovered => Item.Over and then not Item.Down);
         begin
            Pomarine.Boxes.Draw_Control
              (Target, Colors, Face, Colors (Themes.Border),
               (Themes.Highlight (Face), Themes.Shadow_Of (Face)),
               Left, Top, Wide, High, Pixels, Sunken => Item.Down and then Item.Over);
         end;
         Pomarine.Line_Texts.Draw
           (Text_Lines (Item).all, Target, Colors (Themes.Foreground),
            Action (Item), Left + Button_Pad * Pixels, Top + High / 2.0, Pixels,
            Pomarine.Line_Texts.Strong);
      end if;
   end Draw;

   overriding procedure Describe
     (Item  : Toast;
      Facts : in out Semantics.Description) is
   begin
      if Facts.Kind = Semantics.Unknown then
         Facts.Kind := Semantics.Status;
      end if;
      Facts.Live := True;
      Semantics.Name_As (Facts, Message (Item));
   end Describe;

   overriding function Part_Count (Item : Toast) return Natural is
     (if Item.Label_Length > 0 then 1 else 0);

   overriding procedure Describe_Part
     (Item   : Toast;
      Part   : Positive;
      Facts  : in out Semantics.Description;
      Bounds : out Semantics.Rectangle)
   is
      pragma Unreferenced (Part);
   begin
      Facts.Kind := Semantics.Button;
      Semantics.Name_As (Facts, Action (Item));
      Facts.Actions (Semantics.Click) := True;
      --  Where the button is drawn is the right end of the toast.
      Bounds := (Left => Left_Of (Item) + Width_Of (Item) / 2.0,
                 Top => Top_Of (Item),
                 Right => Left_Of (Item) + Width_Of (Item),
                 Bottom => Top_Of (Item) + Height_Of (Item));
   end Describe_Part;

   overriding procedure Perform_Part
     (Item    : in out Toast;
      Part    : Positive;
      Request : Semantics.Request;
      Done    : out Boolean)
   is
      pragma Unreferenced (Part);
   begin
      Done := Request.Doing = Semantics.Click;
      if Done then
         Item.Clicked := True;
         Notify (Item, Click);
         Invalidate (Item);
      end if;
   end Perform_Part;

end Pomarine.Widgets.Toasts;
