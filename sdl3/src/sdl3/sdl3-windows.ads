with System;
private with Ada.Finalization;

package SDL3.Windows is

   type Window is limited private;
   --  Destroyed automatically when it goes out of scope.

   procedure Create
     (Item         : in out Window;
      Title        : String;
      Width        : Positive;
      Height       : Positive;
      Resizable    : Boolean := False;
      High_Density : Boolean := False;
      Hidden       : Boolean := False);
   --  With High_Density the window's pixels are the display's own, not
   --  scaled up from points: see Pixel_Density. A Hidden window is not
   --  shown, but can be drawn to, as for measuring.

   function Is_Open (Item : Window) return Boolean;

   function Pixel_Density (Item : Window) return Float
   with Pre => Is_Open (Item), Post => Pixel_Density'Result >= 1.0;
   --  How many pixels of the window's drawing area there are to each
   --  point of its size: 2.0 on a Retina display, if High_Density.

   procedure Start_Text_Input (Item : Window)
   with Pre => Is_Open (Item);
   --  Have typing in the window come as Text_Input events, through the
   --  system's input methods.

   procedure Stop_Text_Input (Item : Window)
   with Pre => Is_Open (Item);
   --  Have typing in the window no longer come as Text_Input events: for a view of the system's own that is
   --  typed in, which would otherwise be given each key twice.

   procedure Set_Text_Input_Area (Item : Window; X, Y, Width, Height : Integer)
   with Pre => Is_Open (Item) and then Width >= 0 and then Height >= 0;
   --  Where the text being typed is, in points from the window's top
   --  left, so that an input method can show its choices beside it.

   procedure Set_Title (Item : Window; Title : String)
   with Pre => Is_Open (Item);

   procedure Extend_Into_Title_Bar (Item : Window)
   with Pre => Is_Open (Item);
   --  On macOS, have the window's content fill all of it, under a title
   --  bar that is transparent and shows no title (draw your own); the
   --  close, minimise and zoom buttons stay, over the top left corner.
   --  Nothing elsewhere.

   Title_Bar_Height : constant := 28.0;
   --  In points: what the content should leave clear at the top.

   procedure Set_Title_Bar_Height (Item : Window; Height, Left : Float)
   with Pre => Is_Open (Item) and then Height > 0.0 and then Left >= 0.0;
   --  On macOS, after Extend_Into_Title_Bar, centre the close, minimise and
   --  zoom buttons on a bar of the content that is Height points tall, to
   --  line up with what is drawn in it, the first Left points from the
   --  window's left edge. The system puts them back as it lays the window
   --  out, so call this again after that. Nothing elsewhere.

   procedure Set_Size (Item : Window; Width, Height : Positive)
   with Pre => Is_Open (Item);
   --  Ask for the window to be Width x Height points, and wait for it,
   --  if the system will say.

   procedure Get_Geometry (Item : Window; X, Y, Width, Height : out Integer; Found : out Boolean)
   with Pre => Is_Open (Item);
   --  Where the window is, in points from the top left of the desktop,
   --  and how big. Not Found if the system cannot say.

   procedure Set_Position (Item : Window; X, Y : Integer)
   with Pre => Is_Open (Item);
   --  Ask for the window's top left to be at X, Y.

   procedure Set_Movable (Item : Window; Movable : Boolean)
   with Pre => Is_Open (Item);
   --  On macOS, whether the system moves the window when its title bar is
   --  dragged. Off, the content has the whole top of the window, and the
   --  program moves the window itself with Set_Position. Nothing elsewhere.

   function Raw_Handle (Item : Window) return System.Address
   with Pre => Is_Open (Item);
   --  The SDL window, for SDL's own interfaces (see SDL3.Dialogs).

   function Native_Handle (Item : Window) return System.Address
   with Pre => Is_Open (Item);
   --  On macOS, the window's NSWindow, for the system's own interfaces to
   --  work on (as the accessibility adapter does). Null if there is none.

   procedure Global_Pointer (X, Y : out Float);
   --  Where the pointer is on the desktop, in points.

   procedure Zoom (Item : Window)
   with Pre => Is_Open (Item);
   --  On macOS, zoom the window as its title bar's double click does: to
   --  its largest size, or back. Nothing elsewhere.

private

   type Window is new Ada.Finalization.Limited_Controlled with record
      Handle : System.Address := System.Null_Address;
   end record;

   overriding
   procedure Finalize (Item : in out Window);

end SDL3.Windows;
