unit Horus.Shader.Raytracer;

interface

uses
  Mundus.Math,
  Mundus.Types,
  Mundus.Texture,
  Horus.SceneQuery;

type
  TTracerConstantInput = record
    Query: TSceneQuery;
    Light: TFloat3;
    DebugMap: TTexture;
  end;

  PTracerConstantInput = ^TTracerConstantInput;

  TTracerVertexInput = packed record
    UV: TFloat2;
    Normal: TFloat3;
  end;

  TTracerFragmentInput = packed record
    Position: TFloat3;
    Normal: TFloat3;
    UV: TFloat2;
  end;

  PTracerFragmentInput = ^TTracerFragmentInput;

const
  CTracerShader = 'Raytracer';

implementation

uses
  System.Math,
  Mundus.Shader,
  Mundus.Rasterizer.Helper,
  Mundus.Rasterizer.Types,
  Horus.Intersection;

procedure VertexShader(var AVertex: TFloat4; const [Ref] Constants: TTracerConstantInput; const [ref] AVInput: TTracerVertexInput; var AVOutput: TTracerFragmentInput);
begin
  AVOutput.Position := AVertex.XYZ;
  AVOutput.Normal := AVInput.Normal;
  if Assigned(Constants.DebugMap) then
  begin
    AVOutput.UV.U := AVInput.UV.U * Constants.DebugMap.Width;
    AVOutput.UV.V := AVInput.UV.V * Constants.DebugMap.Height;
  end;
  AVertex := Float4(AVInput.UV.U * 2 - 1, AVInput.UV.V * 2 - 1, 0, 1);
end;


function Intensity(const AIntensity, ADistance: Single): Single;
begin
  Result := AIntensity / (1 + (ADistance*ADistance));
end;

function Reflect(const ADirection, ANormal: TFloat3): TFloat3;
begin
  Result := ADirection - ANormal * (2 * Dot(ADirection, ANormal));
end;

function Influence(const ANormal, ADirection: TFloat3): Single;
begin
  Result := Dot(ANormal, ADirection);
end;


function CollectLight(const Constants: PTracerConstantInput; const AOrigin, ANormal: TFloat3; const APastTraveledDistance: Single): Single;
var
  LDirection: TFloat3;
  LHit: THitInfo;
  LMaxDistance: Single;
begin
  Result := 0;
  LDirection := Constants.Light - AOrigin;
  LMaxDistance := LDirection.Length;
  LDirection := LDirection.Normalized;
  if Dot(ANormal, LDirection) > 0 then
  begin
    if not (Constants.Query.LineTrace(AOrigin, LDirection, LHit) and (LHit.Distance < LMaxDistance)) then
    begin
      Result := Result + Influence(ANormal, LDirection) * Intensity(2000000, APastTraveledDistance + LMaxDistance);
    end;
  end;
end;

function Adjust(const APosition, ANormal: TFloat3): TFloat3;
begin
  Result := APosition + ANormal*0.00014;
end;

function PerformTrace(const Constants: PTracerConstantInput; const AStart, ADirection: TFloat3): Single;
var
  LTravelDistance: Single;
  LOrigin, LRayDirection, LHitPosition: TFloat3;
  i: Integer;
  LHitInfo: THitInfo;
  LBounceIntensity: Single;
  LTransportFactor: Single;
const
  CMaxBounces = 4;
begin
  Result := CollectLight(Constants, AStart, ADirection, 0);
  LTravelDistance := 0;
  LOrigin := AStart;
  LRayDirection := ADirection;
  LBounceIntensity := 0;
  LTransportFactor := 1;
  for i := 1 to CMaxBounces do
  begin
    if not Constants.Query.LineTrace(LOrigin, LRayDirection, LHitInfo) then
    begin
      LBounceIntensity := LBounceIntensity + LTransportFactor * 0.5;
      Break;
    end;

    LHitPosition := Adjust(LHitInfo.Position, LHitInfo.Triangle.Normal);
    LTravelDistance := LTravelDistance + (LHitPosition - LOrigin).Length;
    LRayDirection := (LHitPosition - LOrigin).Normalized;

    LRayDirection := Reflect(LRayDirection, LHitInfo.Triangle.Normal);
    LOrigin := LHitPosition;
    LBounceIntensity := LBounceIntensity + LTransportFactor * CollectLight(Constants, LHitPosition, LHitInfo.Triangle.Normal, 0);
    LTransportFactor := LTransportFactor * Influence(LRayDirection, LHitInfo.Triangle.Normal);
  end;
  Result := Result + LBounceIntensity;
end;

