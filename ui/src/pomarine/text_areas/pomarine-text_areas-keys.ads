with Pomarine.Clipboards;
with Pomarine.Events;

--  What the keys do.
private package Pomarine.Text_Areas.Keys is

   procedure Handle_Key
     (Item    : in out Text_Area;
      Event   : Events.Event;
      Board   : in out Clipboards.Clipboard'Class;
      Handled : out Boolean);

end Pomarine.Text_Areas.Keys;
