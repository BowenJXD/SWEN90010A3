with Ada.Numerics.Big_Numbers.Big_Reals;
use Ada.Numerics.Big_Numbers.Big_Reals;

package Vector is

   -- keep this transparent for now, but we might make it opaque later on
   type Vector is record
      X : Big_Real;
      Y : Big_Real;
   end record;

   function Add (V1 : Vector; V2 : Vector) return Vector is
      ((X => V1.X + V2.X, Y => V1.Y + V2.Y));

   function Sub (V1 : Vector; V2 : Vector) return Vector is
      ((X => V1.X - V2.X, Y => V1.Y - V2.Y));

   function Scale (V : Vector; S : Big_Real) return Vector is
      ((X => V.X * S, Y => V.Y * S));

   function Dot (V1 : Vector; V2 : Vector) return Big_Real is
      (V1.X * V2.X + V1.Y * V2.Y);

   procedure Put (V : Vector);

end Vector;