procedure FragmentShader(const Constants: PTracerConstantInput; const APixel: PRGB32; const PSInput: PTracerFragmentInput);
var
  LRayDirection, LLowRayDirection, LHighRayDirection, LSuperlowRayDirection, LSuperHighRayDirection, LOrigin, LRayOrigin: TFloat3;
  LShadowColor, LSample: TRGB32;
  LTotalIntensity: Single;
  LValue: Byte;
  i: Integer;
  LOffset: TFloat3;
  LNorth, LSouth, LEast, LWest: TFloat3;
  LNorthEast, LSouthEast, LSouthWest, LNorthWest: TFloat3;
  LSamples: Integer;
  LDirections: array[0..7] of TFloat3;
  LPotentialTangentA, LPotentialTangentB: TFloat3;
  LTemp: Integer;
const
  CLightColor: TRGB32 = (B: 255; G: 255; R: 255; A: 255);
  CShadowColor: TRGB32 = (B: 0; G: 0; R: 0; A: 255);
  CDebugShadowColor: TRGB32 = (B: 0; G: 255; R: 0; A: 255);
  //Factor fixed to current testscene where 90 luxel represent 200 world units
  COffsetFactor = 0;// 200/90/5;
begin
  LShadowColor := CShadowColor;

  if Assigned(Constants.DebugMap) then
  begin
    Constants.DebugMap.SampleDot(PSInput.UV, @LSample);
    if (LSample.R > 0) and (LSample.B = 0) then
      LShadowColor := CDebugShadowColor
  end;

  //We can calulate the tangent to our normal by doing the crossproduct with any vector that is not paralell to the normal
  //so we try two and pick the best
  LPotentialTangentA := Cross(PSInput.Normal, Float3(0, 0, 1));
  LPotentialTangentB := Cross(PSInput.Normal, Float3(0, 1, 0));
  if LPotentialTangentA.Length > LPotentialTangentB.Length then
  begin
    LNorth := LPotentialTangentA.Normalized;
  end
  else
  begin
    LNorth := LPotentialTangentB.Normalized;
  end;

  LSouth := LNorth * -1;
  //BiNormal
  LEast := Cross(LNorth, PSInput.Normal).Normalized;
  LWest := LEast * -1;

  LNorthEast := (LNorth + LEast).Normalized;
  LNorthWest := (LNorth + LWest).Normalized;
  LSouthEast := (LSouth + LEast).Normalized;
  LSouthWest := (LSouth + LWest).Normalized;


  LDirections[0] := LNorth;
  LDirections[1] := LSouth;
  LDirections[2] := LEast;
  LDirections[3] := LWest;
  LDirections[4] := LNorthEast;
  LDirections[5] := LNorthWest;
  LDirections[6] := LSouthEast;
  LDirections[7] := LSouthWest;

  LOrigin := Adjust(PSInput.Position, PSInput.Normal);
  LSamples := Length(LDirections) * 5 + 1;
  LTotalIntensity := PerformTrace(Constants, LOrigin, PSInput.Normal);
  for i := 0 to High(LDirections) do
  begin
    //move upwards
    LOffset := LDirections[i];
    LRayOrigin := LOrigin + LOffset * COffsetFactor;
    LRayDirection := (PSInput.Normal + LOffset).Normalized;
    LLowRayDirection := (LOffset + LRayDirection).Normalized;
    LSuperlowRayDirection := (LOffset + LLowRayDirection).Normalized;
    LHighRayDirection := (PSInput.Normal + LRayDirection).Normalized;
    LSuperHighRayDirection := (PSInput.Normal + LHighRayDirection).Normalized;
    LTotalIntensity := LTotalIntensity + PerformTrace(Constants, LRayOrigin, LRayDirection);
    LTotalIntensity := LTotalIntensity + PerformTrace(Constants, LRayOrigin, LSuperlowRayDirection);
    LTotalIntensity := LTotalIntensity + PerformTrace(Constants, LRayOrigin, LLowRayDirection);
    LTotalIntensity := LTotalIntensity + PerformTrace(Constants, LRayOrigin, LHighRayDirection);
    LTotalIntensity := LTotalIntensity + PerformTrace(Constants, LRayOrigin, LSuperHighRayDirection);
  end;

  LTotalIntensity := (LTotalIntensity / LSamples);
  LTotalIntensity := LTotalIntensity / (1 + LTotalIntensity);
  LTemp := Trunc(LTotalIntensity * 255);
  LValue := LTemp;
  LSample.B := LValue;
  LSample.G := LValue;
  LSample.R := LValue;
  LSample.A := 255;
  APixel^ := LSample;
end;

type TAttributes = TTracerFragmentInput;
const DepthTest = dtNone;
{$i Rasterizer.inc}

initialization
  TShaders.Register<TTracerConstantInput, TTracerVertexInput, TTracerFragmentInput>(CTracerShader, VertexShader, RasterizeTriangle);

end.
