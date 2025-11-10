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
  Result := (ADirection - ANormal * 2 * Dot(ADirection, ANormal));
end;

procedure FragmentShader(const Constants: PTracerConstantInput; const APixel: PRGB32; const PSInput: PTracerFragmentInput);
var
  LRayDirection, LLightRayDirection, LOrigin, LHitPosition: TFloat3;
  LShadowColor, LSample: TRGB32;
  LHitInfo, LLastInfo: THitInfo;
  LLightDistance, LIntensity, LTravelDistance: Single;
  LValue: Byte;
  i, k: Integer;
  LHadSubHit: Boolean;
const
  CLightColor: TRGB32 = (B: 255; G: 255; R: 255; A: 255);
  CShadowColor: TRGB32 = (B: 0; G: 0; R: 0; A: 255);
  CDebugShadowColor: TRGB32 = (B: 0; G: 255; R: 0; A: 255);
begin
  LShadowColor := CShadowColor;

  if Assigned(Constants.DebugMap) then
  begin
    Constants.DebugMap.SampleDot(PSInput.UV, @LSample);
    if (LSample.R > 0) and (LSample.B = 0) then
      LShadowColor := CDebugShadowColor
  end;

  LOrigin := PSInput.Position + PSInput.Normal*0.01;
  LLightDistance := (Constants.Light - LOrigin).Length;
  LRayDirection := (Constants.Light - LOrigin).Normalized;

  if Constants.Query.LineTrace(LOrigin, LRayDirection, LHitInfo) and (LHitInfo.Distance < LLightDistance) then
  begin
    LTravelDistance := 0;
    LHitPosition := LHitInfo.Position + LHitInfo.Triangle.Normal*0.01;
    LTravelDistance := (LHitPosition - LOrigin).Length;
    LRayDirection := (LHitPosition - LOrigin).Normalized;
    LOrigin := LHitPosition;
    //reflect
    LRayDirection := Reflect(LRayDirection, LHitInfo.Triangle.Normal);
    LLastInfo := LHitInfo;
    for i := 1 to 32 do
    begin
      if not Constants.Query.LineTrace(LOrigin, LRayDirection, LHitInfo) then
      begin
        //try to find a vector between normal and reflection that hits something
        for k := 1 to 16 do
        begin
          LRayDirection := (LRayDirection + LLastInfo.Triangle.Normal).Normalized;
          LHadSubHit := Constants.Query.LineTrace(LOrigin, LRayDirection, LHitInfo);
          if LHadSubHit then
            Break;
        end;
        if not LHadSubHit then
          Break;
      end;
      LLastInfo := LHitInfo;

      LHitPosition := LHitInfo.Position + LHitInfo.Triangle.Normal*0.01;
      LTravelDistance := LTravelDistance + (LHitPosition - LOrigin).Length;
      LRayDirection := (LHitPosition - LOrigin).Normalized;
      LRayDirection := Reflect(LRayDirection, LHitInfo.Triangle.Normal);
      LOrigin := LHitPosition;
      begin
        LLightDistance := (Constants.Light - LHitPosition).Length;
        LLightRayDirection := (Constants.Light - LHitPosition).Normalized;
        if not (Constants.Query.LineTrace(LHitPosition, LLightRayDirection, LHitInfo) and (LHitInfo.Distance < LLightDistance)) then
        begin
          LIntensity := Intensity(2500000, LLightDistance + LTravelDistance);
          LValue := Trunc(LIntensity / (1 + LIntensity) * 255);
          LSample.B := LValue;
          LSample.G := LValue;
          LSample.R := LValue;
          LSample.A := 255;
          APixel^ := LSample;
          exit;
        end;
      end;
    end;
    APixel^ := LShadowColor;
  end
  else
  begin
    LIntensity := Intensity(2500000, LLightDistance);
    LValue := Trunc(LIntensity / (1 + LIntensity) * 255);
    LSample.B := LValue;
    LSample.G := LValue;
    LSample.R := LValue;
    LSample.A := 255;
    APixel^ := LSample;
  end;
end;

type TAttributes = TTracerFragmentInput;
const DepthTest = dtNone;
{$i Rasterizer.inc}

initialization
  TShaders.Register<TTracerConstantInput, TTracerVertexInput, TTracerFragmentInput>(CTracerShader, VertexShader, RasterizeTriangle);

end.
