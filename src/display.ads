with Universe;
with Ada.Numerics.Big_Numbers.Big_Reals;
use Ada.Numerics.Big_Numbers.Big_Reals;

generic
   with package Univ is new Universe (<>);
   Max_Frames : Positive;
package Display with SPARK_Mode is

   procedure Capture (U : Univ.Universe)
     with Global => null;
   --  Record a frame: stores the world coordinates of all universe
   --  items. Call once per tick.

   procedure Save
     (Filename : String;
      Arena_X_Min, Arena_X_Max,
      Arena_Y_Min, Arena_Y_Max : Big_Real)
     with Global => null;
   --  Write all captured frames as a self-contained HTML file
   --  with interactive pan/zoom canvas animation.

end Display;
