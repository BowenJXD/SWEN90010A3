package body Collision_Math with SPARK_Mode is

   --  ---------------------------------------------------------------
   --  Scalar-level definitions (internal to this body)
   --  ---------------------------------------------------------------

   function Sq_Dist_At (SS, SV, VV, T : Big_Real) return Big_Real is
     (SS + To_Big_Real (2) * T * SV + T * T * VV);

   function Will_Collide (SS, SV, VV, Eps2 : Big_Real) return Boolean
   is
      (if VV = To_Big_Real (0) or SV >= To_Big_Real (0)
         then SS <= Eps2
         else SS * VV - SV * SV <= Eps2 * VV)
   with
      Pre => SS >= To_Big_Real (0)
             and VV >= To_Big_Real (0)
             and Eps2 >= To_Big_Real (0);

   function Valid_Dot_Products (SS, SV, VV : Big_Real) return Boolean
   is (SS >= To_Big_Real (0)
       and VV >= To_Big_Real (0)
       and SV * SV <= SS * VV);

   --  ---------------------------------------------------------------
   --  Internal lemmas
   --  ---------------------------------------------------------------

   --  Helper: x*x >= 0 for any Big_Real x.
   procedure Lemma_Square_Nonneg (X : Big_Real)
   with
      Ghost,
      Post => X * X >= To_Big_Real (0)
   is
   begin
      if X >= To_Big_Real (0) then
         pragma Assert (X * X >= To_Big_Real (0));
      else
         pragma Assert ((-X) >= To_Big_Real (0));
         pragma Assert ((-X) * (-X) >= To_Big_Real (0));
         pragma Assert (X * X = (-X) * (-X));
      end if;
   end Lemma_Square_Nonneg;

   --  The Cauchy-Schwarz inequality proved over scalar components.
   procedure Lemma_CS_Scalar (SX, SY, VX, VY : Big_Real)
   with
      Ghost,
      Post => (SX * SX + SY * SY) >= To_Big_Real (0)
              and (VX * VX + VY * VY) >= To_Big_Real (0)
              and (SX * VX + SY * VY) * (SX * VX + SY * VY) <=
                  (SX * SX + SY * SY) * (VX * VX + VY * VY)
   is
      A : constant Big_Real := SX * VY;
      B : constant Big_Real := SY * VX;
   begin
      Lemma_Square_Nonneg (SX);
      Lemma_Square_Nonneg (SY);
      Lemma_Square_Nonneg (VX);
      Lemma_Square_Nonneg (VY);
      Lemma_Square_Nonneg (A - B);
   end Lemma_CS_Scalar;

   --  Prove that dot products from actual 2D vectors satisfy
   --  Cauchy-Schwarz.
   procedure Cauchy_Schwarz (S, V : Vector.Vector)
   with
      Ghost,
      Post => Valid_Dot_Products
                (Vector.Dot (S, S),
                 Vector.Dot (S, V),
                 Vector.Dot (V, V))
   is
   begin
      Lemma_CS_Scalar (S.X, S.Y, V.X, V.Y);
      pragma Assert (Vector.Dot (S, S) = S.X * S.X + S.Y * S.Y);
      pragma Assert (Vector.Dot (V, V) = V.X * V.X + V.Y * V.Y);
      pragma Assert (Vector.Dot (S, V) = S.X * V.X + S.Y * V.Y);
   end Cauchy_Schwarz;

   --  The PDF theorem at scalar level.
   procedure Check_Implies_Safe
      (SS, SV, VV, Eps2, T : Big_Real)
   with
      Ghost,
      Pre  => Valid_Dot_Products (SS, SV, VV) and then
              Eps2 >= To_Big_Real (0) and then T >= To_Big_Real (0)
              and then not Will_Collide (SS, SV, VV, Eps2),
      Post => Sq_Dist_At (SS, SV, VV, T) > Eps2
   is
      Zero : constant Big_Real := To_Big_Real (0);
      Two  : constant Big_Real := To_Big_Real (2);
   begin
      if VV = Zero then
         pragma Assert (SV * SV <= SS * VV);
         pragma Assert (SV * SV <= Zero);
         pragma Assert (SV = Zero);
         pragma Assert (Sq_Dist_At (SS, SV, VV, T) = SS);
      elsif SV >= Zero then
         pragma Assert (Two * T * SV >= Zero);
         pragma Assert (T * T * VV >= Zero);
         pragma Assert (Sq_Dist_At (SS, SV, VV, T) >= SS);
      else
         declare
            TVVPSV : constant Big_Real := T * VV + SV;
         begin
            pragma Assert (TVVPSV * TVVPSV >= Zero);
            pragma Assert (SS * VV - SV * SV > Eps2 * VV);
            pragma Assert
              (Sq_Dist_At (SS, SV, VV, T) * VV =
                 TVVPSV * TVVPSV + (SS * VV - SV * SV));
            pragma Assert (Sq_Dist_At (SS, SV, VV, T) * VV > Eps2 * VV);
         end;
      end if;
   end Check_Implies_Safe;

   --  ---------------------------------------------------------------
   --  Public vector-level interface
   --  ---------------------------------------------------------------

   procedure Check_Implies_Safe_Vec
      (S, V : Vector.Vector; Eps2, T : Big_Real)
   is
   begin
      Cauchy_Schwarz (S, V);
      Check_Implies_Safe
        (Vector.Dot (S, S),
         Vector.Dot (S, V),
         Vector.Dot (V, V),
         Eps2, T);
   end Check_Implies_Safe_Vec;

   procedure Lemma_Sq_Dist_Bridge
      (P1, P2, Init1, Init2, Vel1, Vel2 : Vector.Vector;
       T : Big_Real)
   is
      D : constant Vector.Vector := Vector.Sub (P1, P2);
      S : constant Vector.Vector := Vector.Sub (Init1, Init2);
      V : constant Vector.Vector := Vector.Sub (Vel1, Vel2);
   begin
      --  From preconditions: P_i = Init_i + Vel_i * T
      --  So D = P1 - P2 = (Init1 - Init2) + (Vel1 - Vel2) * T
      --       = S + V * T, component-wise:
      pragma Assert (D.X = S.X + V.X * T);
      pragma Assert (D.Y = S.Y + V.Y * T);
   end Lemma_Sq_Dist_Bridge;

end Collision_Math;
