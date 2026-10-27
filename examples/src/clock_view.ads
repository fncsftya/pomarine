with Clock_Faces;
with Pomarine.UI;

--  Declarative placement of a custom widget; the caller owns the face and its timer behavior.

package Clock_View is
   procedure Build (Screen : in out Pomarine.UI.View; Face : in out Clock_Faces.Face);
   --  Face must outlive Screen.
end Clock_View;
