--  The tree's running animations (Pomarine.Widgets.Animate): start, stop and step them with the clock.
--  A private child of Pomarine.Widgets: its operations are the parts of that package's body that are not
--  its own interface, and are called from it.
private package Pomarine.Widgets.Animations is

   function Eased (How : Easing; T : Float) return Float;

   procedure Start
     (Item         : in out Widget'Class;
      From, To     : Float;
      Milliseconds : Natural;
      How          : Easing := Ease_Out;
      Apply        : not null Animation_Setter);

   procedure Stop (Item : in out Widget'Class);

   procedure Step_Animations (Item : in out Tree; Now : Pomarine.Events.Milliseconds);

end Pomarine.Widgets.Animations;
