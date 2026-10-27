with Ada.Strings.Fixed;
with Pomarine.Text_Areas;
with Pomarine.Widgets.Editors;

package body Pomarine.Widgets.Number_Fields is
   use type Pomarine.Events.Event_Kind;
   use type Pomarine.Events.Key_Code;

   function Parse (Text : String; Result : out Integer) return Boolean is
      First    : Integer := Text'First;
      Negative : Boolean := False;
      Acc      : Integer := 0;
      Limit    : Integer := -Integer'Last;
   begin
      Result := 0;
      if Text'Length = 0 then
         return False;
      end if;
      if Text (First) in '+' | '-' then
         if Text'Length = 1 then
            return False;
         end if;
         Negative := Text (First) = '-';
         First := First + 1;
      end if;
      if First > Text'Last then
         return False;
      end if;
      if Negative then
         Limit := Integer'First;
      end if;
      --  Accumulate negatively so Integer'First is representable without negating it.
      for Index in First .. Text'Last loop
         if Text (Index) not in '0' .. '9' then
            return False;
         end if;
         declare
            Digit : constant Integer := Character'Pos (Text (Index)) - Character'Pos ('0');
         begin
            if Acc < Limit / 10 or else (Acc = Limit / 10 and then Digit > -(Limit rem 10)) then
               return False;
            end if;
            Acc := Acc * 10 - Digit;
         end;
      end loop;
      Result := (if Negative then Acc else -Acc);
      return True;
   end Parse;

   function Valid (Text : String; Min : Integer; Max : Integer) return Boolean is
      Parsed : Integer;
   begin
      return Parse (Text, Parsed) and then Parsed in Min .. Max;
   end Valid;

   function Minimum (Item : Number_Field) return Integer
   is (Item.Low);
   function Maximum (Item : Number_Field) return Integer
   is (Item.High);
   function Value (Item : Number_Field) return Integer
   is (Item.Current);
   function Draft (Item : Number_Field) return String
   is (Texts.Documents.Whole (Item.Doc));
   function Can_Commit (Item : Number_Field) return Boolean
   is (Is_Configured (Item)
       and then Is_Enabled (Item)
       and then Can_Edit (Item)
       and then Valid (Draft (Item), Item.Low, Item.High));

   procedure Restore (Item : in out Number_Field) is
      Text : constant String := Ada.Strings.Fixed.Trim (Integer'Image (Item.Current), Ada.Strings.Left);
   begin
      if Draft (Item) = Text and then not Text_Areas.Is_Composing (Area (Item).all) then
         Set_Invalid (Item, False);
         return;
      end if;
      Texts.Documents.Load (Item.Doc, Text);
      Attach (Item, Item.Doc'Unchecked_Access);
      Text_Areas.Select_Range (Area (Item).all, (1, Text'Length + 1), (1, Text'Length + 1));
      Set_Invalid (Item, False);
      if Is_Attached (Item) then
         Invalidate (Item);
         Content_Changed (Item);
      end if;
   end Restore;

   overriding
   procedure Configure (Item : in out Number_Field; Family : String; Size : Float) is
   begin
      Configure (Item, Family, Size, Integer'First, Integer'Last, 0);
   end Configure;

   procedure Configure
     (Item : in out Number_Field; Family : String; Size : Float; Min : Integer; Max : Integer; Start : Integer := 0) is
   begin
      Text_Fields.Configure (Text_Fields.Text_Field (Item), Family, Size);
      Item.Low := Min;
      Item.High := Max;
      Item.Current := Start;
      Attach (Item, Item.Doc'Unchecked_Access);
      Restore (Item);
   end Configure;

   procedure Set_Value (Item : in out Number_Field; To : Integer) is
   begin
      Item.Current := To;
      Restore (Item);
   end Set_Value;

   procedure Set_Range (Item : in out Number_Field; Min, Max : Integer) is
   begin
      Item.Low := Min;
      Item.High := Max;
      Set_Value (Item, Integer'Max (Min, Integer'Min (Max, Item.Current)));
   end Set_Range;

   procedure Commit (Item : in out Number_Field) is
      Parsed : Integer;
      Good   : constant Boolean := Parse (Draft (Item), Parsed);
   begin
      pragma Assert (Good and then Parsed in Item.Low .. Item.High);
      if Parsed /= Item.Current then
         Item.Current := Parsed;
         Notify (Item, Change);
      end if;
      Set_Invalid (Item, False);
   end Commit;

   overriding
   procedure Handle (Item : in out Number_Field; Event : Pomarine.Events.Event; Handled : out Boolean) is
   begin
      if Has_Focus (Item)
        and then Can_Edit (Item)
        and then Is_Enabled (Item)
        and then Event.Kind = Pomarine.Events.Key_Down
        and then Event.Key in Pomarine.Events.Key_Return | Pomarine.Events.Key_Escape
      then
         if Event.Key = Pomarine.Events.Key_Escape then
            Restore (Item);
         elsif Can_Commit (Item) then
            Commit (Item);
            Notify (Item, Submit);
         else
            Set_Invalid (Item, True);
         end if;
         Handled := True;
      else
         Editors.Handle (Editors.Editor (Item), Event, Handled);
         if Is_Configured (Item) and then not Text_Areas.Is_Composing (Area (Item).all) then
            Set_Invalid (Item, not Valid (Draft (Item), Item.Low, Item.High));
         end if;
      end if;
   end Handle;

   overriding
   procedure Update (Item : in out Number_Field; Now : Pomarine.Events.Milliseconds) is
   begin
      Editors.Update (Editors.Editor (Item), Now);
      if Is_Configured (Item) and then not Text_Areas.Is_Composing (Area (Item).all) then
         Set_Invalid (Item, not Valid (Draft (Item), Item.Low, Item.High));
      end if;
   end Update;

   overriding
   procedure Focus_Changed (Item : in out Number_Field; Focused : Boolean) is
   begin
      if not Focused and then Is_Configured (Item) then
         if Can_Commit (Item) then
            Commit (Item);
         else
            Set_Invalid (Item, not Valid (Draft (Item), Item.Low, Item.High));
         end if;
      end if;
      Editors.Focus_Changed (Editors.Editor (Item), Focused);
   end Focus_Changed;
end Pomarine.Widgets.Number_Fields;
