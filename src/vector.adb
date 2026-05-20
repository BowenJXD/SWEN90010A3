with Ada.Text_IO;

package body Vector is

   procedure Put (V : Vector) is
   begin
      Ada.Text_IO.Put ("[X: ");
      Ada.Text_IO.Put (To_String (V.X));
      Ada.Text_IO.Put (", Y: ");
      Ada.Text_IO.Put (To_String (V.Y));
      Ada.Text_IO.Put ("]");
   end Put;

end Vector;
