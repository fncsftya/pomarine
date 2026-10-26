with Ada.Unchecked_Conversion;
with Pomarine.Line_Texts;
with Pomarine.Widgets.Layouts;
with Pomarine.Widgets.Overlays;
with System.Storage_Elements;
package body Pomarine.Widgets.Dialogs is

   use type System.Address;

   type Dialog_Access is access all Dialog;
   function To_Dialog is new Ada.Unchecked_Conversion (System.Address, Dialog_Access);

   Line_Height   : constant Layouts.Length := 20.0;
   Button_Width  : constant Layouts.Length := 92.0;
   Button_Height : constant Layouts.Length := 32.0;

   procedure Button_Pressed
     (Self, Proc : System.Address; Source : in out Widget'Class; Event : Widget_Event);
   --  What a button says, which it was said of by Proc: the dialog says Choose, and goes.

   procedure Button_Pressed
     (Self, Proc : System.Address; Source : in out Widget'Class; Event : Widget_Event)
   is
      pragma Unreferenced (Source, Event);
      Whole : constant Dialog_Access := To_Dialog (Self);
      Which : constant Natural := Natural (System.Storage_Elements.To_Integer (Proc));
   begin
      Overlays.Dismiss (Whole.all);
      Notify (Whole.all, Choose, Row => Which);
   end Button_Pressed;

   procedure Add
     (Parent : in out Widget'Class;
      Item   : in out Dialog;
      Width  : Float := 360.0) is
   begin
      Item.Room := Width;
      Panels.Set_Fill (Panels.Panel (Item), Themes.Page);
      Panels.Set_Border (Panels.Panel (Item), Themes.Border);
      Panels.Set_Shadow (Panels.Panel (Item), Themes.Drop_Shadow);
      Panels.Set_Radius (Panels.Panel (Item), Themes.Small_Radius);
      Layouts.Add
        (Parent, Item,
         (Flow => Layouts.Column, Width => Layouts.In_Points (Width), Padding => (others => 16.0), Gap => 6.0,
          Outlined => Layouts.On, Shadowed => Layouts.On, Place => Layouts.Absolute, others => <>));
      Layouts.Add (Item, Item.Heading, (Height => 26.0, Margin => (Bottom => 4.0, others => <>), others => <>));
      Labels.Set_Style (Item.Heading, Pomarine.Line_Texts.Strong);
      for Each of Item.Lines loop
         Layouts.Add (Item, Each, (Height => Line_Height, others => <>));
         Set_Visible (Each, False);
      end loop;
      Layouts.Add
        (Item, Item.Row,
         (Flow => Layouts.Row, Height => Button_Height, Spread => Layouts.Finish, Gap => 8.0,
          Margin => (Top => 10.0, others => <>), others => <>));
      for Number in Item.Choices'Range loop
         Buttons.Add
           (Item.Row, Item.Choices (Number), Buttons.Looks ("", Focusable => True),
            (Width => Button_Width, Height => Button_Height, others => <>));
         Set_Visible (Item.Choices (Number), False);
         Set_Hook (Item.Choices (Number), Click, Button_Pressed'Access, Item'Address,
                   System.Storage_Elements.To_Address (System.Storage_Elements.Integer_Address (Number)));
      end loop;
      Set_Visible (Item, False);
   end Add;

   procedure Set_Title (Item : in out Dialog; Text : String) is
   begin
      Labels.Set_Text (Item.Heading, Text);
   end Set_Title;

   function Title (Item : Dialog) return String is (Labels.Text (Item.Heading));

   Side_Padding : constant Float := 16.0;
   --  At each side of the box, in points.

   procedure Wrap_Message (Item : in out Dialog) is
      Pixels : constant Float := Density (Item);
      Room   : constant Float := (Item.Room - 2.0 * Side_Padding) * Pixels;
      Text   : constant String := Ada.Strings.Unbounded.To_String (Item.Whole);
      Lines  : Natural := 0;
      Cut    : Boolean := False;

      function Wide (Words : String) return Float is
        (if Text_Lines (Item) /= null
         then Pomarine.Line_Texts.Width (Text_Lines (Item).all, Words, Pixels)
         else Float (Words'Length) * 8.0 * Pixels);

      procedure Put (Words : String) is
      begin
         if Lines < Max_Lines then
            Lines := Lines + 1;
            Labels.Set_Text (Item.Lines (Lines), Words);
            Set_Visible (Item.Lines (Lines), True);
         else
            Cut := True;
         end if;
      end Put;

      Line  : Ada.Strings.Unbounded.Unbounded_String;
      First : Positive := Text'First;
      Last  : Natural := Text'First - 1;

      procedure Flush is
      begin
         Put (Ada.Strings.Unbounded.To_String (Line));
         Line := Ada.Strings.Unbounded.Null_Unbounded_String;
      end Flush;

      procedure Take_Word (Word : String) is
         Both : constant String :=
           (if Ada.Strings.Unbounded.Length (Line) = 0 then Word
            else Ada.Strings.Unbounded.To_String (Line) & ' ' & Word);
      begin
         if Ada.Strings.Unbounded.Length (Line) = 0 or else Wide (Both) <= Room then
            Line := Ada.Strings.Unbounded.To_Unbounded_String (Both);
         else
            Flush;
            Line := Ada.Strings.Unbounded.To_Unbounded_String (Word);
         end if;
      end Take_Word;

      procedure Take_Paragraph (Paragraph : String) is
         Start : Positive := Paragraph'First;
      begin
         for Index in Paragraph'First .. Paragraph'Last + 1 loop
            if Index > Paragraph'Last or else Paragraph (Index) = ' ' then
               if Index > Start then
                  Take_Word (Paragraph (Start .. Index - 1));
               end if;
               Start := Index + 1;
            end if;
         end loop;
         Flush;
      end Take_Paragraph;
   begin
      for Each of Item.Lines loop
         Set_Visible (Each, False);
      end loop;
      if Text = "" then
         return;
      end if;
      for Index in Text'First .. Text'Last + 1 loop
         if Index > Text'Last or else Text (Index) = ASCII.LF then
            Last := Index - 1;
            Take_Paragraph (Text (First .. Last));
            First := Index + 1;
         end if;
      end loop;
      if Cut then
         Labels.Set_Text (Item.Lines (Max_Lines), Labels.Text (Item.Lines (Max_Lines)) & "...");
      end if;
   end Wrap_Message;

   procedure Set_Message (Item : in out Dialog; Text : String) is
   begin
      Item.Whole := Ada.Strings.Unbounded.To_Unbounded_String (Text);
      Wrap_Message (Item);
   end Set_Message;

   function Message (Item : Dialog) return String is (Ada.Strings.Unbounded.To_String (Item.Whole));

   procedure Add_Button
     (Item  : in out Dialog;
      Label : String;
      Look  : Buttons.Kind := Buttons.Normal) is
   begin
      Item.Count := Item.Count + 1;
      Buttons.Set_Label (Item.Choices (Item.Count), Label);
      Buttons.Set_Kind (Item.Choices (Item.Count), Look);
      Set_Visible (Item.Choices (Item.Count), True);
   end Add_Button;

   procedure Clear_Buttons (Item : in out Dialog) is
   begin
      for Each of Item.Choices loop
         Set_Visible (Each, False);
      end loop;
      Item.Count := 0;
      Item.Default := 0;
   end Clear_Buttons;

   function Button_Count (Item : Dialog) return Natural is (Item.Count);

   procedure Set_Default (Item : in out Dialog; Button : Natural) is
   begin
      Item.Default := Button;
   end Set_Default;

   procedure Show (Item : in out Dialog) is
   begin
      Wrap_Message (Item);
      Overlays.Present_Centered (Item);
      Focus (Item.Choices (if Item.Default = 0 then 1 else Item.Default));
   end Show;

   procedure Hide (Item : in out Dialog) is
   begin
      Overlays.Dismiss (Item);
   end Hide;

   function Is_Shown (Item : Dialog) return Boolean is (Overlays.Is_Presented (Item));

   function Answer (Event : Widget_Event) return Natural is
     (case Event.Kind is when Choose => Event.Row, when others => 0);

end Pomarine.Widgets.Dialogs;
