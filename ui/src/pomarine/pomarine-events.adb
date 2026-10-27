with SDL3.Events;

package body Pomarine.Events is

   package Raw renames SDL3.Events;

   function From_Raw (Item : Raw.Event) return Event
   is ((Kind        => Event_Kind'Val (Raw.Event_Kind'Pos (Item.Kind)),
        Time        => Milliseconds (Item.Time),
        Key         => Key_Code (Item.Key),
        Command     => Item.Command,
        Control     => Item.Control,
        Option      => Item.Option,
        Shift       => Item.Shift,
        Text        => Item.Text,
        Text_Length => Item.Text_Length,
        Cursor      => Item.Cursor,
        Button      => Item.Button,
        Clicks      => Item.Clicks,
        Left_Held   => Item.Left_Held,
        Wheel_X     => Item.Wheel_X,
        Wheel_Y     => Item.Wheel_Y,
        Scale       => Item.Scale,
        Mouse_X     => Item.Mouse_X,
        Mouse_Y     => Item.Mouse_Y));
   --  The kinds are the same, in the same order.

   function Text_Event (Text : String) return Event is
      Result : Event;
   begin
      Result := From_Raw (Raw.Text_Event (Text));
      return Result;
   end Text_Event;

   function Editing_Event (Text : String; Cursor : Natural) return Event is
      Result : Event;
   begin
      Result := From_Raw (Raw.Editing_Event (Text, Cursor));
      return Result;
   end Editing_Event;

   function System_Is_Dark return Boolean
   is (Raw.System_Is_Dark);

   function Command_Held return Boolean
   is (Raw.Command_Held);

   function Ticks return Milliseconds
   is (Milliseconds (Raw.Ticks));

   procedure Wake is
   begin
      Raw.Wake;
   end Wake;

   function Poll (Item : out Event) return Boolean is
      Next : Raw.Event;
   begin
      Item := (others => <>);
      if Raw.Poll (Next) then
         Item := From_Raw (Next);
         return True;
      end if;
      return False;
   end Poll;

   function Wait (Item : out Event; Timeout_MS : Integer := -1) return Boolean is
      Next : Raw.Event;
   begin
      Item := (others => <>);
      if Raw.Wait (Next, Timeout_MS) then
         Item := From_Raw (Next);
         return True;
      end if;
      return False;
   end Wait;

end Pomarine.Events;
