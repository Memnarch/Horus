unit Horus.Intersection;

interface

uses
  Mundus.Math,
  Horus.Types;

const Epsilon: Single = 1.19209e-07;
//function RayTriangleIntersection(const ARayPosition: TFloat3; const ARayVector: TFloat3; const AV1, AV2, AV3: TFloat3; out AHitPos: TFloat3): Boolean;
function RayTriangleIntersection(const ARayPosition: TFloat3; const ARayVector: TFloat3; const ATriangle: PTriangle; out AHitPos: TFloat3): Boolean;

implementation

uses
  System.Types;

function PointInTriangle(const APos: TFloat3; const AV0, AV1, Av2, ANormal: TFloat3): Boolean;
var
  v0v1, v1v2, v0v2, v0p, v1p, v2p: TFloat3;
begin
  v0v1 := AV1 - AV0;
  v1v2 := Av2 - AV1;
  v0v2 := AV0 - Av2;
  v0p := APos - AV0;
  v1p := APos - AV1;
  v2p := APos - Av2;
  Result := (Dot(ANormal, Cross(v0v1, v0p)) > 0)
          and (Dot(ANormal, Cross(v1v2, v1p)) > 0)
          and (Dot(ANormal, Cross(v0v2, v2p)) > 0)
end;

//https://www.scratchapixel.com/lessons/3d-basic-rendering/ray-tracing-rendering-a-triangle/ray-triangle-intersection-geometric-solution.html
function RayTriangleIntersection(const ARayPosition: TFloat3; const ARayVector: TFloat3; const ATriangle: PTriangle; out AHitPos: TFloat3): Boolean;
var
  LDotRayVector, LT: Single;
begin
  LDotRayVector := Dot(ATriangle.Normal, ARayVector);
  if Abs(LDotRayVector) < Epsilon then
    Exit(False);

  LT := (ATriangle.OriginDistance - Dot(ATriangle.Normal, ARayPosition)) / LDotRayVector;

  if LT < 0 then
    Exit(False);

  AHitPos := ARayPosition + ARayVector * LT;

  Result := PointInTriangle(AHitPos, ATriangle.A, ATriangle.B, ATriangle.C, ATriangle.Normal);
end;


//https://en.wikipedia.org/wiki/M%C3%B6ller%E2%80%93Trumbore_intersection_algorithm
//function RayTriangleIntersection(const ARayPosition: TFloat3; const ARayVector: TFloat3; const AV1, AV2, AV3: TFloat3; out AHitPos: TFloat3): Boolean;
//var
//  LEdge1, LEdge2: TFloat3;
//  LCrossEdge2, LScrossEdge1: TFloat3;
//  LDet, LInvDet: Single;
//  LS: TFloat3;
//  LU, LV, LT: Single;
//begin
//  LEdge1 := AV2 - AV1;
//  LEdge2 := AV3 - AV1;
//  LCrossEdge2 := Cross(ARayVector, LEdge2);
//
//  LDet := Dot(LEdge1, LCrossEdge2);
//  if (LDet > -Epsilon) and (LDet < Epsilon) then
//    Exit(False);
//
//  LInvDet := 1 / LDet;
//  LS := ARayPosition - AV1;
//  LU := LInvDet * Dot(LS, LCrossEdge2);
//  if ((LU < 0 ) and (Abs(LU) > Epsilon)) or ((LU > 1) and (Abs(LU - 1) > Epsilon)) then
//  //if (LU < 0) or (LU > 1) then
//    Exit(False);
//
//
//  LScrossEdge1 := Cross(LS, LEdge1);
//  LV := LInvDet * Dot(ARayVector, LScrossEdge1);
//
////  if ((LV < 0 ) and (Abs(LV) > Epsilon)) or ((LV > 1) and (Abs(LV - 1) > Epsilon)) then
//  //if (LV < 0) or (LV > 1) then
//  if ((LV < 0) and (Abs(LV) > Epsilon))
//    or
//    ((LV + LU > 1) and (Abs(LV + LU - 1) > Epsilon))
//  then
//    Exit(False);
//
//  LT := LInvDet * Dot(LEdge2, LScrossEdge1);
//  Result := LT > Epsilon;
//  if Result then
//    AHitPos := ARayPosition + ARayVector * LT;
//end;

end.
