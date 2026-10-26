package body Pomarine.Widgets.Animations is

   use type Pomarine.Events.Milliseconds;

   function Eased (How : Easing; T : Float) return Float is
     (case How is
         when Linear      => T,
         when Ease_Out    => 1.0 - (1.0 - T) ** 3,
         when Ease_In_Out => T * T * (3.0 - 2.0 * T));
   --  How far along the way a number is, of the whole, T of the way
   --  through the time.

   procedure Start
     (Item         : in out Widget'Class;
      From, To     : Float;
      Milliseconds : Natural;
      How          : Easing := Ease_Out;
      Apply        : not null Animation_Setter)
   is
      Home : constant Tree_Access := Item.Owner;
      Mine : constant Node_Id := Id_Of (Item);
      Free : Natural := 0;
   begin
      if Home.Reduce_Motion or else Milliseconds = 0 or else From = To then
         Stop_Animations (Item);
         Apply (Item, To);
         return;
      end if;
      for K in Home.Moving'Range loop
         if Home.Moving (K).Active then
            if Home.Moving (K).Who = Mine and then Home.Moving (K).Apply = Apply then
               Free := K;
               exit;
            end if;
         elsif Free = 0 then
            Free := K;
         end if;
      end loop;
      pragma Assert (Free /= 0, "more animations than the tree can run");
      if not Home.Moving (Free).Active then
         Home.Running := Home.Running + 1;
      end if;
      Home.Moving (Free) :=
        (Active => True, Who => Mine, From => From, To => To, Start => Home.Clock,
         Length => Milliseconds, How => How, Apply => Apply);
      Apply (Item, From);
   end Start;

   procedure Stop (Item : in out Widget'Class) is
      Home : constant Tree_Access := Item.Owner;
      Mine : constant Node_Id := Id_Of (Item);
   begin
      if Home = null then
         return;
      end if;
      for Each of Home.Moving loop
         if Each.Active and then Each.Who = Mine then
            Each.Active := False;
            Home.Running := Home.Running - 1;
         end if;
      end loop;
   end Stop;

   procedure Step_Animations (Item : in out Tree; Now : Pomarine.Events.Milliseconds) is
   begin
      Item.Clock := Now;
      if Item.Running = 0 then
         return;
      end if;
      for Each of Item.Moving loop
         if Each.Active then
            declare
               Going : constant Widget_Access := Resolve (Item, Each.Who);
               Spent : constant Float :=
                 (if Now > Each.Start then Float (Now - Each.Start) else 0.0);
               T     : constant Float := Float'Min (1.0, Spent / Float (Each.Length));
            begin
               if Going = null then
                  Each.Active := False;
                  Item.Running := Item.Running - 1;
               else
                  --  The last is exact, not what the curve comes to.
                  Each.Apply
                    (Going.all,
                     (if T >= 1.0 then Each.To
                      else Each.From + (Each.To - Each.From) * Eased (Each.How, T)));
                  if T >= 1.0 then
                     Each.Active := False;
                     Item.Running := Item.Running - 1;
                  end if;
               end if;
            end;
         end if;
      end loop;
   end Step_Animations;

end Pomarine.Widgets.Animations;
