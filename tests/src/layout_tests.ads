--  Tests of how the layout is kept up to date: widgets that size
--  themselves to what they hold, and that what has not changed is not
--  placed again. See Goldens.

package Layout_Tests is

   procedure Intrinsic_Labels;
   procedure Only_What_Changed;
   procedure Lengths;
   --  What a size is: a literal, In_Points, In_Pixels, Unset; a share; Row and Column; On and Off.
   procedure Declarative_Building;
   --  Layouts.Add, Buttons.Looks, Configure and Buttons.Add.

end Layout_Tests;
