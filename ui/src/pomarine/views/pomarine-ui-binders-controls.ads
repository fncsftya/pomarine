with Pomarine.Line_Texts;
with Pomarine.Themes;
with Pomarine.Widgets.Buttons;
with Pomarine.Widgets.Checks;
with Pomarine.Widgets.Frames;
with Pomarine.Widgets.Labels;
with Pomarine.Widgets.Lists;
with Pomarine.Widgets.Sliders;
with Pomarine.Widgets.Text_Fields;
with Texts.Documents;

--  The controls and bindings that Pomarine.UI.Contexts makes, typed by the adapters of Pomarine.UI.Binders. They are
--  here, not beside Context, so that the calls of an instance (Ctx.Button ...) do not find them as well.

package Pomarine.UI.Binders.Controls is

   --  Controls made one at a time

   function Label
     (Self  : Context'Class;
      Text  : not null Text_Adapter_Ref;
      Index : Natural;
      Style : Pomarine.Line_Texts.Style;
      Ink   : Pomarine.Themes.Slot) return Pomarine.UI.Label_Handle;

   function Label
     (Self    : Context'Class;
      Caption : String;
      Style   : Pomarine.Line_Texts.Style;
      Ink     : Pomarine.Themes.Slot) return Pomarine.UI.Label_Handle;

   function Button
     (Self      : Context'Class;
      Caption   : String;
      Which     : Natural;
      Look      : Pomarine.Widgets.Buttons.Kind;
      Index     : Natural;
      Focusable : Boolean) return Pomarine.UI.Button_Handle;

   function Button
     (Self    : Context'Class;
      Caption : String;
      Action  : not null Action_Adapter_Ref;
      Look    : Pomarine.Widgets.Buttons.Kind;
      Index   : Natural) return Pomarine.UI.Button_Handle;

   function Button
     (Self    : Context'Class;
      Look    : Pomarine.Widgets.Buttons.Settings;
      Which   : Natural;
      Index   : Natural;
      Reflect : Boolean) return Pomarine.UI.Button_Handle;

   function Grip
     (Self  : Context'Class;
      Look  : Pomarine.UI.Grip_Look;
      Which : Natural;
      Index : Natural;
      Name  : String) return Pomarine.UI.Grip_Handle;

   function Plain_Grip (Self : Context'Class; Look : Pomarine.UI.Grip_Look) return Pomarine.UI.Grip_Handle;

   function Plain_Button
     (Self : Context'Class; Look : Pomarine.Widgets.Buttons.Settings) return Pomarine.UI.Button_Handle;

   function Text_Field
     (Self        : Context'Class;
      Text        : not null Text_Adapter_Ref;
      Submit      : not null Action_Adapter_Ref;
      Placeholder : String;
      Name        : String;
      Replacing   : Replacement;
      Index       : Natural) return Pomarine.UI.Field_Handle;

   function Text_Field
     (Self        : Context'Class;
      Text        : not null Text_Adapter_Ref;
      Placeholder : String;
      Name        : String;
      Replacing   : Replacement;
      Index       : Natural) return Pomarine.UI.Field_Handle;

   function Text_Field
     (Self        : Context'Class;
      Text        : not null Text_Adapter_Ref;
      Submit      : Natural;
      Placeholder : String;
      Name        : String;
      Replacing   : Replacement;
      Index       : Natural) return Pomarine.UI.Field_Handle;

   function Check
     (Self    : Context'Class;
      Caption : String;
      Checked : not null Flag_Adapter_Ref;
      Which   : Natural;
      Form    : Pomarine.Widgets.Checks.Kind;
      Index   : Natural;
      Name    : String) return Pomarine.UI.Check_Handle;

   function Check
     (Self    : Context'Class;
      Caption : String;
      Checked : not null Flag_Adapter_Ref;
      Form    : Pomarine.Widgets.Checks.Kind;
      Name    : String) return Pomarine.UI.Check_Handle;

   function Switch
     (Self    : Context'Class;
      Caption : String;
      On      : not null Flag_Adapter_Ref;
      Which   : Natural;
      Index   : Natural;
      Name    : String) return Pomarine.UI.Switch_Handle;

   function Progress
     (Self : Context'Class; Done : not null Fraction_Adapter_Ref) return Pomarine.UI.Progress_Handle;

   function List
     (Self      : Context'Class;
      Rows      : not null Rows_Adapter_Ref;
      Selection : not null Choice_Adapter_Ref;
      Name      : String) return Pomarine.UI.List_Handle;

   --  What a control is made to do, or to show

   procedure Show_When
     (Self : Context'Class; Target : Pomarine.UI.Control_Ref; Shown : not null Flag_Adapter_Ref; Index : Natural);

   procedure Show_When
     (Self : Context'Class; Target : Pomarine.UI.Layout; Shown : not null Flag_Adapter_Ref; Index : Natural);

   procedure Enabled_When
     (Self    : Context'Class;
      Target  : Pomarine.UI.Button_Handle;
      Allowed : not null Flag_Adapter_Ref;
      Index   : Natural);

   procedure Selected_When
     (Self     : Context'Class;
      Target   : Pomarine.UI.Button_Handle;
      Selected : not null Flag_Adapter_Ref;
      Index    : Natural);

   procedure Focus_When
     (Self   : Context'Class;
      Target : Pomarine.UI.Focus_Target;
      Raised : not null Flag_Adapter_Ref;
      Index  : Natural);

   procedure Focus_Initially (Self : Context'Class; Target : Pomarine.UI.Focus_Target);

   procedure Reveal_After
     (Self   : Context'Class;
      Which  : Natural;
      Target : Pomarine.UI.Reveal_Target;
      Count  : not null Count_Adapter_Ref);

   procedure Caption_From
     (Self   : Context'Class;
      Target : Pomarine.UI.Button_Handle;
      Text   : not null Text_Adapter_Ref;
      Index  : Natural);

   --  Controls the application already owns

   function Borrow_Label
     (Self     : Context'Class;
      Existing : in out Pomarine.Widgets.Labels.Label;
      Text     : not null Text_Adapter_Ref) return Pomarine.UI.Label_Handle;

   function Borrow_Button
     (Self     : Context'Class;
      Existing : in out Pomarine.Widgets.Buttons.Button;
      Which    : Natural;
      Index    : Natural;
      Reflect  : Boolean) return Pomarine.UI.Button_Handle;

   function Borrow_Field
     (Self      : Context'Class;
      Existing  : in out Pomarine.Widgets.Text_Fields.Text_Field;
      Backing   : aliased in out Texts.Documents.Document;
      Text      : not null Text_Adapter_Ref;
      Replacing : Replacement) return Pomarine.UI.Field_Handle;

   function Borrow_Slider
     (Self     : Context'Class;
      Existing : in out Pomarine.Widgets.Sliders.Slider;
      Value    : not null Fraction_Adapter_Ref) return Pomarine.UI.Widget_Handle;

   function Borrow_Widget
     (Self : Context'Class; Existing : in out Pomarine.Widgets.Widget'Class) return Pomarine.UI.Widget_Handle;

   function Borrow_List
     (Self      : Context'Class;
      Existing  : in out Pomarine.Widgets.Lists.List;
      Rows      : not null Rows_Adapter_Ref;
      Selection : not null Choice_Adapter_Ref) return Pomarine.UI.List_Handle;

   --  Events

   procedure On_Frame_Event
     (Self   : Context'Class;
      Target : in out Pomarine.Widgets.Frames.Frame;
      Kind   : Pomarine.Widgets.Event_Kind;
      Which  : Natural;
      Index  : Natural);

   procedure On_Event
     (Self             : Context'Class;
      Target           : Pomarine.UI.Control_Ref;
      Kind             : Pomarine.Widgets.Event_Kind;
      Which            : Natural;
      Index            : Natural;
      Index_From_Event : Boolean);

   procedure On_Editor_Event
     (Self             : Context'Class;
      Target           : Pomarine.UI.Widget_Handle;
      Hook             : Editor_Hook;
      Which            : Natural;
      Index            : Natural;
      Index_From_Event : Boolean);

   procedure On_Canvas_Event
     (Self             : Context'Class;
      Target           : Pomarine.UI.Widget_Handle;
      Hook             : Canvas_Hook;
      Which            : Natural;
      Index            : Natural;
      Index_From_Event : Boolean);

   procedure On_List_Actions (Self : Context'Class; Target : Pomarine.UI.Widget_Handle; Actions : Which_Array);

end Pomarine.UI.Binders.Controls;
